# build_tx_tlets.ps1  -- TX_TLETS v4.7
# Single build. 7 cards (Vehicle 1, Person 3 [Options+DL+DH], Firearm 1, Article 1, Boat 1).
# 19 CommSys combos: 5 VehReg + 3 DL + 2 DH + 2 Gun + 2 Article + 5 Boat
# v4.12 (2026-07-27, direct Rob feedback -- Person 2-card fold, layout+DH-sourcing change): folded
#   the standalone SEARCH OPTIONS card away -- Person is now 2 cards (DL + DH), with the State/NCIC
#   Image/Reason Code options DUPLICATED onto the BOTTOM row of EACH card. DL keeps the shared
#   RegistrationState/ImageIndicator/reasonCode fieldIds (DL QIDM unchanged). DH gets DH-suffixed
#   copies (RegistrationStateDH/ImageIndicatorDH/reasonCodeDH) -- unique fieldIds, self-contained DH
#   like NY/HI; the DriverHistoryQuery attributes + KQName/KQOLN any[] were re-sourced to the
#   DH-suffixed names (attribute names + wire targetFields UNCHANGED, so the wire request is
#   identical). The hidden EmailAddress auto-feeder (RND-57165, separate eng team) stays a SINGLE
#   shared hidden field on the DL card -- both QIDMs still source 'emailAddress'; NOT duplicated,
#   handler UNTOUCHED. All 5 entities reset at v4.12. CCH rebuilt in lockstep (BASE-SYNC -> v4.12).
# v4.10 (2026-07-27, direct Rob feedback -- Person DL top-row, NO functional change): the DL card
#   had OLN + Date of Birth + Sex lumped on one row (6/3/3). Rob: "keep it three lines like the DH
#   card with just OLN on top line." Restructured CARD_PER_DL to mirror CARD_PER_DH's 3-content-line
#   layout -- ROW_PER_L1 now OLN alone (12); DOB + Sex moved to their own ROW_PER_N2 (6/6, matching
#   DH's ROW_PER_DHN2); Name row unchanged. Layout-only, no combo/QIDM/routing/fieldId/label change.
#   Person reopened for re-test; Vehicle block-locked at v4.9 preserved (fingerprint unchanged).
#   Also cleaned the TX SQVR of the stale QV Plate/QV VIN combo blocks (both removed at v4.9).
#   CCH variant rebuilt in lockstep (BASE-SYNC -> v4.10).
# v4.9 (2026-07-27, DEX-1284 shadow-query correction -- Rob-confirmed, FUNCTIONAL change): removed
#   QVLicensePlateNumber + QVVehicleIdentificationNumber from VehicleInsuranceRegistrationQuery --
#   both were ungated SUBSET-SHADOWS (QV{Plate} subset of REG/RQ; QV{VIN} subset of VIN+FRT; the
#   extra fields are FRT/Type/Year qualifiers, NOT a state discriminator), so the platform auto-fires
#   the metadata QV transaction from the larger query and building them explicitly was redundant
#   (same class as the QWName removal v4.2, and NY's DGRP). VehReg 7->5 combos. RegionId (an OPTIONAL
#   member of the QV combination) is KEPT -- moved to the RQ plate + RQ VIN any[] (a devdoc-optional
#   combination field is never dropped; it serializes into the union pool the auto-fired regional QV
#   reads). ROW_VEH_3 stays 4/4/4 (Sticker/FRT/RegionId). Boat QB in-state combos gated RegistrationState
#   NOT_EXISTS (were ungated -> co-fired with the State-bearing BQ OOS combos; FL in/out gating).
#   NOTE (Rob ruling): in-state vs OOS are ALWAYS distinct queries (kept + gated); only the
#   no-state-discriminator qualifier subset-shadows (QV) were removed. Full re-test from T1.
# v4.8 (2026-07-27, DEX-1284 relabel/naming-convention pass -- direct Rob feedback, NO functional
#   change): applied the NY-established portfolio conventions. OLN label (OperatorLicenseNumber
#   DL+DH -> "OLN"); canonical "NCIC Image" (all image fields, was "NCIC Image - if available");
#   "Stolen Check" (relatedHitSearchIndicator Gun/Article/Boat, was "(Y) for NCIC stolen-X check");
#   lean labels -- stripped remaining "(optional)"/"(or use X)"/"(required)" helpers (Vehicle Make/
#   Year, VIN spelled-out -> "VIN", Firearm Serial, Gun Make/Caliber, Article Type, Boat Reg, MI/
#   Suffix DL+DH, Message Key); card titles use "Search by" + Person DL/DH titles carry query paths
#   ("Driver License/History Search by OLN, \"OR\" Name"); uniform 4/4/4 grid (Vehicle row 1
#   5/2/2/3 -> 3/3/3/3, row 2 5/4/3 -> 4/4/4). Bare any[] fields carry LABEL-OVERRIDE tags.
#   PERSON OPTIONS CARD KEPT (NOT folded into DL/DH): the NY Person top-row (OLN+State+Image on each
#   card) would require DH-suffixed copies of the shared State/Image/Reason/Email fields + touching
#   the EmailAddress handler (separate eng team, RND-57165 -- do not modify). So State/Image stay on
#   the shared SEARCH OPTIONS card (Image relabeled "NCIC Image"); OLN stays on the DL/DH top rows.
#   Label/title/layout-only -- no combo/QIDM/routing/fieldId/default change. All 5 entities re-test
#   from T1. CCH variant rebuilt in lockstep.
# v4.7 (2026-07-21, direct cosmetic feedback, NO functional change): Vehicle Make/Year helpers
#   dropped "with VIN" (both fields are any[]-optional across ALL Vehicle combos, not just the
#   VIN paths -- now just "(optional)"). Firearm row 1 gained NCIC Number between Serial Number
#   and Gun Make (was on row 2 with Caliber/Image/RelatedHitSearch); row 1 now 3 fields (4/4/4),
#   row 2 down to 3 (Caliber/Image/RelatedHitSearch, 4/4/4). Label/layout-only, no combo/routing
#   change. Folded into the same re-test as v4.6 (no v4.6 test data existed yet). All 5 entities
#   reopened.
# v4.6 (2026-07-21, Firearm CAD fix): GunQuery serial-number form fieldId + QIDM sourceField +
#   combo set[] GunSerialNumber -> serialNumber (CAD sends camelCase serialNumber, so the
#   USx-query button now populates the Firearm form; attribute name + targetField +
#   primaryFieldReference stay GunSerialNumber, wire unchanged). Same class of fix already applied
#   to NJ_NJCJIS v4.10, FL_FCIC v7.8, HI_HCJDC_OFML v4.11. This coincides with the full re-test
#   already owed since the 2026-07-20 hollow-any-field-toggle-fix reopen (27277f37) -- both causes
#   are covered by one v4.6 re-test pass. All 5 entities reopened.
# v4.5 (2026-07-17, direct feedback): Person DL card's Name-search helpers dropped -- First Name/
#   Last Name/Date of Birth all go bare (were "(Name search)"), Sex goes bare (was "(required with
#   Name)"). None of these are any[]-only (all set[]-required on DQName), so no CHECK-15 exposure.
#   DH's equivalents (NameFirstDH/NameLastDH/BirthDateDH/SexCodeDH) mirrored to match, same reasoning
#   (set[]-required on KQName only). Label-only, no combo/routing change.
# v4.4 (2026-07-17, direct feedback): second round of cosmetic label cleanup on top of v4.3.
#   Vehicle+Person State labels went bare ("State", default TX still set via initialValue) --
#   same merely-defaulted-field convention as Plate Type/Year/Reason Code (Boat's State is
#   untouched, it's a genuine routing toggle with no default, not the same class). Removed
#   remaining "(or search by X)"/"(or use X)" cross-reference helpers: Vehicle Plate Number,
#   Sticker Number, Firearm/Article/Boat NCIC Number all went bare (all are set[]-required in
#   their own combo, not any[]-only, so no CHECK-15 exposure). VIN field relabeled "Vehicle
#   Identification Number" (was "VIN (or search by Plate)"). FRT label dropped its "(REG/VIN
#   paths)" qualifier (bare "Fin. Resp. Type", same defaulted-field treatment as v4.3's FRT
#   default). Region ID dropped its "(regional query)" qualifier -- NOTE this one is genuinely
#   any[]-only with no default anywhere, unlike the others in this pass; expect a new CHECK-15
#   WARN here distinct from reasonCode's already-accepted one, flag back to Rob rather than
#   silently treating as equivalent. Label/layout-only, no combo/routing change.
# v4.3 (2026-07-17, direct feedback): bundles the stacked-up labeling backlog with an explicit
#   FRT default. (1) FinancialResponsibilityType defaults to 'E' (Extended Information, the
#   devdoc's own stated default) on both combos that need it (REGLicensePlateNumber,
#   VINVehicleIdentificationNumber) -- both the combo defaults[] (CAD dispatch) and the form
#   field's initialValue (officer-facing UI); field stays a plain visible input, no dropdown
#   conversion, no hiding (Rob's call). (2) Fixed the Name-order regression -- Person DL/DH were
#   Last-before-First, the one outlier vs. every other reviewed provider (NJ/CA/HI/NY/FL are all
#   First-before-Last); now First-before-Last on both cards. (3) Dropped the "(DH...)" qualifier
#   from every Driver History label (matches DL's phrasing minus the tag, mirrors FL/NY/HI).
#   (4) Image labels -> "NCIC Image - if available" (Person Options, Gun, Article, Boat).
#   (5) Related Hit Search labels reworded to name the actual check ("(Y) for NCIC stolen-<entity>
#   check", Gun/Article/Boat). (6) Cleared remaining bare "(opt)" abbreviations across all 5
#   entities (Plate Type/Year, Vehicle Make/Year, MI/Suffix/Message Key/Purpose Code/Reason Code,
#   Gun Make/Caliber) -- merely-defaulted fields (Plate Type/Year, Purpose Code, Reason Code) went
#   fully bare per the established NY_NYSPIN_EJUSTICE precedent (see
#   feedback_no_auto_on_defaulted_fields); Article's Serial Number dropped its "(with Article
#   Type)" cross-reference per the same NY precedent. (7) Card titles reworded to FL/NY-style
#   descriptive titles (Vehicle/Firearm/Article/Boat); Person's 3 cards and their titles unchanged.
#   (8) Person's "SEARCH OPTIONS" card fold-in was evaluated and deliberately NOT done -- TX's DH
#   QIDM shares FOUR unsuffixed fields with DL (email/Image/Reason/State, none DH-suffixed), a
#   materially bigger change than HI_HCJDC_OFML's single-field case; left for a dedicated future
#   pass. Label/layout/default-only changes throughout -- no combo removal, no routing change.
#   Full re-test from Test 1 required -- this is also the first live test since v4.0 (v4.1/v4.2
#   both changed the JSON without a subsequent re-test).
# v4.2 (2026-07-15): Removed the QWName combo (Wanted Person, Name+DOB with Sex optional) from
#   DriverLicenseQuery. QW is a platform-auto-sent shadow query, not client-buildable --
#   confirmed precedent: FL_FCIC_BUILD_NOTES.txt v4.2, "CommSys auto-sends QW query; no
#   JSON-side QIDM needed. Confirmed by platform team." Portfolio audit found the same pattern
#   built on HI_HCJDC_OFML (removed v4.8) and TX_TLETS -- QW is a standard NCIC-level key (not
#   FL-specific). TX's own devdoc doesn't authorize a Sex-optional Name variant either: its
#   closest "Possible Combination" (#3, Name+BirthDate+SexCode+RaceCode) requires Sex AND Race
#   together, a stricter/different combo than what QWName actually built (Sex/Race both merely
#   optional). DriverLicenseQuery now has 3 combos (DQName, CPLName, DQOLN) -- Sex is genuinely
#   required whenever searching via DQName (already gated by its own SexCode EXISTS condition +
#   set[] membership, unchanged). TX_TLETS_CCH intentionally NOT touched -- defer until this is
#   vetted live, consistent with the CCH-defers-until-main rule. Re-opens Person for live re-test.
# v4.1 (RND-57165): EmailAddress converted from a manually-typed field to the automated-handler
#        pattern -- GetUserProfileSingleValueRuleHandler (arguments=['email']) + hidden
#        gate-feeder on the shared Person SEARCH OPTIONS card, matching the existing Attention
#        mechanism. CJIS policy requires the actual signed-in officer's email on TLETS DL-photo
#        requests (NAM+DOB/OLN + IMQ + RSN + EML), not a shared/typed value. ReasonCode="C"
#        default already existed (imgDefs/imgDefsDH) -- confirmed satisfied, no change needed.
#        Ref: source/RND-57165_EmailAddressHandler/ (ticket + Confluence handler doc).
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
    [string]$Version = "4.15"
)

