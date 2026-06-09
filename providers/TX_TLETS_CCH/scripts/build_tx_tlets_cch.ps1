# build_tx_tlets_cch.ps1  -- TX_TLETS_CCH v1.0  (STUB)
# Separate provider: full base TLETS query package (6 QIDMs, ported from TX_TLETS v3.3)
# PLUS all 8 Computerized Criminal History (CCH) transactions.
#
# CCH design (stub):
#  - Person entity. Every CCH form field is CCH-suffixed (full isolation) -- zero collision
#    with the base DL/DH/OPTIONS fieldIds (duplicate fieldId across cards = ISE).
#  - All 8 CCH QIDMs autoSelect=FALSE, exposed as named checkboxes via queryLabel = transaction.
#    Officer explicitly selects the CCH query; no field-content auto-routing, no co-fire.
#  - 3 CCH cards on the Person QIF: CCH OPTIONS (shared), CCH PERSON, CCH RECORD/ADMIN.
#  - FreeText (AQ/AR, maxLen 14400) is a single-row FormInput -- full XML body, capped footprint.
#  - CCH response/rap-sheet QRDM parsing is OUT OF SCOPE for this stub (queries only).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tx_tlets_cch.ps1

param(
    [string]$Version = "1.0",
    [string]$Phase   = "current"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\TX_TLETS_CCH.json"
$VEROUT   = "$PHASEDIR\TX_TLETS_CCH_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: TX_TLETS_CCH PROVIDER (AUTH + QRDM + QMF + 6 base QIDMs + 8 CCH QIDMs)
# =====================================================================

$auth    = Build-Auth -ProviderName 'TX_TLETS_CCH'
$results = Build-ProviderQrdm -ProviderName 'TX_TLETS_CCH'
$qmf     = Build-Qmf -ProviderName 'TX_TLETS_CCH'

# ---------------------------------------------------------------------
# BASE 6 QIDMs -- ported verbatim from TX_TLETS v3.3 (provider name swapped)
# ---------------------------------------------------------------------

# --- VehicleInsuranceRegistrationQuery (7 combos) ---
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'REG','RQ','VIN','DPSI','QV' for multiple combos; field-name suffixes
# (REGLicensePlateNumber, etc.) are synthetic. NOT real TX TLETS transaction codes.
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'FinancialResponsibilityType'; size = 1;  sourceField = @('financialResponsibilityType'); targetField = 'FinancialResponsibilityType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RegionId';                    size = 4;  sourceField = @('regionId');                    targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'StickerNumber';               size = 10; sourceField = @('stickerNumber');               targetField = 'StickerNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','financialResponsibilityType'); any = @('registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'REGLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode'); any = @('registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','financialResponsibilityType'); any = @('registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'VINVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('stickerNumber'); any = @('registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'StickerNumber'; keyReference = 'DPSIStickerNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('regionId','registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QVLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('registrationState','vehicleMakeCode','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('regionId') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QVVehicleIdentificationNumber'; state = 'In/Out' }
    )
    description = 'VehicleInsuranceRegistrationQuery -- 7 combos (REG/RQ/VIN+FRT/DPSI/QV).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_VehicleInsuranceRegistrationQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'VehicleInsuranceRegistrationQuery'; queryLabel = 'Vehicle Registration'; targetEntity = 'Vehicle'
}

# --- DriverLicenseQuery (7 combos) ---
# PLATFORM CONSTRAINT: LIMITATION #21 -- metadata reuses keyRef 'DQ','QW','CPL'; synthetic
# routing labels (DQNameImg, DQName, etc.). NOT real TX TLETS transaction codes.
$imgCond = @(
    [PSCustomObject]@{ field = @('ImageIndicator'); operator = 'EQUALS'; value = @('Y') }
    [PSCustomObject]@{ field = @('ReasonCode');     operator = 'EQUALS'; value = @('C') }
    [PSCustomObject]@{ field = @('EmailAddress');   operator = 'REGEX';  value = @('.+') }
)
$imgDefs   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'ReasonCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' })
$noImgDefs = @([PSCustomObject]@{ field = 'State'; value = 'TX' })
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('birthDate'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('expandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCode'); targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('reasonCode'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'RegionId'; size = 4; sourceField = @('regionId'); targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('emailAddress','imageIndicator','nameMiddle','nameSuffix','reasonCode','registrationState'); conditions = $imgCond; defaults = $imgDefs }; primaryFieldReference = 'Name'; keyReference = 'DQNameImg'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('nameMiddle','nameSuffix','registrationState'); defaults = $noImgDefs }; primaryFieldReference = 'Name'; keyReference = 'DQName'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('expandedBirthDateSearchCode','nameMiddle','nameSuffix','raceCode','regionId','sexCode') }; primaryFieldReference = 'Name'; keyReference = 'QWName'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('nameLast','nameFirst'); any = @('emailAddress','imageIndicator','nameMiddle','nameSuffix','reasonCode','registrationState'); conditions = $imgCond; defaults = $imgDefs }; primaryFieldReference = 'Name'; keyReference = 'CPLNameImg'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('nameLast','nameFirst'); any = @('nameMiddle','nameSuffix','registrationState'); defaults = $noImgDefs }; primaryFieldReference = 'Name'; keyReference = 'CPLName'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('emailAddress','imageIndicator','reasonCode','registrationState'); conditions = $imgCond; defaults = $imgDefs }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOLNImg'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('registrationState'); defaults = $noImgDefs }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOLN'; state = 'In/Out' }
    )
    description = 'DriverLicenseQuery -- 7 combos (3 image-path + 3 catchall + QW).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_DriverLicenseQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'DriverLicenseQuery'; queryLabel = 'Driver License'; targetEntity = 'Person'
}

