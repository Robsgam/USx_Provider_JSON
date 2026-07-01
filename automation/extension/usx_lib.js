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
  // .value property -- it only responds to actual keyboard digit presses per segment, the
  // same way a person types into it (zero-padded: 2 digits month/day, 4 digits year).
  // Live-confirmed via DOM inspection 2026-07-01 (NJ_NJCJIS Person BirthDate).
  function pressDigit(el, digit) {
    const opts = { key: digit, code: 'Digit' + digit, keyCode: digit.charCodeAt(0), which: digit.charCodeAt(0), bubbles: true, cancelable: true };
    el.dispatchEvent(new KeyboardEvent('keydown', opts));
    el.dispatchEvent(new KeyboardEvent('keypress', opts));
    el.dispatchEvent(new KeyboardEvent('keyup', opts));
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
    for (const [seg, digits] of [[monthSeg, mm], [daySeg, dd], [yearSeg, yyyy]]) {
      seg.focus();
      for (const ch of digits) { pressDigit(seg, ch); await sleep(70); }
      await sleep(100);
    }
    yearSeg.blur();
    const readVal = (s) => (s.getAttribute('aria-valuetext') || '').trim();
    const ok = !/empty/i.test(readVal(monthSeg)) && !/empty/i.test(readVal(daySeg)) && !/empty/i.test(readVal(yearSeg));
    return { fieldId, kind: 'date-segments', ok, value: `${readVal(monthSeg)}/${readVal(daySeg)}/${readVal(yearSeg)}` };
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

  // react-select (Arc): open menu -> filter by CODE -> click matching option.
  // Option labels render as "<CODE> - <Name>"; combo values are CODEs.
  async function selectReactSelect(fieldId, value) {
    const input = q(fieldId);
    if (!input) return { fieldId, kind: 'select', ok: false, err: 'not found' };
    const control = input.closest('.arc-select__control') || input.closest('[class*="control"]');
    input.focus();
    (control || input).dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', keyCode: 40, bubbles: true }));
    await sleep(300);
    Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(input, value);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    const code = String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp('^' + code + '\\b', 'i');
    // Poll up to 2s for the filtered option list to render, instead of one fixed 450ms sleep.
    const opt = await pollFor(() => {
      const opts = [...document.querySelectorAll('[class*="select__option"], [role=option]')];
      if (!opts.length) return null;
      return opts.find((o) => re.test((o.textContent || '').trim())) || opts[0];
    }, 2000, 120);
    if (!opt) return { fieldId, kind: 'select', ok: false, err: 'no option for ' + value };
    opt.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    opt.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    // Poll up to 1s for the control's display text to update, instead of one fixed 180ms sleep.
    const display = await pollFor(() => {
      const d = ((input.closest('.arc-select__control') || control)?.textContent || '').trim();
      return re.test(d) ? d : null;
    }, 1000, 100) || ((input.closest('.arc-select__control') || control)?.textContent || '').trim();
    return { fieldId, kind: 'select', ok: re.test(display), display };
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
    const blob = new Blob([JSON.stringify(obj, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a); a.click(); a.remove();
  }

  // Derive the provider folder name from the tenant hostname: usx-nj-njcjis -> NJ_NJCJIS,
  // usx-fl-fcic -> FL_FCIC. Lets one extension serve every USx tenant.
  function providerFromHost() {
    const m = location.hostname.match(/usx-([a-z0-9-]+)\.mark43/i);
    return m ? m[1].toUpperCase().replace(/-/g, '_') : 'UNKNOWN';
  }

  window.__usxLib = { sleep, q, fillText, selectReactSelect, fillField, clickSend, extractConnectCicXml, triggerDownload, providerFromHost };
  console.log('%c[USx]', 'color:#0a0;font-weight:bold', 'usx_lib loaded.');
})();