$ErrorActionPreference = 'Stop'
$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$OUT         = "$DIR\TX_TLETS_v${Version}.json"   # versioned root (NJ/HI/FL/NY parity); Write-ProviderJson removes stale siblings
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

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
        # ── v4.14: ALL 7 METADATA COMBINATIONS, FORM-REACHABLE ───────────────────────────────
        # v4.13 built only 3 of 7 and had DELETED RQ{Plate} + RQ{VIN} as "dead combos". They were
        # never dead: the form prefilled FRT=E / PlateYear / PlateTypeCode, so the combo requiring
        # those matched on every submission and nothing else could ever win first-match. Those two
        # RQ combos are the devdoc's "(OutofState)" paths -- deleting them removed out-of-state
        # plate and VIN search from the provider outright. The v4.13 note claiming "Officer impact
        # none: REG/VIN return a superset" was wrong: an in-state TX DMV query is not a superset of
        # an out-of-state Nlets query, it is a different destination system.
        #
        # Prefills are now GONE (see the Vehicle form rows), so the officer's own input selects the
        # path. Ordered MOST-SPECIFIC-FIRST, which is what makes every one reachable:
        #   plate + year + type -> RQ   (OutofState)      plate + year + FRT -> REG (InState+insurance)
        #   plate alone         -> QV   (plain reg)        sticker            -> DPSI
        #   VIN + FRT           -> VIN  (insurance)        VIN                -> RQ/QV{VIN}
        # RQ{VIN} and QV{VIN} have IDENTICAL metadata set[] ({VIN}) -- the one true shadow pair
        # here -- so they are split on the only optional that differs between them, RegionId.
        # Verify with: tools\audit_query_trace.ps1 -Provider TX_TLETS  (expect 7/7, 0 prefill-dead)
        #
        # NO defaults[] on any of these. A combo default re-injects the value on the CAD path and
        # counts as always-present for routing, which would re-create the exact bug. BUILD_RULES 23:
        # form queries come first; CAD injection never takes precedence.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateYear','LicensePlateTypeCode'); any = @('regionId','RegistrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateYear','financialResponsibilityType'); any = @('regionId','RegistrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'REGLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('regionId','RegistrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QVLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','financialResponsibilityType'); any = @('regionId','RegistrationState','VehicleMakeCode','vehicleYear'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('financialResponsibilityType'); operator = 'EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'VINVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('regionId'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('regionId'); operator = 'EXISTS' }, [PSCustomObject]@{ field = @('financialResponsibilityType'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QVVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('RegistrationState','VehicleMakeCode','vehicleYear'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('regionId'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('financialResponsibilityType'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('stickerNumber'); any = @('RegistrationState') }; primaryFieldReference = 'StickerNumber'; keyReference = 'DPSIStickerNumber'; state = 'In/Out' }
        # QVLicensePlateNumber + QVVehicleIdentificationNumber REMOVED v4.9 (DEX-1284 shadow review,
        # Rob-confirmed). Both were ungated SUBSET-SHADOWS: QV{Plate} subset of REG/RQ, QV{VIN} subset
        # of VIN+FRT -- the extra fields are FRT/Type/Year qualifiers of the SAME plate/VIN query
        # (NOT a state discriminator), so the platform auto-fires the metadata QV transaction from the
        # larger query; an explicit combo was redundant (QWName class). regionId (an OPTIONAL member of
        # the QV combination) is KEPT and moved to the RQ plate + RQ VIN any[] -- a devdoc-optional
        # combination field is never dropped; it serializes into the union pool the auto-fired regional
        # QV reads. in-state/OOS are separately kept + gated -- QV was not that.
        # ── RQLicensePlateNumber + RQVehicleIdentificationNumber REMOVED v4.13 ──────────────
        # Rob's v4.9 subset-shadow ruling applied to the two combos it missed. Both were DEAD --
        # unreachable at ANY fill under first-match ordering, because the combo ordered before each
        # of them matches whenever they do:
        #   RQ{Plate} <- REGLicensePlateNumber (index 0). Its only extra set[] field is
        #                financialResponsibilityType, which the form PRE-FILLS 'E', so REG's set is
        #                always satisfied and REG always wins.
        #   RQ{VIN}   <- VINVehicleIdentificationNumber (index 2), same prefilled-FRT reason.
        # They were missed at v4.9 only because test_commsys did not then seed form initialValues:
        # with FRT blank, REG/VIN reported "[SKIP] missing set" and the RQ combos looked like the
        # live ones. Simulator fixed 2026-07-29; audit_combo_reachability (enforce 2h) now gates this.
        # PROOF they never fired: TX_TLETS_v4.12_REGLicensePlateNumber.txt carries BOTH
        # FinancialResponsibilityType (REG's set field) AND LicensePlateTypeCode (RQ's) in ONE
        # transaction -- REG fired and the LIMITATION #1 union pool dragged RQ's field along.
        # Officer impact: NONE. REG returns registration + financial responsibility (a superset of
        # plain RQ registration); VIN likewise. VehReg 5 -> 3 combos, 17 CommSys total.
        # regionId / VehicleMakeCode preserved on the surviving combos above -- never drop a
        # devdoc-optional combination field.
    )
    description = 'VehicleInsuranceRegistrationQuery -- 3 combos (REG/VIN+FRT/DPSI). QV plate/VIN removed v4.9 (ungated subset shadows, platform auto-fired); RQ plate/VIN removed v4.13 (DEAD -- unreachable behind REG/VIN via the prefilled FinancialResponsibilityType).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_VehicleInsuranceRegistrationQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'VehicleInsuranceRegistrationQuery'; queryLabel = 'Vehicle Registration'; targetEntity = 'Vehicle'
}