# --- DriverHistoryQuery (4 combos) ---
# PLATFORM CONSTRAINT: LIMITATION #21 -- metadata reuses keyRef 'KQ'; synthetic labels
# KQNameImg/KQName/KQOLNImg/KQOLN. NOT real TX TLETS transaction codes.
$imgDefsDH   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }, [PSCustomObject]@{ field = 'ReasonCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' })
$noImgDefsDH = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' })
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionDH'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLastDH','nameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('reasonCode'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @('attentionDH','emailAddress','imageIndicator','nameMiddleDH','nameSuffixDH','purposeCodeDH','reasonCode','registrationState'); conditions = $imgCond; defaults = $imgDefsDH }; primaryFieldReference = 'Name'; keyReference = 'KQNameImg'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @('attentionDH','nameMiddleDH','nameSuffixDH','purposeCodeDH','registrationState'); defaults = $noImgDefsDH }; primaryFieldReference = 'Name'; keyReference = 'KQName'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('attentionDH','emailAddress','imageIndicator','purposeCodeDH','reasonCode','registrationState'); conditions = $imgCond; defaults = $imgDefsDH }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQOLNImg'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('attentionDH','purposeCodeDH','registrationState'); defaults = $noImgDefsDH }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQOLN'; state = 'In/Out' }
    )
    description = 'DriverHistoryQuery -- 4 combos. DH-suffix fields. Attention visible.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_DriverHistoryQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverLicenseQuery'); provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'DriverHistoryQuery'; queryLabel = 'Driver History'; targetEntity = 'Person'
}

# --- GunQuery (2 combos) ---
# PLATFORM CONSTRAINT: LIMITATION #21 -- metadata reuses keyRef 'QG'; synthetic labels
# QGGunSerialNumber/QGNCICNumber. NOT real TX TLETS transaction codes.
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber'; size = 4; sourceField = @('gunCaliber'); targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake'; size = 23; sourceField = @('gunMake'); targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('gunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('ncicNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @('gunCaliber','gunMake','imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'GunSerialNumber'; keyReference = 'QGGunSerialNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'NCICNumber'; keyReference = 'QGNCICNumber'; state = 'In/Out' }
    )
    description = 'GunQuery -- 2 combos (Serial, NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_GunQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'GunQuery'; queryLabel = 'Firearm'; targetEntity = 'Firearm'
}

# --- ArticleSingleQuery (2 combos) ---
# PLATFORM CONSTRAINT: LIMITATION #21 -- metadata reuses keyRef 'QA'; synthetic labels
# QAArticleSerialNumber/QANCICNumber. NOT real TX TLETS transaction codes.
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('articleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode'; size = 7; sourceField = @('articleTypeCode'); targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('ncicNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('articleSerialNumber','articleTypeCode'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'ArticleSerialNumber'; keyReference = 'QAArticleSerialNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'NCICNumber'; keyReference = 'QANCICNumber'; state = 'In/Out' }
    )
    description = 'ArticleSingleQuery -- 2 combos (Serial+Type, NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_ArticleSingleQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'ArticleSingleQuery'; queryLabel = 'Article'; targetEntity = 'Article'
}

