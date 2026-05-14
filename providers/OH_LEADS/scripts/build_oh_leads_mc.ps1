# build_oh_leads_mc.ps1  -- OH_LEADS v1.x MC
# MC variant: PascalCase fieldIds, no full Patch 8 (CAD rename).
# Phase 2 multi-card. Cross-entity combo: RN (vehicle by owner name).
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# OH_LEADS-SPECIFIC:
#   NO CaRequestPurposeCode  -- Ohio, not California.
#   Date format: MMddyyyy    -- DL/DH BirthDate max=8.
#   No State initialValue    -- LIMITATION #30: separate in-state vs OOS keyRefs.
#   ImageIndicator in: ArticleSingleQuery, BoatQuery, DriverLicenseQuery (Y default)
#   RelatedHitSearchIndicator in: Article, Boat, Gun (Y-only flag)
#   DL+DH co-fire: DH uses DH-suffix fieldIds, autoSelect=true
#   VehReg has owner search combos (RS=SSN, RN=Name) -- person fields on Vehicle entity
#   DealerPlateType field for ATDP combo
#   23 combos total (same as BASE -- no new cross-entity combos added)
#
# CROSS-ENTITY:
#   VehicleRegistrationQuery RN: Vehicle by owner name (OwnerLastName, OwnerFirstName, AddressCounty).
#   GunQuery: NO name combos (QG serial only).
#   BoatQuery: NO name combos (BQ/QB hull/reg only).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_oh_leads_mc.ps1

$ErrorActionPreference = "Stop"
$Version     = '1.3'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\mc"
$OUT      = "$DIR\OH_LEADS_MC.json"
$OUTREAD  = "$DIR\OH_LEADS_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\OH_LEADS_MC_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: OH_LEADS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'OH_LEADS'

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'OH_LEADS'

$qmf = Build-Qmf -ProviderName 'OH_LEADS'

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase + cross-entity RN (owner name)
# XML: 9 combos: ATDP, RP, RQ(plate), QV(plate), RV, RS, RN, RQ(VIN), QV(VIN)
# Duplicate keyRefs: RQ -> RQ.P, RQ.V; QV -> QV.P, QV.V
# Owner combos: RS (SSN), RN (Name) -- person fields on Vehicle entity.
# DealerPlateType for ATDP combo.
# LIMITATION #30: No State initialValue -- in-state (RP/RV) vs OOS (RQ) routing.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCounty';               size = 4;  sourceField = @('AddressCounty');               targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'DealerPlateType';             size = 1;  sourceField = @('DealerPlateType');              targetField = 'DealerPlateType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('OwnerLastName','OwnerFirstName'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';        size = 9;  sourceField = @('OwnerSocialSecurityNumber');    targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # Most-specific first (LIMITATION #3: first matching combo fires)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationState','licensePlateNumber','licensePlateTypeCode','licensePlateYear'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','DealerPlateType'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ATDP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','vehicleMakeCode','vehicleYear'); any = @('registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OwnerLastName','OwnerFirstName'); any = @('AddressCounty') }
            primaryFieldReference = 'Name'
            keyReference          = 'RN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RV'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OwnerSocialSecurityNumber'); any = @() }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'RS'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- ATDP (dealer), RP (plate), RQ.P (OOS plate), QV.P (NCIC plate), RV (VIN), RQ.V (OOS VIN), QV.V (NCIC VIN), RS (SSN), RN (Name). MC cross-entity.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'OH_LEADS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'OH_LEADS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase
# XML: 7 combos. Build 4 basic: DL (in-state OLN), DQ.O (OOS OLN),
#   DN (in-state Name), DQ.N (OOS Name).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Most-specific first (LIMITATION #3): DQ.N (4 set) > DN (2 set) > DQ.O (1 set) > DL (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst'); any = @('birthDate') }
            primaryFieldReference = 'Name'
            keyReference          = 'DN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DL'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DL (in-state OLN), DQ.O (OOS OLN), DN (in-state Name), DQ.N (OOS Name).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- PascalCase (DH-suffix fieldIds)
