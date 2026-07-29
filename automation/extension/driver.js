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
  //
  // POLLS for the button to become ENABLED instead of checking once. The platform enables Send
  // asynchronously after re-validating the form, and a single check races that -- the fixed
  // dSettle pause before the call is not always enough.
  // EVIDENCE (2026-07-29, FL_FCIC v7.12 Boat): T71 (Hull+decalNumber) and T73 (Hull+ImageIndicator)
  // both reported "no enabled Send button", yet T74 -- whose fill is a strict SUPERSET of both --
  // submitted fine, and test_commsys confirmed each fill fires FBQBoatHullIdNumber with both
  // fields present in that combo's any[]. So the fills were valid and the miss was pure timing.
  // fillWithRetry() above already retried; the submit step was the one place that did not.
  //
  // The failure message now distinguishes the two very different causes, because "no enabled Send
  // button" sent us looking for a config defect when it was a race:
  //   present-but-disabled -> the FORM rejected the input (validation/maxLength/required)
  //   absent entirely      -> wrong page, or the button markup changed
  async function clickSendClear(waitMs) {
    const budget = waitMs || 6000;
    const deadline = Date.now() + budget;
    for (;;) {
      const sc = [...document.querySelectorAll('button')].find((b) => /send\s*&\s*clear/i.test(b.textContent || '') && !b.disabled);
      if (sc) { sc.click(); return { ok: true, mode: 'send+clear' }; }
      const s = [...document.querySelectorAll('button')].find((b) => (b.textContent || '').trim() === 'Send' && !b.disabled);
      if (s) { s.click(); return { ok: true, mode: 'send (no clear)' }; }
      if (Date.now() >= deadline) break;
      await L.sleep(250);
    }
    const disabledSend = [...document.querySelectorAll('button')].some((b) => /send/i.test(b.textContent || '') && b.disabled);
    return {
      ok: false,
      err: disabledSend
        ? `Send present but still DISABLED after ${budget}ms -- the form rejected this input (check field validation / maxLength / a required field that did not fill)`
        : `no Send button found in the DOM after ${budget}ms -- wrong page, or the button markup changed`
    };
  }

  // Run a whole tier plan for ONE entity in a loop. `plan` = the TEST_PLAN.json object
  // (emit_test_plan.ps1); entityFilter = e.g. 'Vehicle'. Fills each combo's fields (auto-selects
  // the query), clicks "Send & Clear Form" (clears for the next), and records a batch manifest in
  // localStorage so the capture page can correlate each dex-log row back to its combo.
  // guardrail included (2026-07-01): its fills[] already contains BOTH competing identifier
  // fields (emit_test_plan.ps1's Get-GuardrailTests) -- filling+submitting it the same way as
  // combo/any/any-field gets formState/RMS captured automatically instead of requiring a manual
  // popup-capture workaround (which loses formState -- the only proof both fields were entered).
  window.__usxRunPlan = async function (plan, entityFilter, opts) {
    if (!plan || !Array.isArray(plan.tests)) { console.error('[USx-DRV] pass the TEST_PLAN object: __usxRunPlan(plan, "Vehicle")'); return; }
    opts = opts || {};
    // Deliberately unhurried so React state + autoSelect keep up. Tune via opts if needed.
    const dField = opts.fieldDelay || 450;   // pause after each field
    const dSettle = opts.settle || 900;      // pause after all fields, before submit (let autoSelect enable)
    const dBetween = opts.between || 1700;    // pause after submit/clear, before next combo
    const tests = plan.tests.filter((t) => (t.kind === 'combo' || t.kind === 'any' || t.kind === 'any-field' || t.kind === 'guardrail') && (!entityFilter || t.entity === entityFilter));
    if (!tests.length) { console.warn('[USx-DRV] no combo tests for', entityFilter); return; }

    // RENDER SNAPSHOT, automatically, as step 0 of every entity run (2026-07-29). Rob's
    // correction: "we built the extension and watcher tools to automate this" -- a render gate
    // that needs a hand-typed console call is not automation, it is a chore that will be
    // skipped. Right here is also the ONLY correct moment to snapshot: the entity form is
    // confirmed on screen and still PRISTINE (no fills, no submits), so the captured labels
    // and field order are the officer's first view. Downloads via the SW bridge and is filed
    // by watch_captures.ps1 -> import_render_snapshot.ps1. Never blocks the run: a render
    // capture failure must not cost a 79-test sweep.
    if (entityFilter && typeof window.__usxCaptureRender === 'function') {
      try {
        const rp = window.__usxCaptureRender(entityFilter);
        if (rp && rp.labelStrategyTally) {
          console.log('%c[USx-DRV]', 'color:#a0a', `render snapshot captured for ${entityFilter} before any fill (${rp.fieldCount} field(s))`);
        }
      } catch (e) { console.warn('[USx-DRV] render snapshot failed (continuing with the test run):', e); }
      await L.sleep(600);   // let the download settle before the first fill mutates the form
    }

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
      manifest.push({ provider: plan.provider, entity: t.entity, query: t.query, comboKeyRef: t.comboKeyRef, expectedKeyRef: t.expectedKeyRef, tier: t.tier, kind: t.kind, anyField: t.anyField || null, fills: fills, underFilled: !filled, n: t.n, submittedAt: new Date().toISOString() });
      const sent = clickSendClear();
      results.push({ n: t.n, combo: t.comboKeyRef, filled, sent });
      if (!filled) console.warn(`[USx-DRV] T${t.n} ${t.entity} ${t.comboKeyRef}: submitted UNDER-FILLED (a field failed to fill) -- capture records it, but verify this combo.`);
      console.log('%c[USx-DRV]', 'color:#06c', `T${t.n} ${t.entity} ${t.comboKeyRef}: ${sent.ok ? 'submitted' : 'NOT submitted (' + sent.err + ')'}`);
      await L.sleep(dBetween);
    }
    // APPEND to the session manifest (cleared by capture.js after a successful download):
    // one Fetch after several entity runs then has every submission's manifest entry, so
    // positional pairing works for the whole batch (overwrite left only the last entity's).
    try {
      let prior = []; try { prior = JSON.parse(localStorage.getItem('__usx_batch') || '[]'); } catch (e) {}
      localStorage.setItem('__usx_batch', JSON.stringify(prior.concat(manifest)));
    } catch (e) {}
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

  // FOLLOW-UP recon (2026-07-01, round 2): __usxRmsRecon found it -- APP_WRAPPER's flattened
  // text showed "...1HGCM82633A123456RMS(No Returns)..." -- a per-query search-history list
  // where each row is IDENTIFIER + "RMS" + a status like "(No Returns)". That confirms RMS DOES
  // fire alongside every CommSys query and its status renders inline on THIS page. This finds
  // each row by locating the leaf-most element containing the standalone word "RMS", then walks
  // up a few ancestor levels dumping outerHTML (truncated) so the real row structure -- how
  // identifier/RMS/status are split into DOM nodes, what class the row/status carry, whether a
  // data-* attribute correlates it to a transaction id -- comes from evidence, not another guess.
  window.__usxRmsRowRecon = function () {
    // Leaf-most elements whose OWN text (not descendants') contains standalone "RMS".
    const rmsWordRe = /\bRMS\b/;
    const candidates = [...document.querySelectorAll('*')].filter((el) => {
      if (el.children.length > 0) return false; // leaf only -- skip containers
      return rmsWordRe.test(el.textContent || '');
    });
    const rows = candidates.slice(0, 6).map((leaf) => {
      const chain = [];
      let node = leaf;
      for (let i = 0; i < 6 && node; i++) {
        chain.push({
          tag: node.tagName,
          id: node.id || null,
          cls: (node.className || '').toString().slice(0, 100),
          dataAttrs: node.attributes ? [...node.attributes].filter((a) => a.name.startsWith('data-')).map((a) => a.name + '=' + a.value).join(', ') : '',
          outerHTML: (node.outerHTML || '').slice(0, 500)
        });
        node = node.parentElement;
      }
      return chain;
    });
    console.log('%c[USx-RMS-ROW-RECON]', 'color:#c06;font-weight:bold', { matchCount: candidates.length, rows });
    console.log('[USx-RMS-ROW-RECON] report the full object above -- each entry in "rows" is one RMS-row leaf + 6 ancestor levels (tag/class/data-attrs/outerHTML).');
    return { matchCount: candidates.length, rows };
  };

  // -------------------------------------------------------------------------
  // RUN ALL (2026-07-02): one click drives the WHOLE plan -- switches the entity picker
  // (the page's only generic react-select-N-input; every QIF field input has its fieldId
  // as its DOM id), waits for that entity's form to render, runs its tests, then moves on.
  // Finishes by navigating to dex-log and triggering the batch fetch.
  function findEntityPicker() {
    return [...document.querySelectorAll('input[class*="select__input"]')]
      .find((i) => /^react-select-\d+-input$/.test(i.id)) || null;
  }
  async function switchEntity(entityName, probeFieldId) {
    const picker = findEntityPicker();
    if (!picker) return { ok: false, err: 'entity picker not found' };
    const r = await L.selectReactSelect(picker.id, entityName);   // types, matches, clicks
    if (!r || !r.ok) return { ok: false, err: `picker did not confirm "${entityName}" (got: ${r && r.display})` };
    // wait for the target form: its first fill fieldId must appear in the DOM
    const t0 = Date.now();
    while (Date.now() - t0 < 8000) {
      if (!probeFieldId || L.q(probeFieldId)) return { ok: true };
      await L.sleep(250);
    }
    return { ok: false, err: `form for ${entityName} did not render (probe field ${probeFieldId} missing)` };
  }
  window.__usxRunAll = async function (plan, opts) {
    if (!plan || !Array.isArray(plan.tests)) { console.error('[USx-RUNALL] pass the TEST_PLAN object'); return; }
    opts = opts || {};
    const entities = [...new Set(plan.tests.map((t) => t.entity).filter(Boolean))];
    const summary = [];
    for (const ent of entities) {
      const firstTest = plan.tests.find((t) => t.entity === ent && Array.isArray(t.fills) && t.fills.length);
      const probe = firstTest ? (Array.isArray(firstTest.fills) ? firstTest.fills[0].fieldId : firstTest.fills.fieldId) : null;
      console.log('%c[USx-RUNALL]', 'color:#06c;font-weight:bold', `switching to ${ent}...`);
      const sw = await switchEntity(ent, probe);
      if (!sw.ok) { console.error('[USx-RUNALL]', sw.err, '-- STOPPING (run the remaining entities manually).'); summary.push({ entity: ent, error: sw.err }); break; }
      await L.sleep(800);
      const results = await window.__usxRunPlan(plan, ent);
      const ok = results ? results.filter((r) => r.sent && r.sent.ok).length : 0;
      summary.push({ entity: ent, submitted: ok, of: results ? results.length : 0 });
    }
    console.log('%c[USx-RUNALL]', 'color:#06c;font-weight:bold', 'all entities done:', summary);
    if (opts.autoFetch !== false) {
      console.log('%c[USx-RUNALL]', 'color:#06c', 'navigating to dex-log for the batch fetch...');
      location.hash = '#/admin/dex-log';
      const t0 = Date.now();
      while (Date.now() - t0 < 15000 && !(window.__usxBulkFetch && window.__usxSearchReq)) { await L.sleep(400); }
      if (window.__usxBulkFetch) {
        let n = 0; try { n = JSON.parse(localStorage.getItem('__usx_batch') || '[]').length; } catch (e) {}
        const o = { maxPages: 10, since: new Date().toISOString().slice(0, 10) }; if (n > 0) o.maxNew = n;
        await window.__usxBulkFetch(o);
      } else {
        console.warn('[USx-RUNALL] bulk fetch not ready -- click ⚡ Fetch results on the dex-log panel.');
      }
    }
    return summary;
  };

  // -------------------------------------------------------------------------
  // TENANT PICKLIST SCOPE (2026-07-02): dump every dropdown's ACTUAL option list.
  // Code-table contents are tenant data -- the same codeTypeCategory/Source pair serves
  // different codes per tenant (NJ GunMake = numeric NIBRS '03 - Armalite...', HI/CA =
  // NCIC 'IMI'), and there is no code-types API: options exist only in the rendered DOM.
  // Usage: paste providers/<P>/logs/<P>_PICKLIST_SCOPE.json as `scope`, render the entity
  // form, then __usxScopePicklists(scope, 'Vehicle'). One download per entity; no
  // localStorage accumulation (the stale-store bug class stays dead).
  window.__usxScopePicklists = async function (scope, entityFilter) {
    if (!scope || !Array.isArray(scope.fields)) { console.error('[USx-SCOPE] pass the PICKLIST_SCOPE object: __usxScopePicklists(scope, "Vehicle")'); return; }
    if (!entityFilter) { console.error('[USx-SCOPE] entityFilter required (one entity form at a time)'); return; }
    const CAP = 500;
    const fields = scope.fields.filter((f) => f.entity === entityFilter);
    if (!fields.length) { console.warn('[USx-SCOPE] no select fields in scope for', entityFilter); return; }
    // Wrong-form guard: scoping Vehicle while the Firearm form is rendered produced a
    // useless all-errors capture (2026-07-02). If NONE of the scope's fields exist in the
    // DOM, the wrong entity form is up -- abort instead of downloading garbage.
    const present = fields.filter((f) => L.q(f.fieldId)).length;
    if (present === 0) {
      console.error(`[USx-SCOPE] 0 of ${fields.length} ${entityFilter} fields found in the DOM -- is the ${entityFilter} form rendered? Aborting (nothing downloaded).`);
      return;
    }
    const out = [];
    const poll = async (fn, ms, step) => { const t0 = Date.now(); let r; while (!(r = fn()) && Date.now() - t0 < ms) { await L.sleep(step); } return r; };
    const setVal = (input, v) => {
      Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(input, v);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    };

    for (const f of fields) {
      const rec = { entity: f.entity, fieldId: f.fieldId, label: f.label || null, codeTypeCategory: f.codeTypeCategory || null, codeTypeSource: f.codeTypeSource || null, count: 0, truncated: false, options: [], error: null };
      try {
        const input = L.q(f.fieldId);
        if (!input) { rec.error = 'field not found in DOM'; out.push(rec); continue; }
        const control = input.closest('.arc-select__control') || input.closest('[class*="control"]');
        input.focus();
        (control || input).dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
        input.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', keyCode: 40, bubbles: true }));
        const opened = await poll(() => document.querySelector('[class*="select__menu"]'), 2500, 100);
        if (!opened) { rec.error = 'menu never opened'; out.push(rec); continue; }
        await L.sleep(400); // let network-backed lists settle
        const ariaControls = input.getAttribute('aria-controls') || (control && control.getAttribute('aria-controls'));
        const scopeRoot = () => (ariaControls && document.getElementById(ariaControls)) || document.querySelector('[class*="select__menu"]') || document;
        const readOpts = () => {
          const all = [...scopeRoot().querySelectorAll('[class*="select__option"]')];
          // outermost only -- substring-highlight spans nest inside real rows; role="option" matches nothing
          return all.filter((o) => !all.some((other) => other !== o && other.contains(o))).map((o) => (o.textContent || '').trim());
        };
        // These arc-selects load options when TYPING triggers the search (fills work because
        // they type); opening alone can render an empty menu (live-confirmed 2026-07-02:
        // all 4 HI Vehicle selects read 0 options on open). Trigger the load with an
        // empty-string input event and poll for the first option.
        if (!readOpts().length) {
          setVal(input, '');
          await poll(() => readOpts().length, 3000, 150);
        }
        if (!readOpts().length) {           // last resort: type+erase to kick the async source
          setVal(input, ' ');
          await L.sleep(300);
          setVal(input, '');
          await poll(() => readOpts().length, 3000, 150);
        }
        // Virtualization/paging guard: scroll the menu list to the bottom until the option set
        // stabilizes or CAP. The async source pages (~300/fetch, live-confirmed: GunMake and
        // ArticleTypeCode both plateaued at exactly 300), so wait generously between scrolls
        // and flag a page-boundary plateau as truncated -- the list beyond it is invisible to
        // the DOM (the endpoint-direct probe is the complete answer).
        const seen = new Set(readOpts());
        const listEl = scopeRoot().querySelector('[class*="menu-list"], [class*="MenuList"]') || scopeRoot();
        let stable = 0;
        while (seen.size < CAP && stable < 3) {
          const before = seen.size;
          if (listEl && listEl.scrollHeight > listEl.clientHeight) { listEl.scrollTop = listEl.scrollHeight; await L.sleep(650); }
          readOpts().forEach((t) => seen.add(t));
          stable = (seen.size === before) ? stable + 1 : 0;
          if (!listEl || listEl.scrollHeight <= listEl.clientHeight) break;
        }
        await L.sleep(1000);                       // one last chance for a slow page-load
        readOpts().forEach((t) => seen.add(t));
        rec.options = [...seen].slice(0, CAP);
        rec.count = seen.size;
        rec.truncated = seen.size >= CAP || (seen.size >= 200 && seen.size % 100 === 0);   // hard cap or page-boundary plateau
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', keyCode: 27, bubbles: true }));
        input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', keyCode: 27, bubbles: true }));
        await L.sleep(300);
      } catch (e) { rec.error = String(e); }
      console.log('%c[USx-SCOPE]', 'color:#0aa', `${f.fieldId}: ${rec.count} option(s)${rec.truncated ? ' (TRUNCATED at ' + CAP + ')' : ''}${rec.error ? ' ERROR: ' + rec.error : ''}`);
      out.push(rec);
    }

    // Cross-check: selects rendered on the form but absent from the scope plan (and note misses above).
    const rendered = [...document.querySelectorAll('input.arc-select__input, input[class*="select__input"]')].map((i) => i.id).filter(Boolean);
    const scoped = new Set(fields.map((f) => f.fieldId));
    const notInScope = rendered.filter((id) => !scoped.has(id));
    if (notInScope.length) console.warn('[USx-SCOPE] rendered selects NOT in scope plan:', notInScope);

    const payload = { provider: scope.provider || L.providerFromHost(), version: scope.version || null, entity: entityFilter, capturedAt: new Date().toISOString(), renderedSelectsNotInScope: notInScope, fields: out };
    L.triggerDownload(`usx_picklists_${payload.provider}_${entityFilter}.json`, payload);
    console.log('%c[USx-SCOPE]', 'color:#0aa;font-weight:bold', `${entityFilter}: ${out.length} field(s) scoped -> downloaded usx_picklists_${payload.provider}_${entityFilter}.json`);
    return payload;
  };

  // -------------------------------------------------------------------------
  // RENDER SNAPSHOT (2026-07-29, Rob: "render should be classified with the labels and
  // field ordering"). Walks the RENDERED form and records, in visual order, every field's
  // DOM id, its visible label, its control type, and its card/row grouping. Compared against
  // the JSON-derived expected manifest by tools/audit_render_fidelity.ps1.
  //
  // This is its own evidence channel -- no fill, no submit, no dex-log. A render test has no
  // CommSys request, so it cannot ride the wire-XML capture pipeline (and forcing it in would
  // hit the phantom-owed trap in _content_match.ps1). One download per entity, like
  // __usxScopePicklists.
  //
  // LABEL DOM SHAPE IS NOT YET RECON'D. Only the dex-log XML and the fill controls have ever
  // been reverse-engineered on this platform; the input form's label markup has not. So each
  // field tries several strategies in order and RECORDS WHICH ONE WON (labelStrategy) plus a
  // strategyTally in the payload. Read that tally after the first live run: if one strategy
  // wins everywhere, simplify to it; if a field falls through to 'none', its markup needs a
  // look before the gate can be trusted for that field. Do NOT delete the fallbacks based on
  // a guess about the DOM.
  window.__usxCaptureRender = function (entityName) {
    if (!entityName) { console.error('[USx-RENDER] entity required: __usxCaptureRender("Vehicle")'); return; }

    const norm = (s) => (s || '').replace(/\s+/g, ' ').trim();

    // Strategies, most authoritative first. Each returns a label string or ''.
    function resolveLabel(el) {
      const id = el.id;
      // 1. <label for="fieldId"> -- the accessible, standard association
      if (id) {
        const lf = document.querySelector('label[for="' + CSS.escape(id) + '"]');
        if (lf && norm(lf.textContent)) return { label: norm(lf.textContent), strategy: 'label[for]' };
      }
      // 2. aria-labelledby -> referenced element's text
      const alb = el.getAttribute('aria-labelledby');
      if (alb) {
        const t = alb.split(/\s+/).map((x) => { const n = document.getElementById(x); return n ? norm(n.textContent) : ''; }).filter(Boolean).join(' ');
        if (t) return { label: norm(t), strategy: 'aria-labelledby' };
      }
      // 3. an ancestor form-field wrapper containing a <label>
      let p = el.parentElement, hops = 0;
      while (p && hops < 6) {
        const lab = p.querySelector(':scope > label, :scope > * > label');
        if (lab && norm(lab.textContent)) return { label: norm(lab.textContent), strategy: 'ancestor label (' + hops + ' hops)' };
        p = p.parentElement; hops++;
      }
      // 4. aria-label on the control itself
      const al = el.getAttribute('aria-label');
      if (al && norm(al)) return { label: norm(al), strategy: 'aria-label' };
      // 5. placeholder -- last resort; NOTE placeholders are documented as NOT rendered by this
      //    platform (BUILD_RULES), so a hit here is itself suspicious and worth reporting.
      const ph = el.getAttribute('placeholder');
      if (ph && norm(ph)) return { label: norm(ph), strategy: 'placeholder (SUSPECT)' };
      return { label: '', strategy: 'none' };
    }

    function controlType(el) {
      if (el.classList && [...el.classList].some((c) => /select__input/.test(c))) return 'FormSelect';
      if (el.closest && el.closest('[class*="select__control"]')) return 'FormSelect';
      if (el.getAttribute('type') === 'checkbox') return 'FormCheckbox';
      if (el.closest && el.closest('[class*="datepicker"], [class*="date-field"], [class*="DateField"]')) return 'FormDate';
      if (el.getAttribute('role') === 'spinbutton') return 'FormDate';
      return 'FormInput';
    }

    // Every candidate control on the page, in DOCUMENT ORDER (querySelectorAll guarantees it),
    // which is the visual order the officer reads.
    const controls = [...document.querySelectorAll('input[id], select[id], textarea[id]')]
      .filter((el) => el.id && el.offsetParent !== null);   // offsetParent null => not rendered/hidden

    if (!controls.length) {
      console.error('[USx-RENDER] no rendered controls with ids found -- is the ' + entityName + ' form up? Aborting (nothing downloaded).');
      return;
    }

    // Group into cards/rows by DOM ancestry. Card/row IDs are BUILD-TIME Craft.js ids and do
    // NOT exist in the DOM, so ids are emitted as null and the audit pairs cards by INDEX and
    // compares TITLES -- it explicitly skips id comparison when the actual side has none.
    const cardOf = (el) => el.closest('[class*="card" i], section, fieldset') || document.body;
    const rowOf = (el) => el.closest('[class*="row" i], [class*="grid" i]') || cardOf(el);
    const cardTitle = (cardEl) => {
      if (!cardEl) return null;
      const h = cardEl.querySelector('h1,h2,h3,h4,h5,h6,[class*="title" i],[class*="header" i]');
      return h ? norm(h.textContent) : null;
    };

    const cards = [];
    const cardIdx = new Map();
    const rowIdx = new Map();
    const tally = {};

    for (const el of controls) {
      const cEl = cardOf(el), rEl = rowOf(el);
      if (!cardIdx.has(cEl)) { cardIdx.set(cEl, cards.length); cards.push({ id: null, title: cardTitle(cEl), rows: [] }); }
      const card = cards[cardIdx.get(cEl)];
      const rKey = cEl === rEl ? cEl : rEl;
      if (!rowIdx.has(rKey)) { rowIdx.set(rKey, card.rows.length); card.rows.push({ id: null, templateColumns: [], hidden: false, fields: [] }); }
      const row = card.rows[rowIdx.get(rKey)];
      const r = resolveLabel(el);
      tally[r.strategy] = (tally[r.strategy] || 0) + 1;
      row.fields.push({
        fieldId: el.id, label: r.label, type: controlType(el),
        hidden: false, initialValue: (el.value === '' ? null : el.value),
        labelStrategy: r.strategy
      });
    }

    const payload = {
      provider: L.providerFromHost(), entity: entityName, capturedAt: new Date().toISOString(),
      capturedBy: '__usxCaptureRender', fieldCount: controls.length,
      labelStrategyTally: tally, cards: cards
    };
    const unlabeled = controls.length - (tally['label[for]'] || 0) - (tally['aria-labelledby'] || 0) - (tally['ancestor label (0 hops)'] || 0);
    L.triggerDownload('usx_render_' + payload.provider + '_' + entityName + '.json', payload);
    console.log('%c[USx-RENDER]', 'color:#a0a;font-weight:bold',
      entityName + ': ' + controls.length + ' field(s) in ' + cards.length + ' card(s) -> downloaded usx_render_' +
      payload.provider + '_' + entityName + '.json');
    console.log('%c[USx-RENDER]', 'color:#a0a', 'label strategy tally (read this -- the label DOM shape is not yet recon\'d):', tally);
    if (tally['none']) console.warn('[USx-RENDER] ' + tally['none'] + ' field(s) resolved NO label -- their markup needs a look before the gate can be trusted.');
    if (tally['placeholder (SUSPECT)']) console.warn('[USx-RENDER] ' + tally['placeholder (SUSPECT)'] + ' field(s) fell through to placeholder, which this platform does not render -- suspect.');
    return payload;
  };

  if (location.hash.includes('universal-search')) {
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', 'driver ready. __usxRunOne({...}) = one combo; __usxRunPlan(plan,"Vehicle") = whole entity; __usxScopePicklists(scope,"Vehicle") = dump dropdown options; __usxCaptureRender("Vehicle") = render snapshot (labels + field order). After a submit, run __usxRmsRecon() then __usxRmsRowRecon() to help find the RMS result/error row structure.');
  }
})();
