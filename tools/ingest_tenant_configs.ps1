<#
  ingest_tenant_configs.ps1 -- THE BASELINE RECORD OF WHAT IS ACTUALLY DEPLOYED WHERE

  WHY THIS EXISTS. Rob, 2026-09-11, stating the intent behind the whole exercise:
    "i want you to scan and pull all the jsons so we have an actual record of what is where."
    "the idea is for the tool to eventually execute the imports, then run an export, then
     compare the 2 to confirm the json update takes place."
  The first 64-tenant sweep read every config and DISCARDED all 64, keeping a version string
  and a byte count. You cannot confirm an import changed anything without a BEFORE. This tool
  owns the BEFORE.

  INPUT: `usx_tenant_config_*.json` (extension button 6b), ONE FILE PER TENANT, each carrying
  the tenant's own exported configuration in `.config`.

  WHAT IT DOES
    1. Extracts each config to `_versions\tenant_exports\` -- GITIGNORED, verified below, and
       the payloads are NEVER committed. One eSUN export reached pushed history once and
       removing it took a force-push; this tool refuses to write a payload anywhere tracked.
    2. Computes a CANONICAL SHA-256 (via _json_canonical.ps1) per config. This is the
       primitive the future import-verify step needs, because a byte compare CANNOT work:
       the platform re-serializes, so a 246KB export and a 928KB repo JSON at the SAME
       version are expected to differ. Only equality would be surprising.
    3. CLASSIFIES on the evidence, into THREE classes, not two. Rob asked for
       "USx or NON-USx"; the data does not support two:
         OURS              provider bundle + our "Provider configuration for <P> vX.Y" string
         PROVIDER-NOT-OURS provider bundle, NO version string -- a config we did not build
                           (Lafayette, sdso, gordo, 24 byte-identical LA_LEMS demo copies)
         NO-PROVIDER       nothing installed
       Folding the middle class into OURS claims ownership of 32 configs we did not author;
       folding it into NON-USx hides the support exposure. It gets its own class.
    4. Emits a COMMITTED METADATA inventory (`providers\TENANT_CONFIG_INVENTORY.json` +
       a readable table). Metadata only -- no config content ever enters the repo.

  !! WHAT IT REFUSES TO DO
   1. 0 FILES FAILS. "Found nothing" and "never looked" are different verdicts (ENG STD 4.3).
   2. IT WILL NOT WRITE A PAYLOAD TO A TRACKED PATH. `git check-ignore` is consulted; if the
      export directory is not ignored, it stops rather than stage 15MB of customer config.
   3. A CONFIG THAT FAILED TO PARSE IS NOT INVENTORIED AS CLEAN -- it is reported, because a
      config we cannot read is not a config we have a record of.
   4. IT DOES NOT TOUCH `IMPORT_LEDGER.md`. That file is hand-authored and is Rob's source of
      truth: "i will help align them with our ledger as needed". This tool REPORTS deltas.

  Usage:
    .\tools\ingest_tenant_configs.ps1
    .\tools\ingest_tenant_configs.ps1 -Path <dir> -OutFile providers\TENANT_CONFIG_REPORT.txt
#>

param(
    [string]$Path,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot '_json_canonical.ps1')

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

$srcDir  = if ($Path) { $Path } else { Join-Path $env:USERPROFILE 'Downloads' }
$outDir  = Join-Path $repoRoot '_versions\tenant_exports'
$invPath = Join-Path $repoRoot 'providers\TENANT_CONFIG_INVENTORY.json'

Say ''
Say '===================================================================================='
Say '  TENANT CONFIG INGEST -- the baseline record of what is deployed where'
Say '===================================================================================='

# -- GUARD 1: the payload destination MUST be untracked. Non-negotiable. ------------
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$probe = Join-Path $outDir '.ignore_probe'
Set-Content -Path $probe -Value 'x' -Encoding ASCII
Push-Location $repoRoot
$ignored = (& git check-ignore $probe 2>$null)
Pop-Location
Remove-Item $probe -Force -ErrorAction SilentlyContinue
if (-not $ignored) {
    Say "  [FAIL] $outDir is NOT gitignored."
    Say '         Refusing to extract customer configuration into a tracked path. Add'
    Say '         `_versions/` to .gitignore first. (A tenant export reached pushed history'
    Say '         once and removing it required a force-push.)'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

$files = @(Get-ChildItem $srcDir -Filter 'usx_tenant_config_*.json' -File -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime)
Say ("  source: {0}" -f $srcDir)
Say ("  config files found: {0}   payload dir (gitignored): _versions\tenant_exports" -f $files.Count)

if ($files.Count -eq 0) {
    Say '  [FAIL] no usx_tenant_config_*.json found.'
    Say '         0 files examined -- this run says NOTHING about any tenant.'
    Say '         Run extension button "6b. PULL THE CONFIGS" first (one file per tenant).'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

# -- ingest, newest-per-deptId wins (a re-pull supersedes) --------------------------
$inv = @{}
$parseFail = @(); $bytesTotal = 0
foreach ($f in $files) {
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { $parseFail += ("{0} -- wrapper unreadable: {1}" -f $f.Name, $_.Exception.Message); continue }
    if (-not $o.deptId) { $parseFail += ("{0} -- no deptId" -f $f.Name); continue }

    $id  = "$($o.deptId)"
    $tag = if ($o.subdomain) { ($o.subdomain -replace '[^A-Za-z0-9_.-]','_') } else { "dept$id" }
    $dest = Join-Path $outDir ("{0}_{1}.json" -f $tag, $id)

    # The config arrives as a JSON *string*. Write it verbatim, then parse a copy for hashing;
    # a config we cannot parse is reported, never silently inventoried as clean (refusal 3).
    $cfg = $o.config
    $hash = $null; $parsed = $null; $note = ''; $archived = $null
    if ([string]::IsNullOrWhiteSpace($cfg)) {
        $note = 'NO CONFIG CONTENT in the wrapper'
    } else {
        # ⚠️ ARCHIVE A CHANGED PRIOR CONFIG BEFORE OVERWRITING IT. Added 2026-09-11 for the
        # import-verify loop: the destination path is keyed on tenant, so re-ingesting after an
        # import would OVERWRITE the very BEFORE snapshot the proof depends on. Rob's goal is
        # "import, then run an export, then compare the 2" -- and without this, the 2nd export
        # destroys the 1st. Only archived when the content actually DIFFERS, so a routine
        # re-pull does not accumulate identical copies.
        if (Test-Path $dest) {
            $prior = [System.IO.File]::ReadAllText($dest)
            if ($prior -ne $cfg) {
                $arcDir = Join-Path $outDir '_before'
                if (-not (Test-Path $arcDir)) { New-Item -ItemType Directory -Path $arcDir -Force | Out-Null }
                $stampf = (Get-Item $dest).LastWriteTime.ToString('yyyyMMdd-HHmmss')
                $archived = Join-Path $arcDir ("{0}_{1}_{2}.json" -f $tag, $id, $stampf)
                if (-not (Test-Path $archived)) { Move-Item -Path $dest -Destination $archived }
            }
        }
        [System.IO.File]::WriteAllText($dest, $cfg, (New-Object System.Text.UTF8Encoding($false)))
        $bytesTotal += $cfg.Length
        try {
            $parsed = $cfg | ConvertFrom-Json
            $hash = Get-Sha256Hex (ConvertTo-Canonical $parsed)
        } catch { $note = 'CONFIG PRESENT BUT UNPARSEABLE -- not hashable'; $parseFail += ("{0} -- config unparseable" -f $f.Name) }
    }

    # classify on evidence
    $cls = if ($o.provider -and $o.version) { 'OURS' }
           elseif ($cfg)                    { 'PROVIDER-NOT-OURS' }
           else                             { 'UNKNOWN' }

    # ⚠️ [pscustomobject], NOT a bare [ordered]@{}. `Group-Object configSha256` resolves the
    # property through the PSObject adapter, and for a dictionary that adapter exposes
    # Keys/Values/Count -- NOT the entries. With ordered hashtables the grouping silently found
    # NO such property, put all 4 fixture tenants in ONE group, and printed
    # "4 tenants share hash .." with an EMPTY hash. That is a FALSE FINDING in the exact shape
    # this section exists to report (one config copied across N tenants), and `Where-Object`
    # had worked fine on the same rows -- scriptblock member access reads dictionary keys,
    # -Property does not. Two idioms, same data, different answers.
    $inv[$id] = [pscustomobject][ordered]@{
        deptId          = $id
        subdomain       = "$($o.subdomain)"
        status          = "$($o.status)"
        class           = $cls
        provider        = "$($o.provider)"
        version         = "$($o.version)"
        versionStrings  = @($o.versionStrings)
        mixedVersions   = [bool]$o.mixedVersions
        bundleCounters  = "$($o.counters)"
        configBytes     = if ($cfg) { $cfg.Length } else { 0 }
        configSha256    = $hash
        exportPath      = "_versions/tenant_exports/$tag`_$id.json"
        capturedAt      = "$($o.capturedAt)"
        priorArchived   = $archived
        note            = $note
    }
}