# --- BoatQuery (5 combos) ---
# PLATFORM CONSTRAINT: LIMITATION #21 -- metadata reuses keyRef 'BQ','QB'; synthetic labels
# (BQRegistrationNumber, QBBoatHullIdNumber, etc.). NOT real TX TLETS transaction codes.
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber'; size = 20; sourceField = @('boatHullIdNumber'); targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('ncicNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 11; sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('registrationNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'BQRegistrationNumber'; state = 'Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('boatHullIdNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'BQBoatHullIdNumber'; state = 'Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'QBRegistrationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QBBoatHullIdNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'NCICNumber'; keyReference = 'QBNCICNumber'; state = 'In/Out' }
    )
    description = 'BoatQuery -- 5 combos (BQ OOS + QB in-state/NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_BoatQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'BoatQuery'; queryLabel = 'Boat'; targetEntity = 'Boat'
}

# =====================================================================
# CCH QIDMs (8) -- Person entity, autoSelect=false (named-checkbox), CCH-suffixed fields.
# Every CCH form fieldId is suffixed 'CCH' -> zero collision with base Person fields.
# targetField stays the metadata name (XML-facing); only fieldId/sourceField are suffixed.
# =====================================================================

# --- CCHCriminalHistoryAQQuery (AQ) -- admin Nlets message, 1 combo ---
$cchAQ = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionCCH'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'FreeText'; size = 14400; sourceField = @('freeTextCCH'); targetField = 'FreeText' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'NletsDestination'; size = 9; sourceField = @('nletsDestinationCCH'); targetField = 'NletsDestination' }
        [PSCustomObject]@{ name = 'NletsDestination2'; size = 9; sourceField = @('nletsDestination2CCH'); targetField = 'NletsDestination2' }
        [PSCustomObject]@{ name = 'NletsDestination3'; size = 9; sourceField = @('nletsDestination3CCH'); targetField = 'NletsDestination3' }
        [PSCustomObject]@{ name = 'NletsDestination4'; size = 9; sourceField = @('nletsDestination4CCH'); targetField = 'NletsDestination4' }
        [PSCustomObject]@{ name = 'NletsDestination5'; size = 9; sourceField = @('nletsDestination5CCH'); targetField = 'NletsDestination5' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('attentionCCH','freeTextCCH','inquiryReasonCCH','nletsDestinationCCH','purposeCodeCCH'); any = @('nletsDestination2CCH','nletsDestination3CCH','nletsDestination4CCH','nletsDestination5CCH') }; primaryFieldReference = 'FreeText'; keyReference = 'AQ'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryAQQuery -- admin Nlets message (AQ). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryAQQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryAQQuery'; queryLabel = 'CCH Admin Query (AQ)'; targetEntity = 'Person'
}

# --- CCHCriminalHistoryARQuery (AR) -- admin Nlets response, 1 combo ---
$cchAR = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionCCH'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'FreeText'; size = 14400; sourceField = @('freeTextCCH'); targetField = 'FreeText' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'NletsDestination'; size = 9; sourceField = @('nletsDestinationCCH'); targetField = 'NletsDestination' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('attentionCCH','freeTextCCH','inquiryReasonCCH','nletsDestinationCCH','purposeCodeCCH') }; primaryFieldReference = 'FreeText'; keyReference = 'AR'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryARQuery -- admin Nlets response (AR). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryARQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryARQuery'; queryLabel = 'CCH Admin Response (AR)'; targetEntity = 'Person'
}

