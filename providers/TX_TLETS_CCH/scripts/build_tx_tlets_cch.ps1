# build_tx_tlets_cch.ps1  -- TX_TLETS_CCH v1.10
# BASE-SYNC: TX_TLETS v4.14   <- base-6 QIDMs are kept in lockstep with this TX_TLETS version.
# v1.5 (2026-07-27, DEX-1284 shadow correction, lockstep w/ TX_TLETS v4.9 + a CCH-only metadata fix):
#   (base-6) removed QVLicensePlateNumber + QVVehicleIdentificationNumber (ungated subset-shadows,
#   platform auto-fired -- see TX_TLETS v4.9); KEPT regionId (optional combination field) moved to the
#   RQ plate/VIN any[] (never drop a devdoc-optional field); ROW_VEH_3 stays 4/4/4; gated Boat QB
#   in-state combos RegistrationState NOT_EXISTS (FL in/out
#   pattern). (CCH-only) QH.NAME split into QH.NAME.SSN + QH.NAME.MISC to honor the metadata mandatory
#   Choice{SocialSecurityNumber|MiscellaneousNumber} (v1.1 wrongly demoted both to optional any[];
#   the "matches metadata exactly" claim was false). Matches the QWI.SSN/QWI.MISC split pattern.
#   VehReg 7->5, QH 4->5 -> 14 combos net delta. All entities reset for re-test.
# v1.4 (2026-07-27, DEX-1284 lockstep with TX_TLETS v4.8): re-synced the base-6 labels/layout to
#   TX_TLETS's relabel/naming-convention pass -- OLN (DL+DH), canonical "NCIC Image", "Stolen Check"
#   (Gun/Article/Boat), lean labels (Vehicle Make/Year, VIN, Serial, Gun Make/Caliber, Article Type,
#   Boat Reg, MI/Suffix, Message Key), Person DL/DH titles "Driver License/History Search by OLN,
#   \"OR\" Name", Firearm/Article titles "Search by", uniform 4/4/4 Vehicle grid. Person OPTIONS card
#   kept (shared State/Image/Reason/Email + email handler, same rationale as base). The 8 CCH
#   transactions + 3 CCH cards + CCH-suffixed fields UNTOUCHED. Label/layout-only, no combo/QIDM/
#   routing/fieldId change. All 5 base entities + CCH reset for re-test at v1.4.
#   When TX_TLETS bumps, re-sync base-6 + update this marker (tools/audit_variant_sync.ps1 checks it).
# Separate provider: full base TLETS query package (6 QIDMs) PLUS all 8 Computerized Criminal
# History (CCH) transactions on Person.
#
# v1.3 (2026-07-24, BASE-6 RE-SYNC to TX_TLETS v4.7): the base-6 QIDMs had drifted ~4 versions
#       behind TX_TLETS main (were at ~v4.0). This provider's design rule is "base-6 == TX_TLETS
#       main, plus the CCH transactions" -- restoring base<->variant lockstep. Ported the v4.1->v4.7
#       base-6 functional + label/layout deltas (separate build scripts, no auto-propagation):
#       (1) v4.1 email handler -- EmailAddress on DL+DH converted from a manually-typed field to
#           the automated GetUserProfileSingleValueRuleHandler (arguments=['email']) pattern +
#           hidden gate-feeder (InpH initialValue='X') on the Person SEARCH OPTIONS card, with
#           EmailAddress='X' added to the DL $imgDefs and DH $imgDefsDH so it serializes (RND-57165,
#           CJIS policy requires the signed-in officer's email on DL-photo requests).
#       (2) v4.2 QWName removal -- dropped the QWName combo from DriverLicenseQuery (platform
#           auto-sends the Wanted-Person shadow query, not client-buildable; FL_FCIC v4.2 precedent)
#           plus its now-orphaned attributes/fields (ExpandedBirthDateSearchCode, RaceCode, RegionId
#           -- all three only ever fed QWName). DL now 3 combos (DQName, CPLName, DQOLN).
#       (3) v4.3 FRT=E default -- FinancialResponsibilityType defaults to 'E' (devdoc default) on
#           the REG plate + VIN combos (combo defaults[] for CAD + form initialValue for the UI).
#       (4) v4.3-v4.7 base-entity label/layout pass -- descriptive card titles; "(DH...)" qualifier
#           dropped; Name First-before-Last on DL+DH; Image labels "NCIC Image - if available";
#           Related Hit Search labels name the check; merely-defaulted fields (State/Plate Type/
#           Year/Reason/Purpose/regionId) go bare (LABEL-OVERRIDE tags on State/regionId/reasonCode);
#           Vehicle Make/Year "(optional)"; Firearm NCIC# moved to row 1; VIN "Vehicle Identification
#           Number"; cross-reference "(or use X)" helpers dropped.
#       The 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) + their CCH-suffixed fields + 3 CCH cards
#       are UNTOUCHED -- this is a base-6 re-sync only. Boat keeps the RegistrationState-in-set[]
#       accepted divergence (TX_TLETS_CCH_ACCEPTED_DIVERGENCES.txt). Structural/validator check
#       only -- this provider remains NOT live-tested (first-ever live test still deferred).
#
# v1.2 (2026-07-21, Firearm CAD fix): GunQuery serial-number form fieldId + QIDM sourceField +
#       combo set[] GunSerialNumber -> serialNumber (CAD sends camelCase serialNumber, so the
#       USx-query button now populates the Firearm form; attribute name + targetField +
#       primaryFieldReference stay GunSerialNumber, wire unchanged). Ported from TX_TLETS main
#       v4.6 (same class of fix already applied to NJ_NJCJIS v4.10, FL_FCIC v7.8, HI_HCJDC_OFML
#       v4.11) -- this provider's own design rule is "identical to TX_TLETS main except for the
#       CCH addition," and these are separate build scripts/files, so the fix does not
#       auto-propagate; a second, explicit edit was required here. Structural/validator check
#       only -- this provider remains NOT live-tested (first-ever live test deferred to a later
#       session; this bug is invisible to the validator since it's internally self-consistent,
#       only a live CAD-dispatch test would ever catch it).
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
    [string]$Version = "1.10"
)

