// USx Tenant Testing -- background service worker.
//
// Sole job: perform file downloads via chrome.downloads.download() on behalf of the
// MAIN-world capture scripts (relayed here by bridge.js). This exists to defeat a
// specific Chrome behavior that silently dropped captures:
//
//   The capture scripts run in a MAIN-world content script and originally downloaded
//   each batch with a page-context anchor-click (a.click() on a blob: URL). When several
//   captures fire back-to-back (e.g. one per entity in a full re-test), Chrome's
//   "automatic multiple downloads" gate blocks the 2nd..Nth download -- the first lands,
//   the rest are silently refused, and the page's JS has no idea (the anchor click still
//   "succeeds" from its point of view). That's why per-entity bursts lost every file
//   after the first while one-at-a-time captures worked.
//
//   chrome.downloads.download() from the extension is NOT subject to that user-gesture
//   gate, so routing the download here makes every batch land regardless of how many
//   fire in a row. conflictAction:'uniquify' reproduces the historical (1)/(2) suffix
//   behavior, which import_captured_tests.ps1 already ingests in bulk.
//
// The payload is a data: URL (not a blob: URL) because a blob URL created in the page
// context can't be resolved from the service-worker context, and MV3 service workers
// have no URL.createObjectURL.

chrome.runtime.onMessage.addListener(function (msg, sender, sendResponse) {
  if (!msg || msg.type !== 'usx-download') return;
  try {
    chrome.downloads.download(
      { url: msg.dataUrl, filename: msg.filename, conflictAction: 'uniquify', saveAs: false },
      function (id) {
        var err = chrome.runtime.lastError;
        sendResponse({ ok: !err && typeof id === 'number', id: id, error: err ? err.message : null });
      }
    );
  } catch (e) {
    sendResponse({ ok: false, error: String(e) });
  }
  return true; // keep the message channel open for the async sendResponse
});
