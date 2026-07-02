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

  function build(kind) {
    const p = el('div');
    p.id = 'usx-panel'; p.dataset.kind = kind;
    p.style.cssText = 'position:fixed;z-index:2147483647;top:12px;left:12px;background:#141414;color:#eee;font:12px/1.4 system-ui;padding:9px 11px;border-radius:9px;box-shadow:0 6px 22px rgba(0,0,0,.5);width:230px;opacity:.94';
    const head = el('div', 'display:flex;justify-content:space-between;align-items:center;font-weight:700;margin-bottom:6px');
    head.appendChild(el('span', null, kind === 'dex' ? 'USx Capture — dex-log' : 'USx Driver'));
    const hide = el('span', 'cursor:pointer;color:#888', '✕'); hide.title = 'hide'; hide.onclick = () => p.remove();
    head.appendChild(hide); p.appendChild(head);

    if (kind === 'dex') {
      // Two plain-language status lines.
      const batchStatus = el('div', 'font:11px system-ui;color:#fa0;margin:2px 0;min-height:14px'); batchStatus.id = 'usx-batch-status'; p.appendChild(batchStatus);
      const cnt = el('div', 'margin-bottom:8px;color:#7cf', 'Captured so far: 0'); cnt.id = 'usx-cnt'; p.appendChild(cnt);

      // PRIMARY action — the normal post-Run-Plan loop (scope to today + the queued batch).
      const fetchBatch = el('button', BTN, '⚡ Fetch results');
      fetchBatch.onclick = () => {
        let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_batch') || '[]').length; } catch(e) {}
        const today = new Date().toISOString().slice(0,10);
        const o = { maxPages: 3, since: today }; if (n > 0) o.maxNew = n;
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
      bulk.onclick = () => { const o = { maxPages: parseInt(document.getElementById('usx-pages').value) || 1 }; const s = document.getElementById('usx-since').value.trim(); if (s) o.since = s; window.__usxBulkFetch(o); };
      more.appendChild(bulk);

      more.appendChild(el('div', 'border-top:1px solid #333;margin:8px 0 4px'));

      // Click-capture fallback — for when the API fetch returns nothing.
      more.appendChild(el('div', 'color:#aaa;font-size:11px;margin-bottom:2px', 'Click-capture (if fetch finds nothing)'));
      const rawWrap = el('label', 'display:block;margin:2px 0;color:#ccc');
      const raw = el('input'); raw.type = 'checkbox'; raw.id = 'usx-raw'; raw.checked = true;
      rawWrap.appendChild(raw); rawWrap.appendChild(document.createTextNode(' Recover existing entries too')); more.appendChild(rawWrap);
      const w = el('button', BTN + ';' + BLU, '▶ Start click-capture'); w.id = 'usx-watch';
      w.onclick = () => { if (window.__usxWatchTimer) { window.__usxCaptureWatchStop(); } else { window.__usxCaptureWatch(document.getElementById('usx-raw').checked); } };
      more.appendChild(w);
      const s = el('button', BTN + ';' + BLU, '⬇ Stop & download'); s.onclick = () => window.__usxCaptureWatchStop(); more.appendChild(s);
      const o = el('button', BTN + ';' + BLU, 'Capture open popup'); o.onclick = () => window.__usxCaptureOpen(); more.appendChild(o);
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
      repoBtn.onclick = async () => {
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
      run.onclick = async () => {
        const plan = window.__usxLoadedPlan;
        if (!plan) { alert('Load a TEST_PLAN JSON file first (📂 button above).'); return; }
        if (typeof window.__usxRunPlan !== 'function') { alert('__usxRunPlan not found — make sure the extension loaded on this page (reload).'); return; }
        const entity = (document.getElementById('usx-ent').value || '').trim();
        const tests = (plan.tests || []).filter(t => (t.kind === 'combo' || t.kind === 'any' || t.kind === 'any-field' || t.kind === 'guardrail') && (!entity || t.entity === entity));
        if (!tests.length) { alert('No submittable tests found for entity "' + entity + '". Check the entity name (case-sensitive, e.g. Vehicle).'); return; }
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
      scopeBtn.onclick = async () => {
        const entity = (document.getElementById('usx-ent').value || '').trim();
        if (!entity) { alert('Load the plan first (entity list comes from it), render the entity form, then click.'); return; }
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