$ErrorActionPreference = 'Stop'
$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$OUT         = "$DIR\TX_TLETS_CCH_v${Version}.json"   # versioned root (TX_TLETS parity); Write-ProviderJson removes stale siblings
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

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
        # ── v1.10: ALL 7 METADATA COMBINATIONS, FORM-REACHABLE (lockstep w/ TX_TLETS v4.14) ──
        # v1.9 shipped only 3 and had DELETED RQ{Plate}+RQ{VIN} as 'dead combos'. They were never
        # dead: this form prefilled FRT=E / PlateYear / PlateTypeCode, so the combo requiring the
        # prefilled field matched on EVERY submission and nothing else could win first-match. RQ is
        # the devdoc's '(OutofState)' path -- deleting it removed out-of-state plate and VIN search
        # from the provider. Prefills are now gone (see the Vehicle form rows), so the officer's own
        # input selects the path. Ordered MOST-SPECIFIC-FIRST. NO defaults[] on any combo: a combo
        # default re-injects on the CAD path and counts as always-present, re-creating the bug.
        # BUILD_RULES 23: form queries come first. QV{VIN} is ordered BEFORE RQ{VIN} because
        # verify_build CHECK 14 only credits an EXISTS condition on the EARLIER combo.
        # Verify: tools\audit_query_trace.ps1 -Provider TX_TLETS_CCH  (expect 0 PREFILL-DEAD)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateYear','LicensePlateTypeCode'); any = @('regionId','RegistrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateYear','financialResponsibilityType'); any = @('regionId','RegistrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'REGLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('regionId','RegistrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QVLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','financialResponsibilityType'); any = @('regionId','RegistrationState','VehicleMakeCode','vehicleYear'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('financialResponsibilityType'); operator = 'EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'VINVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('regionId'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('regionId'); operator = 'EXISTS' }, [PSCustomObject]@{ field = @('financialResponsibilityType'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QVVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('RegistrationState','VehicleMakeCode','vehicleYear'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('regionId'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('financialResponsibilityType'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('stickerNumber'); any = @('RegistrationState') }; primaryFieldReference = 'StickerNumber'; keyReference = 'DPSIStickerNumber'; state = 'In/Out' }
    )
    description = 'VehicleInsuranceRegistrationQuery -- all 7 metadata combos, form-reachable (RQ/REG/QV plate + VIN/QV/RQ VIN + DPSI). v1.10 restored RQ+QV plate/VIN and removed the routing-affecting prefills that had made them unreachable; lockstep w/ TX_TLETS v4.14.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_VehicleInsuranceRegistrationQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'VehicleInsuranceRegistrationQuery'; queryLabel = 'Vehicle Registration'; targetEntity = 'Vehicle'
}