# --- DriverLicenseQuery (3 combos) ---
# v3.4: POISONED-ARRAY fix. v3.2 gated "image-path" combos with `ImageIndicator EQUALS Y` +
# ReasonCode/EmailAddress conditions -- but value-comparison conditions are INERT on the platform
# (QIDM_REFERENCE Sec 2a), so each Img combo and its catchall twin (identical set[]) both fired =>
# union over-send. Fix: merge each pair into ONE combo per path; image/email/reason stay in any[]
# (sent when populated); defaults inject ImageIndicator=Y + ReasonCode=C (covers CAD). All query
# paths preserved.
# v4.1 (RND-57165): EmailAddress converted to the automated-handler pattern
# (GetUserProfileSingleValueRuleHandler, arguments=['email']) + hidden gate-feeder, same
# mechanism as Attention -- CJIS policy requires the actual signed-in officer's email, not a
# manually-typed value an officer could get wrong or leave blank. See
# source/RND-57165_EmailAddressHandler/ for the ticket + handler reference docs.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'DQ', 'QW', 'CPL'; field-name suffixes (DQName, DQOLN, CPLName) synthetic.
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
        # DQ Name (merged v3.4 -- image/email/reason in any[], no poisoned conditions)
        # SexCode EXISTS is a NECESSARY gate, not redundant with set[] membership -- CHECK 16
        # proved the platform fires on primaryFieldReference presence, not full set[] presence,
        # so without this condition Name alone (no Sex) could still fire DQName.
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('SexCode'); operator = 'EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'DQName'; state = 'In/Out' }
        # QWName (Wanted Person, Name+DOB with Sex/Race/RegionId/ExpandedDOB all optional)
        # intentionally NOT built (v4.2) -- platform-auto-sent shadow query, see header comment.
        # CPL Name (merged v3.4)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('emailAddress','ImageIndicator','messageKey','nameMiddle','nameSuffix','reasonCode','RegistrationState'); defaults = $imgDefs; conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'Name'; keyReference = 'CPLName'; state = 'In/Out' }
        # DQ OLN (merged v3.4)
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('emailAddress','ImageIndicator','reasonCode','RegistrationState'); defaults = $imgDefs }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOLN'; state = 'In/Out' }
    )
    description = 'DriverLicenseQuery -- 3 combos (DQName, CPLName, DQOLN). v3.4: poisoned conditions removed; image/email/reason in any[]. v4.1: EmailAddress auto-populated (GetUserProfileSingleValueRuleHandler, gate-feeder), RND-57165. v4.2: QWName (Wanted Person) removed -- platform auto-sends it, not client-buildable (FL_FCIC v4.2 precedent).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverLicenseQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverLicenseQuery'; queryLabel = 'Driver License'; targetEntity = 'Person'
}

