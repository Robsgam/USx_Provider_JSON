<#
  emit_picklist_scope.ps1 -- emit the PICKLIST_SCOPE.json the browser scope tool consumes.

  Code-table contents are TENANT data: the same codeTypeCategory/codeTypeSource pair serves
  different option sets per tenant (NJ GunMake = numeric NIBRS codes, HI/CA = NCIC letter
  codes; CA gunTypeCode had no 'HP'), and the platform has no code-types API -- options exist
  only in the rendered DOM. This scope plan lists every VISIBLE FormSelect per FORM so
  __usxScopePicklists (driver.js) can open each dropdown and dump its actual options.

  *** PER FORM, NOT PER ENTITY -- and it said "per entity" until 2026-09-18, when that cost a
      real capture. *** Tabs are keyed by QUERYINPUTFORM, NOT by targetEntity (CAPABILITY #47).
  SC_SLED declares ENTITY_WantedPerson with targetEntity='Firearm' and
  ENTITY_AdministrativeMessage with targetEntity='Boat', so bucketing on targetEntity filed
  Wanted Person's 5 dropdowns under "Firearm". The operator selected "Wanted Person" in the
  panel, the scope held no such key, and the button did nothing; he then scoped "Firearm" and
  the download came back with FIVE `field not found in DOM` errors -- correct behaviour, wrong
  scope data. The dedup key was `entity|fieldId` too, so a control appearing on BOTH forms of a
  doubled-up entity was silently DROPPED (it did not bite SC_SLED -- the two sets are disjoint --
  but it was one shared fieldId away from losing a dropdown with no message at all).
  `tab` is the string the operator picks in the panel and is derived EXACTLY as emit_test_plan
  derives it (strip ENTITY_, split CamelCase), so the two agree by construction. A single-QIF
  entity yields tab == entity, which is why the other 20 providers are byte-identical here.
  ⚠️ Do NOT "simplify" back to targetEntity, and do NOT match on the QIF NAME either -- the whole
  defect is that the two DISAGREE.

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
        # The panel group label. Same derivation as emit_test_plan.ps1 (~line 1047) so the
        # scope's keys and the plan's `tab` values cannot drift apart.
        $qifName = "$($config.name)"
        $tab = if ($qifName) { ($qifName -replace '^ENTITY_', '') -creplace '(?<=[a-z0-9])(?=[A-Z])', ' ' } else { "$entity" }
        if (-not $tab) { $tab = "$entity" }
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
            # attributeTypeId ADDED 2026-09-02. It was never emitted, so a dropdown driven by an
            # attributeTypeId rather than a codeTypeCategory/Source pair was recorded with NO SOURCE
            # IDENTIFICATION AT ALL -- both fields empty. Measured on CA_eSUN v1.0: 9 of 15 scoped
            # dropdowns (PurposeCode, SexCode, RegistrationState, VehicleMakeCode) captured as
            # cat=''/src='', so import_picklists stored them sourceless and its EMPTY-table failure
            # printed a bare "()" naming nothing. The capture itself is fine -- ingest keys on
            # fieldId -- but the stored evidence could not say WHICH table came back empty, which is
            # exactly the question LIMITATION #39 turns on (DEX_INQUIRY_PURPOSE_CODE resolves on
            # SDSO and returned ZERO options on NY).
            # STRICTLY ADDITIVE, AND THAT IS DELIBERATE: audit_picklist_scope's category model
            # depends on attributeTypeId dropdowns carrying a NULL codeTypeCategory (its header says
            # so, and it regexes "codeTypeCategory":"<non-empty>"). Folding attributeTypeId INTO
            # codeTypeCategory would silently change that gate's comparison set. A new key does not.
            $fields += [pscustomobject]@{
                entity           = $entity
                tab              = $tab
                qif              = $qifName
                fieldId          = $p.fieldId
                label            = "$($p.label)"
                codeTypeCategory = "$($p.codeTypeCategory)"
                codeTypeSource   = "$($p.codeTypeSource)"
                attributeTypeId  = "$($p.attributeTypeId)"
            }
        }
    }
}

# Dedup (same fieldId can appear in multiple card variants of ONE FORM). Keyed on the FORM,
# never the entity -- two forms sharing an entity are two separate captures on two separate
# tabs, and collapsing them loses one of them silently.
$seen = @{}; $uniq = @()
foreach ($f in $fields) {
    $k = "$($f.tab)|$($f.fieldId)"
    if ($seen[$k]) { continue }
    $seen[$k] = $true; $uniq += $f
}

$scope = [ordered]@{
    provider = $provName
    version  = $version
    note     = "Paste as `scope`; render each FORM (tab); __usxScopePicklists(scope, '<Tab>'). One download per tab. The tab is the panel's group label, not necessarily the targetEntity."
    fields   = $uniq
}
$logsDir = Join-Path (Split-Path (Resolve-Path $Path) -Parent) 'logs'
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
$outFile = Join-Path $logsDir "${provName}_PICKLIST_SCOPE.json"
$json = $scope | ConvertTo-Json -Depth 5
$json | Set-Content $outFile -Encoding utf8

# Console-paste variant: the operator opens this file, selects all, and pastes the whole
# thing into the tenant DevTools console -- it defines `scope` and prints the commands.
$entList = @($uniq | ForEach-Object { $_.tab } | Sort-Object -Unique)
$cmds = ($entList | ForEach-Object { "__usxScopePicklists(scope, '$_')" }) -join '\n  '
$consoleFile = Join-Path $logsDir "${provName}_PICKLIST_SCOPE.console.js"
@"
// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = $json;
console.log('%c[USx-SCOPE] scope loaded: $provName v$version --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  $cmds");
"@ | Set-Content $consoleFile -Encoding utf8

$byEnt = $uniq | Group-Object tab
Write-Host "[PASS] Picklist scope written: $outFile ($($uniq.Count) select field(s) across $($byEnt.Count) tab(s))" -ForegroundColor Green
Write-Host "[PASS] Console-paste variant:  $consoleFile" -ForegroundColor Green
foreach ($g in $byEnt) {
    $ent = @($g.Group)[0].entity
    $note = if ("$($g.Name)" -ne "$ent") { "  [tab != targetEntity '$ent' -- scope it from the '$($g.Name)' tab]" } else { "" }
    Write-Host ("  {0}: {1}{2}" -f $g.Name, (($g.Group | ForEach-Object { $_.fieldId }) -join ', '), $note)
}