# --- DriverLicenseQuery (3 combos) ---
# Poisoned-array fix: value-comparison conditions are INERT on the platform (QIDM_REFERENCE Sec
# 2a), so merge each Img/catchall pair into ONE combo per path; image/email/reason stay in any[]
# (sent when populated); defaults inject ImageIndicator=Y + ReasonCode=C. All query paths preserved.
# v4.1 (RND-57165): EmailAddress converted to the automated-handler pattern
# (GetUserProfileSingleValueRuleHandler, arguments=['email']) + hidden gate-feeder, same mechanism
# as Attention -- CJIS policy requires the actual signed-in officer's email, not a manually-typed
# value. EmailAddress='X' rides in $imgDefs so the gate-feeder value serializes.
# v4.2: QWName (Wanted Person, Name+DOB with Sex/Race/RegionId/ExpandedDOB all optional) removed --
# platform-auto-sent shadow query, not client-buildable (FL_FCIC v4.2 precedent); its 3 orphaned
# fields (ExpandedBirthDateSearchCode/RaceCode/RegionId) dropped too. DL now 3 combos.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'DQ', 'CPL'; field-name suffixes (DQName, DQOLN, CPLName) synthetic.
$imgDefs = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'ReasonCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'EmailAddress'; value = 'X' })
$noImgDefs = @([PSCustomObject]@{ field = 'State'; value = 'TX' })
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress'; rule = [PSCustomObject]@{ function = 'GetUserProfileSingleValueRuleHandler'; arguments = @('email') } }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        # MessageKey (CPL/DWI/RDL) -- DL metadata field, optional in the CPL combo any[] (metadata is field-authority).
        [PSCustomObject]@{ name = 'MessageKey'; size = 3; sourceField = @('messageKey'); targetField = 'MessageKey' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('reasonCode'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ Name (merged -- image/email/reason in any[], no poisoned conditions)
        # SexCode EXISTS is a NECESSARY gate (CHECK 16: platform fires on primaryFieldReference presence, not full set[]).
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('SexCode'); operator = 'EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'DQName'; state = 'In/Out' }
        # QWName (Wanted Person) intentionally NOT built (v4.2) -- platform-auto-sent shadow query, see header comment.
        # CPL Name (merged)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','messageKey','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'CPLName'; state = 'In/Out' }
        # DQ OLN (merged)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('emailAddress','ImageIndicator','reasonCode','RegistrationState'); defaults = $imgDefs }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOLN'; state = 'In/Out' }
    )
    description = 'DriverLicenseQuery -- 3 combos (DQName, CPLName, DQOLN). Poisoned conditions removed; image/email/reason in any[]. v4.1: EmailAddress auto-populated (GetUserProfileSingleValueRuleHandler, gate-feeder), RND-57165. v4.2: QWName (Wanted Person) removed -- platform auto-sends it, not client-buildable (FL_FCIC v4.2 precedent).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_DriverLicenseQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'DriverLicenseQuery'; queryLabel = 'Driver License'; targetEntity = 'Person'
}

