<#
  build_entity_probe.ps1 -- CAN THE PLATFORM RENDER MORE THAN FIVE ENTITY TABS?

  WHY THIS EXISTS. Rob, 2026-09-16, rejecting the Vehicle-card workaround for SC_SLED's
  AdministrativeMessage: "there has to be a way to have more than 5  this is just a card on the
  veh page.   i want it compeltely seperated".

  He is right that the question was not settled. What I actually had was:
    - all 21 of OUR providers use exactly Person/Vehicle/Firearm/Article/Boat -- the WEAKEST kind
      of evidence, 21 copies of one convention (ENGINEERING_STANDARD 4.5: practice is not spec)
    - 66 DEPLOYED tenant configs surveyed, including ones Mark43 engineering built and not us
      (Lafayette, sdso, gordo, demo copies) -- also zero sixth entities
    - ONE attempt (SC_SLED v1.0 `AdministrativeMessage`) that silently rendered nothing
  That proves NOBODY HAS SHIPPED ONE. It does not prove the platform refuses one, and it says
  nothing about WHICH names it would accept. Nothing in the repo documents the valid set:
  `UNIVERSAL_SEARCH_HANDLERS.txt` is a HANDLER registry with no entity section.

  SO STOP ARGUING AND MEASURE. One import answers it. This emits a throwaway configuration that
  declares the five known entities PLUS a list of candidate names, each as its own
  QUERYINPUTFORM with its own uniquely-labelled control, all named in the three order arrays.
  Import it and READ THE TABS: every candidate whose tab appears is a usable entity.

  WHY THE FIVE ARE INCLUDED AND ORDERED FIRST -- this is the safety design, not padding:
  AZ v2.0 proved the ENTITIES bundle is load-bearing (forms do not render when it is not first),
  so an unknown member could in principle break the tabs that matter. SC_SLED v1.0 already
  measured the blast radius of ONE unknown entity as ZERO -- the five still rendered, in order.
  Keeping them first and first-in-order preserves that property, and they double as the CONTROL:
  if the five do not render either, the probe itself is broken and its silence means nothing.

  WHY THESE CANDIDATES. [Likely] `targetEntity` binds the form to a record type RMS can store and
  display -- the five are the NCIC hot-file / RMS master types, and `_build_rms_bundle.ps1` defines
  targetEntity for only Vehicle and Person. If that is the mechanism, the other RMS record types
  are the plausible names, and `Organization` is the interesting one for SC: an administrative
  message is addressed to an ORI, which IS an organization. The rest are included because the cost
  of testing ten names is identical to testing one.

  ⚠️ AN IMPORT REPLACES THE BUNDLE SET. This config carries no provider bundle, so importing it
  REMOVES whatever provider is on that tenant. Use a throwaway/test tenant and re-import the real
  build afterwards. On usx-sc-sled that is `emit_import_job.ps1 -DeptId 73046844870` again.

  ⚠️ IT IS NOT A PROVIDER. It deliberately lives at providers\ENTITY_PROBE.json with no provider
  directory, so no gate treats it as one -- the same shape as TRANSLATE_TEST.json.

  Usage:
    .\tools\build_entity_probe.ps1
    .\tools\build_entity_probe.ps1 -Candidates 'Organization','Location'
#>
[CmdletBinding()]
param(
    [string[]]$Candidates = @(
        'Organization',           # an ORI is an organization -- the interesting one for SC
        'Location',
        'Incident',
        'Property',
        'Case',
        'Address',
        'Message',                # a generic messaging surface, if one exists
        'AdministrativeMessage'   # the one already REFUTED at SC_SLED v1.0 -- kept as a NEGATIVE
                                  # control: it must stay absent, or the v1.0 finding was wrong
    ),
    [string]$OutPath,

    # ROUND 2 -- THE BETTER-DESIGNED TEST. Rob, after round 1 returned "1-5 only appear":
    # "are you sure you are testing this correctly  i feel like 5 is arbitraty".
    #
    # He was right, and round 1 had TWO holes I did not control for:
    #   1. THE FIVE CONTROLS DO NOT CONTROL FOR THE HYPOTHESIS. They render because the platform
    #      ALREADY KNOWS them. That proves the import was processed; it says nothing about whether
    #      a correctly-configured NEW entity would fail.
    #   2. ROUND 1 GUESSED EIGHT NAMES and gave each only a QIF + a minimal QIDM. Real entities
    #      also carry RMS-side QIDMs (only Vehicle and Person have those) and a results layout.
    #      If a tab needs more than that, EVERY candidate fails REGARDLESS OF NAME -- and reading
    #      that as "the set is closed" is the too-narrow-detector trap (usx-tooling 8a).
    # So round 1 proved something much narrower than I claimed: those 8 names, configured that
    # way, do not render.
    #
    # -DuplicateEntityTest removes the guessing ENTIRELY. It declares the five known entities and
    # then THREE EXTRA QUERYINPUTFORMs that ALSO target `Person`, each with a distinct name and
    # label. Every value involved is one the platform demonstrably accepts, so a failure cannot be
    # blamed on an unknown name:
    #   HYPOTHESIS A -- tabs are keyed by ENTITY  -> ONE Person tab (extra forms merge or are
    #                                                dropped), and the tab count really is bounded
    #                                                by the entity set
    #   HYPOTHESIS B -- tabs are keyed by QIF     -> FOUR Person-ish tabs, and "more than 5 tabs"
    #                                                is available TODAY using known entity values
    # B is what Rob wants: a completely separate tab for the administrative message without
    # needing a new entity at all.
    # CLAUDE.md hints at B but does not settle it -- "QUERYINPUTFORM belongs ONLY in the ENTITIES
    # bundle. Adding it to any other bundle causes duplicate entity form CARDS." That is about a
    # form in the WRONG bundle producing cards; two forms in the RIGHT bundle targeting one entity
    # has never been tried.
    [switch]$DuplicateEntityTest
)

