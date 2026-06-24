# build_az_azdps_mc.ps1
# Builds AZ_AZDPS_MC.json from source\AZ_AZDPS.xml + tools\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
# MC variant: multi-card layouts (shared OPTIONS cards for shared fields).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_az_azdps_mc.ps1
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
# ENTITIES (5 QUERYINPUTFORM -- multi-card each):
#   Vehicle (3 cards), Person (7 cards), Firearm (1 card), Article (1 card), Boat (3 cards)
#
# STATE: NCIC pattern confirmed (attributeTypeId=STATE, codeTypeProvider=NCIC)
# SEX: NIBRS confirmed (attributeTypeId=SEX, codeTypeProvider=NIBRS)
# DH-SUFFIX: OperatorLicenseNumberDH, NameLastDH, etc. -- isolates DH from DL field pool
# BadgeNumber: hidden field auto-populated via dexStateUserId (CommsysGetDexStateUserIdRuleHandler)
# Date format: yyyyMMdd (AZ)
#
# CRITICAL: Same fieldId CANNOT appear on multiple cards -- causes Internal Server Error.
#           Shared fields (RegistrationState, dexStateUserId) go on shared OPTIONS cards.

$ErrorActionPreference = "Stop"
$Version = '2.3'
$currentYear = [string](Get-Date).Year
$DIR    = (Resolve-Path "$PSScriptRoot\..").Path
$OUT    = "$DIR\AZ_AZDPS_MC.json"
$VEROUT = "$DIR\phases\mc\AZ_AZDPS_MC_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"
. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: AZ_AZDPS PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'AZ_AZDPS'

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'AZ_AZDPS'

