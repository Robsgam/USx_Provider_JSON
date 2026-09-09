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
- `authwatch.js` — `__usxAuthWatch()` / `__usxAuthProbe()` — **RND-71625 evidence capture** (see below)
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

---

## v0.5.1 — wildcard hosts + the ARM switch (2026-08-13)

### Why the host list became a wildcard
Until v0.4.0 the manifest enumerated eight `usx-*.mark43.com` hosts. `hdle-foundation.mark43.com`
does not fit that naming pattern, so **no content script ever matched it** — which is why the panel
never appeared on HDLE. Now: one pattern, `https://*.mark43.com/rms/*`.

**Chrome match patterns cannot match a URL fragment.** `*.mark43.com/rms/#/admin/dex-log` would
match NOTHING — the hash is invisible to match patterns. The page kind is detected at runtime by
`ui.js tick()` reading `location.hash`. Do not try to put the hash in the manifest.

**Do not put prose in `manifest.json`.** v0.5.0 carried a `_comment_hosts` array and Chrome flagged
it as an unrecognized manifest key on load. JSON has no comments; rationale lives here.

### The ARM switch is the safety, and it replaced one
The manifest allowlist WAS the safety: the extension physically could not act outside the eight
provider test tenants. The wildcard removed that guarantee **on the same day production started
existing** — CA_CLETS went live at Mariposa, 2026-08-13 — so these scripts now load on customer
sites where real officers run real CJIS queries.

- **DISARMED by default**, stored per hostname (`__usx_armed_<host>`), never global.
- `requireArmed()` gates **all eight** action handlers: Fetch results, Fetch custom range,
  click-capture start/stop, Capture open popup, Load plan, Run Plan, Scope picklists.
  Styling alone would not stop a click — the gate is in the handler.
- The panel header names the hostname and whether it is a provider TEST tenant. Anything else is
  labelled **"NOT a test tenant — Foundation or LIVE (customer site)"** in red and needs a
  two-click in-panel confirm to arm.

### NO BROWSER DIALOGS — this is a hard rule, learned the hard way
v0.5.0 used `alert()`/`confirm()`. Chrome offers **"Prevent this page from creating additional
dialogs"** after a few alerts, and once ticked `confirm()` returns `false` silently. The result:
the panel read DISARMED, the switch did nothing, and there was no way to turn the extension on
(Rob, 2026-08-13: *"the tool says disarmed and there was no way to turn the extenion on or off"*).

**A control whose only feedback path can be switched off by the browser is not a control.**
Everything renders in-panel now via `flash()` writing to `#usx-arm-msg` — the arm confirm, and the
five Run Plan / Scope validation messages that had the same flaw (a suppressed validation dialog
looks exactly like "the button did nothing"). `alert(`/`confirm(`/`prompt(` count in `ui.js`: **0**.

### Provider resolution on a non-`usx-` tenant
`providerFromHost()` derives the provider from `usx-<name>`. A Foundation/live host carries no
provider name, so the panel shows a text field to set an override, stored per hostname. Unset, it
returns `UNKNOWN` **deliberately** — a Foundation capture filed into `providers/<P>/logs/` would be
indistinguishable from a test-tenant log and would break the IMPORT_LEDGER derivation rule
("logs at version X = proof X is installed on that provider's USx TEST tenant"). That is
`audit_log_inflation` attack B by construction.

### Verifying a change to these scripts
`node` is not installed on this machine, so `node --check` is a **vacuous pass**. Use headless
Chrome as a real V8 parser, and prove the probe can fail with a deliberate `function broken( {`
control first. Read a dedicated `<title>` verdict — a first attempt grepped `--dump-dom` for
`PARSE_FAIL` and matched the literal string inside its own injected script, so every file "failed".
### v0.5.2 — the panel is toggleable, and the ✕ actually worked for the first time

`✕` used to call `p.remove()` and nothing else. `tick()` runs every 1000 ms and re-appends the
panel whenever it is absent, so the close button visibly did nothing — the panel was back within a
second. Fixed: `✕` now persists a per-host flag (`__usx_ui_off_<host>`), `tick()` checks it BEFORE
the re-append, and a small **`Ux` launcher dot** takes the panel's place so it can always be
brought back. Without that dot, turning the panel off would have been irreversible short of
clearing site data — which is how a hide button becomes a support call.

**ON/OFF and ARM are deliberately independent**, because they answer different questions:

| | means | scope |
|---|---|---|
| **UI OFF** (`✕` / `Ux` dot) | "don't show me this here" — cosmetic only | per hostname |
| **DISARMED** (ARM switch) | "don't let anything act here" — the safety | per hostname |

