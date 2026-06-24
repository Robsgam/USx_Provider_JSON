# build_tx_tlets.ps1  -- TX_TLETS v3.13
# Single build. 6 cards (Vehicle 1, Person 3, Firearm 1, Article 1, Boat 1).
# 24 CommSys combos: 7 VehReg + 4 DL + 4 DH + 2 Gun + 2 Article + 5 Boat
# v3.13: Gap-audit remediation. (1) Hull>Reg guardrail COMPLETED -- added boatHullIdNumber
#        NOT_EXISTS to BQRegistrationNumber (the OOS Nlets Reg combo; v3.12 only covered the
#        in-state QBRegistrationNumber, so Hull+Reg+State OOS co-entry still bled Reg into Hull
#        XML). (2) CAD plate-default gap -- REG/RQ plate combos require licensePlateYear (REG) and
#        licensePlateYear+licensePlateTypeCode (RQ) in set[] but CAD ignores form initialValue, so
#        CAD-dispatched plate queries could not fire; added LicensePlateYear=$currentYear and
#        LicensePlateTypeCode=PC combo defaults (audit_cad CHECK 6 now scans set[] too).
# v3.12: Identifier-priority guardrail (Plate>VIN, OLN>Name DL+DH, Hull>Reg). All 3 pairs:
#        licensePlateNumber NOT_EXISTS on 3 VIN combos; operatorLicenseNumber NOT_EXISTS on
#        DQName/QWName/CPLName; operatorLicenseNumberDH NOT_EXISTS on KQNameImg/KQName;
#        boatHullIdNumber NOT_EXISTS on QBRegistrationNumber. vehicleYear added to
#        VINVehicleIdentificationNumber any[]. Attention gate-feeder added (DH hidden InpH
#        + 'Attention' in all 4 DH combo any[] -- handler was wired but pool excluded it).
#        conditions[].field = camelCase QIF sourceField (live-proven HI/FL pattern).
# v3.8: Restore 4-combo DH structure (v3.3 shape, corrected mechanism). devdoc requires
#       Email ONLY when ImageIndicator=Y -- not always. v3.7 over-restricted (blocked legal
#       no-photo path). Fix: Image/plain variant pairs (per Name, per OLN). Image variants
#       put imageIndicator+reasonCode in any[] and require emailAddress in set[]. Plain
#       variants exclude image/email/reason from pool entirely (union-exclusion semantics --
#       NJ live-proven: a populated field in only non-matching combos is dropped).
#       Result: Image=Y can serialize ONLY when email is present. Name/OLN-alone fires
#       the plain combo with no photo. CAD DH fires plain path (no email source). LA_LEMS
#       DP/DQ is the portfolio precedent for conditions-free image-variant splitting.
# v3.7: DH emailAddress to set[] on both combos (over-restrictive; blocked no-photo path).
# v3.6: Revert DH ImageIndicator default N→Y. Design intent: ImageIndicator=Y is preferred
#       on all DH queries (officers want photo). EmailAddress is a visible FormInput; officers
#       fill it manually until the email-injection handler is available (dexUserId-style).
#       ReasonCode=C default already satisfies the second ImageIndicator=Y constraint (devdoc).
# v3.5: DH ImageIndicator default Y→N (erroneous; v3.5 never imported; reverted in v3.6).
# v3.4: POISONED-ARRAY fix -- removed inert ImageIndicator EQUALS Y conditions; merged
#       Img/catchall combo pairs (DL 7->4, DH 4->2); image/email/reason kept in any[].
# v3.2: email→OPTIONS (shared).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tx_tlets.ps1

