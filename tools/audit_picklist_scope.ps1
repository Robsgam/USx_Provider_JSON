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

  Usage: audit_picklist_scope.ps1 -Path <provider.json>
#>
param([Parameter(Mandatory)][string]$Path)

$ErrorActionPreference = 'Stop'
$json     = (Resolve-Path $Path).Path
$dir      = Split-Path $json -Parent
$provider = Split-Path $dir -Leaf

# TENANT_PICKLISTS.json lives flat (docs/) for legacy providers or docs/reference/ once migrated.
$candidates = @(
    (Join-Path $dir 'docs\TENANT_PICKLISTS.json'),
    (Join-Path $dir 'docs\reference\TENANT_PICKLISTS.json')
)
$tenantFile = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $tenantFile) {
    Write-Output "[NOTE] ${provider}: tenant picklists not captured (no TENANT_PICKLISTS.json) -- run the one-time picklist scope (logs\${provider}_PICKLIST_SCOPE.console.js in the tenant, then the watcher ingests it)."
    exit 0
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
$reqCats  = [regex]::Matches($reqText,                       $catRe) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$capCats  = [regex]::Matches((Get-Content $tenantFile -Raw), $catRe) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$missing  = @($reqCats | Where-Object { $_ -notin $capCats })

if ($missing.Count -gt 0) {
    Write-Output "[NOTE] ${provider}: dropdown code categor$(if($missing.Count -gt 1){'ies'}else{'y'}) not in the captured tenant picklists -- re-scope needed: $($missing -join ', ')"
}
exit 0
