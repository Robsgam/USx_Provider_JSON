# build_ca_clets.ps1  -- CA_CLETS
# Builds CA_CLETS.json from source\CA_CLETS.xml metadata + KB specs.
# QIDMs expanded to cover ALL 40 metadata combos (40 built, 0 LIMITATION).
# Layout: Vehicle(2), Person(3), Firearm(1), Article(1), Boat(1) -- 8 cards total
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 QIDMs, 40 combos):
#   VehicleRegistrationQuery   NLTS.RQ(P/V) + IN.VP + IA.QVK + IA.QV + IV.4*(13) + IV.4V = 19 combos
#   DriverLicenseQuery         NLTS.DQ(N/O) + IN.L1 + ID.L1 + IR.QVC(OLN/Name/CriminalId/SSN) = 8 combos
#     IR.QVC OLN: criminalIdNumber promoted from any[] to set[] as routing differentiator vs ID.L1
#   DriverHistoryQuery         NLTS.KQ(N/O) = 2 combos, DH-suffix fields
#   GunQuery                   IG.QGH (name) + IG.QGB (serial) = 2 combos
#   ArticleSingleQuery         IP.QA(S/O) = 2 combos
#   BoatQuery                  NLTS.BQ(N/H/R) + IA.QB(H/O/R) + IV.4B = 7 combos
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_ca_clets.ps1 -Version 2.4

param(
    [string]$Version = "2.4"
)

$ErrorActionPreference = "Stop"
$provider = 'CA_CLETS'
$currentYear = [string](Get-Date).Year
$outPath  = "$PSScriptRoot\..\CA_CLETS.json"

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_CLETS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_CLETS'

$results = Build-ProviderQrdm -ProviderName 'CA_CLETS'

$qmf = Build-Qmf -ProviderName 'CA_CLETS'

