# build_tx_tlets_cch.ps1  -- TX_TLETS_CCH v1.1
# Separate provider: full base TLETS query package (6 QIDMs) PLUS all 8 Computerized Criminal
# History (CCH) transactions on Person.
#
# v1.1: Base 6 QIDMs rebuilt to match TX_TLETS v4.0 exactly -- this provider's explicit design
#       rule is "identical to TX_TLETS main except for the CCH addition." Brings: PascalCase
#       field naming (22 USx CAD tokens; -PascalCaseUsxFields on RMS), poisoned-array-free DL/DH
#       combos (dropped the inert ImageIndicator EQUALS/ReasonCode EQUALS/EmailAddress REGEX
#       conditions -- value-comparison conditions are inert on the platform, QIDM_REFERENCE Sec
#       2a), identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg), QV-VIN
#       CHECK-16 reachability fix (RegionId EXISTS + reordered before RQ-VIN), CAD combo defaults
#       (LicensePlateYear/LicensePlateTypeCode on REG/RQ), DH Attention converted to the
#       automated-handler pattern (CommsysGetLastNameFirstNameInitialRuleHandler + hidden
#       gate-feeder). Boat keeps the same RegistrationState-in-set[] metadata divergence TX_TLETS
#       main has -- see TX_TLETS_CCH_ACCEPTED_DIVERGENCES.txt -- with the same EXISTS/NOT_EXISTS
#       routing so both the OOS (BQ) and in-state/NCIC (QB) paths stay reachable.
#       CCH QH: replaced the non-metadata QH.NAME.SSN/QH.NAME.MISC substitute combos (which
#       wrongly forced SSN/MiscNumber as if they were required qualifiers) with the actual
#       metadata-defined bare QH.NAME combo (SSN/MiscNumber now optional any[]) -- adds a
#       previously-impossible Name-only search path while keeping Name+SSN/Name+Misc working as
#       optional enrichments. CCH fields stay camelCase (no TX_TLETS-main analog exists for
#       them). ParseCommsysNameRuleHandler empty-arguments regression (shared-module fix, present
#       since 2026-06-17) now picked up by this rebuild. phases/ snapshot mechanism retired to
#       match TX_TLETS main (git history is authoritative); versioned root filename adopted.
#
# CCH design (unchanged):
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
    [string]$Version = "1.1"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$OUT         = "$DIR\TX_TLETS_CCH_v${Version}.json"   # versioned root (TX_TLETS parity); Write-ProviderJson removes stale siblings

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
# BASE 6 QIDMs -- ported from TX_TLETS v4.0 (provider name swapped; identical otherwise)
# ---------------------------------------------------------------------

# --- VehicleInsuranceRegistrationQuery (7 combos) ---
# Combo order: most-specific first (3 set > 2 set > 1 set)
# REG/RQ plate need Year+FRT/PlateType; VIN+FRT needs FRT; DPSI isolated; QV catchalls last
# QV VIN: RegionId EXISTS condition + ordered before RQ VIN so both are reachable (set[] does
# NOT gate firing per CHECK 16). RegionId stays in any[] per metadata (no divergence); the EXISTS
# condition makes QV fire only when RegionId is present, RQ VIN handles bare VIN.
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
    description = 'VehicleInsuranceRegistrationQuery -- 7 combos (REG/RQ/VIN+FRT/DPSI/QV).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_VehicleInsuranceRegistrationQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'VehicleInsuranceRegistrationQuery'; queryLabel = 'Vehicle Registration'; targetEntity = 'Vehicle'
}

# --- DriverLicenseQuery (4 combos) ---
# Poisoned-array fix: value-comparison conditions are INERT on the platform (QIDM_REFERENCE Sec
# 2a), so merge each Img/catchall pair into ONE combo per path; image/email/reason stay in any[]
# (sent when populated); defaults inject ImageIndicator=Y + ReasonCode=C. Email is manually
# entered for now (future email-injection handler TBD). All query paths preserved.
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
        # DQ Name (merged -- image/email/reason in any[], no poisoned conditions)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('SexCode'); operator = 'EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'DQName'; state = 'In/Out' }
        # QW Name -- unchanged (no image/email)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('expandedBirthDateSearchCode','nameMiddle','nameSuffix','raceCode','regionId','SexCode'); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('BirthDate'); operator = 'EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'QWName'; state = 'In/Out' }
        # CPL Name (merged)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','messageKey','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'CPLName'; state = 'In/Out' }
        # DQ OLN (merged)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('emailAddress','ImageIndicator','reasonCode','RegistrationState'); defaults = $imgDefs }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOLN'; state = 'In/Out' }
    )
    description = 'DriverLicenseQuery -- 4 combos (DQName, QWName, CPLName, DQOLN). Poisoned conditions removed; image/email/reason in any[].'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_DriverLicenseQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'DriverLicenseQuery'; queryLabel = 'Driver License'; targetEntity = 'Person'
}

# --- DriverHistoryQuery (2 combos) ---
# Image-variant split merged (set[] does not gate firing -- only primaryFieldReference +
# conditions do). ImageIndicator (default Y) is the trigger; ReasonCode (default C) + EmailAddress
# ride with it in any[] (sent when present). EmailAddress is a visible field for now (future
# email-injection handler TBD). OLN>Name identifier-priority guardrail kept on KQName.
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
    description = 'DriverHistoryQuery -- 2 combos (KQName, KQOLN). Image-variant split merged (set[] does not gate firing); ImageIndicator=Y default triggers Reason=C + Email, all in any[]; Email exposed, handler later. DH-suffix; OLN>Name guardrail on KQName; Attention auto-populated (gate-feeder).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_DriverHistoryQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverLicenseQuery'); provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'DriverHistoryQuery'; queryLabel = 'Driver History'; targetEntity = 'Person'
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
    description = 'GunQuery -- 2 combos (Serial, NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_GunQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'GunQuery'; queryLabel = 'Firearm'; targetEntity = 'Firearm'
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
    description = 'ArticleSingleQuery -- 2 combos (Serial+Type, NCIC).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_ArticleSingleQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'ArticleSingleQuery'; queryLabel = 'Article'; targetEntity = 'Article'
}

