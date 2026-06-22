# build_hi_hcjdc_ofml.ps1  -- HI_HCJDC_OFML canonical build (single JSON, multi-card)
# Builds HI_HCJDC_OFML.json from source\HI_HCJDC_OFML.xml + KB specs.
# v3.6 (2026-06-22): Plate-wins guardrail + vehicleYear any[] gap fix.
#   PLATE-WINS: Added LicensePlateNumber NOT_EXISTS condition to RQV, QVV, M55S. When
#   Plate is in form state, all VIN-path combos exit the union pool so VIN/MakeCode do not
#   bleed into the plate XML (live-proven union-pool over-send: all-fields case fired
#   RQ+RQV+QVV simultaneously). Mirrors the M55L (LicensePlateTypeCode NOT_EXISTS) and
#   M55S (RegistrationState NOT_EXISTS) pool-exclusion pattern. M55S now has two conditions:
#   RegistrationState NOT_EXISTS AND LicensePlateNumber NOT_EXISTS -- fires only for bare VIN.
#   VEHICLEYEAR: Added vehicleYear to RQV, M55S, QVV any[]. sourceField='vehicleYear';
#   the attribute existed in QIDM but was in no combo any[], so vehicleYear was silently
#   dropped from all VIN-query XML even when filled.
# v3.5 (2026-06-22): Fixed any[] gap on GunQuery (QG), ArticleSingleQuery (QA), and BoatQuery
#   (BQ/QB). Platform only serializes set[]+any[] fields; all three QIDMs had any=@(), which
#   silently dropped RelatedSearchHitIndicator (default=Y) + optional fields from XML.
#   QG: added any=@('GunMake','GunCaliber','GunModel','relatedSearchHitIndicator') + default Y.
#   QA: added any=@('relatedSearchHitIndicator') + default Y.
#   BQ/QB: added any=@('RegistrationState','relatedSearchHitIndicator') + default Y.
#   Pattern confirmed from FL_FCIC GunQuery (GunMake+ImageIndicator in any[] + default).
#   Pre-live-test gap found during T19 pre-flight simulator check.
# v3.4 (2026-06-22): Removed RegistrationState from M55S any[]. M55S can only fire when
#   RegistrationState NOT_EXISTS (condition); having it in any[] was a semantic contradiction
#   (State can never be serialized alongside M55S since it's blank when M55S fires) and
#   caused the test conductor to inject RegistrationState="NJ" into minimal test data,
#   triggering the NOT_EXISTS condition and blocking M55S from firing in T16.
#   M55L UNCHANGED -- M55L's condition is LicensePlateTypeCode (not RegistrationState), so
#   State CAN ride along on in-state plate queries via any[].
# v3.3 (2026-06-22): Fixed M55S conditions field name: was @('State') (attribute name),
#   must be @('RegistrationState') (sourceField). T5 (RQV OOS VIN) showed VehicleTypeCode
#   still bled because conditions[].field matches sourceField, NOT the attribute name.
#   M55L worked in T4 because LicensePlateTypeCode is BOTH the attribute name and sourceField.
#   Rule corrected in KB: conditions[].field = sourceField. FL_FCIC uses 'State' because
#   FL's sourceField for the state selector IS 'State'; HI uses 'RegistrationState'. Vehicle
#   tests restarted from T1. Person UNCHANGED (stays blocked).
# v3.2 (2026-06-22): Added conditions to M55L (LicensePlateTypeCode NOT_EXISTS) and M55S
#   (RegistrationState NOT_EXISTS) to prevent VehicleTypeCode union-pool bleed-through in OOS
#   XML. Live T4 (RQ) showed <VehicleTypeCode>1</VehicleTypeCode> in OOS plate XML because
#   M55L set[vehicleTypeCode(defaulted)+Plate] was simultaneously satisfied by form state.
#   Extra field unknown behavior risk on production HI CommSys server. Conditions fix: when
#   PlateType is present (OOS plate), M55L fails conditions -> exits pool -> RQ XML is clean.
#   When State is present (OOS VIN), M55S fails conditions -> exits pool -> RQV XML is clean.
#   Person UNCHANGED (stays blocked). Vehicle tests restarted from T1.
# v3.1 (2026-06-22): Vehicle State label shortened to 'State (Hawaii = leave blank)'
#   (was the longer "Registration State - leave blank for Hawaii; enter..."). Label-only
#   refinement of the v3.0 routing redesign, pre-live-test. Person UNCHANGED (stays blocked).
# v3.0 (2026-06-22): Vehicle OOS-first routing redesign. Reordered VehicleRegistrationQuery
#   combos (RQ-plate, RQV-VIN+State, M55L, M55S, then dormant QVV/QVP) so out-of-state is
#   reached by ADDING fields (Plate Type+Year for plate, State for VIN) -- never by clearing
#   Vehicle Type. RQV now requires VIN+State (State in set[], NY pattern). Removed Plate Year
#   default. Relabeled Vehicle Type / State for the new workflow. Person UNCHANGED (stays blocked).
# v1.8 (2026-06-17): consolidated BASE/MC split -> single JSON; Person split to 2 cards
#   (Driver License / Driver History); added ImageIndicator=N combo defaults to all 6
#   VehicleRegistrationQuery combos (the real CAD failure -- CAD ignores form initialValue).
#   Card count is NOT the CAD cause (BASE single-card and MC multi-card failed identically).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_hi_hcjdc_ofml.ps1
#
# INPUTS:
#   source\HI_HCJDC_OFML.xml  -- XML metadata (System HCJDC_OFML v9) [AUTHORITATIVE]
#   source\HI_HCJDC_OFML.pdf  -- CommSys devdoc (Basic Queries + CCH + Expanded) [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs) + hand-built HI reference
#
# SCOPE: Basic Queries only (6 transactions from PDF/XML):
#   ArticleSingleQuery, BoatQuery, DriverHistoryQuery, DriverLicenseQuery, GunQuery, VehicleRegistrationQuery
#   CCH queries (AQ/FQ/IQ/QH/QR/ZR), SecuritiesStolenQuery (QS), WantedPersonQuery (QW standalone)
#   are NOT in scope for Phase 1. The QW combo inside DriverLicenseQuery IS included (per XML metadata).
#
# XML METADATA NOTES:
#   18 MessageKeys: AQ, BQ, DQ, FQ, IQ, KQ, M55L, M55S, QA, QB, QG, QH, QR, QS, QV, QW, RQ, ZR
#   BoatQuery uses <Choice> elements -- split into separate combos per primary field
#   DriverLicenseQuery has a QW (Wanted Person) combo alongside DQ combos -- included per source authority
#   VehicleRegistrationQuery has 6 combos: M55L/M55S (in-state), RQ (out-state), QV (stolen)
#   State2-5 fields on DL/VehicleReg: NOT implementable (platform has no multi-state mechanism). Excluded.
#
# DUPLICATE keyRef INVENTORY (LIMITATION #21):
#   BoatQuery:               BQ (Boat Reg) + QB (Stolen Boat) -> BQ (Reg), QB (Hull)
#   DriverHistoryQuery:      KQ x2           -> KQN (OLN), KQ (Name)
#   DriverLicenseQuery:      DQ x2 + QW     -> DQN (OLN), DQ (Name), QW (distinct)
#   VehicleRegistrationQuery: RQ x2 + QV x2 + M55L + M55S -> M55L, M55S, RQ, QVP, QVV, RQV (6 distinct)
#   GunQuery:                QG              -> QG (no duplicate)
#   ArticleSingleQuery:      QA              -> QA (no duplicate)
#
# PDF vs XML DISCREPANCIES:
#   BoatQuery:   XML uses <Choice>, PDF shows 2 simple combos -- functionally equivalent after split
#   DL:          XML has QW combo (Wanted Person), PDF Basic Queries does NOT show it -- metadata wins
#   VehicleReg:  XML has QV combos (Stolen Vehicle), PDF has them in Expanded section -- QV combos stay in VehReg QIDM (VehicleRegistrationQuery keys), separate VehicleStolenQuery QIDM removed per devdoc authority
#   VehicleReg:  PDF shows 4 combos, XML has 6 -- extra 2 are QV stolen combos
#   State2-5:    PDF says "submit up to 5 states" on DL/VehicleReg -- not implementable, excluded
#   DH:          XML has State in any[], PDF does not mention State -- metadata wins (include State)
#
# STATE HANDLING (Phase 1 NCIC pattern):
#   Single visible Sel 'RegistrationState' (attributeTypeId=STATE, initialValue=HI)
#   CommSys State attr: sourceField=RegistrationState, codeTypeProvider=NCIC
#   RMS: useAttributeId=true + AttributeArrayWrapperRuleHandler (KB standard)
#   Note: NCIC pattern unconfirmed for HI -- test ST-1 on first import.
#
# SEX HANDLING (NIBRS reverse-lookup):
#   Form: Sel 'SexCode' attributeTypeId=SEX + codeTypeProvider=NIBRS
#   CommSys: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
#   RMS: useAttributeId=true (KB standard)
#
# DATE FORMAT: MMddyyyy
# NAME FORMAT: "First Last Middle Suffix" with space separators