$ErrorActionPreference = 'Stop'
$toolDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $toolDir
. "$toolDir\_build_layout_helpers.ps1"
# _build_rms_bundle.ps1 FIRST: Build-ProviderQrdm (in the provider helpers) WRAPS
# Build-CommsysQrdm, which lives here. Omitting it left the provider bundle with no
# QUERYRESULTDATAMAPPING -- which the validator rejects -- while the file still got written,
# because Write-ProviderJson writes before it validates.
. "$toolDir\_build_rms_bundle.ps1"
. "$toolDir\_build_provider_helpers.ps1"

if (-not $OutPath) { $OutPath = Join-Path $repoRoot 'providers\ENTITY_PROBE.json' }
$providerName = 'ENTITY_PROBE'
$KNOWN5 = @('Person','Vehicle','Firearm','Article','Boat')

Write-Host ''
Write-Host '====================================================================================' -ForegroundColor Cyan
Write-Host '  ENTITY PROBE -- which targetEntity values does the platform actually render?' -ForegroundColor Cyan
Write-Host '====================================================================================' -ForegroundColor Cyan

# One form per entity. A single text control, LABELLED WITH THE ENTITY NAME so the rendered page
# is self-describing: whatever tab appears, its field says which candidate produced it.
function New-ProbeForm([string]$entity, [bool]$isControl, [string]$suffix) {
    $tag = ($entity -replace '[^A-Za-z0-9]', '') + $suffix
    $role = if ($isControl) { 'CONTROL -- this tab MUST appear' }
            elseif ($suffix) { "DUPLICATE-ENTITY CANDIDATE $suffix -- a SECOND form on Person; does it get its OWN tab?" }
            else { 'CANDIDATE -- does this tab appear?' }
    $layout = MakeLayouts @(
        @{
            id    = ('CARD_' + $tag)
            title = ('{0}  ({1})' -f $entity.ToUpper(), $role)
            rows  = @(
                @{ id = ('ROW_' + $tag); cols = @('12'); fields = @(
                    @{ id = ($tag + '_Input'); node = Inp ($tag + 'ProbeField') ("targetEntity = $entity") '30' ('ROW_' + $tag) }
                )}
            )
        }
    )
    return [PSCustomObject]@{
        description  = "Entity probe -- targetEntity='$entity'. $role"
        # A DISTINCT label on each duplicate: if tabs are keyed by QIF rather than by entity, the
        # caption is the thing that would tell them apart on screen.
        label        = $(if ($suffix) { "Person $suffix (dup-entity probe)" } else { $entity })
        layout       = $layout
        name         = ('ENTITY_' + $tag)
        type         = 'QUERYINPUTFORM'
        targetEntity = $entity
    }
}

