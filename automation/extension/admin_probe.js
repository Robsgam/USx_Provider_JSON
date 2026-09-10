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

  window.__usxAdminProbe = { runList, runScan, runOne, listDepartments, scanConfigurations,
                             extractTables, extractDeptRecords, extractDeptIds, filterRecords,
                             extractBundles, readViaIframe, ADMIN_BASE };
  console.log('[USx-ADMIN] admin_probe v5 loaded -- reads each configuration page in a HIDDEN IFRAME so its own scripts populate the bundle table. A FETCH returns it EMPTY (that produced 21 confident zeros); the iframe reproduces the live-DOM result for every department from one click. READ-ONLY, GET only. BUILD 2026-09-10e.');
})();
