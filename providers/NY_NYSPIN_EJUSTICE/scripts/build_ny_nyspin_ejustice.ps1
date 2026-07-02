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
# LAYOUT (5 QIFs, 7 cards):
#   Vehicle:  1 card -- VEHICLE QUERY (Plate + VIN + State + Image)
#   Person:   3 cards -- OPTIONS (State, Image) + DRIVER LICENSE + DRIVER HISTORY
#   Firearm:  1 card
#   Article:  1 card
#   Boat:     1 card -- BOAT QUERY (Reg + Hull + State + Image + RelatedHit)
#
# QIDMs (7, 17 combos):
#   VehicleRegistrationQuery             RVIN, RVEHOUT, RVEH, RCAR
#   DriverLicenseQuery                   DLICN (Name+DOB), DLIC (OLN)  [metadata: both keyRef=DLIC; DLICN is synthetic -- platform requires unique keyRefs per QIDM]
#   NyNyspinDriverLicenseNameQuery       DGRP (autoSelect=FALSE -- manual select for name-only DMV search; avoids co-fire with DL)
#   DriverHistoryQuery                   DALHOUT, DALH, DALLOUT, DALL  [State routing via RegistrationState EXISTS/NOT_EXISTS -- see v4.0]
#   GunQuery                             GINQ
#   ArticleSingleQuery                   AINQ
#   BoatQuery                            BVEH, BVIN, RVEH, RCAR
#
# STATE: NCIC pattern CONFIRMED on NY (no initialValue -- blank default).
#   See LIMITATION #30.
# SEX: Full 3-layer NIBRS pattern CONFIRMED
# DL+DH: DH-suffix fieldIds + one-directional queriesToDeselect (DH deselects DL)
# DL+DGRP: DGRP autoSelect=false (manual) -- prevents NyNyspin co-fire on Name+DOB+Sex
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

param(
    [string]$Version = "4.0"
)

