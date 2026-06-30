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

  // Scrape EVERY distinct ConnectCic request XML currently in the page DOM (no dialogs
  // opened). Dedupes the repeated DIV/TEXTAREA copies by transactionId+messageType.
  // If the list renders XML per row, this returns many; if only an open dialog has it,
  // it returns what's open; if 0, the XML is only behind per-row dialogs.
  window.__usxScrapeAll = function () {
    const blocks = []; const seen = new Set();
    document.querySelectorAll('textarea, pre, code, div').forEach((el) => {
      const r = L.extractConnectCicXml(el.value || el.textContent || '');
      if (!r) return;
      const key = (r.transactionId || '?') + '|' + (r.messageType || '?');
      if (seen.has(key)) return;
      seen.add(key);
      blocks.push({ tag: el.tagName, transactionId: r.transactionId, messageType: r.messageType, xmlLen: r.xml.length });
    });
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'scrapeAll found', blocks.length, blocks);
    return blocks;
  };

  // One-shot recon of the dex-log page: distinct XML blocks in the DOM now, sample row
  // structure (correlation keys), pagination controls, and whether any network response
  // carried the XML. Lives in the extension so a full-page reload re-arms it.
  window.__usxLogRecon = function () {
    const rows = [...document.querySelectorAll('tr, [role=row]')].slice(1, 4).map((r) => ({
      cls: (r.className || '').toString().slice(0, 50),
      dataAttrs: [...r.attributes].filter((a) => a.name.startsWith('data-')).map((a) => a.name + '=' + a.value).join(','),
      text: (r.textContent || '').trim().slice(0, 140),
      links: [...r.querySelectorAll('button,a')].map((b) => ((b.textContent || '').trim() || b.getAttribute('aria-label') || '').slice(0, 24)).filter(Boolean)
    }));
    const xmlBlocks = window.__usxScrapeAll();
    const pager = [...new Set([...document.querySelectorAll('button,[aria-label]')]
      .map((b) => ((b.textContent || '').trim() || b.getAttribute('aria-label') || ''))
      .filter((t) => /next|prev|page|rows per|^\d+$/i.test(t)))].slice(0, 10);
    const out = {
      xmlBlocksInDomNow: xmlBlocks.length,
      xmlBlocks,
      sampleRows: rows,
      paginationControls: pager,
      networkRequestsSeen: (window.__usxNetAll || []).length,
      networkWithXml: (window.__usxNetAll || []).filter((n) => n.hasXml).slice(0, 10)
    };
    console.log('%c[USx-RECON]', 'color:#a0a;font-weight:bold', out);
    return out;
  };

  // ---- Dialog-walk capture (the real, hands-off path) -------------------------
  // The list rows carry the submitted fields as JSON; the full ConnectCic XML is
  // behind each row's "View request and return" dialog. This opens that dialog,
  // scrapes the XML, and closes it -- read-only (no submit).
  function rowFieldJson(rowEl) {
    const m = (rowEl.textContent || '').match(/\{[\s\S]*\}/);
    if (!m) return null;
    try { return JSON.parse(m[0]); } catch (e) { return null; }
  }
  // Scan the (light) DOM -- including the Chakra portal where the popup renders.
  function scanForXml() {
    for (const el of document.querySelectorAll('textarea, pre, code, div, td, span, section')) {
      const r = L.extractConnectCicXml(el.value || el.textContent || '');
      if (r) return r;
    }
    return null;
  }
  // The popup loads its XML async -- poll instead of a fixed wait.
  async function waitForXml(timeoutMs) {
    const steps = Math.max(1, Math.floor(timeoutMs / 250));
    for (let i = 0; i < steps; i++) { const r = scanForXml(); if (r) return r; await L.sleep(250); }
    return null;
  }
  // Full pointer sequence -- React/Chakra controls often need mousedown, not just .click().
  function realClick(el) {
    if (!el) return;
    for (const t of ['pointerdown', 'mousedown', 'mouseup', 'click']) {
      try { el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window })); } catch (e) {}
    }
  }
  // This modal ignores Escape -- click its real "Close" button (scoped to the portal).
  function closePopup() {
    const scope = document.querySelector('.chakra-portal') || document;
    let btn = [...scope.querySelectorAll('button')].find((b) => /^close$/i.test((b.textContent || '').trim()));
    if (!btn) btn = [...scope.querySelectorAll('button')].find((b) => /close/i.test(b.getAttribute('aria-label') || ''));
    if (btn) { realClick(btn); return true; }
    return false;
  }
  async function waitFor(predicate, timeoutMs) {
    const steps = Math.max(1, Math.floor(timeoutMs / 250));
    for (let i = 0; i < steps; i++) { const v = predicate(); if (v) return v; await L.sleep(250); }
    return null;
  }
  function findCopyButton() {
    const scope = document.querySelector('.chakra-portal') || document;
    return [...scope.querySelectorAll('button')].find((b) => /^copy$/i.test((b.textContent || '').trim())) || null;
  }
  async function captureRowEl(rowEl) {
    const fields = rowFieldJson(rowEl);
    const link = [...rowEl.querySelectorAll('button, a')].find((b) => /view request/i.test(b.textContent || ''));
    if (!link) return { ok: false, err: 'no "View request" link in row', fields };
    for (let attempt = 0; attempt < 2; attempt++) {
      closePopup(); await L.sleep(250);
      window.__usxCopied = null;
      realClick(link);
      // Prefer the app's Copy button (its own serializer) -- intercepted via nethook.
      const copyBtn = await waitFor(findCopyButton, 8000);
      let x = null;
      if (copyBtn) {
        realClick(copyBtn);
        const copied = await waitFor(() => window.__usxCopied, 2500);
        if (copied) x = L.extractConnectCicXml(copied);
      }
      if (!x) x = scanForXml();          // fallback: DOM scrape of the portal
      const closed = closePopup(); await L.sleep(500);
      if (x) return { ok: true, fields, requestXml: x.xml, transactionId: x.transactionId, messageType: x.messageType, via: copyBtn && window.__usxCopied ? 'copy' : 'scrape', popupClosed: closed, attempt };
    }
    return { ok: false, fields, requestXml: null, transactionId: null, messageType: null, popupClosed: true };
  }

  // Merge a captured row with the driver's test context (stashed in localStorage by
  // __usxRunOne, same origin) into one import-ready, labeled record.
  function labelRecord(rec) {
    let pending = {};
    try { pending = JSON.parse(localStorage.getItem('__usx_pending') || '{}'); } catch (e) {}
    const fs = rec.fields ? Object.entries(rec.fields).map(([k, v]) => k + '=' + v).join(', ')
      : (Array.isArray(pending.fills) ? pending.fills.map((f) => f.fieldId + '=' + f.value).join(', ') : null);
    return {
      provider: pending.provider || 'NJ_NJCJIS',
      entity: pending.entity || null,
      query: pending.query || rec.messageType || null,
      combo: pending.combo || null,
      tier: pending.tier || null,
      expectedKeyRef: pending.expectedKeyRef || null,
      messageType: rec.messageType,
      transactionId: rec.transactionId,
      requestXml: rec.requestXml,
      formState: fs,
      capturedAt: new Date().toISOString()
    };
  }

  // Data rows only (skip the header: keep rows that actually have a "View request" link).
  function dataRows() {
    return [...document.querySelectorAll('.arc-table_row')]
      .filter((r) => [...r.querySelectorAll('button,a')].some((b) => /view request/i.test(b.textContent || '')));
  }

  // Test ONE row (default: the first data row).
  window.__usxCaptureRow = async function (index) {
    const rows = dataRows();
    const row = rows[index || 0];
    if (!row) { console.warn('[USx-CAP] no data row at index', index || 0, '(', rows.length, 'data rows)'); return null; }
    const rec = await captureRowEl(row);
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'row capture:', rec);
    return rec;
  };

  // Walk rows (optionally filtered by a substring, across up to maxPages) and download all.
  window.__usxCaptureAll = async function (opts) {
    opts = opts || {};
    const filter = opts.filter || null;
    const maxPages = opts.maxPages || 1;
    const out = []; let page = 0;
    while (page < maxPages) {
      const rows = dataRows();
      for (const r of rows) {
        if (filter && !(r.textContent || '').includes(filter)) continue;
        out.push(await captureRowEl(r));
        await L.sleep(300);
      }
      const next = [...document.querySelectorAll('[aria-label]')].find((b) => /next page/i.test(b.getAttribute('aria-label') || ''));
      if (next && !next.disabled) { next.click(); await L.sleep(900); page++; } else break;
    }
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'captured', out.length, out);
    L.triggerDownload('usx_captured_batch.json', out);
    return out;
  };

  // Labeled capture of the NEWEST entry (the query the driver just submitted): captures
  // the top data row + merges the driver's localStorage context, downloads ONE import-ready
  // record. This is the per-test loop: __usxRunOne(...) on universal-search, then this here.
  window.__usxCaptureLatest = async function () {
    const rows = dataRows();
    if (!rows.length) { console.warn('[USx-CAP] no data rows'); return null; }
    const rec = await captureRowEl(rows[0]);
    const full = labelRecord(rec);
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'labeled record:', full);
    if (!rec.ok) { console.warn('[USx-CAP] XML not captured even after retry -- re-run __usxCaptureLatest()'); return full; }
    L.triggerDownload('usx_captured_' + (rec.transactionId || 'rec') + '.json', [full]);
    return full;
  };

  if (location.hash.includes('dex-log')) {
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'capture ready. __usxCaptureLatest() = labeled newest (per-test loop); __usxCaptureAll({filter}) = raw walk; __usxLogRecon() = recon.');
  }
})();
