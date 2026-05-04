# ConnectCIC — MANDATORY PROCESS RULES

**This block MUST appear at the top of every provider repo CLAUDE.md.**
**Source of truth: `C:\Users\RobSgambellone\.local\bin\ConnectCIC-KB\PROCESS_RULES.md`**
**Last synced: 2026-04-30**

If this block is missing or outdated in a provider repo, copy it from the source before doing any work.

---

> **STOP. Read this entire section before doing ANY work in this repo.**
>
> These rules are MANDATORY for every Claude instance working on ConnectCIC provider JSON repos.
> The user (Rob) has established these through repeated corrections. They are not optional.
> They are not suggestions. They cannot be deferred, batched, or skipped.
>
> **If you are tempted to skip a step to save time — STOP. The step exists because
> skipping it caused real failures. Do it now or do not report progress.**

## 1. SESSION START — Before Any Work

1. Read this CLAUDE.md completely
2. Read the KB master rules: `C:\Users\RobSgambellone\.local\bin\ConnectCIC-KB\CLAUDE.md`
3. Run `git status` — confirm working tree is CLEAN and branch is synced with remote
4. Verify `docs/` contains: `<PROVIDER>_STATUS.txt`, `<PROVIDER>_SQVR.txt`, `<PROVIDER>_BUILD_NOTES.txt`, `base/` with 5 report files
5. Verify `tests/` directory exists
6. **If ANYTHING from steps 3-5 is wrong: fix it FIRST before starting the requested task**

## 2. TRIGGER RULES — Automatic Chaining

When a trigger fires, ALL chained actions are part of the same unit of work. You are not done until every chained action completes.

**You edit or create any `.json` provider file →**
- Run `build_report.ps1 -Path <json>`
- Verify 0 FAIL in validator
- Commit JSON + all 5 report files to `docs/base/` or `docs/mc/`
- `git push`
- Update `docs/<PROVIDER>_STATUS.txt` if version changed
- Update `docs/<PROVIDER>_SQVR.txt` if query paths changed

**You complete a live test (user reports PASS or FAIL) →**
- Fill in the test log stub (FORM STATE, XML, FIELD ANALYSIS, RESULT)
- `git add` + `git commit` + `git push` the completed log
- Update `docs/<PROVIDER>_STATUS.txt` test matrix row
- Update `docs/<PROVIDER>_SQVR.txt` — flip [PENDING] to [CONFIRMED] if PASS

**You update any KB file →**
- Commit and push ConnectCIC-KB
- Check: does this affect any provider repo CLAUDE.md or build script? If yes → update + commit + push each

**You discover a new limitation, anti-pattern, or import error →**
- Add to the appropriate KB file (PLATFORM_LIMITATIONS, ANTI_PATTERNS, IMPORT_ERRORS)
- Fire the KB update trigger above

## 3. MANDATORY GATES — Blocking Requirements

### GATE 1: After Every JSON Build or Edit
1. Run `build_report.ps1 -Path <json>` (5 reports: validator + layout + query sim + picklist + HTML)
2. Verify 0 FAIL
3. Commit JSON + reports
4. `git push`
5. **BLOCKED: Cannot proceed to import or testing until reports are committed and pushed**

### GATE 2: Before Each Live Test
1. Run `new_test_log.ps1` to create stub in `tests/`:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Users\RobSgambellone\.local\bin\new_test_log.ps1 `
     -Provider <NAME> -Variant BASE -Version <ver> -Entity <entity> -Combo <combo> -Description "<desc>"
   ```
2. User opens F12 > Network before submitting
3. **BLOCKED: Cannot execute the test without a stub log file on disk**

### GATE 3: After Each Live Test
1. Paste raw XML request into log file
2. Fill in FORM STATE, REQUEST SUMMARY, FIELD ANALYSIS, RESULT
3. `git add` + `git commit` + `git push`
4. **BLOCKED: Cannot proceed to next test until current log is committed and pushed**

### GATE 4: After Each Test Session
1. Update `docs/<PROVIDER>_STATUS.txt` with all results
2. Commit and push
3. **BLOCKED: Cannot report session complete without updated STATUS.txt**

