<#
  audit_picklist_scope.ps1 -- ADVISORY picklist-scope reminder (never blocks).

  Tenant picklists are a ONE-TIME-per-provider capture (docs/TENANT_PICKLISTS.json): the tenant's
  dropdown option lists, keyed by code category (YES_NO_UNKNOWN, NCIC_*, ...). This check reminds
  when a provider still owes that capture, or when a build introduced a NEW code category the
  existing capture doesn't cover (the only case that warrants a re-scope).

  Emits [NOTE] lines only; ALWAYS exits 0. It is advisory -- enforce.ps1 surfaces the NOTE without
  touching PASS/FAIL/WARN counts or the exit code (a NOTE is not a WARN, so the 0-WARN gospel holds).

  Category model: only NON-NULL codeTypeCategory dropdowns are compared. attributeTypeId dropdowns
  (STATE / SEX / VEHICLE_MAKE) capture with codeTypeCategory=null -- they are tenant-global/stable and
  reused across fields (e.g. SexCode, SexCodeDH, SexCodeDGRP all = SEX), so a new field reusing one
  never triggers a re-scope. Only a genuinely new code category does.

  *** THE CATEGORY MODEL IS DELIBERATE, AND IT IS THE REASON NOT TO REPLACE THIS WITH A
      CONTROL-LEVEL CHECK (2026-08-21). *** A control-level probe over the 10 lifecycle-complete
  providers reported "21 of 158 dropdowns have no captured option list" and read as a portfolio-wide
  currency gap. It was not. THIRTEEN of those 21 are AZ_AZDPS, which this gate ALREADY reports
  (4 categories). The remaining 8 -- RegistrationStateDH on 5 providers, ImageIndicatorDH on 2,
  relatedHitSearchIndicator on 2 -- are controls added after their capture that REUSE an
  already-captured category, so the option list is literally the same list and a re-scope would
  capture nothing new. Reporting them would be 8 permanent non-findings, i.e. exactly the noise that
  trains people to ignore a gate. Per-CONTROL is the wrong granularity; per-CATEGORY is the question.

  *** WHAT WAS ACTUALLY BROKEN: NOBODY SWEPT IT. *** enforce.ps1 runs this per-provider, so a
  standing owed capture is invisible unless someone happens to enforce THAT provider -- and
  doctor.ps1, the portfolio dashboard, did not run it at all. AZ_AZDPS has owed 4 categories with its
  Firearm, Article and Person dropdowns never scoped, while every board read green. Hence -All /
  -Providers below, composed into doctor.ps1. Same defect class as audit_layout_flow sitting unwired
  from 2026-08-11 to 08-18: a gate nobody runs is indistinguishable from one that does not exist.

  Usage:
    audit_picklist_scope.ps1 -Path <provider.json>       # single provider (enforce uses this)
    audit_picklist_scope.ps1 -All                        # portfolio sweep, with denominators
    audit_picklist_scope.ps1 -Providers AZ_AZDPS,TX_TLETS