# --- 1. VehicleRegistrationQuery -- 19 combos ---
# NLTS.RQ (OOS plate/VIN) + IV.4* (13 plate-type-routed) + IV.4A (PC/AQ fallback)
# + IN.VP (name) + IV.4V (VIN) + IA.QVK (VIN+make) + IA.QV (plate catchall)
# IV.4* combos use conditions on LicensePlateTypeCode to route by plate type.
# IV.4V: same set[] as IA.QVK — ordered after, documented as covered by IA routing superset.
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCity';                  size = 13; sourceField = @('addressCity');                  targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'AddressStreetNumber';          size = 3;  sourceField = @('addressStreetNumber');          targetField = 'AddressStreetNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';        size = 1;  sourceField = @('purposeCode');                  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';           size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 35; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 30; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # --- OOS combos (most specific: State required + NOT CA condition) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState')
                any        = @('vehicleMakeCode','vehicleYear')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'NLTS.RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','vehicleIdentificationNumber','registrationState')
                any        = @('vehicleMakeCode','vehicleYear')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'NLTS.RQ.V'
            state                 = 'In/Out'
        }
        # --- IV.4* plate-type-routed combos (PlateType in set[], conditions differentiate) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('AP') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4I'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('CO','TK','TR') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4C'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('MC') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4M'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('RE','PE') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4L'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('TL') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4T'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('AT') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4F'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('DX') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('EX') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4E'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('DL') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IL.A1'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('AR') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('IP') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber','licensePlateTypeCode')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('TM') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4K'
            state                 = 'In/Out'
        }
        # --- IN.VP name search (cross-entity, set=3, before IV.4A set=2) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst'); any = @('addressCity','addressStreetNumber') }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.VP'
            state                 = 'In/Out'
        }
        # --- IV.4A: PlateType in any[] (PC/AQ fallback when PlateType actively selected) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','licensePlateNumber')
                any        = @('licensePlateTypeCode')
                conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EQUALS'; value = @('PC','AQ') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IV.4A'
            state                 = 'In/Out'
        }
        # --- IV.4V VIN (no optional fields) -- covered by IA.QVK (IA superset of IV routing) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','vehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'IV.4V'
            state                 = 'In/Out'
        }
        # --- IA.QVK VIN + optional make/state ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','vehicleIdentificationNumber'); any = @('vehicleMakeCode','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'IA.QVK'
            state                 = 'In/Out'
        }
        # --- IA.QV plate catchall (no conditions, fires for any plate type not matched above) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','licensePlateNumber')
                any      = @('registrationState','licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IA.QV'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- 19 combos: NLTS.RQ (OOS), IV.4* (plate-type-routed), IV.4A (PC/AQ), IN.VP (name), IV.4V/IA.QVK (VIN), IA.QV (plate catchall).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = "${provider}_VehicleRegistrationQuery"
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = $provider
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# --- 2. DriverLicenseQuery -- 8 combos ---
# NLTS.DQ(N/O) = OOS name/OLN, IN.L1 = name in-state, ID.L1 = OLN in-state,
# IR.QVC(OLN/CriminalId/SSN/Name) = criminal records search.
# IR.QVC OLN: criminalIdNumber promoted from any[] to set[] — differentiates from ID.L1.
#   OLN alone → ID.L1 (DL lookup). OLN + CII → IR.QVC.O (criminal records).
# IR.QVC.Name: broadest fallback (set=[purposeCode] only), fires when no specific combo matches.
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCounty';        size = 3;  sourceField = @('addressCounty');        targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'Age';                   size = 2;  sourceField = @('age');                   targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCode');           targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'CriminalIdNumber';      size = 11; sourceField = @('criminalIdNumber');      targetField = 'CriminalIdNumber' }
        [PSCustomObject]@{ name = 'Height';                size = 3;  sourceField = @('height');                targetField = 'Height' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';              size = 1;  sourceField = @('raceCode');              targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';  size = 9;  sourceField = @('socialSecurityNumber');  targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # --- NLTS.DQ.N: OOS name search (most specific — name + state required + NOT CA) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','nameLast','nameFirst','registrationState')
                any        = @('birthDate')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.DQ.N'
            state                 = 'In/Out'
        }
        # --- NLTS.DQ: OOS OLN search (NOT CA condition) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','operatorLicenseNumber','registrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.DQ'
            state                 = 'In/Out'
        }
        # --- IN.L1: In-state name search (any[] expanded with IR.QVC Name optional fields) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst'); any = @('birthDate','registrationState','sexCode','addressCounty','height','raceCode','age') }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.L1'
            state                 = 'In/Out'
        }
        # --- IR.QVC.OLN: Criminal records by OLN + CII (set=3, before ID.L1 set=2) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','operatorLicenseNumber','criminalIdNumber'); any = @('socialSecurityNumber','age') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'IR.QVC.O'
            state                 = 'In/Out'
        }
        # --- IR.QVC.Name: Criminal records by name (set=3, nameLast+nameFirst promoted to prevent blank-form send) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst'); any = @('addressCounty','height','raceCode','sexCode','age') }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC.N'
            state                 = 'In/Out'
        }
        # --- ID.L1: In-state OLN search (set=2) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','operatorLicenseNumber'); any = @('registrationState','socialSecurityNumber','age') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.L1'
            state                 = 'In/Out'
        }
        # --- IR.QVC.CriminalId: Criminal records by CII (set=2) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','criminalIdNumber'); any = @('operatorLicenseNumber','socialSecurityNumber','age') }
            primaryFieldReference = 'CriminalIdNumber'
            keyReference          = 'IR.QVC.C'
            state                 = 'In/Out'
        }
        # --- IR.QVC.SSN: Criminal records by SSN (set=2) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','socialSecurityNumber'); any = @('criminalIdNumber','operatorLicenseNumber','age') }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'IR.QVC.S'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- 8 combos: NLTS.DQ (OOS name/OLN), IN.L1 (name), ID.L1 (OLN), IR.QVC (OLN+CII/CII/SSN/Name). 100% metadata coverage.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverLicenseQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# DriverHistoryQuery -- PascalCase + DH-suffix fieldIds (AP #14 / LIMITATION #24-25)
# PurposeCode: DH attr maps from CaRequestPurposeCodeDH (DH-suffix form field)
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCodeDH'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCodeDH','birthDateDH','nameLastDH','nameFirstDH','sexCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.KQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCodeDH','operatorLicenseNumberDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.KQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- NLTS.KQ (Name+DOB+Sex), NLTS.KQ (OLN). DH-suffix fields. All via Nlets.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverHistoryQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# GunQuery -- PascalCase + cross-entity (Name for IG.QGH combo)
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IG.QGH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'IG.QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- IG.QGH (name) + IG.QGB (serial). Most-specific first. MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_GunQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# ArticleSingleQuery -- PascalCase
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('purposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','serialNumber'); any = @('articleBrand','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'IP.QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','ownerAppliedNumber'); any = @('articleBrand','articleTypeCode') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IP.QA.O'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- IP.QA (serial, OAN). CA property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_ArticleSingleQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# BoatQuery -- PascalCase + cross-entity (Name+DOB for NLTS.BQ Name combo)
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('purposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # --- NLTS.BQ OOS combos (NOT CA condition) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','nameLast','nameFirst','birthDate','registrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.BQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','boatHullIdNumber','registrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'NLTS.BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','registrationNumber','registrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'NLTS.BQ.R'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'IA.QB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','ownerAppliedNumber'); any = @('registrationState') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IA.QB.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'IA.QB.R'
            state                 = 'In/Out'
        }
        # --- IV.4B: same set[] as IA.QB.R — documented as covered by IA routing superset ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','registrationNumber'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'IV.4B'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- 7 combos: NLTS.BQ OOS (name, hull, reg) + IA.QB (hull, OAN, reg) + IV.4B (covered by IA.QB.R). MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_BoatQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for ${provider} v${Version} MC -- 6 QIDMs, 40 combos, 100% metadata coverage"
    name           = $provider
    type           = 'BUNDLE'
    provider       = $provider
}

