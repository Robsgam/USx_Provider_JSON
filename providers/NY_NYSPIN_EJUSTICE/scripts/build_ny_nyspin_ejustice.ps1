# build_ny_nyspin_ejustice.ps1
# Builds NY_NYSPIN_EJUSTICE.json -- Single JSON, multi-card layout.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ny_nyspin_ejustice.ps1
#
# INPUTS:
#   source\NY_NYSPIN_EJUSTICE.XML     -- XML metadata (field names, sizes, combinations, keyRefs) [AUTHORITATIVE]
#   source\New York (NYSPIN_XML).pdf  -- CommSys devdoc (Basic Queries Supported) [CROSS-CHECK]
#   tools\_build_rms_bundle.ps1       -- RMS bundle + CommSys QRDM (KB specs)
#
# LAYOUT (5 QIFs, 9 cards):
#   Vehicle:  1 card (v4.6) -- VEHICLE QUERY (Plate row + options folded in, VIN row)
#   Person:   2 cards (v4.11, DEX-1284) -- DRIVER LICENSE (OLN+Name+own State/Image) + DRIVER HISTORY (DH-suffix, own StateDH/ImageDH). DL NAME SEARCH (DGRP name-only shadow) removed; SEARCH OPTIONS card dumped (v4.5).
#   Firearm:  1 card
#   Article:  1 card
#   Boat:     1 card (v4.6) -- BOAT QUERY (Reg + Hull + options folded in)
#
# QIDMs (6, 16 combos):
#   VehicleRegistrationQuery             RVEHOUT/RVIN (OOS, State EXISTS), RVEH/RCAR (NY, State NOT_EXISTS)  [in/out = distinct queries, gated v4.15]
#   DriverLicenseQuery                   DLICN (Name+DOB), DLIC (OLN)  [metadata: both keyRef=DLIC; DLICN is synthetic -- platform requires unique keyRefs per QIDM]
#   DriverHistoryQuery                   DALHOUT, DALH, DALLOUT, DALL  [State routing via RegistrationState EXISTS/NOT_EXISTS -- see v4.0]
#   GunQuery                             GINQ
#   ArticleSingleQuery                   AINQ
#   BoatQuery                            BVEH/BVIN (OOS, State EXISTS), RVEH/RCAR (NY, State NOT_EXISTS)  [in/out = distinct queries, gated v4.15]
#
# STATE: NCIC pattern CONFIRMED on NY (no initialValue -- blank default).
#   See LIMITATION #30.
# SEX: Full 3-layer NIBRS pattern CONFIRMED
# DL+DH: DH-suffix fieldIds + one-directional queriesToDeselect (DH deselects DL)
# Combo order: most set[] fields first
# CAD defaults on all CommSys combos with initialValues
#
# v4.0 (rebuild -- picks up 4 cross-provider hardening rounds already live-proven on
#   FL_FCIC/HI_HCJDC_OFML/TX_TLETS/CA_CLETS):
#   1. PASCALCASE: the 22 USx CAD-integration field names authored natively PascalCase
#      (sourceField/set/any/layout fieldId) per CLAUDE.md; RMS bundle built with
#      -PascalCaseUsxFields. Fields NOT on the 22-token list (vehicleYear, nameMiddle(DH),
#      nameSuffix(DH), relatedHitSearchIndicator, purposeCodeDH, requestorDH,
#      nyNyspinTransactionNameDH) intentionally stay camelCase.
#   2. POISONED-ARRAY FIX (DriverHistoryQuery): the old In=IN('NY','null')/Out=NOT_EQUALS
#      'NY' conditions used the attribute NAME ('State') instead of sourceField, AND used
#      value-comparison operators -- per the live-proven POISONED-ARRAY RULE
#      (knowledge-base/QIDM_REFERENCE.txt) a conditions array containing ANY
#      EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX is disabled IN ITS ENTIRETY, so these 4 combos had
#      ZERO real in/out routing. Replaced with existence-only conditions on RegistrationState
#      (EXISTS on DALHOUT/DALLOUT, NOT_EXISTS on DALH/DALL) -- same fix FL_FCIC v6.0/v7.0
#      applied. The old "destination must not literally equal home state" rule can no longer
#      be config-enforced (it was never actually enforced by the old inert conditions either).
#   3. IDENTIFIER-PRIORITY GUARDRAILS (3 pairs, matching HI/FL/TX/CA rollout): Vehicle
#      Plate>VIN (LicensePlateNumber NOT_EXISTS added to RVIN/RCAR), Person OLN>Name on both
#      DriverLicenseQuery (OperatorLicenseNumber NOT_EXISTS added to DLICN) and
#      DriverHistoryQuery (OperatorLicenseNumberDH NOT_EXISTS added to DALHOUT/DALH), and
#      Boat Hull>Reg (BoatHullIdNumber NOT_EXISTS added to BVEH/RVEH). DGRP untouched (opt-in,
#      autoSelect=false, not part of any priority pair) -- only its shared nameLast/nameFirst/
#      birthDate/sexCode fields moved to PascalCase alongside DL's since they're the same
#      physical DRIVER LICENSE card fields.
#   4. Versioned root filename (NY_NYSPIN_EJUSTICE_v4.0.json), matching NJ/HI/FL/CA_CLETS.
#   ROUTING CHANGE -> full re-test mandate: Vehicle/Person/Boat entities reset to PENDING.
#
# v4.10 (2026-07-20): GunQuery fieldId fix -- GunSerialNumber -> serialNumber on form + QIDM
#   sourceField + combo set[]. CAD sends the serial number as 'serialNumber' (confirmed by Leo
#   Hisoire on the NY tenant -- serial number was not auto-populating from CAD event firearm
#   page). QIDM attribute name + targetField stay 'GunSerialNumber' (XML element unchanged).
#   Same fix CA_CLETS applied at v2.9. Firearm entity reopened for retest.
#
# v4.11 (2026-07-27, DEX-1284): removed the DGRP "DL NAME SEARCH" name-only shadow query + card
#   (Person -> 2 cards DL+DH); OLN relabel (OperatorLicenseNumber DL+DH -> "OLN", global convention).
# v4.12 (2026-07-27, DEX-1284 label pass -- direct Rob feedback, NO functional change): HI-style
#   lean relabel across ALL 5 entities. Stripped every inline field helper EXCEPT the State routing
#   hint; the card TITLE now carries each entity's query paths (the NY Vehicle model extended to
#   Person/Firearm/Article/Boat). Image fields -> canonical bare "NCIC Image" (NEW GLOBAL convention,
#   retrofit to every provider on its revisit turn, DEX-1284 -- verify_build CHECK 15 accepts it
#   directly). Firearm/Article stolen-hit label -> "Stolen Check". Person cards retitled
#   "Driver License/History Search by OLN, \"OR\" Name". Bare any[] fields carry LABEL-OVERRIDE tags
#   (Rob's explicit cosmetic call). Label/title-only -- no combo/QIDM/routing/fieldId/default change.
#   All 5 entities re-test from T1.
# v4.13 (2026-07-27, DEX-1284 layout balance -- direct Rob feedback, NO functional change): Vehicle
#   card rebalanced to a uniform 4/4/4 grid so fields align left-to-right AND top-to-bottom --
#   ROW_VEH_1 4/2/2->4/4/4 (was only filling 8 of 12 cols, Type/Year cramped), ROW_VEH_2 6/3/3->4/4/4
#   (VIN 6->4), ROW_VEH_3 6/6->4/4 (State 6->4; a 2-char code no longer sits in a half-row box). New
#   GLOBAL field-size/placement standard recorded in BUILD_RULES Section 11. Layout-only -- no
#   label/combo/QIDM/routing/fieldId/default change. All 5 entities re-test from T1.
# v4.14 (2026-07-27, DEX-1284 Person top-row -- direct Rob feedback, NO functional change): both
#   Person cards (DL + DH) put OLN + State + NCIC Image together on the TOP line (6/3/3) -- OLN keeps
#   the width, State/Image are short codes. Merged the old row-1 (OLN full-width) + row-1B
#   (State/Image 6/6) into one row per card. Layout-only -- no label/combo/QIDM/routing/fieldId
#   change. All 5 entities re-test from T1 (block-by-version).
# v4.15 (2026-07-27, DEX-1284 shadow-review follow-up -- in/out routing gates): the 4 ungated
#   in/out combos (Vehicle RVEHOUT/RVEH/RCAR, Boat BVIN/RVEH/RCAR) were firing on set[]/any[]
#   membership alone -- an out-of-state plate/hull query (State-bearing) co-fired with its in-state
#   sibling. Per the FL in/out pattern (in-state and out-of-state are ALWAYS distinct queries), added
#   existence-only RegistrationState gates: EXISTS on the OOS combos (RVEHOUT, BVIN -- the State-bearing
#   destination queries), NOT_EXISTS on the NY in-state combos (RVEH, RCAR both entities). Existence-only
#   (poisoned-array-safe). No shadow-subset combos to remove on NY (adversarial re-review: none present).
#   Functional routing change -> all 5 entities re-test from T1 (block-by-version).