param(
    [string]$Version = "3.6",
    # DIAGNOSTIC ONLY: emit a throwaway test JSON to diagnostics/ where the DH
    # Attention attribute has NO handler (plain passthrough) and the Attention
    # field is VISIBLE -- to test whether a typed Attention value reaches the wire
    # (isolates "attribute/plumbing" from "the profile handler"). Not for import to
    # production; not part of the normal build/test package.
    [switch]$AttnDiagnostic,
    # Which Attention experiment to emit (requires -AttnDiagnostic):
    #   dochandler  = doc-exact handler: sourceField=[], rule=handler, targetField=Attention,
    #                 NO form field, Attention NOT in combo any[] (generated field).
    #   passthrough = no handler; visible Attention field + 'Attention' added to DH any[]
    #                 (tests whether combo-membership lets a typed value serialize).
    #   handler     = import-safe handler: sourceField=['Attention'], rule=handler,
    #                 'Attention' in combo any[], VISIBLE field (pre-filled). Tests whether
    #                 the handler reads the RMS profile (-> officer name) or just the field.
    [ValidateSet('passthrough','dochandler','handler')][string]$AttnMode = 'passthrough'
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases"
if ($AttnDiagnostic) {
    $OUT    = "$DIR\diagnostics\HI_HCJDC_OFML_ATTNTEST_${AttnMode}.json"
    $VEROUT = $null
    New-Item -ItemType Directory -Force -Path "$DIR\diagnostics" | Out-Null
} else {
    $OUT    = "$DIR\HI_HCJDC_OFML.json"
    $VEROUT = "$PHASEDIR\HI_HCJDC_OFML_v${Version}_${DATE}.json"
}

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: HI_HCJDC_OFML PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'HI_HCJDC_OFML'

$results = Build-ProviderQrdm -ProviderName 'HI_HCJDC_OFML'

$qmf = Build-Qmf -ProviderName 'HI_HCJDC_OFML'

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: 6 combos across 3 message keys (M55L, M55S, RQ, QV)
#   M55L: In-state plate (VehicleTypeCode + Plate)
#   M55S: In-state VIN (VehicleTypeCode + VIN)
#   RQ:   Out-state plate (Plate + PlateType + PlateYear), Out-state VIN (VIN)
#   QV:   Stolen plate (Plate + State), Stolen VIN (VIN + MakeCode)
# State2-5 excluded (not implementable). Single RegistrationState (NCIC).
# Combo ordering (v3.0, OOS-first): RQ-Plate (OOS, Plate Type+Year) > RQV (OOS VIN, VIN+State)
#   > M55L (in-state plate) > M55S (in-state VIN) > QVV/QVP (stolen, DORMANT, last)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('LicensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 20; sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleTypeCode';              size = 1;  sourceField = @('vehicleTypeCode');              targetField = 'VehicleTypeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    # ORDER (v3.0): OUT-OF-STATE FIRST so the officer reaches OOS by ADDING fields,
    # never by clearing Vehicle Type (the v2.8 "clear-to-switch" UX was confusing).
    #   1. RQ  (OOS plate): fires when Plate Type + Plate Year are filled (the
    #      "out-of-state plates only" fields the server genuinely requires for RQ).
    #   2. RQV (OOS VIN): fires when VIN + State are filled. RegistrationState is in
    #      set[] here (NY pattern) as the VIN OOS discriminator; metadata permits
    #      State on the OOS-VIN RQ combo (it sits in any[] there) -- promoting to set[]
    #      for routing is a design choice, not a field-membership divergence.
    #   3. M55L (in-state plate): bare plate -- VehicleTypeCode defaults to 1 (Auto),
    #      auto-satisfying the server's in-state requirement so a plate alone routes HI.
    #   4. M55S (in-state VIN): bare VIN -- same, VehicleTypeCode default carries it.
    #   5-6. QVV/QVP (stolen) last + DORMANT: ordered AFTER M55L/M55S so they never
    #      shadow an in-state query; the state CommSys server auto-generates the
    #      QV/stolen query from supplied fields (response data-mined via QRDM).
    # Discriminators: plate = Plate Type/Year presence; VIN = State presence. Both are
    # real OOS data, not synthetic switches. Bare plate -> M55L, bare VIN -> M55S.
    combinations = @(
        # RQ: Out-of-state plate (Plate + PlateType + PlateYear). Neither Plate Type nor
        # Plate Year has a form default, so RQ only fires once the officer fills them --
        # a deliberate OOS action. A bare plate has neither -> falls through to M55L.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'Out'
        }
        # RQV: Out-of-state VIN (VIN + State). State in set[] is the VIN OOS discriminator
        # -- a bare VIN has no State -> falls through to M55S (in-state).
        # CONDITION: LicensePlateNumber NOT_EXISTS -- plate-wins guardrail. When officer fills
        # both Plate and VIN, Plate wins: RQV exits the union pool so VehicleIdentificationNumber
        # and vehicleYear do NOT bleed into RQ's XML. (v3.6 all-fields stress test finding)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @('ImageIndicator','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQV'
            state                 = 'Out'
        }
        # M55L: In-state plate (VehicleTypeCode + Plate) -- PRIMARY plate. VehicleTypeCode
        # defaults to 1 (Auto), so a bare plate routes in-state with zero extra clicks.
        # CONDITION: LicensePlateTypeCode NOT_EXISTS -- when officer fills Plate Type for an
        # OOS plate query (RQ), M55L exits the union pool so VehicleTypeCode does NOT bleed
        # into RQ's XML (live T4 finding: extra fields unknown risk on production CommSys).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','LicensePlateNumber'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }); conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'M55L'
            state                 = 'In'
        }
        # M55S: In-state VIN (VehicleTypeCode + VIN) -- PRIMARY VIN
        # CONDITIONS (two -- both must pass):
        #   1. RegistrationState NOT_EXISTS -- when officer fills State for an OOS VIN query
        #      (RQV), M55S exits the pool so VehicleTypeCode does NOT bleed into RQV XML.
        #      NOTE: conditions[].field = SOURCEFIELD (form fieldId), NOT the attribute name.
        #      FL_FCIC uses 'State' because its sourceField IS 'State'; HI's sourceField is
        #      'RegistrationState'. v3.2 used @('State') (silent no-op). Fixed v3.3. (T5)
        #   2. LicensePlateNumber NOT_EXISTS -- plate-wins guardrail. When bare Plate+VIN
        #      present (no State, no PlateType/Year), M55L (in-state plate) and M55S (in-state
        #      VIN) would both satisfy; without this condition VIN bleeds into the plate XML.
        #      With both conditions: M55S fires ONLY for bare VIN (no State, no Plate). (v3.6)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','VehicleIdentificationNumber'); any = @('ImageIndicator','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' },[PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'M55S'
            state                 = 'In'
        }
        # QVV: Stolen VIN (VIN + MakeCode) -- DORMANT (server-generated QV).
        # CONDITION: LicensePlateNumber NOT_EXISTS -- plate-wins guardrail. Without this,
        # filling Plate+VIN+Make causes QVV to co-fire with RQ and bleed VehicleMakeCode
        # into the plate XML via the union pool. (v3.6 all-fields stress test finding)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','VehicleMakeCode'); any = @('ImageIndicator','RegistrationState','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVV'
            state                 = 'In/Out'
        }
        # QVP: Stolen plate (Plate + State) -- DORMANT (server-generated QV). Ordered
        # after M55L so a normal plate+state query stays in-state (M55L), not stolen.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState'); any = @('ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVP'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- OOS-first routing (v3.0): RQ (plate, fires on Plate Type+Year) and RQV (VIN, fires on VIN+State) ordered before in-state M55L (plate) / M55S (VIN); OOS reached by ADDING fields, never clearing Vehicle Type. QVP/QVV stolen DORMANT (server auto-generates QV), ordered last so they never shadow in-state. 6 combos.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'HI_HCJDC_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'HI_HCJDC_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML: 3 combos -- DQ (OLN), DQ (Name+Sex+DOB), QW (Name+DOB wanted person)