param(
    [string]$Version = "3.13",
    [string]$Phase   = "current"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\TX_TLETS.json"
$VEROUT   = "$PHASEDIR\TX_TLETS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: TX_TLETS PROVIDER (AUTH + QRDM + QMF + 6 QIDMs)
# =====================================================================

$auth    = Build-Auth -ProviderName 'TX_TLETS'
$results = Build-ProviderQrdm -ProviderName 'TX_TLETS'
$qmf     = Build-Qmf -ProviderName 'TX_TLETS'

# --- VehicleInsuranceRegistrationQuery (7 combos) ---
# Combo order: most-specific first (3 set > 2 set > 1 set)
# REG/RQ plate need Year+FRT/PlateType; VIN+FRT needs FRT; DPSI isolated; QV catchalls last
# QV VIN unreachable after RQ VIN (same set[VIN]) -- LIMITATION
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'REG', 'RQ', 'VIN', 'DPSI', 'QV' for multiple combos each;
# field-name suffixes (REGLicensePlateNumber, RQLicensePlateNumber, etc.) are synthetic.
# NOT real TX TLETS transaction codes. See PLATFORM_CONSTRAINTS.txt.
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
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','financialResponsibilityType'); any = @('registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'REGLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode'); any = @('registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','financialResponsibilityType'); any = @('registrationState','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }); conditions = @([PSCustomObject]@{ field = @('licensePlateNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'VINVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('stickerNumber'); any = @('registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'StickerNumber'; keyReference = 'DPSIStickerNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('regionId','registrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QVLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('registrationState','vehicleMakeCode','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }); conditions = @([PSCustomObject]@{ field = @('licensePlateNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('regionId'); conditions = @([PSCustomObject]@{ field = @('licensePlateNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QVVehicleIdentificationNumber'; state = 'In/Out' }
    )
    description = 'VehicleInsuranceRegistrationQuery -- 7 combos (REG/RQ/VIN+FRT/DPSI/QV).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_VehicleInsuranceRegistrationQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'VehicleInsuranceRegistrationQuery'; queryLabel = 'Vehicle Registration'; targetEntity = 'Vehicle'
}

# --- DriverLicenseQuery (4 combos) ---
# v3.4: POISONED-ARRAY fix. v3.2 gated "image-path" combos with `ImageIndicator EQUALS Y` +
# ReasonCode/EmailAddress conditions -- but value-comparison conditions are INERT on the platform
# (QIDM_REFERENCE Sec 2a), so each Img combo and its catchall twin (identical set[]) both fired =>
# union over-send. Fix: merge each pair into ONE combo per path; image/email/reason stay in any[]
# (sent when populated); defaults inject ImageIndicator=Y + ReasonCode=C (covers CAD). Email is
# manually entered for now (future email-injection handler TBD). All query paths preserved.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'DQ', 'QW', 'CPL'; field-name suffixes (DQName, DQOLN, CPLName) synthetic.
$imgDefs = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'ReasonCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' })
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
        # DQ Name (merged v3.4 -- image/email/reason in any[], no poisoned conditions)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('emailAddress','imageIndicator','nameMiddle','nameSuffix','reasonCode','registrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('operatorLicenseNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'DQName'; state = 'In/Out' }
        # QW Name -- unchanged (no image/email)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('expandedBirthDateSearchCode','nameMiddle','nameSuffix','raceCode','regionId','sexCode'); conditions = @([PSCustomObject]@{ field = @('operatorLicenseNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'QWName'; state = 'In/Out' }
        # CPL Name (merged v3.4)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('nameLast','nameFirst'); any = @('emailAddress','imageIndicator','nameMiddle','nameSuffix','reasonCode','registrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('operatorLicenseNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'CPLName'; state = 'In/Out' }
        # DQ OLN (merged v3.4)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('emailAddress','imageIndicator','reasonCode','registrationState'); defaults = $imgDefs }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOLN'; state = 'In/Out' }
    )
    description = 'DriverLicenseQuery -- 4 combos (DQName, QWName, CPLName, DQOLN). v3.4: poisoned conditions removed; image/email/reason in any[].'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverLicenseQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverLicenseQuery'; queryLabel = 'Driver License'; targetEntity = 'Person'
}

# --- DriverHistoryQuery (4 combos) ---
# v3.8: Image-variant split (restores v3.3 4-combo shape; corrected mechanism).
# devdoc: Email required ONLY when ImageIndicator=Y (not always). v3.7 over-restricted.
# Image variants (KQNameImg, KQOLNImg): emailAddress in set[]; imageIndicator+reasonCode in
# any[]. Plain variants (KQName, KQOLN): no image/email/reason in pool.
# Union-exclusion semantics: imageIndicator lives ONLY in Image-variant any[]. When email is
# absent the Image variant doesn't match -> imageIndicator excluded from XML (legal Blank).
# Image=Y therefore can NEVER serialize without email. LA_LEMS DP/DQ is the precedent.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'KQ'; synthetic labels KQNameImg/KQName/KQOLNImg/KQOLN. See PLATFORM_CONSTRAINTS.txt.
# ReasonCode=C default (in imgDefsDH) satisfies the second ImageIndicator=Y constraint per devdoc.
# Attention auto-populates via CommsysGetLastNameFirstNameInitialRuleHandler; the hidden
# gate-feeder field carries initialValue='X', so each DH combo needs a matching default (audit_cad CHECK 6).
$imgDefsDH = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }, [PSCustomObject]@{ field = 'ReasonCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'Attention'; value = 'X' })
$noImgDefsDH = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'Attention'; value = 'X' })
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'; rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' } }
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
        # KQNameImg -- Image+photo path (requires Email). Image/Reason serialize ONLY here.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH','emailAddress'); any = @('Attention','imageIndicator','nameMiddleDH','nameSuffixDH','purposeCodeDH','reasonCode','registrationState'); defaults = $imgDefsDH; conditions = @([PSCustomObject]@{ field = @('operatorLicenseNumberDH'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'KQNameImg'; state = 'In/Out' }
        # KQName -- plain (no photo). No image/email/reason in pool -> fires on Name alone.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @('Attention','nameMiddleDH','nameSuffixDH','purposeCodeDH','registrationState'); defaults = $noImgDefsDH; conditions = @([PSCustomObject]@{ field = @('operatorLicenseNumberDH'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'KQName'; state = 'In/Out' }
        # KQOLNImg -- Image+photo path by OLN (requires Email).
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumberDH','emailAddress'); any = @('Attention','imageIndicator','purposeCodeDH','reasonCode','registrationState'); defaults = $imgDefsDH }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQOLNImg'; state = 'In/Out' }
        # KQOLN -- plain by OLN. No image/email/reason in pool.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('Attention','purposeCodeDH','registrationState'); defaults = $noImgDefsDH }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQOLN'; state = 'In/Out' }
    )
    description = 'DriverHistoryQuery -- 4 combos (KQNameImg/KQName/KQOLNImg/KQOLN). v3.8: image-variant split; Image=Y serializes only when email present. DH-suffix. v3.12: Attention auto-populated via handler + hidden gate-feeder; OLN>Name guardrail on KQName/KQNameImg.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverHistoryQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverLicenseQuery'); provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverHistoryQuery'; queryLabel = 'Driver History'; targetEntity = 'Person'
}