# --- CCHCriminalHistoryFQQuery (FQ) -- by StateIdNumber, 1 combo ---
$cchFQ = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCityState'; size = 30; sourceField = @('addressCityStateCCH'); targetField = 'AddressCityState' }
        [PSCustomObject]@{ name = 'AddressStreet'; size = 30; sourceField = @('addressStreetCCH'); targetField = 'AddressStreet' }
        [PSCustomObject]@{ name = 'AddressZipCode'; size = 9; sourceField = @('addressZipCodeCCH'); targetField = 'AddressZipCode' }
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionCCH'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'BuildingName'; size = 30; sourceField = @('buildingNameCCH'); targetField = 'BuildingName' }
        [PSCustomObject]@{ name = 'DepartmentName'; size = 30; sourceField = @('departmentNameCCH'); targetField = 'DepartmentName' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'NletsDestination'; size = 2; sourceField = @('nletsDestinationCCH'); targetField = 'NletsDestination' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('stateCCH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'StateIdNumber'; size = 10; sourceField = @('stateIdNumberCCH'); targetField = 'StateIdNumber' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('attentionCCH','inquiryReasonCCH','purposeCodeCCH','stateIdNumberCCH'); any = @('addressCityStateCCH','addressStreetCCH','addressZipCodeCCH','buildingNameCCH','departmentNameCCH','nletsDestinationCCH','stateCCH') }; primaryFieldReference = 'StateIdNumber'; keyReference = 'FQ'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryFQQuery -- by StateIdNumber (FQ). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryFQQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryFQQuery'; queryLabel = 'CCH SID Query (FQ)'; targetEntity = 'Person'
}

# --- CCHCriminalHistoryIQQuery (IQ) -- III by name/DOB/sex, 1 combo ---
$cchIQ = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionCCH'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('birthDateCCH'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'MiscellaneousNumber'; size = 15; sourceField = @('miscellaneousNumberCCH'); targetField = 'MiscellaneousNumber' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'NletsDestination'; size = 2; sourceField = @('nletsDestinationCCH'); targetField = 'NletsDestination' }
        [PSCustomObject]@{ name = 'NletsDestination2'; size = 2; sourceField = @('nletsDestination2CCH'); targetField = 'NletsDestination2' }
        [PSCustomObject]@{ name = 'NletsDestination3'; size = 2; sourceField = @('nletsDestination3CCH'); targetField = 'NletsDestination3' }
        [PSCustomObject]@{ name = 'NletsDestination4'; size = 2; sourceField = @('nletsDestination4CCH'); targetField = 'NletsDestination4' }
        [PSCustomObject]@{ name = 'NletsDestination5'; size = 2; sourceField = @('nletsDestination5CCH'); targetField = 'NletsDestination5' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCodeCCH'); targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeCCH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber'; size = 9; sourceField = @('socialSecurityNumberCCH'); targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('stateCCH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('attentionCCH','birthDateCCH','inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','sexCodeCCH'); any = @('miscellaneousNumberCCH','nameMiddleCCH','nameSuffixCCH','nletsDestinationCCH','nletsDestination2CCH','nletsDestination3CCH','nletsDestination4CCH','nletsDestination5CCH','raceCodeCCH','socialSecurityNumberCCH','stateCCH') }; primaryFieldReference = 'Name'; keyReference = 'IQ'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryIQQuery -- III name/DOB/sex (IQ). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryIQQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryIQQuery'; queryLabel = 'CCH Name Inquiry (IQ)'; targetEntity = 'Person'
}

# --- CCHCriminalHistoryQHQuery (QH) -- core criminal history, 5 combos ---
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21/#36).
# Metadata uses keyRef 'QH' for all combos, with a <Choice>(SSN|Misc) on the Name path;
# synthetic labels QH.BDOB / QH.NAME.SSN / QH.NAME.MISC / QH.SID / QH.FBI split the Choice and
# differentiate routing. NOT real TX TLETS transaction codes. See PLATFORM_CONSTRAINTS.txt.
$cchQH = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('birthDateCCH'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'FBINumber'; size = 9; sourceField = @('fbiNumberCCH'); targetField = 'FBINumber' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'MiscellaneousNumber'; size = 15; sourceField = @('miscellaneousNumberCCH'); targetField = 'MiscellaneousNumber' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'Operator'; size = 30; sourceField = @('operatorCCH'); targetField = 'Operator' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCodeCCH'); targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'Requestor'; size = 30; sourceField = @('requestorCCH'); targetField = 'Requestor' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeCCH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber'; size = 9; sourceField = @('socialSecurityNumberCCH'); targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'StateIdNumber'; size = 10; sourceField = @('stateIdNumberCCH'); targetField = 'StateIdNumber' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('requestorCCH','operatorCCH','birthDateCCH','inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','sexCodeCCH','raceCodeCCH'); any = @('miscellaneousNumberCCH','socialSecurityNumberCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'BirthDate'; keyReference = 'QH.BDOB'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('requestorCCH','operatorCCH','inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','socialSecurityNumberCCH'); any = @('nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'Name'; keyReference = 'QH.NAME.SSN'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('requestorCCH','operatorCCH','inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','miscellaneousNumberCCH'); any = @('nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'Name'; keyReference = 'QH.NAME.MISC'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','requestorCCH','operatorCCH','stateIdNumberCCH','purposeCodeCCH'); any = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'StateIdNumber'; keyReference = 'QH.SID'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','requestorCCH','operatorCCH','fbiNumberCCH','purposeCodeCCH'); any = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'FBINumber'; keyReference = 'QH.FBI'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryQHQuery -- 5 combos (BDOB/Name+SSN/Name+Misc/SID/FBI; Choice split). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryQHQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryQHQuery'; queryLabel = 'CCH Criminal History (QH)'; targetEntity = 'Person'
}

# --- CCHCriminalHistoryQRQuery (QR) -- record request by SID/FBI, 2 combos ---
# PLATFORM CONSTRAINT: LIMITATION #21 -- metadata reuses keyRef 'QR'; synthetic labels
# QR.FBI / QR.SID differentiate routing. NOT real TX TLETS transaction codes.
$cchQR = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCityState'; size = 30; sourceField = @('addressCityStateCCH'); targetField = 'AddressCityState' }
        [PSCustomObject]@{ name = 'AddressStreet'; size = 30; sourceField = @('addressStreetCCH'); targetField = 'AddressStreet' }
        [PSCustomObject]@{ name = 'AddressZipCode'; size = 9; sourceField = @('addressZipCodeCCH'); targetField = 'AddressZipCode' }
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionCCH'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'BuildingName'; size = 30; sourceField = @('buildingNameCCH'); targetField = 'BuildingName' }
        [PSCustomObject]@{ name = 'DepartmentName'; size = 30; sourceField = @('departmentNameCCH'); targetField = 'DepartmentName' }
        [PSCustomObject]@{ name = 'FBINumber'; size = 9; sourceField = @('fbiNumberCCH'); targetField = 'FBINumber' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'StateIdNumber'; size = 10; sourceField = @('stateIdNumberCCH'); targetField = 'StateIdNumber' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('attentionCCH','fbiNumberCCH','inquiryReasonCCH','purposeCodeCCH'); any = @('addressCityStateCCH','addressStreetCCH','addressZipCodeCCH','buildingNameCCH','departmentNameCCH','nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'FBINumber'; keyReference = 'QR.FBI'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('attentionCCH','inquiryReasonCCH','purposeCodeCCH','stateIdNumberCCH'); any = @('addressCityStateCCH','addressStreetCCH','addressZipCodeCCH','buildingNameCCH','departmentNameCCH','nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'StateIdNumber'; keyReference = 'QR.SID'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryQRQuery -- 2 combos (FBI, SID). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryQRQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryQRQuery'; queryLabel = 'CCH Record Request (QR)'; targetEntity = 'Person'
}

# --- CCHCriminalHistoryQWIQuery (QWI) -- wanted/III with image, 3 combos ---
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21/#36).
# Metadata uses keyRef 'QWI' with a <Choice>[(BirthDate,Race,Sex) | Misc | SSN]; synthetic
# labels QWI.DOB / QWI.MISC / QWI.SSN split the Choice. NOT real TX TLETS transaction codes.
$cchQWI = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionCCH'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('birthDateCCH'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('expandedBirthDateSearchCodeCCH'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchIndicator'; size = 1; sourceField = @('expandedNameSearchIndicatorCCH'); targetField = 'ExpandedNameSearchIndicator' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicatorCCH'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'MiscellaneousNumber'; size = 15; sourceField = @('miscellaneousNumberCCH'); targetField = 'MiscellaneousNumber' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'Operator'; size = 30; sourceField = @('operatorCCH'); targetField = 'Operator' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCodeCCH'); targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicatorCCH'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeCCH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber'; size = 9; sourceField = @('socialSecurityNumberCCH'); targetField = 'SocialSecurityNumber' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','attentionCCH','operatorCCH','birthDateCCH','raceCodeCCH','sexCodeCCH'); any = @('expandedBirthDateSearchCodeCCH','expandedNameSearchIndicatorCCH','imageIndicatorCCH','relatedHitSearchIndicatorCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'Name'; keyReference = 'QWI.DOB'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','attentionCCH','operatorCCH','miscellaneousNumberCCH'); any = @('expandedNameSearchIndicatorCCH','imageIndicatorCCH','relatedHitSearchIndicatorCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'Name'; keyReference = 'QWI.MISC'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','attentionCCH','operatorCCH','socialSecurityNumberCCH'); any = @('expandedNameSearchIndicatorCCH','imageIndicatorCCH','relatedHitSearchIndicatorCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'Name'; keyReference = 'QWI.SSN'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryQWIQuery -- 3 combos (DOB/Misc/SSN Choice split). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryQWIQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryQWIQuery'; queryLabel = 'CCH Wanted/III (QWI)'; targetEntity = 'Person'
}

# --- CCHCriminalHistoryZRQuery (ZR) -- record request by FBI/SID, 2 combos ---
# PLATFORM CONSTRAINT: LIMITATION #21 -- metadata reuses keyRef 'ZR'; synthetic labels
# ZR.FBI / ZR.SID differentiate routing. NOT real TX TLETS transaction codes.
$cchZR = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'FBINumber'; size = 9; sourceField = @('fbiNumberCCH'); targetField = 'FBINumber' }
        [PSCustomObject]@{ name = 'InquiryReason'; size = 75; sourceField = @('inquiryReasonCCH'); targetField = 'InquiryReason' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeCCH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'StateIdNumber'; size = 10; sourceField = @('stateIdNumberCCH'); targetField = 'StateIdNumber' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('fbiNumberCCH','inquiryReasonCCH'); any = @('purposeCodeCCH') }; primaryFieldReference = 'FBINumber'; keyReference = 'ZR.FBI'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('stateIdNumberCCH','inquiryReasonCCH'); any = @('purposeCodeCCH') }; primaryFieldReference = 'StateIdNumber'; keyReference = 'ZR.SID'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryZRQuery -- 2 combos (FBI, SID). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryZRQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryZRQuery'; queryLabel = 'CCH Record Request (ZR)'; targetEntity = 'Person'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery,
                       $cchAQ, $cchAR, $cchFQ, $cchIQ, $cchQH, $cchQR, $cchQWI, $cchZR)
    description    = "Provider configuration for TX_TLETS_CCH v$Version"
    name           = 'TX_TLETS_CCH'
    type           = 'BUNDLE'
    provider       = 'TX_TLETS_CCH'
}

