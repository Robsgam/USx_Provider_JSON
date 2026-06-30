// ===========================================================================
//  USx Tenant Testing automation -- DRIVER (driver.js)
//  Runs on /universal-search. Fills a combo's fields (text + react-select),
//  which auto-checks the query checkbox + enables Send, then clicks Send.
//
//  It stashes the test context in localStorage so the capture page can attach
//  it to the request XML (same origin -> localStorage is shared across the two
//  RMS pages). One test at a time for now.
//
//  USAGE in the Console on /universal-search (entity form rendered):
//    __usxRunOne({
//      provider:L.providerFromHost(), entity:'Vehicle', query:'VehicleRegistrationQuery',
//      combo:'RQ+Plate', tier:'Preliminary', expectedKeyRef:'RQ',
//      fills:[{fieldId:'LicensePlateNumber', value:'TEST123'}]
//    })
//  Then open /admin/dex-log and run __usxCapture().
// ===========================================================================
(() => {
  const L = window.__usxLib;
  if (!L) { console.error('[USx-DRV] usx_lib not loaded'); return; }

  window.__usxRunOne = async function (desc) {
    if (!desc || !Array.isArray(desc.fills)) { console.error('[USx-DRV] need {fills:[...]}'); return; }
    const fillResults = [];
    for (const f of desc.fills) {
      const r = await L.fillField(f.fieldId, f.value);
      fillResults.push(r);
      await L.sleep(150);
    }
    await L.sleep(300);

    // Stash context for the capture page (minus huge data); newest wins.
    try {
      localStorage.setItem('__usx_pending', JSON.stringify({
        provider: desc.provider || L.providerFromHost(),
        entity: desc.entity || null,
        query: desc.query || null,
        combo: desc.combo || null,
        tier: desc.tier || null,
        expectedKeyRef: desc.expectedKeyRef || null,
        fills: desc.fills,
        at: new Date().toISOString()
      }));
    } catch (e) { console.warn('[USx-DRV] localStorage stash failed', e); }

    const allFilled = fillResults.every((r) => r.ok);
    const sent = L.clickSend();
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', { fillResults, allFilled, sent });
    if (!sent.ok) console.warn('[USx-DRV] Send not clicked:', sent.err, '-- check required fields / autoSelect.');
    else console.log('[USx-DRV] submitted. Now open /admin/dex-log and run  __usxCapture()');
    return { fillResults, allFilled, sent };
  };

  // Submit + clear the form (so the next combo starts clean); fall back to plain Send.
  function clickSendClear() {
    const sc = [...document.querySelectorAll('button')].find((b) => /send\s*&\s*clear/i.test(b.textContent || '') && !b.disabled);
    if (sc) { sc.click(); return { ok: true, mode: 'send+clear' }; }
    const s = [...document.querySelectorAll('button')].find((b) => (b.textContent || '').trim() === 'Send' && !b.disabled);
    if (s) { s.click(); return { ok: true, mode: 'send (no clear)' }; }
    return { ok: false, err: 'no enabled Send button' };
  }

  // Run a whole tier plan for ONE entity in a loop. `plan` = the TEST_PLAN.json object
  // (emit_test_plan.ps1); entityFilter = e.g. 'Vehicle'. Fills each combo's fields (auto-selects
  // the query), clicks "Send & Clear Form" (clears for the next), and records a batch manifest in
  // localStorage so the capture page can correlate each dex-log row back to its combo.
  window.__usxRunPlan = async function (plan, entityFilter, opts) {
    if (!plan || !Array.isArray(plan.tests)) { console.error('[USx-DRV] pass the TEST_PLAN object: __usxRunPlan(plan, "Vehicle")'); return; }
    opts = opts || {};
    // Deliberately unhurried so React state + autoSelect keep up. Tune via opts if needed.
    const dField = opts.fieldDelay || 450;   // pause after each field
    const dSettle = opts.settle || 900;      // pause after all fields, before submit (let autoSelect enable)
    const dBetween = opts.between || 1700;    // pause after submit/clear, before next combo
    const tests = plan.tests.filter((t) => (t.kind === 'combo' || t.kind === 'any') && (!entityFilter || t.entity === entityFilter));
    if (!tests.length) { console.warn('[USx-DRV] no combo tests for', entityFilter); return; }
    const manifest = []; const results = [];
    for (const t of tests) {
      const fr = [];
      for (const f of (t.fills || [])) { fr.push(await L.fillField(f.fieldId, f.value)); await L.sleep(dField); }
      await L.sleep(dSettle);
      manifest.push({ provider: plan.provider, entity: t.entity, query: t.query, comboKeyRef: t.comboKeyRef, expectedKeyRef: t.expectedKeyRef, tier: t.tier, fills: t.fills, n: t.n });
      const sent = clickSendClear();
      results.push({ n: t.n, combo: t.comboKeyRef, filled: fr.every((r) => r.ok), sent });
      console.log('%c[USx-DRV]', 'color:#06c', `T${t.n} ${t.entity} ${t.comboKeyRef}: ${sent.ok ? 'submitted' : 'NOT submitted (' + sent.err + ')'}`);
      await L.sleep(dBetween);
    }
    try { localStorage.setItem('__usx_batch', JSON.stringify(manifest)); } catch (e) {}
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', `plan run complete: ${manifest.length} queries submitted. Go to /admin/dex-log and run __usxCaptureBatch().`, results);
    return results;
  };

  if (location.hash.includes('universal-search')) {
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', 'driver ready. __usxRunOne({...}) = one combo; __usxRunPlan(plan,"Vehicle") = whole entity.');
  }
})();
