<#
  build_multiline_test.ps1 -- CAN A FORM CONTROL SHOW MORE THAN ONE LINE OF TEXT?

  WHY THIS EXISTS. Rob 2026-09-17: "on admi  can we make the text line multirow like a box for
  text", then "the admin message line still looks the same", then "can you investigate this
  capability?", then -- after the investigation came back negative -- "The probe import lets try
  that". SC_SLED's AdministrativeMessage carries a 501-character message in a ONE-LINE box.

  WHAT THE INVESTIGATION ALREADY ESTABLISHED, so this probe does not re-ask it (LIMITATION #48):
  four independent sources say no multi-line control is reachable from the JSON --
    1. our 21 builds: 9 component types, a FormInput carrying only fieldId/label/maxLength/initialValue
    2. 66 tenant configs INCLUDING NOT-OUR-BUILD: 7,414 control nodes, 19 props, no multiline
    3. Confluence "Forge -> M43Forms Migration Guide" §3 -- maps 7 Forge component types, no textarea
    4. Confluence "Federated Search JSON Configuration Capabilities" (RND/6397788223) -- the
       capability doc, with explicit Not-Supported sections
  BUT THREE OF THOSE FOUR ARE USAGE CENSUSES, and the migration guide SAYS SO outright ("only
  covers the Forge component types and props that are in use today"). Source 4 is a genuine
  capability statement but was last modified 2026-02-27. So the honest status is "unreachable per
  the documented surface, and nobody has ever shipped one" -- NOT "Forge contains no such
  component". A probe closes that gap; nothing else in reach does.

  ============================================================================================
  THE TWO HALVES HAVE VERY DIFFERENT RISK, AND THE LAYOUT REFLECTS THAT
  ============================================================================================

  HALF A -- CANDIDATE PROPS ON A KNOWN-GOOD `FormInput`. ZERO RISK. `FormInput` is a component the
  renderer certainly resolves; an unrecognised PROP is ignored (that is how `codeTypeProvider`
  sits harmlessly on controls that do not use it). Worst case the field renders as a normal single
  line and we learn the prop is dead. All of these live together on the CONTROL tab.

  HALF B -- CANDIDATE COMPONENT NAMES. REAL RISK, AND IT IS STATED RATHER THAN DISCOVERED: an
  unresolved `resolvedName` in a Craft.js node tree is not guaranteed to degrade to "nothing
  rendered". It may THROW while deserializing the tree and take the whole form down. That is a
  DIFFERENT failure from SC_SLED v1.0's unknown targetEntity, which was measured to be harmless
  (the five known entities still rendered). No such measurement exists for an unknown COMPONENT.
  So each candidate component gets ITS OWN QUERYINPUTFORM, which makes the blast radius readable:

      tab present, BOTH fields render          -> the component RESOLVES. Look at its shape.
      tab present, only the companion renders  -> the component is IGNORED/unknown, non-fatal
      tab MISSING, others fine                 -> that component is fatal to its own form
      NO tabs at all                           -> an unknown component is fatal to the whole
                                                  module. Blunt, but a real and useful finding:
                                                  never risk an unknown resolvedName in a build.

  THE CONTROL TAB IS FIRST IN THE ORDER ARRAYS on purpose -- same reasoning as build_entity_probe:
  if the control tab does not render, the probe is broken and its silence means NOTHING.

  ============================================================================================
  WHY THESE CANDIDATES -- derived, not guessed at random
  ============================================================================================
  Forge's QIF components all read `Form<Thing>`: FormInput, FormSelect, FormDate, FormCheckbox,
  FormRadioGroup. So the sibling names are the first candidates, INCLUDING A CASING VARIANT
  because a resolver lookup is exact-match and `FormTextArea` vs `FormTextarea` is exactly the
  kind of difference that decides it.
  Two candidates are deliberately NOT of that shape:
    * `TextArea`  -- unprefixed, because the QUERYRESULTSLAYOUT components in the SAME tenant
                     configs carry NO prefix at all (Box, Br, Text, Image, KeyValue, DataList).
                     The `Form` prefix may be a QIF convention rather than a platform one.
    * `Text`      -- it PROVABLY EXISTS in QUERYRESULTSLAYOUT (measured: 2 nodes across the 66
                     configs). This tests whether the two resolvers share one registry, and it is
                     the most valuable candidate for a reason beyond multiline: if `Text` renders
                     inside a QIF we gain a HELP-TEXT CHANNEL ON THE FORM, which the capability
                     doc states outright does not exist ("Custom validation messages NOT supported
                     -- errorMessage, helpText, tooltip"). That would be worth more than the
                     textarea.

  ⚠️ AN IMPORT REPLACES THE BUNDLE SET. This config carries no real provider, so importing it
  REMOVES SC_SLED from usx-sc-sled. That tenant has never been swept and holds nothing precious,
  but the real build must go back afterwards: `emit_import_job.ps1 -DeptId 73046844870`.

  ⚠️ IT IS NOT A PROVIDER. It lives at providers\MULTILINE_TEST.json with no provider directory,
  so no gate treats it as one -- same shape as ENTITY_PROBE.json and TRANSLATE_TEST.json.

  Usage:
    .\tools\build_multiline_test.ps1
    .\tools\build_multiline_test.ps1 -Components 'FormTextArea','Text'
#>
[CmdletBinding()]
param(
    # HALF B -- one QUERYINPUTFORM each. Order here is the order of the tabs after the control.
    [string[]]$Components = @(
        'FormTextArea',        # the Form<Thing> convention + the Form.io/React spelling
        'FormTextarea',        # casing variant -- resolver lookups are exact-match
        'FormMultilineInput',  # descriptive variant
        'FormLongText',        # descriptive variant
        'TextArea',            # UNPREFIXED -- results-layout components carry no prefix
        'Text'                 # PROVABLY exists in QUERYRESULTSLAYOUT; tests a shared registry,
                               # and would give us a help-text channel the capability doc denies
    ),
    # HALF A -- candidate props applied to a known-good FormInput. All on the CONTROL tab, all
    # zero-risk. Value is a string where the platform's own convention is stringy (maxLength is
    # "30", not 30) except the boolean-looking one, which is sent as a real boolean like `hidden`.
    [string]$OutPath,

    # ROUND 2 -- DOES THE VALUE REACH THE WIRE? Added 2026-09-17 after round 1 answered the
    # RENDER question (CAPABILITY #48: `FormTextarea` resolves). Round 1 deliberately wired only
    # the COMPANION, because a component that might not be an input at all has no business in a
    # combination -- so it proved the box EXISTS and nothing about whether typing in it transmits.
    # A control that renders beautifully and silently discards officer input is the exact defect
    # class audit_wiring_closure exists to catch, so this must be measured before the component
    # goes anywhere near a real provider.
    #
    # ⚠️ THE CANDIDATE GOES IN any[], NOT set[], AND THAT IS THE WHOLE DESIGN. If it were in
    # set[] and its value never registered in form state, SEND WOULD STAY DISABLED and the result
    # would be ambiguous -- "the control does not transmit" and "the control does not register"
    # would look identical (the CA_eSUN autoSelect=$false failure shape, where Send stayed
    # disabled and told us nothing). With the COMPANION alone in set[], Send is guaranteed to
    # enable, the query is guaranteed to go out, and the wire XML then answers cleanly:
    #     candidate tag present with the typed text -> IT TRANSMITS
    #     companion tag only                        -> it renders and DISCARDS input
    # any[] membership is what feeds a field onto the wire (the same mechanism that makes the
    # Attention auto-handler work on HI/AZ: any[] membership alone, no set[] and no prefill).
    #
    # THE SECOND QUESTION THIS ANSWERS, and it is the one that can still kill the component for
    # the AdministrativeMessage use case: DOES A NEWLINE SURVIVE? The officer's line breaks are
    # the entire point of a textarea. They may pass through, collapse to spaces, or break the XML.
    [switch]$Wire
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = Split-Path -Parent $toolDir
. "$toolDir\_build_layout_helpers.ps1"
# _build_rms_bundle.ps1 BEFORE the provider helpers: Build-ProviderQrdm wraps Build-CommsysQrdm,
# which lives in the RMS module. Omitting it leaves the provider bundle with no
# QUERYRESULTDATAMAPPING, which the validator rejects -- AFTER Write-ProviderJson has already
# written the file. (Learned on build_entity_probe.)
. "$toolDir\_build_rms_bundle.ps1"
. "$toolDir\_build_provider_helpers.ps1"

if (-not $OutPath) { $OutPath = Join-Path $repoRoot 'providers\MULTILINE_TEST.json' }
$providerName = 'MULTILINE_TEST'
# Known-good entity values only. An unknown targetEntity would add a SECOND variable and this
# probe tests exactly one thing (build_entity_probe already measured that axis).
$KNOWN5 = @('Person','Vehicle','Firearm','Article','Boat')

Write-Host ''
Write-Host '====================================================================================' -ForegroundColor Cyan
Write-Host '  MULTILINE PROBE -- can any control render more than one line of text?' -ForegroundColor Cyan
Write-Host '====================================================================================' -ForegroundColor Cyan

# ---- HALF A: the control tab -------------------------------------------------------------------
# A baseline FormInput plus one FormInput per candidate prop. Every label states what it tests, so
# the rendered page is self-describing and Rob can read the answer off the screen without a key.
$propCandidates = @(
    @{ Tag = 'Baseline';  Extra = @{};                         Label = 'BASELINE plain FormInput -- must render, 1 line' }
    @{ Tag = 'Multiline'; Extra = @{ multiline = $true };      Label = 'prop multiline=true -- taller?' }
    @{ Tag = 'Rows';      Extra = @{ rows = '4' };             Label = 'prop rows=4 -- taller?' }
    @{ Tag = 'TypeTa';    Extra = @{ type = 'textarea' };      Label = 'prop type=textarea -- taller?' }
    @{ Tag = 'NumLines';  Extra = @{ numberOfLines = '4' };    Label = 'prop numberOfLines=4 -- taller?' }
    @{ Tag = 'MaxRows';   Extra = @{ maxRows = '4' };          Label = 'prop maxRows=4 -- taller?' }
)

# ONE FIELD PER ROW, each at full width. Deliberate: `templateColumns` length IS the column count,
# so putting two fields under a single '12' column is malformed -- and a malformed row could
# suppress a render on its own, confounding the very thing being measured. Full width also makes a
# height difference between boxes obvious at a glance, which is the entire read-out of half A.
$rows = @()
$i = 0
foreach ($p in $propCandidates) {
    $rid = 'ROW_CTRL' + $i
    $fid = 'MlProp' + $p.Tag
    $rows += @{ id = $rid; cols = @('12'); fields = @(
        @{ id = ($fid + '_Input'); node = Inp $fid $p.Label '501' $rid $p.Extra }
    )}
    $i++
}
$controlLayout = MakeLayouts @(
    @{
        id    = 'CARD_CTRL'
        title = 'CONTROL TAB -- all known-good FormInputs. THIS TAB MUST RENDER or the probe proves nothing. Each label names the prop it carries; any box TALLER than the baseline means that prop works.'
        rows  = $rows
    }
)

$forms = @()
$qidms = @()

$forms += [PSCustomObject]@{
    description  = 'MULTILINE PROBE control tab. Six known-good FormInputs: a baseline plus five candidate PROPS (multiline, rows, type=textarea, numberOfLines, maxRows). Zero risk -- an unrecognised prop is ignored, so the worst case is six identical single-line boxes. If this tab is absent the probe is broken and every other result is meaningless.'
    label        = '0 CONTROL (props)'
    layout       = $controlLayout
    name         = 'ENTITY_MlControl'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}
$ctrlAttrs  = @(Build-QidmAttribute -Name 'MlPropBaseline' -Size 501 -SourceField @('MlPropBaseline'))
$ctrlCombos = @(Build-QidmCombo -KeyReference 'MLCTRL' -PrimaryFieldReference 'MlPropBaseline' -Set @('MlPropBaseline'))
$qidms += Build-Qidm -ProviderName $providerName -Query 'MlControlQuery' `
    -TargetEntity 'Person' -QueryLabel 'Probe Control' `
    -Attributes $ctrlAttrs -Combinations $ctrlCombos `
    -Description 'Throwaway QIDM so the control form is a complete configuration rather than an orphan.'

# ---- HALF B: one tab per candidate component ---------------------------------------------------
# Each tab carries the CANDIDATE plus a known-good COMPANION FormInput. The companion is what makes
# the result readable: candidate-missing-but-companion-present means "ignored", whereas the whole
# tab missing means "fatal to this form".
$n = 0
foreach ($c in $Components) {
    # ⚠️ INDEX-PREFIXED, AND THE VALIDATOR IS WHY. The whole point of testing both `FormTextArea`
    # and `FormTextarea` is that a resolver lookup is exact-match on casing -- but a tag derived
    # only from the name collides between those two under a case-INSENSITIVE comparison, and
    # validate.ps1 refused the file: "duplicate QIF name 'ENTITY_MlFormTextarea' -- second
    # silently overwrites first at import". Had it not, the probe would have tested ONE casing
    # while I reported two, which is the inert-test class: a result that looks like an answer and
    # exercised nothing. The candidate NAME still goes in the label and the resolvedName verbatim;
    # only the internal identifier is disambiguated.
    $tag = ('C{0}{1}' -f $n, ($c -replace '[^A-Za-z0-9]', ''))
    $ent = $KNOWN5[($n % $KNOWN5.Count)]
    $rid = 'ROW_' + $tag
    $companionFid = 'MlComp' + $tag
    $candidateFid = 'MlCand' + $tag

    # The candidate node, hand-built because the layout helpers only emit known component types.
    # Same prop shape a FormInput uses, so if the component IS an input it has everything it needs.
    $candNode = [PSCustomObject]@{
        type       = [PSCustomObject]@{ resolvedName = $c }
        isCanvas   = $false
        props      = [PSCustomObject]@{
            fieldId   = $candidateFid
            label     = if ($Wire) {
                            ("WIRE TEST -- type 3 SHORT LINES here and press ENTER between them, then fill the companion and send. resolvedName='{0}'" -f $c)
                        } else {
                            ("CANDIDATE resolvedName='{0}' -- if you can see this box, the component RESOLVES" -f $c)
                        }
            maxLength = '501'
        }
        displayName = $c
        custom      = [PSCustomObject]@{}
        parent      = $rid
        hidden      = $false
        nodes       = @()
        linkedNodes = [PSCustomObject]@{}
    }

    $layout = MakeLayouts @(
        @{
            id    = ('CARD_' + $tag)
            title = ("CANDIDATE: {0}   --   the FIRST box is a known-good FormInput (companion). The SECOND is the candidate. Companion alone = component IGNORED. Whole tab missing = component FATAL." -f $c)
            rows  = @(
                @{ id = $rid; cols = @('6','6'); fields = @(
                    @{ id = ($companionFid + '_Input'); node = Inp $companionFid ("COMPANION -- known-good, must render (tab for {0})" -f $c) '30' $rid }
                    @{ id = ($candidateFid + '_Input'); node = $candNode }
                )}
            )
        }
    )

    $forms += [PSCustomObject]@{
        description  = ("MULTILINE PROBE candidate -- resolvedName='{0}' on targetEntity='{1}'. Carries a known-good companion FormInput so 'component ignored' can be told from 'form died'." -f $c, $ent)
        label        = ('{0} {1}' -f ($n + 1), $c)
        layout       = $layout
        name         = ('ENTITY_Ml' + $tag)
        type         = 'QUERYINPUTFORM'
        targetEntity = $ent
    }

    $attrs  = @(Build-QidmAttribute -Name $companionFid -Size 30 -SourceField @($companionFid))
    $combos = @(Build-QidmCombo -KeyReference ('ML' + $tag.ToUpper()) -PrimaryFieldReference $companionFid -Set @($companionFid))
    $qidmDesc = ("Throwaway QIDM for the '{0}' candidate form. Wires the COMPANION only -- the candidate may not be an input at all." -f $c)
    if ($Wire) {
        # Candidate in any[], companion alone in set[] -- see the -Wire parameter comment for why
        # set[] would make a non-registering control indistinguishable from a non-transmitting one.
        $attrs += Build-QidmAttribute -Name $candidateFid -Size 501 -SourceField @($candidateFid)
        $combos = @(Build-QidmCombo -KeyReference ('ML' + $tag.ToUpper()) `
            -PrimaryFieldReference $companionFid -Set @($companionFid) -Any @($candidateFid))
        $qidmDesc = ("WIRE TEST QIDM for '{0}'. Companion in set[] guarantees Send enables; the CANDIDATE is in any[] so the wire XML shows whether its typed value -- newlines included -- reaches CommSys. Candidate tag present = it transmits; companion tag only = it renders and discards input." -f $c)
    }
    $qidms += Build-Qidm -ProviderName $providerName -Query ($tag + 'ProbeQuery') `
        -TargetEntity $ent -QueryLabel ("Probe $c") `
        -Attributes $attrs -Combinations $combos `
        -Description $qidmDesc
    $n++
}

# CONTROL FIRST in every order array. Same-entity forms render adjacent in configurations order
# (CAPABILITY #47 + the SC_SLED v1.8 tab-order measurement), and the control is on Person which is
# listed first, so it is the leftmost tab.
#
# ⚠️ DERIVED FROM THE FORMS ACTUALLY EMITTED, not hardcoded to KNOWN5 -- and the validator is why.
# The first version listed all five entities unconditionally, which is fine for the default 6
# candidates (they cycle through every entity) but FAILS the moment you ask for a subset:
# `-Components FormTextarea -Wire` emits Person forms only, and validate.ps1 correctly refused
# with 4 x "Entity 'X' in order array but no QIF has targetEntity='X'". An order array naming an
# entity with no form is a dangling reference, and round 2 is precisely a one-candidate run -- so
# the bug was latent from the moment the -Components parameter existed and surfaced on first use.
$used  = @($forms | ForEach-Object { $_.targetEntity } | Select-Object -Unique)
$order = @('Person') + @($KNOWN5 | Where-Object { $_ -ne 'Person' -and $used -contains $_ })
$order = @($order | Where-Object { $used -contains $_ })

$entitiesBundle = Build-EntitiesBundle -Configurations $forms `
    -DefaultOrder $order -CadOrder $order -FrOrder $order

$cfgs = New-Object System.Collections.Generic.List[object]
$cfgs.Add((Build-Auth         -ProviderName $providerName))
$cfgs.Add((Build-Qmf          -ProviderName $providerName))
$cfgs.Add((Build-ProviderQrdm -ProviderName $providerName))
foreach ($q in $qidms) { $cfgs.Add($q) }
# .ToArray(), never @($list) -- @() on a List[object] THROWS "Argument types do not match" on
# PowerShell 5.1, which is the engine that runs these tools.
$cfgs = $cfgs.ToArray()

$providerBundle = [PSCustomObject]@{
    name           = $providerName
    type           = 'BUNDLE'   # REQUIRED -- the provider-bundle detector keys off it
    provider       = $providerName
    description    = if ($Wire) {
        "Provider configuration for $providerName v1.1 -- THROWAWAY MULTILINE WIRE TEST. Round 1 proved FormTextarea RENDERS (CAPABILITY #48); this round asks whether a typed value -- newlines included -- REACHES THE WIRE. Candidate in any[], companion in set[]. Import, fill both boxes with the candidate on 3 lines, send, then READ THE OUTGOING XML in dex-log."
    } else {
        "Provider configuration for $providerName v1.0 -- THROWAWAY MULTILINE PROBE. 1 control form carrying $($propCandidates.Count) candidate PROPS plus $($Components.Count) candidate COMPONENTS, one form each. Import, then READ THE TABS AND THE BOX HEIGHTS."
    }
    configurations = $cfgs
}

$bundleObject = [PSCustomObject]@{ bundles = @($entitiesBundle, $providerBundle) }

Write-Host ''
Write-Host ('  control tab props : {0}' -f (($propCandidates | ForEach-Object { $_.Tag }) -join ', ')) -ForegroundColor Green
Write-Host ('  candidate components: {0}' -f ($Components -join ', ')) -ForegroundColor Yellow
Write-Host ('  forms emitted     : {0} ({1} tabs expected)' -f $forms.Count, $forms.Count) -ForegroundColor DarkGray
Write-Host ''
if ($Wire) {
    Write-Host '  ROUND 2 -- WIRE TEST. The RENDER question is already answered (CAPABILITY #48).' -ForegroundColor Cyan
    Write-Host '  HOW TO RUN IT:' -ForegroundColor Cyan
    Write-Host '    1. Open the candidate tab. Type 3 SHORT LINES in the big box, ENTER between them.' -ForegroundColor Gray
    Write-Host '    2. Fill the COMPANION box too -- it is the set[] field, and it is what enables Send.' -ForegroundColor Gray
    Write-Host '    3. Send, then open the outgoing XML in dex-log.' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  HOW TO READ THE RESULT:' -ForegroundColor Cyan
    Write-Host '    candidate tag present, line breaks intact  = IT TRANSMITS, newlines survive. DONE.' -ForegroundColor Gray
    Write-Host '    candidate tag present, text run together   = transmits, newlines COLLAPSED (still' -ForegroundColor Gray
    Write-Host '                                                 a better box, but not a better message).' -ForegroundColor Gray
    Write-Host '    COMPANION tag only                         = it renders and DISCARDS officer input.' -ForegroundColor Gray
    Write-Host '                                                 Do NOT ship it. audit_wiring_closure class.' -ForegroundColor Gray
    Write-Host '    SEND stays disabled                        = unexpected -- the companion alone is the' -ForegroundColor Gray
    Write-Host '                                                 set[] field, so this means the candidate' -ForegroundColor Gray
    Write-Host '                                                 control interferes with form state. Say so.' -ForegroundColor Gray
} else {
    Write-Host '  HOW TO READ THE RESULT:' -ForegroundColor Cyan
    Write-Host '    TAB 0 CONTROL must render. If it does not, the probe is broken -- ignore everything else.' -ForegroundColor Gray
    Write-Host '    On tab 0, any box TALLER than the baseline = that PROP works (zero-risk half).' -ForegroundColor Gray
    Write-Host '    Candidate tab with BOTH boxes  = that component RESOLVES.' -ForegroundColor Gray
    Write-Host '    Candidate tab with ONE box     = component ignored, harmless.' -ForegroundColor Gray
    Write-Host '    Candidate tab MISSING          = that component is fatal to its own form.' -ForegroundColor Gray
    Write-Host '    NO TABS AT ALL                 = an unknown component is fatal module-wide.' -ForegroundColor Gray
}
Write-Host ''
Write-Host '  !! AN IMPORT REPLACES THE BUNDLE SET -- this REMOVES SC_SLED from the tenant.' -ForegroundColor Red
Write-Host '     Put the real build back afterwards: emit_import_job.ps1 -DeptId 73046844870' -ForegroundColor Red
Write-Host ''

Write-ProviderJson -BundleObject $bundleObject -OutPath $OutPath -Label 'MULTILINE_TEST'
