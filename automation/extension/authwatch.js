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

  // COLOUR IS A PRIMARY SIGNAL, NOT DECORATION -- and it took a live run to learn that.
  // On IL_LEADS 2026-09-09 the icon beside "Queries:" came back class="chakra-icon arc-1oy47jo",
  // aria-label=null, title=null, data-icon=null -- a HASHED emotion class carrying no semantic
  // token at all -- with computed colour rgb(149,111,13). That is hue 43 / saturation 0.84, i.e.
  // amber. So the probable warning icon was PRESENT and the name-based test above returned false.
  // A heuristic that can only see semantic class names cannot see a Chakra icon, so the colour is
  // promoted to evidence. Still reported rather than trusted blindly: a themed icon can inherit
  // its colour, which is why `warnish` records WHICH signal fired.
  function colourFamily(css) {
    const m = /rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/.exec(css || '');
    if (!m) return null;
    const r = +m[1] / 255, g = +m[2] / 255, b = +m[3] / 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    if (d < 0.08) return null;                       // grey/near-grey: no hue to speak of
    const l = (max + min) / 2;
    const s = d / (1 - Math.abs(2 * l - 1));
    if (s < 0.3) return null;                        // washed out; not a deliberate status colour
    let h;
    if (max === r) h = 60 * (((g - b) / d) % 6);
    else if (max === g) h = 60 * (((b - r) / d) + 2);
    else h = 60 * (((r - g) / d) + 4);
    if (h < 0) h += 360;
    if (h >= 20 && h <= 70) return 'amber';          // the ticket's "yellow"
    if (h < 12 || h > 348) return 'red';             // danger, worth flagging too
    return null;
  }
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
        const byName = WARNISH.test(bag);
        let colour = null, fill = null;
        try { const cs = getComputedStyle(c); if (cs) { colour = cs.color || null; fill = cs.fill || null; } } catch (e) { /* detached */ }
        const fam = colourFamily(colour) || colourFamily(fill);
        // Record WHICH signal fired. A bare true/false would have hidden that the live IL icon
        // was found by colour ALONE -- and that is the fact that made the probe useful.
        const isWarn = byName || fam === 'amber' || fam === 'red';
        // The class is a hashed Chakra name, so it identifies nothing. Carry the markup: an
        // engineer can tell a warning TRIANGLE from an info circle by the path, and we cannot.
        let markup = null;
        try { markup = (c.outerHTML || '').replace(/\s+/g, ' ').slice(0, 300); } catch (e) {}
        out.push(Object.assign(snap(c), {
          warnish: isWarn, warnishBy: isWarn ? (byName ? (fam ? 'name+colour' : 'name') : 'colour') : null,
          colour, fill, colourFamily: fam, markup
        }));
      }
    }
    return out;
  }

  // ── 1b. THE MESSAGE IS IN A TOOLTIP, AND A TOOLTIP DOES NOT EXIST UNTIL YOU HOVER ────────
  // Rob, 2026-09-09: "i have the warning indicator when you hover over the indicator this is the
  // displayed error". That one sentence explains an empty field I had already shipped: the live
  // icon has title=null, aria-label=null and textContent=null, so `warnIconText` came back [] --
  // not because there is no message, but because a Chakra tooltip renders its text into a
  // SEPARATE PORTAL ELEMENT that is absent from the DOM while the icon is not hovered. Reading
  // attributes can never find it. SQA-217's fail condition is "icon doesn't appear WITH CORRECT
  // MESSAGE", so the message is half the ticket and it was unreachable.
  //
  // DIFF-BASED, deliberately: snapshot the tooltip-ish elements BEFORE hovering, hover, snapshot
  // again, and report only what is NEW. Otherwise an unrelated tooltip already open somewhere on
  // the page would be attributed to this icon -- the same false-attribution shape as reading a
  // sibling combination's optionals.
  //
  // NOTE ON "READ-ONLY": this DISPATCHES HOVER EVENTS, so authwatch is no longer strictly passive.
  // It still never fills a field and never clicks Send, which is what the ARM switch protects
  // against -- but the claim is now "cannot submit", not "touches nothing".
  const TIP_SEL = '[role="tooltip"], .chakra-tooltip, [id^="tooltip"], [id*="tooltip"], [data-popper-placement], [class*="tooltip"], [class*="Tooltip"], [class*="popover"]';
  function tipSet() {
    const m = new Map();
    for (const e of document.querySelectorAll(TIP_SEL)) {
      const t = (e.textContent || '').trim().replace(/\s+/g, ' ');
      if (t) m.set(e, t);
    }
    return m;
  }
  function fire(el, types) {
    for (const ty of types) {
      try {
        const E = (ty.indexOf('pointer') === 0) ? PointerEvent : MouseEvent;
        el.dispatchEvent(new E(ty, { bubbles: true, cancelable: true, view: window }));
      } catch (e) {
        try { el.dispatchEvent(new MouseEvent(ty, { bubbles: true, cancelable: true })); } catch (e2) {}
      }
    }
  }
  async function hoverCapture() {
    const lbl = queriesLabel();
    let targets = iconsNear(lbl).length ? null : null;
    // Re-collect the live ELEMENTS (iconsNear returns snapshots, not nodes).
    const scopes = [lbl, lbl && lbl.parentElement, lbl && lbl.parentElement && lbl.parentElement.parentElement].filter(Boolean);
    const seen = new Set(); const els = [];
    for (const s of scopes) {
      for (const c of s.querySelectorAll('svg, img, i, [class*="icon"], [class*="Icon"], [aria-label], [title], [data-icon]')) {
        if (seen.has(c)) continue; seen.add(c); els.push(c);
      }
    }
    const out = [];
    for (const c of els) {
      const before = tipSet();
      // Hover the icon AND its wrapper: a Chakra Tooltip attaches to the TRIGGER element, which is
      // commonly the icon's parent rather than the svg itself.
      for (const h of [c, c.parentElement].filter(Boolean)) {
        fire(h, ['pointerover', 'pointerenter', 'mouseover', 'mouseenter', 'mousemove']);
      }
      await sleep(450);
      const after = tipSet();
      const gained = [];
      after.forEach((txt, el) => { if (!before.has(el)) gained.push(txt); });
      // aria-describedby is the standard trigger->tooltip link once the tooltip is open.
      const desc = [];
      for (const h of [c, c.parentElement].filter(Boolean)) {
        const id = h.getAttribute && h.getAttribute('aria-describedby');
        if (id) for (const one of id.split(/\s+/)) {
          const t = document.getElementById(one);
          if (t) { const s2 = (t.textContent || '').trim().replace(/\s+/g, ' '); if (s2) desc.push(s2); }
        }
      }
      for (const h of [c, c.parentElement].filter(Boolean)) fire(h, ['mouseout', 'mouseleave', 'pointerleave']);
      await sleep(120);
      if (gained.length || desc.length) {
        out.push(Object.assign(snap(c), {
          tooltipText: gained.concat(desc.filter((d) => gained.indexOf(d) < 0)),
          via: gained.length ? 'portal-diff' : 'aria-describedby'
        }));
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

  // ── 4. IS UNIVERSAL SEARCH OFFERED HERE AT ALL? ───────────────────────────
  // SQA-217 (TC-12) states it outright: "In First Responder, there is no USX
  // icon available at all for a user without a State ID assigned." So an ABSENT
  // entry point is the EXPECTED behaviour on at least one surface -- and without
  // this check, "no warning icon" on such a surface would satisfy
  // matchesRnd71625RmsSymptom and report a symptom where the product is correct.
  // A verdict that cannot tell "no warning" from "nothing to warn about" is the
  // vacuous measurement this repo keeps finding in its own gates.
  function entryPoint(lbl, snd, cbs) {
    const heading = [...document.querySelectorAll('h1,h2,h3,h4,[role="heading"]')]
      .find((el) => /universal search/i.test((el.textContent || '').trim().slice(0, 80))) || null;
    const found = !!(lbl || snd.present || cbs.total || heading);
    return { found, viaQueriesLabel: !!lbl, viaSendButton: snd.present, viaCheckboxes: cbs.total > 0, viaHeading: snap(heading) };
  }

  // ── the instantaneous probe ────────────────────────────────────────────────
  function probeOnce() {
    const lbl = queriesLabel();
    const icons = iconsNear(lbl);
    const n = notices();
    const snd = sendState();
    const cbs = queryCheckboxes();
    return {
      at: new Date().toISOString(),
      queriesLabel: snap(lbl),
      queriesLabelFound: !!lbl,
      icons,
      warnIconPresent: icons.some((i) => i.warnish),
      // TC-12's fail condition is "icon doesn't appear WITH CORRECT MESSAGE", so the
      // icon's own accessible text is carried out separately -- presence alone
      // cannot answer whether the message was right.
      warnIconText: icons.filter((i) => i.warnish)
        .map((i) => [i.ariaLabel, i.title, i.text].filter(Boolean).join(' | '))
        .filter(Boolean),
      notices: n,
      noticePresent: !!(n.containers.length || n.phrase.length),
      send: snd,
      checkboxes: cbs,
      entryPoint: entryPoint(lbl, snd, cbs)
    };
  }

  // A SNAPSHOT WITH NO TRIGGER LABEL IS UNATTRIBUTABLE, and that cost a round trip on the very
  // first live run: the record showed Send disabled AND both query checkboxes disabled, which
  // either means "the interface is correctly blocked" or "this is an ordinary empty form" -- and
  // NOTHING in the record said which tenant state it was taken in. One missing string, two
  // opposite conclusions. So the probe now carries the label the watch already did.
  window.__usxAuthProbe = function (opts) {
    const o = opts || {};
    if (o.trigger && !TRIGGERS[o.trigger]) {
      console.log(TAG, 'color:#c00;font-weight:bold', `unknown trigger "${o.trigger}". Known: ${Object.keys(TRIGGERS).join(', ')}`);
      throw new Error('__usxAuthProbe: unknown trigger');
    }
    if (!o.trigger) {
      console.log(TAG, 'color:#c00;font-weight:bold',
        'NO TRIGGER GIVEN -- this snapshot cannot be interpreted. "Send disabled" reads as BLOCKED ' +
        'under tc10-sim-off and as an ORDINARY EMPTY FORM under control-normal. Pass one of: ' +
        Object.keys(TRIGGERS).join(', '));
    }
    const out = Object.assign({
      surface: surface(), trigger: o.trigger || null,
      triggerMeans: o.trigger ? TRIGGERS[o.trigger].setup : null,
      triggerTicket: o.trigger ? TRIGGERS[o.trigger].ticket : null,
      interpretable: !!o.trigger
    }, probeOnce());
    console.log(TAG, CSS, out);
    return out;
  };

  // ── the documented triggers ───────────────────────────────────────────────
  // Sourced from the SQA suite, NOT inferred. All three are expected to produce
  // a warning/blocked interface, and they are INDEPENDENT -- which is what makes
  // a negative result meaningful: a probe that finds nothing under TC-10 alone
  // is indistinguishable from a broken probe, but one that finds nothing under
  // TC-10 AND something under TC-12 has proven its own selectors.
  // EACH ENTRY CARRIES THE SETUP THE OPERATOR MUST HAVE DONE, IN PLAIN ENGLISH.
  // Rob, 2026-09-09: "your instructions were not clear" -- and they were not. I handed over enum
  // slugs (`tc10-sim-off`) and never said what to CONFIGURE for each, which is exactly the
  // "translate console names into GUI buttons, do not echo them" rule. The dropdown now shows
  // `label`; `setup` is what you must have already done; `ticket` is the authority. If the panel
  // cannot be operated without a chat message beside it, the panel is not finished.
  const TRIGGERS = {
    'no-device-id': {
      label: 'A - No device ID configured (simulation OFF)',
      setup: 'Device simulation is OFF and this device has NO device ID configured. This is the exact condition RND-71625 describes, so it is the run that matters most.',
      ticket: 'RND-71625'
    },
    'tc10-sim-off': {
      label: 'B - Simulation turned OFF (device IS registered)',
      setup: 'Settings > Universal Search: turn OFF device simulation (dex.device_simulation_mode / dex.simulation_mode / dex.local_simulation_mode). TENANT-WIDE -- turn it back ON straight after.',
      ticket: 'SQA-215'
    },
    'tc12-no-stateid': {
      label: 'C - Signed in as a user with NO State User ID',
      setup: 'Sign in as a user that has no State User ID assigned. PER-USER, so it does not disturb the tenant. Expect the icon WITH a message on RMS, blocking on CAD/FR, and NO Universal Search at all on First Responder.',
      ticket: 'SQA-217'
    },
    'tc13-image-reason': {
      label: 'D - NCIC Image = Y with Reason Code blank',
      setup: 'On the person form set NCIC Image to Y and leave Reason Code empty; submission must be blocked. Only reproducible where the provider builds a ReasonCode control -- TX_TLETS only, IL_LEADS_OFML metadata defines none.',
      ticket: 'SQA-218'
    },
    'control-normal': {
      label: 'E - CONTROL: everything normal (simulation ON)',
      setup: 'A fully authorized user, device simulation ON, nothing special configured. This is the BASELINE every other run is compared against -- without it, a disabled Send button cannot be told from an ordinary empty form.',
      ticket: 'baseline'
    }
  };

  // EXPORTED so ui.js can build its dropdown FROM this list rather than restating it.
  // A second copy of an enum in the panel would drift from the one the recorder validates
  // against, and the failure would be a trigger the button offers and the function rejects.
  window.__usxAuthTriggers = TRIGGERS;
  // Standalone hover capture, so the message can be read without committing to a full watch.
  window.__usxAuthHover = hoverCapture;

  // ── the watch ─────────────────────────────────────────────────────────────
  window.__usxAuthWatch = async function (opts) {
    const o = Object.assign({ seconds: 10, everyMs: 500, download: true, note: null, trigger: null }, opts || {});
    const sfc = surface();
    const t0 = Date.now();
    const samples = [];
    const firstSeen = { warnIcon: null, notice: null, sendDisabled: null, queriesLabel: null };
    // A run that does not say WHICH documented trigger it was made under is not
    // comparable to any other run, and comparing runs is the entire value here.
    // The SQA suite documents three independent triggers for the same symptom
    // family, so the label is an enum, not free text.
    if (o.trigger && !TRIGGERS[o.trigger]) {
      console.log(TAG, 'color:#c00;font-weight:bold', `unknown trigger "${o.trigger}". Known: ${Object.keys(TRIGGERS).join(', ')}`);
      throw new Error('__usxAuthWatch: unknown trigger -- refusing to record an unlabelled run');
    }
    if (!o.trigger) {
      console.log(TAG, 'color:#c00;font-weight:bold', `no trigger given. Pass one of: ${Object.keys(TRIGGERS).join(', ')} -- an unlabelled record cannot be compared to a control.`);
    }

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
    // Hover LAST, after the passive window has closed, so dispatching events cannot influence any
    // of the timing measurements above.
    let hover = [];
    try { hover = await hoverCapture(); } catch (e) { hover = [{ error: e.message }]; }
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
      usxEntryPointFound: last.entryPoint.found,
      // The message half of SQA-217's fail condition. Absent from attributes on this build --
      // it lives in a hover-only tooltip portal.
      hoverMessagesFound: hover.filter((h) => h && h.tooltipText && h.tooltipText.length).length,
      hoverMessages: hover.reduce((a, h) => a.concat((h && h.tooltipText) || []), []),
      // The exact shape RND-71625 reports on RMS: nothing at all.
      // GUARDED on the entry point existing. SQA-217 says First Responder shows NO
      // USX icon at all for a user without a State ID -- on that surface "no warning"
      // is the CORRECT product behaviour, and reporting it as the RMS symptom would be
      // a false positive on this tool's own headline verdict.
      matchesRnd71625RmsSymptom: last.entryPoint.found
        && firstSeen.warnIcon === null && firstSeen.notice === null && firstSeen.sendDisabled === null
    };

    const rec = {
      kind: 'usx-authwatch', ticket: 'RND-71625',
      capturedAt: new Date().toISOString(),
      note: o.note,
      trigger: o.trigger || null,
      triggerMeans: o.trigger ? TRIGGERS[o.trigger].setup : null,
      triggerTicket: o.trigger ? TRIGGERS[o.trigger].ticket : null,
      simulationSettingsReadable: false,   // stated, not implied: this page cannot see dex.*simulation* settings
      surface: sfc, verdict, firstSeen, samples, finalSnapshot: last
    };

    console.log(TAG, CSS, verdict);
    if (verdict.matchesRnd71625RmsSymptom) {
      console.log(TAG, CSS, 'NO icon, NO notice and Send never disabled for the whole window -- this is the RND-71625 RMS symptom. Pair it with a simulation-ON control run before concluding.');
    }
    if (!verdict.usxEntryPointFound) {
      console.log(TAG, 'color:#c00;font-weight:bold', 'NO Universal Search entry point found on this surface -- no Queries label, no Send button, no query checkboxes, no heading. Per SQA-217 that is the EXPECTED state on First Responder for a user without a State ID, so this run reports no symptom. It is NOT evidence about the icon.');
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
