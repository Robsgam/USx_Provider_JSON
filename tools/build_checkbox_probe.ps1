<#
  build_checkbox_probe.ps1 -- WHAT CREATES, AND WHAT REMOVES, A QUERY CHECKBOX?

  WHY THIS EXISTS. Rob, 2026-09-18: "did we probe the checkbox creation mechnism  were you
  gusing at naming values". The honest answers were NO and MOSTLY-NO:
    - We READ the shipping federatedSearch bundle (captured read-only, 29 files / 3.67 MB) and
      derived the rule from source. That is evidence, but it is STATIC ANALYSIS -- not one
      checkbox claim has ever been MEASURED against a config we controlled.
    - The names are not invented: `enabled`, `order`, `queryableEntityType` are literal
      identifiers from that bundle, and `Other` came from the enum `ut` and was CONFIRMED LIVE
      (6 tabs, 2026-09-18). What is NOT established is whether the IMPORTER carries `enabled`
      and `order` from our JSON through to the model the client reads. The client consuming a
      field says nothing about the config pipeline emitting it.

  WHAT THE SOURCE SAYS, so the predictions below are falsifiable:
      tabs       queryForms.filter(te => te.enabled && d.includes(te.queryableEntityType))
      checkboxes RS(t)= t.filter(e=>e.enabled).map(e=>({...queries:(e.queries||[]).filter(n=>n.enabled)}))
      autoSelect CS(t)= queries.filter(n => n.autoSelect === false)   // PRE-DESELECT, never remove
      tab order  sortBy(t, e => [ e.order ?? MAX_SAFE_INTEGER, RC.indexOf(e.queryableEntityType) ])
      the list   GET fetch_validation_requirements/{queryableEntityType}   <- PER ENTITY, not per form

  THE FOUR QUESTIONS, all on entity `Other` so no real entity is disturbed:

    Q1  DOES THE DEFECT REPRODUCE?  Two forms share `Other`. CB_CONTROL requires FieldA, which
        exists only on form A. PREDICTED: its checkbox appears on BOTH tabs, dead on B. If it
        does not appear on B, the per-entity rule is wrong and everything else is rewritten.
        This is the CONTROL -- without it a null result elsewhere means nothing.

    Q2  DOES `enabled:false` REMOVE A CHECKBOX?  CB_DISABLED is identical to CB_CONTROL plus
        enabled:false. PREDICTED (if the importer carries it): absent from BOTH tabs. If it
        still appears, the importer drops the field and this lever is unreachable from config.

    Q3  IS `autoSelect:false` DIFFERENT FROM `enabled:false`?  CB_AUTOFALSE should still RENDER,
        merely unchecked. This separates "not selected" from "not present" -- a distinction
        every earlier discussion in this repo conflated, including SC_SLED's stolen-query note.

    Q4  DOES A SECOND PROVIDER BUNDLE SCOPE ANYTHING?  CB_SECOND lives in its own provider
        bundle. The admin UI has "Link forms to interface -- the following query forms can be
        sent to this interface", so linkage exists SOMEWHERE; this asks whether a second
        provider alone changes what a tab shows, before touching admin settings.

  ALSO CARRIED: `order` on both forms (form A order 2, form B order 1) -- if tab order flips,
  `order` is honoured by the importer and SC_SLED's host-entity juggling for tab placement can
  be retired.

  ⚠️ THROWAWAY RIG, NOT A PROVIDER. Hand-import only; the deploy path and bridge refuse it, the
  same as MULTILINE_TEST and ENTITY_PROBE. AN IMPORT REPLACES THE BUNDLE SET -- put the real
  build back afterwards.

  Usage: .\tools\build_checkbox_probe.ps1 [-Entity Other] [-OutPath ...]
