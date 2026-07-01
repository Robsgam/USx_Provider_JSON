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

  // BirthDate's segmented-date stepping (activate + arrow-walk to the target, up to ~dozens of
  // presses for year) is by far the slowest fill. Filling it last per test means the fast
  // fields (text, react-select) complete first, and keeps its lengthy operation from
  // overlapping with -- and possibly destabilizing the timing of -- other fields' fills.
  function sortFillsDateLast(fills) {
    return [...fills].sort((a, b) => (/birthdate/i.test(a.fieldId) ? 1 : 0) - (/birthdate/i.test(b.fieldId) ? 1 : 0));
  }

  window.__usxRunOne = async function (desc) {
    if (!desc || !Array.isArray(desc.fills)) { console.error('[USx-DRV] need {fills:[...]}'); return; }
    const orderedFills = sortFillsDateLast(desc.fills);
    const fillResults = [];
    for (const f of orderedFills) {
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

  // Fill a field; on failure wait a longer settle and retry once (React/autoSelect lag, or a
  // react-select whose options hadn't populated yet). Logs a clear message if it still fails --
  // no silent under-fill.
  async function fillWithRetry(fieldId, value, settle) {
    let r = await L.fillField(fieldId, value);
    if (!r || !r.ok) {
      await L.sleep(settle);
      r = await L.fillField(fieldId, value);
      if (!r || !r.ok) console.warn(`[USx-DRV] field "${fieldId}" did not fill (value="${value}") -- react-select may have no matching option, or the field id changed.`);
    }
    return r;
  }

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
    const tests = plan.tests.filter((t) => (t.kind === 'combo' || t.kind === 'any' || t.kind === 'any-field') && (!entityFilter || t.entity === entityFilter));
    if (!tests.length) { console.warn('[USx-DRV] no combo tests for', entityFilter); return; }
    const manifest = []; const results = [];
    for (const t of tests) {
      const fr = [];
      // Normalize fills: PowerShell ConvertTo-Json collapses single-element arrays to bare objects
      const rawFills = t.fills ? (Array.isArray(t.fills) ? t.fills : [t.fills]) : [];
      const fills = sortFillsDateLast(rawFills);
      for (const f of fills) { fr.push(await fillWithRetry(f.fieldId, f.value, dSettle)); await L.sleep(dField); }
      await L.sleep(dSettle);
      const filled = fr.every((r) => r && r.ok);
      // Store the NORMALIZED fills array (not t.fills) -- PowerShell's ConvertTo-Json collapses
      // a single-element array to a bare object, and idFills() downstream (capture.js) expects
      // a real array; storing the raw plan value here crashed __usxBulkFetch mid-batch.
      manifest.push({ provider: plan.provider, entity: t.entity, query: t.query, comboKeyRef: t.comboKeyRef, expectedKeyRef: t.expectedKeyRef, tier: t.tier, kind: t.kind, anyField: t.anyField || null, fills: fills, underFilled: !filled, n: t.n });
      const sent = clickSendClear();
      results.push({ n: t.n, combo: t.comboKeyRef, filled, sent });
      if (!filled) console.warn(`[USx-DRV] T${t.n} ${t.entity} ${t.comboKeyRef}: submitted UNDER-FILLED (a field failed to fill) -- capture records it, but verify this combo.`);
      console.log('%c[USx-DRV]', 'color:#06c', `T${t.n} ${t.entity} ${t.comboKeyRef}: ${sent.ok ? 'submitted' : 'NOT submitted (' + sent.err + ')'}`);
      await L.sleep(dBetween);
    }
    try { localStorage.setItem('__usx_batch', JSON.stringify(manifest)); } catch (e) {}
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', `plan run complete: ${manifest.length} queries submitted. Go to /admin/dex-log and run __usxCaptureBatch().`, results);
    return results;
  };

  // ---------------------------------------------------------------------------
  // RMS-SIDE RECON (spike, 2026-07-01): capture.js/usx_lib.js only ever scrape the
  // CommSys/ConnectCic dex-log wire XML -- nothing touches Mark43 RMS query/result data at
  // all (e.g. the "Mock results processed" / "Query execution failed" failure class, which so
  // far has only ever been caught by someone manually screenshotting the RMS UI). Testing
  // already runs on "USx tenant, RMS client (default bundle)" -- the RMS query fires and its
  // result/error renders in THIS SAME universal-search page, not a separate system -- but the
  // exact DOM shape of wherever that renders has never been recon'd (only dex-log XML has).
  // Run this right after a submit (__usxRunOne / manual Send) to find it from real evidence
  // instead of guessing a selector (see selectReactSelect's substring-highlight-fragment bug
  // earlier this session for what guessing costs: a live bug report + a second round-trip).
  //
  // USAGE: submit a query (a known repro like NJ Vehicle plate ABC123, which has documented
  // Mock-results history), then run __usxRmsRecon() and report the full console output.
  window.__usxRmsRecon = function () {
    // Outermost-only filter (drops nested duplicates/fragments) -- same pattern as
    // selectReactSelect's option matching, reused here for the same reason.
    function outermostOnly(nodes) {
      const arr = [...nodes];
      return arr.filter((n) => !arr.some((other) => other !== n && other.contains(n)));
    }
    function snap(el) {
      return {
        tag: el.tagName,
        id: el.id || null,
        cls: (el.className || '').toString().slice(0, 80),
        testId: el.getAttribute && (el.getAttribute('data-testid') || el.getAttribute('data-test-id')) || null,
        role: el.getAttribute && el.getAttribute('role') || null,
        text: (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 200)
      };
    }

    // 1) Toasts/alerts/banners -- likely home for "Mock results processed" / "Query execution
    // failed" style one-line failure messages (Chakra toasts commonly use role=status/alert).
    const alertSelectors = '[role="alert"], [role="status"], [aria-live], .chakra-toast, .chakra-alert, [class*="toast"], [class*="Toast"], [class*="alert"], [class*="Alert"]';
    const alerts = outermostOnly(document.querySelectorAll(alertSelectors)).map(snap).filter((s) => s.text);

    // 2) Any element whose text matches known failure/result phrasing, regardless of container
    // -- catches the message even if it's NOT in a toast-like element (e.g. inline in a card).
    const phraseRe = /mock result|execution failed|query execution|no results?|not found|record found|results? \(\d+\)|error/i;
    const phraseHits = outermostOnly(
      [...document.querySelectorAll('div, span, p, li, td')].filter((el) => {
        const t = (el.textContent || '').trim();
        return t && t.length < 300 && phraseRe.test(t);
      })
    ).map(snap).slice(0, 20);

    // 3) Every data-testid on the page right now -- the app already tags form fields this way
    // (usx_lib's DOM-id-equals-fieldId trick); a results panel may carry similar tags.
    const testIdEls = outermostOnly(document.querySelectorAll('[data-testid], [data-test-id]')).map(snap).slice(0, 40);

    // 4) Broad structural scan: top-level regions under the main content area, so we can see
    // what's THERE even if none of the above heuristics hit (e.g. a results panel with no
    // role/testid/matching phrase -- just a plain rendered record).
    const main = document.querySelector('main, [role="main"]') || document.body;
    const topLevel = [...main.children].map(snap).slice(0, 30);

    const out = { alerts, phraseHits, testIdEls, topLevel };
    console.log('%c[USx-RMS-RECON]', 'color:#c60;font-weight:bold', out);
    console.log('[USx-RMS-RECON] report the full object above (expand in DevTools or copy via console) so real selectors can be written from evidence.');
    return out;
  };

  if (location.hash.includes('universal-search')) {
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', 'driver ready. __usxRunOne({...}) = one combo; __usxRunPlan(plan,"Vehicle") = whole entity. After a submit, run __usxRmsRecon() to help find the RMS result/error panel.');
  }
})();
