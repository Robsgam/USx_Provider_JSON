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
//      provider:'NJ_NJCJIS', entity:'Vehicle', query:'VehicleRegistrationQuery',
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
        provider: desc.provider || 'NJ_NJCJIS',
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

  if (location.hash.includes('universal-search')) {
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', 'driver ready. Render an entity form, then run __usxRunOne({...}).');
  }
})();
