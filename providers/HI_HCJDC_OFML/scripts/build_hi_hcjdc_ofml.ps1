# build_hi_hcjdc_ofml.ps1  -- HI_HCJDC_OFML canonical build (single JSON, multi-card)
# Builds HI_HCJDC_OFML.json from source\HI_HCJDC_OFML.xml + KB specs.
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
    [string]$Version = "2.8",
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
# Combo ordering: M55 (in-state) > RQ-Plate (out-state) > QV (stolen) > RQ-VIN (fallback)
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
    # ORDER (v2.8): in-state primary (M55L/M55S) first so a bare plate/VIN routes
    # in-state HI (VehicleTypeCode defaults to 1). Out-of-state (RQ/RQV) next --
    # reached when the officer fills Plate Type+Year (plate) or clears Vehicle Type
    # (VIN); union pool still carries those fields so the CommSys server fans out.
    # QVP/QVV (stolen) last + DORMANT: the state CommSys server auto-generates the
    # QV/stolen query from supplied fields (response data-mined via QRDM), so we do
    # not route them here. Revisit if/when the QV automation is built.
    combinations = @(
        # M55L: In-state plate (VehicleTypeCode + Plate) -- PRIMARY plate
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','LicensePlateNumber'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'M55L'
            state                 = 'In'
        }
        # M55S: In-state VIN (VehicleTypeCode + VIN) -- PRIMARY VIN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','VehicleIdentificationNumber'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'M55S'
            state                 = 'In'
        }
        # RQ: Out-state plate (Plate + PlateType + PlateYear). Plate Type has NO form
        # default (Plate Year keeps current-year per cross-provider standard), so RQ
        # only fires once the officer picks a Plate Type -- a deliberate OOS action.
        # That keeps a bare plate in-state (M55L).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'Out'
        }
        # QVV: Stolen VIN (VIN + MakeCode) -- DORMANT (server-generated QV).
        # Ordered before RQV so RQV's set[VIN] (a subset) does not shadow it.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','VehicleMakeCode'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVV'
            state                 = 'In/Out'
        }
        # QVP: Stolen plate (Plate + State) -- DORMANT (server-generated QV)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState'); any = @('ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVP'
            state                 = 'In/Out'
        }
        # RQV: Out-state VIN (VIN only) -- least specific, ordered LAST. Reached by
        # clearing Vehicle Type (and no Make).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQV'
            state                 = 'Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- in-state primary: M55L (plate) / M55S (VIN) first; out-of-state RQ/RQV next (Plate Type+Year, or clear Vehicle Type); QVP/QVV stolen DORMANT (server auto-generates QV). State in any[] rides along. 6 combos.'
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
# Platform serializes only fields in the FIRED COMBO's set[]/any[] -- an attribute
# absent from the combo is dropped (live-proven HI v2.8: passthrough Attention not
# in any[] never reached the wire). The passthrough diagnostic adds 'Attention' to
# the DH any[] to prove membership is what lets a form-sourced value serialize.
# (dochandler is a sourceless generated field, so it is NOT added to any[].)
$dhAny = if ($AttnDiagnostic -and ($AttnMode -eq 'passthrough' -or $AttnMode -eq 'handler')) { @('RegistrationState','purposeCodeDH','Attention') } else { @('RegistrationState','purposeCodeDH') }
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
    description     = 'DriverHistoryQuery -- KQ (Name+Sex+DOB), KQN (OLN). DH-suffix fields on own card. State+PurposeCode in any[]. autoSelect + one-directional queriesToDeselect=DL. Attention handler-only.'
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
        # Caliber/Make/Model/RSH optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @() }
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
        # RSH optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @() }
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
        # BQ: Boat Registration. RSH/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        # QB: Stolen Boat. RSH/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @() }
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

# Vehicle -- 3 cards (v2.8): SEARCH OPTIONS (shared State/Type/Image) + PLATE SEARCH + VIN SEARCH.
# Routing: in-state primary (M55L/M55S, VehicleType default=1). Out-of-state via Plate Type
# (plate) or clearing Vehicle Type (VIN). Plate Type default REMOVED so a bare plate stays
# in-state (RQ needs Plate Type); Plate Year keeps current-year default (cross-provider standard).
# QV (stolen) server-generated. VehicleTypeCode: 1=Auto, 2=Motorcycle, 3=Truck, 5=Trailer, 6=Moped.
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'SEARCH OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_OPT1'; cols = @('4','4','4'); fields = @(
                @{ id = 'vehicleTypeCode_Input';   node = Sel 'vehicleTypeCode' 'Vehicle Type - required for Hawaii (plate or VIN)' @{ codeTypeCategory = 'VEHICLE_TYPE'; codeTypeSource = 'HI_NIBRS'; initialValue = '1' } 'ROW_VEH_OPT1' }
                @{ id = 'registrationState_Input'; node = Sel 'RegistrationState' 'Registration State - leave blank for Hawaii' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT1' }
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
                @{ id = 'licensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year - out-of-state plates only' '4' 'ROW_VEH_PLATE2' @{ initialValue = $currentYear } }
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
    description  = 'Vehicle queries -- 3 cards: SEARCH OPTIONS (Vehicle Type/State/NCIC Image), PLATE SEARCH, VIN SEARCH. In-state primary (M55L/M55S); OOS via Plate Type+Year or clearing Vehicle Type; QV server-generated.'
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