param(
    [string]$Version = "4.22"
)

$ErrorActionPreference = 'Stop'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\NY_NYSPIN_EJUSTICE_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: NY_NYSPIN_EJUSTICE PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'NY_NYSPIN_EJUSTICE'

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'NY_NYSPIN_EJUSTICE'

$qmf = Build-Qmf -ProviderName 'NY_NYSPIN_EJUSTICE'

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: VehicleRegistrationQuery v1
#   RVEH: Choice(set[Plate,any[PlateType]], set[Plate,PlateType,PlateYear,State]), any[Image]
#     -> in-state RVEH: set[LicensePlateNumber], any[PlateType, PlateYear, State]
#     -> OOS RVEHOUT:   set[LicensePlateNumber, registrationState], any[Image, PlateType, PlateYear]
#        (State is the non-defaulted OOS discriminator -> set[]; PlateType/Year are
#         defaulted (PC/$currentYear) so stay in any[] per LIMITATION #31. Mirrors RVIN.)
#   RCAR: set[VIN], any[Image]                          (in-state VIN, NY DMV)
#   RVIN: set[VIN, State], any[Image, VehicleMakeCode, VehicleYear]   (OOS VIN)
# Choice OOS rule (LIMITATION #36): metadata Choice extended-Set with State =>
#   build a dedicated OOS combo with State in set[]. See KB QIDM_REFERENCE.
# RVEHOUT is a synthetic keyRef (NOT a real NYSPIN transaction code). Metadata RVEH uses
# a Choice combo with State in extended-Set; LIMITATION #36 requires a dedicated OOS combo.
# RVEH narrowed to in-state only; RVEHOUT handles OOS plate queries.
# Order: RVIN (2 set) > RVEHOUT (2 set) > RVEH (1 set) > RCAR (1 set)
# v4.0: Plate>VIN identifier-priority guardrail -- LicensePlateNumber NOT_EXISTS added to
#   RVIN + RCAR (VIN combos exit the pool when a plate is also entered). Also added
#   RegistrationState EXISTS to RVIN -- set[] is NOT a firing gate (only primaryFieldReference
#   presence + conditions matter), so a bare VIN-only payload was previously satisfying RVIN's
#   conditions (it had none) and shadowing RCAR every time regardless of State (verify_build
#   CHECK 16, live platform behavior). Mirrors FL_FCIC's OOS-gate symmetry hardening.
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';        size = 10; sourceField = @('LicensePlateNumber');        targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        # DEX-1284 EXPERIMENT (v4.22): CAD auto-fills RegistrationState with the officer's home
        # state (NY) on every Vehicle entry, which forces RVEHOUT (OOS) to fire for a plate that
        # is actually NY-registered. IgnoreUserValueRuleHandler(["NY"]) strips "NY" from the
        # OUTBOUND wire value only -- it does NOT change combo selection (conditions read raw
        # FORM state before this handler runs; confirmed via scratch simulator test 2026-08-06,
        # see knowledge-base/UNIVERSAL_SEARCH_HANDLERS.txt Sec 4). RVEHOUT still fires and its
        # own unconditional defaults (LicensePlateTypeCode/Year) still ride along; only <State>
        # is now omitted from the wire when the value is exactly "NY". Whether the live CommSys
        # server treats that as a correct in-state lookup or a malformed OOS request is NOT
        # determinable from a simulator (LIMITATION #37: the server picks the real message key
        # from field VALUES, not our internal keyReference) -- this version exists to observe the
        # real wire/result live. STATUS: HYPOTHESIS pending live capture. Revert this rule alone
        # (leave everything else) if the live test shows a regression.
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC'; rule = [PSCustomObject]@{ function = 'IgnoreUserValueRuleHandler'; arguments = @('NY') } }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('VehicleIdentificationNumber','RegistrationState')
                any        = @('ImageIndicator','VehicleMakeCode','vehicleYear')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RVIN'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState','LicensePlateTypeCode','LicensePlateYear'); any = @('ImageIndicator'); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEHOUT'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('ImageIndicator','LicensePlateTypeCode'); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEH'
            state                 = 'In'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('ImageIndicator'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery -- RVIN (VIN+State OOS), RVEHOUT (plate+State OOS), RVEH (plate in-state), RCAR (VIN NY DMV). Plate>VIN guardrail v4.0.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML: DriverLicenseQuery v2
#   DLIC (OLN): set[OLN], any[ImageIndicator, State]
#   DLIC (Name): set[BirthDate, Name, SexCode], any[ImageIndicator, State]
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata XML uses keyReference="DLIC" for BOTH combos (OLN and Name+DOB).
# Synthetic keyRef "DLICN" used for the Name combo to satisfy platform uniqueness.
# DLICN is not a real NYSPIN transaction code -- it is a ConnectCIC internal label only.
# See PLATFORM_CONSTRAINTS.txt -- duplicate-keyRef constraint.
# NyNyspinDriverLicenseNameQuery (DGRP) is a SEPARATE QIDM (see 1e2 below) --
# a distinct DMV name-search transaction (autoSelect=false, manual select).
# DL is the autoSelect default query (AP #14); DGRP is opt-in for name-only search.
# SexCode: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
# State: codeTypeProvider=NCIC (reverse-lookup attr ID -> 2-letter code)
# Name: 4-field FormatStringRuleHandler -> "LAST, FIRST MIDDLE SUFFIX"
# Combo order: DLICN (4 set) before DLIC (1 set) per LIMITATION #3
# v4.0: OLN>Name identifier-priority guardrail -- OperatorLicenseNumber NOT_EXISTS added to
#   DLICN (Name combo exits the pool when an OLN is also entered).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode'); any = @('ImageIndicator','RegistrationState','nameMiddle','nameSuffix'); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'DLICN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DLIC'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery -- DLICN (Name+DOB+Sex, synthetic keyRef) and DLIC (OLN). Platform requires unique keyRefs; metadata uses DLIC for both. autoSelect default query. OLN>Name guardrail v4.0.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1e2. NyNyspinDriverLicenseNameQuery (DGRP) -- REMOVED v4.11 (DEX-1284, Leo).
# The "DL NAME SEARCH" card was a name-only shadow of DriverLicenseQuery's DLICN (Name+DOB+Sex)
# combo -- an Expanded (non-Basic) transaction. Removed to condense Person to 2 cards (DL + DH).
# DL-by-name now runs via DLICN (requires Name+DOB+Sex); the looser name-only path is gone.
# Data-safe: all DGRP-suffixed fields were confined to this QIDM (audit C5-F6, 2026-07-24).
# =====================================================================

# =====================================================================
# 1f. DriverHistoryQuery
# XML: DriverHistoryQuery v3
#   DALL (OLN): Choice(set[OLN], set[OLN,PurposeCode,Requestor,State])
#               any[ImageIndicator, NyNyspinTransactionName]
#               -> in-state: set[OLN-DH], any[ImageIndicator, purposeCodeDH, requestorDH, nyNyspinTransactionName]
#               -> OOS:      set[OLN-DH, purposeCodeDH, requestorDH, registrationState], any[imageIndicator, nyNyspinTransactionName]
#   DALL (Name): Choice(set[DOB,Name,Sex], set[DOB,Name,PurposeCode,Requestor,Sex,State])
#                any[ImageIndicator, NyNyspinTransactionName]
#               -> in-state: set[DOB-DH,NameLast-DH,NameFirst-DH,SexCode-DH], any[image,purpose,requestor,txname,state,middle,suffix]
#               -> OOS:      set[DOB-DH,NameLast-DH,NameFirst-DH,SexCode-DH,purposeCodeDH,requestorDH,registrationState], any[...]
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'DALL' for all 4 DH combos; synthetic labels DALH (Name in-state),
# DALHOUT (Name OOS), DALLOUT (OLN OOS) invented for platform routing only.
# NOT real NYSPIN transaction codes. See PLATFORM_CONSTRAINTS.txt.
# PurposeCode + Requestor required for OOS DH (State filled) -- per metadata OOS Set.
# In-state any[] = ONLY imageIndicator + nyNyspinTransactionName (matches metadata <Any>);
#   State/PurposeCode/Requestor are OOS-only -- NOT in in-state combos (DALH/DALL).
# STATE ROUTING (v4.0, replaces old LIMITATION #35 value-comparison conditions): the old
#   In=IN('NY','null')/Out=NOT_EQUALS 'NY' conditions keyed on the attribute NAME ('State',
#   not sourceField) AND used value-comparison operators -- per the live-proven
#   POISONED-ARRAY RULE (knowledge-base/QIDM_REFERENCE.txt), a conditions array containing
#   ANY value-comparison operator is disabled IN ITS ENTIRETY, so these 4 combos had ZERO
#   real routing. Fixed with existence-only conditions on RegistrationState (matches
#   FL_FCIC v6.0/v7.0's identical fix):
#     in-state (DALH/DALL): RegistrationState NOT_EXISTS -- fires only when State is blank
#     OOS (DALHOUT/DALLOUT): RegistrationState EXISTS     -- fires only when State is present
#   The old "destination must not literally equal home state" rule can no longer be
#   config-enforced -- it was never actually enforced by the inert NOT_EQUALS either.
# OLN>Name identifier-priority guardrail (v4.0): OperatorLicenseNumberDH NOT_EXISTS added to
#   DALHOUT + DALH (Name combos exit the pool when an OLN-DH is also entered), composed in
#   the same conditions array as the RegistrationState routing condition above.
# NyNyspinTransactionName: visible FormInput on DH card, initialValue=DALL (officer can
#   override, e.g. DLIC). In any[] of all 4 DH combos + defaults[]=DALL. Per Visible-First
#   Mandate (BUILD_RULES Section 14) -- exposed rather than omitted. See NYSPIN op manual.
# DH-suffix fieldIds isolate DH from DL field pool (AP #14 / LIM #24-25)
# queriesToDeselect=DriverLicenseQuery -- one-directional (DH deselects DL)
# Combo order: DALHOUT (7 set) > DALH (4 set) > DALLOUT (4 set) > DALL (1 set) per LIMITATION #3
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 10; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicatorDH');      targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('NameLastDH','NameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                size = 2;  sourceField = @('RegistrationStateDH');      targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'PurposeCode';          size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{
            name        = 'Requestor'
            rule        = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size        = 35; sourceField = @('requestorDH'); targetField = 'Requestor'
        }
        [PSCustomObject]@{ name = 'NyNyspinTransactionName'; size = 4; sourceField = @('nyNyspinTransactionNameDH'); targetField = 'NyNyspinTransactionName' }
    )
    # PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
    # This QIDM's 4 combos (DALHOUT/DALH/DALLOUT/DALL) are synthetic disambiguations --
    # see the file-header keyRef inventory comment for the full rationale.
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # v4.21 (DEX-1283 follow-up): requestorDH demoted set[]->any[]. Metadata's DALH/
                # DALHOUT Choice puts Requestor in the mandatory Set branch -- REGISTERED
                # divergence, not a metadata-fidelity miss (see accept_divergence entry + KB). The
                # platform builds an attribute if it's in the fired combo's set[] OR any[]; set[]
                # additionally makes the CLIENT gate Send on the field having a value, which a
                # hidden auto-populated field with no initialValue can never satisfy (live-caught
                # 2026-08-06: DALHOUT's Send button stayed permanently disabled). any[] avoids that
                # client-side gate while the wire outcome is unchanged -- the rule handler
                # (CommsysGetLastNameFirstNameInitialRuleHandler) populates Requestor
                # unconditionally regardless of set[]/any[] placement (proven on TX_TLETS v4.19 /
                # FL_FCIC v7.18 / CA_CLETS v2.24). Routing is also unaffected: DALHOUT vs DALH is
                # already fully decided by RegistrationStateDH EXISTS/NOT_EXISTS, not by Requestor.
                set        = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH','purposeCodeDH','RegistrationStateDH')
                any        = @('ImageIndicatorDH','nameMiddleDH','nameSuffixDH','nyNyspinTransactionNameDH','requestorDH')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationStateDH');      operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'NyNyspinTransactionName'; value = 'DALL' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DALHOUT'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH')
                any        = @('ImageIndicatorDH','nameMiddleDH','nameSuffixDH','nyNyspinTransactionNameDH')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationStateDH');      operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'NyNyspinTransactionName'; value = 'DALL' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DALH'
            state                 = 'In'
        }
        [PSCustomObject]@{
            # v4.21: requestorDH demoted set[]->any[], same reasoning as DALHOUT above.
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH','purposeCodeDH','RegistrationStateDH'); any = @('ImageIndicatorDH','nyNyspinTransactionNameDH','requestorDH'); conditions = @([PSCustomObject]@{ field = @('RegistrationStateDH'); operator = 'EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'NyNyspinTransactionName'; value = 'DALL' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALLOUT'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('ImageIndicatorDH','nyNyspinTransactionNameDH'); conditions = @([PSCustomObject]@{ field = @('RegistrationStateDH'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'NyNyspinTransactionName'; value = 'DALL' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALL'
            state                 = 'In'
        }
    )
    description     = 'Mapping for DriverHistoryQuery -- DALHOUT/DALH (Name OOS/in-state), DALLOUT/DALL (OLN OOS/in-state). DH-suffix fields. NyNyspinTransactionName visible, default DALL. queriesToDeselect=DL. State routing via EXISTS/NOT_EXISTS + OLN>Name guardrail, v4.0.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# 1h. GunQuery
