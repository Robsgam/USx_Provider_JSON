// ===========================================================================
//  USx Tenant Testing automation -- on-screen control panel (ui.js)
//  Injects a small floating panel so you drive everything with buttons instead
//  of console commands. Adapts per page (dex-log = capture; universal-search =
//  driver) and re-mounts on SPA hash changes. Calls the window.__usx* functions
//  defined by capture.js / driver.js (loaded before this).
// ===========================================================================
(() => {
  if (window.__usxUiTimer) return;

  function el(tag, css, txt) { const e = document.createElement(tag); if (css) e.style.cssText = css; if (txt != null) e.textContent = txt; return e; }
  const BTN = 'display:block;margin:4px 0;width:100%;padding:6px;border:0;border-radius:5px;color:#fff;cursor:pointer;font:12px system-ui;background:#2a8a55';
  const BLU = 'background:#3a66c0'; const RED = 'background:#a33';

  // ── ARM SWITCH (v0.5.0) ────────────────────────────────────────────────────────────────────
  // WHY THIS EXISTS. Until v0.4.0 the manifest enumerated eight usx-*.mark43.com hosts, so the
  // extension COULD NOT act anywhere else -- the allowlist was the safety. v0.5.0 widened to
  // *.mark43.com (Rob: "open up access to all tenants with the tail end of the url") on the same
  // day production started existing: CA_CLETS went live at Mariposa 2026-08-13. So this script now
  // loads on customer sites where real officers run real CJIS queries, and something has to stop
  // a reflex click from driving 41 test queries into one.
  //
  // The rule: DISARMED BY DEFAULT, per hostname, and every action refuses while disarmed. The
  // switch is not decoration -- requireArmed() gates the handlers, so disabling the styling alone
  // would not be enough to fire anything.
  const armKey = () => '__usx_armed_' + location.hostname;
  function isArmed() { try { return localStorage.getItem(armKey()) === '1'; } catch (e) { return false; } }
  function setArmed(v) { try { v ? localStorage.setItem(armKey(), '1') : localStorage.removeItem(armKey()); } catch (e) {} }
  const isTestTenant = () => (window.__usxLib && window.__usxLib.isProviderTestTenant) ? window.__usxLib.isProviderTestTenant() : false;
  // NO BROWSER DIALOGS. The first version of this used alert()/confirm(), and that made the
  // safety control unusable: Chrome shows "Prevent this page from creating additional dialogs"
  // after a few alerts, and once ticked confirm() returns FALSE silently -- so the arm button
  // did nothing, with the panel still reading DISARMED and no way to turn it on (Rob,
  // 2026-08-13: "the tool says disarmed and there was no way to turn the extenion on or off").
  // A control whose only feedback path can be switched off by the browser is not a control.
  // Everything now renders IN the panel.
  function flash(msg, color) {
    const s = document.getElementById('usx-arm-msg');
    if (s) { s.style.color = color || '#f77'; s.textContent = msg; }
    else console.log('%c[USx-UI]', 'color:#fa0;font-weight:bold', msg);
  }
  function requireArmed() {
    if (isArmed()) return true;
    flash('DISARMED — click the switch above to arm this tenant first.', '#f77');
    return false;
  }

  // Header block: hostname, tenant class, provider, and the arm toggle. Built for every panel kind.
  function buildArmBlock(p) {
    const testT = isTestTenant();
    const wrap = el('div', 'margin:0 0 8px;padding:6px;border-radius:6px;background:' + (testT ? '#1c2a1c' : '#3a1f1f') + ';border:1px solid ' + (testT ? '#2a8a55' : '#a33'));
    wrap.appendChild(el('div', 'font:11px/1.3 system-ui;color:#ccc;word-break:break-all', location.hostname));
    wrap.appendChild(el('div', 'font:10px system-ui;color:' + (testT ? '#7c7' : '#f99') + ';margin-top:2px',
      testT ? 'provider TEST tenant' : '⚠ NOT a test tenant — Foundation or LIVE (customer site)'));

    // Provider line. On a non-usx host nothing in the hostname names the provider, so the operator
    // sets it; it persists per hostname and is what the plan fetch and capture filenames use.
    const provRow = el('div', 'margin-top:4px');
    const provNow = () => (window.__usxLib ? window.__usxLib.providerFromHost() : 'UNKNOWN');
    const provLbl = el('div', 'font:10px system-ui;color:#9cf', 'provider: ' + provNow());
    provRow.appendChild(provLbl);
    if (!testT) {
      const pi = el('input', 'width:100%;margin-top:3px;padding:3px;box-sizing:border-box;background:#222;color:#eee;border:1px solid #555;border-radius:4px;font:11px system-ui');
      pi.placeholder = 'provider for this tenant, e.g. HI_HCJDC_OFML';
      try { pi.value = localStorage.getItem(window.__usxLib.providerOverrideKey()) || ''; } catch (e) {}
      pi.onchange = () => {
        try {
          const v = pi.value.trim();
          if (v) localStorage.setItem(window.__usxLib.providerOverrideKey(), v);
          else localStorage.removeItem(window.__usxLib.providerOverrideKey());
        } catch (e) {}
        provLbl.textContent = 'provider: ' + provNow();
      };
      provRow.appendChild(pi);
    }
    wrap.appendChild(provRow);

    // The switch. Big, unmissable, and NO browser dialog anywhere in its path.
    const t = el('button', 'display:block;margin:8px 0 0;width:100%;padding:9px;border:0;border-radius:6px;color:#fff;cursor:pointer;font:700 13px system-ui');
    const msg = el('div', 'font:10px/1.3 system-ui;margin-top:4px;min-height:13px;color:#f77'); msg.id = 'usx-arm-msg';
    let pendingConfirm = false;
    function paint() {
      const on = isArmed();
      if (pendingConfirm) {
        t.textContent = '⚠ CLICK AGAIN TO ARM';
        t.style.background = '#c60';
      } else {
        t.textContent = on ? 'ARMED ✓  (click to disarm)' : 'DISARMED  (click to ARM)';
        t.style.background = on ? '#2a8a55' : '#666';
      }
    }
    t.onclick = () => {
      if (isArmed()) { setArmed(false); pendingConfirm = false; msg.textContent = ''; paint(); return; }
      // Arming a customer site takes two clicks -- an IN-PANEL confirm, not a browser confirm().
      if (!isTestTenant() && !pendingConfirm) {
        pendingConfirm = true;
        msg.style.color = '#fc0';
        msg.textContent = 'NOT a test tenant. Queries here hit a customer site. Click again to confirm.';
        paint();
        setTimeout(() => { if (pendingConfirm) { pendingConfirm = false; msg.textContent = ''; paint(); } }, 6000);
        return;
      }
      setArmed(true); pendingConfirm = false;
      msg.style.color = '#7c7'; msg.textContent = 'Armed for ' + location.hostname;
      paint();
    };
    paint();
    wrap.appendChild(t);
    wrap.appendChild(msg);
    p.appendChild(wrap);
  }

  function build(kind) {
    const p = el('div');
    p.id = 'usx-panel'; p.dataset.kind = kind;
    p.style.cssText = 'position:fixed;z-index:2147483647;top:12px;left:12px;background:#141414;color:#eee;font:12px/1.4 system-ui;padding:9px 11px;border-radius:9px;box-shadow:0 6px 22px rgba(0,0,0,.5);width:230px;opacity:.94';
    const head = el('div', 'display:flex;justify-content:space-between;align-items:center;font-weight:700;margin-bottom:6px');
    head.appendChild(el('span', null, kind === 'dex' ? 'USx Capture — dex-log' : 'USx Driver'));
    const hide = el('span', 'cursor:pointer;color:#888', '✕'); hide.title = 'hide'; hide.onclick = () => p.remove();
    head.appendChild(hide); p.appendChild(head);
    buildArmBlock(p);

    if (kind === 'dex') {
      // Two plain-language status lines.
      const batchStatus = el('div', 'font:11px system-ui;color:#fa0;margin:2px 0;min-height:14px'); batchStatus.id = 'usx-batch-status'; p.appendChild(batchStatus);
      const cnt = el('div', 'margin-bottom:8px;color:#7cf', 'Captured so far: 0'); cnt.id = 'usx-cnt'; p.appendChild(cnt);

      // PRIMARY action — the normal post-Run-Plan loop (scope to today + the queued batch).
      const fetchBatch = el('button', BTN, '⚡ Fetch results');
      fetchBatch.onclick = () => { if (!requireArmed()) return;
        let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_batch') || '[]').length; } catch(e) {}
        const today = new Date().toISOString().slice(0,10);
        // maxPages 10: every query creates TWO rows (ConnectCic + RMS), so a 47-test run
        // spans ~94 rows -- 3 pages (60) dropped the run's first submissions (2026-07-02).
        const o = { maxPages: 10, since: today }; if (n > 0) o.maxNew = n;
        window.__usxBulkFetch(o);
      };
      p.appendChild(fetchBatch);

      // Everything else is a fallback — tucked under a disclosure so the default view stays clean.
      const more = el('details', 'margin-top:6px');
      const sum = el('summary', 'cursor:pointer;color:#9cf;font:12px system-ui;list-style:none;user-select:none;padding:2px 0', 'More capture options'); more.appendChild(sum);

      // Custom range — same API fetch, manual pages/since.
      more.appendChild(el('div', 'color:#aaa;font-size:11px;margin:6px 0 2px', 'Custom range'));
      const bulkWrap = el('div', 'margin:2px 0;color:#ccc');
      const pages = el('input', 'width:42px'); pages.id = 'usx-pages'; pages.type = 'number'; pages.value = '1'; pages.title = 'list pages (~20 queries each)';
      const since = el('input', 'width:104px;margin-left:4px;box-sizing:border-box'); since.id = 'usx-since'; since.value = new Date().toISOString().slice(0,10); since.placeholder = 'since YYYY-MM-DD';
      bulkWrap.appendChild(document.createTextNode('pages ')); bulkWrap.appendChild(pages); bulkWrap.appendChild(since);
      more.appendChild(bulkWrap);
      const bulk = el('button', BTN + ';' + BLU, 'Fetch custom range');
      bulk.onclick = () => { if (!requireArmed()) return; const o = { maxPages: parseInt(document.getElementById('usx-pages').value) || 1 }; const s = document.getElementById('usx-since').value.trim(); if (s) o.since = s; window.__usxBulkFetch(o); };
      more.appendChild(bulk);

      more.appendChild(el('div', 'border-top:1px solid #333;margin:8px 0 4px'));

      // Click-capture fallback — for when the API fetch returns nothing.
      more.appendChild(el('div', 'color:#aaa;font-size:11px;margin-bottom:2px', 'Click-capture (if fetch finds nothing)'));
      const rawWrap = el('label', 'display:block;margin:2px 0;color:#ccc');
      const raw = el('input'); raw.type = 'checkbox'; raw.id = 'usx-raw'; raw.checked = true;
      rawWrap.appendChild(raw); rawWrap.appendChild(document.createTextNode(' Recover existing entries too')); more.appendChild(rawWrap);
      const w = el('button', BTN + ';' + BLU, '▶ Start click-capture'); w.id = 'usx-watch';
      w.onclick = () => { if (!requireArmed()) return; if (window.__usxWatchTimer) { window.__usxCaptureWatchStop(); } else { window.__usxCaptureWatch(document.getElementById('usx-raw').checked); } };
      more.appendChild(w);
      const s = el('button', BTN + ';' + BLU, '⬇ Stop & download'); s.onclick = () => { if (!requireArmed()) return; window.__usxCaptureWatchStop(); }; more.appendChild(s);
      const o = el('button', BTN + ';' + BLU, 'Capture open popup'); o.onclick = () => { if (!requireArmed()) return; window.__usxCaptureOpen(); }; more.appendChild(o);
      more.appendChild(el('div', 'color:#999;font-size:11px;margin:4px 0', 'Turn on, then click each row\'s "View request and return". Page through freely.'));

      more.appendChild(el('div', 'border-top:1px solid #333;margin:8px 0 4px'));
      const r = el('button', BTN + ';' + RED, '✕ Clear captured'); r.onclick = () => window.__usxCaptureWatchReset(); more.appendChild(r);
      p.appendChild(more);

      p.appendChild(el('div', 'margin-top:8px;color:#999;font-size:11px', 'After Run Plan on universal-search, click ⚡ Fetch results — a JSON downloads; import with tools\\import_captured_tests.ps1.'));
    } else {
      // Status line shows loaded plan info (declared first -- both load paths write to it)
      const planStatus = el('div', 'font:11px system-ui;color:#7cf;margin:2px 0;min-height:14px'); planStatus.id = 'usx-plan-status';

      // Shared plan-apply for both the repo fetch and the manual file picker.
      function applyPlan(planObj, sourceName) {
        const tests = planObj.tests || planObj;
        const count = Array.isArray(tests) ? tests.length : '?';
        const entities = Array.isArray(tests) ? [...new Set(tests.map(t => t.entity).filter(Boolean))] : [];
        planStatus.style.color = '#7cf';
        planStatus.textContent = `✔ ${sourceName} — ${count} tests`;
        const sel = document.getElementById('usx-ent'); sel.innerHTML = '';
        entities.forEach((e, i) => { const o = document.createElement('option'); o.value = e; o.textContent = e; if (i === 0) o.selected = true; sel.appendChild(o); });
        window.__usxLoadedPlan = planObj;
      }

      // PRIMARY: load the repo's current plan from the local plan server (tools/serve_plans.ps1,
      // http://localhost:8477 -- localhost is exempt from mixed-content blocking). Provider is
      // derived from the tenant hostname, so one button works on every tenant.
      const prov = window.__usxLib ? window.__usxLib.providerFromHost() : 'UNKNOWN';
      const repoBtn = el('button', BTN, '⟳ Load plan from repo');
      repoBtn.onclick = async () => { if (!requireArmed()) return;
        planStatus.style.color = '#fa0'; planStatus.textContent = `fetching plan for ${prov}…`;
        try {
          const r = await fetch(`http://localhost:8477/plan/${prov}`);
          if (!r.ok) throw new Error((await r.json()).error || r.status);
          const planObj = await r.json();
          applyPlan(planObj, `repo plan ${prov} v${planObj.version || '?'}`);
        } catch (e) {
          planStatus.style.color = '#f77';
          planStatus.textContent = `✖ repo load failed (${e.message}) — is tools\\serve_plans.ps1 running? Use 📂 below.`;
        }
      };
      p.appendChild(repoBtn);

      // Manual file picker — kept for testing / one-off plans.
      const fileRow = el('div', 'margin:4px 0');
      const fileLbl = el('label', 'display:block;padding:6px;border:1px dashed #555;border-radius:5px;color:#aaa;font:11px system-ui;cursor:pointer;text-align:center', '📂 Load TEST_PLAN JSON (manual)…');
      const fileIn = el('input'); fileIn.type = 'file'; fileIn.accept = '.json'; fileIn.style.cssText = 'display:none';
      fileLbl.appendChild(fileIn);
      fileRow.appendChild(fileLbl);
      p.appendChild(fileRow);
      p.appendChild(planStatus);
      fileIn.onchange = () => {
        const f = fileIn.files[0]; if (!f) return;
        const r = new FileReader();
        r.onload = (ev) => {
          try { applyPlan(JSON.parse(ev.target.result), f.name.replace(/^.*[/\\]/,'')); }
          catch (e) { planStatus.style.color='#f77'; planStatus.textContent = '✖ parse error: ' + e.message; }
        };
        r.readAsText(f);
      };
      // Run ALL (auto entity switching) PARKED 2026-07-02 by user decision -- "we are
      // trying too much"; the proven flow is semi-automatic: pick entity, Run Plan, repeat,
      // one Fetch at the end. __usxRunAll stays available from the console for later.
      const ent = el('select', 'width:100%;margin:4px 0;padding:5px;box-sizing:border-box;background:#222;color:#eee;border:1px solid #555;border-radius:4px'); ent.id = 'usx-ent'; const entPlaceholder = document.createElement('option'); entPlaceholder.value = ''; entPlaceholder.textContent = '— load plan first —'; entPlaceholder.disabled = true; entPlaceholder.selected = true; ent.appendChild(entPlaceholder); p.appendChild(ent);
      const runStatus = el('div', 'font:11px system-ui;color:#fa0;margin:2px 0;min-height:14px'); runStatus.id = 'usx-run-status'; p.appendChild(runStatus);
      const run = el('button', BTN, '▶ Run Plan');
      run.onclick = async () => { if (!requireArmed()) return;
        const plan = window.__usxLoadedPlan;
        if (!plan) { flash('Load a TEST_PLAN JSON file first (📂 button above).'); return; }
        if (typeof window.__usxRunPlan !== 'function') { flash('__usxRunPlan not found — make sure the extension loaded on this page (reload).'); return; }
        const entity = (document.getElementById('usx-ent').value || '').trim();
        const tests = (plan.tests || []).filter(t => (t.kind === 'combo' || t.kind === 'any' || t.kind === 'any-field' || t.kind === 'guardrail') && (!entity || t.entity === entity));
        if (!tests.length) { flash('No submittable tests found for entity "' + entity + '". Check the entity name (case-sensitive, e.g. Vehicle).'); return; }
        // Wrong-form guard: an entity run on the WRONG rendered form burns every test
        // ("Firearm" ran on the Article form, all six NOT submitted, 2026-07-02). Probe the
        // entity's first fill field before starting.
        const firstFill = tests.map(t => Array.isArray(t.fills) ? t.fills[0] : t.fills).find(f => f && f.fieldId);
        if (firstFill && !document.querySelector('#' + CSS.escape(firstFill.fieldId))) {
          flash('The ' + (entity || 'selected') + ' form is not on screen (field "' + firstFill.fieldId + '" not found). Click the ' + entity + ' entity tab first, then Run Plan.');
          return;
        }
        runStatus.style.color = '#fa0'; runStatus.textContent = `Running ${tests.length} tests for ${entity || 'all'}…`;
        run.disabled = true;
        try {
          const results = await window.__usxRunPlan(plan, entity || undefined);
          const ok = results ? results.filter(r => r.sent && r.sent.ok).length : 0;
          runStatus.style.color = '#7cf'; runStatus.textContent = `Done: ${ok}/${tests.length} submitted. Go to dex-log → Bulk Fetch.`;
        } catch (e) {
          runStatus.style.color = '#f77'; runStatus.textContent = 'Error: ' + e.message;
        } finally { run.disabled = false; }
      };
      p.appendChild(run);

      // Picklist scope — fetches the repo scope and dumps the CURRENT entity's dropdown
      // options (render the entity form, pick it in the dropdown above, click).
      const scopeBtn = el('button', BTN + ';' + BLU, '🔍 Scope picklists (current entity)');
      const scopeStatus = el('div', 'font:11px system-ui;color:#fa0;margin:2px 0;min-height:14px');
      scopeBtn.onclick = async () => { if (!requireArmed()) return;
        const entity = (document.getElementById('usx-ent').value || '').trim();
        if (!entity) { flash('Load the plan first (entity list comes from it), render the entity form, then click.'); return; }
        scopeStatus.textContent = `scoping ${entity}…`;
        try {
          if (!window.__usxLoadedScope) {
            const r = await fetch(`http://localhost:8477/scope/${prov}`);
            if (!r.ok) throw new Error((await r.json()).error || r.status);
            window.__usxLoadedScope = await r.json();
          }
          const res = await window.__usxScopePicklists(window.__usxLoadedScope, entity);
          scopeStatus.style.color = '#7cf';
          scopeStatus.textContent = res ? `✔ ${entity}: ${res.fields.length} dropdown(s) dumped + downloaded` : `no selects for ${entity}`;
        } catch (e) { scopeStatus.style.color = '#f77'; scopeStatus.textContent = '✖ ' + e.message; }
      };
      p.appendChild(scopeBtn);
      p.appendChild(scopeStatus);

      p.appendChild(el('div', 'margin-top:6px;color:#999;font-size:11px', '0. Run tools\\watch_captures.ps1 + tools\\serve_plans.ps1 once  1. ⟳ Load plan  2. Pick entity  3. Run Plan (or 🔍 Scope)  4. Fetch results'));
    }
    return p;
  }

  function tick() {
    const isDex = location.hash.includes('dex-log');
    const isSearch = location.hash.includes('universal-search');
    const want = isDex ? 'dex' : (isSearch ? 'search' : null);
    let p = document.getElementById('usx-panel');
    if (!want) { if (p) p.remove(); return; }
    if (p && p.dataset.kind !== want) { p.remove(); p = null; }
    if (!p && document.body) document.body.appendChild(build(want));
    if (want === 'dex') {
      const c = document.getElementById('usx-cnt');
      if (c) { let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_captured') || '[]').length; } catch (e) {} c.textContent = 'Captured so far: ' + n; }
      const bs = document.getElementById('usx-batch-status');
      if (bs) { let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_batch') || '[]').length; } catch(e) {} bs.textContent = n > 0 ? 'Queued from Run Plan: ' + n : ''; }
      const w = document.getElementById('usx-watch');
      if (w) w.textContent = window.__usxWatchTimer ? '⏹ Click-capturing… (click to stop)' : '▶ Start click-capture';
    }
  }

  window.__usxUiTimer = setInterval(tick, 1000);
  tick();
  console.log('%c[USx-UI]', 'color:#fa0;font-weight:bold', 'control panel injected.');
})();
