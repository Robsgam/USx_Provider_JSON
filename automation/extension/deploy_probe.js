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

  // Find the dept-id field inside the import modal. Rob observed it is prefilled; it is the
  // one field that makes the TARGET explicit rather than implied by "whatever page we are on",
  // so it is checked rather than trusted.
  function findTargetField(modal) {
    const cands = Array.from(modal.querySelectorAll('input'))
      .filter(i => (i.type || 'text') !== 'file' && /^\d{3,}$/.test(String(i.value || '').trim()));
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
      dl('usx_deploy_' + (opts.deptId || 'unknown') + '_' + nowStamp() + '_REFUSED.json', out);
      return out;
    }

    out.notes.push('All guards passed: target ' + opts.deptId + ' confirmed against the page AND the modal field; payload is ' +
                   ctx.payloadProvider + ' v' + ctx.payloadVersion + ' with bundles [' + ctx.bundleNames.join(', ') + '].');

    if (out.dryRun) {
      out.verdict = 'DRY-RUN-OK';
      out.notes.push('DRY RUN -- nothing was clicked. Re-call with execute:true to perform it.');
      out.notes.push('WOULD set ' + TEXTAREA + ' (' + out.payloadBytes + ' bytes) and click ' + DO_IMPORT + '.');
      dl('usx_deploy_' + opts.deptId + '_' + nowStamp() + '_DRYRUN.json', out);
      return out;
    }

    // ── THE WRITE. Everything above this line is refusable; this is the only action. ──
    ctx.textarea.value = opts.payload;
    // Dispatch both: Semantic UI/jQuery may read .value directly, but a framework that mirrors
    // into its own state would otherwise submit an EMPTY field while the box looks full.
    ctx.textarea.dispatchEvent(new Event('input', { bubbles: true }));
    ctx.textarea.dispatchEvent(new Event('change', { bubbles: true }));
    out.notes.push('payload written to ' + TEXTAREA + '; input+change dispatched');

    // Re-read the field. If the UI rejected or transformed the write, do NOT click.
    const readBack = String(ctx.textarea.value || '');
    out.readBackBytes = readBack.length;
    if (readBack.length !== opts.payload.length) {
      out.verdict = 'ABORTED-BEFORE-CLICK';
      out.notes.push('read-back is ' + readBack.length + ' bytes but ' + opts.payload.length + ' were written -- the field did not take the payload, so ' + DO_IMPORT + ' was NOT clicked.');
      dl('usx_deploy_' + opts.deptId + '_' + nowStamp() + '_ABORTED.json', out);
      return out;
    }

    ctx.doBtn.click();
    out.clicked = true;
    out.verdict = 'CLICKED';
    out.notes.push('clicked ' + DO_IMPORT + '. THIS IS NOT PROOF OF SUCCESS -- re-export the tenant and run tools\\verify_tenant_import.ps1. The dialog saying "import complete" says the platform accepted the payload, not which build ended up installed.');
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
  async function openImportModal(budgetMs) {
    const budget = budgetMs || 8000;
    let modal = document.querySelector(MODAL);
    if (modal && modal.querySelector(TEXTAREA)) { return { opened: false, already: true, modal: modal }; }
    const btn = document.querySelector(OPEN_BTN);
    if (!btn) { throw new Error('cannot find ' + OPEN_BTN + ' -- is this a configuration page?'); }
    btn.click();
    const t0 = Date.now();
    while (Date.now() - t0 < budget) {
      await new Promise(r => setTimeout(r, 150));
      modal = document.querySelector(MODAL);
      if (modal && modal.querySelector(TEXTAREA)) { return { opened: true, already: false, modal: modal }; }
    }
    throw new Error('the import modal did not render within ' + budget + 'ms');
  }

  // THE WHOLE LOOP, one call: fetch the repo build -> open the modal -> guard -> (maybe) write.
  // Still ONE TENANT, still dry-run unless execute:true. This is the automation; deployOne
  // remains callable on its own for a payload that did not come from the repo.
  async function deployFromRepo(opts) {
    opts = opts || {};
    if (!opts.provider) { throw new Error('provider is required (e.g. FL_FCIC)'); }
    const deptId = opts.deptId || deptIdFromUrl();
    if (!deptId) { throw new Error('no deptId given and none in the URL'); }
    const payload = await fetchBuild(opts.provider, opts.port);
    // Read the version out of the payload rather than making the caller assert it twice --
    // but still pass it as expectVersion so the guard compares the payload against itself and
    // a malformed build cannot slip through by simply not stating a version.
    const m = payload.match(/Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)/);
    await openImportModal(opts.modalBudgetMs);
    return await deployOne({
      deptId: String(deptId),
      payload: payload,
      expectProvider: opts.provider,
      expectVersion: m ? m[2] : null,
      tenantStatus: opts.tenantStatus || null,
      liveConfirmed: opts.liveConfirmed === true,
      execute: opts.execute === true
    });
  }

  window.__usxDeployAbort = false;
  window.__usxDeploy = { deployOne, deployFromRepo, openImportModal, fetchBuild, runGuards,
                         findTargetField, MODAL, TEXTAREA, DO_IMPORT, OPEN_BTN };
  console.log('%c[USx-DEPLOY]', 'color:#f66;font-weight:bold',
    'deploy_probe loaded -- THE ONLY WRITE PATH. Dry-run by default; execute:true required. ' +
    'One tenant per call, no batch, no all. Guards: explicit deptId matching BOTH the URL and the ' +
    'modal target field, modal+textarea+button present, payload parseable and version-stamped with ' +
    'ENTITIES plus exactly one provider bundle, LIVE needs liveConfirmed, and an abort flag. ' +
    'A CLICKED verdict is NOT proof -- verify_tenant_import.ps1 is. BUILD 2026-09-11d.');
})();
