// ===========================================================================
//  USx Tenant Testing automation -- network hook (nethook.js)
//  Runs in MAIN world at document_START so it arms BEFORE the page issues its
//  requests (the dex-log list load, the universal-search submit). Because it is
//  part of the extension it re-injects on every full page reload -- unlike a
//  console-pasted hook, which a reload wipes.
//
//  It only records {via, url, hasXml, len} per response (+ outgoing request
//  bodies) into window.__usxNetAll so recon can see whether the request XML
//  ever travels over the network (vs only living in the dex-log DOM).
// ===========================================================================
(() => {
  if (window.__usxNetAll) return;
  window.__usxNetAll = [];
  const RX = /ConnectCic|LawEnforcement|<\?xml|MessageType/i;
  const flag = (via, url, body) => {
    try { window.__usxNetAll.push({ via, url: String(url), hasXml: RX.test(body || ''), len: (body || '').length }); } catch (e) {}
  };

  const of = window.fetch;
  if (of) {
    window.fetch = function (...a) {
      const u = (a[0] && a[0].url) || a[0];
      try { if (a[1] && a[1].body) flag('fetch-req', u, String(a[1].body)); } catch (e) {}
      const p = of.apply(this, a);
      p.then((r) => { try { r.clone().text().then((t) => flag('fetch-resp', u, t)).catch(() => {}); } catch (e) {} }).catch(() => {});
      return p;
    };
  }

  const oo = XMLHttpRequest.prototype.open, os = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) { this.__u = u; return oo.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function (b) {
    try { if (b) flag('xhr-req', this.__u, String(b)); } catch (e) {}
    this.addEventListener('load', () => { try { flag('xhr-resp', this.__u, this.responseText); } catch (e) {} });
    return os.apply(this, arguments);
  };
})();
