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
    p.style.cssText = 'position:fixed;z-index:2147483647;bottom:16px;right:16px;background:#141414;color:#eee;font:12px/1.4 system-ui;padding:10px 12px;border-radius:9px;box-shadow:0 6px 22px rgba(0,0,0,.5);width:248px;opacity:.96';
    const head = el('div', 'display:flex;justify-content:space-between;align-items:center;font-weight:700;margin-bottom:6px');
    head.appendChild(el('span', null, 'USx ' + (kind === 'dex' ? 'Capture' : 'Driver')));
    const hide = el('span', 'cursor:pointer;color:#888', '✕'); hide.title = 'hide'; hide.onclick = () => p.remove();
    head.appendChild(hide); p.appendChild(head);

    if (kind === 'dex') {
      const cnt = el('div', 'margin-bottom:6px;color:#7cf', 'captured: 0'); cnt.id = 'usx-cnt'; p.appendChild(cnt);
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
      const ta = el('textarea', 'width:100%;height:64px;font:11px monospace;box-sizing:border-box'); ta.id = 'usx-plan'; ta.placeholder = 'paste TEST_PLAN JSON'; p.appendChild(ta);
      const ent = el('input', 'width:100%;margin:4px 0;padding:5px;box-sizing:border-box'); ent.id = 'usx-ent'; ent.placeholder = 'entity (e.g. Vehicle)'; p.appendChild(ent);
      const run = el('button', BTN, '▶ Run Plan');
      run.onclick = () => { try { const plan = JSON.parse(document.getElementById('usx-plan').value); window.__usxRunPlan(plan, document.getElementById('usx-ent').value || undefined); } catch (e) { alert('bad plan JSON: ' + e); } };
      p.appendChild(run);
      p.appendChild(el('div', 'margin-top:6px;color:#999;font-size:11px', 'Render the entity form first. Fills + Send & Clear per combo.'));
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
      const w = document.getElementById('usx-watch');
      if (w) w.textContent = window.__usxWatchTimer ? '⏹ Watching… (click to stop)' : '▶ Start Watch';
    }
  }

  window.__usxUiTimer = setInterval(tick, 1000);
  tick();
  console.log('%c[USx-UI]', 'color:#fa0;font-weight:bold', 'control panel injected.');
})();
