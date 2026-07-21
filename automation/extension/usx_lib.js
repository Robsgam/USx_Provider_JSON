// ===========================================================================
//  USx Tenant Testing automation -- shared primitives (usx_lib.js)
//  Loaded first (MAIN world) on the Mark43 RMS tenant. Defines window.__usxLib
//  with the spike-PROVEN interaction primitives:
//    - fillText / selectReactSelect / fillField (auto-detect)
//    - clickSend
//    - extractConnectCicXml (dex-log capture)
//  All selectors key off the field's DOM id, which equals the QIF fieldId.
// ===========================================================================
(() => {
  if (window.__usxLib) return;

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const q = (id) => document.querySelector('#' + CSS.escape(id));

  // Native <input type=date> only accepts ISO yyyy-MM-dd via .value -- any other string
  // (e.g. MM/DD/YYYY, which is fine for a human typing through the browser's own locale
  // mask) is silently rejected and .value stays empty. Normalize before assigning.
  function toIsoDate(v) {
    if (!v) return v;
    if (/^\d{4}-\d{2}-\d{2}$/.test(v)) return v;
    const m = String(v).match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (m) return `${m[3]}-${m[1].padStart(2, '0')}-${m[2].padStart(2, '0')}`;
    return v;
  }

  // React-Aria segmented date field (Arc "arc-date-input"): the field id lands on a wrapper
  // DIV containing 3 contenteditable [role=spinbutton] divs (month/day/year) showing
  // placeholder text (mm/dd/yyyy) until real input. There is NO <input>/<textarea> and no
  // .value property.
  //
  // Live-confirmed via DOM experiment 2026-07-01 (NJ_NJCJIS Person BirthDate): dispatching
  // digit keydown/keypress/keyup does NOTHING, and dispatching beforeinput/input does NOTHING
  // -- this widget only responds to ArrowUp/ArrowDown. Also confirmed: the FIRST ArrowUp on an
  // "Empty" segment does not increment by 1 -- it "activates" the segment to its existing
  // (pre-interaction) aria-valuenow. Only presses after that behave as a true +/-1 step.
  // So: read the starting aria-valuenow, press ArrowUp once to activate if currently Empty,
  // then walk from wherever it lands to the target with plain +/-1 presses.
  function pressArrow(el, up) {
    const opts = { key: up ? 'ArrowUp' : 'ArrowDown', code: up ? 'ArrowUp' : 'ArrowDown', keyCode: up ? 38 : 40, which: up ? 38 : 40, bubbles: true, cancelable: true };
    el.dispatchEvent(new KeyboardEvent('keydown', opts));
  }
  async function stepSegment(seg, targetVal) {
    const readNow = () => parseInt(seg.getAttribute('aria-valuenow'), 10);
    const readText = () => (seg.getAttribute('aria-valuetext') || '').trim();
    seg.focus();
    await sleep(80);
    let current = readNow();
    if (/empty/i.test(readText())) {
      pressArrow(seg, true);
      await sleep(90);
      current = readNow();
    }
    const delta = targetVal - current;
    for (let i = 0; i < Math.abs(delta); i++) {
      pressArrow(seg, delta >= 0);
      await sleep(35);
    }
    await sleep(80);
    return { ok: readNow() === targetVal && !/empty/i.test(readText()), value: readText() };
  }
  async function fillDateSegments(fieldId, value) {
    const wrapperEl = q(fieldId);
    if (!wrapperEl) return { fieldId, kind: 'date-segments', ok: false, err: 'not found' };
    const iso = toIsoDate(value);
    const m = String(iso).match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!m) return { fieldId, kind: 'date-segments', ok: false, err: 'expected ISO yyyy-MM-dd, got ' + value };
    const [, yyyy, mm, dd] = m;
    const segs = [...wrapperEl.querySelectorAll('[role="spinbutton"]')];
    const findSeg = (re) => segs.find((s) => re.test(s.getAttribute('aria-label') || ''));
    const monthSeg = findSeg(/month/i), daySeg = findSeg(/day/i), yearSeg = findSeg(/year/i);
    if (!monthSeg || !daySeg || !yearSeg) return { fieldId, kind: 'date-segments', ok: false, err: 'segments not found (' + segs.length + ' spinbuttons)' };
    const rMonth = await stepSegment(monthSeg, parseInt(mm, 10));
    const rDay = await stepSegment(daySeg, parseInt(dd, 10));
    const rYear = await stepSegment(yearSeg, parseInt(yyyy, 10));
    const ok = rMonth.ok && rDay.ok && rYear.ok;
    return { fieldId, kind: 'date-segments', ok, value: `${rMonth.value}/${rDay.value}/${rYear.value}` };
  }

  // Plain Chakra text input: React controlled-input pattern.
  function fillText(fieldId, value) {
    let el = q(fieldId);
    if (!el) return { fieldId, kind: 'text', ok: false, err: 'not found' };
    // If the id landed on a wrapper (e.g. datepicker div), drill to the real input.
    if (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA') {
      const inner = el.querySelector('input, textarea');
      if (!inner) return { fieldId, kind: 'text', ok: false, err: 'no input inside ' + el.tagName };
      el = inner;
    }
    // Native date input: must be ISO yyyy-MM-dd regardless of the format we were passed.
    if (el.tagName === 'INPUT' && el.type === 'date') {
      const iso = toIsoDate(value);
      Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(el, iso);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return { fieldId, kind: 'date', ok: el.value === iso, value: el.value };
    }
    const proto = el.tagName === 'TEXTAREA'
      ? window.HTMLTextAreaElement.prototype
      : window.HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return { fieldId, kind: 'text', ok: el.value === String(value), value: el.value };
  }

  // Poll a predicate instead of trusting a fixed sleep -- the filtered option list (network-
  // backed, e.g. State/SexCode) can take longer than a fixed wait on a live tenant, especially
  // mid-way through a fast automated run. Same pattern as capture.js's waitFor/waitForXml.
  async function pollFor(fn, timeoutMs, stepMs) {
    const steps = Math.max(1, Math.floor(timeoutMs / stepMs));
    for (let i = 0; i < steps; i++) {
      const r = fn();
      if (r) return r;
      await sleep(stepMs);
    }
    return fn();
  }

  // Close a dropdown left open after a failed fill (Escape, then blur as a fallback) -- live-
  // confirmed the field is otherwise left in an open dropdown state at Send time, which can
  // also interfere with subsequent fields' open/scope detection.
  function closeDropdown(input) {
    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, which: 27, bubbles: true, cancelable: true }));
    input.blur();
  }

  // react-select (Arc): open menu -> filter by CODE -> click matching option.
  // Option labels render as "<CODE> - <Name>"; combo values are CODEs.
  //
  // Stage-by-stage [USx-SEL] logging is intentional and always-on (not debug-gated): this
  // function has failed intermittently on live tenants twice already (SexCode, RegistrationState)
  // in ways a poll-ceiling increase alone didn't fully resolve. Rather than requiring another
  // manual diagnostic round-trip, the next failure's exact stage (menu never opened / no options
  // rendered / no regex match / display never confirmed) shows up directly in the normal
  // console log the operator already captures.
  async function selectReactSelect(fieldId, value) {
    const dbg = (...a) => console.log('%c[USx-SEL]', 'color:#a0a', fieldId, ...a);
    const input = q(fieldId);
    if (!input) return { fieldId, kind: 'select', ok: false, err: 'not found' };
    const control = input.closest('.arc-select__control') || input.closest('[class*="control"]');
    input.focus();
    (control || input).dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', keyCode: 40, bubbles: true }));

    // Poll for the dropdown actually OPENING before typing the filter value -- previously a
    // blind 300ms sleep with no confirmation it opened at all. A tiny option list (SexCode:
    // 2-3 options) still failing intermittently even with a 2s option-render poll pointed at
    // THIS earlier, unconfirmed step rather than option-render speed.
    let t = Date.now();
    const opened = await pollFor(() => document.querySelector('[class*="select__menu"], [class*="select__option"]'), 1500, 100);
    dbg(opened ? `menu opened after ${Date.now() - t}ms` : `menu open NOT confirmed after ${Date.now() - t}ms -- proceeding best-effort`);

    Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(input, value);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    const code = String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp('^' + code + '\\b', 'i');

    // Scope the option lookup to THIS field's own open listbox via aria-controls (the standard
    // ARIA combobox link from an input to its own menu) instead of querying the whole document --
    // fixes cross-field contamination from a different, unrelated open menu elsewhere on the page.
    const ariaControls = input.getAttribute('aria-controls') || (control && control.getAttribute('aria-controls'));
    const scopeRoot = () => (ariaControls && document.getElementById(ariaControls)) || document;

    // Live-confirmed root cause (2026-07-01, full option dump): the class-based selector also
    // matches SUBSTRING-HIGHLIGHT spans NESTED INSIDE other (non-matching) options -- e.g.
    // filtering "GA" against "MI - Michigan" (which contains "ga" in "michiGAn") splits that
    // label into 3 child spans ("MI - Michi" / "ga" / "n") for highlighting, and the isolated
    // "ga" fragment trivially matches the anchored regex against itself.
    // Tried [role="option"] alone to exclude these (previous commit) -- WRONG, this component
    // doesn't set role=option on the real rows at all, so that matched nothing and broke every
    // field including the previously-working ImageIndicator. The correct fix: keep the
    // class-based selector, but discard any matched element that is a DESCENDANT of another
    // matched element -- a highlight fragment is always nested inside its real parent row, so
    // this keeps only the outermost (real) rows regardless of what class/role they carry.
    t = Date.now();
    const found = await pollFor(() => {
      const all = [...scopeRoot().querySelectorAll('[class*="select__option"]')];
      const opts = all.filter((o) => !all.some((other) => other !== o && other.contains(o)));
      if (!opts.length) return null;
      const m = opts.find((o) => re.test((o.textContent || '').trim()));
      return { opt: m || opts[0], matched: !!m, count: opts.length, allTexts: opts.map((o) => (o.textContent || '').trim()) };
    }, 2500, 120);
    if (!found) { dbg(`no options rendered after ${Date.now() - t}ms (aria-controls=${ariaControls || 'none'}) -- FAIL`); closeDropdown(input); return { fieldId, kind: 'select', ok: false, err: 'no option for ' + value }; }
    const { opt, matched, count, allTexts } = found;
    dbg(`${count} option(s) (aria-controls=${ariaControls || 'none, unscoped'}) after ${Date.now() - t}ms; using ${matched ? 'regex match' : `opts[0] FALLBACK (no regex match for "${value}")`}: "${(opt.textContent || '').trim()}"`);
    // Full option dump whenever the match looks suspicious (anomalously short text, e.g. the
    // earlier "m" bogus match) -- so the next failure's actual option list is in the log
    // without a separate manual diagnostic round-trip.
    if (!matched || (opt.textContent || '').trim().length <= 2) dbg(`all options: [${allTexts.map((t2) => JSON.stringify(t2)).join(', ')}]`);

    opt.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    opt.dispatchEvent(new MouseEvent('click', { bubbles: true }));

    // Poll up to 1s for the control's display text to update.
    t = Date.now();
    const display = await pollFor(() => {
      const d = ((input.closest('.arc-select__control') || control)?.textContent || '').trim();
      return re.test(d) ? d : null;
    }, 1000, 100) || ((input.closest('.arc-select__control') || control)?.textContent || '').trim();
    const ok = re.test(display);
    dbg(ok ? `display confirmed "${display}" after ${Date.now() - t}ms` : `display NEVER matched (got "${display}") after ${Date.now() - t}ms -- FAIL`);
    return { fieldId, kind: 'select', ok, display };
  }

  // Auto-detect: react-select inputs carry class arc-select__input; a segmented date field
  // (FormDate) has [role=spinbutton] children instead of an <input>; else plain text.
  async function fillField(fieldId, value) {
    const el = q(fieldId);
    if (!el) return { fieldId, ok: false, err: 'not found' };
    if ((el.className || '').toString().includes('arc-select__input')) {
      return await selectReactSelect(fieldId, value);
    }
    if (el.querySelector && el.querySelector('[role="spinbutton"]')) {
      return await fillDateSegments(fieldId, value);
    }
    return fillText(fieldId, value);
  }

  // Click the enabled "Send" button (exact text; not "Send & Clear Form").
  function clickSend() {
    const send = [...document.querySelectorAll('button')]
      .find((b) => (b.textContent || '').trim() === 'Send' && !b.disabled);
    if (!send) return { ok: false, err: 'Send button not enabled' };
    send.click();
    return { ok: true };
  }

  // Pull the ConnectCic request XML out of arbitrary page text.
  function extractConnectCicXml(text) {
    if (!text) return null;
    // If the text is a JSON body (network capture), find the raw (already-unescaped) XML
    // string value inside it -- avoids the double-escaped \" damage from regexing JSON.
    let candidates = [text];
    try {
      const j = JSON.parse(text);
      const found = [];
      (function walk(o) {
        if (typeof o === 'string') { if (o.includes('ConnectCicApi')) found.push(o); }
        else if (o && typeof o === 'object') { for (const k in o) walk(o[k]); }
      })(j);
      if (found.length) candidates = found;
    } catch (e) {}
    for (const c of candidates) {
      const m = c.match(/<\?xml[\s\S]*?<\/api:ConnectCicApi>/) || c.match(/<api:ConnectCicApi[\s\S]*?<\/api:ConnectCicApi>/);
      if (!m) continue;
      const xml = m[0];
      // Prefer the transaction id; the <Id> fallback must be the ULID, NOT the Session <Id>.
      const txId = (xml.match(/<api:Transaction\s+id="([^"]+)"/) || [])[1] ||
                   (xml.match(/<Id>(01[0-9A-HJKMNP-TV-Z]{20,})<\/Id>/) || [])[1] || null;
      const messageType = (xml.match(/<MessageType>([^<]+)<\/MessageType>/) || [])[1] || null;
      return { xml, transactionId: txId, messageType };
    }
    return null;
  }

  function triggerDownload(filename, obj) {
    const json = JSON.stringify(obj, null, 2);
    const nonce = 'usx-' + Date.now() + '-' + Math.floor(Math.random() * 1e6);
    let done = false;
    function anchorFallback() {
      if (done) return; done = true;
      // Original page-context download. Works for a single download, but Chrome's
      // "automatic multiple downloads" gate silently blocks the 2nd..Nth in a burst --
      // which is why per-entity capture bursts used to lose every file after the first.
      const blob = new Blob([json], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      document.body.appendChild(a); a.click(); a.remove();
    }
    // Preferred path: hand the download to the background service worker via bridge.js,
    // which downloads through chrome.downloads.download() -- immune to that gate, so
    // back-to-back captures all land (uniquified (1)/(2) suffixes, ingested in bulk by
    // import_captured_tests.ps1). If no ack arrives within the grace window (old
    // extension build without the worker/bridge), fall back to the anchor click.
    try {
      const onAck = function (ev) {
        const d = ev && ev.data;
        if (ev.source !== window || !d || d.__usxDownloadAck !== true || d.nonce !== nonce) return;
        window.removeEventListener('message', onAck);
        if (d.ok) { done = true; }
        else { console.warn('[USx] worker download failed (' + (d.error || '?') + '); using anchor fallback'); anchorFallback(); }
      };
      window.addEventListener('message', onAck);
      const dataUrl = 'data:application/json;base64,' + btoa(unescape(encodeURIComponent(json)));
      window.postMessage({ __usxDownload: true, nonce: nonce, filename: filename, dataUrl: dataUrl }, '*');
      setTimeout(function () { window.removeEventListener('message', onAck); anchorFallback(); }, 1500);
    } catch (e) {
      anchorFallback();
    }
  }

  // Derive the provider folder name from the tenant hostname: usx-nj-njcjis -> NJ_NJCJIS,
  // usx-fl-fcic -> FL_FCIC. Lets one extension serve every USx tenant.
  function providerFromHost() {
    const m = location.hostname.match(/usx-([a-z0-9-]+)\.mark43/i);
    return m ? m[1].toUpperCase().replace(/-/g, '_') : 'UNKNOWN';
  }

  window.__usxLib = { sleep, q, fillText, selectReactSelect, fillField, clickSend, extractConnectCicXml, triggerDownload, providerFromHost };
  // Build tag: bump on every extension change so console pastes identify the loaded build
  // (version skew burned attempt 4: a stale build still had the parked Run ALL button).
  console.log('%c[USx]', 'color:#0a0;font-weight:bold', 'usx_lib loaded. BUILD 2026-07-21a (downloads via SW bridge)');
})();