# --- DriverHistoryQuery (2 combos) ---
# Image-variant split merged (set[] does not gate firing -- only primaryFieldReference +
# conditions do). ImageIndicator (default Y) is the trigger; ReasonCode (default C) + EmailAddress
# ride with it in any[] (sent when present). OLN>Name identifier-priority guardrail kept on KQName.
# v4.1 (RND-57165): EmailAddress converted to the automated-handler pattern
# (GetUserProfileSingleValueRuleHandler, arguments=['email']), same mechanism as Attention -- CJIS
# policy requires the actual signed-in officer's email. EmailAddress='X' rides in $imgDefsDH.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'KQ'; synthetic labels KQName/KQOLN. See PLATFORM_CONSTRAINTS.txt.
# Attention auto-populates via CommsysGetLastNameFirstNameInitialRuleHandler; EmailAddress via
# GetUserProfileSingleValueRuleHandler (arguments=['email']) -- both use a hidden gate-feeder
# field carrying initialValue='X', so each DH combo needs a matching default (audit_cad CHECK 6).
$imgDefsDH = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }, [PSCustomObject]@{ field = 'ReasonCode'; value = 'C' }, [PSCustomObject]@{ field = 'State'; value = 'TX' }, [PSCustomObject]@{ field = 'Attention'; value = 'X' }, [PSCustomObject]@{ field = 'EmailAddress'; value = 'X' })
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'; rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' } }
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress'; rule = [PSCustomObject]@{ function = 'GetUserProfileSingleValueRuleHandler'; arguments = @('email') } }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicatorDH'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('NameLastDH','NameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('reasonCodeDH'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQName -- name path. Image=Y + Reason=C defaults ride; Email in any[] (typed now, handler later). OLN>Name guardrail.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCodeDH','BirthDateDH','NameLastDH','NameFirstDH'); any = @('Attention','ImageIndicatorDH','emailAddress','nameMiddleDH','nameSuffixDH','purposeCodeDH','reasonCodeDH','RegistrationStateDH'); defaults = $imgDefsDH; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'KQName'; state = 'In/Out' }
        # KQOLN -- OLN path (catchall). Image=Y + Reason=C defaults ride; Email in any[].
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('Attention','ImageIndicatorDH','emailAddress','purposeCodeDH','reasonCodeDH','RegistrationStateDH'); defaults = $imgDefsDH }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQOLN'; state = 'In/Out' }
    )
    description = 'DriverHistoryQuery -- 2 combos (KQName, KQOLN). Image-variant split merged (set[] does not gate firing); ImageIndicator=Y default triggers Reason=C, all in any[]. v4.1: EmailAddress auto-populated (GetUserProfileSingleValueRuleHandler, gate-feeder), RND-57165. DH-suffix; OLN>Name guardrail on KQName; Attention auto-populated (gate-feeder).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_DriverHistoryQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverLicenseQuery'); provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'DriverHistoryQuery'; queryLabel = 'Driver History'; targetEntity = 'Person'
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
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('serialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('NCICNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('serialNumber'); any = @('GunCaliber','GunMake','ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }; primaryFieldReference = 'GunSerialNumber'; keyReference = 'QGGunSerialNumber'; state = 'In/Out' }
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
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'QBRegistrationNumber'; state = 'In' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QBBoatHullIdNumber'; state = 'In' }
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
        # QH.NAME split v1.5 into SSN + MISC branches to honor the metadata mandatory
        # Choice{SocialSecurityNumber|MiscellaneousNumber} (v1.1 wrongly demoted both to optional
        # any[]). Matches the QWI.SSN/QWI.MISC pattern -- one of SSN/Misc is now required.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('requestorCCH','operatorCCH','inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','socialSecurityNumberCCH'); any = @('nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'Name'; keyReference = 'QH.NAME.SSN'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('requestorCCH','operatorCCH','inquiryReasonCCH','nameLastCCH','nameFirstCCH','purposeCodeCCH','miscellaneousNumberCCH'); any = @('nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'Name'; keyReference = 'QH.NAME.MISC'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','requestorCCH','operatorCCH','stateIdNumberCCH','purposeCodeCCH'); any = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'StateIdNumber'; keyReference = 'QH.SID'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('inquiryReasonCCH','requestorCCH','operatorCCH','fbiNumberCCH','purposeCodeCCH'); any = @('nameLastCCH','nameFirstCCH','nameMiddleCCH','nameSuffixCCH') }; primaryFieldReference = 'FBINumber'; keyReference = 'QH.FBI'; state = 'In/Out' }
    )
    description = 'CCHCriminalHistoryQHQuery -- 5 combos (BDOB/NAME.SSN/NAME.MISC/SID/FBI; Name split to honor the mandatory SSN|Misc Choice, v1.5). Manual select.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_CCH_CCHCriminalHistoryQHQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; provider = 'TX_TLETS_CCH'; providerType = 'Commsys'; query = 'CCHCriminalHistoryQHQuery'; queryLabel = 'CCH Criminal History (QH)'; targetEntity = 'Person'
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

# LABEL-OVERRIDE cluster (v1.4, DEX-1284 lockstep with TX_TLETS v4.8). Pure-any[] fields kept bare
# per the lean convention (card title carries paths); CHECK 15 Rule 3 WARN downgraded to [INFO].
# (Image fields use canonical "NCIC Image", accepted by CHECK 15 directly -- no override needed.)
# LABEL-OVERRIDE: VehicleMakeCode -- bare "Vehicle Make" per lean pass (any[] optional)
# LABEL-OVERRIDE: vehicleYear -- bare "Vehicle Year" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameMiddle -- bare "MI" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameSuffix -- bare "Suffix" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameMiddleDH -- bare "MI" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameSuffixDH -- bare "Suffix" per lean pass (any[] optional)
# LABEL-OVERRIDE: messageKey -- bare "Message Key" per lean pass (any[]-only in CPL combo)
# LABEL-OVERRIDE: GunMake -- bare "Gun Make" per lean pass (any[] optional)
# LABEL-OVERRIDE: GunCaliber -- bare "Caliber" per lean pass (any[] optional)
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per lean pass (any[] optional)
# Vehicle -- 1 card, 3 rows (ported from TX_TLETS main v4.8)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE REGISTRATION SEARCH BY PLATE, "OR" VIN, "OR" STICKER'
        rows  = @(
            # LABEL-OVERRIDE: RegistrationState -- merely-defaulted (initialValue=TX), officer-editable;
            # bare label is the TX_TLETS main v4.4 convention (feedback_no_auto_on_defaulted_fields).
            @{ id = 'ROW_VEH_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';             node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'vehicleYear_Input';                 node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            # LABEL-OVERRIDE: regionId -- any[]-only optional combination field, KEPT after the QV combo
            # removal (a devdoc-optional combination field is never dropped); rides the RQ plate/VIN pool.
            @{ id = 'ROW_VEH_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'stickerNumber_Input';               node = Inp 'stickerNumber' 'Sticker Number' '10' 'ROW_VEH_3' }
                @{ id = 'financialResponsibilityType_Input'; node = Inp 'financialResponsibilityType' 'Fin. Resp. Type' '1' 'ROW_VEH_3' }
                @{ id = 'regionId_Input';                    node = Inp 'regionId' 'Region ID' '4' 'ROW_VEH_3' }
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
# Person base = 2 cards (v1.8, lockstep w/ TX_TLETS main v4.12): the SEARCH OPTIONS card folded away
# -- State / NCIC Image / Reason Code options duplicated onto the bottom row of BOTH DL and DH (shared
# fieldIds on DL, DH-suffixed on DH); the hidden EmailAddress feeder (RND-57165, separate eng team)
# stays a single shared hidden field on DL, untouched. Plus the 3 CCH cards (unchanged). See TX_TLETS
# main v4.12.
# LABEL-OVERRIDE: reasonCode -- bare "Reason Code" (initialValue=C), officer-editable (TX convention).
# LABEL-OVERRIDE: reasonCodeDH -- DH copy of reasonCode, same bare "Reason Code".
# LABEL-OVERRIDE: RegistrationState -- bare "State", TX default via initialValue.
# LABEL-OVERRIDE: RegistrationStateDH -- DH copy of RegistrationState, bare "State", TX default via initialValue.
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # OLN alone on the top line (Rob 2026-07-27, lockstep w/ TX_TLETS main v4.10) -- the DL
            # card now mirrors the DH card's 3-line structure (OLN / Name / DOB+Sex). DOB + Sex were
            # previously lumped onto the OLN row (6/3/3); moved to their own ROW_PER_N2.
            @{ id = 'ROW_PER_L1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_L1' }
            )}
            # Name order First-before-Last (TX_TLETS main v4.3 convention); messageKey moved onto
            # this row (v4.2 removed the old ROW_PER_N2 -- Race/ExpandedDOB/RegionId only fed the dropped QWName).
            @{ id = 'ROW_PER_N1'; cols = @('3','3','2','2','2'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name' '30' 'ROW_PER_N1' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'  '30' 'ROW_PER_N1' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'MI'     '30' 'ROW_PER_N1' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix' '30' 'ROW_PER_N1' }
                @{ id = 'messageKey_Input'; node = Inp 'messageKey' 'Message Key' '3' 'ROW_PER_N1' }
            )}
            # DOB + Sex on their own row (moved off ROW_PER_L1 2026-07-27), matching DH's ROW_PER_DHN2.
            @{ id = 'ROW_PER_N2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_N2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_N2' }
            )}
            # Search options as the DL card's last row (folded from OPTIONS). Shared fieldIds + the
            # single hidden EmailAddress feeder (shared by DL + DH).
            @{ id = 'ROW_PER_DL_OPT'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'TX' } 'ROW_PER_DL_OPT' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DL_OPT' }
                @{ id = 'reasonCode_Input';        node = Inp 'reasonCode' 'Reason Code' '1' 'ROW_PER_DL_OPT' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DL_OE'; cols = @('12'); fields = @(
                @{ id = 'EmailAddress_Hidden'; node = InpH 'emailAddress' 'Email Address (auto-populated from officer profile)' '80' 'ROW_PER_DL_OE' @{ initialValue = 'X' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # Attention is auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler.
            # Hidden gate-feeder (InpH initialValue='X') makes 'Attention' visible to the platform
            # so the handler's sourceField resolves and the value enters the serialization pool.
            @{ id = 'ROW_PER_DHA'; cols = @('12'); fields = @(
                @{ id = 'Attention_Hidden'; node = InpH 'Attention' 'Attention (auto-populated from officer profile)' '30' 'ROW_PER_DHA' @{ initialValue = 'X' } }
            )}
            # "(DH...)" qualifier dropped from every label (TX_TLETS main v4.3 convention, mirrors
            # FL/NY/HI) -- the card's own "DRIVER HISTORY" title disambiguates it from "DRIVER LICENSE".
            @{ id = 'ROW_PER_DHL1'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DHL1' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DHL1' @{ initialValue = 'C' } }
            )}
            # Name order First-before-Last (TX_TLETS main v4.3), matches DL.
            @{ id = 'ROW_PER_DHN1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name' '30' 'ROW_PER_DHN1' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name'  '30' 'ROW_PER_DHN1' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'MI'     '30' 'ROW_PER_DHN1' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix' '30' 'ROW_PER_DHN1' }
            )}
            @{ id = 'ROW_PER_DHN2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input';    node = Dt  'BirthDateDH' 'Date of Birth' 'ROW_PER_DHN2' }
                @{ id = 'SexCodeDH_Input';      node = Sel 'SexCodeDH'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DHN2' }
            )}
            # Search options as the DH card's last row (DH-suffixed copies -- self-contained DH). Email
            # NOT duplicated (single shared hidden feeder on DL serves both; RND-57165 handler untouched).
            @{ id = 'ROW_PER_DH_OPT'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationStateDH_Input'; node = Sel 'RegistrationStateDH' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'TX' } 'ROW_PER_DH_OPT' }
                @{ id = 'ImageIndicatorDH_Input';    node = Sel 'ImageIndicatorDH' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DH_OPT' }
                @{ id = 'reasonCodeDH_Input';        node = Inp 'reasonCodeDH' 'Reason Code' '1' 'ROW_PER_DH_OPT' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_CCH_OPT'
        title = 'CCH OPTIONS (RESTRICTED -- CRIMINAL HISTORY)'
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
        title = 'FIREARM SEARCH BY SERIAL NUMBER, "OR" NCIC NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'NCICNumber_Input';       node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake' 'Gun Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{ description = 'Firearm query -- QG (Serial/NCIC).'; label = 'Firearm'; layout = $faLayout; name = 'ENTITY_Firearm'; type = 'QUERYINPUTFORM'; targetEntity = 'Firearm' }

# Article -- 1 card (ported from TX_TLETS main)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL NUMBER, "OR" NCIC NUMBER'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';                node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_ART_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{ description = 'Article query -- QA (Serial+Type / NCIC).'; label = 'Article'; layout = $artLayout; name = 'ENTITY_Article'; type = 'QUERYINPUTFORM'; targetEntity = 'Article' }

# Boat -- 1 card, 2 rows (ported from TX_TLETS main; State no default -- BQ In/Out routing)
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY REGISTRATION NUMBER, "OR" HULL ID, "OR" NCIC NUMBER'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '11' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for TX)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';                node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_BOA_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
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