$qmf = Build-Qmf -ProviderName 'AZ_AZDPS'

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
        [PSCustomObject]@{ name = 'SocialSecurityNumber';  size = 9;  sourceField = @('SocialSecurityNumber');  targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('registrationState');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','birthDate','nameLast','nameFirst','sexCode')
                any = @('nameMiddle','nameSuffix','operatorLicenseNumber','registrationState','SocialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACWL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('nameLast','nameFirst','sexCode','birthDate')
                any = @('dexStateUserId','nameMiddle','nameSuffix','operatorLicenseNumber','registrationState','SocialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('operatorLicenseNumber')
                any = @('dexStateUserId','birthDate','nameFirst','nameLast','nameMiddle','nameSuffix','registrationState','sexCode','SocialSecurityNumber')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('SocialSecurityNumber')
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
            size        = 30; sourceField = @('nameLastDH','nameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCode');             targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('StateDH');                 targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('StateDH','nameLastDH','nameFirstDH','birthDateDH','sexCodeDH')
                any = @('attention','NameMiddleDH','NameSuffixDH','operatorLicenseNumberDH','purposeCode')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('StateDH','operatorLicenseNumberDH')
                any = @('attention','birthDateDH','nameFirstDH','nameLastDH','NameMiddleDH','NameSuffixDH','purposeCode','sexCodeDH')
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
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('ExpandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';    size = 1;  sourceField = @('ExpandedNameSearchCode');    targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('ncicNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                  size = 1;  sourceField = @('RaceCode');                  targetField = 'RaceCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                   size = 1;  sourceField = @('sexCode');                   targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('nameLast','nameFirst','birthDate','sexCode','RaceCode')
                any = @('ExpandedBirthDateSearchCode','ExpandedNameSearchCode','nameMiddle','nameSuffix','ncicNumber','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQW'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('ncicNumber')
                any = @('birthDate','ExpandedBirthDateSearchCode','ExpandedNameSearchCode','nameFirst','nameLast','nameMiddle','nameSuffix','RaceCode','relatedHitSearchIndicator','sexCode')
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
        [PSCustomObject]@{ name = 'Age';                      size = 2;  sourceField = @('Age');                      targetField = 'Age' }
        [PSCustomObject]@{ name = 'AreaCode';                 size = 3;  sourceField = @('AreaCode');                 targetField = 'AreaCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';   size = 1;  sourceField = @('ExpandedNameSearchCode');   targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{ name = 'EyeColorCode';             size = 3;  sourceField = @('EyeColorCode');             targetField = 'EyeColorCode' }
        [PSCustomObject]@{ name = 'FormORI';                  size = 9;  sourceField = @('FormORI');                  targetField = 'FormORI' }
        [PSCustomObject]@{ name = 'HairColorCode';            size = 3;  sourceField = @('HairColorCode');            targetField = 'HairColorCode' }
        [PSCustomObject]@{ name = 'Height';                   size = 3;  sourceField = @('Height');                   targetField = 'Height' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';               size = 10; sourceField = @('ncicNumber');               targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                 size = 1;  sourceField = @('RaceCode');                 targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                  size = 1;  sourceField = @('sexCode');                  targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'Weight';                   size = 3;  sourceField = @('Weight');                   targetField = 'Weight' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('Age','sexCode','RaceCode','Height','Weight','EyeColorCode','HairColorCode','nameLast','nameFirst')
                any = @('AreaCode','ExpandedNameSearchCode','FormORI','nameMiddle','nameSuffix','ncicNumber','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQM'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('ncicNumber')
                any = @('Age','AreaCode','ExpandedNameSearchCode','EyeColorCode','FormORI','HairColorCode','Height','nameFirst','nameLast','nameMiddle','nameSuffix','RaceCode','relatedHitSearchIndicator','sexCode','Weight')
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
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43) -- MC VARIANT
# =====================================================================

# VEHICLE -- 3 cards: OPTIONS, PLATE SEARCH, VIN SEARCH
# RegistrationState + dexStateUserId on shared OPTIONS card (no duplicate fieldIds)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Select State for OOS queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'State_Veh_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_VEH_OPT_1' }
            )}
            @{ id = 'ROW_VEH_OPT_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Veh'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_VEH_OPT_BADGE' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicPlate_Input';  node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_PLATE_1' }
                @{ id = 'PlateType_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_PLATE_1' }
                @{ id = 'PlateYear_Input'; node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_PLATE_1' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'VIN_Input';       node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_VIN_1' }
                @{ id = 'Make_Veh_Input';  node = Sel 'vehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_VIN_1' }
                @{ id = 'Year_Veh_Input';  node = Inp 'vehicleYear' 'Year' '4' 'ROW_VEH_VIN_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate+Badge (ACVR) and VIN+Badge (ACVRV) on multi-card layout.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# PERSON -- 7 cards: OPTIONS, DL, NAME, DH-OLN, DH-NAME, WANTED/MISSING, MISSING PHYSICAL
# Shared fields: RegistrationState, dexStateUserId, StateDH on OPTIONS card
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'State_Per_Input'; node = Sel 'registrationState' 'State (DL)' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_PER_OPT_1' }
            )}
            @{ id = 'ROW_PER_OPT_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Per'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_PER_OPT_BADGE' }
            )}
            @{ id = 'ROW_PER_OPT_STEDH'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'StateDH_Input'; node = InpH 'StateDH' 'State (DH)' $null 'ROW_PER_OPT_STEDH' @{ initialValue = 'AZ' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DL - LICENSE #'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('6','6'); fields = @(
                @{ id = 'OLN_Per_Input'; node = Inp 'operatorLicenseNumber' 'License Number (DL)' '20' 'ROW_PER_DL_1' }
                @{ id = 'SSN_Per_Input'; node = Inp 'SocialSecurityNumber' 'SSN' '9' 'ROW_PER_DL_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '20' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'M.I.'         '20' 'ROW_PER_NAME_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'        '4' 'ROW_PER_NAME_2' }
                @{ id = 'BirthDate_Input';  node = Dt  'birthDate'  'Date of Birth'     'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';    node = Sel 'sexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DH - LICENSE #'
        rows  = @(
            @{ id = 'ROW_PER_DH_OLN_1'; cols = @('8','4'); fields = @(
                @{ id = 'OLN_DH_Input';     node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH_OLN_1' }
                @{ id = 'Purpose_DH_Input';  node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_PER_DH_OLN_1' }
            )}
            @{ id = 'ROW_PER_DH_OLN_2'; cols = @('12'); fields = @(
                @{ id = 'Attention_DH_Input'; node = Inp 'attention' 'Attention (DH)' '30' 'ROW_PER_DH_OLN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_NAME'
        title = 'DH - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH_NAME_1' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '20' 'ROW_PER_DH_NAME_1' }
            )}
            @{ id = 'ROW_PER_DH_NAME_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'M.I. (DH)'    '20' 'ROW_PER_DH_NAME_2' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix (DH)'   '4' 'ROW_PER_DH_NAME_2' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'birthDateDH'  'DOB (DH)'          'ROW_PER_DH_NAME_2' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_WM'
        title = 'WANTED/MISSING'
        rows  = @(
            @{ id = 'ROW_PER_WM_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCIC_Input';    node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_PER_WM_1' }
                @{ id = 'RaceCode_Input';node = Sel 'RaceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_WM_1' }
                @{ id = 'RelHit_Input';  node = Inp 'relatedHitSearchIndicator' 'Related Hit' '1' 'ROW_PER_WM_1' }
            )}
            @{ id = 'ROW_PER_WM_2'; cols = @('4','4'); fields = @(
                @{ id = 'ExpandName_Input'; node = Inp 'ExpandedNameSearchCode'      'Exp Name Search' '1' 'ROW_PER_WM_2' }
                @{ id = 'ExpandDOB_Input';  node = Inp 'ExpandedBirthDateSearchCode' 'Exp DOB Search'  '1' 'ROW_PER_WM_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_MP'
        title = 'MISSING PHYSICAL'
        rows  = @(
            @{ id = 'ROW_PER_MP_1'; cols = @('2','2','2','3','3'); fields = @(
                @{ id = 'Age_Input';    node = Inp 'Age'    'Age'    '2' 'ROW_PER_MP_1' }
                @{ id = 'Height_Input'; node = Inp 'Height' 'Height' '3' 'ROW_PER_MP_1' }
                @{ id = 'Weight_Input'; node = Inp 'Weight' 'Weight' '3' 'ROW_PER_MP_1' }
                @{ id = 'Eye_Input';    node = Sel 'EyeColorCode'  'Eye Color'  @{ codeTypeCategory = 'NCIC_EYE_COLOR';  codeTypeSource = 'NCIC' } 'ROW_PER_MP_1' }
                @{ id = 'Hair_Input';   node = Sel 'HairColorCode' 'Hair Color' @{ codeTypeCategory = 'NCIC_HAIR_COLOR'; codeTypeSource = 'NCIC' } 'ROW_PER_MP_1' }
            )}
            @{ id = 'ROW_PER_MP_2'; cols = @('4','4'); fields = @(
                @{ id = 'AreaCode_Input'; node = Inp 'AreaCode' 'Area Code' '3' 'ROW_PER_MP_2' }
                @{ id = 'FormORI_Input';  node = Inp 'FormORI'  'Form ORI'  '9' 'ROW_PER_MP_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL + DH + Wanted + Missing on multi-card layout (7 cards).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# FIREARM -- 1 card (same as BASE)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('12'); fields = @(
                @{ id = 'Serial_FA_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_FA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_GUN_BADGE' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'Make_FA_Input';   node = Sel 'gunMake'    'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'Model_FA_Input';  node = Inp 'gunModel'   'Model'   '11' 'ROW_GUN_2' }
                @{ id = 'Cal_FA_Input';    node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('4'); fields = @(
                @{ id = 'RelHit_FA_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_GUN_3' }
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

# ARTICLE -- 1 card (same as BASE)
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

# BOAT -- 3 cards: OPTIONS, REGISTRATION, HULL
# RegistrationState + dexStateUserId on shared OPTIONS card (no duplicate fieldIds)
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'State_BOA_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_BOA_OPT_1' }
            )}
            @{ id = 'ROW_BOA_OPT_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_BOA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_BOA_OPT_BADGE' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('8'); fields = @(
                @{ id = 'Reg_BOA_Input'; node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_REG_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('8','4'); fields = @(
                @{ id = 'Hull_BOA_Input';   node = Inp 'boatHullIdNumber'          'Hull ID Number'  '20' 'ROW_BOA_HULL_1' }
                @{ id = 'RelHit_BOA_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit (Y)'  '1' 'ROW_BOA_HULL_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- ACQB/ACQBH (Badge) and BQ/BQH (no Badge) on multi-card layout.'
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
$rmsBundle = Build-RmsBundle -KeepSsn
# =====================================================================
# FINAL ASSEMBLY
# =====================================================================
$provBundle = [PSCustomObject]@{
    name           = 'AZ_AZDPS'
    type           = 'BUNDLE'
    description    = "Provider configuration for AZ_AZDPS v${Version}"
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhistQuery, $gunQuery, $artQuery, $boatQuery, $wantedQuery, $missingQuery)
    provider       = 'AZ_AZDPS'
}

$final = [PSCustomObject]@{
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

# =====================================================================
# OUTPUT
# =====================================================================
Write-ProviderJson -BundleObject $final -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built AZ_AZDPS v${Version}" `
    -Version $Version

# =====================================================================