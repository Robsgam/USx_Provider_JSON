# build_or_leds.ps1  -- OR_LEDS v1.x BASE (5 basic queries only)
# Builds OR_LEDS_BASE.json from source\OR_LEDS.xml (metadata v5) + KB specs.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_or_leds.ps1 [-Version X.X]
#
# INPUTS:
#   source\OR_LEDS.xml    -- XML metadata (v5) [AUTHORITATIVE]
#   source\OR_LEDS_DEVDOC.txt -- CommSys devdoc [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
#
# METADATA SUMMARY (OR_LEDS -- 5 basic queries, 8 combos):
#   ArticleSingleQuery       v4  -- 1 combo: QA (Serial+ArticleType)
#   BoatQuery                v3  -- 2 combos: BQ (Reg), BQ (Hull) -- same keyRef, invented BQ.R/BQ.H
#   DriverLicenseQuery       v3  -- 2 combos: DQ (Name+DOB+Sex), DQ (OLN) -- same keyRef, invented DQ.N/DQ.O
#   GunQuery                 v3  -- 1 combo: QG (Serial)
#   VehicleRegistrationQuery v3  -- 2 combos: RQ (Plate), RQ (VIN) -- same keyRef, invented RQ.P/RQ.V
#
# REMOVED (25 non-basic): WMPI x6, CCH x10, CPICBI x5, provider-specific x4
#
# OR-SPECIFIC:
#   NO CaRequestPurposeCode     -- Oregon, not California.
#   NO DriverHistoryQuery        -- not in metadata or devdoc.
#   ImageIndicator: in DL metadata (Y/blank field), default Y.
#   Date format: yyyyMMdd (size=8 in metadata).
#   Devdoc shows In/Out state routing: LIMITATION #30 applies (no State initialValue).
#   ArticleTypeCode: codeTypeSource='NCIC' per task spec (metadata size=7).
#   State: NCIC pattern (codeTypeProvider='NCIC').
#   Sex: NIBRS pattern (codeTypeProvider='NIBRS').
#   PlateType: PC, PlateYear: 2026.
#   RelatedHitSearchIndicator: Y-only flag (FormInput maxLength=1).
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- VehicleRegistrationQuery (In plate/VIN + Out plate/VIN)
#   Person   -- DriverLicenseQuery (In Name/OLN + Out Name/OLN)
#   Firearm  -- GunQuery (QG serial)
#   Article  -- ArticleSingleQuery (QA serial+type)
#   Boat     -- BoatQuery (BQ hull/reg)

param(
    [string]$Version = '1.3',
    [string]$Phase   = "base"
)

$ErrorActionPreference = "Stop"

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\OR_LEDS_BASE.json"
$VEROUT   = "$PHASEDIR\OR_LEDS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: OR_LEDS PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'OR_LEDS'

$results = Build-ProviderQrdm -ProviderName 'OR_LEDS'

$qmf = Build-Qmf -ProviderName 'OR_LEDS'

# =====================================================================
# 1d. VehicleRegistrationQuery
# Devdoc: In plate, In VIN, Out plate+State, Out VIN+State
# Metadata keyRef RQ for both -- invent RQ.P / RQ.V / RQ.PO / RQ.VO
# LIMITATION #30: No State initialValue (In vs Out routing)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS plate (most specific -- requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.PO'
            state                 = 'In/Out'
        }
        # OOS VIN (requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.VO'
            state                 = 'In/Out'
        }
        # In-state VIN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('vehicleMakeCode','vehicleYear','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # In-state plate (least specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear','registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ (In plate/VIN, Out plate+State/VIN+State).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'OR_LEDS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'OR_LEDS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# Devdoc: In Name+DOB+[Sex], In OLN, Out Name+DOB+State+[Sex,Img], Out OLN+State+[Img]
# Metadata keyRef DQ for both -- invent DQ.N / DQ.O / DQ.NO / DQ.OO
# LIMITATION #30: No State initialValue (In vs Out routing)
# ImageIndicator: in metadata (any[])
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
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
        # OOS Name (4 set -- most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','registrationState'); any = @('sexCode','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.NO'
            state                 = 'In/Out'
        }
        # In-state Name (3 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('sexCode','registrationState','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # OOS OLN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.OO'
            state                 = 'In/Out'
        }
        # In-state OLN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (In OLN/Name, Out OLN+State/Name+State). ImageIndicator supported.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. GunQuery -- QG (serial), any[GunMake, GunCaliber]
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';          size = 23; sourceField = @('gunMake');         targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';  size = 11; sourceField = @('serialNumber');    targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','gunMake') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). NCIC firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1g. ArticleSingleQuery -- QA (Serial+ArticleType)
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
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial+type). NCIC article query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1h. BoatQuery -- BQ (Reg), BQ (Hull) -- same keyRef, invent BQ.R / BQ.H
# State in any[] for both combos
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Reg, Hull). NCIC boat query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# Provider bundle assembly (5 basic QIDMs only)
# =====================================================================
$providerBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery
    )
    description    = "Provider configuration for OR_LEDS v${Version}"
    name           = 'OR_LEDS'
    type           = 'BUNDLE'
    provider       = 'OR_LEDS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# LIMITATION #30: No State initialValue on Vehicle/Person (In vs Out routing).
# =====================================================================

# Vehicle -- VehicleRegistrationQuery
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- DriverLicenseQuery
# No State initialValue (LIMITATION #30)
# ImageIndicator: Y default FormInput
# Standard DL fields only: OLN, Name (First/Last/Middle/Suffix), DOB, Sex, State, Race, ImageIndicator, RelatedHitSearchIndicator
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_3' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '5'  'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_4' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_4' }
                @{ id = 'raceCode_Input';  node = Sel 'raceCode'  'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'imageIndicator_Input';          node = Sel 'imageIndicator'          'Image (Y)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_5' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_PER_5' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DriverLicenseQuery.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- GunQuery
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '23' 'ROW_GUN_1' }
                @{ id = 'gunMake_Input';      node = Sel 'gunMake'      'Make'           @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'gunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm queries -- GunQuery.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article -- ArticleSingleQuery
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '23' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article queries -- ArticleSingleQuery.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat -- BoatQuery
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber'  'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'registrationState_Input';   node = Sel 'registrationState'   'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('12'); fields = @(
                @{ id = 'boatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BoatQuery.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm) `
    -DefaultOrder @('Person','Vehicle','Firearm','Article','Boat')

# =====================================================================
# BUNDLE 3: RMS (from KB specs)
# Patches: 1, 3, 6, 7, 8
# =====================================================================
$rmsBundle = Build-RmsBundle
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built OR_LEDS v${Version}"