# XML: 3 combos: KQ(OLN), KQ(Name), BMVIMS(OLN).
# Duplicate keyRef KQ -> KQ.O, KQ.N.
# DH uses DH-suffix fieldIds to avoid deadlock with DL co-fire.
# Attention: CommsysGetLastNameFirstNameInitialRuleHandler (auto-fill).
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'Attention'
            rule        = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size        = 30
            sourceField = @('nameLastDH','nameFirstDH')
            targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 30; sourceField = @('ReasonCodeDH'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ.N: Name search -- most specific first (4 set fields)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @('purposeCodeDH','registrationStateDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # KQ.O: OLN search (1 set field)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('nameLastDH','nameFirstDH','purposeCodeDH','registrationStateDH') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # BMVIMS: BMV IMS image lookup by OLN (1 set field)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('nameLastDH','nameFirstDH','ReasonCodeDH') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'BMVIMS'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ.O (OLN), KQ.N (Name), BMVIMS (BMV IMS). DH-suffix fieldIds.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# Add queriesToDeselect on DL QIDM too
$dlQuery | Add-Member -NotePropertyName 'queriesToDeselect' -NotePropertyValue @('DriverHistoryQuery') -Force

# =====================================================================
# 1g. GunQuery -- PascalCase
# XML: 1 combo (QG serial). No name combos.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                  size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                     size = 23; sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';             size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';   size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('firearmMake','gunCaliber','relatedHitSearchIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). Firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- PascalCase
# XML: 2 combos, BOTH keyRef=QA. Invented: QA.S (serial), QA.N (NCIC#).
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('serialNumber');                 targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('articleTypeCode');              targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicatorArticle');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 9;  sourceField = @('ncicNumber');                   targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicatorArticle'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleTypeCode','serialNumber'); any = @('ImageIndicatorArticle','RelatedHitSearchIndicatorArticle') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('ImageIndicatorArticle','RelatedHitSearchIndicatorArticle') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QA.N'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA.S (serial+type), QA.N (NCIC#). Property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- PascalCase
# XML: 4 combos, duplicate keyRefs BQ(x2), QB(x2).
# Invented: BQ.R (reg in-state), BQ.H (hull in-state), QB.R (reg NCIC), QB.H (hull NCIC).
# No name combos in OH BoatQuery.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('boatHullIdNumber');               targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicatorBoat');             targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('registrationNumber');             targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicatorBoat'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationStateBoat'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ.R: in-state registration lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('RegistrationStateBoat') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        # BQ.H: in-state hull lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('RegistrationStateBoat') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        # QB.R: NCIC registration lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','ImageIndicatorBoat','RelatedHitSearchIndicatorBoat') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
        # QB.H: NCIC hull lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('ImageIndicatorBoat','RelatedHitSearchIndicatorBoat') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ.R/BQ.H (in-state reg/hull), QB.R/QB.H (NCIC reg/hull).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$ohBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for OH_LEADS v${Version} MC -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 2 Person QIDMs"
    name           = 'OH_LEADS'
    type           = 'BUNDLE'
    provider       = 'OH_LEADS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  6 cards (OPTIONS + PLATE + DEALER PLATE + VIN + NAME SEARCH + SSN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH) + DH hidden rows
# Firearm:  1 card  (SERIAL SEARCH -- no name combos, no shared options)
# Article:  2 cards (SERIAL SEARCH + NCIC# SEARCH)
# Boat:     2 cards (OPTIONS + HULL/REG SEARCH)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState)
# live on a separate card to avoid duplicate fieldId across cards (= ISE).
# NCIC state pattern: visible RegistrationState, NO initialValue (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 6 cards (MC)
# OPTIONS: RegistrationState (shared by plate+VIN combos, not needed by name/SSN/ATDP)
# PLATE SEARCH: Plate + PlateType + PlateYear (RP, RQ.P, QV.P)
# DEALER PLATE: DealerPlateType (ATDP -- requires plate+type from PLATE card)
# VIN SEARCH: VIN + VehicleMake + VehicleYear (RV, RQ.V, QV.V)
# NAME SEARCH: OwnerFirst + OwnerLast + County (RN cross-entity)
# SSN SEARCH: OwnerSSN (RS)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for OH queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE_1'; cols = @('12'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_PLATE_1' }
            )}
            @{ id = 'ROW_VEH_PLATE_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_PLATE_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_PLATE_2' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_DEALER'
        title = 'DEALER PLATE'
        rows  = @(
            @{ id = 'ROW_VEH_DEALER_1'; cols = @('6'); fields = @(
                @{ id = 'DealerPlateType_Input'; node = Inp 'DealerPlateType' 'Dealer Plate Type' '1' 'ROW_VEH_DEALER_1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_NAME'
        title = 'NAME SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'OwnerFirstName_Input'; node = Inp 'OwnerFirstName' 'Owner First Name' '30' 'ROW_VEH_NAME_1' }
                @{ id = 'OwnerLastName_Input';  node = Inp 'OwnerLastName'  'Owner Last Name'  '30' 'ROW_VEH_NAME_1' }
            )}
            @{ id = 'ROW_VEH_NAME_2'; cols = @('6'); fields = @(
                @{ id = 'AddressCounty_Input'; node = Inp 'AddressCounty' 'County Code' '4' 'ROW_VEH_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SSN'
        title = 'SSN SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_SSN_1'; cols = @('6'); fields = @(
                @{ id = 'OwnerSocialSecurityNumber_Input'; node = Inp 'OwnerSocialSecurityNumber' 'Owner SSN' '9' 'ROW_VEH_SSN_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State) + PLATE (RP/RQ.P/QV.P) + DEALER (ATDP) + VIN (RV/RQ.V/QV.V) + NAME (RN cross-entity) + SSN (RS)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC) + DH hidden rows
# OPTIONS: RegistrationState + ImageIndicator (shared by DL + DH)
# OLN SEARCH: OperatorLicenseNumber (DL, DQ.O, KQ.O, BMVIMS)
# NAME SEARCH: First + Last + DOB + Sex (DN, DQ.N, KQ.N)
# DH hidden fields: DH-suffix fieldIds on hidden rows in NAME/OLN cards
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for OH queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image Indicator' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_NAME_2' }
            )}
        )
    }
    # DH-suffix hidden fields -- mirror DL fields for DH QIDM
    @{
        id    = 'CARD_PER_DH'
        rows  = @(
            @{ id = 'ROW_PER_DH1'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = InpH 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH1' }
                @{ id = 'RegistrationStateDH_Input';     node = SelH 'RegistrationStateDH' 'State (DH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DH1' }
            )}
            @{ id = 'ROW_PER_DH2'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'NameFirstDH_Input'; node = InpH 'NameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH2' }
                @{ id = 'NameLastDH_Input';  node = InpH 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH2' }
            )}
            @{ id = 'ROW_PER_DH3'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_DH3' }
                @{ id = 'SexCodeDH_Input';   node = SelH 'SexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH3' }
            )}
            @{ id = 'ROW_PER_DH4'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'PurposeCodeDH_Input'; node = InpH 'PurposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_DH4' }
                @{ id = 'ReasonCodeDH_Input';  node = InpH 'ReasonCodeDH'  'Reason Code (DH)'  '30' 'ROW_PER_DH4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Image) + OLN (DL/DQ.O/KQ.O/BMVIMS) + NAME (DN/DQ.N/KQ.N). DH-suffix fieldIds.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (MC)
# QG serial only. No name combos, no shared options needed.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_SERIAL_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_SERIAL_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_1' }
            )}
            @{ id = 'ROW_GUN_SERIAL_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit Search' '1' 'ROW_GUN_SERIAL_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: SERIAL (QG). No GunTypeCode in OH metadata.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 2 cards (MC)
# SERIAL SEARCH: Serial + ArticleType + ImageIndicator + RelatedHitSearchIndicator (QA.S)
# NCIC# SEARCH: NCICNumber + ImageIndicator + RelatedHitSearchIndicator (QA.N)
# Note: ImageIndicator and RelatedHitSearchIndicator are in any[] for both combos.
# They use entity-specific suffixed fieldIds to avoid ISE with other entities.
# Since both combos share these any[] fields, they go on both cards.
# But duplicate fieldId across cards = ISE. So use OPTIONS card for shared fields.
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_ART_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'ImageIndicatorArticle_Input';            node = Sel 'ImageIndicatorArticle'            'Image Indicator'    @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_OPT_1' }
                @{ id = 'RelatedHitSearchIndicatorArticle_Input'; node = Inp 'RelatedHitSearchIndicatorArticle' 'Related Hit Search' '1' 'ROW_ART_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_ART_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_SERIAL_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'serialNumber'    'Serial Number' '20' 'ROW_ART_SERIAL_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type'  @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_SERIAL_1' }
            )}
        )
    }
    @{
        id    = 'CARD_ART_NCIC'
        title = 'NCIC# SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_NCIC_1'; cols = @('12'); fields = @(
                @{ id = 'NCICNumber_Input'; node = Inp 'ncicNumber' 'NCIC Number' '9' 'ROW_ART_NCIC_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: OPTIONS (Image + RelatedHit) + SERIAL (QA.S) + NCIC# (QA.N)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 2 cards (MC)
# OPTIONS: RegistrationStateBoat + ImageIndicatorBoat + RelatedHitSearchIndicatorBoat
#          (shared by BQ + QB combos)
# HULL/REG SEARCH: HullId + RegNumber (BQ.R, BQ.H, QB.R, QB.H)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for OH queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationStateBoat_Input';           node = Sel 'RegistrationStateBoat'            'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'ImageIndicatorBoat_Input';              node = Sel 'ImageIndicatorBoat'               'Image Indicator'    @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_OPT_1' }
            )}
            @{ id = 'ROW_BOA_OPT_2'; cols = @('6'); fields = @(
                @{ id = 'RelatedHitSearchIndicatorBoat_Input';   node = Inp 'RelatedHitSearchIndicatorBoat'    'Related Hit Search' '1' 'ROW_BOA_OPT_2' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_SEARCH'
        title = 'HULL / REGISTRATION SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_SEARCH_1'; cols = @('6','6'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_SEARCH_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number'  '8'  'ROW_BOA_SEARCH_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + Image + RelatedHit) + HULL/REG (BQ.R/BQ.H/QB.R/QB.H)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ohBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -ReadablePath $OUTREAD -PhasePath $VEROUT `
    -Label "Built OH_LEADS v${Version}"