# --- GunQuery (2 combos) ---
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QG' for both combos; synthetic labels QGGunSerialNumber and
# QGNCICNumber differentiate routing. NOT real TX TLETS transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
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
    description = 'GunQuery -- 2 combos (Serial, NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_GunQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'GunQuery'; queryLabel = 'Firearm'; targetEntity = 'Firearm'
}

# --- ArticleSingleQuery (2 combos) ---
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QA' for both combos; synthetic labels QAArticleSerialNumber and
# QANCICNumber differentiate routing. NOT real TX TLETS transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
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
    description = 'ArticleSingleQuery -- 2 combos (Serial+Type, NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_ArticleSingleQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'ArticleSingleQuery'; queryLabel = 'Article'; targetEntity = 'Article'
}

# --- BoatQuery (5 combos) ---
# BQ combos: State promoted to set[] (routing toggle: State filled → OOS Nlets, blank → NCIC)
# QB combos: no State required (NCIC in-state/any)
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'BQ' and 'QB' for multiple combos each; field-name suffixes
# (BQRegistrationNumber, QBBoatHullIdNumber, etc.) are synthetic routing labels.
# NOT real TX TLETS transaction codes. See PLATFORM_CONSTRAINTS.txt.
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
        # BQRegistrationNumber (OOS Nlets Reg): Hull>Reg guardrail. Co-fires with BQBoatHullIdNumber
        # when Hull+Reg+State all present -> RegistrationNumber bleeds into the Hull XML. Hull wins
        # (unique permanent id), so this Reg combo exits the pool when a Hull ID is entered.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('registrationNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('boatHullIdNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'BQRegistrationNumber'; state = 'Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('boatHullIdNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'BQBoatHullIdNumber'; state = 'Out' }
        # QBRegistrationNumber: Hull>Reg guardrail. boatHullIdNumber is the NOT_EXISTS gate subject,
        # so it must NOT appear in any[] -- a field can't be in the serialization pool AND gate the
        # combo out of existence (contradiction; also poisons Build-MinimalData test injection).
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('registrationNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('boatHullIdNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'QBRegistrationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QBBoatHullIdNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'NCICNumber'; keyReference = 'QBNCICNumber'; state = 'In/Out' }
    )
    description = 'BoatQuery -- 5 combos (BQ OOS + QB in-state/NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_BoatQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'BoatQuery'; queryLabel = 'Boat'; targetEntity = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for TX_TLETS v$Version"
    name           = 'TX_TLETS'
    type           = 'BUNDLE'
    provider       = 'TX_TLETS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (6 cards)
# =====================================================================

# Vehicle -- 1 card, 3 rows (tightened)
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
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- single card. VehReg (7 combos) + VehStolen (2 combos).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 3 cards: SEARCH OPTIONS (State, Image, ReasonCode) + DL + DH
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
            # Attention is auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler.
            # Hidden gate-feeder (InpH initialValue='X') makes 'Attention' visible to the platform
            # so the handler's sourceField resolves and the value enters the serialization pool.
            @{ id = 'ROW_PER_DHA'; cols = @('12'); fields = @(
                @{ id = 'Attention_Hidden'; node = InpH 'Attention' 'Attention (auto-populated from officer profile)' '30' 'ROW_PER_DHA' @{ initialValue = 'X' } }
            )}
            @{ id = 'ROW_PER_DHL1'; cols = @('8','4'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DHL1' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose (DH)' '1' 'ROW_PER_DHL1' @{ initialValue = 'C' } }
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
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 3 cards: SEARCH OPTIONS (State + Image + ReasonCode + Email) + DRIVER LICENSE + DRIVER HISTORY (DH-suffix).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card, 2 rows (tightened)
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

# Boat -- 1 card, 2 rows (tightened, State no default -- BQ In/Out routing)
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
$boatForm = [PSCustomObject]@{ description = 'Boat queries -- single card. BQ (OOS) + QB (NCIC).'; label = 'Boat'; layout = $boaLayout; name = 'ENTITY_Boat'; type = 'QUERYINPUTFORM'; targetEntity = 'Boat' }

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
    -Label "Built TX_TLETS v${Version}" `
    -Version $Version

Write-Host ""
Write-Host "Build complete. 6 cards, 22 CommSys combos, 6 QIDMs."
