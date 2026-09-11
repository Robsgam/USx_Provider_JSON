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

⚠️ **That count was WRONG from the day the Reset-queue button shipped until 2026-09-09.** It used
`window.confirm()` — in this same file, against the rule stated directly above — so the exact v0.5.0
failure was live again: with dialogs suppressed, `confirm()` returns `false`, Reset queue does
nothing, and there is no error. Now a **two-click in-panel confirm** reusing the ARM switch's
`pendingConfirm` pattern, with the queue contents shown in the panel and a 6 s auto-cancel. The
pending flag lives on the **element** (`dataset.pending`), because `tick()` repaints that label on a
timer and would otherwise erase the "⚠ CLICK AGAIN" cue while leaving the confirm armed — the same
destroyed-feedback bug in a new place. **A documented invariant with no check is a comment**;
`audit_extension_syntax.ps1` cannot see this one, so the count above is still maintained by hand.

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
## v0.5.5 — `authwatch.js`: RND-71625 evidence capture (the yellow-icon / blocking question)

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

### Use the PANEL, not the console (v0.5.6)
On `universal-search` the panel carries a **"RND-71625 — warning-icon check (read-only)"** section:
pick the trigger, pick the window, click **▶ Watch + download record**. **Probe now** takes an
instant snapshot without downloading. The verdict prints in the panel as three *separate* signals —
`icon · notice · Send` — because "a warning appeared" and "the interface is blocked" are independent
expectations and collapsing them would hide the two interesting mixed cases.

- The trigger dropdown is built **from `authwatch.js`'s exported `__usxAuthTriggers`**, never a
  second copy — a restated enum drifts, and the failure mode is a trigger the button offers and the
  function rejects. `control-normal` is the **default**, because a run with no baseline beside it
  cannot conclude anything.
- **Not ARM-gated, deliberately.** The ARM switch exists because the driver *submits real queries*;
  `authwatch` only reads the DOM and saves a JSON. Gating it would mean arming the driver on a
  customer site to answer a question about an icon — the opposite of what the switch protects. The
  section header says *read-only* so that difference is visible rather than assumed.
- The panel only loads on `/rms/*`, so **CAD and First Responder still need a console paste** — the
  file degrades standalone for exactly that reason. Widening the manifest would also load the
  **driver** onto those surfaces, which is Rob's call, not a side effect of adding a diagnostic.

The console entry points remain, and are what CAD/FR use:

```js
__usxAuthWatch({ trigger: 'control-normal'   })   // BASELINE first -- authorized user, simulation ON
__usxAuthWatch({ trigger: 'tc12-no-stateid'  })   // per-USER, does not disturb the tenant
__usxAuthWatch({ trigger: 'tc10-sim-off'     })   // tenant-wide -- turn simulation back ON immediately
__usxAuthWatch({ trigger: 'tc10-sim-off', seconds: 20 })
__usxAuthProbe()                                  // one instantaneous snapshot
```

`trigger` is a required-in-practice **enum** (see the table below): an unknown value **throws**, and
omitting it prints a loud warning. An unlabelled record cannot be compared against a control, and
comparing runs is the entire value — so the record refuses to look tidier than it is.

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

### What actually triggers it — THREE documented triggers, from the SQA suite

Answering *"do we know what triggers it, and how do we reproduce it?"* — **yes, and from written
test cases rather than inference.** The same symptom family has three **independent** triggers, which
is what makes a negative result interpretable at all:

| Trigger | Ticket | Scope | Expected |
|---|---|---|---|
| **`tc10-sim-off`** device simulation OFF | SQA-215 / 174 / **145** / 114 / 76 | **TENANT-WIDE** | yellow warning icon on the "Queries" label within 2–3 s |
| **`tc12-no-stateid`** user has **no State User ID** | SQA-217 / 176 / 147 / 116 / 78 | **PER-USER** | icon **with a message** on RMS · query blocked on CAD **and** FR · **no USX icon at all** on FR |
| **`tc13-image-reason`** `ImageIndicator="Y-yes"` + `ReasonCode` blank | SQA-218 / 177 / 148 / 117 / 79 | **PER-FORM** | submission blocked until a Reason Code is entered |

**TC-10 verbatim:** Settings → Universal Search → turn OFF device simulation → RMS → Universal
Search → Person Query → wait 2–3 s → look at the "Queries" label → **turn it back ON immediately**.
Fail condition: *"Yellow warning icon doesn't appear, or query interface remains fully functional
when it should be blocked."*