#>
[CmdletBinding()]
param(
    [string]$Entity = 'Other',
    [string]$OutPath
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = Split-Path -Parent $toolDir
. "$toolDir\_build_layout_helpers.ps1"
. "$toolDir\_build_rms_bundle.ps1"
. "$toolDir\_build_provider_helpers.ps1"

$provName = 'CHECKBOX_PROBE'
Write-Host ''
Write-Host '====================================================================================' -ForegroundColor Cyan
Write-Host '  CHECKBOX PROBE -- what creates, and what removes, a query checkbox?' -ForegroundColor Cyan
Write-Host '====================================================================================' -ForegroundColor Cyan

# ---- two forms, ONE shared entity -- that is the whole point ------------------------------------
function New-ProbeForm([string]$tag, [string]$label, [string]$fieldId, [int]$order) {
    $layout = MakeLayouts @(
        @{
            id    = "CARD_$tag"
            title = "$label -- probe"
            rows  = @(
                @{ id = "ROW_$tag"; cols = @('12'); fields = @(
                    @{ id = "${fieldId}_Input"; node = Inp $fieldId $fieldId '20' "ROW_$tag" }
                )}
            )
        }
    )
    # `order` is emitted DELIBERATELY even though no provider emits it -- Q5. If the importer
    # strips it the tabs keep entity order and we learn that in the same import.
    [PSCustomObject]@{
        description  = "Checkbox probe form $label on targetEntity=$Entity. Throwaway."
        label        = $label
        layout       = $layout
        name         = "ENTITY_$tag"
        order        = $order
        type         = 'QUERYINPUTFORM'
        targetEntity = $Entity
    }
}

$formA = New-ProbeForm 'CBA' 'CB A (has FieldA)' 'FieldA' 2
$formB = New-ProbeForm 'CBB' 'CB B (has FieldB)' 'FieldB' 1

# ---- the four QIDMs, all on the SAME entity -----------------------------------------------------
function New-ProbeQidm([string]$name, [string]$field, [hashtable]$extra) {
    $q = Build-Qidm -ProviderName $provName -Query $name -TargetEntity $Entity -QueryLabel $name `
        -Attributes @( Build-QidmAttribute -Name $field -Size 20 -SourceField @($field) ) `
        -Combinations @( Build-QidmCombo -KeyReference "K$name" -PrimaryFieldReference $field -Set @($field) ) `
        -Description "Checkbox probe QIDM $name. Throwaway."
    foreach ($k in $extra.Keys) { $q | Add-Member -NotePropertyName $k -NotePropertyValue $extra[$k] -Force }
    return $q
}

$qControl  = New-ProbeQidm 'CBControl'  'FieldA' @{}
$qDisabled = New-ProbeQidm 'CBDisabled' 'FieldA' @{ enabled = $false }
$qAutoOff  = New-ProbeQidm 'CBAutoOff'  'FieldA' @{ autoSelect = $false }
$qSecond   = New-ProbeQidm 'CBSecond'   'FieldB' @{}

$entityOrder = @($Entity)
$entitiesBundle = Build-EntitiesBundle -Configurations @($formA, $formB) `
    -DefaultOrder $entityOrder -CadOrder $entityOrder -FrOrder $entityOrder

$auth = Build-Auth       -ProviderName $provName
$qmf  = Build-Qmf        -ProviderName $provName
$qrdm = Build-ProviderQrdm -ProviderName $provName

$providerBundle = [PSCustomObject]@{
    configurations = @($auth, $qmf, $qrdm, $qControl, $qDisabled, $qAutoOff)
    description    = "Checkbox probe -- primary interface. THROWAWAY RIG, not a provider."
    name           = $provName
    type           = 'BUNDLE'
    provider       = $provName
}

# Q4 -- a SECOND provider bundle. RMS proves multi-provider bundles are normal.
$prov2 = "${provName}_SECOND"
$providerBundle2 = [PSCustomObject]@{
    configurations = @((Build-Auth -ProviderName $prov2), (Build-Qmf -ProviderName $prov2),
                       (Build-ProviderQrdm -ProviderName $prov2), $qSecond)
    description    = "Checkbox probe -- SECOND interface, to test whether provider identity scopes a tab."
    name           = $prov2
    type           = 'BUNDLE'
    provider       = $prov2
}

$bundle = [PSCustomObject]@{ bundles = @($entitiesBundle, $providerBundle, $providerBundle2) }

if (-not $OutPath) { $OutPath = Join-Path $repoRoot 'providers\CHECKBOX_PROBE.json' }

Write-Host ''
Write-Host "  entity (shared by BOTH forms): $Entity" -ForegroundColor Gray
Write-Host '  form A "CB A" order=2  field FieldA     form B "CB B" order=1  field FieldB' -ForegroundColor Gray
Write-Host ''
Write-Host '  HOW TO READ THE RESULT -- look at BOTH tabs and list the checkboxes on each:' -ForegroundColor Yellow
Write-Host '    CBControl  on BOTH tabs      -> per-entity rule CONFIRMED (dead on CB B). If absent' -ForegroundColor Gray
Write-Host '                                    from CB B, the whole model is wrong -- say so loudly.' -ForegroundColor Gray
Write-Host '    CBDisabled ABSENT everywhere -> `enabled:false` SURVIVES THE IMPORT = the removal lever.' -ForegroundColor Gray
Write-Host '               PRESENT           -> importer strips it; unreachable from config.' -ForegroundColor Gray
Write-Host '    CBAutoOff  PRESENT, unticked -> autoSelect only pre-deselects (never removes).' -ForegroundColor Gray
Write-Host '    CBSecond   on BOTH tabs      -> provider identity does NOT scope; linkage must be admin-side.' -ForegroundColor Gray
Write-Host '               on CB B only      -> PROVIDER BUNDLE SCOPES THE TAB = 7 clean tabs from config.' -ForegroundColor Gray
Write-Host '    tab order  CB B before CB A  -> `order` is honoured; the host-entity juggling can go.' -ForegroundColor Gray
Write-Host ''

Write-ProviderJson -BundleObject $bundle -OutPath $OutPath -Label "$provName (throwaway rig)"
