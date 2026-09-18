<#
  build_sharedquery_probe.ps1 -- CAN ONE `query` LIVE ON TWO ENTITIES AT ONCE?

  WHY THIS EXISTS. Rob, 2026-09-18: "the wanted person query will need to cofire with person
  queires and vehicle queires were appropriate. so no longer will the wanted person tab exist but
  we will roll the wanted person query onto to each tab  veh on veh and person on person relative
  to the required and ioptional fields in the combinations."

  THAT REQUIRES SPLITTING ONE TRANSACTION ACROSS TWO ENTITIES, and two measured facts box it in:
    1. A QIDM has exactly ONE targetEntity, and CHECKBOXES ARE KEYED BY ENTITY (measured with
       CHECKBOX_PROBE, 2026-09-18). So a Vehicle-tab plate fill can NEVER trigger a Person-entity
       query. Person combos and Vehicle combos must live in SEPARATE QIDMs.
    2. THE WIRE CARRIES THE `query` VALUE AS <MessageType>. Read from a real SC_SLED capture:
           <MessageType>WantedPersonQuery</MessageType>
       So the two QIDMs MUST share the same `query` -- inventing `WantedPersonQueryVehicle` would
       put that string on the wire and SC would reject it. And `name` must DIFFER, because a
       duplicate config name is a silent overwrite at import (the validator caught exactly that
       on CHECKBOX_PROBE's first cut).

  THE UNKNOWN THIS TESTS. The platform spec says `query` is "Internal query name. Used to match
  this config with the form the user submitted." It does NOT say whether that match is by query
  ALONE or by (query, targetEntity). If it is query alone, one of the two configs wins and the
  other is DEAD -- and it would be dead SILENTLY, with every structural gate green, which is the
  failure class this repo exists to catch before an officer meets it.

  THE DESIGN. Two QIDMs, same query `SharedProbeQuery`, different names, different entities:
      SHAREDQ_PROBE_SharedProbeQuery       targetEntity=Person    set[PersonKey]
      SHAREDQ_PROBE_SharedProbeQuery_Veh   targetEntity=Vehicle   set[VehicleKey]
  Plus ONE CONTROL PER ENTITY that only that entity's combo needs, so the tabs cannot be confused.
  Each entity also gets a CONTROL QIDM with a unique query name, which is the part that makes a
  null result readable: if the control renders and the shared one does not, the shared `query` is
  the cause; if NEITHER renders, the probe is broken and proves nothing.

  HOW TO READ IT -- look at the Person tab and the Vehicle tab and list the checkboxes:
    BOTH tabs show 'Shared Probe' + their own control  -> (query, entity) is the key. THE SPLIT
                                                          WORKS and the Wanted Person roll-in is
                                                          buildable as designed.
    ONLY ONE tab shows 'Shared Probe'                  -> query alone is the key; the second
                                                          config is silently dropped. The roll-in
                                                          needs a different approach entirely.
    NEITHER shows it, controls DO                      -> a duplicate query is rejected outright.
    NEITHER tab renders at all                         -> probe broken; ignore everything above.
  Then type in each tab's key field and confirm the shared checkbox ACTIVATES there -- present but
  never-activating is the dead-checkbox state, not a working split.

  ⚠️ THROWAWAY RIG, HAND-IMPORT ONLY. An import REPLACES the bundle set; put the real build back.

  Usage: .\tools\build_sharedquery_probe.ps1 [-OutPath ...]
#>
[CmdletBinding()]
param([string]$OutPath)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = Split-Path -Parent $toolDir
. "$toolDir\_build_layout_helpers.ps1"
. "$toolDir\_build_rms_bundle.ps1"
. "$toolDir\_build_provider_helpers.ps1"

$provName = 'SHAREDQ_PROBE'
$shared   = 'SharedProbeQuery'

Write-Host ''
Write-Host '====================================================================================' -ForegroundColor Cyan
Write-Host '  SHARED-QUERY PROBE -- can one `query` live on two entities at once?' -ForegroundColor Cyan
Write-Host '====================================================================================' -ForegroundColor Cyan

function New-Form([string]$entity, [string]$keyField, [string]$label) {
    $tag = $entity.ToUpper()
    $layout = MakeLayouts @(
        @{
            id    = "CARD_$tag"
            title = "$label -- shared-query probe"
            rows  = @(
                @{ id = "ROW_$tag"; cols = @('12'); fields = @(
                    @{ id = "${keyField}_Input"; node = Inp $keyField $keyField '20' "ROW_$tag" }
                )}
            )
        }
    )
    [PSCustomObject]@{
        description  = "Shared-query probe form for $entity. Throwaway."
        label        = $label
        layout       = $layout
        name         = "ENTITY_$entity"
        type         = 'QUERYINPUTFORM'
        targetEntity = $entity
    }
}

# Build-Qidm DERIVES name from query on purpose, so the second shared QIDM is assembled by hand
# here -- deliberately, and only inside a throwaway rig. This is exactly the override the real
# build would need, and testing it here is cheaper than adding it to the shared helper first.
function New-SharedQidm([string]$entity, [string]$keyField, [string]$nameSuffix) {
    $q = Build-Qidm -ProviderName $provName -Query $shared -TargetEntity $entity -QueryLabel 'Shared Probe' `
        -Attributes @( Build-QidmAttribute -Name $keyField -Size 20 -SourceField @($keyField) ) `
        -Combinations @( Build-QidmCombo -KeyReference "SH.$($entity.Substring(0,3).ToUpper())" `
                            -PrimaryFieldReference $keyField -Set @($keyField) ) `
        -Description "Shared-query probe: query='$shared' on targetEntity='$entity'. Throwaway."
    if ($nameSuffix) { $q.name = "$($q.name)$nameSuffix" }
    return $q
}

function New-ControlQidm([string]$entity, [string]$keyField, [string]$queryName) {
    Build-Qidm -ProviderName $provName -Query $queryName -TargetEntity $entity -QueryLabel "Control $entity" `
        -Attributes @( Build-QidmAttribute -Name $keyField -Size 20 -SourceField @($keyField) ) `
        -Combinations @( Build-QidmCombo -KeyReference "CTL.$($entity.Substring(0,3).ToUpper())" `
                            -PrimaryFieldReference $keyField -Set @($keyField) ) `
        -Description "CONTROL for the shared-query probe on $entity -- unique query name, must render."
}

$personForm  = New-Form 'Person'  'PersonKey'  'Person (probe)'
$vehicleForm = New-Form 'Vehicle' 'VehicleKey' 'Vehicle (probe)'

$sharedPerson = New-SharedQidm 'Person'  'PersonKey'  ''        # keeps the derived name
$sharedVeh    = New-SharedQidm 'Vehicle' 'VehicleKey' '_Veh'    # the collision-avoiding suffix
$ctlPerson    = New-ControlQidm 'Person'  'PersonKey'  'ControlPersonQuery'
$ctlVehicle   = New-ControlQidm 'Vehicle' 'VehicleKey' 'ControlVehicleQuery'

$entityOrder    = @('Person','Vehicle')
$entitiesBundle = Build-EntitiesBundle -Configurations @($personForm, $vehicleForm) `
    -DefaultOrder $entityOrder -CadOrder $entityOrder -FrOrder $entityOrder

$providerBundle = [PSCustomObject]@{
    configurations = @((Build-Auth -ProviderName $provName), (Build-Qmf -ProviderName $provName),
                       (Build-ProviderQrdm -ProviderName $provName),
                       $sharedPerson, $sharedVeh, $ctlPerson, $ctlVehicle)
    description    = "Shared-query probe -- THROWAWAY RIG, not a provider."
    name           = $provName
    type           = 'BUNDLE'
    provider       = $provName
}

$bundle = [PSCustomObject]@{ bundles = @($entitiesBundle, $providerBundle) }
if (-not $OutPath) { $OutPath = Join-Path $repoRoot 'providers\SHAREDQ_PROBE.json' }

Write-Host ''
Write-Host ("  two QIDMs share query='{0}':" -f $shared) -ForegroundColor Gray
Write-Host ("    {0,-42} entity=Person   set[PersonKey]" -f $sharedPerson.name) -ForegroundColor Gray
Write-Host ("    {0,-42} entity=Vehicle  set[VehicleKey]" -f $sharedVeh.name) -ForegroundColor Gray
Write-Host '  plus one CONTROL QIDM per entity with a UNIQUE query name.' -ForegroundColor Gray
Write-Host ''
Write-Host '  READ IT -- checkboxes on the Person tab and on the Vehicle tab:' -ForegroundColor Yellow
Write-Host '    Shared Probe on BOTH   -> (query, entity) is the key: the Wanted Person split WORKS' -ForegroundColor Gray
Write-Host '    Shared Probe on ONE    -> query alone is the key: one config is silently dropped' -ForegroundColor Gray
Write-Host '    Shared Probe on NEITHER (controls present) -> duplicate query rejected outright' -ForegroundColor Gray
Write-Host '    no tabs at all         -> probe broken, conclude nothing' -ForegroundColor Gray
Write-Host '  Then type in each key field: the shared checkbox must ACTIVATE on that tab.' -ForegroundColor Yellow
Write-Host ''

Write-ProviderJson -BundleObject $bundle -OutPath $OutPath -Label "$provName (throwaway rig)"