# A minimal QIDM per entity so each form is a structurally complete configuration rather than an
# orphan -- an unwired form is a second variable, and this probe tests exactly one thing.
function New-ProbeQidm([string]$entity, [string]$suffix) {
    $tag = ($entity -replace '[^A-Za-z0-9]', '') + $suffix
    $attrs = @(Build-QidmAttribute -Name ($tag + 'ProbeField') -Size 30 -SourceField @($tag + 'ProbeField'))
    $combos = @(Build-QidmCombo -KeyReference ('PROBE' + $tag) -PrimaryFieldReference ($tag + 'ProbeField') -Set @($tag + 'ProbeField'))
    return Build-Qidm -ProviderName $providerName -Query ($tag + 'ProbeQuery') `
        -TargetEntity $entity -QueryLabel ("Probe $entity") `
        -Attributes $attrs -Combinations $combos `
        -Description "Entity probe QIDM for targetEntity='$entity'. Throwaway."
}

$all = @()
foreach ($e in $KNOWN5) { $all += [pscustomobject]@{ Entity = $e; Control = $true; Suffix = '' } }

if ($DuplicateEntityTest) {
    # THREE extra forms, all targeting `Person` -- a value the platform demonstrably accepts, so a
    # failure here cannot be blamed on an unknown name. Distinct `name` and `label` on each.
    foreach ($s in @('Alpha','Bravo','Charlie')) {
        $all += [pscustomobject]@{ Entity = 'Person'; Control = $false; Suffix = $s }
    }
} else {
    foreach ($e in $Candidates) {
        if ($KNOWN5 -contains $e) { Write-Host ("  [skip] '$e' is one of the five -- already a control") -ForegroundColor DarkGray; continue }
        $all += [pscustomobject]@{ Entity = $e; Control = $false; Suffix = '' }
    }
}

$forms = @(); $qidms = @()
foreach ($row in $all) {
    $forms += New-ProbeForm $row.Entity $row.Control $row.Suffix
    $qidms += New-ProbeQidm $row.Entity $row.Suffix
}

# CONTROLS FIRST in every order array -- preserves the zero-blast-radius property measured at
# SC_SLED v1.0, where the five rendered correctly despite a sixth unknown member being present.
# In -DuplicateEntityTest this deliberately lists `Person` FOUR TIMES. The order array names
# ENTITIES, so if the platform de-duplicates it we learn that too -- and if tabs turn out to be
# keyed by QIF rather than by this array, the duplicates are harmless either way. Listing each
# form's entity once per form is the honest attempt; silently de-duplicating it here would be me
# pre-deciding the answer.
$order = @($all | ForEach-Object { $_.Entity })

$entitiesBundle = Build-EntitiesBundle -Configurations $forms `
    -DefaultOrder $order -CadOrder $order -FrOrder $order

# `type = 'BUNDLE'` is REQUIRED. Omitting it gave two validator FAILs at once -- "Bundle
# 'ENTITY_PROBE' missing 'type' property" AND "No provider bundle found", because the
# provider-bundle detector keys off the type. Build-EntitiesBundle sets it for you; a hand-rolled
# bundle has to say it.
$cfgs = New-Object System.Collections.Generic.List[object]
$cfgs.Add((Build-Auth        -ProviderName $providerName))
$cfgs.Add((Build-Qmf         -ProviderName $providerName))
$cfgs.Add((Build-ProviderQrdm -ProviderName $providerName))
foreach ($q in $qidms) { $cfgs.Add($q) }
# .ToArray(), never @($list) -- @() on a List[object] THROWS ArgumentException, even when empty
# (usx-tooling: it once impersonated a refusal guard and made two LAW-2 cases "pass" wrongly).
$cfgs = $cfgs.ToArray()

$providerBundle = [PSCustomObject]@{
    name           = $providerName
    type           = 'BUNDLE'
    provider       = $providerName
    description    = "Provider configuration for $providerName v1.0 -- THROWAWAY ENTITY PROBE. Declares $($all.Count) QUERYINPUTFORMs: $($KNOWN5.Count) controls that MUST render and $(@($all | Where-Object { -not $_.Control }).Count) candidates under test. Import, then READ THE TABS."
    # A QUERYRESULTDATAMAPPING is MANDATORY -- the validator refuses a provider bundle without one.
    # Worth noting for the question this probe exists to answer: the platform requires every
    # provider bundle to declare how RESULTS map back, which is consistent with [Likely]
    # targetEntity binding to a record type the platform can store and display.
    # Built by explicit Add rather than an array literal. `@(@(Build-Auth ...), ...)` produced a
    # configuration with a BLANK `type` -- the nested @() became one element instead of flattening
    # -- and a blank-typed config is invisible to every type-keyed check in the validator.
    configurations = $cfgs
}

$bundleObject = [PSCustomObject]@{ bundles = @($entitiesBundle, $providerBundle) }

Write-Host ''
Write-Host ('  controls  : {0}' -f (($KNOWN5) -join ', ')) -ForegroundColor Green
Write-Host ('  candidates: {0}' -f ((@($all | Where-Object { -not $_.Control } | ForEach-Object { $_.Entity })) -join ', ')) -ForegroundColor Yellow
Write-Host ('  order     : {0}' -f ($order -join ' > ')) -ForegroundColor DarkGray
Write-Host ''
Write-Host '  HOW TO READ THE RESULT:' -ForegroundColor Cyan
Write-Host '    every candidate whose TAB APPEARS is a usable targetEntity.' -ForegroundColor Gray
Write-Host '    AdministrativeMessage is the NEGATIVE control -- it must stay ABSENT.' -ForegroundColor Gray
Write-Host '    if the five CONTROLS do not render, the probe is broken and proves nothing.' -ForegroundColor Gray
Write-Host ''

Write-ProviderJson -BundleObject $bundleObject -OutPath $OutPath -Label 'ENTITY_PROBE'