# =====================================================================
# BUNDLE 2: ENTITIES (5 QIFs, collapsed card layouts)
#
# Vehicle:  2 cards (OPTIONS + VEHICLE SEARCH)
# Person:   3 cards (OPTIONS + DRIVER LICENSE SEARCH + DRIVER HISTORY SEARCH)
# Firearm:  1 card  (FIREARM SEARCH -- Purpose merged in)
# Article:  1 card  (ARTICLE SEARCH -- Purpose merged in)
# Boat:     1 card  (BOAT SEARCH -- State + Purpose merged in)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState,
# CaRequestPurposeCode) live on a separate card to avoid duplicate fieldId
# across cards (= ISE). NCIC state pattern: visible RegistrationState,
# NO initialValue (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 2 cards (MC collapsed)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# VEHICLE SEARCH: Plate + PlateType + PlateYear + VIN + Make + Year + Name + City + StreetNum
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_VEH_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SEARCH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '30' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_VEH_3' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_VEH_3' }
                @{ id = 'AddressCity_Input';         node = Inp 'addressCity'         'City'           '13' 'ROW_VEH_3' }
                @{ id = 'AddressStreetNumber_Input'; node = Inp 'addressStreetNumber' 'Street Number'  '3'  'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC collapsed: OPTIONS (State + Purpose) + SEARCH (Plate/VIN/Name all on one card)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC collapsed)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by DL combos)
# DRIVER LICENSE SEARCH: OLN + CII + SSN + Name + DOB + Sex + Age + Height + County + Race
# DRIVER HISTORY SEARCH: OLN_DH + PurposeCode_DH + Name_DH + DOB_DH + Sex_DH
# DH-suffix fieldIds isolate DH from DL field pool (AP #14 / LIMITATION #24-25)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_PER_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_DL_1' }
                @{ id = 'CriminalIdNumber_Input';     node = Inp 'criminalIdNumber'     'Criminal ID (CII)' '11' 'ROW_PER_DL_1' }
                @{ id = 'SocialSecurityNumber_Input';  node = Inp 'socialSecurityNumber'  'SSN'               '9'  'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('3','2','2','2','3'); fields = @(
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_DL_3' }
                @{ id = 'Age_Input';            node = Inp 'age'            'Age'    '2' 'ROW_PER_DL_3' }
                @{ id = 'Height_Input';         node = Inp 'height'         'Height' '3' 'ROW_PER_DL_3' }
                @{ id = 'AddressCounty_Input';  node = Inp 'addressCounty'  'County' '3' 'ROW_PER_DL_3' }
                @{ id = 'RaceCode_Input'; node = Sel 'raceCode' 'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('6','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH_1' }
                @{ id = 'PurposeCodeDH_Input';  node = Inp 'purposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_DH_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH_2' }
                @{ id = 'NameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH_2' }
                @{ id = 'BirthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)'                                                                  'ROW_PER_DH_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_DH_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC collapsed: OPTIONS + DL SEARCH (OLN/CII/SSN/Name/DOB/Sex/Age/Height/County/Race) + DH SEARCH (DH-suffix fields).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 2 cards (MC collapsed)
# OPTIONS: CaRequestPurposeCode
# FIREARM SEARCH: Serial + Make + Caliber + Type + Name (cross-entity IG.QGH)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN_SEARCH'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_GUN_2' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_GUN_2' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_GUN_2' @{ initialValue = 'C' } }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC collapsed: OPTIONS (Purpose) + SEARCH (Serial/Make/Caliber/Type/Name)'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (MC collapsed, OPTIONS merged into search)
# ARTICLE SEARCH: Serial + OAN + PurposeCode + ArticleType + Brand
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART_SEARCH'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input';      node = Inp 'serialNumber'      'Serial Number'        '20' 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_ART_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_2' }
                @{ id = 'ArticleBrand_Input';    node = Inp 'articleBrand'    'Brand'        '6'                                                                     'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC collapsed: single card (Serial/OAN/Purpose/Type/Brand)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (MC collapsed, OPTIONS merged into search)
# BOAT SEARCH: Hull + Reg + OAN + Name + DOB + State + PurposeCode
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_SEARCH'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number'  '8'  'ROW_BOA_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_BOA_2' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_BOA_2' }
                @{ id = 'BirthDate_Input'; node = Dt 'birthDate' 'Date of Birth' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_3' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_BOA_3' @{ initialValue = 'C' } }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC collapsed: single card (Hull/Reg/OAN/Name/DOB/State/Purpose)'
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
    bundles = @($entitiesBundle, $caBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $outPath `
    -PhasePath "$PSScriptRoot\..\phases\${provider}.json" `
    -Label "Built ${provider} v${Version} MC"