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

  // Department ids from any /configurations/<id> href anywhere in the document.
  // Independent of table shape, so it still works if the markup changes.
  function extractDeptIds(root) {
    const ids = [];
    const seen = {};
    Array.from(root.querySelectorAll('a[href]')).forEach(a => {
      const m = (a.getAttribute('href') || '').match(/configurations\/(\d+)/);
      if (m && !seen[m[1]]) {
        seen[m[1]] = true;
        // The row this link sits in usually carries the tenant name.
        const tr = a.closest('tr');
        ids.push({ deptId: m[1], linkText: txt(a), rowText: tr ? txt(tr) : '' });
      }
    });
    return ids;
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
      const r = await getParsed(ADMIN_BASE + '/configurations/' + encodeURIComponent(id));
      // Keep the tables (that is where bundles live) but drop nothing silently.
      out.results.push({
        deptId: id,
        tenantHint: (item && (item.rowText || item.linkText)) || null,
        meta: r.meta,
        tableSummary: (r.tables || []).map(t => ({ index: t.index, heading: t.heading, headers: t.headers, rowCount: t.rowCount })),
        tables: r.tables,
        json: r.json
      });
      if (delayMs) await new Promise(res => setTimeout(res, delayMs));
    }
    const empties = out.results.filter(x => !x.tables || !x.tables.length).length;
    out.notes.push(out.results.length + ' department(s) read; ' + empties + ' returned no table at all.');
    return out;
  }

  // ---- entry points ------------------------------------------------------
  async function runList() {
    const o = await listDepartments();
    dl('usx_admin_departments_' + location.hostname + '_' + nowStamp() + '.json', o);
    return o;
  }

  // ONE CLICK = LIST + SWEEP. The operator should not be navigating per tenant;
  // the loop is the probe's job.
  async function runScan(opts) {
    opts = opts || {};
    const listing = await listDepartments();
    const ids = listing.deptIds || [];
    const o = await scanConfigurations(ids, opts);
    o.listing = {
      deptIdCount: listing.deptIdCount,
      tableSummary: listing.tableSummary,
      notes: listing.notes
    };
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
          tables: extractTables(document), json: null
        }],
        notes: ['READ-ONLY. Read from the LIVE DOM of the page you are on.']
      };
      o.results[0].tableSummary = o.results[0].tables.map(t => ({ index: t.index, heading: t.heading, headers: t.headers, rowCount: t.rowCount }));
    } else {
      o = await scanConfigurations([deptId], { limit: 1, delayMs: 0 });
    }
    dl('usx_admin_one_' + deptId + '_' + nowStamp() + '.json', o);
    return o;
  }

  window.__usxAdminProbe = { runList, runScan, runOne, listDepartments, scanConfigurations, extractTables, extractDeptIds, ADMIN_BASE };
  console.log('[USx-ADMIN] admin_probe v2 loaded -- HTML/DOM table extraction (v1 truncated at 20KB and lost the table). READ-ONLY, GET only. BUILD 2026-09-10b.');
})();