# XML: GunQuery v1, keyRef GINQ
#   set[GunSerialNumber], any[GunCaliber, GunMake, RelatedHitSearchIndicator]
# GunMake/GunCaliber: NCIC codeTypeSource (confirmed working).
# RelatedHitSearchIndicator: YES_NO_UNKNOWN, default Y, in any[].
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('GunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('GunMake');          targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('serialNumber');  targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('GunMake','GunCaliber','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'GINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery in NY NYSPIN EJUSTICE'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1i. ArticleSingleQuery
# XML: ArticleSingleQuery v1, keyRef AINQ
#   set[ArticleSerialNumber, ArticleTypeCode], any[ImageIndicator, RelatedHitSearchIndicator]
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown).
# RelatedHitSearchIndicator: YES_NO_UNKNOWN, default Y, in any[].
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';      size = 1;  sourceField = @('ImageIndicator');      targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'AINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery in NY NYSPIN EJUSTICE'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1j. BoatQuery
# PLATFORM CONSTRAINT: multi-combo QIDM, each combo needs a distinct keyReference
# (LIMITATION #21). Canonical example per PLATFORM_CONSTRAINTS.txt -- one QIDM, four
# combinations (RVEH/RCAR/BVEH/BVIN), each already a unique real NYSPIN transaction code
# (no synthetic renaming needed here, unlike DLICN/DALH above).
# XML: BoatQuery v2
#   RVEH: set[RegistrationNumber], any[ImageIndicator]              -- NY reg
#   RCAR: set[BoatHullIdNumber], any[ImageIndicator]                -- NY hull
#   BVEH: set[RegistrationNumber, State], any[ImageIndicator]       -- OOS reg
#   BVIN: set[BoatHullIdNumber, State], any[ImageIndicator]         -- OOS hull
# ImageIndicator: on the Boat card. NY BoatQuery metadata defines NO RelatedHitSearchIndicator,
# so no stolen toggle is built (correct -- NY Boat = Hull/Reg/State/Image only).
# Order: BVEH > BVIN > RVEH > RCAR (most-specific first)
# v4.0: Hull>Reg identifier-priority guardrail -- BoatHullIdNumber NOT_EXISTS added to
#   BVEH + RVEH (Reg combos exit the pool when a Hull ID is also entered). Hull is a
#   permanent unique identifier (HIN); Reg is reassignable -- Hull wins. Also added
#   RegistrationState EXISTS to BVEH -- set[] is NOT a firing gate, so a bare Reg-only
#   payload was previously satisfying BVEH's conditions (it had none) and shadowing RVEH
#   regardless of State (verify_build CHECK 16). Mirrors FL_FCIC's OOS-gate symmetry.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('ImageIndicator');      targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 10; sourceField = @('RegistrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('RegistrationNumber','RegistrationState')
                any        = @('ImageIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber','RegistrationState'); any = @('ImageIndicator'); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BVIN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('ImageIndicator'); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('ImageIndicator'); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery -- BVEH/BVIN (OOS), RVEH/RCAR (NY). Hull>Reg guardrail v4.0.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$nyBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NY_NYSPIN_EJUSTICE v${Version}"
    name           = 'NY_NYSPIN_EJUSTICE'
    type           = 'BUNDLE'
    provider       = 'NY_NYSPIN_EJUSTICE'
}

