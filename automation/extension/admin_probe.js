// ===========================================================================
//  admin_probe.js -- READ-ONLY reconnaissance of the RMS support-admin
//  department / configuration endpoints.
//
//  WHY THIS EXISTS (Rob, 2026-09-10): "i want you to look at this page and see
//  if you can import/export or do anything else ... Can you use both of these
//  links and information and see if we can't get a list of active tenant that
//  have a json imported".
//
//  I CANNOT REACH THOSE URLS AND THAT WAS MEASURED, NOT ASSUMED.
//  GET https://demo.mark43.com/rms/api/support/admin/departments returns
//  303 See Other -> /rms/login/. They are session-authenticated, so only the
//  operator's own browser can read them. That is what forces this to be an
//  extension probe rather than a repo-side tool.
//
//  WHAT IT CLOSES. providers/IMPORT_LEDGER.md section B is MAINTAINED BY HAND:
//  "the capture tool can't reach them, so their versions are recorded manually
//  in the ledger from actual import reports only." An authenticated read of the
//  admin endpoints is the first thing that could make that section DERIVED
//  instead of remembered.
//
//  ⚠️ THIS FIRST PASS IS RECON AND DELIBERATELY ASSUMES NOTHING ABOUT SHAPE.
//  I do not know whether these endpoints return JSON or HTML, nor the key names
//  for department id / name / bundles. Guessing field names is how a probe
//  reports a confident wrong answer, so pass 1 RECORDS the raw response and
//  reports what it found; the enumerator gets hardened against a real sample.
//  Every extractor here is best-effort and labels itself as such.
//
//  READ-ONLY BY CONSTRUCTION: this file issues GET only. There is no POST, PUT,
//  PATCH or DELETE anywhere in it, and no import/upload path. Importing a JSON
//  into a tenant is an outward-facing change to someone's environment and is
//  NOT something a probe should be able to do as a side effect.
//
//  NOT ARM-GATED, following the authwatch precedent in ui.js: the ARM switch
//  exists because the driver SUBMITS REAL QUERIES on tenants that may be live.
//  This only reads. Requiring an arm would mean arming the query driver on a
//  customer site to answer an inventory question, which is the opposite of what
//  the switch is for. The captions say read-only so the difference is visible.
// ===========================================================================
(() => {
  if (window.__usxAdminProbe) return;

  const ADMIN_BASE = '/rms/api/support/admin/departments';

  const nowStamp = () => new Date().toISOString().replace(/[:.]/g, '-');

  function dl(filename, obj) {
    // Reuse the lib's proven download bridge rather than re-implementing it (a
    // second copy is how one of them silently rots). Fail loudly if absent.
    if (!window.__usxLib || !window.__usxLib.triggerDownload) {
      throw new Error('usx_lib not loaded -- reload the extension before running a probe');
    }
    return window.__usxLib.triggerDownload(filename, obj);
  }

  // ---- fetch that reports WHAT it got, never just the parsed guess ---------
  async function getRaw(url) {
    const res = await fetch(url, {
      method: 'GET',
      credentials: 'same-origin',
      headers: { 'Accept': 'application/json, text/html;q=0.9, */*;q=0.8' },
      redirect: 'follow'
    });
    const ct = res.headers.get('content-type') || '';
    const text = await res.text();
    let json = null, parseError = null;
    if (text && (ct.includes('json') || text.trim().startsWith('{') || text.trim().startsWith('['))) {
      try { json = JSON.parse(text); } catch (e) { parseError = String(e && e.message || e); }
    }
    return {
      url: url,
      status: res.status,
      ok: res.ok,
      redirected: res.redirected,
      finalUrl: res.url,
      contentType: ct,
      bytes: text ? text.length : 0,
      // A login redirect is the single most likely failure and must be OBVIOUS,
      // not inferred from an empty result later.
      looksLikeLogin: /\/login\/?$/.test(res.url || '') || /name=["']?password/i.test(text || ''),
      json: json,
      parseError: parseError,
      text: json ? null : (text || '').slice(0, 20000)   // keep HTML only when it did not parse
    };
  }

  // ---- shape reporting: describe, do not interpret -------------------------
  function describe(node, depth) {
    depth = depth || 0;
    if (node === null) return 'null';
    if (Array.isArray(node)) {
      return depth > 3 ? 'array[' + node.length + ']'
        : 'array[' + node.length + ']' + (node.length ? ' of ' + describe(node[0], depth + 1) : '');
    }
    const t = typeof node;
    if (t !== 'object') return t;
    const keys = Object.keys(node);
    if (depth > 3) return 'object{' + keys.length + ' keys}';
    const out = {};
    keys.slice(0, 40).forEach(k => { out[k] = describe(node[k], depth + 1); });
    return out;
  }

  // Find the array of records inside an unknown JSON envelope. Returns the
  // LONGEST array of objects found, plus the path -- and reports both so a
  // wrong pick is visible instead of silent.
  function findRecordArray(root) {
    let best = null;
    (function walk(n, path) {
      if (!n || typeof n !== 'object') return;
      if (Array.isArray(n)) {
        if (n.length && typeof n[0] === 'object' && n[0] !== null) {
          if (!best || n.length > best.rows.length) best = { path: path || '$', rows: n };
        }
        n.slice(0, 3).forEach((c, i) => walk(c, path + '[' + i + ']'));
        return;
      }
      Object.keys(n).forEach(k => walk(n[k], path ? path + '.' + k : k));
    })(root, '');
    return best;
  }

  // Best-effort (deptId, name) extraction. EVERY guess is labelled, and the
  // whole record is kept so a wrong key choice can be corrected from the file
  // without re-driving the browser.
  const ID_KEYS   = ['departmentId', 'deptId', 'id', 'departmentID', 'configurationId'];
  const NAME_KEYS = ['departmentName', 'name', 'displayName', 'deptName', 'agencyName', 'title'];

  function pick(rec, keys) {
    for (const k of keys) {
      if (rec && Object.prototype.hasOwnProperty.call(rec, k) && rec[k] !== null && rec[k] !== '') {
        return { key: k, value: rec[k] };
      }
    }
    // fall back to any key whose NAME looks right, so a novel schema still yields something
    if (rec) {
      for (const k of Object.keys(rec)) {
        if (/departmentid|deptid|^id$/i.test(k) && keys === ID_KEYS) return { key: k, value: rec[k], guessed: true };
        if (/name|agency|title/i.test(k) && keys === NAME_KEYS && typeof rec[k] === 'string') return { key: k, value: rec[k], guessed: true };
      }
    }
    return null;
  }

  // ---- STEP 1: the department list ----------------------------------------
  async function listDepartments() {
    const raw = await getRaw(ADMIN_BASE);
    const out = {
      probe: 'admin-departments',
      capturedAt: new Date().toISOString(),
      host: location.hostname,
      raw: raw,
      shape: raw.json ? describe(raw.json) : null,
      derived: null,
      notes: []
    };
    if (raw.looksLikeLogin) {
      out.notes.push('LOGIN REDIRECT -- the session is not authenticated for this host. Log in to the RMS UI in this tab first, then retry.');
      return out;
    }
    if (!raw.ok) { out.notes.push('HTTP ' + raw.status + ' -- endpoint did not return a result.'); return out; }

    if (raw.json) {
      const found = findRecordArray(raw.json);
      if (found) {
        out.derived = {
          recordPath: found.path,
          count: found.rows.length,
          idKeysSeen: {}, nameKeysSeen: {},
          rows: found.rows.map(r => {
            const id = pick(r, ID_KEYS), nm = pick(r, NAME_KEYS);
            if (id) out.derived.idKeysSeen[id.key] = (out.derived.idKeysSeen[id.key] || 0) + 1;
            if (nm) out.derived.nameKeysSeen[nm.key] = (out.derived.nameKeysSeen[nm.key] || 0) + 1;
            return {
              deptId: id ? id.value : null,
              deptIdKey: id ? id.key : null,
              name: nm ? nm.value : null,
              nameKey: nm ? nm.key : null,
              guessed: !!((id && id.guessed) || (nm && nm.guessed)),
              record: r      // FULL record kept -- the point of a recon pass
            };
          })
        };
        out.notes.push('Extraction is BEST-EFFORT. Cross-check derived.rows against derived.recordPath + the full records before trusting any count.');
      } else {
        out.notes.push('JSON parsed but no array of objects found -- see shape and fix the extractor.');
      }
    } else {
      out.notes.push('Response is NOT JSON (contentType=' + raw.contentType + '). First 20KB kept in raw.text so the real structure can be read.');
    }
    return out;
  }

  // ---- STEP 2: per-department configuration / bundles ---------------------
  // Bounded on purpose. A demo host may carry hundreds of departments and a
  // per-department fetch loop is the one part of this that could look like
  // hammering, so the caller MUST pass a limit and the default is small.
  async function scanConfigurations(deptIds, opts) {
    opts = opts || {};
    const limit = Math.max(1, Math.min(parseInt(opts.limit, 10) || 5, 500));
    const delayMs = Math.max(0, parseInt(opts.delayMs, 10) || 250);
    const ids = (deptIds || []).slice(0, limit);
    const out = {
      probe: 'admin-configurations',
      capturedAt: new Date().toISOString(),
      host: location.hostname,
      requested: ids.length,
      limitApplied: limit,
      results: [],
      notes: ['READ-ONLY: GET only, no import performed.']
    };
    for (const id of ids) {
      const raw = await getRaw(ADMIN_BASE + '/configurations/' + encodeURIComponent(id));
      const rec = { deptId: id, raw: raw, shape: raw.json ? describe(raw.json) : null, bundleGuess: null };
      if (raw.json) {
        const found = findRecordArray(raw.json);
        // Look for anything that smells like a bundle list WITHOUT asserting the key.
        const bundleKeys = [];
        (function walk(n, path) {
          if (!n || typeof n !== 'object') return;
          if (Array.isArray(n)) { n.slice(0, 3).forEach((c, i) => walk(c, path + '[' + i + ']')); return; }
          Object.keys(n).forEach(k => {
            if (/bundle|configuration|provider/i.test(k)) {
              bundleKeys.push({ path: path ? path + '.' + k : k, type: describe(n[k], 3) });
            }
            walk(n[k], path ? path + '.' + k : k);
          });
        })(raw.json, '');
        rec.bundleGuess = { recordPath: found ? found.path : null, recordCount: found ? found.rows.length : 0, keysMatchingBundle: bundleKeys.slice(0, 40) };
      }
      out.results.push(rec);
      if (delayMs) { await new Promise(r => setTimeout(r, delayMs)); }
    }
    return out;
  }

  // ---- entry points used by the panel buttons -----------------------------
  async function runList() {
    const o = await listDepartments();
    dl('usx_admin_departments_' + location.hostname + '_' + nowStamp() + '.json', o);
    return o;
  }

  async function runScan(opts) {
    opts = opts || {};
    let ids = opts.deptIds;
    let listing = null;
    if (!ids || !ids.length) {
      listing = await listDepartments();
      ids = (listing.derived && listing.derived.rows ? listing.derived.rows : [])
              .map(r => r.deptId).filter(v => v !== null && v !== undefined && v !== '');
    }
    const o = await scanConfigurations(ids, opts);
    o.listing = listing ? { count: listing.derived ? listing.derived.count : 0, notes: listing.notes } : null;
    dl('usx_admin_bundles_' + location.hostname + '_' + nowStamp() + '.json', o);
    return o;
  }

  // Single department -- for the exact URL Rob supplied, so the shape of ONE
  // known-good page can be read before any sweep is attempted.
  async function runOne(deptId) {
    const o = await scanConfigurations([deptId], { limit: 1, delayMs: 0 });
    dl('usx_admin_one_' + deptId + '_' + nowStamp() + '.json', o);
    return o;
  }

  window.__usxAdminProbe = { runList, runScan, runOne, listDepartments, scanConfigurations, ADMIN_BASE };
  console.log('[USx-ADMIN] admin_probe loaded. READ-ONLY (GET only, no import). BUILD 2026-09-10a. Use the "admin inventory" section of the USx panel.');
})();
