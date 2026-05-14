# build_az_azdps.ps1
# Builds AZ_AZDPS_BASE.json from source\AZ_AZDPS.xml + HIDLE.json (RMS template).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_az_azdps.ps1
#
# QUERYINPUTDATAMAPPING (CommSys -- 8 QIDMs):
#   VehicleRegistrationQuery         ACVR (Plate+Badge), ACVRV (VIN+Badge -- invented)
#   AzAzdpsDriverLicenseQuery        DQ (OLN), DQN (Name), DQSS (SSN), ACWL (Badge+Name)
#   DriverHistoryQuery               KQ (OLN+State), KQH (Name+State -- invented)
#   GunQuery                         ACQG (Badge+Serial)
#   ArticleSingleQuery               ACQA (Badge+Type+Serial)
#   BoatQuery                        ACQB (Reg+Badge), ACQBH (Hull+Badge), BQ (Reg), BQH (Hull)
#   WMPIWantedPersonInquiry          ACQW (Name+DOB+Sex+Race), ACQWN (NCICNumber -- invented)
#   WMPIMissingPersonInquiry         ACQM (Name+descriptors), ACQMN (NCICNumber -- invented)
#
# ENTITIES (5 QUERYINPUTFORM -- single card each):
#   Vehicle, Person, Firearm, Article, Boat
#
# STATE: NCIC pattern confirmed (attributeTypeId=STATE, codeTypeProvider=NCIC)
# SEX: NIBRS confirmed (attributeTypeId=SEX, codeTypeProvider=NIBRS)
# DH-SUFFIX: OperatorLicenseNumberDH, NameLastDH, etc. -- isolates DH from DL field pool
# BadgeNumber: hidden field auto-populated via dexStateUserId (CommsysGetDexStateUserIdRuleHandler)
# Date format: yyyyMMdd (AZ)

$ErrorActionPreference = "Stop"
$Version = '2.3'
$currentYear = [string](Get-Date).Year
$DIR    = (Resolve-Path "$PSScriptRoot\..").Path
$OUT    = "$DIR\AZ_AZDPS_BASE.json"
$VEROUT = "$DIR\phases\base\AZ_AZDPS_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"
$hidle  = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"

# =====================================================================
# BUNDLE 1: AZ_AZDPS PROVIDER
# =====================================================================

