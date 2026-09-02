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
  // BUDGET RAISED 6000 -> 20000 AND THE DIAGNOSIS CORRECTED (2026-08-04).
  // The 6000ms budget produced 13 "still DISABLED" reports across NJ/TX/CA/HI/AZ on 2026-08-03/04.
  // EVERY ONE cleared on a plain re-run with no build change, and the tenant logged
  // "[Intervention] Slow network" during the failing runs -- so the button was still settling, not
  // refusing. Not one was ever reproducible.
  //
  // The old message was actively harmful: "the form rejected this input (check field validation /
  // maxLength / a required field that did not fill)" states a CAUSE it has not established, and it
  // sent us hunting a config defect every time. A disabled Send is ambiguous between "the form
  // rejects this" and "the form has not caught up yet", and after 13-for-13 recoveries latency is
  // the FIRST hypothesis, not the second. A tool must not assert the cause it happens to have
  // been written to suspect.
  //
  // Also re-checks ONE more time after the deadline with a longer settle, so the common case
  // (button enables at ~20.2s under load) costs a retry instead of a whole re-run of the entity.
  async function clickSendClear(waitMs) {
    const budget = waitMs || 20000;
    const deadline = Date.now() + budget;
    const findEnabled = () => {
      const sc = [...document.querySelectorAll('button')].find((b) => /send\s*&\s*clear/i.test(b.textContent || '') && !b.disabled);
      if (sc) return { btn: sc, mode: 'send+clear' };
      const s = [...document.querySelectorAll('button')].find((b) => (b.textContent || '').trim() === 'Send' && !b.disabled);
      if (s) return { btn: s, mode: 'send (no clear)' };
      return null;
    };
    for (;;) {
      const hit = findEnabled();
      if (hit) { hit.btn.click(); return { ok: true, mode: hit.mode }; }
      if (Date.now() >= deadline) break;
      await L.sleep(250);
    }
    // Grace retry -- one longer settle before calling it a failure.
    await L.sleep(3000);
    const late = findEnabled();
    if (late) { late.btn.click(); return { ok: true, mode: late.mode + ' (late, after grace retry)' }; }

    const disabledSend = [...document.querySelectorAll('button')].some((b) => /send/i.test(b.textContent || '') && b.disabled);
    return {
      ok: false,
      err: disabledSend
        ? `Send still DISABLED after ${budget}ms + 3000ms grace. MOST LIKELY LATENCY -- 13 of 13 such reports on 2026-08-03/04 cleared on a plain re-run with no build change (tenant logged "[Intervention] Slow network"). RE-RUN THIS TEST BEFORE INVESTIGATING THE BUILD. If it fails a second time, THEN suspect the form rejecting the input (field validation / maxLength / a required field that did not fill).`
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

    // RE-ENTRANCY LOCK. There was none, and a second Run press started a SECOND concurrent walk
    // over the SAME form -- the two runs filling and submitting on top of each other.
    // Live-caught on the CA_eSUN v2.1 sweep 2026-09-02, where the console interleaved
    //   T1 T2 T3 T4  T1  T5  T2  T6  T3  T7  T4  T8  T5 ...
    // and produced a whole run of anomalies that all LOOKED like build defects: BirthDate "did not
    // fill" (the other run had cleared the form mid-fill), T8 submitting in one walk and not the
    // other, and NameAddressIn -- registered unreachable across five prior runs -- appearing to
    // submit for the first time ever because another walk's fields were sitting on the form.
    // Operator's words: "the tests are a mess". They were, and none of it was the JSON.
    // This is refused rather than queued ON PURPOSE: a queued second run would silently double
    // every dex-log row and re-create the manifest-vs-rows mismatch that caused three fabricated
    // batches earlier the same day.
    if (window.__usxRunInFlight) {
      console.error('%c[USx-DRV]', 'color:#c00;font-weight:bold',
        `A RUN IS ALREADY IN PROGRESS (${window.__usxRunInFlight}). This second run was REFUSED -- ` +
        `two concurrent runs fill the same form on top of each other and every result from both is ` +
        `untrustworthy. Wait for "plan run complete", or reload the tab to clear a stuck run.`);
      return null;
    }
    window.__usxRunInFlight = (entityFilter || 'ALL') + ' @ ' + new Date().toLocaleTimeString();

    opts = opts || {};
    // Deliberately unhurried so React state + autoSelect keep up. Tune via opts if needed.
    const dField = opts.fieldDelay || 450;   // pause after each field
    const dSettle = opts.settle || 900;      // pause after all fields, before submit (let autoSelect enable)
    const dBetween = opts.between || 1700;    // pause after submit/clear, before next combo
    const tests = plan.tests.filter((t) => (t.kind === 'combo' || t.kind === 'any' || t.kind === 'any-field' || t.kind === 'guardrail' || t.kind === 'value-strip') && (!entityFilter || t.entity === entityFilter));
    // RELEASE THE LOCK ON THIS EXIT TOO. A lock that is only released on the happy path is worse
    // than no lock: one no-op run would wedge the button until a tab reload.
    if (!tests.length) { window.__usxRunInFlight = null; console.warn('[USx-DRV] no combo tests for', entityFilter); return; }
    const manifest = []; const results = []; const notSent = [];
    for (const t of tests) {
      const fr = [];
      // Normalize fills: PowerShell ConvertTo-Json collapses single-element arrays to bare objects
      const rawFills = t.fills ? (Array.isArray(t.fills) ? t.fills : [t.fills]) : [];
      const fills = sortFillsDateLast(rawFills);
      for (const f of fills) { fr.push(await fillWithRetry(f.fieldId, f.value, dSettle)); await L.sleep(dField); }
      await L.sleep(dSettle);
      const filled = fr.every((r) => r && r.ok);
      // MUST await -- clickSendClear is async (it polls up to 6s for Send to enable). Calling it
      // bare returns a Promise, so `sent.ok`/`sent.err` are both undefined: every test logs
      // "NOT submitted (undefined)" even when the click lands, and the run does not wait for the
      // submit to happen before filling the next combo. Live-caught on the TX v4.14 Vehicle run
      // 2026-07-30 (all 7 tests reported NOT submitted while the fills were visibly working).
      const sent = await clickSendClear();
      results.push({ n: t.n, combo: t.comboKeyRef, filled, sent });

      // A MANIFEST ENTRY IS A CLAIM THAT A QUERY WAS SENT. Only write one if it WAS.
      // This push used to sit ABOVE clickSendClear(), so every test entered the manifest whether
      // or not it ever submitted. capture.js then KEEPS unpaired entries by design (they may be
      // late dex-log rows), so a combo that can NEVER submit accumulated forever and got
      // positionally paired onto unrelated wire rows -- manufacturing evidence.
      // Cost of not having this, all on 2026-09-02: three fabricated batches on CA_eSUN. The worst
      // held 19 records of which 8 were labelled 'NameAddressIn', a combo that reported
      // "NOT submitted" on 4 tests x 2 runs and was sent ZERO times; only 2 of those 8 carried a
      // Name on the wire at all, the rest carried VIN or Plate, and both records labelled
      // 'VPNameBirthDateIn' carried Plate wire. Every one was caught by hand, which is not a gate.
      // The late-row case this does NOT break: a SUBMITTED query whose dex-log row has not appeared
      // yet still gets its manifest entry and still survives to the next fetch. Only the
      // never-sent ones are dropped, and those could never pair with anything truthfully.
      if (sent.ok) {
        // Store the NORMALIZED fills array (not t.fills) -- PowerShell's ConvertTo-Json collapses
        // a single-element array to a bare object, and idFills() downstream (capture.js) expects
        // a real array; storing the raw plan value here crashed __usxBulkFetch mid-batch.
        manifest.push({ provider: plan.provider, entity: t.entity, query: t.query, comboKeyRef: t.comboKeyRef, expectedKeyRef: t.expectedKeyRef, tier: t.tier, kind: t.kind, anyField: t.anyField || null, strippedField: t.strippedField || null, strippedValue: t.strippedValue || null, fills: fills, underFilled: !filled, n: t.n, submittedAt: new Date().toISOString() });
      } else {
        notSent.push(`T${t.n} ${t.entity} ${t.comboKeyRef}`);
      }
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
    // RECONCILE OUT LOUD. This line used to read "${manifest.length} queries submitted" off a
    // manifest that included FAILED tests, so it was a send count that could not fail -- the same
    // success-shaped-silence class as an inert gate. manifest.length is now genuinely the send
    // count, but print BOTH numbers anyway so the operator never has to do the subtraction, and
    // name the tests that did not send so a shortfall is visible at the point it happens.
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold',
      `plan run complete: ${tests.length} test(s) driven, ${manifest.length} SENT, ${notSent.length} NOT sent. ` +
      `${manifest.length} manifest entr${manifest.length === 1 ? 'y' : 'ies'} written (never-sent tests are NOT recorded). ` +
      `Go to /admin/dex-log and run __usxCaptureBatch(). EXPECT EXACTLY ${manifest.length} CAPTURE(S).`, results);
    if (notSent.length) {
      console.warn('%c[USx-DRV]', 'color:#c60;font-weight:bold',
        `${notSent.length} test(s) did NOT send and were deliberately kept OUT of the manifest, so nothing can be ` +
        `labelled with them: ${notSent.join(' | ')}`);
    }
    window.__usxRunInFlight = null;   // release: this run is finished, the next Run press is allowed
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
      // ROUTE RENAME: Mark43 moved the admin log page from /admin/dex-log to /admin/usx-log
      // (seen on usx-nm-nmlets 2026-08-27; Rob: "that will likely be universal"). Navigate to the
      // NEW name, but fall back to the old one if the hash does not take -- a tenant still on the
      // old route would otherwise land on a blank page and the batch fetch would time out after 15s
      // with no explanation. Detection in ui.js/capture.js accepts BOTH, so the panel appears either
      // way; only this auto-navigation had to choose.
      const logRoute = '#/admin/usx-log';
      console.log('%c[USx-RUNALL]', 'color:#06c', 'navigating to ' + logRoute + ' for the batch fetch...');
      location.hash = logRoute;
      await L.sleep(1200);
      if (!location.hash.includes('usx-log')) {
        console.warn('[USx-RUNALL] usx-log route did not take -- falling back to the legacy dex-log route.');
        location.hash = '#/admin/dex-log';
      }
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
      // attributeTypeId echoed 2026-09-02. emit_picklist_scope now carries it, but this record is
      // what actually reaches the download and then import_picklists -- so without it the repo-side
      // fix is only half a fix, and an attributeTypeId-driven dropdown still stores with NO source.
      // Measured on CA_eSUN v1.0: 9 of 15 scoped dropdowns (PurposeCode, SexCode, RegistrationState,
      // VehicleMakeCode) are attributeTypeId-driven and were captured as cat=null/src=null.
      const rec = { entity: f.entity, fieldId: f.fieldId, label: f.label || null, codeTypeCategory: f.codeTypeCategory || null, codeTypeSource: f.codeTypeSource || null, attributeTypeId: f.attributeTypeId || null, count: 0, truncated: false, options: [], error: null };
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

  // ---------------------------------------------------------------------------
  // MANIFEST RESET -- the recovery tool that did not exist on 2026-09-02.
  // capture.js KEEPS unpaired manifest entries by design, and until this build the driver wrote an
  // entry for every test whether it sent or not. So a stale manifest could span VERSIONS: during the
  // CA_eSUN v2.0 sweep it still held Person/DriverLicenseQuery x4 and Article/ArticleSingleQuery x2
  // from the v1.1 sweep -- entities that had not been driven once at v2.0 -- and those labels were
  // positionally dealt onto whatever dex-log rows the bulk fetch found. There was no supported way
  // to clear it; __usxCaptureWatchReset() resets WATCH mode, not this. Prints what it drops rather
  // than clearing silently, because a reset that reports nothing is indistinguishable from a no-op.
  window.__usxManifestReset = function () {
    let prior = [];
    try { prior = JSON.parse(localStorage.getItem('__usx_batch') || '[]'); } catch (e) {}
    if (!prior.length) {
      console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', 'manifest already empty -- nothing to reset.');
      return { dropped: 0, entries: [] };
    }
    const summary = {};
    for (const e of prior) {
      const k = `${e.entity}/${e.comboKeyRef}`;
      summary[k] = (summary[k] || 0) + 1;
    }
    localStorage.removeItem('__usx_batch');
    console.warn('%c[USx-DRV]', 'color:#c60;font-weight:bold',
      `manifest RESET -- dropped ${prior.length} queued entr${prior.length === 1 ? 'y' : 'ies'}. ` +
      `Anything not yet captured is now unrecoverable BY DESIGN: re-drive it rather than pairing a ` +
      `stale label onto a fresh row.`);
    console.table(Object.keys(summary).sort().map((k) => ({ 'entity/combo': k, queued: summary[k] })));
    return { dropped: prior.length, entries: summary };
  };

  if (location.hash.includes('universal-search')) {
    console.log('%c[USx-DRV]', 'color:#06c;font-weight:bold', 'driver ready. BUILD 2026-09-02c (RE-ENTRANCY LOCK: a second Run press while a run is in flight is REFUSED, not queued -- two concurrent runs fill the same form on top of each other and every result from both is untrustworthy. MANIFEST TRUTH FIX: a manifest entry is written ONLY when the query actually SENT -- never-sent tests can no longer be labelled onto someone else\'s wire row; run summary now reconciles driven/SENT/NOT-sent; new __usxManifestReset() clears a stale or cross-version manifest and prints what it dropped). __usxRunOne({...}) = one combo; __usxRunPlan(plan,"Vehicle") = whole entity; __usxScopePicklists(scope,"Vehicle") = dump dropdown options. After a submit, run __usxRmsRecon() then __usxRmsRowRecon() to help find the RMS result/error row structure.');
  }
})();