Say ("  distinct tenants ingested: {0}   config bytes extracted: {1:N0}" -f $inv.Count, $bytesTotal)
if ($parseFail.Count -gt 0) {
    Say ("  !! {0} FILE(S) COULD NOT BE FULLY READ -- a config we cannot parse is not a record:" -f $parseFail.Count)
    foreach ($x in $parseFail) { Say ("     $x") }
}

# -- the classes --------------------------------------------------------------------
$ours   = @($inv.Values | Where-Object { $_.class -eq 'OURS' })
$notOur = @($inv.Values | Where-Object { $_.class -eq 'PROVIDER-NOT-OURS' })
$unk    = @($inv.Values | Where-Object { $_.class -eq 'UNKNOWN' })
Say ''
Say ("  OURS {0} | PROVIDER-NOT-OURS {1} | UNKNOWN {2}" -f $ours.Count, $notOur.Count, $unk.Count)
Say '  (a provider bundle with no "Provider configuration for <P> vX.Y" description is a config'
Say '   we did NOT build -- that absence is positive evidence, not a gap.)'

# -- THE QUESTION THE OLD SWEEP COULD NOT ANSWER ------------------------------------
$mixed = @($inv.Values | Where-Object { $_.mixedVersions })
Say ''
Say '  ---- MIXED-VERSION TENANTS (the discriminating test, now answerable from data) ----'
if ($mixed.Count -eq 0) {
    Say '  NONE. No tenant names the same provider at two different versions.'
    Say '  => a tenant reading OLDER than its committed logs is NOT a "we read the first of two'
    Say '     strings" artifact. The remaining explanation is a genuinely stale install.'
} else {
    foreach ($m in $mixed) {
        Say ("  {0,-28} {1}" -f $m.subdomain, (@($m.versionStrings) -join ' + '))
    }
    Say '  => these tenants carry MORE THAN ONE version string; the single `version` field on'
    Say '     such a row is whichever came first and must NOT be cited as "the" version.'
}