# --- DriverHistoryQuery (2 combos) ---
# v4.0: merged the v3.8 image-variant split (KQNameImg/KQOLNImg dropped). CHECK 16 proved set[]
# membership does NOT gate firing (only primaryFieldReference + conditions do), so the split never
# actually enforced "Image only with email" -- the Img variant shadowed the plain one AND could
# serialize Image=Y without email. Merged to one combo per identifier: ImageIndicator (default Y) is
# the trigger; ReasonCode (default C) + EmailAddress ride with it in any[] (sent when present).
# v4.1 (RND-57165): EmailAddress converted to the automated-handler pattern (same mechanism as
# Attention below) -- CJIS policy requires the actual signed-in officer's email.
# OLN>Name identifier-priority guardrail kept on KQName (OperatorLicenseNumberDH NOT_EXISTS).
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
    description = 'DriverHistoryQuery -- 2 combos (KQName, KQOLN). v4.0: image-variant split merged (set[] does not gate firing); ImageIndicator=Y default triggers Reason=C, all in any[]. v4.1: EmailAddress auto-populated (GetUserProfileSingleValueRuleHandler, gate-feeder), RND-57165. DH-suffix; OLN>Name guardrail on KQName; Attention auto-populated (gate-feeder).'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverHistoryQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverLicenseQuery'); provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverHistoryQuery'; queryLabel = 'Driver History'; targetEntity = 'Person'
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
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'QBRegistrationNumber'; state = 'In' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QBBoatHullIdNumber'; state = 'In' }
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

