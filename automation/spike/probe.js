// ===========================================================================
//  USx Tenant Testing -- Feasibility Spike : PROBE (DRV-lite)
//  Runs in MAIN world on the Mark43 RMS tenant.
//
//  Goal: answer BINDING UNKNOWN #2 -- can the universal-search query fields be
//  driven programmatically, and what do the custom components look like (so we
//  know the selector + interaction strategy)?
//
//  It does NOT submit the form. It fills ONE text field (to prove the
//  React-controlled-input pattern works) and enumerates the markup of the
//  custom dropdown / checkbox / date controls so we can plan how to drive them.
//
//  USAGE: navigate to /universal-search (pick an entity so the form renders),
//  then in the DevTools console run:   __usxProbe()
//  Right-click the logged result object -> "Copy object" and paste it back.
// ===========================================================================
(() => {
  if (window.__usxSpikeProbeInstalled) return;
  window.__usxSpikeProbeInstalled = true;

  const note = (...a) =>
    console.log('%c[USx-PROBE]', 'color:#06c;font-weight:bold', ...a);

  // React 16+ controlled <input>/<textarea>: set value via the native prototype
  // setter, then dispatch input+change so React's onChange state updates.
  function setReactInput(el, value) {
    const proto = el.tagName === 'TEXTAREA'
      ? window.HTMLTextAreaElement.prototype
      : window.HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
    setter.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  window.__usxSetReactInput = setReactInput;

  function describe(el) {
    if (!el) return null;
    return {
      tag: el.tagName,
      type: el.getAttribute('type') || null,
      id: el.id || null,
      name: el.getAttribute('name'),
      testid: el.getAttribute('data-testid') || el.getAttribute('data-test-id') || el.getAttribute('data-test') || null,
      aria: el.getAttribute('aria-label') || el.getAttribute('aria-labelledby') || null,
      role: el.getAttribute('role') || null,
      cls: (el.className || '').toString().slice(0, 140),
      outer: (el.outerHTML || '').slice(0, 320)
    };
  }
  const many = (sel, n = 3) => [...document.querySelectorAll(sel)].slice(0, n).map(describe);

  // Fill an arbitrary field by selector (manual helper for deeper probing).
  window.__usxFill = function (selector, value) {
    const el = document.querySelector(selector);
    if (!el) { console.warn('[USx-PROBE] no element for', selector); return false; }
    setReactInput(el, value);
    note(`filled ${selector} -> "${el.value}"`);
    return el.value === value;
  };

  window.__usxProbe = function () {
    const out = { url: location.href, when: new Date().toISOString() };

    // (a) prove text fill works on the first plausible text input
    const text = document.querySelector(
      'input[type=text], input[type=search], input:not([type]):not([role])'
    );
    out.textField = describe(text);
    if (text) {
      try {
        setReactInput(text, 'SPIKETEST123');
        out.textFillTried = true;
        out.textValueAfter = text.value;
        out.textFillWorked = (text.value === 'SPIKETEST123');
      } catch (e) { out.textFillError = String(e); }
    }

    // (b) enumerate the custom components so we can plan interaction
    out.nativeSelects = many('select');
    out.comboboxes = many('[role=combobox], [class*="select__control"], [class*="Select-"], [class*="dropdown"], [class*="Dropdown"]');
    out.checkboxes = many('input[type=checkbox], [role=checkbox], [class*="checkbox"], [class*="Checkbox"]');
    out.dates = many('input[type=date], [class*="date"], [class*="Date"], [placeholder*="/"]');

    // (c) is there a Send/Search button we could later click?
    out.submitButtons = [...document.querySelectorAll('button')]
      .filter((b) => /send|search|submit|run|query/i.test(b.textContent || ''))
      .slice(0, 4).map(describe);

    console.log('[USx-PROBE] result:', out);
    note('Right-click the object above -> "Copy object", and paste it back.');
    return out;
  };

  if (location.hash.includes('universal-search')) {
    note('ready on universal-search. Pick an entity so fields render, then run  __usxProbe()');
  } else {
    note('loaded. Go to /universal-search, render the form, then run  __usxProbe()');
  }
})();