# -- duplicate configs: one file copied, or N independent installs? -----------------
Say ''
Say '  ---- IDENTICAL CONFIGS (same canonical hash = one config copied, not N installs) ----'
$groups = @($inv.Values | Where-Object { $_.configSha256 } | Group-Object configSha256 | Where-Object { $_.Count -gt 1 } | Sort-Object Count -Descending)
if ($groups.Count -eq 0) { Say '  none -- every config is distinct.' }
foreach ($g in $groups) {
    # Build every piece FIRST. A backtick continuation carrying an inline $(if ...) inside a
    # -f argument list parses under pwsh 7 and DIES under 5.1 -- and 5.1 is the engine that
    # actually runs these (`powershell -File`). Caught by the tool's own fixture run.
    $subs  = (@($g.Group | ForEach-Object { $_.subdomain }) -join ', ')
    $p     = @($g.Group)[0]
    $short = [string]$g.Name
    if ($short.Length -gt 12) { $short = $short.Substring(0, 12) }
    $label = 'NOT OURS'
    if ($p.provider) { $label = [string]$p.provider + ' v' + [string]$p.version }
    Say ("  {0,2} tenants share hash {1}..  [{2}]" -f $g.Count, $short, $label)
    Say ("     {0}" -f $subs)
}

# -- write the committed METADATA inventory (never the payloads) --------------------
# ⚠️ MERGE, DO NOT REPLACE. Found 2026-09-11 by doing it wrong: ingesting a SINGLE tenant's
# pull (the deploy loop's before/after step) rewrote this committed inventory with ONE row and
# clobbered the other 64. Restored from git. It would have recurred on EVERY single-tenant pull
# -- which is exactly the workflow usx-deploy prescribes, so the bug was aimed squarely at the
# procedure I had just written down. A partial ingest is now ADDITIVE: existing rows survive,
# re-ingested rows are superseded by deptId.
$merged = [ordered]@{}
if (Test-Path $invPath) {
    try {
        $prev = Get-Content $invPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($t in @($prev.tenants)) { $merged["$($t.deptId)"] = $t }
    } catch { Say '  [WARN] existing inventory unreadable -- writing a fresh one rather than merging.' }
}
$carriedOver = $merged.Count
foreach ($k in $inv.Keys) { $merged[$k] = $inv[$k] }
Say ("  inventory merge: {0} carried over + {1} from this run = {2} total" -f `
     $carriedOver, $inv.Count, $merged.Count)

$doc = [ordered]@{
    _what   = 'Baseline record of which provider configuration is deployed on which tenant.'
    _rules  = @(
        'METADATA ONLY. Config payloads live in the gitignored _versions/tenant_exports/ and are NEVER committed.',
        'deptId is the only stable join key -- subdomains get renamed and the ledger uses prose names.',
        'THREE classes: OURS / PROVIDER-NOT-OURS / UNKNOWN. Two would lose the not-ours configs.',
        'configSha256 is a CANONICAL hash for before/after import comparison. A raw byte compare cannot work: the platform re-serializes.',
        'This file is DERIVED. It does not amend IMPORT_LEDGER.md, which is hand-authored.'
    )
    generated = (Get-Date).ToString('s')
    source    = 'tools/ingest_tenant_configs.ps1 <- extension button 6b'
    counts    = [ordered]@{ tenants = $merged.Count; ours = $ours.Count; providerNotOurs = $notOur.Count; unknown = $unk.Count; mixedVersions = $mixed.Count }
    tenants   = @($merged.Values | Sort-Object { $_.subdomain })
}
$doc | ConvertTo-Json -Depth 6 | Set-Content -Path $invPath -Encoding UTF8
Say ''
Say ("  inventory written: providers\TENANT_CONFIG_INVENTORY.json  ({0} tenants total, metadata only)" -f $merged.Count)
Say '===================================================================================='
Say ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