# =====================================================================
# BUNDLE 2: ENTITIES (5 QIFs, 7 cards total)
#
# Vehicle:  1 card (all fields)
# Person:   3 cards (OPTIONS + DRIVER LICENSE + DRIVER HISTORY)
# Firearm:  1 card
# Article:  1 card
# Boat:     1 card (all fields)
#
# NCIC state pattern: visible RegistrationState, NO initialValue (blank default -- confirmed NY).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card (v4.6): options folded into the identifier rows; card title carries the
# Plate-OR-VIN query paths. State keeps its "leave blank for NY" routing hint (the one field
# exempt from the v4.12 lean strip).
# ------------------------------------------------------------------
#
# LABEL-OVERRIDE cluster (v4.12, DEX-1284 lean label pass -- Rob's explicit cosmetic call).
# CHECK 15 Rule 3 wants a '(' / ' - ' qualifier on pure-any[] fields; these are deliberately bare
# per Rob's "strip all helpers except State" directive -- the card title now carries the query
# paths. Downgrades the WARN to accepted [INFO]. Image fields use the canonical global "NCIC Image"
# label (accepted by CHECK 15 directly -- no override needed).
# LABEL-OVERRIDE: VehicleMakeCode -- bare "Vehicle Make" per lean pass (any[] optional)
# LABEL-OVERRIDE: vehicleYear -- bare "Vehicle Year" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameMiddle -- bare "MI" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameSuffix -- bare "Suffix" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameMiddleDH -- bare "MI" per lean pass (any[] optional)
# LABEL-OVERRIDE: nameSuffixDH -- bare "Suffix" per lean pass (any[] optional)
# LABEL-OVERRIDE: GunMake -- bare "Gun Make" per lean pass (any[] optional)
# LABEL-OVERRIDE: GunCaliber -- bare "Caliber" per lean pass (any[] optional)
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per lean pass (any[] optional)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    # Single card (v4.6): SEARCH OPTIONS folded into the plate row -- no separate options card.
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE REGISTRATION SEARCH BY PLATE, "OR" VIN'
        rows  = @(
            # NOTE (v4.9, manual/Rob-confirmed): Plate Type/Year are deliberately bare, no
            # parenthetical at all -- both are prefilled via initialValue and officer-editable.
            # verify_build CHECK 15 rule 3 will WARN on these (any[]-only field with no '('/' - '
            # in its label) -- that WARN is Rob-confirmed as accepted, not a defect to chase:
            # CHECK 15's suggested hint is a bootstrapping aid for initial build/standup, not a
            # mandate on final officer-facing wording. Do not "fix" this back to "(auto)" or
            # "(default X)" in a future automated labeling pass.
            # LABEL-OVERRIDE: LicensePlateTypeCode -- Rob's explicit exception; bare "Plate Type" is
            # the intended officer-facing wording. Merely-defaulted (initialValue=PC), officer-editable,
            # any[] optional -- CHECK 15 Rule 3's "(optional)" qualifier is not wanted here.
            # LABEL-OVERRIDE: LicensePlateYear -- 'Plate Year (out-of-state)' at v4.19. v4.18 removed this
# field's initialValue and dropped it from RVEH's any[] (devdoc #1's in-state optionals are
# [ImageIndicator, LicensePlateTypeCode] only), which left a VISIBLE field that is in NO in-state
# combination -- an in-state officer typing a plate year had it silently dropped. Spec-correct but a
# usability trap created by the v4.18 fix. The qualifier tells the officer the field belongs to the
# out-of-state path, where devdoc #3 makes it MANDATORY alongside Plate Type and State.
            # (initialValue=current year, officer-editable, any[] optional).
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (out-of-state)' '4' 'ROW_VEH_1' @{} }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';             node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';                 node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            # Options row (v4.13): State + Image on the uniform 4/4/4 grid (each 4 wide, aligned
            # under the Plate#/VIN and Type/Make columns above) -- content-sized, not a half-row box
            # for a 2-char State code.
            @{ id = 'ROW_VEH_3'; cols = @('4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_3' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card (v4.6, options folded in): Plate (RVEH), Plate+State OOS (RVEHOUT), VIN+State (RVIN), VIN (RCAR)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards
# OPTIONS: RegistrationState + ImageIndicator (shared by all DL/DH/DGRP combos)
# DRIVER LICENSE: OLN + Name fields (DL combos)
# DRIVER HISTORY: OLN-DH + Name-DH fields (DH-suffix isolation)
#
# v4.8 (direct feedback, mirrors FL_FCIC DEX-1278): dropped the "(DH..." qualifier from every
# CARD_PER_DH field label -- the card's own "DRIVER HISTORY" title already disambiguates it from
# "DRIVER LICENSE" (verify_build CHECK 15 Rule 2 downgraded FAIL->Info portfolio-wide this
# session; same structural argument as FL's Person DH card). Each DH label lands on its DL
# counterpart's exact phrasing minus the DH tag (e.g. "Last Name (DH, Name search)" ->
# "Last Name (Name search)", matching NameLast_Input's existing wording); DH-only fields
# (PurposeCode/TransactionType/Requestor) just lose the "DH, " prefix. Also reordered the Name
# fields on the Person cards (DL/DH) to First-before-Last (was Last-first),
# matching FL's now-established First/Last convention. Label/order-only -- no combo/QIDM/wire
# change (Name attributes still format Last-first on the wire via FormatStringRuleHandler
# regardless of visual field order). Person re-tests from T1; Vehicle/Firearm/Article/Boat
# preserved blocked at v4.7.
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # Row 1 (v4.14): OLN + State + NCIC Image together on the top line (6/3/3) -- OLN keeps
            # the width (long identifier), State/Image are short codes. Name/DOB rows follow.
            @{ id = 'ROW_PER_DL_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name' '35' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'  '35' 'ROW_PER_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'MI'     '35' 'ROW_PER_DL_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix' '10' 'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'                                      'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # Row 1 (v4.14): OLN + State + NCIC Image together on the top line (6/3/3), mirroring the
            # DL card -- self-contained DH-own State/Image. Name/DOB rows follow.
            @{ id = 'ROW_PER_DH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_1' }
                @{ id = 'RegistrationStateDH_Input'; node = Sel 'RegistrationStateDH' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DH_1' }
                @{ id = 'ImageIndicatorDH_Input';    node = Sel 'ImageIndicatorDH' 'NCIC Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_PER_DH_1' }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name' '35' 'ROW_PER_DH_2' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name'  '35' 'ROW_PER_DH_2' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'MI'         '35' 'ROW_PER_DH_2' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix'     '10' 'ROW_PER_DH_2' }
            )}
            # DH row 3 SPLIT at v4.17 (DEX-1284, Leo's CAD review): this was a single 4-across
            # row @('3','3','3','3') holding Date of Birth + Sex + Purpose Code + Transaction Type.
            # At CAD width a 3-column FormDate compacts -- the date segments (MM/DD/YYYY) do not
            # fit a quarter-row box -- so DOB and Sex now get half a row each and the two
            # prefilled/optional fields drop to their own line beneath them.
            # Purpose Code and Transaction Type are both merely-defaulted officer-editable fields
            # (C / DALL), so they belong below the identifying fields, not competing with them.
            # This is layout-only: same fieldIds, same initialValues, same combo membership, so
            # the wire is unchanged. Applies to ALL THREE layout variants automatically --
            # MakeLayouts builds default/CAD_DISPATCH/FIRST_RESPONDER from this one definition.
            @{ id = 'ROW_PER_DH_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth'                                 'ROW_PER_DH_3' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_3' }
            )}
            @{ id = 'ROW_PER_DH_4'; cols = @('6','6'); fields = @(
                # DEX-1284 (v4.22): dropdown, not free text -- confirmed live pattern in the CA_eSUN
                # department export (2026-08-06): FormSelect + attributeTypeId='DEX_INQUIRY_PURPOSE_CODE'
                # (a platform attributeTypeId code table, same mechanism as STATE/SEX/VEHICLE_MAKE --
                # NOT a codeTypeCategory/codeTypeSource pairing). Devdoc's valid codes are C,F,E,D,J,S;
                # whether the platform's code table matches is confirmed at Rob's own render/import
                # review, same discipline as LIMITATION #38 (dropdown renders != wire-valid code).
                @{ id = 'PurposeCodeDH_Input'; node = Sel 'purposeCodeDH' 'Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE'; initialValue = 'C' } 'ROW_PER_DH_4' }
                # LABEL-OVERRIDE: nyNyspinTransactionNameDH -- Rob's explicit exception; bare
                # "Transaction Type" is the intended wording (prefilled initialValue=DALL,
                # officer-editable, any[] optional). CHECK 15 Rule 3's "(optional)" qualifier is not
                # wanted -- do not "fix" this to "(auto)"/"(default X)" in a future labeling pass.
                @{ id = 'NyNyspinTransactionName_Input'; node = Inp 'nyNyspinTransactionNameDH' 'Transaction Type' '4' 'ROW_PER_DH_4' @{ initialValue = 'DALL' } }
            )}
            # Requestor (DH) automated-identity EXCEPTION (2026-07-06, user-approved): the value
            # is knowable and stable (officer's own RMS-profile name), not officer judgment --
            # same rationale as the optional-Attention standard elsewhere. Hidden gate-feeder +
            # CommsysGetLastNameFirstNameInitialRuleHandler on the 'Requestor' QIDM attribute (see
            # below); sourceField=['requestorDH'] already pointed at this fieldId.
            # v4.20 (DEX-1283): removed the hidden feeder's initialValue='X' + the matching combo
            # defaults[] entries (same fix as TX_TLETS v4.19 / FL_FCIC v7.18 / CA_CLETS v2.24),
            # WHILE LEAVING requestorDH in set[] unchanged. Live-caught 2026-08-06: DALHOUT's Send
            # button stayed permanently disabled -- a hidden field with no initialValue submits no
            # key at all (confirmed on all three prior providers), and set[] membership means the
            # CLIENT gates Send on the field having a value, which it now never could.
            # v4.21 (same-day fix): demoted requestorDH set[]->any[] on both DALHOUT/DALLOUT
            # instead of restoring the default. REGISTERED metadata divergence -- NY's own
            # DALH/DALHOUT Choice puts Requestor in the mandatory Set branch (verified against the
            # raw XML, not the build-script comment alone) -- but the platform builds an attribute
            # from set[] OR any[] equally; set[] ADDITIONALLY imposes the client-side Send gate
            # that any[] does not. The rule handler still populates Requestor unconditionally
            # either way (proven server-side on TX/FL/CA_CLETS), so any[] keeps the wire outcome
            # identical while removing the one thing a hidden auto-populated field can never
            # satisfy without reintroducing the "X" placeholder this whole fix exists to remove.
            # Routing is unaffected: DALHOUT vs DALH is already fully decided by
            # RegistrationStateDH EXISTS/NOT_EXISTS, not by Requestor's presence.
            @{ id = 'ROW_PER_DH_5B'; cols = @('12'); fields = @(
                @{ id = 'RequestorDH_Input'; node = InpH 'requestorDH' 'Requestor (auto-populated from officer profile)' '35' 'ROW_PER_DH_5B' }
            )}
        )
    }
    # DL NAME SEARCH (DGRP) card removed v4.11 (DEX-1284) -- Person is now 2 cards (DL + DH).
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards (v4.11, DEX-1284): DRIVER LICENSE (OLN+Name, own State/Image) + DRIVER HISTORY (DH-suffix, own RegistrationStateDH/ImageIndicatorDH). DL NAME SEARCH / DGRP name-only shadow query removed.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (GINQ)
# XML: set[GunSerialNumber], any[GunMake, GunCaliber]
# GunMake/GunCaliber: NCIC code type source.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake'         'Gun Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- serial + optional make/caliber'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (AINQ)
# XML: set[ArticleSerialNumber, ArticleTypeCode]
# ArticleTypeCode: CA_CLETS (NCIC gives empty dropdown)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4'); fields = @(
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_ART_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- serial + type code'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 2 cards (SEARCH OPTIONS + BOAT SEARCH)
# SEARCH OPTIONS holds the cross-cutting modifier/router fields (State = in/out-of-state
# selector, Image, Related Hit); BOAT SEARCH holds the identifiers (Reg Number, Hull ID).
# Mirrors the Vehicle + Person card structure and FL_FCIC/HI_HCJDC_OFML's Boat Options+Search
# split. Layout-only -- same fields/fieldIds/combos, no routing change.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    # Single card (v4.6): SEARCH OPTIONS folded into the identifier row -- no separate options card.
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY REGISTRATION, "OR" HULL ID'
        rows  = @(
            # State moved off row 1 onto its own row with Image (Rob-confirmed 2026-07-17) --
            # sharing row 1 with both identifier fields left State's label wrapping. Row 1 now
            # balanced 6/6; State+Image share row 2 at 6/6, mirroring Vehicle/Person DL/DH.
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '10' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_1B'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1B' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_BOA_1B' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card (v4.6, options folded in): Reg+State (BVEH), Hull+State (BVIN), Reg (RVEH), Hull (RCAR)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — PascalCase USx fields v4.0, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields `
    -Description "Provider configuration for NY_NYSPIN_EJUSTICE v${Version} -- RMS bundle"
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $nyBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built NY_NYSPIN_EJUSTICE v${Version}" `
    -Version $Version

# Clear the rebuild-pending flags -- this build's version bump + reset_test_package regenerated
# the plan via the fixed emit_test_plan.ps1 (form-defaults namespace fix, flagged 2026-08-05), so
# the deferred condition is now satisfied. Migrated docs/tracking/ location.
$pendingPath = Join-Path $PSScriptRoot "..\docs\tracking\PENDING_UPDATES.txt"
if (Test-Path $pendingPath) { Remove-Item $pendingPath -Force }

# =====================================================================