A tenant can be visible-and-disarmed or hidden-and-armed. Turning the panel off never arms
anything; arming never forces the panel on. The launcher dot turns green when the tenant is armed,
so a hidden-but-armed tenant is still visible at a glance rather than being a silent trap.
## v0.5.4 — `authwatch.js`: RND-71625 evidence capture (the yellow-icon / blocking question)

**The ticket.** RND-71625 (P3, Amy Blair 2026-08-31, found in SQA-145 TC-10, IL-LEADS suite). With
device simulation OFF — `dex.device_simulation_mode.enabled`, `dex.simulation_mode.enabled` and
`dex.local_simulation_mode.enabled` all off — the expected **yellow warning icon on the "Queries"
label** never appears, and the surfaces disagree:

| Surface | Reported |
|---|---|
| **RMS** | no icon **and no blocking indicator of any kind** — nothing tells the officer queries are unavailable |
| **CAD / First Responder** | no icon, but a ConnectCIC **"License Violation Notice"** appears and does block |

**What this file is for.** It converts *"no icon appeared"* from an eyeball observation into a
timestamped, downloadable record: which surface, whether the icon **ever** rendered and at what
offset, what notice text appeared, and whether **Send** was actually disabled.
**It proves WHETHER, never WHY.** The cause is platform-side; only engineering can settle it.

```js
__usxAuthWatch()                    // 10s watch, prints verdict + downloads the record
__usxAuthWatch({ seconds: 20 })     // longer window
__usxAuthWatch({ download: false })  // print only
__usxAuthProbe()                    // one instantaneous snapshot
```

Saves `usx_authwatch_<SURFACE>_<timestamp>.json`.

### Why it POLLS, and why that is not gold-plating
The ticket's expectation is that the icon appears *"within 2-3 seconds (or after a refresh)"*. A
one-shot probe at `t=0` would miss a late render and report a **false absence** — the same vacuous
measurement pattern this repo keeps finding in its own gates. So the default is a 10 s watch
recording **first-seen offset** per signal, and an absence is only asserted after the whole window.

### It measures the two expectations SEPARATELY
"A warning icon" and "a blocked interface" are independent. `no icon but correctly blocked` and
`icon shown but still sendable` are **different bugs**, so they never collapse into one verdict.
`verdict.matchesRnd71625RmsSymptom` is true only when the icon never appeared, no notice appeared,
**and** Send was never disabled for the entire window — i.e. the exact RMS shape in the ticket.

### Run it TWICE per surface — a single run cannot conclude
Once with simulation **ON** (control) and once **OFF** (the reported condition). The page cannot
read the `dex.*simulation*` settings, so whether a warning is *due* is unmeasurable from here — the
record states `simulationSettingsReadable: false` rather than implying otherwise. This is also why
the verdict is **descriptive, not pass/fail**: calling an absence a FAILURE would assert something
unmeasured.

### It runs STANDALONE, and that is deliberate
The manifest matches only `https://*.mark43.com/rms/*`, but this ticket spans **RMS, CAD and First
Responder**. Widening that match would also load the **driver** onto CAD/FR, and the stated safety
model is exactly that allowlist plus the on-screen ARM switch — so widening it is **Rob's decision**,
not a side effect of adding a diagnostic. Instead the file degrades: with `usx_lib` present it uses
the proven SW-bridge download; **pasted into the Console on CAD/FR it falls back** to a local sleep
and a single anchor download. `authwatch` is **read-only** — it observes and saves, never fills or
sends — so pasting it carries none of the driver's risk.

### Known limits, stated up front
- The icon probe **anchors on the "Queries" label**. If the label is absent (or its text changed),
  the probe has nothing to anchor to and its silence proves nothing — so the run prints a loud
  warning and `verdict.queriesLabelFound` is false. Do not read that as "no icon".
- Colour is **reported, not decisive**. The ticket says *yellow*, but a themed icon can inherit its
  colour, so `warnish` is driven by class/aria/title/data-icon, with `colour` recorded alongside.
- It cannot reach Foundation or LIVE tenants — same constraint as the capture tool.

### Verified
Per the "Verifying a change to these scripts" note above: headless Edge as a real V8 parser, with a
deliberate `function broken( {` control run **first** (→ `FAIL: Unexpected end of input`), then
`authwatch.js` → `OK` and `driver.js` unchanged → `OK`. `manifest.json` re-parsed, and load order
asserted (`usx_lib` → `authwatch` → `ui`). **Reload the unpacked extension** after pulling this —
`manifest.json` changed.

