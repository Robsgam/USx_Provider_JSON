# USx Tenant Testing — Driver + Capture (browser automation)

Removes the manual paste loop: drive the `universal-search` query form, capture the
`dex-log` request XML, and feed it straight into `post_test.ps1` (which auto-stamps
version + fingerprint + tier). All in-browser — rides your authenticated, Zscaler-decrypted
session; no certificate needed.

Built on spike-proven mechanics (see `memory/reference_usx_tenant_dom_automation.md`):
field DOM `id` == QIF fieldId; text fill auto-checks the query + enables Send; dropdowns are
react-select picked by code; the request XML lives in the dex-log entry's textarea.

## Files
- `manifest.json` — MV3, `downloads` permission, background SW, content scripts on the USx tenant allowlist `/rms/*`
- `usx_lib.js` — proven primitives: `fillField` (text + react-select), `clickSend`, `extractConnectCicXml`, `triggerDownload`
- `driver.js` — `__usxRunOne(descriptor)` on `/universal-search`
- `capture.js` — `__usxCapture()` / bulk + watch capture on `/admin/dex-log`
- `bridge.js` — ISOLATED-world relay: page → background worker (has `chrome.runtime`; MAIN world does not)
- `background.js` — service worker; downloads via `chrome.downloads.download()`
- `../../tools/import_captured_tests.ps1` — ingests downloaded records → `post_test.ps1`

## Downloads — why the background worker exists
`triggerDownload` (usx_lib.js, MAIN world) hands each batch to `background.js` via `bridge.js`,
which saves it with `chrome.downloads.download({conflictAction:'uniquify'})`. This is deliberate:
the extension runs in the page (MAIN) world, and a page-initiated anchor-click download hits
Chrome's **"automatic multiple downloads"** gate — the first download in a burst lands, the
2nd..Nth are silently blocked (the page's JS still thinks they succeeded). That silently dropped
every file after the first when a full re-test captured several entities back-to-back.
`chrome.downloads.download()` from the extension is not subject to that gate, so bursts all land
as `usx_captured_batch_labeled.json`, `... (1).json`, `... (2).json`, … which
`import_captured_tests.ps1 -Provider <NAME>` ingests in bulk. If the worker path is unreachable
(e.g. the unpacked extension wasn't reloaded after this change), `triggerDownload` falls back to
the original anchor-click after a short grace window — single downloads still work, bursts revert
to the old blocked-after-first behavior until reloaded.

## Load it
`chrome://extensions` → Developer mode → **Load unpacked** → select `automation/extension/`.
After pulling a change that touches `manifest.json` / `background.js` / `bridge.js`, hit
**Reload** on the extension card (and accept the new "Manage your downloads" permission the first
time). Confirm the console shows `usx_lib loaded. BUILD 2026-07-21a (downloads via SW bridge)`.
(DevTools-Snippets fallback: the anchor-click download still runs, but the multiple-download gate
applies — capture one entity at a time in that mode.)

## First proof — ONE combo end-to-end (Vehicle RQ+Plate)

1. **Drive** — on `/universal-search`, render the Vehicle form, open Console, run:
   ```js
   __usxRunOne({
     provider:'NJ_NJCJIS', entity:'Vehicle', query:'VehicleRegistrationQuery',
     combo:'RQ+Plate', tier:'Preliminary', expectedKeyRef:'RQ',
     fills:[{fieldId:'LicensePlateNumber', value:'TEST123'}]
   })
   ```
   Expect `sent.ok:true` (Plate fills → query auto-checks → Send clicked).

2. **Capture** — go to `/admin/dex-log`, open the entry that just fired, run:
   ```js
   __usxCapture()
   ```
   Downloads `usx_captured_<txId>.json` (the request XML + the combo context).

3. **Import** — in PowerShell:
   ```powershell
   .\tools\import_captured_tests.ps1
   ```
   Reads the newest `usx_captured_*.json` from Downloads and calls `post_test.ps1`
   (stamped, `-NoCommit`). Result is PASS when the fired `MessageType` matches the query.

4. **Verify** — the loop is closed when `post_test` wrote a stamped log and:
   ```powershell
   .\tools\audit_test_coverage.ps1 -Path providers\NJ_NJCJIS\<json> -Gate
   ```
   shows that combo as valid-backed — no manual paste anywhere.

## Status / next
- Proven: capture, text fill, autoSelect, Send, react-select.
- Next (P2): auto-emit a per-tier `TEST_PLAN.json` so the driver runs a whole entity/tier in a
  loop instead of one descriptor at a time.
- Next (P5): auto-navigate driver→dex-log + correlate by transaction id; optional localhost bridge.

## Scope / safety
- Hardcoded to `usx-nj-njcjis.mark43.com` (widen `matches` for other tenants).
- One test at a time (driver stashes context in localStorage; capture reads it).
- Driver submits real queries — run it only against the test tenant with test data.
