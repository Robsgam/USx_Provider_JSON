# build_md_meters_mc.ps1  -- MD_METERS v1.x MC
# MC variant: PascalCase fieldIds, multi-card layout, no Patch 8 (CAD rename).
# Builds MD_METERS_MC.json from source\MD_METERS.xml (2026-05-06 metadata) + KB specs.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_md_meters_mc.ps1 -Version X.X -Phase mc
#
# INPUTS:
#   source\MD_METERS.xml       -- XML metadata (2026-05-06) [AUTHORITATIVE]
#   source\MD_METERS_DEVDOC.txt -- CommSys devdoc [CROSS-CHECK]
#   tools\_build_rms_bundle.ps1            -- RMS bundle + CommSys QRDM (KB specs)
#
# METADATA SUMMARY (MD_METERS v6/v7/v6/v3/v3/v4):
#   VehicleRegistrationQuery v6  -- 4 combos (ZVEH x2, ZLRG x2), collapsed to 4 w/ invented keyRefs
#   DriverLicenseQuery v7        -- 5 combos (ZWAR x2, ZDRV, ZLDR x2), collapsed to 4
#   DriverHistoryQuery v6        -- 2 combos (ZDRV x2), invented DH keyRefs
#   GunQuery v3                  -- 1 combo (ZGUN), all mandatory fields
#   ArticleSingleQuery v3        -- 1 combo (ZART), all mandatory fields
#   BoatQuery v4                 -- 2 combos (ZBOA x2), invented keyRefs
#
# MD-SPECIFIC:
#   No CaRequestPurposeCode -- not a CA system.
#   ImageIndicator present  -- on Vehicle, DL, DH, Boat (in any[]).
#   No VehicleStolenQuery   -- not in metadata.
#   No RandomRequest        -- not in metadata.
#   State: no initialValue (clean routing -- add back after live testing if needed).
#   Date format: MMddyyyy   -- size=8, standard NCIC format.
#   Name: composite Last,First via FormatStringRuleHandler.
#   RaceCode in DL          -- use NIBRS_RACE/NIBRS (not attributeTypeId).
#   GunQuery: all 3 fields mandatory (set[]).
#   DL+DH with DH-suffix + queriesToDeselect on Person entity.
#   No cross-entity combos.
#
# MC LAYOUT (multi-card, PascalCase fieldIds):
#   Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
#   Person:   4 cards (OPTIONS + OLN SEARCH + NAME SEARCH + DRIVER HISTORY)
#   Firearm:  1 card  (ZGUN -- single combo, all mandatory)
#   Article:  1 card  (ZART -- single combo)
#   Boat:     3 cards (OPTIONS + HULL SEARCH + REG SEARCH)

param(
    [string]$Version = "1.3",
    [string]$Phase   = "mc"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\MD_METERS_MC.json"
$OUTREAD  = "$DIR\MD_METERS_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\MD_METERS_MC_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: MD_METERS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'MD_METERS'

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'MD_METERS'

$qmf = Build-Qmf -ProviderName 'MD_METERS'

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase sourceField + combo refs
# XML v6: 4 combos (ZVEH x2, ZLRG x2)
# Invented distinct keyRefs: ZVEH.V, ZVEH.P, ZLRG.P, ZLRG.V
# ImageIndicator in any[] on all combos.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('imageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 24; sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        # Most specific first: Plate+PlateType+PlateYear+[State] (ZLRG plate)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ZLRG.P'
            state                 = 'In/Out'
        }
        # VIN+[State] (ZLRG VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ZLRG.V'
            state                 = 'In/Out'
        }
        # VIN+[VehicleMakeCode] (ZVEH VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('vehicleMakeCode','imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ZVEH.V'
            state                 = 'In/Out'
        }
        # Plate only (ZVEH plate) -- least specific, fallback
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ZVEH.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- ZVEH (plate/VIN), ZLRG (plate+type+year, VIN+state). MC PascalCase.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'MD_METERS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'MD_METERS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase sourceField + combo refs
# 4 combos: ZWAR.N, ZWAR.O, ZLDR.O, ZLDR.N
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';                size = 1;  sourceField = @('imageIndicator');                targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseExpirationYear'; size = 4;  sourceField = @('OperatorLicenseExpirationYear'); targetField = 'OperatorLicenseExpirationYear' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber';         size = 20; sourceField = @('operatorLicenseNumber');         targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                      size = 1;  sourceField = @('RaceCode');                      targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'SexCode';                       size = 1;  sourceField = @('sexCode');                       targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'YearsPastViolationsWanted';     size = 2;  sourceField = @('YearsPastViolationsWanted');     targetField = 'YearsPastViolationsWanted' }
    )
    combinations = @(
        # ZWAR.N: Warrant name search -- Name+Sex+Race+DOB+[State,ImageIndicator] (5 set, most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','RaceCode','sexCode'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'ZWAR.N'
            state                 = 'In/Out'
        }
        # ZWAR.O: Warrant OLN search -- Name+Sex+Race+OLN+[ExpYear,State,ImageIndicator] (5 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','operatorLicenseNumber','RaceCode','sexCode'); any = @('OperatorLicenseExpirationYear','registrationState','imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZWAR.O'
            state                 = 'In/Out'
        }
        # ZLDR.N: DL by Name+DOB+Sex+[State,ImageIndicator] (4 set, Name before OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','sexCode'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'ZLDR.N'
            state                 = 'In/Out'
        }
        # ZLDR.O: DL by OLN+[State,ImageIndicator,YearsPastViolationsWanted] (1 set, least specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('registrationState','imageIndicator','YearsPastViolationsWanted') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZLDR.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- ZWAR (warrant name/OLN), ZLDR (Name/OLN). MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# 1f. DriverHistoryQuery -- PascalCase, DH-suffix sourceField + combo refs