### GATE 5: Before Declaring PASS or DONE
1. `ls tests/` — one log file per test? Count matches?
2. `ls docs/base/` — all 5 report files present?
3. `docs/<PROVIDER>_STATUS.txt` — current?
4. `docs/<PROVIDER>_SQVR.txt` — exists with [CONFIRMED]/[PENDING] per query?
5. `git status` — everything committed and pushed?
6. **BLOCKED: Cannot declare PASS or DONE until all 5 checks pass. Fix first.**

### GATE 6: After Any KB Update
1. Commit and push ConnectCIC-KB
2. Check cross-repo impact
3. Update affected repos if needed
4. **BLOCKED: Cannot finish KB update without checking cross-repo impact**

## 4. END-OF-RESPONSE VERIFICATION

Before ending ANY response that involved file changes, verify:

1. Every file I edited — saved, committed, pushed?
2. Every JSON I touched — build_report ran? Reports committed?
3. Every test completed — log file in tests/? Committed?
4. STATUS.txt — reflects current state?
5. SQVR — reflects current confirmed/pending state?
6. Any KB updates — KB pushed? Affected repos updated?
7. Anything I said I would do but haven't? → Do it now or state explicitly why deferred.

Do not output this checklist. Just do the work. Only mention it if something was missing and you fixed it.

## 5. TOOLS

```powershell
# Build report (validator + layout + query sim + picklist + HTML) — GATE 1
powershell -ExecutionPolicy Bypass -File C:\Users\RobSgambellone\.local\bin\build_report.ps1 -Path <json>

# Test log stub — GATE 2
powershell -ExecutionPolicy Bypass -File C:\Users\RobSgambellone\.local\bin\new_test_log.ps1 `
  -Provider <NAME> -Variant BASE -Version <ver> -Entity <entity> -Combo <combo> -Description "<desc>"

# Validator only (quick check)
powershell -ExecutionPolicy Bypass -File C:\Users\RobSgambellone\.local\bin\connectcic-validator\validate.ps1 -Path <json>

# Layout renderer (text tree)
powershell -ExecutionPolicy Bypass -File C:\Users\RobSgambellone\.local\bin\render_layout.ps1 -Path <json> -Summary

# Query simulator
powershell -ExecutionPolicy Bypass -File C:\Users\RobSgambellone\.local\bin\test_commsys.ps1 -Path <json>

# Picklist scanner
powershell -ExecutionPolicy Bypass -File C:\Users\RobSgambellone\.local\bin\report_picklists.ps1 -Path <json>
```

## 6. KB REFERENCE

**Read before every session:**
- `C:\Users\RobSgambellone\.local\bin\ConnectCIC-KB\CLAUDE.md` — Master build rules, anti-patterns, field rules, QIDM architecture
- `C:\Users\RobSgambellone\.local\bin\ConnectCIC-KB\knowledge-base\README.txt` — KB index (13 docs)
- `C:\Users\RobSgambellone\.local\bin\ConnectCIC-KB\knowledge-base\BUILD_CHECKLIST.txt` — Full pre-build/pre-import/test checklists

## 7. CANONICAL REPO STRUCTURE

```
<PROVIDER>/
├── CLAUDE.md                              # This file (process rules + provider-specific)
├── .gitignore
├── <PROVIDER>_BASE.json
├── <PROVIDER>_MC.json                     # If applicable
├── docs/
│   ├── <PROVIDER>_STATUS.txt
│   ├── <PROVIDER>_BUILD_NOTES.txt
│   ├── <PROVIDER>_SQVR.txt
│   ├── JSON_INVENTORY.md
│   ├── base/ (5 report files)
│   └── mc/  (5 report files, if applicable)
├── tests/                                 # One log file per live test executed
├── phases/                                # Version snapshots
├── release/                               # Frozen release bundles
├── scripts/                               # Build scripts
└── source/                                # XML metadata, devdoc PDF, HIDLE.json
```

If this repo does not match this structure, fix it before doing any other work.

---
<!-- END PROCESS RULES — Provider-specific content below -->