# --- BoatQuery (5 combos) ---
# BQ combos: State promoted to set[] (routing toggle: State filled -> OOS Nlets, blank -> NCIC).
# This is a documented metadata divergence (metadata lists State in any[] for BQ); see
# TX_TLETS_CCH_ACCEPTED_DIVERGENCES.txt -- same divergence + same rationale as TX_TLETS main.
# QB combos: no State required (NCIC in-state/any).
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

# --- CCHCriminalHistoryQHQuery (QH) -- core criminal history, 4 combos ---
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21/#36).
# Metadata defines 4 real combos: BirthDate, Name (bare -- Requestor/Operator/InquiryReason/
# Name/PurposeCode only, everything else optional), StateIdNumber, FBINumber. v1.0 substituted
# QH.NAME.SSN/QH.NAME.MISC (wrongly forcing SSN/MiscNumber as required qualifiers) instead of the
# real bare Name combo -- fixed here: QH.NAME now matches metadata exactly, with
# SocialSecurityNumber/MiscellaneousNumber carried as optional any[] enrichments (an officer with
# an SSN or misc-number can still supply it; a bare Name-only search is newly possible too).
# Ordered after QH.BDOB (more-specific-first; BDOB requires strictly more fields, no shadow risk).
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
        # QH.NAME -- bare Name combo (metadata-exact). SSN/MiscNumber optional enrichments, not required.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('requestorCCH','operatorCCH','inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH'); any = @('nameMiddleCCH','nameSuffixCCH','socialSecurityNumberCCH','miscellaneousNumberCCH') }; primaryFieldReference = 'Name'; keyReference = 'QH.NAME'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','requestorCCH','operatorCCH','stateIdNumberCCH','purposeCodeCCH'); any = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'StateIdNumber'; keyReference = 'QH.SID'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','requestorCCH','operatorCCH','fbiNumberCCH','purposeCodeCCH'); any = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'FBINumber'; keyReference = 'QH.FBI'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryQHQuery -- 4 combos (BDOB/Name/SID/FBI, metadata-exact). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryQHQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryQHQuery'; queryLabel = 'CCH Criminal History (QH)'; targetEntity = 'Person'
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

# Vehicle -- 1 card, 3 rows (ported from TX_TLETS main)
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
    description  = 'Vehicle queries -- single card. VehReg (7 combos).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- base 3 cards (SEARCH OPTIONS/DRIVER LICENSE/DRIVER HISTORY, ported from TX_TLETS
# main) + 3 CCH cards (OPT/PERSON/RECORD, CCH-suffixed, unchanged)
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
                @{ id = 'socialSecurityNumberCCH_Input'; node = Inp 'socialSecurityNumberCCH' 'SSN (CCH, optional)' '9' 'ROW_CCH_P3' }
                @{ id = 'miscellaneousNumberCCH_Input';  node = Inp 'miscellaneousNumberCCH' 'Misc Number (CCH, optional)' '15' 'ROW_CCH_P3' }
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
                @{ id = 'nletsDestinationCCH_Input';  node = Inp 'nletsDestinationCCH' 'Nlets Dest (CCH)' '2' 'ROW_CCH_R3' }
                @{ id = 'nletsDestination2CCH_Input'; node = Inp 'nletsDestination2CCH' 'Nlets Dest 2 (CCH)' '2' 'ROW_CCH_R3' }
                @{ id = 'nletsDestination3CCH_Input'; node = Inp 'nletsDestination3CCH' 'Nlets Dest 3 (CCH)' '2' 'ROW_CCH_R3' }
            )}
            @{ id = 'ROW_CCH_R4'; cols = @('3','3','6'); fields = @(
                @{ id = 'nletsDestination4CCH_Input'; node = Inp 'nletsDestination4CCH' 'Nlets Dest 4 (CCH)' '2' 'ROW_CCH_R4' }
                @{ id = 'nletsDestination5CCH_Input'; node = Inp 'nletsDestination5CCH' 'Nlets Dest 5 (CCH)' '2' 'ROW_CCH_R4' }
                @{ id = 'freeTextCCH_Input';          node = Inp 'freeTextCCH' 'Free Text / Admin Message (CCH)' '14400' 'ROW_CCH_R4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- base (SEARCH OPTIONS+DRIVER LICENSE+DRIVER HISTORY, DH-suffix) + 3 CCH cards (OPT/PERSON/RECORD), CCH-suffixed, manual-select.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card, 2 rows (ported from TX_TLETS main)
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

# Article -- 1 card (ported from TX_TLETS main)
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

# Boat -- 1 card, 2 rows (ported from TX_TLETS main; State no default -- BQ In/Out routing)
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
# BUNDLE 3: RMS (shared module -- PascalCase USx fields to match base-6 QIDMs, -SkipRace)
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace -PascalCaseUsxFields

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{ bundles = @($entitiesBundle, $provBundle, $rmsBundle) }

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built TX_TLETS_CCH v${Version}" `
    -Version $Version

Write-Host ""
Write-Host "Build complete. TX_TLETS_CCH v${Version} -- 14 QIDMs (6 base + 8 CCH), Person CCH cards CCH-suffixed."