$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\NY_NYSPIN_EJUSTICE_v${Version}.json"

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
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
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
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RVIN'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEHOUT'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEH'
            state                 = 'In'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('ImageIndicator'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }) }
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
# 1e2. NyNyspinDriverLicenseNameQuery (DGRP)
# XML: NyNyspinDriverLicenseNameQuery v1
#   DGRP: set[Name], any[AddressCity, AddressStateCode, AddressStreet,
#         AddressZipCode, Age, BirthDate, MessageContinueKeyCode,
#         MiscellaneousDescriptiveText, SexCode]
# Name composite -> set[nameLast, nameFirst], any[nameMiddle, nameSuffix]
# Uses DL name fields (not DH-suffix) -- shares name pool with DL.
# autoSelect=FALSE: DGRP (set=2) would otherwise auto-fire whenever Name is
#   entered and send BEFORE DriverLicenseQuery's deselect could intercept,
#   producing a dual NyNyspinDriverLicenseNameQuery co-fire (confirmed v2.8
#   live test). With autoSelect=false the officer manually selects DGRP for a
#   name-only DMV search; Name+DOB+Sex auto-routes to DL (DLICN) alone.
# No ImageIndicator or State in this transaction's metadata.
# =====================================================================
$dgrpQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('nameMiddle','nameSuffix','BirthDate','SexCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'DGRP'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for NyNyspinDriverLicenseNameQuery -- DGRP (Name search). Manual select (autoSelect=false) so it does not co-fire with DL on Name+DOB+Sex.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_NyNyspinDriverLicenseNameQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $false
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'NyNyspinDriverLicenseNameQuery'
    queryLabel      = 'DL Name Search'
    targetEntity    = 'Person'
}

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
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('NameLastDH','NameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                size = 2;  sourceField = @('RegistrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'PurposeCode';          size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'Requestor';            size = 35; sourceField = @('requestorDH');              targetField = 'Requestor' }
        [PSCustomObject]@{ name = 'NyNyspinTransactionName'; size = 4; sourceField = @('nyNyspinTransactionNameDH'); targetField = 'NyNyspinTransactionName' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH','purposeCodeDH','requestorDH','RegistrationState')
                any        = @('ImageIndicator','nameMiddleDH','nameSuffixDH','nyNyspinTransactionNameDH')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');        operator = 'EXISTS' }
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
                any        = @('ImageIndicator','nameMiddleDH','nameSuffixDH','nyNyspinTransactionNameDH')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');        operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'NyNyspinTransactionName'; value = 'DALL' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DALH'
            state                 = 'In'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH','purposeCodeDH','requestorDH','RegistrationState'); any = @('ImageIndicator','nyNyspinTransactionNameDH'); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'NyNyspinTransactionName'; value = 'DALL' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALLOUT'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('ImageIndicator','nyNyspinTransactionNameDH'); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'NyNyspinTransactionName'; value = 'DALL' }) }
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
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('GunSerialNumber');  targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';  size = 1;  sourceField = @('ImageIndicator');   targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @('ImageIndicator','GunMake','GunCaliber','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }
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
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }
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
# ImageIndicator: on Boat OPTIONS card. RelatedHitSearchIndicator: YES_NO_UNKNOWN, default Y.
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
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('RegistrationNumber','RegistrationState')
                any        = @('ImageIndicator','relatedHitSearchIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber','RegistrationState'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BVIN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }) }
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
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dgrpQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
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
# Vehicle -- 1 card
# All vehicle fields on one card. State blank=NY, filled=OOS.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE QUERY - Leave State blank for NY'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (optional)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (optional)' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';             node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';                 node = Inp 'vehicleYear' 'Vehicle Year (optional)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_3' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- single card: Plate (RVEH), VIN+State (RVIN), VIN (RCAR)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards
# OPTIONS: RegistrationState + ImageIndicator (shared by all DL/DH/DGRP combos)
# DRIVER LICENSE: OLN + Name fields (DL + DGRP combos)
# DRIVER HISTORY: OLN-DH + Name-DH fields (DH-suffix isolation)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'SEARCH OPTIONS - Leave State blank for NY'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '35' 'ROW_PER_DL_2' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '35' 'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('6','6'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name (optional)' '35' 'ROW_PER_DL_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix (optional)'      '10' 'ROW_PER_DL_3' }
            )}
            @{ id = 'ROW_PER_DL_4'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'                                                    'ROW_PER_DL_4' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_4' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH_1' }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name (DH)'  '35' 'ROW_PER_DH_2' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name (DH)' '35' 'ROW_PER_DH_2' }
            )}
            @{ id = 'ROW_PER_DH_3'; cols = @('6','6'); fields = @(
                @{ id = 'NameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH)' '35' 'ROW_PER_DH_3' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH)'      '10' 'ROW_PER_DH_3' }
            )}
            @{ id = 'ROW_PER_DH_4'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'DOB (DH)'                                                         'ROW_PER_DH_4' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_4' }
            )}
            @{ id = 'ROW_PER_DH_5'; cols = @('6','6'); fields = @(
                @{ id = 'PurposeCodeDH_Input'; node = Inp 'purposeCodeDH' 'Purpose Code (DH)' '1'  'ROW_PER_DH_5' @{ initialValue = 'C' } }
                @{ id = 'RequestorDH_Input';   node = Inp 'requestorDH'   'Requestor (DH)'    '35' 'ROW_PER_DH_5' }
            )}
            @{ id = 'ROW_PER_DH_6'; cols = @('12'); fields = @(
                @{ id = 'NyNyspinTransactionName_Input'; node = Inp 'nyNyspinTransactionNameDH' 'Transaction Type (DH, optional)' '4' 'ROW_PER_DH_6' @{ initialValue = 'DALL' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- OPTIONS + DRIVER LICENSE (OLN+Name, DL+DGRP) + DRIVER HISTORY (DH-suffix)'
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
        title = 'FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake'         'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_GUN_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_GUN_2' }
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
        title = 'ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4'); fields = @(
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_ART_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_ART_2' }
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
# Boat -- 1 card
# All boat fields on one card. State blank=NY, filled=OOS.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT QUERY - Leave State blank for NY'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '10' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_BOA_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (optional)' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- single card: Reg+State (BVEH), Hull+State (BVIN), Reg (RVEH), Hull (RCAR)'
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

# =====================================================================