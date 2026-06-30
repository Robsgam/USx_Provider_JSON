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
    head.appendChild(el('span', null, 'USx ' + (kind === 'dex' ? 'Capture' : 'Driver')));
    const hide = el('span', 'cursor:pointer;color:#888', '✕'); hide.title = 'hide'; hide.onclick = () => p.remove();
    head.appendChild(hide); p.appendChild(head);

    if (kind === 'dex') {
      const cnt = el('div', 'margin-bottom:6px;color:#7cf', 'captured: 0'); cnt.id = 'usx-cnt'; p.appendChild(cnt);
      const batchStatus = el('div', 'font:11px system-ui;color:#fa0;margin:2px 0;min-height:14px'); batchStatus.id = 'usx-batch-status'; p.appendChild(batchStatus);
      const fetchBatch = el('button', BTN, '⚡ Fetch batch');
      fetchBatch.onclick = () => {
        let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_batch') || '[]').length; } catch(e) {}
        const today = new Date().toISOString().slice(0,10);
        const o = { maxPages: 3, since: today }; if (n > 0) o.maxNew = n;
        window.__usxBulkFetch(o);
      };
      p.appendChild(fetchBatch);
      // Manual override
      const bulkWrap = el('div', 'margin:4px 0;color:#ccc');
      const pages = el('input', 'width:42px'); pages.id = 'usx-pages'; pages.type = 'number'; pages.value = '1'; pages.title = 'list pages (~20 queries each)';
      const since = el('input', 'width:104px;margin-left:4px;box-sizing:border-box'); since.id = 'usx-since'; since.value = new Date().toISOString().slice(0,10); since.placeholder = 'since YYYY-MM-DD';
      bulkWrap.appendChild(document.createTextNode('pages ')); bulkWrap.appendChild(pages); bulkWrap.appendChild(since);
      p.appendChild(bulkWrap);
      const bulk = el('button', BTN, '⚡ Bulk fetch (API, no clicks)');
      bulk.onclick = () => { const o = { maxPages: parseInt(document.getElementById('usx-pages').value) || 1 }; const s = document.getElementById('usx-since').value.trim(); if (s) o.since = s; window.__usxBulkFetch(o); };
      p.appendChild(bulk);
      p.appendChild(el('div', 'border-top:1px solid #333;margin:6px 0'));
      const rawWrap = el('label', 'display:block;margin:2px 0;color:#ccc');
      const raw = el('input'); raw.type = 'checkbox'; raw.id = 'usx-raw'; raw.checked = true;
      rawWrap.appendChild(raw); rawWrap.appendChild(document.createTextNode(' raw (recover existing entries)')); p.appendChild(rawWrap);
      const w = el('button', BTN, '▶ Start Watch'); w.id = 'usx-watch';
      w.onclick = () => { if (window.__usxWatchTimer) { window.__usxCaptureWatchStop(); } else { window.__usxCaptureWatch(document.getElementById('usx-raw').checked); } };
      p.appendChild(w);
      const s = el('button', BTN + ';' + BLU, '⬇ Stop & Save'); s.onclick = () => window.__usxCaptureWatchStop(); p.appendChild(s);
      const o = el('button', BTN + ';' + BLU, 'Capture open popup'); o.onclick = () => window.__usxCaptureOpen(); p.appendChild(o);
      const r = el('button', BTN + ';' + RED, '✕ Reset captures'); r.onclick = () => window.__usxCaptureWatchReset(); p.appendChild(r);
      p.appendChild(el('div', 'margin-top:6px;color:#999;font-size:11px', 'Watch on, then click each "View request and return". Page through freely.'));
    } else {
      // File picker — primary UX
      const fileRow = el('div', 'margin:4px 0');
      const fileLbl = el('label', 'display:block;padding:6px;border:1px dashed #555;border-radius:5px;color:#aaa;font:11px system-ui;cursor:pointer;text-align:center', '📂 Load TEST_PLAN JSON…');
      const fileIn = el('input'); fileIn.type = 'file'; fileIn.accept = '.json'; fileIn.style.cssText = 'display:none';
      fileLbl.appendChild(fileIn);
      fileRow.appendChild(fileLbl);
      p.appendChild(fileRow);
      // Status line shows loaded plan info
      const planStatus = el('div', 'font:11px system-ui;color:#7cf;margin:2px 0;min-height:14px'); planStatus.id = 'usx-plan-status'; p.appendChild(planStatus);
      // Hidden store for loaded plan
      let _loadedPlan = null;
      fileIn.onchange = () => {
        const f = fileIn.files[0]; if (!f) return;
        const r = new FileReader();
        r.onload = (ev) => {
          try {
            _loadedPlan = JSON.parse(ev.target.result);
            const tests = _loadedPlan.tests || _loadedPlan;
            const count = Array.isArray(tests) ? tests.length : '?';
            const entities = Array.isArray(tests) ? [...new Set(tests.map(t => t.entity).filter(Boolean))] : [];
            planStatus.textContent = `✔ ${f.name.replace(/^.*[/\\]/,'')} — ${count} tests`;
            const sel = document.getElementById('usx-ent'); sel.innerHTML = '';
            entities.forEach((e, i) => { const o = document.createElement('option'); o.value = e; o.textContent = e; if (i === 0) o.selected = true; sel.appendChild(o); });
            window.__usxLoadedPlan = _loadedPlan;
          } catch (e) { planStatus.style.color='#f77'; planStatus.textContent = '✖ parse error: ' + e.message; }
        };
        r.readAsText(f);
      };
      const ent = el('select', 'width:100%;margin:4px 0;padding:5px;box-sizing:border-box;background:#222;color:#eee;border:1px solid #555;border-radius:4px'); ent.id = 'usx-ent'; const entPlaceholder = document.createElement('option'); entPlaceholder.value = ''; entPlaceholder.textContent = '— load plan first —'; entPlaceholder.disabled = true; entPlaceholder.selected = true; ent.appendChild(entPlaceholder); p.appendChild(ent);
      const runStatus = el('div', 'font:11px system-ui;color:#fa0;margin:2px 0;min-height:14px'); runStatus.id = 'usx-run-status'; p.appendChild(runStatus);
      const run = el('button', BTN, '▶ Run Plan');
      run.onclick = async () => {
        const plan = window.__usxLoadedPlan;
        if (!plan) { alert('Load a TEST_PLAN JSON file first (📂 button above).'); return; }
        if (typeof window.__usxRunPlan !== 'function') { alert('__usxRunPlan not found — make sure the extension loaded on this page (reload).'); return; }
        const entity = (document.getElementById('usx-ent').value || '').trim();
        const tests = (plan.tests || []).filter(t => (t.kind === 'combo' || t.kind === 'any') && (!entity || t.entity === entity));
        if (!tests.length) { alert('No combo tests found for entity "' + entity + '". Check the entity name (case-sensitive, e.g. Vehicle).'); return; }
        runStatus.style.color = '#fa0'; runStatus.textContent = `Running ${tests.length} combos for ${entity || 'all'}…`;
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
      p.appendChild(el('div', 'margin-top:6px;color:#999;font-size:11px', '0. Run tools\\watch_captures.ps1 once  1. Load plan  2. Pick entity  3. Run Plan  4. Fetch batch'));
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
      if (c) { let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_captured') || '[]').length; } catch (e) {} c.textContent = 'captured: ' + n; }
      const bs = document.getElementById('usx-batch-status');
      if (bs) { let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_batch') || '[]').length; } catch(e) {} bs.textContent = n > 0 ? 'batch: ' + n + ' submitted' : ''; }
      const w = document.getElementById('usx-watch');
      if (w) w.textContent = window.__usxWatchTimer ? '⏹ Watching… (click to stop)' : '▶ Start Watch';
    }
  }

  window.__usxUiTimer = setInterval(tick, 1000);
  tick();
  console.log('%c[USx-UI]', 'color:#fa0;font-weight:bold', 'control panel injected.');
})();
