# USx Tenant Testing — Feasibility Spike

A throwaway proof-of-concept that answers, against the **live NJ tenant in your own Chrome**,
the three questions that gate building the real automation:

1. **Can you load an unpacked extension at all?** (enterprise policy may block it)
2. **Is the full ConnectCic _request_ XML retrievable from `/admin/dex-log`?** (capture feasibility)
3. **Can the `universal-search` query fields be driven, and what do the custom dropdowns look like?** (driver feasibility)

It is **read-only / non-destructive**: it observes network traffic and fills exactly one
text field with `SPIKETEST123`. **It never clicks Send / submits a query.**

> Note: there are no separate `snippets/*.js` files — `capture.js` and `probe.js` are plain
> self-contained IIFEs, so the *same* file contents work as DevTools snippets (Path B below).
> Keeping one copy avoids the two drifting apart.

---

## Path A — Load as an extension (preferred; also tests whether install is allowed)

1. Open `chrome://extensions`.
2. Toggle **Developer mode** (top-right).
3. Click **Load unpacked** and select this folder:
   `...\USx_Provider_JSON\automation\spike\`
4. **Evidence #1:** Did it load, or did Chrome block it / show a policy error?
   Also open `chrome://policy` and note any `ExtensionInstall*` / `BlockExternalExtensions`
   rows. (If blocked, use Path B — capture/driver feasibility is still testable.)
5. Open `https://usx-nj-njcjis.mark43.com/rms/#/admin/dex-log`, open DevTools (F12) → Console.
   You should see `[USx-CAP] capture hooks installed`.

If it loaded, skip to **Run the tests** below.

---

## Path B — DevTools snippets (no install needed; use if Path A is blocked)

1. Open the tenant page, then DevTools (F12) → **Sources → Snippets → New snippet**.
2. Paste the **entire contents of `capture.js`** into one snippet; paste **`probe.js`** into
   another. (Or paste either directly into the Console.)
3. Run the capture snippet **first, on `/admin/dex-log`, _before_ you load/refresh a log**
   (it only sees traffic that happens after it installs). Run the probe snippet on
   `/universal-search`.

---

## Run the tests & what to send back

### Capture (on `/admin/dex-log`)
1. With the page open and hooks installed, **load or refresh a DEX log entry** (open one that
   has a real ConnectCic transaction).
2. In the Console run:  `__usxDump()`
   - It logs every captured response and downloads `usx_spike_captures.json`.
3. If `requestXmlFound` is `false` for all entries, open one log entry's **detail view** and run:
   `__usxScrapeDom()`  (checks whether the request XML is in the page DOM instead).
4. **Evidence #2:** send back `usx_spike_captures.json` (or the console output) — specifically
   whether `requestXmlFound` was true, whether a `transactionId` was captured, and via `fetch`
   or `xhr`. Redact any real PII in the sample before sending.

### Probe (on `/universal-search`)
1. Pick an entity (e.g. Vehicle) so the query form renders.
2. In the Console run:  `__usxProbe()`
3. **Evidence #3:** right-click the logged result object → **Copy object**, and paste it back.
   Key fields: `textFillWorked` (did the React fill take?), and the `comboboxes` / `checkboxes`
   / `dates` markup (tells us how to drive the custom controls).
4. **Evidence #4:** note any **CSP violation** warnings in the console (red), and whether the
   `[USx-CAP]`/`[USx-PROBE]` messages appeared at all (confirms `world:MAIN` injection ran).

---

## After the spike
Send back evidence #1–#4. That converts the two BINDING UNKNOWNs into facts and tells us the
delivery vehicle (extension vs snippet). Then we build the real capture + driver per the plan
(`P1`→`P5`), wiring captured XML straight into `post_test.ps1` (which auto-stamps version +
fingerprint + tier). This whole `automation/spike/` folder is disposable once that's underway.

## Safety / scope
- Non-destructive: observes network + fills one text field; never submits.
- In-browser only: rides your authenticated, Zscaler-decrypted session — no certificate or
  proxy config needed.
- Hardcoded to `usx-nj-njcjis.mark43.com` in `manifest.json`; widen the `matches` for other tenants.