# 2 combos: ZDRV.N (Name+DOB+Sex), ZDRV.O (OLN). In-state only.
# DH-suffix fieldIds isolate from DL field pool (AP #14)
# Combo ordering: Name before OLN (operational priority)
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        # ZDRV.N: DH by Name+DOB+Sex+[ImageIndicator] -- Name before OLN (operational priority)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDateDH','nameLastDH','nameFirstDH','sexCodeDH'); any = @('imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'ZDRV.N'
            state                 = 'In'
        }
        # ZDRV.O: DH by OLN+[ImageIndicator]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZDRV.O'
            state                 = 'In'
        }
    )
    description     = 'DriverHistoryQuery -- ZDRV (Name+DOB+Sex, OLN). DH-suffix fields. In-state only. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# 1g. GunQuery -- PascalCase sourceField + combo refs
# 1 combo (ZGUN) -- all mandatory fields
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');   targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('firearmMake');   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('serialNumber'); targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunCaliber','firearmMake','serialNumber'); any = @() }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'ZGUN'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- ZGUN (serial+make+caliber). All fields mandatory. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- PascalCase sourceField + combo refs
# 1 combo (ZART) -- both fields mandatory
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');    targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode'); targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'ZART'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- ZART (serial+type). MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- PascalCase sourceField + combo refs
# 2 combos: ZBOA.H (hull), ZBOA.R (reg). No State field in BoatQuery.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('imageIndicator');     targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
    )
    combinations = @(
        # ZBOA.H: Hull + [Reg, ImageIndicator]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationNumber','imageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ZBOA.H'
            state                 = 'In/Out'
        }
        # ZBOA.R: Reg + [Hull, ImageIndicator]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','imageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ZBOA.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- ZBOA (hull, reg). MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$mdBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for MD_METERS v${Version} MC -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 2 Person QIDMs"
    name           = 'MD_METERS'
    type           = 'BUNDLE'
    provider       = 'MD_METERS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Firearm:  1 card  (ZGUN -- single combo, all mandatory)
# Article:  1 card  (ZART -- single combo)
# Boat:     3 cards (OPTIONS + HULL SEARCH + REG SEARCH)
#
# No cross-entity combos in MD metadata.
# Shared OPTIONS card: fields used by multiple combos live on a separate
# card to avoid duplicate fieldId across cards (= ISE).
# NCIC state pattern: visible RegistrationState, initialValue='MD'.
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards (MC)
# OPTIONS: RegistrationState + ImageIndicator (shared by all combos)
# PLATE SEARCH: Plate + PlateType + PlateYear
# VIN SEARCH: VIN + VehicleMakeCode
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_OPT_1' }
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
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '24' 'ROW_VEH_VIN_2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State + Image) + PLATE (ZLRG.P/ZVEH.P) + VIN (ZLRG.V/ZVEH.V)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 4 cards (MC)
# OPTIONS: RegistrationState + ImageIndicator + SexCode + RaceCode (shared by DL)
# OLN SEARCH: OperatorLicenseNumber + ExpYear + YearsPastViolations
# NAME SEARCH: First + Last + DOB
# DRIVER HISTORY: DH-suffix fields (isolated from DL field pool per AP #14)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
                @{ id = 'SexCode_Input';           node = Sel 'sexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_OPT_1' }
            )}
            @{ id = 'ROW_PER_OPT_2'; cols = @('6'); fields = @(
                @{ id = 'RaceCode_Input'; node = Sel 'RaceCode' 'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_OPT_2' }
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
            @{ id = 'ROW_PER_OLN_2'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseExpirationYear_Input'; node = Inp 'OperatorLicenseExpirationYear' 'License Expiration Year' '4' 'ROW_PER_OLN_2' }
                @{ id = 'YearsPastViolationsWanted_Input';     node = Inp 'YearsPastViolationsWanted'     'Years Past Violations'  '2' 'ROW_PER_OLN_2' }
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
            @{ id = 'ROW_PER_NAME_2'; cols = @('6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt 'birthDate' 'Date of Birth' 'ROW_PER_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_DH'
        title = 'Driver History'
        rows  = @(
            @{ id = 'ROW_DH1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_DH1' }
                @{ id = 'SexCodeDH_Input';               node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DH1' }
            )}
            @{ id = 'ROW_DH2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_DH2' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_DH2' }
            )}
            @{ id = 'ROW_DH3'; cols = @('6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt 'birthDateDH' 'DOB (DH)' 'ROW_DH3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS + OLN + NAME + DH. DH-suffix fields on separate card.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (MC)
# Single combo ZGUN -- all fields mandatory. No need for multi-card.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'gunCaliber'   'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- ZGUN (serial+make+caliber). Single card, all mandatory.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (MC)
# Single combo ZART. Serial + ArticleType.
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- ZART (serial+type). Single card.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 3 cards (MC)
# OPTIONS: ImageIndicator (shared by both combos)
# HULL SEARCH: BoatHullIdNumber (ZBOA.H)
# REG SEARCH: RegistrationNumber (ZBOA.R)
# No State field in MD BoatQuery metadata.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'ImageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_HULL_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REG SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_REG_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (Image) + HULL (ZBOA.H) + REG (ZBOA.R)'
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
$rmsBundle = Build-RmsBundle -SkipRace
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $mdBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -ReadablePath $OUTREAD -PhasePath $VEROUT `
    -Label "Built MD_METERS v${Version}"