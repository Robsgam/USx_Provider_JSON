// ===========================================================================
//  USx Tenant Testing automation -- AUTH/BLOCK WATCH (authwatch.js)
//
//  WHY THIS EXISTS: RND-71625 (P3, Amy Blair 2026-08-31, found in SQA-145 TC-10).
//  With device simulation OFF, the expected YELLOW WARNING ICON on the "Queries"
//  label never appears, and the surfaces disagree about blocking:
//     RMS        -- no icon AND no blocking indicator of any kind
//     CAD / FR   -- no icon, but a ConnectCIC "License Violation Notice" blocks
//  So an officer on RMS gets no signal that queries are unavailable.
//
//  WHAT THIS DOES, AND WHAT IT CANNOT DO. It turns "no icon appeared" from an
//  eyeball observation into a timestamped, downloadable record: which surface,
//  whether the icon EVER rendered (and when), what notice text appeared, and
//  whether Send was actually blocked. It proves WHETHER, never WHY -- the cause
//  is platform-side and only engineering can settle it.
//
//  ⚠️ IT POLLS, AND THAT IS THE WHOLE POINT. The ticket says the icon should
//  appear "within 2-3 seconds (or after a refresh)". A one-shot probe at t=0
//  would miss a late render and report a false absence -- the same vacuous
//  measurement this repo keeps finding elsewhere. So the default is a 10s watch
//  that records FIRST-SEEN time per signal, and an absence is only reported
//  after the full window elapses.
//
//  USAGE in the Console on any tenant page (RMS / CAD / First Responder):
//    __usxAuthWatch()                       // 10s watch, prints + downloads
//    __usxAuthWatch({ seconds: 20 })        // longer window
//    __usxAuthWatch({ download: false })    // print only, no file
//    __usxAuthProbe()                       // single instantaneous snapshot
//
//  Run it TWICE per surface -- once with device simulation ON (control) and once
//  OFF (the reported condition). A single run cannot distinguish "the icon is
//  broken" from "this tenant is configured so no warning is due".
// ===========================================================================
(() => {
  // ── RUNS STANDALONE ON PURPOSE -- do NOT convert this to `if (!L) return;` ──────────
  // The manifest loads content scripts only on https://*.mark43.com/rms/*, but RND-71625
  // spans RMS **and CAD and First Responder**. Widening that match would also load the
  // DRIVER onto CAD/FR, and the extension's stated safety model is exactly that allowlist
  // plus the on-screen ARM switch -- so widening it is a deliberate decision for Rob, not
  // a side effect of adding a diagnostic.
  // Instead this file degrades: with usx_lib present it uses the proven SW-bridge download;
  // pasted into the Console on any other surface it falls back to local sleep + anchor
  // download. authwatch is READ-ONLY (it observes and saves; it never fills or sends), so
  // pasting it carries none of the driver's risk.
  const L = window.__usxLib || null;
  const sleep = (L && L.sleep) ? L.sleep : ((ms) => new Promise((r) => setTimeout(r, ms)));
  const save = (L && L.triggerDownload) ? L.triggerDownload : function (filename, obj) {
    // Single download per run, so Chrome's automatic-multiple-downloads gate (the reason
    // usx_lib routes through the background worker) does not apply here.
    const blob = new Blob([JSON.stringify(obj, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = filename;
    document.body.appendChild(a); a.click(); a.remove();
  };

  const TAG = '%c[USx-AUTHWATCH]';
  const CSS = 'color:#b8860b;font-weight:bold';

  // ── which surface are we on? ──────────────────────────────────────────────
  // Derived, never assumed: the ticket's whole finding is that the surfaces
  // BEHAVE DIFFERENTLY, so a record that does not name its surface is useless.
  function surface() {
    const p = location.pathname.toLowerCase();
    const h = (document.title || '').toLowerCase();
    let name = 'UNKNOWN';
    if (/first[-_ ]?responder|\/fr\b/.test(p + ' ' + h)) name = 'FIRST_RESPONDER';
    else if (/\bcad\b|dispatch/.test(p + ' ' + h))        name = 'CAD';
    else if (/\/rms\//.test(p))                            name = 'RMS';
    return { name, url: location.href, path: location.pathname, title: document.title || null };
  }

  function snap(el) {
    if (!el) return null;
    return {
      tag: el.tagName,
      role: el.getAttribute && el.getAttribute('role') || null,
      testId: el.getAttribute && (el.getAttribute('data-testid') || el.getAttribute('data-test-id')) || null,
      ariaLabel: el.getAttribute && el.getAttribute('aria-label') || null,
      title: el.getAttribute && el.getAttribute('title') || null,
      cls: (el.getAttribute && el.getAttribute('class') || '').slice(0, 120) || null,
      text: (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 200) || null
    };
  }

  // ── 1. the "Queries" label, and any icon attached to it ───────────────────
  // The signal in the ticket is an ICON, not text, so a text match cannot find
  // it. Strategy: locate the label, then walk its own subtree AND its parent's
  // subtree (icons are commonly siblings, not children) looking for svg/img or
  // anything whose class/aria/title smells like a warning.
  const WARNISH = /warn|alert|caution|danger|error|exclam|triangle|attention/i;
  function queriesLabel() {
    const cands = [...document.querySelectorAll('label,span,div,h1,h2,h3,h4,p,button,legend')]
      .filter((el) => {
        const t = (el.textContent || '').trim();
        if (!t || t.length > 40) return false;              // the LABEL, not a container that happens to contain it
        return /^queries\b/i.test(t) || /^query\b/i.test(t);
      });
    // innermost wins: the shortest text is the actual label rather than its wrapper
    cands.sort((a, b) => (a.textContent || '').trim().length - (b.textContent || '').trim().length);
    return cands[0] || null;
  }
  function iconsNear(el) {
    if (!el) return [];
    const scopes = [el, el.parentElement, el.parentElement && el.parentElement.parentElement].filter(Boolean);
    const seen = new Set(); const out = [];
    for (const s of scopes) {
      for (const c of s.querySelectorAll('svg, img, i, [class*="icon"], [class*="Icon"], [aria-label], [title], [data-icon]')) {
        if (seen.has(c)) continue; seen.add(c);
        const bag = [c.getAttribute('class') || '', c.getAttribute('aria-label') || '',
                     c.getAttribute('title') || '', c.getAttribute('data-icon') || ''].join(' ');
        const isWarn = WARNISH.test(bag);
        // colour is a real signal here -- the ticket calls it a YELLOW icon -- but it is
        // reported, never used as the sole test: a themed icon may inherit its colour.
        let colour = null;
        try { const cs = getComputedStyle(c); colour = cs && (cs.color || cs.fill) || null; } catch (e) { /* detached */ }
        out.push(Object.assign(snap(c), { warnish: isWarn, colour }));
      }
    }
    return out;
  }

  // ── 2. blocking notices ───────────────────────────────────────────────────
  // Reuses the container selectors driver.js's RMS recon already proved find
  // Chakra toasts/alerts, and WIDENS the phrase set to the authorization family
  // the ticket names. driver.js's regex targets result/failure phrasing
  // ("mock result", "no results"), which would not match a licence notice.
  const NOTICE_RE = /licen[sc]e violation|not authoriz|unauthoriz|device (registration|simulation)|simulation mode|blocked|forbidden|permission|denied|contact your admin/i;
  const ALERT_SEL = '[role="alert"], [role="status"], [aria-live], .chakra-toast, .chakra-alert, [class*="toast"], [class*="Toast"], [class*="alert"], [class*="Alert"], [class*="banner"], [class*="Banner"]';
  function outermostOnly(list) {
    const els = [...list];
    return els.filter((e) => !els.some((o) => o !== e && o.contains(e)));
  }
  function notices() {
    const containers = outermostOnly(document.querySelectorAll(ALERT_SEL)).map(snap).filter((s) => s && s.text);
    const phrase = outermostOnly(
      [...document.querySelectorAll('div,span,p,li,td,h1,h2,h3,h4')].filter((el) => {
        const t = (el.textContent || '').trim();
        return t && t.length < 400 && NOTICE_RE.test(t);
      })
    ).map(snap).slice(0, 15);
    return { containers, phrase };
  }

  // ── 3. is the query interface actually blocked? ───────────────────────────
  // The ticket's expectation is TWO things: a warning icon AND a blocked
  // interface. They are independent, so they are measured independently --
  // "no icon but correctly blocked" and "icon but still sendable" are
  // different bugs and must not collapse into one verdict.
  function sendState() {
    const btns = [...document.querySelectorAll('button')].filter((b) => /^send/i.test((b.textContent || '').trim()));
    if (!btns.length) return { present: false, enabled: null, disabled: null, count: 0 };
    const anyEnabled = btns.some((b) => !b.disabled);
    return {
      present: true, count: btns.length,
      enabled: anyEnabled, disabled: !anyEnabled,
      buttons: btns.map((b) => ({ text: (b.textContent || '').trim().slice(0, 40), disabled: !!b.disabled }))
    };
  }
  function queryCheckboxes() {
    const cbs = [...document.querySelectorAll('input[type="checkbox"]')];
    return { total: cbs.length, checked: cbs.filter((c) => c.checked).length, disabled: cbs.filter((c) => c.disabled).length };
  }

  // ── the instantaneous probe ────────────────────────────────────────────────
  function probeOnce() {
    const lbl = queriesLabel();
    const icons = iconsNear(lbl);
    const n = notices();
    return {
      at: new Date().toISOString(),
      queriesLabel: snap(lbl),
      queriesLabelFound: !!lbl,
      icons,
      warnIconPresent: icons.some((i) => i.warnish),
      notices: n,
      noticePresent: !!(n.containers.length || n.phrase.length),
      send: sendState(),
      checkboxes: queryCheckboxes()
    };
  }

  window.__usxAuthProbe = function () {
    const out = Object.assign({ surface: surface() }, probeOnce());
    console.log(TAG, CSS, out);
    return out;
  };

  // ── the watch ─────────────────────────────────────────────────────────────
  window.__usxAuthWatch = async function (opts) {
    const o = Object.assign({ seconds: 10, everyMs: 500, download: true, note: null }, opts || {});
    const sfc = surface();
    const t0 = Date.now();
    const samples = [];
    const firstSeen = { warnIcon: null, notice: null, sendDisabled: null, queriesLabel: null };

    console.log(TAG, CSS, `watching ${sfc.name} for ${o.seconds}s -- an ABSENCE is only reported after the full window`);
    while (Date.now() - t0 < o.seconds * 1000) {
      const s = probeOnce();
      const tRel = Date.now() - t0;
      if (s.queriesLabelFound && firstSeen.queriesLabel === null) firstSeen.queriesLabel = tRel;
      if (s.warnIconPresent   && firstSeen.warnIcon     === null) firstSeen.warnIcon     = tRel;
      if (s.noticePresent     && firstSeen.notice       === null) firstSeen.notice       = tRel;
      if (s.send.disabled     && firstSeen.sendDisabled === null) firstSeen.sendDisabled = tRel;
      samples.push({ tRel, warnIconPresent: s.warnIconPresent, noticePresent: s.noticePresent,
                     sendDisabled: s.send.disabled, queriesLabelFound: s.queriesLabelFound });
      await sleep(o.everyMs);
    }

    const last = probeOnce();
    // VERDICT is deliberately descriptive, not pass/fail. Whether a warning is DUE
    // depends on the tenant's simulation settings, which this page cannot read -- so
    // calling an absence a FAILURE here would be asserting something unmeasured.
    // That is why the record demands a control run (simulation ON) to compare against.
    const verdict = {
      surface: sfc.name,
      warnIconEverSeen: firstSeen.warnIcon !== null,
      warnIconFirstSeenMs: firstSeen.warnIcon,
      noticeEverSeen: firstSeen.notice !== null,
      noticeFirstSeenMs: firstSeen.notice,
      sendEverDisabled: firstSeen.sendDisabled !== null,
      sendDisabledFirstSeenMs: firstSeen.sendDisabled,
      queriesLabelFound: firstSeen.queriesLabel !== null,
      windowMs: o.seconds * 1000,
      samples: samples.length,
      // The exact shape RND-71625 reports on RMS: nothing at all.
      matchesRnd71625RmsSymptom: firstSeen.warnIcon === null && firstSeen.notice === null && firstSeen.sendDisabled === null
    };

    const rec = {
      kind: 'usx-authwatch', ticket: 'RND-71625',
      capturedAt: new Date().toISOString(),
      note: o.note,
      simulationSettingsReadable: false,   // stated, not implied: this page cannot see dex.*simulation* settings
      surface: sfc, verdict, firstSeen, samples, finalSnapshot: last
    };

    console.log(TAG, CSS, verdict);
    if (verdict.matchesRnd71625RmsSymptom) {
      console.log(TAG, CSS, 'NO icon, NO notice and Send never disabled for the whole window -- this is the RND-71625 RMS symptom. Pair it with a simulation-ON control run before concluding.');
    }
    if (!verdict.queriesLabelFound) {
      console.log(TAG, 'color:#c00;font-weight:bold', 'The "Queries" label was never found -- the icon probe had NOTHING to anchor to, so its absence proves nothing. Check the label text/markup changed, and re-run on a page where the query list renders.');
    }
    if (o.download) {
      const stamp = new Date().toISOString().replace(/[:.]/g, '-');
      save(`usx_authwatch_${sfc.name}_${stamp}.json`, rec);
    }
    return rec;
  };

  console.log(TAG, CSS, 'loaded. __usxAuthWatch() / __usxAuthProbe() -- RND-71625 evidence capture.');
})();
