// ===========================================================================
//  USx Tenant Testing -- Feasibility Spike : CAPTURE (CAP-lite)
//  Runs in MAIN world at document_start on the Mark43 RMS tenant.
//
//  Goal: answer BINDING UNKNOWN #1 -- is the full ConnectCic *request* XML
//  retrievable from the dex-log page's network traffic (or do we need a DOM
//  fallback)? It monkey-patches fetch + XHR, tees responses that look like DEX
//  log payloads, and tries to extract the request XML + a transaction id.
//
//  It does NOT submit anything. Read-only observation.
//
//  USAGE (after the page loads): open /admin/dex-log, load/refresh a log entry,
//  then in the DevTools console run:   __usxDump()
//  -> prints all captures and downloads usx_spike_captures.json
// ===========================================================================
(() => {
  if (window.__usxSpikeCaptureInstalled) return;
  window.__usxSpikeCaptureInstalled = true;

  const captures = [];
  const note = (...a) =>
    console.log('%c[USx-CAP]', 'color:#0a0;font-weight:bold', ...a);

  // Broad heuristic for "this response is DEX-ish" -- intentionally loose for
  // discovery; we'd tighten to the real endpoint once we see it.
  function looksDex(url, body) {
    const u = (url || '').toString().toLowerCase();
    if (u.includes('dex') || u.includes('transaction') || u.includes('lawenforcement')) return true;
    const b = body || '';
    return /ConnectCic|LawEnforcementTransaction|<api:|MessageType|QueryInput/i.test(b);
  }

  // Pull request XML + a transaction id out of a JSON or raw-XML body.
  function extract(body) {
    let xml = null, txId = null;
    const xmlRe = /<api:ConnectCicApi[\s\S]*?<\/api:ConnectCicApi>/;
    const xmlReLoose = /<\?xml[\s\S]*?<\/[A-Za-z][\w:.-]*>/;
    try {
      const j = JSON.parse(body);
      const s = JSON.stringify(j);
      const m = s.match(xmlRe) || s.match(xmlReLoose);
      if (m) xml = m[0].replace(/\\"/g, '"').replace(/\\n/g, '\n').replace(/\\\//g, '/');
      const t = s.match(/"transaction[_ ]?id"\s*:\s*"([^"]+)"/i) ||
                s.match(/Transaction\s+id=\\?"([^"\\]+)/);
      if (t) txId = t[1];
    } catch (e) {
      const m = body.match(xmlRe) || body.match(xmlReLoose);
      if (m) xml = m[0];
      const t = body.match(/Transaction\s+id="([^"]+)"/);
      if (t) txId = t[1];
    }
    return { xml, txId };
  }

  function record(via, url, body) {
    const { xml, txId } = extract(body);
    const rec = {
      via, url,
      transactionId: txId,
      requestXmlFound: !!xml,
      xmlSample: xml ? xml.slice(0, 4000) : null,
      rawSample: (body || '').slice(0, 1500),
      at: new Date().toISOString()
    };
    captures.push(rec);
    note(`captured ${via} ${url} -- requestXmlFound=${!!xml}${txId ? ' txId=' + txId : ''}`);
  }

  // --- fetch hook ---
  const origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function (...args) {
      const p = origFetch.apply(this, args);
      p.then((res) => {
        try {
          const url = (args[0] && args[0].url) || args[0];
          res.clone().text().then((body) => { if (looksDex(url, body)) record('fetch', url, body); }).catch(() => {});
        } catch (e) {}
      }).catch(() => {});
      return p;
    };
  }

  // --- XHR hook ---
  const origOpen = XMLHttpRequest.prototype.open;
  const origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url) { this.__usxUrl = url; return origOpen.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function () {
    this.addEventListener('load', () => {
      try { const body = this.responseText || ''; if (looksDex(this.__usxUrl, body)) record('xhr', this.__usxUrl, body); } catch (e) {}
    });
    return origSend.apply(this, arguments);
  };

  // --- DOM fallback: scrape rendered request XML if the network path yields none ---
  window.__usxScrapeDom = function () {
    const hits = [];
    const all = document.querySelectorAll('pre, code, textarea, td, div');
    all.forEach((el) => {
      const t = el.textContent || '';
      if (/<api:ConnectCicApi|LawEnforcementTransaction/.test(t)) {
        hits.push({ tag: el.tagName, sample: t.slice(0, 4000) });
      }
    });
    console.log('[USx-CAP] DOM scrape hits:', hits.length, hits);
    return hits;
  };

  window.__usxCaptures = captures;
  window.__usxDump = function () {
    console.log('[USx-CAP] total network captures:', captures.length, captures);
    try {
      const blob = new Blob([JSON.stringify(captures, null, 2)], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = 'usx_spike_captures.json';
      document.body.appendChild(a); a.click(); a.remove();
    } catch (e) { console.warn('[USx-CAP] download failed:', e); }
    return captures.length;
  };

  note('capture hooks installed (fetch + XHR).');
  note('Open /admin/dex-log, load/refresh a log entry, then run  __usxDump()  here.');
  note('If network capture finds no request XML, run  __usxScrapeDom()  on the log detail view.');
})();
