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
      provider: pending.provider || L.providerFromHost(),
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

  // ---- RMS-side capture (2026-07-01) -------------------------------------------
  // dex-log's table carries an RMS-destination row alongside the ConnectCic row for every
  // query that has an RMS mapping (Person/Vehicle only per the RMS bundle -- Gun/Article/Boat/DH
  // have none, so finding no RMS row for those is EXPECTED, not a failure). The RMS row's own
  // "View request and return" popup shows a single textarea:
  //   ***** Request *****\n\n{elasticQuery JSON}\n\n***** Response *****\n\n<text, e.g. "No Returns">
  // (live-confirmed via __usxRmsPopupRecon spike). Unlike the ConnectCic popup, this one loaded
  // real content from a purely synthetic click (no "trusted gesture" gate observed) -- still
  // click-based, not zero-click network, since the network body for RMS items isn't retained by
  // nethook.js (its capture regex only keeps XML-shaped or /queries/search list bodies).
  function extractRmsPopup(text) {
    const m = /\*{5}\s*Request\s*\*{5}\s*([\s\S]*?)\*{5}\s*Response\s*\*{5}\s*([\s\S]*)/i.exec(text || '');
    if (!m) return null;
    let requestJson = null;
    try { requestJson = JSON.parse(m[1].trim()); } catch (e) { requestJson = null; }
    return { requestRaw: m[1].trim(), requestJson, response: m[2].trim() };
  }
  // Order-independent shallow equality for two plain field-map objects (JSON key order in the
  // DOM's rendered "Query String" cell isn't guaranteed to match our own JSON.stringify order).
  function fieldsEqual(a, b) {
    if (!a || !b) return false;
    const ak = Object.keys(a), bk = Object.keys(b);
    if (ak.length !== bk.length) return false;
    return ak.every((k) => String(a[k]) === String(b[k]));
  }
  // Find the RMS-destination row (Query cell === 'RMS') whose Query String cell matches the
  // given fields object. Returns null if none exists -- normal for entities with no RMS mapping.
  function findRmsRowForFields(fieldsObj) {
    if (!fieldsObj) return null;
    const rows = [...document.querySelectorAll('.arc-table_row')].filter((r) => r.querySelector('.arc-table_cell'));
    for (const r of rows) {
      const cells = [...r.querySelectorAll('.arc-table_cell')];
      if (!cells.length || (cells[1] && cells[1].textContent.trim() !== 'RMS')) continue;
      const qs = cells[0] ? cells[0].textContent.trim() : '';
      let parsed = null;
      try { parsed = JSON.parse(qs); } catch (e) { continue; }
      if (fieldsEqual(parsed, fieldsObj)) return r;
    }
    return null;
  }
  // Click an RMS row's "View request and return" link, scrape+parse the popup, close it.
  // Best-effort: returns null (not throw) on any failure so a missing/slow RMS row never
  // aborts the caller's main ConnectCic capture.
  async function captureRmsRow(rmsRow) {
    try {
      const link = [...rmsRow.querySelectorAll('button, a')].find((b) => /view request/i.test(b.textContent || ''));
      if (!link) return null;
      closePopup(); await L.sleep(200);
      realClick(link);
      await waitFor(popupOpen, 2500);
      await L.sleep(700);
      const portal = document.querySelector('.chakra-portal');
      const raw = portal ? (portal.textContent || '').trim() : null;
      closePopup();
      return raw ? extractRmsPopup(raw) : null;
    } catch (e) { return null; }
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
  // Full pointer sequence -- a plain .click() often opens the popup shell but the app does NOT
  // fetch/render the XML; the richer gesture triggers the real handler + data load.
  function realClick(el) {
    if (!el) return;
    for (const t of ['pointerover', 'pointerenter', 'pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click']) {
      try { el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window })); } catch (e) {}
    }
  }
  async function waitFor(predicate, timeoutMs) {
    const steps = Math.max(1, Math.floor(timeoutMs / 250));
    for (let i = 0; i < steps; i++) { if (predicate()) return true; await L.sleep(250); }
    return false;
  }
  function popupOpen() {
    const s = document.querySelector('.chakra-portal');
    return !!(s && [...s.querySelectorAll('button')].some((b) => /^close$/i.test((b.textContent || '').trim())));
  }
  // This modal ignores Escape -- click its real "Close" button (scoped to the portal).
  function closePopup() {
    const scope = document.querySelector('.chakra-portal') || document;
    let btn = [...scope.querySelectorAll('button')].find((b) => /^close$/i.test((b.textContent || '').trim()));
    if (!btn) btn = [...scope.querySelectorAll('button')].find((b) => /close/i.test(b.getAttribute('aria-label') || ''));
    if (btn) { realClick(btn); return true; }
    return false;
  }
  // Fallback: the View click may fetch the XML -- nethook keeps XML response bodies.
  function scanNetworkForXml() {
    const net = (window.__usxNetAll || []);
    for (let i = net.length - 1; i >= 0; i--) {
      if (net[i].hasXml && net[i].body) { const r = L.extractConnectCicXml(net[i].body); if (r) return r; }
    }
    return null;
  }
  async function captureRowEl(rowEl) {
    const fields = rowFieldJson(rowEl);
    const link = [...rowEl.querySelectorAll('button, a')].find((b) => /view request/i.test(b.textContent || ''));
    if (!link) return { ok: false, err: 'no "View request" link in row', fields };
    // One fast attempt -- synthetic clicks usually do NOT make the app load the XML, so don't
    // hang the popup open for 30s. For reliable capture use __usxCaptureWatch (real clicks).
    closePopup(); await L.sleep(250);
    realClick(link);
    await waitFor(popupOpen, 2500);
    const x = await waitForXml(3500);
    const xx = x || scanNetworkForXml();
    const closed = closePopup(); await L.sleep(300);
    // RMS row (if this entity has one -- Person/Vehicle only; Gun/Article/Boat/DH normally
    // won't, which is expected, not a failure). Best-effort: never blocks the main XML result.
    const rmsRow = findRmsRowForFields(fields);
    const rms = rmsRow ? await captureRmsRow(rmsRow) : null;
    const rmsFields = { rmsRequestJson: rms ? rms.requestJson : null, rmsResponse: rms ? rms.response : null };
    if (xx) return { ok: true, fields, requestXml: xx.xml, transactionId: xx.transactionId, messageType: xx.messageType, via: x ? 'dom' : 'network', popupClosed: closed, ...rmsFields };
    return { ok: false, fields, requestXml: null, transactionId: null, messageType: null, popupClosed: true, ...rmsFields };
  }

  // Merge a captured row with the driver's test context (stashed in localStorage by
  // __usxRunOne, same origin) into one import-ready, labeled record.
  function labelRecord(rec) {
    let pending = {};
    try { pending = JSON.parse(localStorage.getItem('__usx_pending') || '{}'); } catch (e) {}
    const fs = rec.fields ? Object.entries(rec.fields).map(([k, v]) => k + '=' + v).join(', ')
      : (Array.isArray(pending.fills) ? pending.fills.map((f) => f.fieldId + '=' + f.value).join(', ') : null);
    return {
      provider: pending.provider || L.providerFromHost(),
      entity: pending.entity || null,
      query: pending.query || rec.messageType || null,
      combo: pending.combo || null,
      tier: pending.tier || null,
      expectedKeyRef: pending.expectedKeyRef || null,
      messageType: rec.messageType,
      transactionId: rec.transactionId,
      requestXml: rec.requestXml,
      formState: fs,
      rmsRequestJson: rec.rmsRequestJson != null ? rec.rmsRequestJson : null,
      rmsResponse: rec.rmsResponse != null ? rec.rmsResponse : null,
      capturedAt: new Date().toISOString()
    };
  }

  // Data rows only (skip the header: keep rows that actually have a "View request" link).
  // CORRECTED 2026-07-01: originally assumed this filter alone excluded RMS-destination rows
  // (on the premise they had no "View request" link, hence no XML) -- __usxDexTableRecon +
  // __usxRmsPopupRecon proved that premise wrong: RMS rows have the SAME link, just behind a
  // differently-shaped popup (elasticQuery/response text, not ConnectCic XML). Without an
  // explicit exclusion here, every ConnectCic-row function (captureRowEl et al.) would also
  // iterate RMS rows and miscount them as failed ConnectCic captures (ok:false, no XML found)
  // instead of the separate, successful RMS captures they now are via captureRmsRow(). The
  // Query column value is the reliable discriminator (only ConnectCic rows carry a MessageType-
  // style query name there; RMS rows always say exactly "RMS").
  function dataRows() {
    return [...document.querySelectorAll('.arc-table_row')].filter((r) => {
      const hasLink = [...r.querySelectorAll('button,a')].some((b) => /view request/i.test(b.textContent || ''));
      if (!hasLink) return false;
      const cells = [...r.querySelectorAll('.arc-table_cell')];
      return !(cells[1] && cells[1].textContent.trim() === 'RMS');
    });
  }

  // RMS-ROW RECON (spike, 2026-07-01 round 3): dex-log's table has an RMS-destination row
  // for every query alongside its ConnectCic row (same "Query String" JSON, no "View request"
  // link since there's no XML) -- dataRows() above has always silently skipped these. This dumps
  // the full header row + one full RMS row's cell texts (labeled) so the real column mapping
  // (which cell holds the status/result) comes from evidence, not another guess.
  window.__usxDexTableRecon = function () {
    const headerCells = [...document.querySelectorAll('.arc-table_header_cell')].map((th) => (th.textContent || '').trim());
    const allRows = [...document.querySelectorAll('.arc-table_row')].filter((r) => r.querySelector('.arc-table_cell'));
    const rmsRow = allRows.find((r) => {
      const cells = [...r.querySelectorAll('.arc-table_cell')];
      return cells.some((c) => (c.textContent || '').trim() === 'RMS');
    });
    if (!rmsRow) { console.warn('[USx-DEX-RECON] no RMS row found on this page/view.'); return null; }
    const cellTexts = [...rmsRow.querySelectorAll('.arc-table_cell')].map((c) => (c.textContent || '').trim());
    const labeled = headerCells.map((h, i) => ({ header: h, value: cellTexts[i] !== undefined ? cellTexts[i] : null }));
    // Also grab the matching ConnectCic row (same Query String JSON) if present, so both sides
    // of the pair can be compared column-for-column.
    const qs = cellTexts[0];
    const pairRow = qs ? allRows.find((r) => r !== rmsRow && (r.querySelector('.arc-table_cell')?.textContent || '').trim() === qs) : null;
    const pairLabeled = pairRow ? headerCells.map((h, i) => ({ header: h, value: [...pairRow.querySelectorAll('.arc-table_cell')][i]?.textContent?.trim() ?? null })) : null;
    const out = { headerCells, rmsRow: labeled, matchingConnectCicRow: pairLabeled };
    console.log('%c[USx-DEX-RECON]', 'color:#c60;font-weight:bold', out);
    console.log('[USx-DEX-RECON] report the full object above -- rmsRow is one RMS-destination row\'s cells labeled by header; matchingConnectCicRow is the paired ConnectCic row (same Query String) for comparison.');
    return out;
  };

  // RMS-ROW RECON round 4: __usxDexTableRecon showed the RMS row ALSO has a "View request and
  // return" link -- contradicts the old assumption (dataRows() has always filtered these out
  // assuming no link/no XML). Click it and dump the popup's RAW text (NOT run through
  // extractConnectCicXml, since RMS content won't be ConnectCic-XML-shaped -- that's likely why
  // scanForXml() would find nothing there even after a real click).
  window.__usxRmsPopupRecon = async function () {
    const allRows = [...document.querySelectorAll('.arc-table_row')].filter((r) => r.querySelector('.arc-table_cell'));
    const rmsRow = allRows.find((r) => [...r.querySelectorAll('.arc-table_cell')].some((c) => (c.textContent || '').trim() === 'RMS'));
    if (!rmsRow) { console.warn('[USx-RMS-POPUP-RECON] no RMS row found on this page/view.'); return null; }
    const link = [...rmsRow.querySelectorAll('button, a')].find((b) => /view request/i.test(b.textContent || ''));
    if (!link) { console.warn('[USx-RMS-POPUP-RECON] RMS row has no "View request" link after all.'); return null; }
    closePopup(); await L.sleep(250);
    realClick(link);
    const opened = await waitFor(popupOpen, 2500);
    await L.sleep(1000); // let async content finish rendering, whatever shape it is
    const portal = document.querySelector('.chakra-portal');
    const raw = portal ? (portal.textContent || '').trim() : null;
    const textareas = portal ? [...portal.querySelectorAll('textarea')].map((t) => t.value || t.textContent || '') : [];
    closePopup();
    const out = { opened, rawTextLength: raw ? raw.length : 0, rawText: raw ? raw.slice(0, 3000) : null, textareas };
    console.log('%c[USx-RMS-POPUP-RECON]', 'color:#c60;font-weight:bold', out);
    console.log('[USx-RMS-POPUP-RECON] report rawText (and any textarea content) above -- this is whatever the RMS "View request and return" popup actually shows.');
    return out;
  };

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

  // Manual-assist: YOU click "View request and return" (a real gesture loads it reliably),
  // then run this -- it scrapes the OPEN popup, merges driver context, downloads, and closes.
  // Robust fallback when the programmatic auto-click is flaky.
  window.__usxCaptureOpen = function () {
    const x = scanForXml() || scanNetworkForXml();
    if (!x) { console.warn('[USx-CAP] no XML found -- is the request popup open with XML visible?'); return null; }
    const top = dataRows()[0];
    const rec = { fields: top ? rowFieldJson(top) : null, requestXml: x.xml, transactionId: x.transactionId, messageType: x.messageType };
    const full = labelRecord(rec);
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'labeled record (manual-assist):', full);
    L.triggerDownload('usx_captured_' + (x.transactionId || 'rec') + '.json', [full]);
    closePopup();
    return full;
  };

  // Batch capture: correlate the driver's localStorage manifest (__usx_batch) to dex-log rows
  // by identifier field values, capture each row's XML, label, and download one array for import.
  function labelFromManifest(m, rec) {
    return {
      provider: m.provider || L.providerFromHost(), entity: m.entity, query: m.query || rec.messageType,
      combo: m.comboKeyRef, tier: m.tier, expectedKeyRef: m.expectedKeyRef,
      kind: m.kind || null, anyField: m.anyField || null, underFilled: m.underFilled || false,
      messageType: rec.messageType, transactionId: rec.transactionId, requestXml: rec.requestXml,
      // Prefer the raw dex-log field-map JSON (rec.formState, e.g. from __usxBulkFetch's
      // parsedRawQuery) when present; fall back to deriving from rec.fields for capture paths
      // that don't have it (rec.formState was previously omitted at the bulk-fetch call site,
      // silently dropping the scraped JSON -- fixed alongside this).
      formState: rec.formState != null
        ? (typeof rec.formState === 'string' ? rec.formState : JSON.stringify(rec.formState))
        : (rec.fields ? Object.entries(rec.fields).map(([k, v]) => k + '=' + v).join(', ') : null),
      rmsRequestJson: rec.rmsRequestJson != null ? rec.rmsRequestJson : null,
      rmsResponse: rec.rmsResponse != null ? rec.rmsResponse : null,
      capturedAt: new Date().toISOString(), ok: rec.ok
    };
  }
  // Identifier fills are the distinctive text fields that pinpoint a row (not shared defaults/dropdowns).
  // Defensive: PowerShell's ConvertTo-Json collapses a single-element array to a bare object,
  // so a `fills` producer upstream (or an older cached localStorage batch) may hand us a
  // non-array here -- normalize instead of throwing (a throw inside a .find()/.findIndex()
  // predicate aborts the whole __usxBulkFetch batch, not just this one item).
  const ID_FIELD_RE = /Number$|^operatorLicense|^nameLast|Serial|Hull|^registrationNumber/i;
  function idFills(fills) {
    const arr = Array.isArray(fills) ? fills : (fills ? [fills] : []);
    return arr.filter((f) => f && ID_FIELD_RE.test(f.fieldId));
  }
  // Debug: dump the data rows the page currently shows (count + parsed field JSON).
  window.__usxDebugRows = function () {
    const rows = dataRows();
    const info = rows.slice(0, 8).map((r, i) => ({ i, fields: rowFieldJson(r) }));
    console.log('%c[USx-DBG]', 'color:#a0a;font-weight:bold', 'dataRows:', rows.length, info);
    return { count: rows.length, sample: info };
  };

  window.__usxCaptureBatch = async function () {
    let batch = [];
    try { batch = JSON.parse(localStorage.getItem('__usx_batch') || '[]'); } catch (e) {}
    if (!batch.length) { console.warn('[USx-CAP] no __usx_batch -- run __usxRunPlan first'); return null; }
    const rows = dataRows();
    if (!rows.length) { console.warn('[USx-CAP] no data rows -- reload /admin/dex-log so the new queries show, then retry.'); return null; }

    // Pass 1: correlate each manifest entry to a row by identifier field values.
    const used = new Set();
    const pair = new Array(batch.length).fill(null);
    batch.forEach((m, bi) => {
      const ids = idFills(m.fills);
      const idx = rows.findIndex((r, i) => {
        if (used.has(i)) return false;
        const fj = rowFieldJson(r) || {};
        if (!(ids.length && ids.every((f) => String(fj[f.fieldId] ?? '').toUpperCase() === String(f.value).toUpperCase()))) return false;
        // Reject rows carrying an identifier this test did NOT fill: a plate-only test must not
        // claim a Plate+VIN guardrail row. Subset matching cross-labelled the whole CA batch
        // (2026-07-02) when the dex-log held rows from more than one run.
        const filledIds = new Set(ids.map((f) => String(f.fieldId).toUpperCase()));
        return !Object.keys(fj).some((k) => ID_FIELD_RE.test(k) && String(fj[k] ?? '').trim() !== '' && !filledIds.has(k.toUpperCase()));
      });
      if (idx >= 0) { used.add(idx); pair[bi] = idx; }
    });

    // Pass 2 (fallback): if nothing matched, pair by ORDER -- newest rows are the most recent
    // submissions, so manifest (oldest-first) maps to the top rows in reverse.
    if (pair.every((p) => p === null) && rows.length >= batch.length) {
      for (let bi = 0; bi < batch.length; bi++) pair[bi] = batch.length - 1 - bi;
      console.log('[USx-CAP] field-match found nothing; using order-based pairing (reverse of newest rows).');
    }

    const out = [];
    for (let bi = 0; bi < batch.length; bi++) {
      const m = batch[bi];
      if (pair[bi] === null || !rows[pair[bi]]) { out.push({ ...labelFromManifest(m, {}), ok: false, err: 'no matching dex-log row' }); continue; }
      const rec = await captureRowEl(rows[pair[bi]]);
      out.push(labelFromManifest(m, rec));
    }
    L.triggerDownload('usx_captured_batch_labeled.json', out);
    markSeen(out);   // row-click path: no store to clear, but keep ids so bulk fetch skips these
    const okN = out.filter((r) => r.ok).length;
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', `batch: ${okN}/${out.length} captured`, out);
    if (okN < out.length) console.log('[USx-CAP] tip: if 0 matched, run __usxDebugRows() and check the row field JSON.');
    return out;
  };

  // Captures persist in localStorage so they accumulate ACROSS pages (even if a page change does
  // a full reload, which restarts the interval -- just re-run __usxCaptureWatch() and keep clicking).
  function loadCaptured() { try { return JSON.parse(localStorage.getItem('__usx_captured') || '[]'); } catch (e) { return []; } }
  function saveCaptured(a) { try { localStorage.setItem('__usx_captured', JSON.stringify(a)); } catch (e) {} }

  // Seen-id ledger, separate from the record store. After every successful download the record
  // store is EMPTIED (each download then contains only new records -- stale labeled records from
  // earlier runs re-imported the whole history and scrambled labels, 2026-07-02) while the ids
  // persist here so incremental dedup still skips already-captured dex-log entries.
  function loadSeenIds() { try { return JSON.parse(localStorage.getItem('__usx_seen_ids') || '[]'); } catch (e) { return []; } }
  function saveSeenIds(a) { try { localStorage.setItem('__usx_seen_ids', JSON.stringify(a.slice(-3000))); } catch (e) {} }
  function markSeen(records) {
    const ids = new Set(loadSeenIds());
    for (const r of records) { if (r && r.transactionId) ids.add(r.transactionId); if (r && r.qId) ids.add(r.qId); }
    saveSeenIds(Array.from(ids));
  }
  function markSeenAndClear(records) { markSeen(records); saveCaptured([]); }

  // WATCHER (recommended for batches): you click each row's "View request and return" (a real
  // click -- the app only loads the XML for trusted clicks), and this auto-scrapes the popup,
  // matches it to the driver batch by identifier value, closes it, and accumulates. Click through
  // all rows, then __usxCaptureWatchStop() downloads the labeled array. One real click per row.
  window.__usxCaptureWatch = function (raw) {
    if (window.__usxWatchTimer) { console.log('[USx-WATCH] already watching'); return; }
    let batch = [];
    if (!raw) { try { batch = JSON.parse(localStorage.getItem('__usx_batch') || '[]'); } catch (e) {} }
    const seen = new Set(loadCaptured().map((r) => r.transactionId).filter(Boolean).concat(loadSeenIds()));
    console.log('%c[USx-WATCH]', 'color:#a0a;font-weight:bold', `watching${raw ? ' (RAW -- label from XML; combo inferred at import)' : `; batch=${batch.length}`}. Click each row's "View request and return"; I capture + close each. __usxCaptureWatchStop() when done.`);
    window.__usxWatchTimer = setInterval(() => {
      if (!popupOpen()) return;
      const x = scanForXml() || scanNetworkForXml();
      if (!x) return;
      const key = x.transactionId || ('len' + x.xml.length);
      if (seen.has(key)) return;
      seen.add(key);
      const m = batch.find((b) => idFills(b.fills).some((f) => x.xml.includes('>' + f.value + '<')));
      let labeled;
      if (m) {
        labeled = labelFromManifest(m, { fields: null, requestXml: x.xml, transactionId: x.transactionId, messageType: x.messageType, ok: true });
      } else {
        // XML-derived label (recovers arbitrary existing dex-log entries); import infers entity+combo.
        labeled = {
          provider: L.providerFromHost(), entity: null, query: x.messageType, combo: null, tier: null, expectedKeyRef: null,
          messageType: x.messageType, transactionId: x.transactionId, requestXml: x.xml, formState: null,
          capturedAt: new Date().toISOString(), ok: true
        };
      }
      const cur = loadCaptured(); cur.push(labeled); saveCaptured(cur);
      console.log('%c[USx-WATCH]', 'color:#a0a', `captured ${x.messageType} ${x.transactionId} ${m ? '=> ' + m.comboKeyRef : '(infer at import)'} [total ${cur.length}]`);
      closePopup();
    }, 700);
  };
  window.__usxCaptureWatchStop = function () {
    if (window.__usxWatchTimer) { clearInterval(window.__usxWatchTimer); window.__usxWatchTimer = null; }
    const store = loadCaptured();
    L.triggerDownload('usx_captured_batch_labeled.json', store);
    markSeenAndClear(store);
    console.log('%c[USx-WATCH]', 'color:#a0a;font-weight:bold', `stopped. ${store.length} captured -> downloaded usx_captured_batch_labeled.json (store cleared; ids kept for dedup)`, store);
    return store;
  };
  window.__usxCaptureWatchReset = function () { saveCaptured([]); console.log('[USx-WATCH] cleared persisted captures.'); };

  // ZERO-CLICK bulk capture via the federated-search API: list (/queries/search) -> ids ->
  // GET /queries/<id> for each -> ConnectCic XML -> label -> accumulate -> download. No popups,
  // no clicking, no UI paging. Filter so we don't pull all 1182: opts.maxPages (list pages of ~20),
  // opts.since ('2026-06-29' -> only entries created on/after), opts.limit.
  async function fetchJson(url, init) {
    const r = await fetch(url, Object.assign({ credentials: 'include', headers: { 'accept': 'application/json' } }, init));
    const t = await r.text();
    try { return JSON.parse(t); } catch (e) { return t; }
  }
  window.__usxBulkFetch = async function (opts) {
    opts = opts || {};
    const maxPages = opts.maxPages || 1;
    const since = opts.since ? Date.parse(opts.since) : null;
    const limit = opts.limit || Infinity;
    const maxNew = opts.maxNew != null ? opts.maxNew : null;
    const provider = L.providerFromHost();

    // Gather query items -- page the API with the captured search request if available, else use
    // whatever /queries/search bodies nethook already captured (pages you've viewed).
    let items = [];
    const req = window.__usxSearchReq;
    if (req) {
      let base = {}; try { base = JSON.parse(req.body || '{}'); } catch (e) {}
      for (let p = 0; p < maxPages; p++) {
        const body = Object.assign({}, base);
        body.pageable = Object.assign({}, base.pageable, { page: p });          // the real pager
        body.pagination = Object.assign({}, base.pagination, { pageNumber: p }); // belt-and-suspenders
        const j = await fetchJson(req.url, { method: req.method || 'POST', headers: { 'content-type': 'application/json', 'accept': 'application/json' }, body: JSON.stringify(body) });
        const qs = (j && j.queries) || [];
        items.push(...qs);
        console.log('%c[USx-BULK]', 'color:#fa0', `list page ${p}: ${qs.length} (total so far ${items.length})`);
        if (qs.length < ((j.pagination && j.pagination.pageSize) || 20)) break;
        // sorted createdDateUtc,desc -> once a page's oldest row is before `since`, stop paging.
        if (since) { const last = qs[qs.length - 1]; const t = Date.parse((last.auditMetadata && last.auditMetadata.createdDateUtc) || ''); if (t && t < since) break; }
      }
    } else {
      for (const n of (window.__usxNetAll || []).filter((x) => /queries\/search/i.test(x.url) && x.body)) {
        try { const j = JSON.parse(n.body); items.push(...(j.queries || [])); } catch (e) {}
      }
      console.log('%c[USx-BULK]', 'color:#fa0', `no search-request template; using ${items.length} items from captured list bodies`);
    }

    // Dedupe by id, date/limit filter (newest-first assumed).
    const seenId = new Set();
    items = items.filter((q) => q && q.id && !seenId.has(q.id) && seenId.add(q.id));
    if (since) items = items.filter((q) => { const t = Date.parse((q.auditMetadata && q.auditMetadata.createdDateUtc) || ''); return t && t >= since; });
    items = items.slice(0, limit);

    // RMS-destination items are SEPARATE, independently-ordered list entries (confirmed live via
    // __usxRmsNetworkRecon 2026-07-01: q.transaction === 'RMS', own id, own parsedRawQuery
    // matching its ConnectCic sibling's fields) -- fully fetchable over the network, same as the
    // ConnectCic detail fetch below. This REPLACES the earlier DOM-click approach
    // (findRmsRowForFields/captureRmsRow), which was confirmed working but unreliable: it only
    // found whatever RMS row happened to still be rendered on the current dex-log page, and rows
    // scroll off-page as the session accumulates entries (2 per query: ConnectCic + RMS) -- live
    // evidence showed it capturing Person's RMS pair but missing Vehicle's in the same run.
    const rmsItems = items.filter((q) => q.transaction === 'RMS');
    const commsysItems = items.filter((q) => q.transaction !== 'RMS');
    console.log('%c[USx-BULK]', 'color:#fa0;font-weight:bold', `fetching detail for ${commsysItems.length} queries (+ ${rmsItems.length} RMS pairs available)...`);

    // /queries/<id> for an RMS item returns { requestContent: "<stringified JSON>",
    // queryStatus: { queryStatus: "NO_CONTENT"|..., statusMessage: "No results were created"|... } }
    // -- requestContent is double-encoded (a JSON string inside the JSON response), and
    // statusMessage is the RAW API response text (may read differently than the DOM's friendlier
    // rendering of the same status, e.g. "No results were created" vs "No Returns" -- both are
    // faithful to their own source, not reconciled/translated here).
    function parseRmsDetail(raw) {
      let requestJson = null;
      if (raw && raw.requestContent) {
        try { requestJson = JSON.parse(raw.requestContent); } catch (e) { requestJson = raw.requestContent; }
      }
      const response = raw && raw.queryStatus ? (raw.queryStatus.statusMessage || raw.queryStatus.queryStatus || null) : null;
      return { requestJson, response };
    }
    const rmsDetailCache = new Map(); // rmsItem.id -> {requestJson, response}, fetched lazily once per id
    async function getRmsPairFor(fieldsObj) {
      const match = rmsItems.find((r) => fieldsEqual(r.parsedRawQuery, fieldsObj));
      if (!match) return null;
      if (rmsDetailCache.has(match.id)) return rmsDetailCache.get(match.id);
      let parsed = null;
      try { const d = await fetchJson('/federated-search/api/v2/openapi/queries/' + match.id); parsed = parseRmsDetail(typeof d === 'string' ? JSON.parse(d) : d); } catch (e) {}
      rmsDetailCache.set(match.id, parsed);
      return parsed;
    }

    let batch = [];
    try { batch = JSON.parse(localStorage.getItem('__usx_batch') || '[]'); } catch (e) {}

    // Manifest time floor: rows created before this run's FIRST submission (minus 2min
    // tolerance) are backlog from earlier sessions, not this run's -- 27 stale rows rode
    // into an HI batch (2026-07-02) because their ids predated the seen-ids ledger. Drop
    // them here (and mark seen) so they can never pair or import again.
    let floorTs = null;
    const subTimes = batch.map((b) => Date.parse(b.submittedAt || '')).filter((t) => t);
    if (subTimes.length) floorTs = Math.min(...subTimes) - 120000;

    const out = loadCaptured();
    const have = new Set(out.map((r) => r.transactionId).filter(Boolean).concat(loadSeenIds()));
    const dropped = [];
    const fresh = []; // new items collected this run, in API order (newest-first)
    for (const q of commsysItems) {
      if (have.has(q.id)) continue;
      if (floorTs) {
        const ct = Date.parse((q.auditMetadata && q.auditMetadata.createdDateUtc) || '');
        if (ct && ct < floorTs) { dropped.push(q.id); have.add(q.id); continue; }
      }
      let xml = null;
      try { const d = await fetchJson('/federated-search/api/v2/openapi/queries/' + q.id); xml = L.extractConnectCicXml(typeof d === 'string' ? d : JSON.stringify(d)); } catch (e) {}
      if (!xml) continue;
      const rms = await getRmsPairFor(q.parsedRawQuery);
      fresh.push({ qId: q.id, createdAt: (q.auditMetadata && q.auditMetadata.createdDateUtc) || null, formState: q.parsedRawQuery || null, xml, rmsRequestJson: rms ? rms.requestJson : null, rmsResponse: rms ? rms.response : null });
      have.add(q.id);
      if (maxNew !== null && fresh.length >= maxNew) { console.log('%c[USx-BULK]', 'color:#fa0', 'maxNew=' + maxNew + ' reached, stopping.'); break; }
      if (fresh.length % 10 === 0) console.log('%c[USx-BULK]', 'color:#fa0', `captured ${fresh.length}...`);
    }
    // Correlate fresh captures to manifest entries, ALWAYS messageType-guarded.
    // PASS 1 (2026-07-02 rework): POSITIONAL alignment per messageType. Both sides carry an
    // ordering that reflects true submission order -- manifest submittedAt (client clock) and
    // item createdDateUtc (server clock) -- so sorting each side by its OWN timestamps and
    // pairing positionally is deterministic and immune to client/server clock skew. This
    // replaces identifier-content matching as pass 1: content matching is inherently ambiguous
    // for same-identifier families (all six NJ Firearm tests share one serial; subset matches
    // rotated the whole family's labels). Positional pass only fires when the group counts
    // MATCH (the per-entity-download contract); otherwise fall to
    // PASS 2 identifier-content match (formState-based, unfilled-identifier rejection), then
    // PASS 3 messageType-scoped reverse-order, else unlabeled (import infers from XML).
    const usedM = new Set();
    const pairOf = new Array(fresh.length).fill(-1);

    // -- PASS 1: per-messageType positional alignment when counts match --
    const mtGroups = {};
    for (let i = 0; i < fresh.length; i++) {
      const mt = fresh[i].xml.messageType;
      if (!mt) continue;
      (mtGroups[mt] = mtGroups[mt] || []).push(i);
    }
    for (const mt of Object.keys(mtGroups)) {
      const itemIdx = mtGroups[mt].slice().sort((a, b) => Date.parse(fresh[a].createdAt || 0) - Date.parse(fresh[b].createdAt || 0));
      const manIdx = batch.map((b, k) => k).filter((k) => batch[k].query === mt);
      manIdx.sort((a, b) => Date.parse(batch[a].submittedAt || 0) - Date.parse(batch[b].submittedAt || 0));
      const haveTimes = itemIdx.every((i) => fresh[i].createdAt) && manIdx.every((k) => batch[k].submittedAt);
      if (itemIdx.length === manIdx.length && itemIdx.length > 0 && haveTimes) {
        for (let p = 0; p < itemIdx.length; p++) { pairOf[itemIdx[p]] = manIdx[p]; usedM.add(manIdx[p]); }
        console.log('%c[USx-BULK]', 'color:#fa0', `pass1 positional: ${mt} ${itemIdx.length}/${itemIdx.length} paired by timestamp order`);
      }
    }

    for (let i = 0; i < fresh.length; i++) {
      const item = fresh[i];
      const mt = item.xml.messageType;
      let mi = pairOf[i];

      // -- PASS 2: identifier-field content match (messageType-guarded). Match against the
      // dex-log formState, NOT the XML: a guardrail's XML is intentionally identical to the
      // base combo's (loser suppressed on the wire); formState still shows the suppressed
      // field, and an identifier present in formState that the test did not fill disqualifies.
      if (mi < 0) {
        let ifj = null;
        try { ifj = typeof item.formState === 'string' ? JSON.parse(item.formState) : item.formState; } catch (e) {}
        const haveFj = ifj && typeof ifj === 'object';
        mi = batch.findIndex((b, idx) => {
          if (usedM.has(idx)) return false;
          if (!mt && !b.query) return false;
          if (b.query && mt && b.query !== mt) return false;
          const ids = idFills(b.fills || []);
          if (!ids.length) return false;
          if (haveFj) {
            if (!ids.every((f) => String(ifj[f.fieldId] ?? '').toUpperCase() === String(f.value).toUpperCase())) return false;
            const filledIds = new Set(ids.map((f) => String(f.fieldId).toUpperCase()));
            return !Object.keys(ifj).some((k) => ID_FIELD_RE.test(k) && String(ifj[k] ?? '').trim() !== '' && !filledIds.has(k.toUpperCase()));
          }
          return ids.every((f) => item.xml.xml.includes('>' + f.value + '<'));
        });
        if (mi >= 0) usedM.add(mi);
      }

      // -- PASS 3: messageType-scoped reverse-order pairing --
      if (mi < 0 && mt) {
        for (let k = batch.length - 1; k >= 0; k--) {
          if (!usedM.has(k) && batch[k].query === mt) { mi = k; usedM.add(k); break; }
        }
      }

      if (mi >= 0) {
        out.push(Object.assign(labelFromManifest(batch[mi], { fields: null, formState: item.formState, requestXml: item.xml.xml, transactionId: item.xml.transactionId || item.qId, messageType: mt, ok: true, rmsRequestJson: item.rmsRequestJson, rmsResponse: item.rmsResponse }), { qId: item.qId }));
      } else {
        out.push({ provider, entity: null, query: mt, combo: null, tier: null, expectedKeyRef: null, kind: null, anyField: null, messageType: mt, transactionId: item.xml.transactionId || item.qId, qId: item.qId, requestXml: item.xml.xml, formState: item.formState, rmsRequestJson: item.rmsRequestJson, rmsResponse: item.rmsResponse, capturedAt: new Date().toISOString(), ok: true });
      }
    }
    // Late-indexing guard: the newest submissions can take seconds to appear in the
    // /queries/search index -- a fetch fired right after a run raced 2 Boat rows and broke
    // positional pairing for that family (2026-07-02). When a manifest is present and we
    // collected fewer rows than it expects, re-list and collect until counts match (max 30s).
    if (batch.length && fresh.length < batch.length) {
      const tRetry = Date.now();
      while (fresh.length < batch.length && Date.now() - tRetry < 30000) {
        await new Promise((res) => setTimeout(res, 3000));
        console.log('%c[USx-BULK]', 'color:#fa0', `waiting for late rows: ${fresh.length}/${batch.length}...`);
        let extra = [];
        try {
          const j2 = await fetchJson(window.__usxSearchReq.url, { method: window.__usxSearchReq.method || 'POST', headers: { 'content-type': 'application/json', 'accept': 'application/json' }, body: window.__usxSearchReq.body });
          extra = ((typeof j2 === 'string' ? JSON.parse(j2) : j2).queries || []).filter((q) => q.transaction !== 'RMS');
        } catch (e) { break; }
        for (const q of extra) {
          if (have.has(q.id)) continue;
          if (floorTs) { const ct = Date.parse((q.auditMetadata && q.auditMetadata.createdDateUtc) || ''); if (ct && ct < floorTs) { have.add(q.id); continue; } }
          let xml2 = null;
          try { const d2 = await fetchJson('/federated-search/api/v2/openapi/queries/' + q.id); xml2 = L.extractConnectCicXml(typeof d2 === 'string' ? d2 : JSON.stringify(d2)); } catch (e) {}
          if (!xml2) continue;
          const rms2 = await getRmsPairFor(q.parsedRawQuery);
          fresh.push({ qId: q.id, createdAt: (q.auditMetadata && q.auditMetadata.createdDateUtc) || null, formState: q.parsedRawQuery || null, xml: xml2, rmsRequestJson: rms2 ? rms2.requestJson : null, rmsResponse: rms2 ? rms2.response : null });
          have.add(q.id);
        }
      }
      console.log('%c[USx-BULK]', 'color:#fa0', `late-row wait done: ${fresh.length}/${batch.length}.`);
    }

    const added = fresh.length;
    if (dropped.length) {
      const ids = new Set(loadSeenIds()); dropped.forEach((id) => ids.add(id)); saveSeenIds(Array.from(ids));
      console.log('%c[USx-BULK]', 'color:#fa0', `${dropped.length} pre-run backlog row(s) dropped (older than this run's first submission).`);
    }
    L.triggerDownload('usx_captured_batch_labeled.json', out);
    markSeenAndClear(out);
    try { localStorage.removeItem('__usx_batch'); } catch (e) {}   // manifest consumed by this download
    console.log('%c[USx-BULK]', 'color:#fa0;font-weight:bold', `done. +${added} new, ${out.length} total -> downloaded usx_captured_batch_labeled.json (store + manifest cleared; ids kept for dedup)`);
    return out;
  };

  // RMS RECON round 5 (2026-07-01, post-first-live-test): the DOM-click RMS pairing in
  // __usxBulkFetch is confirmed WORKING but INCONSISTENT -- it found Person's RMS row but
  // missed Vehicle's in the same batch, because it only searches whatever's CURRENTLY rendered
  // in the dex-log table, and with 30+ rows (2 per query: ConnectCic + RMS) accumulating this
  // session, older rows scroll off the visible page. A DOM-independent path would be reliable
  // regardless of page size: IF /queries/search's list items already include RMS-destination
  // entries (not just ConnectCic ones), we could fetch RMS detail via the SAME network call
  // __usxBulkFetch already makes for every item, with no DOM dependency at all. This checks that
  // hypothesis directly instead of guessing.
  window.__usxRmsNetworkRecon = async function () {
    const req = window.__usxSearchReq;
    if (!req) { console.warn('[USx-NET-RECON] no __usxSearchReq captured yet -- load/refresh the dex-log list first.'); return null; }
    let base = {}; try { base = JSON.parse(req.body || '{}'); } catch (e) {}
    const j = await (await fetch(req.url, { method: req.method || 'POST', credentials: 'include', headers: { 'content-type': 'application/json', 'accept': 'application/json' }, body: JSON.stringify(base) })).json();
    const items = (j && j.queries) || [];
    const sample = items.slice(0, 10).map((q) => ({ id: q.id, keys: Object.keys(q), transaction: q.transaction, destination: q.destination, provider: q.provider, parsedRawQuery: q.parsedRawQuery }));
    // Try to find one item that LOOKS like an RMS destination (any field mentioning RMS).
    const rmsLike = items.find((q) => JSON.stringify(q).includes('RMS'));
    let rmsDetail = null;
    if (rmsLike) {
      try { rmsDetail = await (await fetch('/federated-search/api/v2/openapi/queries/' + rmsLike.id, { credentials: 'include', headers: { accept: 'application/json' } })).text(); } catch (e) {}
    }
    const out = { totalItems: items.length, sample, rmsLikeItem: rmsLike || null, rmsDetailRaw: rmsDetail ? rmsDetail.slice(0, 3000) : null };
    console.log('%c[USx-NET-RECON]', 'color:#0cc;font-weight:bold', out);
    console.log('[USx-NET-RECON] report the full object above -- sample shows the list item shape; rmsLikeItem/rmsDetailRaw show whether RMS is fetchable via network alone (no DOM).');
    return out;
  };

  if (location.hash.includes('dex-log')) {
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', 'capture ready. ZERO-CLICK: __usxBulkFetch({maxPages:2, since:"2026-06-29"}). Or __usxCaptureWatch() + click Views. __usxCaptureWatchStop()/Reset to manage. Run __usxDexTableRecon() to inspect an RMS-destination row, then __usxRmsPopupRecon() to see what its "View request" popup actually shows. Run __usxRmsNetworkRecon() to check if RMS is fetchable via network alone (no DOM dependency).');
  }
})();