# ------------------------------------------------------------------
# LABEL-OVERRIDE cluster (v4.8, DEX-1284 lean label pass). CHECK 15 Rule 3 wants a '(' / ' - '
# qualifier on pure-any[] fields; these are deliberately bare per the "strip helpers" convention
# (card title carries the paths). Downgrades the WARN to accepted [INFO]. (Image fields use the
# canonical global "NCIC Image" label, accepted by CHECK 15 directly -- no override needed.)
# LABEL-OVERRIDE: VehicleMakeCode -- bare "Vehicle Make" per lean pass (any[] optional)
# LABEL-OVERRIDE: vehicleYear -- bare "Vehicle Year" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameMiddle -- bare "MI" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameSuffix -- bare "Suffix" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameMiddleDH -- bare "MI" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameSuffixDH -- bare "Suffix" per lean pass (any[] optional)
# messageKey: label is now 'CPL/DWI/RDL (optional)' (DEX-1283 #4) -- has a '(' qualifier, no LABEL-OVERRIDE needed
# LABEL-OVERRIDE: GunMake -- bare "Gun Make" per lean pass (any[] optional)
# LABEL-OVERRIDE: GunCaliber -- bare "Caliber" per lean pass (any[] optional)
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per lean pass (any[] optional)
# ------------------------------------------------------------------
# Vehicle -- 1 card, 3 rows (tightened)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE REGISTRATION SEARCH BY PLATE, "OR" VIN, "OR" STICKER'
        rows  = @(
            # LABEL-OVERRIDE: RegistrationState -- see the full explanation next to the Person
            # card's OPTIONS row further down; same field/label, same override applies.
            @{ id = 'ROW_VEH_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                # v4.14 -- NO PREFILLS ON THESE THREE. Each is a set[] field of some vehicle
                # combination, so any initialValue makes the combo requiring it match on every
                # submission and permanently hides the others FROM THE FORM. PlateType=PC +
                # PlateYear=<year> + FRT=E hid all 4 RQ/QV combos, including the devdoc's two
                # "(OutofState)" paths -- and that false "dead combo" reading is why v4.13 deleted
                # RQ{Plate} and RQ{VIN}, removing out-of-state plate and VIN search entirely.
                # See enforce PHASE 2n / tools\audit_query_trace.ps1. THE FORM COMES FIRST
                # (BUILD_RULES 23): never trade a search path for a prefilled convenience value.
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';             node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'vehicleYear_Input';                 node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            # LABEL-OVERRIDE: regionId -- any[]-only optional combination field. KEPT after the QV combo
            # removal (a devdoc-optional combination field is never dropped): it now rides the RQ plate/
            # VIN any[] pool, which the platform's auto-fired regional QV reads. Bare label, Rob's call.
            @{ id = 'ROW_VEH_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'stickerNumber_Input';               node = Inp 'stickerNumber' 'Sticker Number' '10' 'ROW_VEH_3' }
                # v4.14 -- FRT prefill removed (see ROW_VEH_1 note). It is REG/VIN's discriminator:
                # prefilled 'E' it satisfied their set[] on every submission, so RQ/QV never fired.
                # Officer types E (or R) when they want the insurance return; a bare plate now
                # reaches the plain registration query (QV) as the devdoc intends.
                @{ id = 'financialResponsibilityType_Input'; node = Inp 'financialResponsibilityType' 'Fin. Resp. Type' '1' 'ROW_VEH_3' }
                @{ id = 'regionId_Input';                    node = Inp 'regionId' 'Region ID' '4' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- single card. VehReg (5 combos: REG/RQ/VIN+FRT/DPSI).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 3 cards: SEARCH OPTIONS (State, Image, ReasonCode, hidden Email) + DL + DH.
# Options-card fold-in evaluated 2026-07-17 and deliberately NOT done in this pass: unlike
# HI_HCJDC_OFML (where only ONE field, State, was shared between DL/DH and got its own
# DH-suffixed copy), TX's DH QIDM shares FOUR unsuffixed fields with DL -- emailAddress,
# ImageIndicator, reasonCode, RegistrationState (none are DH-suffixed, all read straight off
# this shared card). Giving DH its own copies of all four would mean duplicating the
# email-automation handler wiring too, a materially bigger and riskier change than HI's
# single-field case -- left for a dedicated future pass, not bundled into this labeling rebuild.
# Person = 2 cards (v4.12, Rob 2026-07-27): the standalone SEARCH OPTIONS card was FOLDED AWAY --
# its State / NCIC Image / Reason Code options are now duplicated onto the BOTTOM row of BOTH the
# DRIVER LICENSE and DRIVER HISTORY cards. DL keeps the shared RegistrationState/ImageIndicator/
# reasonCode fieldIds (DL QIDM sources them). DH gets DH-suffixed copies (RegistrationStateDH/
# ImageIndicatorDH/reasonCodeDH -- unique fieldIds, self-contained DH like NY/HI; DH QIDM re-sourced
# to them, wire targetFields unchanged). The hidden EmailAddress auto-feeder (RND-57165 handler,
# owned by a separate eng team -- do NOT modify) stays a SINGLE shared hidden field on the DL card;
# both DL and DH QIDMs still source 'emailAddress' from it, so it is NOT duplicated and the handler
# is untouched.
# LABEL-OVERRIDE: reasonCode -- merely-defaulted (initialValue=C), officer-editable bare label (Rob v4.3/v4.4).
# LABEL-OVERRIDE: reasonCodeDH -- DH copy of reasonCode, same bare "Reason Code".
# LABEL-OVERRIDE: RegistrationState -- bare "State", TX default via initialValue (Rob v4.4).
# LABEL-OVERRIDE: RegistrationStateDH -- DH copy of RegistrationState, bare "State", TX default via initialValue.
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # OLN alone on the top line (Rob 2026-07-27) -- the DL card now mirrors the DH card's
            # 3-line structure (OLN line / Name line / DOB+Sex line). DOB + Sex were previously
            # lumped onto the OLN row (6/3/3); moved to their own row (ROW_PER_N2) so the primary
            # identifier stands alone on top, matching CARD_PER_DH.
            # DEX-1283 #4 (Leo CAD review): OLN pairs with CPL/DWI/RDL on the top line; name split
            # First+Last / MI+Suffix so no row is uneven in CAD. messageKey relabelled from the bare
            # 'Message Key' -- the ticket asked for the value list only, and the '(' qualifier now
            # satisfies verify_build CHECK 15 natively (its LABEL-OVERRIDE is no longer needed).
            @{ id = 'ROW_PER_L1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_L1' }
                @{ id = 'messageKey_Input'; node = Inp 'messageKey' 'CPL/DWI/RDL (optional)' '3' 'ROW_PER_L1' }
            )}
            @{ id = 'ROW_PER_N1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name' '30' 'ROW_PER_N1' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'  '30' 'ROW_PER_N1' }
            )}
            @{ id = 'ROW_PER_N1B'; cols = @('6','6'); fields = @(
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'MI'     '30' 'ROW_PER_N1B' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix' '30' 'ROW_PER_N1B' }
            )}
            # DOB + Sex on their own row (moved off ROW_PER_L1 2026-07-27), matching DH's ROW_PER_DHN2.
            @{ id = 'ROW_PER_N2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_N2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_N2' }
            )}
            # Search options as the DL card's last row (folded from the retired OPTIONS card). Shared
            # fieldIds -- the DriverLicenseQuery combos source these. Hidden EmailAddress feeder lives
            # here (shared by DL + DH; the RND-57165 handler resolves the officer's signed-in email).
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
            # "(DH)" qualifier dropped from every label (Rob-confirmed 2026-07-17, mirrors
            # FL_FCIC/NY_NYSPIN_EJUSTICE/HI_HCJDC_OFML) -- the card's own "DRIVER HISTORY" title
            # already disambiguates it from "DRIVER LICENSE"; labels now match DL's phrasing.
            @{ id = 'ROW_PER_DHL1'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DHL1' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DHL1' @{ initialValue = 'C' } }
            )}
            # Name order First-before-Last (Rob-confirmed 2026-07-17), matches DL.
            # "(Name search)"/"(required with Name)" helpers dropped (Rob-confirmed 2026-07-17),
            # mirrors DL -- NameFirstDH/NameLastDH/BirthDateDH/SexCodeDH are all set[]-required on
            # KQName, never any[]-only anywhere else, so bare labels carry no CHECK-15 exposure.
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
            # Search options as the DH card's last row (DH-suffixed copies -- self-contained DH, unique
            # fieldIds; the DriverHistoryQuery combos source these DH-suffixed names, wire unchanged).
            # EmailAddress is NOT duplicated here: the single shared hidden feeder on the DL card serves
            # both QIDMs (DH QIDM still sources 'emailAddress'), so the RND-57165 handler stays untouched.
            @{ id = 'ROW_PER_DH_OPT'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationStateDH_Input'; node = Sel 'RegistrationStateDH' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'TX' } 'ROW_PER_DH_OPT' }
                @{ id = 'ImageIndicatorDH_Input';    node = Sel 'ImageIndicatorDH' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DH_OPT' }
                @{ id = 'reasonCodeDH_Input';        node = Inp 'reasonCodeDH' 'Reason Code' '1' 'ROW_PER_DH_OPT' @{ initialValue = 'C' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards (v4.12, OPTIONS folded in): DRIVER LICENSE + DRIVER HISTORY, each with State/Image/Reason options as its last row (DH-suffixed on DH); single shared hidden EmailAddress feeder on DL.'
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

# Article -- 1 card
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

# Boat -- 1 card, 2 rows (tightened, State no default -- BQ In/Out routing)
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY REGISTRATION NUMBER, "OR" HULL ID, "OR" NCIC NUMBER'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '11' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
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
Write-Host "Build complete. 7 cards, 19 CommSys combos, 6 QIDMs."
