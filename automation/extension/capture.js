// ===========================================================================
//  USx Tenant Testing automation -- CAPTURE (capture.js)
//  Runs on /admin/dex-log. Scrapes the entry's ConnectCic request XML from the
//  page (the TEXTAREA is cleanest; DIVs append "CopyClose" button text), merges
//  the test context the driver stashed in localStorage, and downloads one
//  import-ready record.
//
//  USAGE in the Console on /admin/dex-log (the entry's request XML on screen):
//    __usxCapture()      -> logs + downloads usx_captured_<txId>.json
// ===========================================================================
(() => {
  const L = window.__usxLib;
  if (!L) { console.error('[USx-CAP] usx_lib not loaded'); return; }

  function scrape() {
    // 1) textareas (cleanest)
    for (const ta of document.querySelectorAll('textarea')) {
      const r = L.extractConnectCicXml(ta.value || ta.textContent || '');
      if (r) return r;
    }
    // 2) DOM fallback
    for (const el of document.querySelectorAll('div, pre, code')) {
      const r = L.extractConnectCicXml(el.textContent || '');
      if (r) return r;
    }
    return null;
  }

  window.__usxCapture = function () {
    const found = scrape();
    if (!found) { console.warn('[USx-CAP] no ConnectCic XML on this page -- open a DEX entry showing the request.'); return null; }

    let pending = {};
    try { pending = JSON.parse(localStorage.getItem('__usx_pending') || '{}'); } catch (e) {}

    const rec = {
      provider: pending.provider || 'NJ_NJCJIS',
      entity: pending.entity || null,
      query: pending.query || found.messageType || null,
      combo: pending.combo || null,
      tier: pending.tier || null,
      expectedKeyRef: pending.expectedKeyRef || null,
      messageType: found.messageType,
      transactionId: found.transactionId,
      requestXml: found.xml,
      formState: Array.isArray(pending.fills) ? pending.fills.map((f) => f.fieldId + '=' + f.value).join(', ') : null,
      capturedAt: new Date().toISOString()
    };

    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'record:', rec);
    if (!rec.combo) console.warn('[USx-CAP] no combo context (driver not used or localStorage cleared) -- fill combo/entity manually before import.');
    L.triggerDownload('usx_captured_' + (found.transactionId || 'rec') + '.json', [rec]);
    return rec;
  };

  if (location.hash.includes('dex-log')) {
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'capture ready. Open a DEX entry, then run __usxCapture().');
  }
})();