# =====================================================================
# BUNDLE 2: ENTITIES (Vehicle, Person [base 3 cards + 3 CCH cards], Firearm, Article, Boat)
# =====================================================================

# Vehicle -- 1 card
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE QUERY'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'licensePlateNumber_Input';  node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                @{ id = 'stickerNumber_Input';               node = Inp 'stickerNumber' 'Sticker Number' '10' 'ROW_VEH_2' }
                @{ id = 'financialResponsibilityType_Input'; node = Inp 'financialResponsibilityType' 'Fin. Resp. Type' '1' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'vehicleMakeCode_Input';   node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'vehicleYear_Input';       node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_3' }
                @{ id = 'registrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'TX' } 'ROW_VEH_3' }
                @{ id = 'regionId_Input';          node = Inp 'regionId' 'Region ID' '4' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{ description = 'Vehicle queries -- single card.'; label = 'Vehicle'; layout = $vehLayout; name = 'ENTITY_Vehicle'; type = 'QUERYINPUTFORM'; targetEntity = 'Vehicle' }

# Person -- base 3 cards (OPTIONS, DL, DH) + 3 CCH cards (OPT, PERSON, RECORD)
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'SEARCH OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_O1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'registrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'TX' } 'ROW_PER_O1' }
                @{ id = 'imageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_O1' }
                @{ id = 'reasonCode_Input';        node = Inp 'reasonCode' 'Reason Code' '1' 'ROW_PER_O1' @{ initialValue = 'C' } }
                @{ id = 'emailAddress_Input';      node = Inp 'emailAddress' 'Email Address' '80' 'ROW_PER_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE'
        rows  = @(
            @{ id = 'ROW_PER_L1'; cols = @('6','3','3'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_L1' }
                @{ id = 'birthDate_Input';             node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_L1' }
                @{ id = 'sexCode_Input';               node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_L1' }
            )}
            @{ id = 'ROW_PER_N1'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'nameLast_Input';   node = Inp 'nameLast'   'Last Name'   '30' 'ROW_PER_N1' }
                @{ id = 'nameFirst_Input';  node = Inp 'nameFirst'  'First Name'  '30' 'ROW_PER_N1' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_N1' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '30' 'ROW_PER_N1' }
            )}
            @{ id = 'ROW_PER_N2'; cols = @('4','4','4'); fields = @(
                @{ id = 'raceCode_Input';                   node = Sel 'raceCode' 'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_N2' }
                @{ id = 'expandedBirthDateSearchCode_Input'; node = Inp 'expandedBirthDateSearchCode' 'Expanded DOB' '1' 'ROW_PER_N2' }
                @{ id = 'regionId_Input';                   node = Inp 'regionId' 'Region ID' '4' 'ROW_PER_N2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY'
        rows  = @(
            @{ id = 'ROW_PER_DHL1'; cols = @('6','2','4'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DHL1' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose (DH)' '1' 'ROW_PER_DHL1' @{ initialValue = 'C' } }
                @{ id = 'attentionDH_Input';             node = Inp 'attentionDH' 'Attention (DH)' '30' 'ROW_PER_DHL1' }
            )}
            @{ id = 'ROW_PER_DHN1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'nameLastDH_Input';   node = Inp 'nameLastDH'   'Last Name (DH)'   '30' 'ROW_PER_DHN1' }
                @{ id = 'nameFirstDH_Input';  node = Inp 'nameFirstDH'  'First Name (DH)'  '30' 'ROW_PER_DHN1' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH)' '30' 'ROW_PER_DHN1' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH)'      '30' 'ROW_PER_DHN1' }
            )}
            @{ id = 'ROW_PER_DHN2'; cols = @('3','3'); fields = @(
                @{ id = 'birthDateDH_Input';    node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_DHN2' }
                @{ id = 'sexCodeDH_Input';      node = Sel 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DHN2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_CCH_OPT'
        title = 'CCH OPTIONS (RESTRICTED -- Criminal History)'
        rows  = @(
            @{ id = 'ROW_CCH_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'attentionCCH_Input';     node = Inp 'attentionCCH' 'Attention (CCH)' '30' 'ROW_CCH_O1' }
                @{ id = 'inquiryReasonCCH_Input'; node = Inp 'inquiryReasonCCH' 'Inquiry Reason (CCH)' '75' 'ROW_CCH_O1' }
                @{ id = 'purposeCodeCCH_Input';   node = Inp 'purposeCodeCCH' 'Purpose Code (CCH)' '1' 'ROW_CCH_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_CCH_PERSON'
        title = 'CCH PERSON / CRIMINAL HISTORY (RESTRICTED)'
        rows  = @(
            @{ id = 'ROW_CCH_P1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'nameLastCCH_Input';   node = Inp 'nameLastCCH'   'Last Name (CCH)'   '30' 'ROW_CCH_P1' }
                @{ id = 'nameFirstCCH_Input';  node = Inp 'nameFirstCCH'  'First Name (CCH)'  '30' 'ROW_CCH_P1' }
                @{ id = 'nameMiddleCCH_Input'; node = Inp 'nameMiddleCCH' 'Middle Name (CCH)' '30' 'ROW_CCH_P1' }
                @{ id = 'nameSuffixCCH_Input'; node = Inp 'nameSuffixCCH' 'Suffix (CCH)'      '30' 'ROW_CCH_P1' }
            )}
            @{ id = 'ROW_CCH_P2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'birthDateCCH_Input'; node = Dt  'birthDateCCH' 'DOB (CCH)' 'ROW_CCH_P2' }
                @{ id = 'sexCodeCCH_Input';   node = Sel 'sexCodeCCH' 'Sex (CCH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_CCH_P2' }
                @{ id = 'raceCodeCCH_Input';  node = Sel 'raceCodeCCH' 'Race (CCH)' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_CCH_P2' }
                @{ id = 'stateCCH_Input';     node = Sel 'stateCCH' 'State (CCH)' @{ attributeTypeId = 'STATE' } 'ROW_CCH_P2' }
            )}
            @{ id = 'ROW_CCH_P3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'socialSecurityNumberCCH_Input'; node = Inp 'socialSecurityNumberCCH' 'SSN (CCH)' '9' 'ROW_CCH_P3' }
                @{ id = 'miscellaneousNumberCCH_Input';  node = Inp 'miscellaneousNumberCCH' 'Misc Number (CCH)' '15' 'ROW_CCH_P3' }
                @{ id = 'fbiNumberCCH_Input';            node = Inp 'fbiNumberCCH' 'FBI Number (CCH)' '9' 'ROW_CCH_P3' }
                @{ id = 'stateIdNumberCCH_Input';        node = Inp 'stateIdNumberCCH' 'State ID / SID (CCH)' '10' 'ROW_CCH_P3' }
            )}
            @{ id = 'ROW_CCH_P4'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'operatorCCH_Input';                    node = Inp 'operatorCCH' 'Operator (CCH)' '30' 'ROW_CCH_P4' }
                @{ id = 'requestorCCH_Input';                   node = Inp 'requestorCCH' 'Requestor (CCH)' '30' 'ROW_CCH_P4' }
                @{ id = 'expandedBirthDateSearchCodeCCH_Input'; node = Inp 'expandedBirthDateSearchCodeCCH' 'Expanded DOB (CCH)' '1' 'ROW_CCH_P4' }
                @{ id = 'expandedNameSearchIndicatorCCH_Input'; node = Inp 'expandedNameSearchIndicatorCCH' 'Expanded Name (CCH)' '1' 'ROW_CCH_P4' }
            )}
            @{ id = 'ROW_CCH_P5'; cols = @('6','6'); fields = @(
                @{ id = 'imageIndicatorCCH_Input';            node = Sel 'imageIndicatorCCH' 'Image (CCH)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_CCH_P5' }
                @{ id = 'relatedHitSearchIndicatorCCH_Input'; node = Sel 'relatedHitSearchIndicatorCCH' 'Related Hit Search (CCH)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_CCH_P5' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_CCH_RECORD'
        title = 'CCH RECORD REQUEST / ADMIN (RESTRICTED)'
        rows  = @(
            @{ id = 'ROW_CCH_R1'; cols = @('4','4','4'); fields = @(
                @{ id = 'addressStreetCCH_Input';    node = Inp 'addressStreetCCH' 'Address Street (CCH)' '30' 'ROW_CCH_R1' }
                @{ id = 'addressCityStateCCH_Input'; node = Inp 'addressCityStateCCH' 'City/State (CCH)' '30' 'ROW_CCH_R1' }
                @{ id = 'addressZipCodeCCH_Input';   node = Inp 'addressZipCodeCCH' 'Zip (CCH)' '9' 'ROW_CCH_R1' }
            )}
            @{ id = 'ROW_CCH_R2'; cols = @('6','6'); fields = @(
                @{ id = 'buildingNameCCH_Input';   node = Inp 'buildingNameCCH' 'Building (CCH)' '30' 'ROW_CCH_R2' }
                @{ id = 'departmentNameCCH_Input'; node = Inp 'departmentNameCCH' 'Department (CCH)' '30' 'ROW_CCH_R2' }
            )}
            @{ id = 'ROW_CCH_R3'; cols = @('4','4','4'); fields = @(
                @{ id = 'nletsDestinationCCH_Input';  node = Inp 'nletsDestinationCCH' 'Nlets Dest (CCH)' '9' 'ROW_CCH_R3' }
                @{ id = 'nletsDestination2CCH_Input'; node = Inp 'nletsDestination2CCH' 'Nlets Dest 2 (CCH)' '9' 'ROW_CCH_R3' }
                @{ id = 'nletsDestination3CCH_Input'; node = Inp 'nletsDestination3CCH' 'Nlets Dest 3 (CCH)' '9' 'ROW_CCH_R3' }
            )}
            @{ id = 'ROW_CCH_R4'; cols = @('3','3','6'); fields = @(
                @{ id = 'nletsDestination4CCH_Input'; node = Inp 'nletsDestination4CCH' 'Nlets Dest 4 (CCH)' '9' 'ROW_CCH_R4' }
                @{ id = 'nletsDestination5CCH_Input'; node = Inp 'nletsDestination5CCH' 'Nlets Dest 5 (CCH)' '9' 'ROW_CCH_R4' }
                @{ id = 'freeTextCCH_Input';          node = Inp 'freeTextCCH' 'Free Text / Admin Message (CCH)' '14400' 'ROW_CCH_R4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{ description = 'Person queries -- base (OPTIONS+DL+DH) + 3 CCH cards (OPT/PERSON/RECORD), CCH-suffixed, manual-select.'; label = 'Person'; layout = $perLayout; name = 'ENTITY_Person'; type = 'QUERYINPUTFORM'; targetEntity = 'Person' }

# Firearm -- 1 card
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'gunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'gunMake_Input';         node = Sel 'gunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'gunCaliber_Input';                node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'ncicNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_GUN_2' }
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{ description = 'Firearm query -- QG (Serial/NCIC).'; label = 'Firearm'; layout = $faLayout; name = 'ENTITY_Firearm'; type = 'QUERYINPUTFORM'; targetEntity = 'Firearm' }

# Article -- 1 card
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'articleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ncicNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_ART_2' }
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{ description = 'Article query -- QA (Serial+Type / NCIC).'; label = 'Article'; layout = $artLayout; name = 'ENTITY_Article'; type = 'QUERYINPUTFORM'; targetEntity = 'Article' }

# Boat -- 1 card
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT QUERY'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'registrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '11' 'ROW_BOA_1' }
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'ncicNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_BOA_2' }
                @{ id = 'registrationState_Input';         node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{ description = 'Boat queries -- single card.'; label = 'Boat'; layout = $boaLayout; name = 'ENTITY_Boat'; type = 'QUERYINPUTFORM'; targetEntity = 'Boat' }

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (shared module -- camelCase, registrationState, -SkipRace)
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{ bundles = @($entitiesBundle, $provBundle, $rmsBundle) }

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built TX_TLETS_CCH v${Version}"

Write-Host ""
Write-Host "Build complete. TX_TLETS_CCH v${Version} -- 14 QIDMs (6 base + 8 CCH), Person CCH cards CCH-suffixed."
