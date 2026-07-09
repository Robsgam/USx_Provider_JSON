# build_tx_tlets.ps1  -- TX_TLETS v4.0
# Single build. 7 cards (Vehicle 1, Person 3 [Options+DL+DH], Firearm 1, Article 1, Boat 1).
# 22 CommSys combos: 7 VehReg + 4 DL + 2 DH + 2 Gun + 2 Article + 5 Boat
# v4.0 CHECK-16 reachability fixes (set[] does NOT gate firing -- only primary+conditions): added
#   existence-only EXISTS gates so metadata combos are all reachable -- VIN gated FRT EXISTS, QV-VIN
#   RegionId EXISTS, DL DQName SexCode EXISTS + QWName BirthDate EXISTS, Boat BQ RegistrationState
#   EXISTS; DH image-variant split merged (see DriverHistoryQuery note).
# v4.0 (REBUILD under current methodology): PascalCase USx fieldIds (+ -PascalCaseUsxFields on RMS);
#        versioned root filename; clears PENDING_UPDATES flags (VehicleMakeName QRDM RND-62365 +
#        ParseCommsysName args -- shared-module fixes, verified present post-build). Condensed,
#        better-explained UI (FL-style, full CHECK-15 label-hint pass, all 5 entities; Person keeps
#        the shared OPTIONS card -- emailAddress is owned by a separate eng team, untouched). Exposed
#        MessageKey (CPL/DWI/RDL) on DriverLicenseQuery (metadata field-authority; CPL combo any[]).
#        QV-VIN shadow resolved: RegionId EXISTS condition + reordered before RQ-VIN (RegionId stays in
#        any[] per metadata -- no divergence). Docs migrated 4-category; tests/->logs/; phases/ retired.
# v3.13: Gap-audit remediation. (1) Hull>Reg guardrail COMPLETED -- added BoatHullIdNumber
#        NOT_EXISTS to BQRegistrationNumber (the OOS Nlets Reg combo; v3.12 only covered the
#        in-state QBRegistrationNumber, so Hull+Reg+State OOS co-entry still bled Reg into Hull
#        XML). (2) CAD plate-default gap -- REG/RQ plate combos require LicensePlateYear (REG) and
#        LicensePlateYear+LicensePlateTypeCode (RQ) in set[] but CAD ignores form initialValue, so
#        CAD-dispatched plate queries could not fire; added LicensePlateYear=$currentYear and
#        LicensePlateTypeCode=PC combo defaults (audit_cad CHECK 6 now scans set[] too).
# v3.12: Identifier-priority guardrail (Plate>VIN, OLN>Name DL+DH, Hull>Reg). All 3 pairs:
#        LicensePlateNumber NOT_EXISTS on 3 VIN combos; OperatorLicenseNumber NOT_EXISTS on
#        DQName/QWName/CPLName; OperatorLicenseNumberDH NOT_EXISTS on KQNameImg/KQName;
#        BoatHullIdNumber NOT_EXISTS on QBRegistrationNumber. vehicleYear added to
#        VINVehicleIdentificationNumber any[]. Attention gate-feeder added (DH hidden InpH
#        + 'Attention' in all 4 DH combo any[] -- handler was wired but pool excluded it).
#        conditions[].field = camelCase QIF sourceField (live-proven HI/FL pattern).
# v3.8: Restore 4-combo DH structure (v3.3 shape, corrected mechanism). devdoc requires
#       Email ONLY when ImageIndicator=Y -- not always. v3.7 over-restricted (blocked legal
#       no-photo path). Fix: Image/plain variant pairs (per Name, per OLN). Image variants
#       put ImageIndicator+reasonCode in any[] and require emailAddress in set[]. Plain
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
    [string]$Version = "4.0"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$OUT         = "$DIR\TX_TLETS_v${Version}.json"   # versioned root (NJ/HI/FL/NY parity); Write-ProviderJson removes stale siblings

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
# QV VIN: RegionId EXISTS condition + ordered before RQ VIN so both are reachable (was a shadow LIMITATION
# under first-match; set[] does NOT gate firing per CHECK 16). RegionId stays in any[] per metadata (no
# divergence); the EXISTS condition makes QV fire only when RegionId is present, RQ VIN handles bare VIN.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'REG', 'RQ', 'VIN', 'DPSI', 'QV' for multiple combos each;
# field-name suffixes (REGLicensePlateNumber, RQLicensePlateNumber, etc.) are synthetic.
# NOT real TX TLETS transaction codes. See PLATFORM_CONSTRAINTS.txt.
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'FinancialResponsibilityType'; size = 1;  sourceField = @('financialResponsibilityType'); targetField = 'FinancialResponsibilityType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RegionId';                    size = 4;  sourceField = @('regionId');                    targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'StickerNumber';               size = 10; sourceField = @('stickerNumber');               targetField = 'StickerNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateYear','financialResponsibilityType'); any = @('RegistrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'REGLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateYear','LicensePlateTypeCode'); any = @('RegistrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','financialResponsibilityType'); any = @('RegistrationState','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('financialResponsibilityType'); operator = 'EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'VINVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('stickerNumber'); any = @('RegistrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'StickerNumber'; keyReference = 'DPSIStickerNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('regionId','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }) }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QVLicensePlateNumber'; state = 'In/Out' }
        # QV VIN (regional) -- RegionId stays in any[] (metadata-faithful); RegionId EXISTS gates firing + ordered BEFORE RQ VIN: VIN+RegionId -> QV, VIN alone -> RQ.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('regionId'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('regionId'); operator = 'EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QVVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('RegistrationState','VehicleMakeCode','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'State'; value = 'TX' }); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQVehicleIdentificationNumber'; state = 'In/Out' }
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
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('expandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        # MessageKey (CPL/DWI/RDL) -- DL metadata field, optional in the CPL combo any[] (metadata is field-authority).
        [PSCustomObject]@{ name = 'MessageKey'; size = 3; sourceField = @('messageKey'); targetField = 'MessageKey' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCode'); targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('reasonCode'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'RegionId'; size = 4; sourceField = @('regionId'); targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ Name (merged v3.4 -- image/email/reason in any[], no poisoned conditions)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('SexCode'); operator = 'EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'DQName'; state = 'In/Out' }
        # QW Name -- unchanged (no image/email)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('expandedBirthDateSearchCode','nameMiddle','nameSuffix','raceCode','regionId','SexCode'); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('BirthDate'); operator = 'EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'QWName'; state = 'In/Out' }
        # CPL Name (merged v3.4)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','messageKey','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'CPLName'; state = 'In/Out' }
        # DQ OLN (merged v3.4)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('emailAddress','ImageIndicator','reasonCode','RegistrationState'); defaults = $imgDefs }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOLN'; state = 'In/Out' }
    )
    description = 'DriverLicenseQuery -- 4 combos (DQName, QWName, CPLName, DQOLN). v3.4: poisoned conditions removed; image/email/reason in any[].'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverLicenseQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverLicenseQuery'; queryLabel = 'Driver License'; targetEntity = 'Person'
}

# --- DriverHistoryQuery (2 combos) ---
# v4.0: merged the v3.8 image-variant split (KQNameImg/KQOLNImg dropped). CHECK 16 proved set[]
# membership does NOT gate firing (only primaryFieldReference + conditions do), so the split never
# actually enforced "Image only with email" -- the Img variant shadowed the plain one AND could
# serialize Image=Y without email. Merged to one combo per identifier: ImageIndicator (default Y) is
# the trigger; ReasonCode (default C) + EmailAddress ride with it in any[] (sent when present).
# EmailAddress is exposed as a visible field now and will be auto-populated by a handler later
# (like Attention/Requestor) -- until then the officer types it on image queries.
# OLN>Name identifier-priority guardrail kept on KQName (OperatorLicenseNumberDH NOT_EXISTS).
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'KQ'; synthetic labels KQName/KQOLN. See PLATFORM_CONSTRAINTS.txt.
# Attention auto-populates via CommsysGetLastNameFirstNameInitialRuleHandler; the hidden
# gate-feeder field carries initialValue='X', so each DH combo needs a matching default (audit_cad CHECK 6).
$imgDefsDH = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }, [PSCustomObject]@{ field = 'ReasonCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'Attention'; value = 'X' })
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'; rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' } }
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('NameLastDH','NameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('reasonCode'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQName -- name path. Image=Y + Reason=C defaults ride; Email in any[] (typed now, handler later). OLN>Name guardrail.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCodeDH','BirthDateDH','NameLastDH','NameFirstDH'); any = @('Attention','ImageIndicator','emailAddress','nameMiddleDH','nameSuffixDH','purposeCodeDH','reasonCode','RegistrationState'); defaults = $imgDefsDH; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'KQName'; state = 'In/Out' }
        # KQOLN -- OLN path (catchall). Image=Y + Reason=C defaults ride; Email in any[].
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('Attention','ImageIndicator','emailAddress','purposeCodeDH','reasonCode','RegistrationState'); defaults = $imgDefsDH }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQOLN'; state = 'In/Out' }
    )
    description = 'DriverHistoryQuery -- 2 combos (KQName, KQOLN). v4.0: image-variant split merged (set[] does not gate firing); ImageIndicator=Y default triggers Reason=C + Email, all in any[]; Email exposed now, handler later. DH-suffix; OLN>Name guardrail on KQName; Attention auto-populated (gate-feeder).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverHistoryQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverLicenseQuery'); provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverHistoryQuery'; queryLabel = 'Driver History'; targetEntity = 'Person'
}