# 1a. AUTHENTICATION
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');       targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic');   targetField = 'Mnemonic' }
        [PSCustomObject]@{
            description = 'dexUserStateid from RMS profile'
            name        = 'UserName'
            rule        = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }
            sourceField = @('dexStateUserId')
            targetField = 'UserName'
        }
    )
    combinations = @(
        [PSCustomObject]@{
            keyReference = 'AUTH'
            requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for AZ AZDPS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'AZ_AZDPS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'AZ_AZDPS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'AZ_AZDPS_Results'
$results.description = 'Results mapping for AZ AZDPS'
$results.provider    = 'AZ_AZDPS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'AZ_AZDPS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'AZ_AZDPS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery -- ACVR (Plate) + ACVRV (VIN, invented)
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';                 size = 4;  sourceField = @('dexStateUserId');            targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');       targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');      targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');          targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('registrationState');         targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');           targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');               targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','licensePlateNumber')
                any = @('licensePlateYear','licensePlateTypeCode','registrationState','vehicleIdentificationNumber','vehicleMakeCode','vehicleYear')
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ACVR'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','vehicleIdentificationNumber')
                any = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState','vehicleMakeCode','vehicleYear')
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ACVRV'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (ACVR Plate + ACVRV VIN)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. AzAzdpsDriverLicenseQuery -- DQ (OLN), DQN (Name), DQSS (SSN), ACWL (Badge+Name)
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';           size = 4;  sourceField = @('dexStateUserId');        targetField = 'BadgeNumber' }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';  size = 9;  sourceField = @('socialSecurityNumber');  targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('registrationState');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','birthDate','nameLast','nameFirst','sexCode')
                any = @('nameMiddle','nameSuffix','operatorLicenseNumber','registrationState','socialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACWL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('nameLast','nameFirst','sexCode','birthDate')
                any = @('dexStateUserId','nameMiddle','nameSuffix','operatorLicenseNumber','registrationState','socialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('operatorLicenseNumber')
                any = @('dexStateUserId','birthDate','nameFirst','nameLast','nameMiddle','nameSuffix','registrationState','sexCode','socialSecurityNumber')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('socialSecurityNumber')
                any = @('dexStateUserId','birthDate','nameFirst','nameLast','nameMiddle','nameSuffix','operatorLicenseNumber','registrationState','sexCode')
            }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'DQSS'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for AzAzdpsDriverLicenseQuery (DQ OLN + DQN Name + DQSS SSN + ACWL Badge)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_AzAzdpsDriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('DriverHistoryQuery')
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'AzAzdpsDriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- KQ (OLN), KQH (Name, invented)
# DH-suffix isolation. StateDH hidden with initialValue='AZ'. Date: yyyyMMdd.
# =====================================================================
$dhistQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention';             size = 30; sourceField = @('attention');               targetField = 'Attention' }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('nameLastDH','nameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCode');             targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('stateDH');                 targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('stateDH','nameLastDH','nameFirstDH','birthDateDH','sexCodeDH')
                any = @('attention','nameMiddleDH','nameSuffixDH','operatorLicenseNumberDH','purposeCode')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('stateDH','operatorLicenseNumberDH')
                any = @('attention','birthDateDH','nameFirstDH','nameLastDH','nameMiddleDH','nameSuffixDH','purposeCode','sexCodeDH')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverHistoryQuery (KQ OLN + KQH Name -- DH-suffix isolation)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('AzAzdpsDriverLicenseQuery')
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery -- ACQG (Badge+Serial)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'GunCaliber';               size = 4;  sourceField = @('gunCaliber');               targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                  size = 4;  sourceField = @('gunMake');                  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                 size = 11; sourceField = @('gunModel');                 targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';          size = 11; sourceField = @('gunSerialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','gunSerialNumber')
                any = @('gunCaliber','gunMake','gunModel','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'ACQG'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery (ACQG)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- ACQA (Badge+Type+Serial)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';      size = 11; sourceField = @('articleSerialNumber');      targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';          size = 7;  sourceField = @('articleTypeCode');          targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','articleTypeCode','articleSerialNumber')
                any = @('relatedHitSearchIndicator')
            }
            primaryFieldReference = 'ArticleTypeCode'
            keyReference          = 'ACQA'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery (ACQA)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- ACQB/ACQBH (Badge), BQ/BQH (no Badge)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';         size = 20; sourceField = @('boatHullIdNumber');         targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';       size = 8;  sourceField = @('registrationNumber');       targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State';                    size = 2;  sourceField = @('registrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','registrationNumber')
                any = @('boatHullIdNumber','registrationState','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ACQB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','boatHullIdNumber')
                any = @('registrationNumber','registrationState','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ACQBH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('registrationNumber')
                any = @('dexStateUserId','boatHullIdNumber','registrationState','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('boatHullIdNumber')
                any = @('dexStateUserId','registrationNumber','registrationState','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQH'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (ACQB+ACQBH Badge, BQ+BQH no-Badge)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# 1j. WMPIWantedPersonInquiry -- ACQW (Name+DOB+Sex+Race), ACQWN (NCIC, invented)
# =====================================================================
$wantedQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('expandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';    size = 1;  sourceField = @('expandedNameSearchCode');    targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('ncicNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                  size = 1;  sourceField = @('raceCode');                  targetField = 'RaceCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                   size = 1;  sourceField = @('sexCode');                   targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('nameLast','nameFirst','birthDate','sexCode','raceCode')
                any = @('expandedBirthDateSearchCode','expandedNameSearchCode','nameMiddle','nameSuffix','ncicNumber','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQW'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('ncicNumber')
                any = @('birthDate','expandedBirthDateSearchCode','expandedNameSearchCode','nameFirst','nameLast','nameMiddle','nameSuffix','raceCode','relatedHitSearchIndicator','sexCode')
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'ACQWN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for WMPIWantedPersonInquiry (ACQW Name+DOB+Sex+Race + ACQWN NCIC)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_WMPIWantedPersonInquiry'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'WMPIWantedPersonInquiry'
    queryLabel      = 'Wanted Person'
    targetEntity    = 'Person'
}

# =====================================================================
# 1k. WMPIMissingPersonInquiry -- ACQM (Name+descriptors), ACQMN (NCIC, invented)
# =====================================================================
$missingQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Age';                      size = 2;  sourceField = @('age');                      targetField = 'Age' }
        [PSCustomObject]@{ name = 'AreaCode';                 size = 3;  sourceField = @('areaCode');                 targetField = 'AreaCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';   size = 1;  sourceField = @('expandedNameSearchCode');   targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{ name = 'EyeColorCode';             size = 3;  sourceField = @('eyeColorCode');             targetField = 'EyeColorCode' }
        [PSCustomObject]@{ name = 'FormORI';                  size = 9;  sourceField = @('formORI');                  targetField = 'FormORI' }
        [PSCustomObject]@{ name = 'HairColorCode';            size = 3;  sourceField = @('hairColorCode');            targetField = 'HairColorCode' }
        [PSCustomObject]@{ name = 'Height';                   size = 3;  sourceField = @('height');                   targetField = 'Height' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';               size = 10; sourceField = @('ncicNumber');               targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                 size = 1;  sourceField = @('raceCode');                 targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                  size = 1;  sourceField = @('sexCode');                  targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'Weight';                   size = 3;  sourceField = @('weight');                   targetField = 'Weight' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('age','sexCode','raceCode','height','weight','eyeColorCode','hairColorCode','nameLast','nameFirst')
                any = @('areaCode','expandedNameSearchCode','formORI','nameMiddle','nameSuffix','ncicNumber','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQM'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('ncicNumber')
                any = @('age','areaCode','expandedNameSearchCode','eyeColorCode','formORI','hairColorCode','height','nameFirst','nameLast','nameMiddle','nameSuffix','raceCode','relatedHitSearchIndicator','sexCode','weight')
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'ACQMN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for WMPIMissingPersonInquiry (ACQM Name+descriptors + ACQMN NCIC)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_WMPIMissingPersonInquiry'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'WMPIMissingPersonInquiry'
    queryLabel      = 'Missing Person'
    targetEntity    = 'Person'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# =====================================================================

# VEHICLE -- 1 card
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','6'); fields = @(
                @{ id = 'LicPlate_Input';  node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'State_Veh_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Veh'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_VEH_BADGE' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'PlateType_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'PlateYear_Input'; node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
                @{ id = 'VIN_Input';       node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'Make_Veh_Input'; node = Sel 'vehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'Year_Veh_Input'; node = Inp 'vehicleYear' 'Year' '4' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate+Badge (ACVR) and VIN+Badge (ACVRV) on single card.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# PERSON -- 1 card (DL + DH + Wanted + Missing all on one card)
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'OLN_Per_Input';   node = Inp 'operatorLicenseNumber' 'License Number (DL)' '20' 'ROW_PER_1' }
                @{ id = 'SSN_Per_Input';   node = Inp 'socialSecurityNumber' 'SSN' '9' 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Per'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_PER_BADGE' }
            )}
            @{ id = 'ROW_PER_1B'; cols = @('6'); fields = @(
                @{ id = 'State_Per_Input'; node = Sel 'registrationState' 'State (DL)' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_PER_1B' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '20' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'M.I.'         '20' 'ROW_PER_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'        '4' 'ROW_PER_3' }
                @{ id = 'BirthDate_Input';  node = Dt  'birthDate'  'Date of Birth'     'ROW_PER_3' }
                @{ id = 'SexCode_Input';    node = Sel 'sexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('8','4'); fields = @(
                @{ id = 'OLN_DH_Input';    node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_4' }
                @{ id = 'Purpose_DH_Input';node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_4B'; cols = @('12'); fields = @(
                @{ id = 'Attention_DH_Input'; node = Inp 'attention' 'Attention (DH)' '30' 'ROW_PER_4B' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_5' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '20' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'M.I. (DH)'    '20' 'ROW_PER_6' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH)'   '4' 'ROW_PER_6' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'birthDateDH'  'DOB (DH)'          'ROW_PER_6' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_6' }
            )}
            @{ id = 'ROW_PER_7'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCIC_Input';    node = Inp 'ncicNumber'             'NCIC Number'        '10' 'ROW_PER_7' }
                @{ id = 'RaceCode_Input';node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_7' }
                @{ id = 'RelHit_Input';  node = Inp 'relatedHitSearchIndicator' 'Related Hit'     '1'  'ROW_PER_7' }
            )}
            @{ id = 'ROW_PER_8'; cols = @('2','2','2','3','3'); fields = @(
                @{ id = 'Age_Input';    node = Inp 'age'    'Age'    '2' 'ROW_PER_8' }
                @{ id = 'Height_Input'; node = Inp 'height' 'Height' '3' 'ROW_PER_8' }
                @{ id = 'Weight_Input'; node = Inp 'weight' 'Weight' '3' 'ROW_PER_8' }
                @{ id = 'Eye_Input';    node = Sel 'eyeColorCode'  'Eye Color'  @{ codeTypeCategory = 'NCIC_EYE_COLOR';  codeTypeSource = 'NCIC' } 'ROW_PER_8' }
                @{ id = 'Hair_Input';   node = Sel 'hairColorCode' 'Hair Color' @{ codeTypeCategory = 'NCIC_HAIR_COLOR'; codeTypeSource = 'NCIC' } 'ROW_PER_8' }
            )}
            @{ id = 'ROW_PER_9'; cols = @('4','4','4'); fields = @(
                @{ id = 'ExpandName_Input'; node = Inp 'expandedNameSearchCode'      'Exp Name Search' '1' 'ROW_PER_9' }
                @{ id = 'ExpandDOB_Input';  node = Inp 'expandedBirthDateSearchCode' 'Exp DOB Search'  '1' 'ROW_PER_9' }
                @{ id = 'AreaCode_Input';   node = Inp 'areaCode'                    'Area Code'       '3' 'ROW_PER_9' }
            )}
            @{ id = 'ROW_PER_10'; cols = @('6'); fields = @(
                @{ id = 'FormORI_Input'; node = Inp 'formORI' 'Form ORI' '9' 'ROW_PER_10' }
            )}
            @{ id = 'ROW_PER_STATE_DH'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'StateDH_Input'; node = InpH 'stateDH' 'State (DH)' $null 'ROW_PER_STATE_DH' @{ initialValue = 'AZ' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL + DH + Wanted + Missing on single card.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# FIREARM -- 1 card (ACQG)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_FA'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_FA_1'; cols = @('12'); fields = @(
                @{ id = 'Serial_FA_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '11' 'ROW_FA_1' }
            )}
            @{ id = 'ROW_FA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_FA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_FA_BADGE' }
            )}
            @{ id = 'ROW_FA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'Make_FA_Input';   node = Sel 'gunMake'    'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_FA_2' }
                @{ id = 'Model_FA_Input';  node = Inp 'gunModel'   'Model'   '11' 'ROW_FA_2' }
                @{ id = 'Cal_FA_Input';    node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_FA_2' }
            )}
            @{ id = 'ROW_FA_3'; cols = @('4'); fields = @(
                @{ id = 'RelHit_FA_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_FA_3' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm queries -- ACQG (Badge+Serial required).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ARTICLE -- 1 card (ACQA)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('5','7'); fields = @(
                @{ id = 'Type_ART_Input';   node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'Serial_ART_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '11' 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_ART'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_ART_BADGE' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4'); fields = @(
                @{ id = 'RelHit_ART_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article queries -- ACQA (Badge+TypeCode+Serial required).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# BOAT -- 1 card
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'Reg_BOA_Input';   node = Inp 'registrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'State_BOA_Input'; node = Sel 'registrationState'  'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_BOA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_BOA_BADGE' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('8','4'); fields = @(
                @{ id = 'Hull_BOA_Input';   node = Inp 'boatHullIdNumber'          'Hull ID Number'  '20' 'ROW_BOA_2' }
                @{ id = 'RelHit_BOA_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit (Y)'  '1' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- ACQB/ACQBH (Badge) and BQ/BQH (no Badge) on single card.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Vehicle','Person','Firearm','Article','Boat')
        CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
        FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE, with AZ patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
if (-not $rmsBundle) {
    $rmsBundle = $hidle.bundles | Where-Object { $_.name -notin @('AZ_AZDPS','ENTITIES') } | Select-Object -First 1
}

$providerConfigs = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhistQuery, $gunQuery, $artQuery, $boatQuery, $wantedQuery, $missingQuery)
$entityConfigs   = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

$final = [PSCustomObject]@{
    bundles = @(
        [PSCustomObject]@{
            name           = 'ENTITIES'
            type           = 'BUNDLE'
            order          = [PSCustomObject]@{
                default         = @('Vehicle','Person','Firearm','Article','Boat')
                CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
                FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
            }
            configurations = $entityConfigs
            provider       = 'MARK43'
        }
        [PSCustomObject]@{
            name           = 'AZ_AZDPS'
            type           = 'BUNDLE'
            description    = "Provider configuration for AZ_AZDPS v${Version}"
            configurations = $providerConfigs
            provider       = 'AZ_AZDPS'
        }
        $rmsBundle
    )
}

# RMS PATCHES

# PATCH 1: Remove LicensePlateYear from RMS Vehicle combination any[] (no elastic mapping)
$rmsVehicleQidm = $final.bundles | Where-Object { $_.name -eq 'RMS' } |
    ForEach-Object { $_.configurations } |
    Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Vehicle' } |
    Select-Object -First 1
if ($rmsVehicleQidm) {
    foreach ($combo in $rmsVehicleQidm.combinations) {
        if ($combo.requirements.any) {
            $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'licensePlateYear' })
        }
    }
}

# PATCH 2: autoSelect=true on all RMS QIDMs
$rmsBundleRef = $final.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
foreach ($cfg in $rmsBundleRef.configurations) {
    if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') {
        $cfg | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
    }
}

# PATCH 3: add registrationState attr to RMS Person QIDM + RegistrationState to all person combo any[]
$rmsPersonQidm = $rmsBundleRef.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'registrationState'
    sourceField    = @('registrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'registrationState'
}

# =====================================================================
# PATCH 6: RMS CLEANUP -- remove unused HIDLE fields
# Vehicle: OOS dual-field plate, Owner search
# Person: OOS-suffixed attrs + combos (no OOS fieldIds on AZ form)
# NOTE: socialSecurityNumber removed from RMS (CommSys DQSS handles SSN directly)
# =====================================================================
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehicleQidm.attributes = @($rmsVehicleQidm.attributes | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehicleQidm.combinations = @($rmsVehicleQidm.combinations | Where-Object {
    $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName')
})
foreach ($combo in $rmsVehicleQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

$deadPerAttrs = @('firstNameOOS','lastNameOOS','dateOfBirthOOS','licenseNumberOOS','sexOOS','socialSecurityNumber')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS',
        'firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS','firstNameLastNameSocialSecurityNumber')
})
foreach ($combo in $rmsPersonQidm.combinations) {
    if ($combo.requirements.set) {
        $combo.requirements.set = @($combo.requirements.set | Where-Object { $_ -ne 'socialSecurityNumber' })
    }
    if ($combo.requirements.any) {
        $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'socialSecurityNumber' })
    }
}

# =====================================================================
# PATCH 9: RMS sourceField camelCase alignment
# HIDLE RMS attrs use PascalCase sourceFields that must match our camelCase form fieldIds.
# Renames sourceField refs in RMS Vehicle + Person QIDMs + combo set[]/any[] arrays.
# =====================================================================
$rmsFieldMap = @{
    'LicensePlateNumber'          = 'licensePlateNumber'
    'LicensePlateTypeCode'        = 'licensePlateTypeCode'
    'LicensePlateYear'            = 'licensePlateYear'
    'RegistrationState'           = 'registrationState'
    'VehicleIdentificationNumber' = 'vehicleIdentificationNumber'
    'VehicleMakeCode'             = 'vehicleMakeCode'
    'VehicleYear'                 = 'vehicleYear'
    'OperatorLicenseNumber'       = 'operatorLicenseNumber'
    'SocialSecurityNumber'        = 'socialSecurityNumber'
    'NameLast'                    = 'nameLast'
    'NameFirst'                   = 'nameFirst'
    'NameMiddle'                  = 'nameMiddle'
    'NameSuffix'                  = 'nameSuffix'
    'BirthDate'                   = 'birthDate'
    'SexCode'                     = 'sexCode'
}
foreach ($cfg in $rmsBundleRef.configurations) {
    if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
    foreach ($attr in $cfg.attributes) {
        if ($attr.sourceField) {
            $attr.sourceField = @($attr.sourceField | ForEach-Object {
                if ($rmsFieldMap.ContainsKey($_)) { $rmsFieldMap[$_] } else { $_ }
            })
        }
    }
    foreach ($combo in $cfg.combinations) {
        if ($combo.requirements.set) {
            $combo.requirements.set = @($combo.requirements.set | ForEach-Object {
                if ($rmsFieldMap.ContainsKey($_)) { $rmsFieldMap[$_] } else { $_ }
            })
        }
        if ($combo.requirements.any) {
            $combo.requirements.any = @($combo.requirements.any | ForEach-Object {
                if ($rmsFieldMap.ContainsKey($_)) { $rmsFieldMap[$_] } else { $_ }
            })
        }
    }
}

# =====================================================================
# OUTPUT
# =====================================================================
$json = $final | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $final | ConvertTo-Json -Depth 100

# Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)
$json = $json -replace 'LicensePlateNumberIn', 'licensePlateNumber'
$jsonReadable = $jsonReadable -replace 'LicensePlateNumberIn', 'licensePlateNumber'

$OUTREADABLE = "$DIR\AZ_AZDPS_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         (New-Object System.Text.UTF8Encoding $false))

Write-Host "Built AZ_AZDPS_BASE.json v${Version}" -ForegroundColor Green
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
# =====================================================================
Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green