**TC-12 is the better instrument, and that is the useful finding.** It is **per-user**, so it does
not disturb a shared tenant the way flipping three `dex.*simulation*` settings does; it is the only
one that expects a **message** alongside the icon; and its trigger is a field this repo actually
configures (`dexStateUserId`, set by `Build-Auth`). So it doubles as the **positive control** the
icon probe otherwise lacks.

**TC-13 is deterministic but NOT reproducible on IL_LEADS_OFML** — the provider RND-71625 was filed
against. IL's metadata defines `ReasonCode` **zero** times and its devdoc never mentions it, while
TX_TLETS's metadata defines it 13 times. So the Image/Reason conditional is a **TX-family**
requirement, not an IL gap — checked against IL's own authority, not assumed from the resemblance.

### Why the third trigger matters: it makes a NEGATIVE run mean something
A probe that finds nothing under **one** trigger is **indistinguishable from a broken probe** — the
selectors here were written without ever having seen the icon, so they are a hypothesis. Running a
**second, independent** trigger resolves that:

- icon appears under TC-12 but not TC-10 → **selectors are proven**, and TC-10 is a real product gap
- icon appears under **neither** → either the icon does not exist on this build (a stronger finding
  than the ticket's single observation) **or** the probe is wrong — and the raw `icons[]` array,
  which records **every** icon near the label with its computed colour, is what an engineer reads to
  tell those apart
- icon appears under **both** → RND-71625 does not reproduce here, which is also worth knowing

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
deliberate `function broken( {` control run **first** (→ `PARSE-FAIL`), then `authwatch.js` →
`PARSE-OK` **and both globals exported** (`__usxAuthWatch`, `__usxAuthProbe` are functions).
`manifest.json` re-parsed, and load order asserted (`usx_lib` → … → `authwatch` → `ui`).
**Reload the unpacked extension** after pulling this — `manifest.json` changed.

🔴 **READ THIS BEFORE YOU EXPLAIN AWAY A `PARSE-FAIL`. It happened, and it cost five days.**

On 2026-09-09 this harness reported that `usx_lib.js`, `capture.js` and `driver.js` did not export
their globals. I wrote a paragraph here explaining that away as a `file://` opaque-origin artifact —
because Chrome sanitizes the reason to `Script error.`, the explanation was *plausible*, and those
files were "unmodified and known to work". **It was wrong. The file was genuinely broken**, and the
tenant console said so in one line the moment Rob loaded it:

```
usx_lib.js:473 Uncaught SyntaxError: missing ) after argument list
capture.js:13 [USx-CAP] usx_lib not loaded
driver.js:20  [USx-DRV] usx_lib not loaded
```

The cause: the build tag on line 473 was a paragraph of prose inside a **single-quoted** string, and
on 2026-09-04 it grew to contain `initialValue='C'`. That apostrophe closed the literal. **The
driver and capture tools were completely dead from 2026-09-04 to 2026-09-09** — and the harness had
been saying so.

Three things this repo already knew and I violated anyway:

- **A parse error is TOTAL.** `window.__usxLib` is assigned on the line *above* the bad one and
  still never existed. "It only broke a console message" is not a possible outcome.
- **The red "⚠ NOT a test tenant" banner was a SYMPTOM, not a second bug.** `isProviderTestTenant()`
  lives in the dead file, so `ui.js` fell back to its most cautious label. Two alarming signals, one
  cause — and it resolves itself the moment the parse error is fixed.
- **Don't rationalize an anomaly.** The verdict was correct and I substituted a story for it. If this
  harness says a file does not export, treat it as broken until you have the real error text — load
  the unpacked extension and read the `chrome-extension://` console, which is **not** sanitized.

Standing rule that follows: **keep the build tag short and free of apostrophes.** Per-change prose
belongs in comments and commit bodies, where a quote cannot terminate anything.
`tools\audit_extension_syntax.ps1` now gates this.


## v0.6.0 — `admin_probe.js`: READ-ONLY support-admin inventory (2026-09-10)

Rob: *"i want you to look at this page and see if you can import/export or do anything else …
Can you use both of these links and information and see if we can't get a list of active tenant
that have a json imported … We can add any feelers and probes to the exsiting extension."*

**Why it had to be an extension probe, measured not assumed.** A repo-side fetch of
`https://demo.mark43.com/rms/api/support/admin/departments` returns **`303 See Other` →
`/rms/login/`**. Both endpoints are session-authenticated, so only the operator's own logged-in
browser can read them. Nothing in `tools/` can ever do this.

**What it closes.** `providers/IMPORT_LEDGER.md` section B is maintained BY HAND — *"the capture
tool can't reach them, so their versions are recorded manually in the ledger from actual import
reports only."* An authenticated read of the admin endpoints is the first thing that could make
that section DERIVED rather than remembered.

**The panel now has a third mode: `admin`.** ⚠️ **The admin route is PATH-based, not hash-based**,
and that is the whole reason `tick()` needed changing: those URLs
(`/rms/api/support/admin/departments[/configurations/<id>]`) carry NO hash, so the existing
`dex-log` / `universal-search` hash tests were both false, `want` came out `null`, and the
`!want` branch REMOVES the panel. The buttons would have been invisible on the only pages they
work on. Caught by reading `tick()` before shipping, not by discovering it on the tenant.

### The admin panel after the STEP 3 CLEANUP (BUILD 2026-09-11b)

Rob, 2026-09-11: *"we will need to clean up the extension and remove all diagnostics hooks.
maybe not completely but remove the buttons for now."*

**Three buttons are visible — the standing workflow, and nothing else:**

| Button | Does | Feeds |
|---|---|---|
| **2. List all tenants + department ids** | GETs `/departments` — **ONE page load** for all 1,785 | `ingest_tenant_roster.ps1` → new tenants / renames / status changes |
| **6b. PULL THE CONFIGS for the dept ids above** | clicks each tenant's own **Export JSON**, **one file per tenant** | `ingest_tenant_configs.ps1` → the baseline, and the BEFORE for any import |
| **7. Scan ALL departments** (+ Stop) | reads the bundle table for every department, chunked and abortable | `ingest_tenant_scan.ps1` → presence census, for **new** tenants only |

**Five buttons are HIDDEN behind a collapsed `▸ diagnostics` toggle — hidden, NOT deleted:**

| Button | Why it is no longer part of the workflow |
|---|---|
| **1. Read this department** | single-page read; the census and the pull both supersede it |
| **3. Scan bundles for that many tenants** | bounded sweep, superseded by 7 (which covers all 1,785 with coverage accounting) |
| **4. Look at the controls** / **5. Try the export** | the look-then-click safety split that ESTABLISHED the export control was safe to click. Its job is done; it is how we knew 6b would not delete a bundle |
| **6. Version catalogue** | versions only — **6b is a strict superset**, writing the same aggregate index PLUS the configs |

⚠️ **WHY HIDDEN AND NOT REMOVED — two independent reasons.**
1. A one-character break in these scripts once killed the driver AND capture tools for **five
   days**, found only when the operator opened a console. Deleting working code paths is exactly
   how that recurs, and `audit_extension_syntax.ps1` exists because of it.
2. **It would throw, not degrade.** Button 3's handler reads `#usx-admin-sub`,
   `#usx-admin-status` and `#usx-admin-lim`; buttons 4 and 5 read `#usx-admin-expid`. Those
   inputs live inside the hidden container, so they still exist in the DOM. Remove the inputs
   and the handlers fail on a null dereference the moment anyone re-enables them.

The dept-ids textarea stays **visible** because 6b reads it.

Each writes a JSON to Downloads (`usx_admin_departments_*`, `usx_admin_bundles_*`,
`usx_admin_one_*`) which is then ingested repo-side for cross-checking.

**READ-ONLY BY CONSTRUCTION.** `admin_probe.js` issues **GET only** — there is no POST/PUT/PATCH/
DELETE and no upload path anywhere in it. Importing a JSON into a tenant changes someone's
environment and must never be a side effect of an inventory probe; that stays a deliberate,
separately-authorised action.

**NOT arm-gated, and no arm block is drawn on this panel** — following the `authwatch` precedent.
The ARM switch exists because the driver SUBMITS REAL QUERIES on hosts that may be live; this only
reads. Requiring an arm would mean arming the query driver on a customer host to answer an
inventory question, which is the opposite of what the switch is for.

⚠️ **PASS 1 IS RECON AND ASSUMES NOTHING ABOUT SHAPE.** It is not known whether these endpoints
return JSON or HTML, nor the key names for department id / name / bundles. So the probe records the
**raw response** (status, content-type, byte count, login-redirect flag, and the parsed tree or the
first 20KB of HTML), reports a **described shape**, and extracts `(deptId, name)` only
best-effort — every guessed key is labelled `guessed:true` and the FULL record is kept, so a wrong
key choice is correctable from the file without re-driving the browser. Guessing field names is how
a probe reports a confident wrong answer.

**These files are deliberately OUTSIDE the capture watcher's allowlist.** `watch_captures.ps1` was
narrowed the same day to `usx_captured_*` / `usx_picklists_*`, so an `usx_admin_*` file is IGNORED
and **announced by name** rather than silently fed to the test-log importer. Verified with a decoy.