# --- GunQuery (2 combos) ---
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QG' for both combos; synthetic labels QGGunSerialNumber and
# QGNCICNumber differentiate routing. NOT real TX TLETS transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber'; size = 4; sourceField = @('GunCaliber'); targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake'; size = 23; sourceField = @('GunMake'); targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('GunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('NCICNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @('GunCaliber','GunMake','ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'GunSerialNumber'; keyReference = 'QGGunSerialNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'NCICNumber'; keyReference = 'QGNCICNumber'; state = 'In/Out' }
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
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode'; size = 7; sourceField = @('ArticleTypeCode'); targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('NCICNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'ArticleSerialNumber'; keyReference = 'QAArticleSerialNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'NCICNumber'; keyReference = 'QANCICNumber'; state = 'In/Out' }
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
        [PSCustomObject]@{ name = 'BoatHullIdNumber'; size = 20; sourceField = @('BoatHullIdNumber'); targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('NCICNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 11; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQRegistrationNumber (OOS Nlets Reg): Hull>Reg guardrail. Co-fires with BQBoatHullIdNumber
        # when Hull+Reg+State all present -> RegistrationNumber bleeds into the Hull XML. Hull wins
        # (unique permanent id), so this Reg combo exits the pool when a Hull ID is entered.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('RegistrationNumber','RegistrationState'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'BQRegistrationNumber'; state = 'Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BoatHullIdNumber','RegistrationState'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'BQBoatHullIdNumber'; state = 'Out' }
        # QBRegistrationNumber: Hull>Reg guardrail. BoatHullIdNumber is the NOT_EXISTS gate subject,
        # so it must NOT appear in any[] -- a field can't be in the serialization pool AND gate the
        # combo out of existence (contradiction; also poisons Build-MinimalData test injection).
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'QBRegistrationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QBBoatHullIdNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'NCICNumber'; keyReference = 'QBNCICNumber'; state = 'In/Out' }
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
            @{ id = 'ROW_VEH_1'; cols = @('5','2','2','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number (or search by VIN)' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (opt)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (opt)' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (default TX - change for out-of-state)' @{ attributeTypeId = 'STATE'; initialValue = 'TX' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('5','4','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN (or search by Plate)' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';             node = Sel 'VehicleMakeCode' 'Vehicle Make (opt)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'vehicleYear_Input';                 node = Inp 'vehicleYear' 'Vehicle Year (opt)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'stickerNumber_Input';               node = Inp 'stickerNumber' 'Sticker Number (or use Plate/VIN)' '10' 'ROW_VEH_3' }
                @{ id = 'financialResponsibilityType_Input'; node = Inp 'financialResponsibilityType' 'Fin. Resp. Type (REG/VIN paths)' '1' 'ROW_VEH_3' }
                @{ id = 'regionId_Input';                    node = Inp 'regionId' 'Region ID (regional query)' '4' 'ROW_VEH_3' }
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
            @{ id = 'ROW_PER_O1'; cols = @('3','2','2','5'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (default TX - change for out-of-state)' @{ attributeTypeId = 'STATE'; initialValue = 'TX' } 'ROW_PER_O1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (opt)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_O1' }
                @{ id = 'reasonCode_Input';        node = Inp 'reasonCode' 'Reason Code (opt)' '1' 'ROW_PER_O1' @{ initialValue = 'C' } }
                @{ id = 'emailAddress_Input';      node = Inp 'emailAddress' 'Email Address (optional; sent with image queries)' '80' 'ROW_PER_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE'
        rows  = @(
            @{ id = 'ROW_PER_L1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number (or search by Name + DOB + Sex)' '20' 'ROW_PER_L1' }
                @{ id = 'BirthDate_Input';             node = Dt  'BirthDate' 'Date of Birth (Name search)' 'ROW_PER_L1' }
                @{ id = 'SexCode_Input';               node = Sel 'SexCode'   'Sex (required with Name)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_L1' }
            )}
            @{ id = 'ROW_PER_N1'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name (Name search)'  '30' 'ROW_PER_N1' }
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name (Name search)' '30' 'ROW_PER_N1' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'MI (opt)'     '30' 'ROW_PER_N1' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix (opt)' '30' 'ROW_PER_N1' }
            )}
            @{ id = 'ROW_PER_N2'; cols = @('3','3','2','4'); fields = @(
                @{ id = 'raceCode_Input';                    node = Sel 'raceCode' 'Race (opt)' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_N2' }
                @{ id = 'expandedBirthDateSearchCode_Input'; node = Inp 'expandedBirthDateSearchCode' 'Expanded DOB (opt)' '1' 'ROW_PER_N2' }
                @{ id = 'regionId_Input';                    node = Inp 'regionId' 'Region ID (opt)' '4' 'ROW_PER_N2' }
                @{ id = 'messageKey_Input';                  node = Inp 'messageKey' 'Message Key (CPL/DWI/RDL, opt)' '3' 'ROW_PER_N2' }
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
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number (DH) - or search by Name + DOB + Sex' '20' 'ROW_PER_DHL1' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code (DH, opt)' '1' 'ROW_PER_DHL1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DHN1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name (DH, Name search)'  '30' 'ROW_PER_DHN1' }
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name (DH, Name search)' '30' 'ROW_PER_DHN1' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'MI (DH, opt)'     '30' 'ROW_PER_DHN1' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH, opt)' '30' 'ROW_PER_DHN1' }
            )}
            @{ id = 'ROW_PER_DHN2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input';    node = Dt  'BirthDateDH' 'Date of Birth (DH, Name search)' 'ROW_PER_DHN2' }
                @{ id = 'SexCodeDH_Input';      node = Sel 'SexCodeDH'   'Sex (DH) - required with Name' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DHN2' }
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
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number (or use NCIC#)' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake' 'Gun Make (opt)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber (opt)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'NCICNumber_Input';                node = Inp 'NCICNumber' 'NCIC Number (or use Serial)' '10' 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (opt)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (opt)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
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
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number (with Article Type)' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type (required)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';                node = Inp 'NCICNumber' 'NCIC Number (or use Serial + Type)' '10' 'ROW_ART_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (opt)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (opt)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
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
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number (or use Hull ID)' '11' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for TX)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';                node = Inp 'NCICNumber' 'NCIC Number (or use Reg/Hull)' '10' 'ROW_BOA_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (opt)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (opt)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{ description = 'Boat queries -- single card. BQ (OOS) + QB (NCIC).'; label = 'Boat'; layout = $boaLayout; name = 'ENTITY_Boat'; type = 'QUERYINPUTFORM'; targetEntity = 'Boat' }

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (shared module -- camelCase, RegistrationState, -SkipRace)
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace -PascalCaseUsxFields

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{ bundles = @($entitiesBundle, $provBundle, $rmsBundle) }

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built TX_TLETS v${Version}" `
    -Version $Version

# Clear the rebuild-pending flags -- this build incorporates the shared-module fixes
# (VehicleMakeName QRDM RND-62365 + ParseCommsysName args). Presence is verified post-build.
$pendingPath = Join-Path $PSScriptRoot "..\docs\PENDING_UPDATES.txt"
if (Test-Path $pendingPath) { Remove-Item $pendingPath -Force }

Write-Host ""
Write-Host "Build complete. 7 cards, 22 CommSys combos, 6 QIDMs."
