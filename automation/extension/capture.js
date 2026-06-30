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
  async function closeDialog() {
    document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', keyCode: 27, bubbles: true }));
    await L.sleep(250);
    if ([...document.querySelectorAll('textarea')].some((t) => /ConnectCic/.test(t.value || t.textContent || ''))) {
      const x = [...document.querySelectorAll('button')]
        .find((b) => /^(close|cancel)$/i.test((b.textContent || '').trim()) || /close/i.test(b.getAttribute('aria-label') || ''));
      if (x) { try { x.click(); } catch (e) {} await L.sleep(200); }
    }
  }
  async function captureRowEl(rowEl) {
    const fields = rowFieldJson(rowEl);
    const link = [...rowEl.querySelectorAll('button, a')].find((b) => /view request/i.test(b.textContent || ''));
    if (!link) return { ok: false, err: 'no "View request" link in row', fields };
    link.click();
    await L.sleep(500);
    let x = null;
    for (const ta of document.querySelectorAll('textarea')) { x = L.extractConnectCicXml(ta.value || ta.textContent || ''); if (x) break; }
    if (!x) { for (const el of document.querySelectorAll('div,pre,code')) { x = L.extractConnectCicXml(el.textContent || ''); if (x) break; } }
    await closeDialog();
    return { ok: !!x, fields, requestXml: x ? x.xml : null, transactionId: x ? x.transactionId : null, messageType: x ? x.messageType : null };
  }

  // Test ONE row (default: the first list row).
  window.__usxCaptureRow = async function (index) {
    const rows = [...document.querySelectorAll('.arc-table_row')];
    const row = rows[index || 0];
    if (!row) { console.warn('[USx-CAP] no row at index', index || 0); return null; }
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
      const rows = [...document.querySelectorAll('.arc-table_row')];
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

  if (location.hash.includes('dex-log')) {
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'capture ready. __usxCaptureRow() = test one row; __usxCaptureAll({filter:"TEST123"}) = walk; __usxLogRecon() = recon.');
  }
})();
