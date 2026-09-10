// ===========================================================================
//  admin_probe.js -- READ-ONLY reconnaissance of the RMS support-admin
//  department / configuration pages.
//
//  WHY THIS EXISTS (Rob, 2026-09-10): "see if we can't get a list of active
//  tenant that have a json imported ... if possible download and ingest the
//  json for reference and cross checking."
//
//  WHY IT RUNS IN THE BROWSER AND NOT IN tools/ -- MEASURED, NOT ASSUMED.
//  A repo-side GET of /rms/api/support/admin/departments returns
//  303 See Other -> /rms/login/. Session-authenticated; only the operator's
//  logged-in browser can read it.
//
//  ⚠️ v2 (2026-09-10, SAME DAY): THESE ARE HTML PAGES, NOT JSON APIS, AND v1
//  THREW THE DATA AWAY. The path looks like an API (`/rms/api/support/...`) and
//  I built v1 around a JSON envelope. The first real run settled it:
//      status 200 · content-type: text/html · bytes 3,410,555
//  v1 kept only the first 20KB "so the real structure can be read" -- which was
//  20,022 of 3,410,555 chars (99.4% discarded) and contained ZERO <table>, <tr>
//  or `configurations/<id>` matches, because 3.4MB of Semantic-UI CSS/JS sits
//  above the content. The department table was never in the sample. The
//  downstream sweep then reported `requested: 0` and did nothing -- correctly
//  honest, but useless. The lesson is the repo's own: a recon pass must extract
//  BEFORE it truncates, or the truncation decides the finding.
//
//  SO v2 PARSES THE DOM. DOMParser is available in the page context, and these
//  are server-rendered tables, so extraction is exact rather than regex-guessed.
//  It also reads the LIVE `document` for the page the operator is already on --
//  no refetch, and guaranteed to be what is actually rendered.
//
//  READ-ONLY BY CONSTRUCTION: GET only. No POST/PUT/PATCH/DELETE, no upload,
//  no import path. Importing a JSON into a tenant changes someone's environment
//  and must never be a side effect of an inventory probe.
//
//  NOT ARM-GATED, following the authwatch precedent: the ARM switch exists
//  because the driver SUBMITS REAL QUERIES on hosts that may be live. This only
//  reads.
// ===========================================================================
(() => {
  if (window.__usxAdminProbe) return;

  const ADMIN_BASE = '/rms/api/support/admin/departments';
  const MAX_ROWS_PER_TABLE = 2000;   // generous; these are inventory tables
  const MAX_TABLES = 40;
  const SAMPLE_CHARS = 4000;         // diagnostic sample ONLY -- never the data path

  const nowStamp = () => new Date().toISOString().replace(/[:.]/g, '-');

  function dl(filename, obj) {
    if (!window.__usxLib || !window.__usxLib.triggerDownload) {
      throw new Error('usx_lib not loaded -- reload the extension before running a probe');
    }
    return window.__usxLib.triggerDownload(filename, obj);
  }

  // ---- table extraction: the actual data path ----------------------------
  const txt = (el) => (el && el.textContent ? el.textContent.replace(/\s+/g, ' ').trim() : '');

  // Nearest preceding heading, so a table can be identified without guessing
  // which one is "the" table.
  function nearestHeading(tableEl) {
    let n = tableEl;
    for (let hops = 0; hops < 6 && n; hops++) {
      let s = n.previousElementSibling;
      while (s) {
        if (/^H[1-6]$/.test(s.tagName)) return txt(s);
        s = s.previousElementSibling;
      }
      n = n.parentElement;
    }
    const cap = tableEl.querySelector('caption');
    return cap ? txt(cap) : '';
  }

  function extractTables(root) {
    const out = [];
    const tables = Array.from(root.querySelectorAll('table')).slice(0, MAX_TABLES);
    tables.forEach((t, ti) => {
      const headers = Array.from(t.querySelectorAll('thead th, thead td')).map(txt);
      let bodyRows = Array.from(t.querySelectorAll('tbody tr'));
      if (!bodyRows.length) {
        // Tables without <tbody>: take all <tr>, dropping a header-only first row.
        bodyRows = Array.from(t.querySelectorAll('tr')).filter(r => !r.querySelector('th') || r.querySelector('td'));
      }
      const rows = bodyRows.slice(0, MAX_ROWS_PER_TABLE).map(r => {
        const cells = Array.from(r.querySelectorAll('th,td')).map(txt);
        // Links carry the department id, so keep hrefs alongside the text.
        const links = Array.from(r.querySelectorAll('a[href]')).map(a => a.getAttribute('href'));
        return { cells: cells, links: links };
      });
      out.push({
        index: ti,
        heading: nearestHeading(t),
        headers: headers,
        rowCount: bodyRows.length,
        rowsKept: rows.length,
        truncated: bodyRows.length > rows.length,
        rows: rows
      });
    });
    return out;
  }

  // ── DEPARTMENT RECORDS ────────────────────────────────────────────────────────────
  // ⚠️ v3 (2026-09-10): v2 read ids ONLY from /configurations/<id> hrefs and found ZERO,
  // so the sweep had nothing to loop over and Rob reported "its not rally working yet".
  // The parse was fine -- the real departments table came back with 1785 rows and headers
  // [ID, Subdomain, Analytics Alias, Status, CAD Subdomain, SSO Connection Id] -- but the
  // ID is PLAIN TEXT IN A CELL, not a link. So: read the ID COLUMN, and keep the href path
  // only as a fallback for pages that do link.
  //
  // This is also where the answer to Rob's actual question lives: `Subdomain` identifies
  // the tenant and `Status` says whether it is active. That is "a list of active tenants"
  // without fetching anything further.
  const normHdr = (s) => (s || '').replace(/[^\x20-\x7E]/g, '').replace(/\s+/g, ' ').trim().toLowerCase();

  function extractDeptRecords(root) {
    const recs = [];
    const seen = {};
    const tables = extractTables(root);

    tables.forEach(t => {
      const hdrs = (t.headers || []).map(normHdr);
      const idIdx = hdrs.indexOf('id');
      if (idIdx < 0) return;                       // not the departments table
      const col = (name) => hdrs.indexOf(name);
      const iSub = col('subdomain'), iAlias = col('analytics alias'),
            iStat = col('status'), iCad = col('cad subdomain'), iSso = col('sso connection id');
      t.rows.forEach(r => {
        const cells = r.cells || [];
        const id = (cells[idIdx] || '').trim();
        if (!/^\d+$/.test(id) || seen[id]) return;
        seen[id] = true;
        recs.push({
          deptId: id,
          subdomain:      iSub   >= 0 ? (cells[iSub]   || '') : '',
          analyticsAlias: iAlias >= 0 ? (cells[iAlias] || '') : '',
          status:         iStat  >= 0 ? (cells[iStat]  || '') : '',
          cadSubdomain:   iCad   >= 0 ? (cells[iCad]   || '') : '',
          ssoConnectionId:iSso   >= 0 ? (cells[iSso]   || '') : '',
          source: 'id-column'
        });
      });
    });

    // Fallback / supplement: any explicit configurations link.
    Array.from(root.querySelectorAll('a[href]')).forEach(a => {
      const m = (a.getAttribute('href') || '').match(/configurations\/(\d+)/);
      if (!m || seen[m[1]]) return;
      seen[m[1]] = true;
      const tr = a.closest('tr');
      recs.push({ deptId: m[1], subdomain: txt(a), status: '', rowText: tr ? txt(tr) : '', source: 'href' });
    });
    return recs;
  }

  // Kept as a thin alias so nothing that referenced the old name breaks.
  function extractDeptIds(root) { return extractDeptRecords(root); }

  // Filtering is MANDATORY in practice, not a nicety: demo.mark43.com lists 1785
  // departments and each configuration page measured 3.4MB, so an unfiltered sweep would
  // pull roughly 6GB and hammer the host. Filter, then limit.
  // COMMA-SEPARATED, ANY-MATCH. A single substring was enough for our own fleet (all
  // `usx-*`) but the tenants that actually need verifying are the FOUNDATION ones --
  // Newark, Miami Springs, North Miami, Homestead, Balcones Heights, HDLE, Mariposa,
  // Albany County, Aurora, Lafayette, Anzini -- and those share no common prefix. They
  // are also the ones IMPORT_LEDGER.md section B maintains BY HAND ("the capture tool
  // can't reach them"), so they are the whole point of doing this at all.
  function filterRecords(recs, opts) {
    opts = opts || {};
    const toks = (opts.subdomainMatch || '').toLowerCase().split(',')
                   .map(s => s.trim()).filter(s => s.length > 0);
    const st = (opts.statusMatch || '').trim().toLowerCase();
    return (recs || []).filter(r => {
      const hay = ((r.subdomain || '') + ' ' + (r.analyticsAlias || '') + ' ' + (r.cadSubdomain || '')).toLowerCase();
      if (toks.length && !toks.some(t => hay.includes(t))) return false;
      if (st && !((r.status || '').toLowerCase().includes(st))) return false;
      return true;
    });
  }

  // ── FINDING THE DATA ENDPOINT (v4, 2026-09-10) ────────────────────────────────────
  // PROVEN: the bundle table is JAVASCRIPT-POPULATED. The same configuration page returns
  // rowCount 0 when FETCHED and rowCount 3 from the LIVE DOM:
  //     tfas8xq | ENTITIES | 590
  //     w7p2cdq | CA_eSUN  | 48
  //     0ydnyze | RMS      | 70
  // (that is the mandated 3-bundle structure, so the page really does say which JSON is
  // imported). A fetch does not execute scripts, so a fetch-based sweep will ALWAYS see an
  // empty table -- reading 21 pages that way would have produced 21 confident zeros.
  //
  // So: harvest the URL the page's own JS calls, and sweep THAT instead. Scanning inline
  // scripts is diagnostic -- it reports candidates and does not act on them.
  function extractEndpointCandidates(root) {
    const cands = [];
    const seen = {};
    const push = (u, where) => {
      if (!u || seen[u] || u.length > 300) return;
      seen[u] = true;
      cands.push({ url: u, where: where });
    };
    // Inline scripts: any quoted path that looks like an API route.
    Array.from(root.querySelectorAll('script:not([src])')).forEach((s, i) => {
      const code = s.textContent || '';
      const rx = /["'`](\/[A-Za-z0-9_\-\/.${}:]*(?:bundle|configuration|department|admin)[A-Za-z0-9_\-\/.${}:]*)["'`]/gi;
      let m;
      while ((m = rx.exec(code)) !== null) push(m[1], 'inline-script[' + i + ']');
      // Explicit jQuery/fetch call sites, which name the verb as well as the URL.
      const rx2 = /(?:\$\.(?:get|post|ajax)|fetch)\s*\(\s*["'`]([^"'`]+)["'`]/gi;
      while ((m = rx2.exec(code)) !== null) push(m[1], 'call-site inline-script[' + i + ']');
    });
    Array.from(root.querySelectorAll('script[src]')).forEach(s => push(s.getAttribute('src'), 'script-src'));
    return cands;
  }

  // ── v5: READ EACH PAGE IN A HIDDEN IFRAME, SO ITS OWN SCRIPTS RUN ────────────────
  // This replaces both bad options. The bundle table is JS-populated, so:
  //   - fetching gives an empty table (proven: 21 confident zeros), and
  //   - the "find the endpoint the page calls" route needs a diagnostic round-trip
  //     through the operator before a single tenant can be read.
  // An iframe is same-origin here, so the page loads, ITS OWN SCRIPTS FILL THE TABLE,
  // and the DOM is directly readable -- identical to what the live-DOM read produced,
  // for every department, from one click.
  //
  // WHY THIS IS CHEAP: the 3.4MB page is the departments LIST. A configuration page
  // measured ~63KB, so 21 of them is ~1.3MB total. The earlier "unfiltered sweep is
  // ~6GB" warning was about fetching the LIST repeatedly, not these.
  //
  // WAITS FOR THE ROWS, does not guess a fixed delay: polls until a table has rows or
  // the budget expires, and REPORTS which happened. A timeout that silently returns an
  // empty table would recreate the exact defect this is fixing.
  function readViaIframe(url, budgetMs) {
    budgetMs = budgetMs || 12000;
    return new Promise((resolve) => {
      const fr = document.createElement('iframe');
      fr.style.cssText = 'position:fixed;left:-10000px;top:0;width:1200px;height:800px;opacity:0;pointer-events:none';
      let done = false;
      const t0 = Date.now();

      const finish = (why) => {
        if (done) return;
        done = true;
        let tables = null, err = null;
        try {
          const doc = fr.contentDocument;
          tables = doc ? extractTables(doc) : null;
          if (!doc) err = 'no contentDocument (cross-origin or blocked)';
        } catch (e) { err = 'DOM access threw: ' + String(e && e.message || e); }
        try { fr.remove(); } catch (e) {}
        const rowTotal = (tables || []).reduce((a, t) => a + (t.rowCount || 0), 0);
        resolve({
          method: 'iframe', url: url, why: why, waitedMs: Date.now() - t0,
          tables: tables, error: err, rowTotal: rowTotal,
          // An empty result is REPORTED as unresolved rather than as "no bundles".
          verdict: err ? 'ERROR' : (rowTotal > 0 ? 'ROWS' : 'NO-ROWS-WITHIN-BUDGET')
        });
      };

      const poll = () => {
        if (done) return;
        let rows = 0;
        try {
          const doc = fr.contentDocument;
          if (doc) {
            doc.querySelectorAll('table').forEach(t => {
              rows += t.querySelectorAll('tbody tr').length;
            });
          }
        } catch (e) { finish('dom-access-error'); return; }
        if (rows > 0) { finish('rows-appeared'); return; }
        if (Date.now() - t0 > budgetMs) { finish('budget-expired'); return; }
        setTimeout(poll, 250);
      };

      fr.onload = () => setTimeout(poll, 150);
      fr.onerror = () => finish('iframe-error');
      fr.src = url;
      document.body.appendChild(fr);
      setTimeout(() => { if (!done) finish('hard-timeout'); }, budgetMs + 3000);
    });
  }

  // ---- fetch: report the response, extract WITHOUT truncating first -------
  async function getParsed(url) {
    const res = await fetch(url, {
      method: 'GET',
      credentials: 'same-origin',
      headers: { 'Accept': 'text/html,application/json;q=0.9,*/*;q=0.8' },
      redirect: 'follow'
    });
    const ct = res.headers.get('content-type') || '';
    const body = await res.text();
    const meta = {
      url: url, status: res.status, ok: res.ok, finalUrl: res.url,
      contentType: ct, bytes: body ? body.length : 0,
      looksLikeLogin: /\/login\/?$/.test(res.url || '') || /name=["']?password/i.test(body || '')
    };
    let json = null, tables = null, deptIds = null;
    if (ct.includes('json') || /^\s*[\[{]/.test(body || '')) {
      try { json = JSON.parse(body); } catch (e) { meta.jsonParseError = String(e && e.message || e); }
    }
    if (!json && body) {
      const doc = new DOMParser().parseFromString(body, 'text/html');
      tables = extractTables(doc);
      deptIds = extractDeptIds(doc);
    }
    // Sample is for DIAGNOSIS ONLY. Never the data path -- that was the v1 bug.
    meta.sample = (body || '').slice(0, SAMPLE_CHARS);
    return { meta: meta, json: json, tables: tables, deptIds: deptIds };
  }

  // ---- STEP 1: department list -------------------------------------------
  async function listDepartments(opts) {
    opts = opts || {};
    let r, source;
    // If the operator is ALREADY on the departments page, read the live DOM --
    // exact, and avoids re-downloading 3.4MB.
    if (!opts.forceFetch && /\/rms\/api\/support\/admin\/departments\/?$/.test(location.pathname)) {
      r = {
        meta: { url: location.href, status: 200, ok: true, finalUrl: location.href,
                contentType: 'text/html (LIVE DOM)', bytes: document.documentElement.outerHTML.length,
                looksLikeLogin: false, sample: '(live DOM -- no sample needed)' },
        json: null, tables: extractTables(document), deptIds: extractDeptIds(document)
      };
      source = 'live-dom';
    } else {
      r = await getParsed(ADMIN_BASE);
      source = 'fetch';
    }
    const out = {
      probe: 'admin-departments', version: 2, source: source,
      capturedAt: new Date().toISOString(), host: location.hostname,
      meta: r.meta,
      tableSummary: (r.tables || []).map(t => ({ index: t.index, heading: t.heading, headers: t.headers, rowCount: t.rowCount, truncated: t.truncated })),
      tables: r.tables, json: r.json,
      deptIds: r.deptIds, deptIdCount: (r.deptIds || []).length,
      notes: []
    };
    if (r.meta.looksLikeLogin) out.notes.push('LOGIN REDIRECT -- not authenticated for this host.');
    if (!r.meta.ok) out.notes.push('HTTP ' + r.meta.status);
    if (out.deptIdCount === 0) {
      out.notes.push('ZERO department ids found. That is a FINDING about this probe or the markup, NOT proof there are no tenants -- check tableSummary and sample.');
    } else {
      out.notes.push(out.deptIdCount + ' department id(s) extracted from /configurations/<id> links.');
    }
    return out;
  }

  // ── v6: EXERCISE THE EXPORT CONTROL (Rob: "i was hoping you could exercise the export
  //     buttons yourself via the extnetion to pull cross reference and catalog") ────────
  // Exporting a bundle yields the ACTUAL JSON, and our version lives inside it (the bundle
  // description, "Provider configuration for <P> v<X.Y>"). That is the only route left to a
  // real version-per-tenant catalogue: the table's Version column is a platform counter and
  // there is no API endpoint to harvest (① found only CDN script tags).
  //
  // ⚠️ THIS PAGE IS AN ADMIN PAGE AND MAY CARRY DESTRUCTIVE CONTROLS. Blind-clicking
  // anything here could delete a bundle or trigger an import. So the design is:
  //   1. ENUMERATE every control and REPORT it -- no clicking at all on the first pass.
  //   2. Click ONLY a control that matches the export allowlist AND matches nothing on the
  //      destructive denylist. A control that is ambiguous is REPORTED, NOT CLICKED.
  //   3. Never click more than one control per page, and never a form submit.
  // The denylist is deliberately broader than the allowlist is narrow.
  const EXPORT_OK   = /(export|download|view\s*json|show\s*json|json|copy|raw|inspect)/i;
  const DESTRUCTIVE = /(delete|remove|destroy|drop|import|upload|replace|overwrite|reset|revert|rollback|deactivate|disable|enable|save|submit|apply|publish|promote|migrate|sync|clear|purge|archive|restore)/i;

  function describeControl(el, idx) {
    const attrs = {};
    Array.from(el.attributes || []).forEach(a => { attrs[a.name] = (a.value || '').slice(0, 200); });
    const label = (el.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 120);
    const rowText = (() => { const tr = el.closest && el.closest('tr'); return tr ? (tr.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 160) : ''; })();
    const isExport = EXPORT_OK.test(label) || EXPORT_OK.test(attrs['href'] || '') || EXPORT_OK.test(attrs['id'] || '') || EXPORT_OK.test(attrs['class'] || '') || EXPORT_OK.test(attrs['download'] || '');
    const isDestr  = DESTRUCTIVE.test(label) || DESTRUCTIVE.test(attrs['href'] || '') || DESTRUCTIVE.test(attrs['id'] || '') || DESTRUCTIVE.test(attrs['class'] || '') || DESTRUCTIVE.test(attrs['name'] || '');
    return {
      index: idx, tag: el.tagName, label: label, rowText: rowText, attrs: attrs,
      looksExport: isExport, looksDestructive: isDestr,
      // The verdict the clicker will act on, so it is auditable in the file.
      clickable: (isExport && !isDestr)
    };
  }

  function enumerateControls(doc) {
    const els = Array.from(doc.querySelectorAll('a, button, input[type=submit], input[type=button], [role=button]'));
    return els.slice(0, 400).map(describeControl);
  }

  // Direct-download links are better than a click: fetchable, no side effects at all.
  function directJsonLinks(doc) {
    return Array.from(doc.querySelectorAll('a[href]'))
      .map(a => ({ href: a.getAttribute('href'), download: a.getAttribute('download') || null, text: (a.textContent || '').trim().slice(0, 80) }))
      .filter(x => x.href && (/\.json(\?|$)/i.test(x.href) || x.download || /export|download/i.test(x.href)))
      .filter(x => !DESTRUCTIVE.test(x.href));
  }

  async function probeExportControls(deptId, opts) {
    opts = opts || {};
    const url = ADMIN_BASE + '/configurations/' + encodeURIComponent(deptId);
    const budget = opts.budgetMs || 12000;
    const out = { probe: 'admin-export-controls', version: 6, deptId: String(deptId), url: url,
                  capturedAt: new Date().toISOString(), host: location.hostname,
                  clicked: null, notes: [] };

    const fr = document.createElement('iframe');
    fr.style.cssText = 'position:fixed;left:-10000px;top:0;width:1280px;height:900px;opacity:0;pointer-events:none';
    document.body.appendChild(fr);
    try {
      await new Promise((res) => { fr.onload = () => setTimeout(res, 400); fr.onerror = () => setTimeout(res, 0); fr.src = url; setTimeout(res, budget); });
      const doc = fr.contentDocument;
      if (!doc) { out.notes.push('no contentDocument -- cannot enumerate'); return out; }

      // Wait for the JS-populated table before enumerating, or the row controls will not exist yet.
      const t0 = Date.now();
      while (Date.now() - t0 < budget) {
        if (doc.querySelectorAll('tbody tr').length > 0) break;
        await new Promise(r => setTimeout(r, 250));
      }

      out.tables = extractTables(doc);
      out.controls = enumerateControls(doc);
      out.directJsonLinks = directJsonLinks(doc);
      out.controlSummary = {
        total: out.controls.length,
        looksExport: out.controls.filter(c => c.looksExport).length,
        looksDestructive: out.controls.filter(c => c.looksDestructive).length,
        clickable: out.controls.filter(c => c.clickable).length
      };
      out.notes.push('ENUMERATION ONLY unless a control passed the export allowlist AND the destructive denylist.');

      if (!opts.click) { out.notes.push('click=false -- nothing was clicked.'); return out; }

      const cand = out.controls.filter(c => c.clickable);
      if (!cand.length) {
        out.notes.push('NO control passed both lists, so NOTHING was clicked. See controls[] and decide by hand.');
        return out;
      }

      // Click exactly ONE, and record the before/after so the effect is evidence.
      const target = cand[0];
      const before = { html: doc.documentElement.outerHTML.length, tables: out.tables.length,
                       pre: doc.querySelectorAll('pre,textarea,code').length };
      const els = Array.from(doc.querySelectorAll('a, button, input[type=submit], input[type=button], [role=button]'));
      const elToClick = els[target.index];
      out.clicked = { control: target, before: before, after: null, newText: null };
      if (!elToClick) { out.notes.push('candidate index no longer resolves -- DOM changed; nothing clicked.'); return out; }
      elToClick.click();

      // Watch for the effect: a modal/pre/textarea appearing, or the DOM growing.
      const t1 = Date.now();
      let after = null;
      while (Date.now() - t1 < budget) {
        await new Promise(r => setTimeout(r, 300));
        after = { html: doc.documentElement.outerHTML.length, tables: extractTables(doc).length,
                  pre: doc.querySelectorAll('pre,textarea,code').length };
        if (after.pre > before.pre || after.html > before.html + 2000) break;
      }
      out.clicked.after = after;

      // If JSON-looking text appeared, capture it -- that IS the bundle.
      const blobs = Array.from(doc.querySelectorAll('pre,textarea,code'))
        .map(n => (n.value || n.textContent || '').trim())
        .filter(s => s.length > 200 && /^[\[{]/.test(s));
      if (blobs.length) {
        out.clicked.newText = blobs.map(s => s.slice(0, 400000));
        out.notes.push('JSON-LOOKING TEXT APPEARED after the click -- captured (' + blobs.length + ' blob(s)).');
      } else {
        out.notes.push('No JSON text appeared in-page. If the click started a FILE DOWNLOAD it will be in Downloads; check there.');
      }
      return out;
    } finally {
      try { fr.remove(); } catch (e) {}
    }
  }

  // Pull the bundle rows out of whichever table carries [ID, Name, Version].
  // Proven shape from CA_eSUN's live DOM: tfas8xq|ENTITIES|590, w7p2cdq|CA_eSUN|48,
  // 0ydnyze|RMS|70 -- i.e. our mandated ENTITIES / <PROVIDER> / RMS trio.
  // ⚠️ `version` here is a PLATFORM BUNDLE COUNTER (590/48/70), NOT our JSON version
  // (v3.3). Never present it as the provider version.
  function extractBundles(tables) {
    const out = [];
    (tables || []).forEach(t => {
      const h = (t.headers || []).map(normHdr);
      const iId = h.indexOf('id'), iName = h.indexOf('name'), iVer = h.indexOf('version');
      if (iName < 0) return;
      (t.rows || []).forEach(r => {
        const c = r.cells || [];
        const name = (c[iName] || '').trim();
        if (!name) return;
        out.push({
          bundleId: iId >= 0 ? (c[iId] || '').trim() : '',
          name: name,
          platformBundleVersion: iVer >= 0 ? (c[iVer] || '').trim() : '',
          note: 'platformBundleVersion is a PLATFORM counter, NOT the provider JSON version'
        });
      });
    });
    return out;
  }

  // ---- STEP 2: per-department configuration / bundles --------------------
  async function scanConfigurations(deptIds, opts) {
    opts = opts || {};
    const limit = Math.max(1, Math.min(parseInt(opts.limit, 10) || 5, 1000));
    const delayMs = Math.max(0, parseInt(opts.delayMs, 10) || 200);
    const ids = (deptIds || []).slice(0, limit);
    const out = {
      probe: 'admin-configurations', version: 2,
      capturedAt: new Date().toISOString(), host: location.hostname,
      requested: ids.length, limitApplied: limit,
      results: [], notes: ['READ-ONLY: GET only, no import performed.']
    };
    for (const item of ids) {
      const id = (item && item.deptId) ? item.deptId : item;
      const url = ADMIN_BASE + '/configurations/' + encodeURIComponent(id);
      // IFRAME, NOT FETCH. The bundle table is JS-populated; a fetch returns it empty
      // (proven across all 21 tenants). The iframe runs the page's own scripts.
      const r = await readViaIframe(url, opts.budgetMs);
      const bundles = extractBundles(r.tables);
      out.results.push({
        deptId: id,
        subdomain: (item && item.subdomain) || null,
        status: (item && item.status) || null,
        method: r.method, verdict: r.verdict, waitedMs: r.waitedMs, why: r.why, error: r.error,
        bundleCount: bundles.length,
        bundles: bundles,
        tableSummary: (r.tables || []).map(t => ({ index: t.index, heading: t.heading, headers: t.headers, rowCount: t.rowCount })),
        tables: r.tables
      });
      if (delayMs) await new Promise(res => setTimeout(res, delayMs));
    }
    const withRows = out.results.filter(x => x.verdict === 'ROWS').length;
    const noRows   = out.results.filter(x => x.verdict === 'NO-ROWS-WITHIN-BUDGET').length;
    const errored  = out.results.filter(x => x.verdict === 'ERROR').length;
    out.notes.push(out.results.length + ' department(s) read via iframe: ' + withRows + ' returned rows, '
      + noRows + ' returned none within the wait budget, ' + errored + ' errored.');
    if (noRows > 0) {
      out.notes.push('A NO-ROWS-WITHIN-BUDGET result is UNRESOLVED, not "no bundles imported" -- raise budgetMs or re-run those ids before drawing any conclusion.');
    }
    return out;
  }

  // ---- entry points ------------------------------------------------------
  async function runList() {
    const o = await listDepartments();
    dl('usx_admin_departments_' + location.hostname + '_' + nowStamp() + '.json', o);
    return o;
  }

  // ONE CLICK = LIST + FILTER + SWEEP. The operator should not be navigating per tenant;
  // the loop is the probe's job. But the loop MUST be filtered first -- see filterRecords.
  async function runScan(opts) {
    opts = opts || {};
    const listing = await listDepartments();
    const all = listing.deptIds || [];

    // EXPLICIT ID LIST BEATS A SUBSTRING FILTER, and the first real attempt showed why:
    // filtering on `usx,newark,miami,homestead,balcones,hdle,mariposa,lafayette,albany,
    // aurora,anzini` matched 63 departments because "miami" also catches miami-dade,
    // miamigardens and four migration rounds, "aurora" catches northaurorapd, and
    // "lafayette" catches ten. With a `how many` cap the sweep then read the wrong five.
    // Once the ids are known (they are, from the index), naming them is exact.
    let matched;
    const idList = (opts.deptIds || '').split(',').map(s => s.trim()).filter(s => /^\d+$/.test(s));
    if (idList.length) {
      const byId = {};
      all.forEach(r => { byId[r.deptId] = r; });
      // Keep an id even if it is NOT in the index -- reporting "requested but not listed"
      // is information; silently dropping it would look like a clean result.
      matched = idList.map(id => byId[id] || { deptId: id, subdomain: '(not in index)', status: '' });
    } else {
      matched = filterRecords(all, opts);
    }
    const o = await scanConfigurations(matched, opts);
    o.listing = {
      deptIdCount: listing.deptIdCount,
      matchedCount: matched.length,
      subdomainMatch: opts.subdomainMatch || '(none)',
      statusMatch: opts.statusMatch || '(none)',
      tableSummary: listing.tableSummary,
      // Keep the MATCHED records -- v2 dropped every row and left the output unusable
      // even though 1785 had been extracted.
      matchedRecords: matched,
      notes: listing.notes
    };
    if (all.length && !matched.length) {
      o.notes.push('FILTER MATCHED NOTHING: ' + all.length + ' departments listed but 0 matched subdomain="' + (opts.subdomainMatch || '') + '" status="' + (opts.statusMatch || '') + '". Widen the filter -- this is not evidence of absence.');
    }
    dl('usx_admin_bundles_' + location.hostname + '_' + nowStamp() + '.json', o);
    return o;
  }

  // Two entry points, separate ON PURPOSE. The LOOK must be runnable with no chance of
  // acting on an admin page; only the TRY clicks, and then at most one allowlisted,
  // non-destructive control.
  async function runExportLook(deptId) {
    const o = await probeExportControls(deptId, { click: false });
    dl('usx_admin_controls_' + deptId + '_' + nowStamp() + '.json', o);
    return o;
  }
  async function runExportTry(deptId) {
    const o = await probeExportControls(deptId, { click: true });
    dl('usx_admin_export_' + deptId + '_' + nowStamp() + '.json', o);
    return o;
  }

  // ── v7: EXPORT SWEEP -- the actual "document what version each tenant has" ─────────
  // One click, N tenants. Proven single-tenant first (eSUN: tenant v3.3 == repo v3.3), which
  // is the order that matters -- a sweep built before the single case worked would have
  // produced N confident wrongs, exactly as the fetch-based bundle sweep did.
  //
  // ⚠️ DOES NOT KEEP THE FULL PAYLOAD BY DEFAULT. One export measured 294,107 chars; 31 of
  // them is ~9MB in a single download, and the catalogue only needs provider + version +
  // counters. `keepFull` is opt-in for when the whole config is actually wanted for diffing.
  async function runExportSweep(opts) {
    opts = opts || {};
    const idList = (opts.deptIds || '').split(',').map(s => s.trim()).filter(s => /^\d+$/.test(s));
    const out = {
      probe: 'admin-export-sweep', version: 7, capturedAt: new Date().toISOString(),
      host: location.hostname, requested: idList.length, results: [],
      notes: ['READ-ONLY: clicks at most ONE allowlisted, non-destructive control per tenant.']
    };
    if (!idList.length) { out.notes.push('NO VALID DEPT IDS GIVEN -- nothing attempted.'); return out; }

    // The index gives each id a subdomain, which is what makes the catalogue readable.
    let byId = {};
    try {
      const listing = await listDepartments();
      (listing.deptIds || []).forEach(r => { byId[r.deptId] = r; });
    } catch (e) { out.notes.push('index unavailable (' + String(e && e.message || e) + ') -- ids will have no subdomain'); }

    for (const id of idList) {
      let rec = { deptId: id, subdomain: (byId[id] && byId[id].subdomain) || null,
                  status: (byId[id] && byId[id].status) || null,
                  provider: null, version: null, counters: null, verdict: null, error: null };
      try {
        const r = await probeExportControls(id, { click: true, budgetMs: opts.budgetMs });
        const blobs = (r.clicked && r.clicked.newText) ? r.clicked.newText : [];
        let full = null, summary = null;
        blobs.forEach(b => {
          if (b.indexOf('"departmentBundle"') >= 0) { if (!full || b.length > full.length) full = b; }
          else if (b.indexOf('"bundles"') >= 0 && b.length < 4000) summary = b;
        });
        if (summary) {
          try {
            const sj = JSON.parse(summary);
            rec.counters = (sj.bundles || []).map(b => b.name + '/' + b.version).join(' ');
            rec.departmentBundleVersion = sj.version;
          } catch (e) {}
        }
        if (full) {
          // OUR version string -- the bundle description. Prefer a non-RMS provider.
          const rx = /Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)/g;
          let m, first = null;
          while ((m = rx.exec(full)) !== null) {
            if (!first) first = m;
            if (m[1] !== 'RMS') { rec.provider = m[1]; rec.version = m[2]; break; }
          }
          if (!rec.provider && first) { rec.provider = first[1]; rec.version = first[2]; }
          rec.fullBytes = full.length;
          if (opts.keepFull) rec.full = full;
          rec.verdict = rec.version ? 'VERSION-READ' : 'EXPORTED-BUT-NO-VERSION-STRING';
        } else if (!r.clicked) {
          rec.verdict = 'NO-SAFE-CONTROL';   // nothing passed both lists
        } else {
          rec.verdict = 'CLICKED-BUT-NO-JSON';
        }
      } catch (e) {
        rec.verdict = 'ERROR'; rec.error = String(e && e.message || e);
      }
      out.results.push(rec);
      await new Promise(r => setTimeout(r, 200));
    }
    const got = out.results.filter(r => r.verdict === 'VERSION-READ').length;
    out.notes.push(got + ' of ' + out.results.length + ' tenant(s) yielded a version string.');
    if (got < out.results.length) {
      out.notes.push('A non-VERSION-READ row is UNRESOLVED, not "no config" -- read its verdict.');
    }
    return out;
  }

  async function runExportSweepDl(opts) {
    const o = await runExportSweep(opts);
    dl('usx_admin_versions_' + location.hostname + '_' + nowStamp() + '.json', o);
    return o;
  }

  // ── v8: THE FULL CENSUS -- ALL 1785 DEPARTMENTS ─────────────────────────────────────
  // Rob's actual goal, restated: "scan the entire departments page and visit each
  // configuration page to 1 determine if it has a usx provider installed and download to
  // compare what version for cross checking".
  //
  // TWO PHASES, BECAUSE ONE PHASE CANNOT WORK:
  //   PHASE 1 (this function) -- iframe each configuration page and read the BUNDLE TABLE
  //     only. That answers "does it have a USx provider installed?" for every tenant, and
  //     costs one ~63KB page load each. No export click, no 294KB payload.
  //   PHASE 2 (runExportSweep, already built) -- click Export JSON ONLY for the tenants
  //     phase 1 found a provider bundle on, to read the actual version.
  // Doing phase 2 for all 1785 would be ~525MB of payload (294KB x 1785) and is the reason
  // the phases are split rather than merged.
  //
  // CHUNKED AND RESUMABLE ON PURPOSE. 1785 page loads is ~20-25 minutes; a single
  // end-of-run download would lose everything to one browser hiccup at #1700. Each chunk
  // saves its own self-contained file, so a failure costs one chunk and I can resume from a
  // named index instead of starting over.
  //
  // A PROVIDER BUNDLE is any bundle whose name is neither ENTITIES nor RMS -- deliberately
  // NOT matched against our 20 provider names, so an UNKNOWN provider bundle (a name nobody
  // here recognises) shows up as a finding instead of being filtered out as noise.
  const NON_PROVIDER_BUNDLES = { 'ENTITIES': 1, 'RMS': 1 };
  window.__usxAdminAbort = false;

  async function runFullScan(opts) {
    opts = opts || {};
    const chunk = Math.max(10, Math.min(parseInt(opts.chunk, 10) || 250, 1000));
    const from = Math.max(0, parseInt(opts.from, 10) || 0);
    const delayMs = Math.max(0, parseInt(opts.delayMs, 10) || 150);
    const budgetMs = opts.budgetMs || 9000;
    const onProgress = opts.onProgress || function () {};

    const listing = await listDepartments();
    const all = listing.deptIds || [];
    if (!all.length) { throw new Error('department index came back empty -- nothing to scan'); }

    let idx = from;
    let chunkNo = 0;
    const totals = { scanned: 0, withProvider: 0, empty: 0, unresolved: 0, errored: 0, files: [] };

    while (idx < all.length) {
      if (window.__usxAdminAbort) { totals.aborted = true; break; }
      const slice = all.slice(idx, idx + chunk);
      const out = {
        probe: 'admin-full-scan', version: 8, capturedAt: new Date().toISOString(),
        host: location.hostname, indexTotal: all.length,
        range: { from: idx, to: idx + slice.length - 1 },
        results: [], notes: ['READ-ONLY: GET only, no click, no import. Bundle table read from a hidden iframe.']
      };

      for (let i = 0; i < slice.length; i++) {
        if (window.__usxAdminAbort) { out.notes.push('ABORTED by operator at offset ' + (idx + i)); totals.aborted = true; break; }
        const rec = slice[i];
        const url = ADMIN_BASE + '/configurations/' + encodeURIComponent(rec.deptId);
        let r;
        try { r = await readViaIframe(url, budgetMs); }
        catch (e) { r = { verdict: 'ERROR', error: String(e && e.message || e), tables: null, waitedMs: 0 }; }

        const bundles = extractBundles(r.tables);
        const provs = bundles.filter(b => !NON_PROVIDER_BUNDLES[b.name]);
        const row = {
          deptId: rec.deptId, subdomain: rec.subdomain, status: rec.status,
          verdict: r.verdict, waitedMs: r.waitedMs,
          bundleCount: bundles.length,
          providerBundles: provs.map(b => ({ name: b.name, platformCounter: b.platformBundleVersion })),
          hasRms: bundles.some(b => b.name === 'RMS'),
          hasEntities: bundles.some(b => b.name === 'ENTITIES'),
          error: r.error || null
        };
        out.results.push(row);

        totals.scanned++;
        if (r.verdict === 'ERROR') totals.errored++;
        else if (provs.length) totals.withProvider++;
        else if (r.verdict === 'NO-ROWS-WITHIN-BUDGET') totals.unresolved++;
        else totals.empty++;

        if ((totals.scanned % 10) === 0 || provs.length) {
          onProgress({ scanned: totals.scanned, total: all.length, withProvider: totals.withProvider,
                       current: rec.subdomain, found: provs.map(p => p.name).join(',') });
        }
        if (delayMs) await new Promise(res => setTimeout(res, delayMs));
      }

      out.chunkTotals = {
        scanned: out.results.length,
        withProvider: out.results.filter(x => x.providerBundles.length).length,
        empty: out.results.filter(x => !x.providerBundles.length && x.verdict === 'ROWS').length,
        unresolved: out.results.filter(x => x.verdict === 'NO-ROWS-WITHIN-BUDGET').length,
        errored: out.results.filter(x => x.verdict === 'ERROR').length
      };
      // UNRESOLVED IS NOT EMPTY. A page that did not fill within the budget has NOT been
      // shown to lack a provider -- conflating those would understate the fleet.
      out.notes.push('unresolved = page did not fill within ' + budgetMs + 'ms; that is UNKNOWN, not "no provider".');
      const name = 'usx_admin_scan_' + String(out.range.from).padStart(5, '0') + '-' + String(out.range.to).padStart(5, '0') + '_' + nowStamp() + '.json';
      dl(name, out);
      totals.files.push(name);
      chunkNo++;
      idx += slice.length;
      if (totals.aborted) break;
    }
    totals.indexTotal = all.length;
    totals.chunks = chunkNo;
    return totals;
  }

  async function runOne(deptId) {
    const onThisPage = new RegExp('configurations/' + deptId + '$').test(location.pathname);
    let o;
    if (onThisPage) {
      // Read the rendered page directly.
      o = {
        probe: 'admin-configurations', version: 2, source: 'live-dom',
        capturedAt: new Date().toISOString(), host: location.hostname,
        requested: 1, limitApplied: 1,
        results: [{
          deptId: deptId, tenantHint: document.title || null,
          meta: { url: location.href, status: 200, ok: true, contentType: 'text/html (LIVE DOM)',
                  bytes: document.documentElement.outerHTML.length, looksLikeLogin: false,
                  sample: '(live DOM -- no sample needed)' },
          tables: extractTables(document), json: null,
          // The bundle table is JS-populated, so a fetch-based sweep sees zeros. These are
          // the candidate URLs the page's own scripts reference -- the way to a sweep that
          // does not need 21 page loads.
          endpointCandidates: extractEndpointCandidates(document)
        }],
        notes: ['READ-ONLY. Read from the LIVE DOM of the page you are on.',
                'endpointCandidates lists URLs referenced by this page\'s scripts -- reported, NOT called.']
      };
      o.results[0].tableSummary = o.results[0].tables.map(t => ({ index: t.index, heading: t.heading, headers: t.headers, rowCount: t.rowCount }));
    } else {
      o = await scanConfigurations([deptId], { limit: 1, delayMs: 0 });
    }
    dl('usx_admin_one_' + deptId + '_' + nowStamp() + '.json', o);
    return o;
  }

  window.__usxAdminProbe = { runList, runScan, runOne, runExportLook, runExportTry,
                             runExportSweep, runExportSweepDl, runFullScan,
                             probeExportControls, enumerateControls, listDepartments, scanConfigurations,
                             extractTables, extractDeptRecords, extractDeptIds, filterRecords,
                             extractBundles, readViaIframe, ADMIN_BASE };
  console.log('[USx-ADMIN] admin_probe v5 loaded -- reads each configuration page in a HIDDEN IFRAME so its own scripts populate the bundle table. A FETCH returns it EMPTY (that produced 21 confident zeros); the iframe reproduces the live-DOM result for every department from one click. READ-ONLY, GET only. BUILD 2026-09-10e.');
})();