#   State2-5 excluded. Single RegistrationState (NCIC).
#   QW fires when Name+DOB present but SexCode absent (less restrictive than DQ Name).
#   autoSelect=true, queriesToDeselect=DriverHistoryQuery
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 30; sourceField = @('NameFirst','NameLast','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ: Name+DOB+Sex path -- 4 set[], most specific. primary=SexCode per metadata
        # (the SexCode-primary DQ combo; distinguishes from QW Name+DOB). State optional (OOS).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('RegistrationState') }
            primaryFieldReference = 'SexCode'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        # QW: Wanted Person -- 3 set[] (Name+DOB, no Sex). State optional companion (OOS).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('RegistrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'QW'
            state                 = 'In/Out'
        }
        # DQN: OLN path -- 1 set[], least specific. State optional companion (OOS).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (Name+Sex+DOB), QW (Wanted Person), DQN (OLN). State in any[] for OOS. Shared Person fields; DH is opt-in (no queriesToDeselect).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- DH-SUFFIX, SEPARATE CARD (v1.8 3-card Person)
# XML: 2 combos -- KQ (Name+Sex+DOB), KQN (OLN).
#   DH on its own card with DH-suffix fieldIds (nameFirstDH/.../operatorLicenseNumberDH/
#   purposeCodeDH/birthDateDH/sexCodeDH) -- isolates DH from DL (no duplicate-fieldId
#   across cards). registrationState (shared, on the Search Options card) carries OOS.
#   autoSelect=true; ONE-DIRECTIONAL queriesToDeselect=['DriverLicenseQuery'] (DH deselects
#   the default DL; never bidirectional -- LIMITATION #24/one-directional rule). PurposeCode
#   + State in any[] (optional companions). Attention handler-only.
# =====================================================================
if ($AttnDiagnostic -and $AttnMode -eq 'passthrough') {
    # DIAGNOSTIC B: passthrough -- no handler. Typed value should serialize verbatim
    # IF 'Attention' is in the fired combo's any[] (added below).
    $attnAttr = [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention' }
} elseif ($AttnDiagnostic -and $AttnMode -eq 'handler') {
    # DIAGNOSTIC C: import-safe handler WITH correct plumbing (Attention in any[],
    # visible pre-filled field). Output reveals what the handler does:
    #   officer name -> reads RMS profile (production: hide the field) | field value -> passthrough.
    $attnAttr = [PSCustomObject]@{
        name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
        rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
    }
} elseif ($AttnDiagnostic -and $AttnMode -eq 'dochandler') {
    # DIAGNOSTIC A: doc-exact handler -- sourceField=[] (generated field), per the
    # CommsysGetLastNameFirstNameInitialRuleHandler documentation.
    $attnAttr = [PSCustomObject]@{
        name = 'Attention'; size = 30; sourceField = @(); targetField = 'Attention'
        rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
    }
} else {
    # PRODUCTION: handler + sourceField=['Attention'] (the import-safe form we shipped).
    $attnAttr = [PSCustomObject]@{
        name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
        rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
    }
}
# Platform serializes ONLY fields in the FIRED COMBO's set[]/any[]; an attribute
# absent from the combo is dropped -- this is why Attention never reached the wire
# before. FIX (live-proven HI handler diagnostic 2026-06-22): 'Attention' must be
# in the DH combos' any[]. With that + the hidden gate-feeder field populated +
# sourceField=['Attention'] + the handler, CommsysGetLastNameFirstNameInitialRuleHandler
# emits the officer's profile name (e.g. "SGAMBELLONE R"). So Attention is in any[]
# for production AND the passthrough/handler diagnostics; only the (dead, import-
# rejected) dochandler sourceField=[] variant omits it.
$dhAny = if ($AttnDiagnostic -and $AttnMode -eq 'dochandler') { @('RegistrationState','purposeCodeDH') } else { @('RegistrationState','purposeCodeDH','Attention') }
$dhQuery = [PSCustomObject]@{
    attributes = @(
        $attnAttr
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 30; sourceField = @('NameFirstDH','NameLastDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');              targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ: Name path -- 4 set[], most specific. DH-suffix. State+PurposeCode optional.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCodeDH','BirthDateDH','NameLastDH','NameFirstDH'); any = $dhAny; defaults = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
        # KQN: OLN path -- 1 set[]. DH-suffix. State+PurposeCode optional.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = $dhAny; defaults = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ (Name+Sex+DOB), KQN (OLN). DH-suffix fields on own card. State+PurposeCode+Attention in any[]. Attention auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler (officer LastName FirstInitial from RMS profile) -- requires Attention in any[] + hidden gate-feeder field populated (v2.9, live-proven). autoSelect + one-directional queriesToDeselect=DL.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    queriesToDeselect = @('DriverLicenseQuery')
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery
# XML: 1 combo (QG). GunMake maxLength=10 (not 23 like NJ). GunSerialNumber=20.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                size = 4;  sourceField = @('GunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                   size = 10; sourceField = @('GunMake');                   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                  size = 20; sourceField = @('GunModel');                  targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';           size = 20; sourceField = @('GunSerialNumber');           targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # Caliber/Make/Model ride along in any[]; relatedSearchHitIndicator defaults Y.
        # NOTE: Platform serializes only set[]+any[] fields -- empty any[] silently drops
        # all optional fields (Make/Caliber/Model/RSH) from XML. FL_FCIC pattern confirmed.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('GunSerialNumber')
                any      = @('GunMake','GunCaliber','GunModel','relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. GunMake maxLength=10 (HI-specific).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML: 1 combo (QA). Same structure as NJ but with RelatedSearchHitIndicator.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('ArticleSerialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('ArticleTypeCode');           targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # RSH optional; must be in any[] to serialize. Default Y.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('ArticleSerialNumber','ArticleTypeCode')
                any      = @('relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# XML: BQ (Choice[Hull/Reg], any=[State]) + QB (Choice(max2)[Reg/Hull], any=[RelatedSearchHitIndicator])
# Merged into 2 combos: one per primary field, both optional fields in any[]
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ: Boat Registration. RegistrationState/RSH optional; must be in any[] to serialize.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('RegistrationNumber')
                any      = @('RegistrationState','relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        # QB: Stolen Boat. RegistrationState/RSH optional; must be in any[] to serialize.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('BoatHullIdNumber')
                any      = @('RegistrationState','relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Reg), QB (Stolen/Hull). Merged from XML Choice elements.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for HI_HCJDC_OFML v${Version}"
    name           = 'HI_HCJDC_OFML'
    type           = 'BUNDLE'
    provider       = 'HI_HCJDC_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# =====================================================================

# Vehicle -- 3 cards (v3.0): SEARCH OPTIONS (shared State/Type/Image) + PLATE SEARCH + VIN SEARCH.
# Routing (OOS-first): out-of-state reached by ADDING fields, never clearing Vehicle Type.
#   Plate: bare plate -> M55L (in-state); + Plate Type + Plate Year -> RQ (out-of-state).
#   VIN:   bare VIN -> M55S (in-state); + State -> RQV (out-of-state).
# Plate Type AND Plate Year now have NO form default (both blank) so they read as the
# "out-of-state plates only" fields and filling them is the deliberate OOS signal.
# VehicleType default=1 (Auto) auto-satisfies the server's in-state requirement.
# QV (stolen) server-generated. VehicleTypeCode: 1=Auto, 2=Motorcycle, 3=Truck, 5=Trailer, 6=Moped.
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'SEARCH OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_OPT1'; cols = @('4','4','4'); fields = @(
                @{ id = 'vehicleTypeCode_Input';   node = Sel 'vehicleTypeCode' 'Vehicle Type - Auto (Hawaii queries)' @{ codeTypeCategory = 'VEHICLE_TYPE'; codeTypeSource = 'HI_NIBRS'; initialValue = '1' } 'ROW_VEH_OPT1' }
                @{ id = 'registrationState_Input'; node = Sel 'RegistrationState' 'State (Hawaii = leave blank)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT1' }
                @{ id = 'imageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image - include image (Y/N)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_OPT1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE1'; cols = @('12'); fields = @(
                @{ id = 'licensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'License Plate Number' '10' 'ROW_VEH_PLATE1' }
            )}
            @{ id = 'ROW_VEH_PLATE2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type - out-of-state plates only' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_PLATE2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year - out-of-state plates only' '4' 'ROW_VEH_PLATE2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN1'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number (VIN)' '20' 'ROW_VEH_VIN1' }
            )}
            @{ id = 'ROW_VEH_VIN2'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Make - optional' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_VIN2' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year - optional' '4' 'ROW_VEH_VIN2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 3 cards: SEARCH OPTIONS (Vehicle Type/State/NCIC Image), PLATE SEARCH, VIN SEARCH. OOS-first routing: bare plate->M55L, +Plate Type+Year->RQ; bare VIN->M55S, +State->RQV. OOS by adding fields, never clearing Vehicle Type. QV server-generated.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 1 card
# Serves BOTH DriverLicenseQuery (DQN/DQ/QW) and DriverHistoryQuery (KQN/KQ)
# DL/DH share fields. DH adds Attention + PurposeCode.
# autoSelect on DL, queriesToDeselect bidirectional.
# Person -- 2 cards: DRIVER LICENSE (DL: DQ/QW/DQN) and DRIVER HISTORY (DH: KQ/KQN).
# DL and DH are distinct queries with bidirectional autoSelect + queriesToDeselect, so they
# get distinct cards (clarifies which query the officer runs). One QIF, two visual cards;
# DH uses DH-suffix fieldIds. registrationState lives on the DL card and is shared by the
# DH State attr (cards are visual only -- field population is form-wide, not card-scoped).
# Person -- 3 cards: SEARCH OPTIONS (shared State) + DRIVER LICENSE (DQ/QW/DQN, plain
# fieldIds) + DRIVER HISTORY (KQ/KQN, DH-suffix + Purpose Code). Separate cards need
# distinct fieldIds (duplicate fieldId across cards = ISE), hence DH-suffix on the DH card.
# registrationState lives on the Options card and is shared by both DL and DH QIDMs.
# Attention field on the DH card: normally hidden (gate-feeder for the auto-handler);
# in -AttnDiagnostic it is VISIBLE passthrough (type a value, expect it verbatim in XML).
# Visible Attention field only for the passthrough diagnostic (officer types a value).
# dochandler + production keep it hidden (handler is sourceless / gate-feeder).
if ($AttnDiagnostic -and ($AttnMode -eq 'passthrough' -or $AttnMode -eq 'handler')) {
    $attnRowHidden = $false
    $attnFieldNode = Inp  'Attention' 'ATTENTION TEST - type any value, it should appear verbatim in the XML' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'ATTNTEST123' }
} else {
    $attnRowHidden = $true
    $attnFieldNode = InpH 'Attention' 'Attention (auto-populated from officer profile)' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'X' }
}
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'SEARCH OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_OPT1'; cols = @('12'); fields = @(
                @{ id = 'registrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for in-state)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE'
        rows  = @(
            @{ id = 'ROW_PER_DL1'; cols = @('12'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number (or search by Name + DOB)' '20' 'ROW_PER_DL1' }
            )}
            @{ id = 'ROW_PER_DL2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'nameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL2' }
                @{ id = 'nameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL2' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_DL2' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '30' 'ROW_PER_DL2' }
            )}
            @{ id = 'ROW_PER_DL3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (required with Name)' 'ROW_PER_DL3' }
                @{ id = 'sexCode_Input';   node = Sel 'SexCode'   'Sex (optional)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY'
        rows  = @(
            @{ id = 'ROW_PER_DH1'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number (DH) - or Name + DOB + Sex' '20' 'ROW_PER_DH1' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code (DH) - optional' '1' 'ROW_PER_DH1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DH2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name (DH)'  '30' 'ROW_PER_DH2' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name (DH)'   '30' 'ROW_PER_DH2' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH, optional)' '30' 'ROW_PER_DH2' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH, optional)'      '30' 'ROW_PER_DH2' }
            )}
            @{ id = 'ROW_PER_DH3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth (DH) - required with Name' 'ROW_PER_DH3' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex (DH) - required with Name' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH3' }
            )}
            # v2.7: hidden Attention gate-feeder. The DH QIDM Attention attribute
            # (CommsysGetLastNameFirstNameInitialRuleHandler) is gated out of
            # serialization unless its sourceField ['Attention'] resolves to a value.
            # This hidden field supplies that value so the handler runs and emits the
            # logged-in officer's name (LastName FirstInitial) from the profile.
            # initialValue is a placeholder the handler is expected to ignore.
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $attnRowHidden; fields = @(
                @{ id = 'Attention_Input'; node = $attnFieldNode }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 3 cards: SEARCH OPTIONS (shared State), DRIVER LICENSE (DQ/QW/DQN, plain), DRIVER HISTORY (KQ/KQN, DH-suffix + PurposeCode). DL autoSelect; DH opt-in via one-directional queriesToDeselect.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card (QG)
# GunMake maxLength=10 (HI-specific, not 23 like NJ)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'gunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number (required)' '20' 'ROW_GUN_1' }
                @{ id = 'gunMake_Input';         node = Sel 'GunMake' 'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'gunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunModel_Input';                  node = Inp 'GunModel' 'Model (optional)' '20' 'ROW_GUN_2' }
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Search Hit (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article -- 1 card (QA)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'articleSerialNumber_Input';       node = Inp 'ArticleSerialNumber' 'Serial Number (required)' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';           node = Sel 'ArticleTypeCode' 'Article Type (required)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6'); fields = @(
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Search Hit (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat -- 1 card
# BoatQuery: BQ (Reg) + BQN (Hull). State + RelatedSearchHitIndicator optional.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'registrationNumber_Input';        node = Inp 'RegistrationNumber' 'Registration Number (or use Hull ID)' '8' 'ROW_BOA_1' }
                @{ id = 'registrationState_Input';         node = Sel 'RegistrationState' 'State (optional)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('8','4'); fields = @(
                @{ id = 'boatHullIdNumber_Input';          node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Search Hit (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (Reg) and BQN (Hull).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

if ($AttnDiagnostic) {
    Write-ProviderJson -BundleObject $output -OutPath $OUT -Label "Built HI_HCJDC_OFML ATTN DIAGNOSTIC (passthrough, visible Attention)"
    Write-Host ""
    Write-Host "DIAGNOSTIC JSON written: $OUT" -ForegroundColor Cyan
    Write-Host "  Import it, run a Driver History query (the Attention field is visible, pre-filled 'ATTNTEST123')," -ForegroundColor Cyan
    Write-Host "  and check the XML: if <Attention>ATTNTEST123</Attention> appears, the wire works and the" -ForegroundColor Cyan
    Write-Host "  production handler is what suppresses output; if absent, Attention is dropped regardless." -ForegroundColor Cyan
    return
}
Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built HI_HCJDC_OFML v${Version}"

# =====================================================================
# VALIDATE (use NJ validator adapted for HI)
# =====================================================================
$VALIDATOR = (Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1").Path
if (Test-Path $VALIDATOR) {
    Write-Host "Validation complete." -ForegroundColor Green
} else {
    Write-Host "Validator not found at $VALIDATOR -- skipping." -ForegroundColor Yellow
}

# -- Git commit --
Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."