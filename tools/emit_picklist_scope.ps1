<#
  emit_picklist_scope.ps1 -- emit the PICKLIST_SCOPE.json the browser scope tool consumes.

  Code-table contents are TENANT data: the same codeTypeCategory/codeTypeSource pair serves
  different option sets per tenant (NJ GunMake = numeric NIBRS codes, HI/CA = NCIC letter
  codes; CA gunTypeCode had no 'HP'), and the platform has no code-types API -- options exist
  only in the rendered DOM. This scope plan lists every VISIBLE FormSelect per entity so
  __usxScopePicklists (driver.js) can open each dropdown and dump its actual options.

  Usage: .\tools\emit_picklist_scope.ps1 -Path providers/<P>/<P>_vX.Y.json
  Output: providers/<P>/logs/<P>_PICKLIST_SCOPE.json  (paste in console as `scope`)
#>
param([Parameter(Mandatory)][string]$Path)

$raw  = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$data = $raw | ConvertFrom-Json
$provName = (Split-Path (Split-Path (Resolve-Path $Path) -Parent) -Leaf)
$version = "unknown"
if ($data.version) { $version = $data.version }
elseif ((Split-Path $Path -Leaf) -match 'v(\d+\.\d+)') { $version = $Matches[1] }

$fields = @()
foreach ($bundle in $data.bundles) {
    foreach ($config in $bundle.configurations) {
        if ($config.type -ne "QUERYINPUTFORM") { continue }
        $entity = $config.targetEntity
        $layoutObj = $null
        try { $layoutObj = $config.layout.default } catch { }
        if (-not $layoutObj) { continue }
        foreach ($prop in $layoutObj.PSObject.Properties) {
            $node = $prop.Value
            if (-not $node) { continue }
            $resolved = $null
            try { $resolved = $node.type.resolvedName } catch { continue }
            if ($resolved -ne "FormSelect") { continue }
            if ($node.hidden -eq $true) { continue }   # hidden gate-feeders can't be opened
            $p = $node.props
            if (-not $p -or -not $p.fieldId) { continue }
            $fields += [pscustomobject]@{
                entity           = $entity
                fieldId          = $p.fieldId
                label            = "$($p.label)"
                codeTypeCategory = "$($p.codeTypeCategory)"
                codeTypeSource   = "$($p.codeTypeSource)"
            }
        }
    }
}

# Dedup (same fieldId can appear in multiple card variants of one entity)
$seen = @{}; $uniq = @()
foreach ($f in $fields) {
    $k = "$($f.entity)|$($f.fieldId)"
    if ($seen[$k]) { continue }
    $seen[$k] = $true; $uniq += $f
}

$scope = [ordered]@{
    provider = $provName
    version  = $version
    note     = "Paste as `scope`; render each entity form; __usxScopePicklists(scope, '<Entity>'). One download per entity."
    fields   = $uniq
}
$logsDir = Join-Path (Split-Path (Resolve-Path $Path) -Parent) 'logs'
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
$outFile = Join-Path $logsDir "${provName}_PICKLIST_SCOPE.json"
$json = $scope | ConvertTo-Json -Depth 5
$json | Set-Content $outFile -Encoding utf8

# Console-paste variant: the operator opens this file, selects all, and pastes the whole
# thing into the tenant DevTools console -- it defines `scope` and prints the commands.
$entList = @($uniq | ForEach-Object { $_.entity } | Sort-Object -Unique)
$cmds = ($entList | ForEach-Object { "__usxScopePicklists(scope, '$_')" }) -join '\n  '
$consoleFile = Join-Path $logsDir "${provName}_PICKLIST_SCOPE.console.js"
@"
// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = $json;
console.log('%c[USx-SCOPE] scope loaded: $provName v$version --', 'color:#0aa;font-weight:bold', scope.fields.length, 'select field(s). Now render an entity form and run:\n  $cmds');
"@ | Set-Content $consoleFile -Encoding utf8

$byEnt = $uniq | Group-Object entity
Write-Host "[PASS] Picklist scope written: $outFile ($($uniq.Count) select field(s))" -ForegroundColor Green
Write-Host "[PASS] Console-paste variant:  $consoleFile" -ForegroundColor Green
foreach ($g in $byEnt) { Write-Host ("  {0}: {1}" -f $g.Name, (($g.Group | ForEach-Object { $_.fieldId }) -join ', ')) }
