// USx Tenant Testing -- isolated-world download bridge.
//
// MAIN-world scripts (usx_lib.js / capture.js) cannot call chrome.* APIs, so
// triggerDownload() posts the download request onto the page's window message bus;
// this ISOLATED-world content script (which DOES have chrome.runtime) picks it up,
// relays it to the background service worker, and posts the result back so the page
// can fall back to a plain anchor-click download if the worker path is unavailable
// (e.g. the unpacked extension hasn't been reloaded with the new background worker yet).
//
// Must run in the default (isolated) world -- do NOT add "world": "MAIN" to its
// manifest entry, or chrome.runtime.sendMessage will be undefined here.

window.addEventListener('message', function (ev) {
  var d = ev && ev.data;
  if (ev.source !== window || !d || d.__usxDownload !== true) return;
  try {
    chrome.runtime.sendMessage(
      { type: 'usx-download', filename: d.filename, dataUrl: d.dataUrl },
      function (res) {
        var err = chrome.runtime.lastError;
        window.postMessage({
          __usxDownloadAck: true,
          nonce: d.nonce,
          ok: !!(!err && res && res.ok),
          error: err ? err.message : (res && res.error) || null
        }, '*');
      }
    );
  } catch (e) {
    window.postMessage({ __usxDownloadAck: true, nonce: d.nonce, ok: false, error: String(e) }, '*');
  }
});
