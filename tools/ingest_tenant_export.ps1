<#
  ingest_tenant_export.ps1 -- READ A TENANT'S EXPORTED CONFIG AND SAY WHICH VERSION IT RUNS.

  WHY THIS EXISTS (Rob, 2026-09-10): "i want to be able to parse all the tenants and document
  what each tenant has for a version of json", and before that "download and ingest the json
  for reference and cross checking".

  THE CHAIN THAT MADE IT POSSIBLE, and every link was measured rather than assumed:
    1. The support-admin endpoints are session-authenticated (repo-side GET -> 303 /rms/login/),
       so reading them happens in the operator's browser via automation/extension/admin_probe.js.
    2. The bundle table on a configuration page is JAVASCRIPT-POPULATED: fetching returns 0 rows
       (that produced 21 confident zeros), the live DOM returns them. Solved with a hidden iframe.
    3. ⚠️ THE BUNDLE TABLE'S `Version` COLUMN IS A PLATFORM COUNTER, NOT OUR VERSION.
       eSUN's table says 590/48/70 while the provider is v3.3. It CANNOT answer this question.
    4. There is NO API endpoint to harvest -- the page references only CDN scripts.
    5. So the answer is the page's own **Export JSON** control, which yields the full bundle,
       and OUR version lives inside it as the bundle description:
           "Provider configuration for CA_eSUN v3.3"
       That is repo convention precisely BECAUSE the platform rejects a top-level version field
       (it deserializes as java.lang.Integer). The convention that exists for one reason turns
       out to be what makes a tenant's version readable at all.

  WHAT THIS TOOL DOES. Given the extension's `usx_admin_export_<deptId>_*.json`, it:
    - extracts the EMBEDDED full configuration to a real .json file, so it can be diffed against
      the repo build byte-for-byte,
    - reads the provider + version out of the bundle description,
    - reports the platform's own bundle counters alongside, and
    - cross-references the version against the repo's CURRENT version for that provider.

  ⚠️ WHAT IT DOES NOT DO: claim a tenant is "correct". A matching version means the tenant runs a
  build with that version STRING. Byte-equality against the repo file is a separate check and is
  offered (-Diff) rather than implied.

  Usage:
    .\tools\ingest_tenant_export.ps1                       # newest export in Downloads
    .\tools\ingest_tenant_export.ps1 -All                  # every export in Downloads
    .\tools\ingest_tenant_export.ps1 -Path <file> -Diff
#>

param(
    [string]$Path,
    [switch]$All,
    [switch]$Diff,
    [string]$OutDir,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot '_resolve_provider_json.ps1')

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }

if (-not $OutDir) { $OutDir = Join-Path $repoRoot '_versions\tenant_exports' }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# Source files
$dl = Join-Path $env:USERPROFILE 'Downloads'
$files = @()
if ($Path) {
    if (-not (Test-Path $Path)) { Say "  [FAIL] not found: $Path"; exit 1 }
    $files = @(Get-Item $Path)
} else {
    $found = @(Get-ChildItem $dl -Filter 'usx_admin_export_*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    if (-not $All -and $found.Count -gt 0) { $files = @($found[-1]) } else { $files = $found }
}

Say ''
Say '===================================================================================='
Say '  TENANT EXPORT -> WHICH VERSION IS ACTUALLY INSTALLED'
Say '===================================================================================='

if ($files.Count -eq 0) {
    # A zero denominator is not a pass (ENGINEERING_STANDARD 4.3).
    Say "  [FAIL] no usx_admin_export_*.json found in $dl -- run the panel's export probe first."
    Say '         0 files examined; this run says NOTHING about any tenant.'
    exit 1
}

$rows = @()
foreach ($f in $files) {
    $o = Get-Content $f.FullName -Raw | ConvertFrom-Json
    $deptId = "$($o.deptId)"
    $blobs = @($o.clicked.newText)
    if (-not $o.clicked) { Say ("  [NOTE] {0}: nothing was clicked -- no export payload" -f $f.Name); continue }
    if ($blobs.Count -eq 0) { Say ("  [NOTE] {0}: click produced no in-page JSON" -f $f.Name); continue }

    # Two blobs are expected: a small summary (departmentId + bundle counters) and the
    # full configuration. Pick by SIZE and by content, never by index.
    $summary = $null; $full = $null
    foreach ($b in $blobs) {
        if ($b -match '"departmentBundle"') { if (-not $full -or $b.Length -gt $full.Length) { $full = $b } }
        elseif ($b -match '"bundles"' -and $b.Length -lt 4000) { $summary = $b }
    }
    if (-not $full) { Say ("  [NOTE] {0}: no blob contains departmentBundle -- cannot read a version" -f $f.Name); continue }

    # OUR version, from the bundle description. This is the whole point.
    $vm = [regex]::Matches($full, 'Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)')
    $provider = $null; $version = $null
    if ($vm.Count -gt 0) {
        # Prefer a non-RMS provider name; the RMS bundle carries its own description.
        foreach ($m in $vm) {
            $p = $m.Groups[1].Value
            if ($p -ne 'RMS') { $provider = $p; $version = $m.Groups[2].Value; break }
        }
        if (-not $provider) { $provider = $vm[0].Groups[1].Value; $version = $vm[0].Groups[2].Value }
    }

    # Platform counters, for the record -- explicitly NOT the version.
    $counters = ''
    if ($summary) {
        try {
            $sj = $summary | ConvertFrom-Json
            $counters = (@($sj.bundles | ForEach-Object { "$($_.name)/$($_.version)" }) -join ' ')
        } catch {}
    }

    # Write the embedded config out as a real file so it can be diffed against the repo build.
    $tag = if ($provider) { $provider } else { 'UNKNOWN' }
    $outFile = Join-Path $OutDir ("{0}_dept{1}_{2}.json" -f $tag, $deptId, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    [System.IO.File]::WriteAllText($outFile, $full, (New-Object System.Text.UTF8Encoding($false)))

    # Cross-reference: what does the REPO currently hold for that provider?
    $repoVer = $null
    if ($provider) {
        $pd = Join-Path $repoRoot ("providers\{0}" -f $provider)
        if (Test-Path $pd) {
            $rj = Get-ProviderRootJson $pd $provider
            if ($rj -and ($rj -match '_v([0-9]+\.[0-9]+)\.json$')) { $repoVer = $Matches[1] }
        }
    }
    $verdict = 'UNKNOWN'
    if ($version -and $repoVer) { $verdict = if ($version -eq $repoVer) { 'MATCHES REPO' } else { "REPO IS v$repoVer" } }
    elseif ($version -and -not $repoVer) { $verdict = 'no repo provider dir' }

    $rows += [pscustomobject]@{
        DeptId = $deptId; Provider = $provider; TenantVersion = $version
        RepoVersion = $repoVer; Verdict = $verdict; Counters = $counters
        Extracted = $outFile; Bytes = $full.Length
    }
}

if ($rows.Count -eq 0) { Say '  [FAIL] no export payload could be read from any file.'; exit 1 }

Say ''
Say ('  {0,-14} {1,-22} {2,-8} {3,-8} {4}' -f 'deptId', 'provider', 'tenant', 'repo', 'verdict')
Say ('  ' + ('-' * 92))
foreach ($r in $rows) {
    Say ('  {0,-14} {1,-22} v{2,-7} v{3,-7} {4}' -f $r.DeptId, $r.Provider, $r.TenantVersion, $r.RepoVersion, $r.Verdict)
    Say ('     platform counters: ' + $r.Counters)
    Say ('     full config extracted -> ' + $r.Extracted + (' ({0:N0} bytes)' -f $r.Bytes))
}

if ($Diff) {
    Say ''
    Say '  -- byte comparison against the repo build --'
    foreach ($r in $rows) {
        if (-not $r.Provider) { continue }
        $pd = Join-Path $repoRoot ("providers\{0}" -f $r.Provider)
        $rj = if (Test-Path $pd) { Get-ProviderRootJson $pd $r.Provider } else { $null }
        if (-not $rj) { Say ("     {0}: no repo JSON to compare" -f $r.Provider); continue }
        $a = (Get-FileHash $r.Extracted -Algorithm SHA256).Hash
        $b = (Get-FileHash $rj -Algorithm SHA256).Hash
        # ⚠️ A MISMATCH IS EXPECTED AND IS NOT A DEFECT. The platform RE-SERIALIZES on export
        # (an earlier tenant export measured 246KB against the repo's 928KB for the same
        # version, wrapped in departmentBundle). Only equality would be notable.
        Say ("     {0}: export {1}  repo {2}  -> {3}" -f $r.Provider, $a.Substring(0,12), $b.Substring(0,12),
             $(if ($a -eq $b) { 'IDENTICAL (surprising -- platform normally re-serializes)' } else { 'differ (EXPECTED: platform re-serializes; compare semantically, not by hash)' }))
    }
}

Say ''
Say ("  {0} export file(s) read / {1} tenant version(s) resolved" -f $files.Count, $rows.Count)
Say '===================================================================================='
Say ''
exit 0
