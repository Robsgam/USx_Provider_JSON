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

  // Plain Chakra text input: React controlled-input pattern.
  function fillText(fieldId, value) {
    const el = q(fieldId);
    if (!el) return { fieldId, kind: 'text', ok: false, err: 'not found' };
    const proto = el.tagName === 'TEXTAREA'
      ? window.HTMLTextAreaElement.prototype
      : window.HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return { fieldId, kind: 'text', ok: el.value === String(value), value: el.value };
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
    await sleep(180);
    Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(input, value);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await sleep(280);
    const opts = [...document.querySelectorAll('[class*="select__option"], [role=option]')];
    const code = String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp('^' + code + '\\b', 'i');
    const opt = opts.find((o) => re.test((o.textContent || '').trim())) || opts[0];
    if (!opt) return { fieldId, kind: 'select', ok: false, err: 'no option for ' + value };
    opt.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    opt.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    await sleep(180);
    const display = ((input.closest('.arc-select__control') || control)?.textContent || '').trim();
    return { fieldId, kind: 'select', ok: re.test(display), display };
  }

  // Auto-detect: react-select inputs carry class arc-select__input; else plain text.
  async function fillField(fieldId, value) {
    const el = q(fieldId);
    if (!el) return { fieldId, ok: false, err: 'not found' };
    if ((el.className || '').toString().includes('arc-select__input')) {
      return await selectReactSelect(fieldId, value);
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

  window.__usxLib = { sleep, q, fillText, selectReactSelect, fillField, clickSend, extractConnectCicXml, triggerDownload };
  console.log('%c[USx]', 'color:#0a0;font-weight:bold', 'usx_lib loaded.');
})();
