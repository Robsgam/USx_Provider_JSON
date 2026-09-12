// ===========================================================================
//  deploy_probe.js -- THE ONLY FILE IN THIS EXTENSION THAT CAN WRITE.
//
//  WHY IT IS A SEPARATE FILE (Rob, 2026-09-11): "maybe we just leave this tool
//  as the auditor and generate another tool only for deployment with safe
//  guards." admin_probe.js stays GET-only by construction, so the question
//  "is the read path still read-only?" is answerable by reading ONE file.
//  Nothing here is reachable from admin_probe.js and it defines its own global.
//
//  WHAT IT DOES: sets #import-json.value in #import-modal and clicks #do-import.
//  Those ids were MEASURED, not guessed -- captured from the live DOM on
//  2026-09-11 via runCaptureDialogDl:
//      TEXTAREA #import-json   in #import-modal   visible, NOT readonly
//      INPUT    #import-file   in #import-modal   hidden, accept=.json
//      BUTTON   #do-import     -- executes
//  So no native file dialog is involved, which is what made this feasible at
//  all: page JavaScript cannot drive an OS file picker.
//
//  ⚠️ THE IMPORT REPLACES THE BUNDLE SET, IT DOES NOT MERGE. Proven on
//  usx-fl-fcic 2026-09-11: the tenant's CA_eSUN bundle was REMOVED, not left
//  alongside. So importing a PARTIAL file deletes whatever it omits. Hence the
//  payload guards below insist on a complete, parseable, version-stamped build.
//
//  ⚠️ DRY RUN IS THE DEFAULT. Every guard runs, nothing is clicked, and the
//  result says exactly what WOULD have happened. `execute:true` is required.
//
//  ⚠️ ONE TENANT PER CALL. There is deliberately no batch and no "all". Rob's
//  eventual model -- "auto update grouped by usx provider" -- is a REPO-SIDE
//  plan that calls this once per tenant, so a group is N audited single
//  actions rather than one unaudited loop. Grouping goes ON TOP of a proven
//  single, not beside an unproven one.
// ===========================================================================
(() => {
  if (window.__usxDeploy) return;

  const MODAL = '#import-modal';
  const TEXTAREA = '#import-json';
  const DO_IMPORT = '#do-import';
  const OPEN_BTN = '#import-dept-btn';

  const nowStamp = () => new Date().toISOString().replace(/[:.]/g, '-');

  function dl(filename, obj) {
    if (!window.__usxLib || !window.__usxLib.triggerDownload) {
      throw new Error('usx_lib not loaded -- reload the extension');
    }
    return window.__usxLib.triggerDownload(filename, obj);
  }

  const deptIdFromUrl = () => (location.pathname.match(/configurations\/(\d+)/) || [])[1] || null;

  // The dept-id field inside the import modal -- the one field that makes the TARGET explicit
  // rather than implied by "whatever page we are on", so it is checked rather than trusted.
  //
  // ⚠️ BY ID, MEASURED. The first cut scanned every input in the modal for a value matching
  // /^\d{3,}$/ and demanded EXACTLY ONE match. That refused a legitimate dry run with
  // "could not identify the modal target field unambiguously" -- because the modal ALSO
  // contains #import-file-name, and because the dept-id field is populated a moment AFTER the
  // modal renders, so a run that opened the dialog and proceeded immediately saw ZERO matches.
  // A heuristic written against a fixture I invented, rather than against the DOM the capture
  // button had already measured for me. The id was sitting in that capture the whole time.
  const TARGET_FIELD = '#import-dept-id-input';
  function findTargetField(modal) {
    if (!modal) { return null; }
    const byId = modal.querySelector(TARGET_FIELD);
    if (byId) { return byId; }
    // Fallback for a UI change: the heuristic, but EXCLUDING the filename box by id so a
    // second empty text input cannot make it ambiguous.
    const cands = Array.from(modal.querySelectorAll('input'))
      .filter(i => (i.type || 'text') !== 'file' && i.id !== 'import-file-name' &&
                   /^\d{3,}$/.test(String(i.value || '').trim()));
    return cands.length === 1 ? cands[0] : null;
  }

  // ── THE GUARDS. Each returns a reason string to REFUSE, or null to allow. ──────────────
  // Ordered cheapest-first, and every one of them can stop the run. A guard that cannot
  // refuse is decoration.
  function runGuards(opts, ctx) {
    const bad = [];

    // 1. An explicit target, and it must match the page. No "current page" implicitness.
    if (!opts.deptId || !/^\d+$/.test(String(opts.deptId))) {
      bad.push('no explicit numeric deptId was supplied -- refusing to infer the target');
    } else if (ctx.urlDeptId && String(opts.deptId) !== String(ctx.urlDeptId)) {
      bad.push('deptId ' + opts.deptId + ' does not match this page (' + ctx.urlDeptId + ')');
    }

    // 2. The modal must actually be open, with the field we measured.
    if (!ctx.modal) { bad.push('the import modal (' + MODAL + ') is not present -- click "Import JSON" first'); }
    else if (!ctx.textarea) { bad.push('the payload field (' + TEXTAREA + ') is not present in the modal'); }
    else if (ctx.textarea.readOnly) { bad.push('the payload field is readOnly -- refusing to fight the UI'); }
    if (ctx.modal && !ctx.doBtn) { bad.push('the execute control (' + DO_IMPORT + ') is not present'); }

    // 3. The modal's own target field must agree. This is the check that catches
    //    "right button, wrong tenant", the only genuinely unrecoverable mistake here.
    if (ctx.targetField) {
      const shown = String(ctx.targetField.value || '').trim();
      if (shown !== String(opts.deptId)) {
        bad.push("the modal's target field reads " + shown + ' but the intended target is ' + opts.deptId);
      }
    } else if (ctx.modal) {
      bad.push('could not identify the modal target field unambiguously -- refusing to proceed blind');
    }

    // 4. THE PAYLOAD MUST BE A COMPLETE, PARSEABLE, VERSION-STAMPED BUILD OF OURS.
    //    Because the import REPLACES the bundle set, a truncated or foreign payload does not
    //    fail safe -- it deletes what it omits.
    if (!opts.payload || typeof opts.payload !== 'string') { bad.push('no payload string supplied'); }
    else {
      if (opts.payload.length < 10000) { bad.push('payload is only ' + opts.payload.length + ' bytes -- implausibly small for a provider build'); }
      let parsed = null;
      try { parsed = JSON.parse(opts.payload); } catch (e) { bad.push('payload is not valid JSON: ' + e.message); }
      if (parsed) {
        const bundles = parsed.bundles || (parsed.departmentBundle && parsed.departmentBundle.bundles);
        if (!bundles || !bundles.length) { bad.push('payload contains no bundles[]'); }
        else {
          ctx.bundleNames = bundles.map(b => b.name);
          const hasEntities = ctx.bundleNames.indexOf('ENTITIES') >= 0;
          const provB = bundles.filter(b => b.name !== 'ENTITIES' && b.name !== 'RMS');
          if (!hasEntities) { bad.push('payload has no ENTITIES bundle -- an import REPLACES the set, so this would remove the forms'); }
          if (provB.length !== 1) { bad.push('payload has ' + provB.length + ' provider bundle(s); expected exactly 1'); }
          else {
            const m = String(provB[0].description || '').match(/Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)/);
            if (!m) { bad.push('the provider bundle carries no "Provider configuration for <P> vX.Y" description -- this is NOT one of our builds'); }
            else {
              ctx.payloadProvider = m[1]; ctx.payloadVersion = m[2];
              if (opts.expectProvider && m[1] !== opts.expectProvider) { bad.push('payload is ' + m[1] + ' but ' + opts.expectProvider + ' was expected'); }
              if (opts.expectVersion && m[2] !== opts.expectVersion) { bad.push('payload is v' + m[2] + ' but v' + opts.expectVersion + ' was expected'); }
            }
          }
        }
      }
    }

    // 5. LIVE tenants need their own explicit consent, never a batch default.
    if (opts.tenantStatus && /LIVE/i.test(opts.tenantStatus) && !opts.liveConfirmed) {
      bad.push('tenant status is ' + opts.tenantStatus + ' -- set liveConfirmed:true to import to a LIVE tenant');
    }

    // 6. An operator abort always wins.
    if (window.__usxDeployAbort) { bad.push('aborted by the operator'); }

    return bad;
  }

  // DID THE FIELD ACTUALLY TAKE THE PAYLOAD? -- and the answer is NOT a byte count.
  //
  // ⚠️ THE DOM NORMALISES CRLF TO LF ON `textarea.value`. That is spec, not a quirk, and it made
  // the first real EXECUTE abort on a perfectly good write:
  //     read-back is 1250943 bytes but 1261872 were written
  // The deficit was 10,929 -- and `tr -cd '\r' < FL_FCIC_v7.24.json | wc -c` is 10,929 EXACTLY.
  // Our JSON is written with Windows line endings and served byte-for-byte, so every CRLF became
  // an LF and the raw-length comparison could never succeed on any provider build.
  //
  // The guard was RIGHT to refuse -- it saw a difference it could not explain and did not click.
  // But the comparison was the wrong one, so it could only ever fail. Normalise before writing,
  // compare against what we actually wrote, and then check something that MEANS something:
  // a length match alone would pass on a same-length corruption.
  //
  // Safe for the platform: line endings between JSON tokens are insignificant whitespace, and the
  // 5,152 `\r` sequences inside string literals are two-character ESCAPES, not raw CR bytes, so
  // normalisation cannot touch them.
  function bundleNamesOf(o) {
    const bs = (o && (o.bundles || (o.departmentBundle && o.departmentBundle.bundles))) || [];
    return bs.map(x => x && x.name).join(',');
  }
  function stampOf(o) {
    const bs = (o && (o.bundles || (o.departmentBundle && o.departmentBundle.bundles))) || [];
    for (const b of bs) {
      const m = String((b && b.description) || '').match(/Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)/);
      if (m && b.name !== 'ENTITIES' && b.name !== 'RMS') { return m[1] + ' v' + m[2]; }
    }
    return '';
  }
  function verifyReadBack(written, readBack) {
    if (readBack.length !== written.length) {
      return 'read-back is ' + readBack.length + ' bytes but ' + written.length +
             ' were written (after CRLF->LF normalisation) -- the field did not take the payload';
    }
    let a = null, b = null;
    try { a = JSON.parse(written); } catch (e) { return 'the payload we were about to submit is not parseable JSON: ' + e.message; }
    try { b = JSON.parse(readBack); } catch (e) { return 'the field does not hold parseable JSON after the write: ' + e.message; }
    if (bundleNamesOf(a) !== bundleNamesOf(b)) {
      return 'bundles differ after the write: wrote [' + bundleNamesOf(a) + '] but the field holds [' + bundleNamesOf(b) + ']';
    }
    if (stampOf(a) !== stampOf(b)) {
      return 'the version stamp differs after the write: wrote "' + stampOf(a) + '" but the field holds "' + stampOf(b) + '"';
    }
    return null;
  }

  async function deployOne(opts) {
    opts = opts || {};
    const out = {
      probe: 'usx-deploy', version: 1, capturedAt: new Date().toISOString(),
      host: location.hostname, url: location.href,
      deptId: opts.deptId || null, dryRun: (opts.execute !== true),
      guardsFailed: [], clicked: false, verdict: null, notes: []
    };

    const modal = document.querySelector(MODAL);
    const ctx = {
      urlDeptId: deptIdFromUrl(),
      modal: modal,
      textarea: modal ? modal.querySelector(TEXTAREA) : null,
      doBtn: document.querySelector(DO_IMPORT),
      targetField: modal ? findTargetField(modal) : null
    };

    const bad = runGuards(opts, ctx);
    out.payloadProvider = ctx.payloadProvider || null;
    out.payloadVersion = ctx.payloadVersion || null;
    out.payloadBundles = ctx.bundleNames || null;
    out.payloadBytes = opts.payload ? opts.payload.length : 0;
    out.modalTargetShown = ctx.targetField ? String(ctx.targetField.value || '').trim() : null;

    if (bad.length) {
      out.guardsFailed = bad;
      out.verdict = 'REFUSED';
      out.notes.push('No write was attempted. Every guard must pass; ' + bad.length + ' failed.');
    // ⚠️ SAY IT WHERE IT CAN BE SEEN. The verdict used to go ONLY to the panel's status line and a
    // downloaded file -- and the import modal covers the panel, so the operator's report of a clean
    // DRY-RUN-OK was "window popped up but nothing happened after that". A result nobody can read is
    // indistinguishable from a hang, and it cost a round of diagnosis on working code.
    console.log('%c[USx-DEPLOY] ' + out.verdict,
      'color:' + (out.verdict === 'REFUSED' || out.verdict === 'ABORTED-BEFORE-CLICK' ? '#f66'
                : out.verdict === 'CLICKED' ? '#6c6' : '#fa0') + ';font-weight:bold',
      out.verdict === 'REFUSED' ? out.guardsFailed
        : (out.payloadProvider + ' v' + out.payloadVersion + ' (' + out.payloadBytes +
           ' bytes) -> dept ' + out.deptId + '; modal target ' + out.modalTargetShown),
      out);
      dl('usx_deploy_' + (opts.deptId || 'unknown') + '_' + nowStamp() + '_REFUSED.json', out);
      return out;
    }

    out.notes.push('All guards passed: target ' + opts.deptId + ' confirmed against the page AND the modal field; payload is ' +
                   ctx.payloadProvider + ' v' + ctx.payloadVersion + ' with bundles [' + ctx.bundleNames.join(', ') + '].');

    if (out.dryRun) {
      out.verdict = 'DRY-RUN-OK';
      out.notes.push('DRY RUN -- nothing was clicked. Re-call with execute:true to perform it.');
      out.notes.push('WOULD set ' + TEXTAREA + ' (' + out.payloadBytes + ' bytes) and click ' + DO_IMPORT + '.');
      // The dialog is LEFT OPEN on purpose. A dry run clicks nothing, and the live capture shows
      // the modal contains exactly two buttons -- Browse and Import -- so there is no MEASURED close
      // control to use. Guessing at one (Escape, a dimmer click, an unmeasured icon) is the same
      // class of mistake as the heuristic that started this. Close it by hand.
      out.notes.push('The import dialog is still open -- a dry run clicks nothing, including any close control. Close it yourself before the next step.');
    // ⚠️ SAY IT WHERE IT CAN BE SEEN. The verdict used to go ONLY to the panel's status line and a
    // downloaded file -- and the import modal covers the panel, so the operator's report of a clean
    // DRY-RUN-OK was "window popped up but nothing happened after that". A result nobody can read is
    // indistinguishable from a hang, and it cost a round of diagnosis on working code.
    console.log('%c[USx-DEPLOY] ' + out.verdict,
      'color:' + (out.verdict === 'REFUSED' || out.verdict === 'ABORTED-BEFORE-CLICK' ? '#f66'
                : out.verdict === 'CLICKED' ? '#6c6' : '#fa0') + ';font-weight:bold',
      out.verdict === 'REFUSED' ? out.guardsFailed
        : (out.payloadProvider + ' v' + out.payloadVersion + ' (' + out.payloadBytes +
           ' bytes) -> dept ' + out.deptId + '; modal target ' + out.modalTargetShown),
      out);
      dl('usx_deploy_' + opts.deptId + '_' + nowStamp() + '_DRYRUN.json', out);
      return out;
    }

    // ── THE WRITE. Everything above this line is refusable; this is the only action. ──
    // Normalised FIRST so that what we intend to write is what the DOM can actually hold --
    // see verifyReadBack above for why the raw string could never survive the round trip.
    const toWrite = String(opts.payload).replace(/\r\n/g, '\n');
    out.payloadNormalizedBytes = toWrite.length;
    if (toWrite.length !== opts.payload.length) {
      out.notes.push('normalised CRLF -> LF before writing: ' + opts.payload.length + ' -> ' +
                     toWrite.length + ' bytes (' + (opts.payload.length - toWrite.length) +
                     ' CR characters removed; JSON whitespace, no content change)');
    }
    ctx.textarea.value = toWrite;
    // Dispatch both: Semantic UI/jQuery may read .value directly, but a framework that mirrors
    // into its own state would otherwise submit an EMPTY field while the box looks full.
    ctx.textarea.dispatchEvent(new Event('input', { bubbles: true }));
    ctx.textarea.dispatchEvent(new Event('change', { bubbles: true }));
    out.notes.push('payload written to ' + TEXTAREA + '; input+change dispatched');

    // Re-read the field. If the UI rejected, truncated or transformed the write, do NOT click.
    const readBack = String(ctx.textarea.value || '');
    out.readBackBytes = readBack.length;
    const problem = verifyReadBack(toWrite, readBack);
    if (problem) {
      out.verdict = 'ABORTED-BEFORE-CLICK';
      out.notes.push(problem + ', so ' + DO_IMPORT + ' was NOT clicked.');
    // ⚠️ SAY IT WHERE IT CAN BE SEEN. The verdict used to go ONLY to the panel's status line and a
    // downloaded file -- and the import modal covers the panel, so the operator's report of a clean
    // DRY-RUN-OK was "window popped up but nothing happened after that". A result nobody can read is
    // indistinguishable from a hang, and it cost a round of diagnosis on working code.
    console.log('%c[USx-DEPLOY] ' + out.verdict,
      'color:' + (out.verdict === 'REFUSED' || out.verdict === 'ABORTED-BEFORE-CLICK' ? '#f66'
                : out.verdict === 'CLICKED' ? '#6c6' : '#fa0') + ';font-weight:bold',
      out.verdict === 'REFUSED' ? out.guardsFailed
        : (out.payloadProvider + ' v' + out.payloadVersion + ' (' + out.payloadBytes +
           ' bytes) -> dept ' + out.deptId + '; modal target ' + out.modalTargetShown),
      out);
      dl('usx_deploy_' + opts.deptId + '_' + nowStamp() + '_ABORTED.json', out);
      return out;
    }

    ctx.doBtn.click();
    out.clicked = true;
    out.verdict = 'CLICKED';
    out.notes.push('clicked ' + DO_IMPORT + '. THIS IS NOT PROOF OF SUCCESS -- re-export the tenant and run tools\\verify_tenant_import.ps1. The dialog saying "import complete" says the platform accepted the payload, not which build ended up installed.');
    // ⚠️ SAY IT WHERE IT CAN BE SEEN. The verdict used to go ONLY to the panel's status line and a
    // downloaded file -- and the import modal covers the panel, so the operator's report of a clean
    // DRY-RUN-OK was "window popped up but nothing happened after that". A result nobody can read is
    // indistinguishable from a hang, and it cost a round of diagnosis on working code.
    console.log('%c[USx-DEPLOY] ' + out.verdict,
      'color:' + (out.verdict === 'REFUSED' || out.verdict === 'ABORTED-BEFORE-CLICK' ? '#f66'
                : out.verdict === 'CLICKED' ? '#6c6' : '#fa0') + ';font-weight:bold',
      out.verdict === 'REFUSED' ? out.guardsFailed
        : (out.payloadProvider + ' v' + out.payloadVersion + ' (' + out.payloadBytes +
           ' bytes) -> dept ' + out.deptId + '; modal target ' + out.modalTargetShown),
      out);
    dl('usx_deploy_' + opts.deptId + '_' + nowStamp() + '_CLICKED.json', out);
    return out;
  }

  // Fetch the repo build through serve_plans.ps1 so the payload is the repo artifact
  // BYTE-FOR-BYTE. A hand-picked file can be stale, renamed, or out of _versions/ -- and
  // verify_tenant_import compares the tenant against the REPO build, so a payload from
  // anywhere else would have it comparing a tenant to a build it was never given.
  async function fetchBuild(provider, port) {
    const url = 'http://localhost:' + (port || 8477) + '/build/' + encodeURIComponent(provider);
    const r = await fetch(url, { method: 'GET' });
    const t = await r.text();
    if (!r.ok) { throw new Error('build fetch failed (' + r.status + '): ' + t.slice(0, 200)); }
    return t;
  }

  // Open the import modal and wait for it to render. Clicking #import-dept-btn only OPENS a
  // dialog -- the destructive control is #do-import, which nothing but deployOne touches, and
  // only with execute:true after every guard has passed. Kept separate from deployOne so the
  // act of opening is never a side effect of a call that might also write.
  // READY means: the modal rendered AND the page has finished populating the dept-id field.
  //
  // ⚠️ "THE TEXTAREA EXISTS" WAS NOT ENOUGH, and this is the bug that refused Rob's dry run with
  // "could not identify the modal target field unambiguously". The measured modal holds only
  // THREE inputs (#import-dept-id-input, #import-file-name, #import-file), so the old heuristic
  // -- scan non-file inputs for a /^\d{3,}$/ value, require exactly one -- had no competing
  // candidate and should have matched. It found ZERO, because the dept-id is filled by the page's
  // own jQuery (`fsRequest` -> `loadDepartmentBundles`, visible in the tenant console) a moment
  // AFTER the modal renders. We opened the dialog and read the field in the same breath.
  //
  // So the message blamed ambiguity for what was a RACE, and resolving by id alone would have
  // fixed only the wording: an empty field still fails the target-agreement guard. The wait is
  // the fix; the id is what makes the wait checkable.
  function targetReady(modal) {
    const f = findTargetField(modal);
    return !!(f && String(f.value || '').trim().length > 0);
  }

  // ⚠️ PRESENCE IS NOT OPENNESS, and this is the bug behind BOTH refusals.
  //
  // The import modal lives in the DOM PERMANENTLY -- Semantic UI hides it with display:none
  // rather than removing it. The live capture proves it: #export-modal's children are recorded
  // `"visible": false, "display": "none"` while that dialog is closed, and #import-modal is the
  // same construction. So "modal element exists AND contains the textarea" was TRUE for a CLOSED
  // dialog. openImportModal concluded `already: true`, NEVER CLICKED "Import JSON", and then read
  // a dept-id field the page had no reason to have populated.
  //
  // That is the whole story of both errors the operator saw: first
  // "could not identify the modal target field unambiguously" (the old heuristic found zero
  // numeric inputs, because the field was empty, and reported that as ambiguity), then
  // "#import-dept-id-input never populated within 8000ms" (the wait was right, but we were
  // waiting on a dialog nobody had opened). The wait did its job -- it turned a silent wrong
  // answer into a specific one.
  //
  // Test OPENNESS, not existence. A hidden element has no offsetParent and no layout box.
  function isShown(el) {
    if (!el) { return false; }
    if (el.offsetParent === null) {
      // position:fixed elements legitimately report a null offsetParent, so do not trust that
      // alone -- a fixed, VISIBLE modal would read as closed.
      const cs = window.getComputedStyle(el);
      if (cs.position !== 'fixed') { return false; }
      if (cs.display === 'none' || cs.visibility === 'hidden') { return false; }
    }
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  }

  function modalIsOpen(modal) { return !!(modal && modal.querySelector(TEXTAREA) && isShown(modal)); }

  async function openImportModal(budgetMs) {
    const budget = budgetMs || 8000;
    const t0 = Date.now();
    let modal = document.querySelector(MODAL);
    const already = modalIsOpen(modal);
    if (!already) {
      const btn = document.querySelector(OPEN_BTN);
      if (!btn) { throw new Error('cannot find ' + OPEN_BTN + ' -- is this a configuration page?'); }
      btn.click();
    }
    while (Date.now() - t0 < budget) {
      modal = document.querySelector(MODAL);
      if (modalIsOpen(modal) && targetReady(modal)) {
        return { opened: !already, already: already, modal: modal,
                 waitedMs: Date.now() - t0, targetShown: findTargetField(modal).value };
      }
      await new Promise(r => setTimeout(r, 150));
    }
    // THREE distinguishable failures. Reporting any of them as another is what cost two rounds.
    modal = document.querySelector(MODAL);
    if (!modal || !modal.querySelector(TEXTAREA)) {
      throw new Error('the import modal (' + MODAL + ') never appeared within ' + budget + 'ms');
    }
    if (!isShown(modal)) {
      throw new Error('the import modal is present but NOT VISIBLE after clicking ' + OPEN_BTN +
                      ' -- the dialog did not open (it exists in the DOM even when closed)');
    }
    throw new Error('the modal is open but ' + TARGET_FIELD + ' never populated within ' + budget +
                    'ms -- refusing to read the target before the page has written it');
  }

  // WHICH PROVIDER IS THIS TENANT SUPPOSED TO RUN -- asked of the repo, never of the operator.
  //
  // Rob, 2026-09-11: "typing fcic in tath window is not right you should already know what the
  // tenatn is supposed to be based on my direct input intitally since you ahve not deployed any
  // on your own." Correct, and the reason is safety rather than keystrokes: a typo in a provider
  // box imports the WRONG PROVIDER into a real tenant and EVERY existing guard still passes --
  // the build is valid, version-stamped, the deptId matches the page and the modal. Nothing
  // compared the payload's provider to the tenant's intended one because nothing knew it.
  async function resolveTarget(deptId, port) {
    const url = 'http://localhost:' + (port || 8477) + '/target/' + encodeURIComponent(String(deptId));
    const r = await fetch(url, { method: 'GET' });
    const t = await r.text();
    let j = null; try { j = JSON.parse(t); } catch (e) {}
    if (!r.ok) { throw new Error('target resolve failed (' + r.status + '): ' + ((j && (j.error || j.fix)) || t.slice(0, 200))); }
    if (!j || !j.provider) { throw new Error('target resolve returned no provider for ' + deptId); }
    return j;
  }

  // THE WHOLE LOOP, one call: resolve the target -> fetch the repo build -> open the modal ->
  // guard -> (maybe) write. Still ONE TENANT, still dry-run unless execute:true. This is the
  // automation; deployOne remains callable on its own for a payload that did not come from the repo.
  async function deployFromRepo(opts) {
    opts = opts || {};
    const deptId = opts.deptId || deptIdFromUrl();
    if (!deptId) { throw new Error('no deptId given and none in the URL'); }

    // Resolution is MANDATORY and un-bypassable. An unrecorded tenant is not a deploy target.
    const tgt = await resolveTarget(deptId, opts.port);
    if (tgt.scopeExcluded) {
      throw new Error('tenant ' + tgt.subdomain + ' is EXCLUDED by tenant_scope.json: ' + tgt.scopeExcluded);
    }
    // A supplied provider is treated as an ASSERTION TO CHECK, never as the answer. That turns a
    // typo into a refusal instead of into an import.
    if (opts.provider && opts.provider !== tgt.provider) {
      throw new Error('provider mismatch: you asked for ' + opts.provider + ' but ' + tgt.subdomain +
                      ' is recorded as ' + tgt.provider + ' (' + tgt.source + ') -- refusing');
    }
    const provider = tgt.provider;

    const payload = await fetchBuild(provider, opts.port);
    // Read the version out of the payload rather than making the caller assert it twice --
    // but still pass it as expectVersion so the guard compares the payload against itself and
    // a malformed build cannot slip through by simply not stating a version.
    const m = payload.match(/Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)/);
    await openImportModal(opts.modalBudgetMs);
    // tenantStatus comes from the RECORD, not from the caller. It used to be an opts field, which
    // meant the LIVE guard was armed only by an operator who volunteered the status -- i.e. it was
    // disarmed by default on exactly the tenants it exists to protect (hawaii-dle is LIVE).
    const res = await deployOne({
      deptId: String(deptId),
      payload: payload,
      expectProvider: provider,
      expectVersion: m ? m[2] : null,
      tenantStatus: tgt.status || opts.tenantStatus || null,
      liveConfirmed: opts.liveConfirmed === true,
      execute: opts.execute === true
    });
    res.target = tgt;
    return res;
  }

  // ══ THE JOB RUNNER ═══════════════════════════════════════════════════════════════════════
  //
  // Rob, 2026-09-11: "this is still too clunky  i want the import process to be run by a json you
  // create  kinda of like a import job file.  then i runi t via the console  it updates based on
  // what we discused here."
  //
  // The clunk was real and it was not about keystrokes: the operator was ASSEMBLING THE DECISION
  // AT THE KEYBOARD -- open a tenant, read a panel, judge a dry run, press a red button. Decision
  // and execution were the same act, so there was nothing to review beforehand and nothing to diff
  // afterwards. Now the decision is a FILE (tools\emit_import_job.ps1 writes it, Rob reads it) and
  // this only executes what the file says.
  //
  // ONE TENANT PER CALL, STILL. The import happens through THIS page's modal, so the job may list
  // many targets but a call imports only the row matching the page it is run on -- then prints the
  // next url. That keeps the standing safeguard while letting one reviewed file cover a batch.
  async function fetchJob(port) {
    const url = 'http://localhost:' + (port || 8477) + '/job';
    const r = await fetch(url, { method: 'GET' });
    const t = await r.text();
    let j = null; try { j = JSON.parse(t); } catch (e) {}
    if (!r.ok) { throw new Error('job fetch failed (' + r.status + '): ' + ((j && j.error) || t.slice(0, 200))); }
    if (!j || !j.targets || !j.targets.length) { throw new Error('the job file has no targets'); }
    return j;
  }

  // PRE-FLIGHT: is the tenant still in the state the job was cut against?
  // Safeguard 2 from the usx-deploy skill -- "re-export and confirm the BEFORE still matches the
  // plan; abort the row if it changed" -- which is what stops us overwriting somebody else's
  // concurrent change. Read the page's own bundle tables, the same way admin_probe reads them
  // (generic table/tbody scrape; there is no measured id for that table, so do not invent one).
  function bundleNamesOnPage() {
    const cells = [];
    document.querySelectorAll('table td, table th').forEach(c => {
      const s = (c.textContent || '').replace(/\s+/g, ' ').trim();
      if (s && s.length < 60) { cells.push(s); }
    });
    return cells;
  }
  function bundlePreflight(expected) {
    const cells = bundleNamesOnPage();
    if (!cells.length) { return 'no table cells on this page -- cannot confirm the tenant is still in the state the job was cut against'; }
    const missing = (expected || []).filter(n => !cells.some(c => c === n || c.indexOf(n) >= 0));
    if (missing.length === (expected || []).length && missing.length > 0) {
      return 'none of the job expected bundles [' + expected.join(', ') + '] appear on this page -- either the table has not loaded or this is not the tenant the job describes';
    }
    if (missing.length) {
      return 'the tenant no longer carries [' + missing.join(', ') + '] which the job recorded as present -- it has CHANGED since the job was cut, so this row is refused rather than overwritten';
    }
    return null;
  }

  async function runJob(opts) {
    opts = opts || {};
    const job = await fetchJob(opts.port);
    const did = deptIdFromUrl();
    if (!did) { throw new Error('no department id in this URL -- open a target configuration page'); }

    const rows = job.targets.filter(t => String(t.deptId) === String(did));
    if (rows.length !== 1) {
      console.log('%c[USx-JOB] this page is not in the job (' + job.jobId + ')', 'color:#fa0;font-weight:bold');
      console.table(job.targets.map(t => ({ tenant: t.subdomain, deptId: t.deptId, to: t.provider + ' v' + t.toVersion, done: !!t.done, url: t.url })));
      throw new Error('deptId ' + did + ' matched ' + rows.length + ' job target(s) -- open one of the urls listed above');
    }
    const t = rows[0];

    // TWO INDEPENDENT AUTHORITIES MUST AGREE. The job says what to import; /target says what the
    // repo RECORD believes this tenant runs. A job typo that contradicts the record is refused.
    const tgt = await resolveTarget(did, opts.port);
    if (tgt.provider !== t.provider) {
      throw new Error('job says ' + t.provider + ' but the repo record says ' + tgt.subdomain + ' runs ' +
                      tgt.provider + ' (' + tgt.source + ') -- refusing on a disagreement');
    }
    if (tgt.scopeExcluded) { throw new Error('tenant is EXCLUDED by tenant_scope.json: ' + tgt.scopeExcluded); }

    if (!opts.skipBundlePreflight && !job.skipBundlePreflight) {
      const p = bundlePreflight(t.expectBundlesNow);
      if (p) { throw new Error('PRE-FLIGHT: ' + p); }
    }
    if (/LIVE/i.test(String(t.tenantStatus || '')) && t.liveConfirmed !== true) {
      throw new Error('tenant status is ' + t.tenantStatus + ' -- set liveConfirmed:true on this target IN THE JOB FILE, deliberately, before it can run');
    }

    const execute = (job.dryRunOnly === true) ? false : (opts.dryRun !== true);
    console.log('%c[USx-JOB] ' + job.jobId + ' -> ' + t.subdomain + ' (' + did + ')  ' +
                (t.fromVersion ? 'v' + t.fromVersion : 'NOT-OURS') + ' -> ' + t.provider + ' v' + t.toVersion +
                (execute ? '  EXECUTING' : '  DRY RUN'), 'color:#6cf;font-weight:bold');

    const res = await deployFromRepo({
      deptId: did, provider: t.provider, execute: execute,
      liveConfirmed: t.liveConfirmed === true, port: opts.port
    });
    res.jobId = job.jobId;

    const remaining = job.targets.filter(x => String(x.deptId) !== String(did) && !x.done);
    if (remaining.length) {
      console.log('%c[USx-JOB] next: ' + remaining[0].subdomain + '  ' + remaining[0].url,
                  'color:#fa0;font-weight:bold', '(' + remaining.length + ' target(s) left in this job)');
    } else {
      console.log('%c[USx-JOB] that was the last target in ' + job.jobId, 'color:#6c6;font-weight:bold');
    }
    console.log('%c[USx-JOB] NOT PROOF. Pull with button 6b, then ingest_tenant_configs.ps1 + verify_tenant_import.ps1.', 'color:#999');
    return res;
  }

  window.__usxJob = runJob;
  window.__usxDeployAbort = false;
  window.__usxDeploy = { deployOne, deployFromRepo, openImportModal, fetchBuild, runGuards, resolveTarget, targetReady, isShown, modalIsOpen, verifyReadBack, runJob, fetchJob, bundlePreflight,
                         findTargetField, MODAL, TEXTAREA, DO_IMPORT, OPEN_BTN };
  console.log('%c[USx-DEPLOY]', 'color:#f66;font-weight:bold',
    'deploy_probe loaded -- THE ONLY WRITE PATH. Dry-run by default; execute:true required. ' +
    'One tenant per call, no batch, no all. Guards: explicit deptId matching BOTH the URL and the ' +
    'modal target field, modal+textarea+button present, payload parseable and version-stamped with ' +
    'ENTITIES plus exactly one provider bundle, LIVE needs liveConfirmed, and an abort flag. ' +
    'A CLICKED verdict is NOT proof -- verify_tenant_import.ps1 is. BUILD 2026-09-11g -- the read-back check now NORMALISES CRLF to LF before comparing (the DOM does that to textarea.value by spec, so the raw-length compare aborted a perfectly good import: deficit 10,929 == the exact CR count in that build) and verifies bundle names + version stamp rather than a byte count. Earlier: PRESENCE IS NOT OPENNESS: the import modal exists in the DOM while CLOSED (display:none), so the old "modal + textarea present" check read a shut dialog as already-open, never clicked Import JSON, and then read an empty dept-id. That single cause produced BOTH operator errors -- the bogus "ambiguous target field" and then "never populated within 8000ms". openImportModal now tests VISIBILITY, waits for the dept-id to populate, and reports never-appeared / not-visible / never-populated as three distinct failures. findTargetField resolves the measured id #import-dept-id-input. deployFromRepo resolves the provider AND the LIVE status from the repo record, not from the caller.');
})();