#>
param(
    [string]$Path,
    [string[]]$Providers,
    [switch]$All,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
. "$PSScriptRoot\_resolve_provider_json.ps1"

# Returns a hashtable: Provider, State ('no-capture'|'rescope'|'ok'), Missing (array), Note (string)
function Test-PicklistScope([string]$jsonPath) {
    $json     = (Resolve-Path $jsonPath).Path
    $dir      = Split-Path $json -Parent
    $provider = Split-Path $dir -Leaf

    # TENANT_PICKLISTS.json lives flat (docs/) for legacy providers or docs/reference/ once migrated.
    $candidates = @(
        (Join-Path $dir 'docs\TENANT_PICKLISTS.json'),
        (Join-Path $dir 'docs\reference\TENANT_PICKLISTS.json')
    )
    $tenantFile = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $tenantFile) {
        $msg = "[NOTE] ${provider}: tenant picklists not captured (no TENANT_PICKLISTS.json) -- run the one-time picklist scope (logs\${provider}_PICKLIST_SCOPE.console.js in the tenant, then the watcher ingests it)."
        return @{ Provider = $provider; State = 'no-capture'; Missing = @(); Note = $msg }
    }

    # Non-null code categories the tenant query FORMS require vs what the capture covers.
    # Scope the "required" scan to the ENTITIES bundle only (the ConnectCic query-input forms the
    # picklist scope actually captures) -- NOT the RMS bundle or QRDM, whose dropdowns (NIBRS_RACE,
    # NJ_NIBRS_STATE, VEHICLE_BODY_STYLE, ...) belong to the RMS elastic form and are never part of
    # the tenant ConnectCic picklist capture. The ENTITIES bundle is the one holding QUERYINPUTFORM
    # configurations. Fall back to whole-JSON if the shape is unexpected.
    $catRe = '"codeTypeCategory"\s*:\s*"([^"]+)"'
    try {
        $obj = Get-Content $json -Raw | ConvertFrom-Json
        $entBundle = $obj.bundles | Where-Object {
            $_.configurations -and (@($_.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' }).Count -gt 0)
        } | Select-Object -First 1
        $reqText = if ($entBundle) { $entBundle | ConvertTo-Json -Depth 100 } else { Get-Content $json -Raw }
    } catch {
        $reqText = Get-Content $json -Raw
    }
    $reqCats = [regex]::Matches($reqText,                       $catRe) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $capCats = [regex]::Matches((Get-Content $tenantFile -Raw), $catRe) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $missing = @($reqCats | Where-Object { $_ -notin $capCats })

    if ($missing.Count -gt 0) {
        $plural = 'y'
        if ($missing.Count -gt 1) { $plural = 'ies' }
        $msg = "[NOTE] ${provider}: dropdown code categor${plural} not in the captured tenant picklists -- re-scope needed: $($missing -join ', ')"
        return @{ Provider = $provider; State = 'rescope'; Missing = $missing; Note = $msg }
    }
    return @{ Provider = $provider; State = 'ok'; Missing = @(); Note = '' }
}

# ---- dispatch -------------------------------------------------------------------------------
if (-not $All -and -not $Providers -and -not $Path) {
    Write-Output "[NOTE] audit_picklist_scope: pass -Path <json>, -Providers <list> or -All."
    exit 0
}

# SINGLE-PROVIDER MODE IS BYTE-FOR-BYTE THE OLD BEHAVIOUR -- enforce.ps1 filters this tool's output
# on '^\[NOTE\]', so adding a summary line to this branch would change what enforce reports for
# every provider. Do not "improve" it.
if ($Path -and -not $All -and -not $Providers) {
    $r = Test-PicklistScope $Path
    if ($r.Note) { Write-Output $r.Note }
    exit 0
}

$names = @()
if ($All) {
    $names = @(Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name | ForEach-Object { $_.Name })
} else {
    $names = @($Providers)
}

$results = @()
$skipped = @()
foreach ($n in $names) {
    $pd = Join-Path $repoRoot "providers\$n"
    if (-not (Test-Path $pd)) { $skipped += "$n (no such provider)"; continue }
    $j = Get-ProviderRootJson -ProvDir $pd -Provider $n
    if (-not $j) { $skipped += "$n (no active JSON)"; continue }
    $results += (Test-PicklistScope $j)
}

if (-not $Quiet) {
    Write-Output ''
    Write-Output '===================================================================================='
    Write-Output '  TENANT PICKLIST SCOPE -- does each capture still cover the dropdowns we build?'
    Write-Output '===================================================================================='
    Write-Output ''
}

foreach ($r in ($results | Where-Object { $_.State -ne 'ok' } | Sort-Object { $_.Provider })) {
    Write-Output "  $($r.Note)"
}

$noCap   = @($results | Where-Object { $_.State -eq 'no-capture' })
$rescope = @($results | Where-Object { $_.State -eq 'rescope' })
$ok      = @($results | Where-Object { $_.State -eq 'ok' })

if (-not $Quiet) { Write-Output '' }

# A run that examined nothing must NOT read as clean -- the failure mode this whole file guards
# against is a check whose silence cannot be told apart from a pass.
if ($results.Count -eq 0) {
    Write-Output "  [NO-VERDICT] 0 provider(s) examined -- nothing was compared, this is NOT a clean result."
    if ($skipped.Count) { Write-Output "               SKIPPED: $($skipped -join ', ')" }
    exit 0
}

Write-Output ("  EXAMINED: {0} provider(s) / {1} owe the one-time capture / {2} owe a re-scope / {3} current" -f `
    $results.Count, $noCap.Count, $rescope.Count, $ok.Count)
if ($skipped.Count) { Write-Output "  SKIPPED: $($skipped -join ', ')" }
if ($noCap.Count -eq 0 -and $rescope.Count -eq 0) {
    Write-Output '  [PASS] every provider has a capture and it covers every dropdown category built.'
}
Write-Output '  ADVISORY -- always exits 0. A capture is a TENANT action, not a repo action.'
if (-not $Quiet) { Write-Output '====================================================================================' }
exit 0
