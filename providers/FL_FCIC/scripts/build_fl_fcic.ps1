# build_fl_fcic.ps1 -- FL_FCIC
# Builds FL_FCIC.json from source\FL_FCIC.xml metadata + KB specs.
# Layout:
#   Vehicle: 2 cards (OPTIONS: State+Image, SEARCH: compacted rows)
#   Person:  2 cards (DL + DH, compacted rows)
#   Boat:    2 cards (OPTIONS: State+Stolen+Image, SEARCH: compacted rows)
#   Firearm: 1 card (compacted)
#   Article: 1 card (compacted)
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_fl_fcic.ps1 -Version 4.3
#
# INPUTS:
#   source\FL_FCIC.xml   -- XML metadata (FCIC v94, 170+ message keys) [AUTHORITATIVE]
#   source\FL_FCIC.pdf   -- CommSys devdoc (6 basic queries) [CROSS-CHECK]
#   tools\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs, no external template)
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 QIDMs, 31 combos):
#   Combo array order follows the devdoc "Possible Combinations" listing order in every
#   QIDM (v4.7 standard). Routing conditions are EXISTENCE-ONLY (State NOT_EXISTS /
#   RelatedHit NOT_EXISTS / OLN NOT_EXISTS) -- v5.0 POISONED-ARRAY RULE: any value
#   comparison (EQUALS/NOT_EQUALS/...) disables its entire conditions array, live-proven
#   v4.9 T-A/T-B 2026-06-12 (QIDM_REFERENCE Sec 2a). Existence conditions keep later
#   OOS/stolen combos reachable under first-match AND isolate the serialization pool.
#   VehicleRegistrationQuery   FRQ (Decal/plate/Title/VIN) + RQ (plate+state/VIN+state) = 6 combos
#                              QV (plate/VIN) NOT BUILT -- devdoc "Data-Mined Transactions"
#                              (QA, QB, QG, QV, QW) = CommSys auto secondaries [PENDING CONFIRMATION]
#   DriverLicenseQuery         FDQ (Name/OLN) + DQ (Name+state/OLN+state) = 4 combos, autoSelect=true
#   WantedPersonQuery          REMOVED -- CommSys auto-sends QW (platform-confirmed, v4.2)
#   DriverHistoryQuery         KQ (Name/OLN) = 2 combos, DH-suffix fields, OUT-OF-STATE ONLY:
#                              FCIC: "KQ is out of state and <XX> destination is required ...
#                              would require the destination to be something other than FL."
#                              State in set[], no default. Not-FL gate NOT enforceable
#                              (LIMITATION -- value conditions inert; platform escalation).
#   GunQuery                   QG (serial/NCIC/PCN) = 3 combos
#   ArticleSingleQuery         QA (serial/OAN/NCIC/PCN) = 4 combos
#   BoatQuery                  FBQ (hull/decal/reg/title) + QB (hull/CG/NCIC/PCN/reg)
#                              + BQ (name/hull/reg -- Nlets OOS, restored v4.7) = 12 combos
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- 2 cards: OPTIONS(State/Image) + SEARCH(Plate/VIN/Decal/Title)
#   Person   -- 2 cards: DL(OLN/State/Image/Name/DOB/Sex) + DH(OLN/DestState/Purpose/Name/DOB/Sex/Attention, OOS-only)
#   Firearm  -- 1 card: serial + make + NCIC# + PCN + Image (2 rows)
#   Article  -- 1 card: serial + type + OAN + Image + NCIC# + PCN (2 rows)
#   Boat     -- 2 cards: OPTIONS(DestState/Stolen/Image) + SEARCH(Hull/Reg/CG/Decal/Title/NCIC/PCN/Name/DOB)
#
# FL-SPECIFIC PATTERNS:
#   Date format: yyyyMMdd (CommsysParseDateRuleHandler arguments=['yyyy-MM-dd','yyyyMMdd'])
#   Name format: FormatStringRuleHandler arguments=[','] (Last,First -- no space)
#   Attention:   Visible FormInput (AttentionDH) on DH card
#   DH-suffix:   OperatorLicenseNumberDH, NameLastDH, etc. (isolates DH from DL fields)
#   State:       No initialValue anywhere (LIMITATION #30 -- in-state vs OOS routing;
#                DH/BQ destination state must be non-FL per FCIC, cannot be defaulted).
#                ALL State fields = NCIC dropdown (attributeTypeId=STATE Sel +
#                codeTypeProvider NCIC). v5.0 reverted the v4.9 literal-FormInput
#                experiment: T-A proved value guards inert even on literal "FL", so the
#                FormInput bought nothing (POISONED-ARRAY RULE). The not-FL destination
#                rule is officer-facing only (card labels) -- LIMITATION + escalation.
#   Conditions:  NESTED inside requirements, field = @(AttributeName), value = @(...)
#                (CA_CLETS/NY live-proven wire format). v4.7's combo-level camelCase
#                scalar conditions were SILENTLY IGNORED by the platform (live XML
#                evidence 2026-06-12: full DL card over-sent all fields).

param(
    [string]$Version = "5.1"
)

$ErrorActionPreference = 'Stop'
$provider = 'FL_FCIC'
$outPath  = "$PSScriptRoot\..\FL_FCIC.json"

$currentYear = [string](Get-Date).Year
. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: FL_FCIC PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'FL_FCIC'
$results = Build-ProviderQrdm -ProviderName 'FL_FCIC'
$qmf = Build-Qmf -ProviderName 'FL_FCIC'

# =====================================================================
# 6 COMMSYS QIDMs
# =====================================================================

# --- 1. VehicleRegistrationQuery (FRQ + RQ) -- 6 combos ---
# XML: FRQ (plate/VIN/Decal/TitleLien) + RQ (plate+state/VIN+state)
# FRQ = FCIC-only (no NCIC/Nlets), RQ = with state routing
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'FRQ' and 'RQ' for multiple combos each; field-name suffixes
# (FRQLicensePlateNumber, RQLicensePlateNumber, etc.) are synthetic routing labels.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DecalNumber';                  size = 10; sourceField = @('decalNumber');                  targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('licensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TitleLienInformation';         size = 8;  sourceField = @('titleLienInformation');         targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # Devdoc order: FRQ Decal(1), FRQ Plate(2), FRQ TitleLien(3), FRQ VIN(4), [QV 5-6 not built], RQ Plate(7), RQ VIN(8)
        # FRQ combos carry State NOT_EXISTS: devdoc lists FRQ first, so a State-filled OOS
        # query must fall through to RQ; the condition also keeps State out of the FRQ pool.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('decalNumber','licensePlateYear')
                any        = @('imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FRQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('licensePlateNumber')
                any        = @('licensePlateYear','vehicleMakeCode','vehicleYear','imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EXISTS' })
                defaults   = @(
                    [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }
                    [PSCustomObject]@{ field = 'ImageIndicator';   value = 'N' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'FRQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('titleLienInformation')
                any        = @('imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FRQTitleLienInformation'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('vehicleIdentificationNumber')
                any        = @('vehicleMakeCode','vehicleYear','imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'FRQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState')
                any      = @('imageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('vehicleIdentificationNumber','registrationState')
                any      = @('vehicleMakeCode','vehicleYear','imageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- devdoc order: FRQ (Decal, plate, Title, VIN; State NOT_EXISTS), RQ (plate+state, VIN+state). 6 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_VehicleRegistrationQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# --- 2. VehicleStolenQuery -- REMOVED / QV combos PENDING CONFIRMATION ---
# Separate VehicleStolenQuery transaction is not in devdoc "Basic Queries Supported" (correct removal, v4.4).
# Devdoc DOES list QV combos 5-6 under VehicleRegistrationQuery, but QV appears in the devdoc
# "Data-Mined Transactions" list (QA, QB, QG, QV, QW) -- believed to be CommSys auto-sent
# secondary queries (QW precedent: platform-confirmed auto-send, v4.2). NOT BUILT pending
# platform confirmation. If refuted: build QV via Stolen Search toggle (Boat QB pattern).

# --- 3. DriverLicenseQuery (FDQ + DQ) -- 4 combos, autoSelect ---
# Devdoc order: FDQ Name(1), FDQ OLN(2), [QW 3-4 auto-sent], DQ Name(5), DQ OLN(6)
# Routing conditions (first-match + pool isolation):
#   State NOT_EXISTS on FDQ combos -- State filled falls through to DQ (devdoc lists FDQ first)
#   operatorLicenseNumber NOT_EXISTS on Name combos -- OLN filled falls through to the OLN
#   combo and excludes Name/DOB/Sex from the serialization pool (fixes full-card over-send)
# DQ is devdoc (In/Out): State=FL on DQ is legal, no NOT_EQUALS guard (deliberate).
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'FDQ' and 'DQ' for 2 combos each; synthetic labels
# (FDQName, FDQOperatorLicenseNumber, DQName, DQOperatorLicenseNumber) differentiate routing.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 80; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('birthDate','nameLast','nameFirst','sexCode')
                any        = @('imageIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('State');                 operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'FDQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('operatorLicenseNumber')
                any        = @('imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'FDQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('birthDate','nameLast','nameFirst','sexCode','registrationState')
                any        = @('imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @('imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- devdoc order: FDQ (Name, OLN; State NOT_EXISTS), DQ (Name+state, OLN+state). OLN NOT_EXISTS isolates Name combos. autoSelect=true.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverLicenseQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# --- 4. WantedPersonQuery (QW) -- REMOVED ---
# CommSys auto-sends QW; no QIDM needed in JSON.

# --- 5. DriverHistoryQuery (KQ) -- 2 combos, DH-suffix fields, OUT-OF-STATE ONLY ---
# FCIC (2026-06-12): "Since the KQ is out of state and <XX> which denotes the destination
# is required, yes DriverHistoryQuery can only be used out of state and would require the
# destination to be something other than FL." Devdoc: State is Mandatory, both combos (Out).
# Therefore: registrationStateDH in set[] (no default possible -- destination must be an
# explicit officer choice). NO NOT_EQUALS FL gate: value-comparison conditions are wholly
# inert and poison the entire array (POISONED-ARRAY RULE, QIDM_REFERENCE Sec 2a; live-proven
# v4.9 T-A/T-B 2026-06-12). Not-FL destination is LIMITATION + platform escalation; the
# dropdown (no FL exclusion possible) + card title carry the officer-facing guard.
# Devdoc order: KQ Name(1), KQ OLN(2). operatorLicenseNumberDH NOT_EXISTS on KQName
# (existence-only array -- the working class) falls through to KQ OLN and keeps
# Name/DOB/Sex out of the pool on OLN searches.
# CAD dispatch cannot supply a destination state, so DH will not auto-fire from CAD (correct).
# DH-suffix fields isolate from DL field pool (AP #14)
# Attention: visible FormInput (AttentionDH), NOT in combo requirements
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'KQ' for both combos; synthetic labels KQName and KQOperatorLicenseNumber
# differentiate routing. NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionDH'); targetField = 'Attention' }
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        # v5.1: attribute NAME made unique (OperatorLicenseNumberDH) so the KQName NOT_EXISTS
        # gate resolves to THIS field, not the DL QIDM's OperatorLicenseNumber. Conditions/
        # defaults/primaryFieldReference resolve attributes by NAME, entity-global; a shared
        # name collided -> the gate checked the DL field (blank on a DH query) -> never fired
        # -> full DH card over-sent Name/DOB/Sex (live FAIL 2026-06-15, txn 01KV5XVZ...).
        # targetField stays 'OperatorLicenseNumber' so the wire element is unchanged.
        [PSCustomObject]@{ name = 'OperatorLicenseNumberDH'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        # v5.0: dropdown restored (attributeTypeId=STATE Sel + NCIC reverse-lookup).
        # The v4.9 literal-FormInput experiment is over: T-A proved the NOT_EQUALS FL
        # gate is inert even against an exact-uppercase literal "FL", so the literal
        # field bought nothing and cost typo/case risk. Reverse-lookup serialization
        # is live-proven on all instances.
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('birthDateDH','nameLastDH','nameFirstDH','sexCodeDH','registrationStateDH')
                any        = @('purposeCodeDH','attentionDH')
                # Existence-only array (working class). NEVER add a value comparison
                # here -- it would poison the array and kill this NOT_EXISTS (T-B).
                # v5.1: references the unique DH attr name (not the shared 'OperatorLicenseNumber')
                # so it resolves to operatorLicenseNumberDH, not the DL field.
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('operatorLicenseNumberDH','registrationStateDH')
                any        = @('purposeCodeDH','attentionDH')
                conditions = $null
            }
            primaryFieldReference = 'OperatorLicenseNumberDH'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'Out'
        }
    )
    description     = 'DriverHistoryQuery -- OOS only (FCIC): KQ by Name+DestState, KQ by OLN+DestState. State in set[] (dropdown, no default); not-FL gate is a LIMITATION (value conditions inert). DH-suffix fields. Attention visible.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverHistoryQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# --- 6. GunQuery (QG) -- 3 combos ---
# XML: QG by serial, QG by NCIC#, QG by PCN
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QG' for all 3 combos; synthetic labels QGGunSerialNumber,
# QGNCICNumber, QGProcessControlNumber differentiate routing. NOT real FCIC transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunMake';               size = 23; sourceField = @('gunMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';       size = 11; sourceField = @('gunSerialNumber');       targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('ncicNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('processControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @('gunMake','imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGGunSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('gunMake','imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QGNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('gunMake','imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QGProcessControlNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG by serial, NCIC#, PCN.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_GunQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# --- 7. ArticleSingleQuery (QA) -- 4 combos ---
# XML: QA by serial+type, QA by OAN+type, QA by NCIC#, QA by PCN
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QA' for all 4 combos; synthetic labels QAArticleSerialNumber,
# QAOwnerAppliedNumber, QANCICNumber, QAProcessControlNumber differentiate routing.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';   size = 20; sourceField = @('articleSerialNumber');   targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';       size = 7;  sourceField = @('articleTypeCode');       targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('ncicNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('processControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleSerialNumber','articleTypeCode'); any = @('imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QAArticleSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleTypeCode','ownerAppliedNumber'); any = @('imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QAOwnerAppliedNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QANCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('imageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QAProcessControlNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA by serial+type, OAN+type, NCIC#, PCN.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_ArticleSingleQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# --- 8. BoatQuery (FBQ + QB + BQ) -- 12 combos ---
# Devdoc order: FBQ Hull(1), FBQ Decal(2), FBQ Reg(3), FBQ Title(4),
#               QB Hull(5), QB CG(6), QB NCIC(7), QB PCN(8), QB Reg(9),
#               BQ Name(10), BQ Hull(11), BQ Reg(12)
# BQ (Nlets OOS) RESTORED v4.7 -- devdoc Boat combos 10-12 ARE the BQ paths and BQ is not
# in the data-mined list. The v4.4 removal cited a devdoc "key list (FBQ + QB only)" that
# does not exist (devdoc contains no key mnemonics; combos are the authority).
# Routing conditions (v5.0: EXISTENCE-ONLY -- value comparisons poison the whole array,
# POISONED-ARRAY RULE, QIDM_REFERENCE Sec 2a, live-proven v4.9 T-A/T-B 2026-06-12):
#   FBQ all: registrationState NOT_EXISTS (State filled falls through to BQ)
#   FBQ Hull/Reg additionally: relatedHitSearchIndicator NOT_EXISTS (any Stolen Search
#   value falls through to QB -- same routing as the v4.7 NOT_EQUALS Y intent, but in
#   the working operator class; officer types Y per card hint, live-proven 13/13 v3.x)
#   QB Hull/Reg: NO conditions -- relatedHitSearchIndicator in set[] does the gating
#   BQ all: NO conditions -- the non-FL destination rule is NOT enforceable config-side
#   (LIMITATION + platform escalation, same as DH KQ)
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'FBQ', 'QB', 'BQ' for multiple combos each; field-name suffixes
# (FBQBoatHullIdNumber, QBRegistrationNumber, etc.) are synthetic routing labels.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 62; sourceField = @('boatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CoastGuardDocumentNumber';  size = 8;  sourceField = @('coastGuardDocumentNumber');  targetField = 'CoastGuardDocumentNumber' }
        [PSCustomObject]@{ name = 'DecalNumber';               size = 10; sourceField = @('decalNumber');               targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('ncicNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';      size = 10; sourceField = @('processControlNumber');      targetField = 'ProcessControlNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('registrationNumber');        targetField = 'RegistrationNumber' }
        # v5.0: dropdown restored (attributeTypeId=STATE Sel + NCIC reverse-lookup) -- the
        # literal-FormInput experiment proved nothing gates on value anyway (T-A).
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TitleLienInformation';      size = 8;  sourceField = @('titleLienInformation');      targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        # FBQ combos -- devdoc 1-4 (FCIC registration; State NOT_EXISTS defers to BQ,
        # Hull/Reg additionally RelatedHit NOT_EXISTS defers to QB -- existence-only arrays)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('boatHullIdNumber')
                any        = @('decalNumber','registrationNumber','titleLienInformation','imageIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('State');                     operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RelatedHitSearchIndicator'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'FBQBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('decalNumber')
                any        = @('boatHullIdNumber','registrationNumber','titleLienInformation','imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FBQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('registrationNumber')
                any        = @('boatHullIdNumber','decalNumber','titleLienInformation','imageIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('State');                     operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RelatedHitSearchIndicator'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'FBQRegistrationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('titleLienInformation')
                any        = @('boatHullIdNumber','decalNumber','registrationNumber','imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FBQTitleLienInformation'
            state                 = 'In/Out'
        }
        # QB combos -- devdoc 5-9 (NCIC stolen; Hull/Reg gated by relatedHitSearchIndicator
        # in set[] -- presence-based, no conditions; officer types Y per card hint)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('boatHullIdNumber','relatedHitSearchIndicator')
                any        = @('imageIndicator','registrationNumber')
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('coastGuardDocumentNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'CoastGuardDocumentNumber'
            keyReference          = 'QBCoastGuardDocumentNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QBNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('imageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QBProcessControlNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('registrationNumber','relatedHitSearchIndicator')
                any        = @('imageIndicator','boatHullIdNumber')
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QBRegistrationNumber'
            state                 = 'In/Out'
        }
        # BQ combos -- devdoc 10-12 (Nlets OOS; destination state in set[]. Non-FL rule
        # NOT enforceable config-side -- LIMITATION, dropdown + card hint only)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('birthDate','nameLast','nameFirst','registrationState')
                any        = @('boatHullIdNumber','registrationNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'BQName'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('boatHullIdNumber','registrationState')
                any        = @('registrationNumber')
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQBoatHullIdNumber'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('registrationNumber','registrationState')
                any        = @('boatHullIdNumber')
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQRegistrationNumber'
            state                 = 'Out'
        }
    )
    description     = 'BoatQuery -- devdoc order: FBQ (hull/decal/reg/title; State+RelatedHit NOT_EXISTS), QB (hull/CG/NCIC/PCN/reg; Stolen in set[]), BQ (name/hull/reg; State in set[], non-FL is LIMITATION). 12 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_BoatQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$providerBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for $provider v$Version"
    name           = $provider
    type           = 'BUNDLE'
    provider       = $provider
}

# =====================================================================
# BUNDLE 2: ENTITIES (5 QUERYINPUTFORM)
# =====================================================================

# --- Vehicle (2 cards: OPTIONS + SEARCH) ---
# OPTIONS: State+Image (routing for VehReg RQ combos)
# SEARCH: Plate/VIN/Decal/Title (VehicleRegistrationQuery fields only)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_VEH_O1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_O1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SEARCH'
        title = 'Vehicle Search'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';  node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';    node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('5','4','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';              node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';                  node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'DecalNumber_Input';                  node = Inp 'decalNumber' 'Decal Number' '10' 'ROW_VEH_3' }
                @{ id = 'TitleLienInformation_Input';         node = Inp 'titleLienInformation' 'Title/Lien Info' '8' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC 2-card: OPTIONS(State/Image) + SEARCH(Plate/VIN/Decal/Title).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# --- Person (DL card + DH card, DH-suffix fields) ---
# v3.9: Search Options merged into DL card (State+Image only serve DL)
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_DL'
        title = 'Driver License'
        rows  = @(
            @{ id = 'ROW_DL1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'OLN' '20' 'ROW_DL1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'registrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_DL1' }
                @{ id = 'ImageIndicator_Input';         node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_DL1' }
            )}
            @{ id = 'ROW_DL2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_DL2' }
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_DL2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_DL2' }
            )}
            @{ id = 'ROW_DL3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_DL3' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DL3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix' '10' 'ROW_DL3' }
            )}
        )
    }
    @{
        id    = 'CARD_DH'
        title = 'Driver History (Out-of-State Only)'
        rows  = @(
            @{ id = 'ROW_DH1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_DH1' }
                @{ id = 'RegistrationStateDH_Input';     node = Sel 'registrationStateDH' 'Destination State (not FL)' @{ attributeTypeId = 'STATE' } 'ROW_DH1' }
                @{ id = 'PurposeCodeDH_Input';            node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_DH1' }
            )}
            @{ id = 'ROW_DH2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_DH2' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_DH2' }
                @{ id = 'BirthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_DH2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DH2' }
            )}
            @{ id = 'ROW_DH4'; cols = @('12'); fields = @(
                @{ id = 'AttentionDH_Input'; node = Inp 'attentionDH' 'Attention (DH)' '30' 'ROW_DH4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (FDQ/DQ) + DH (KQ, out-of-state only) on separate cards. DH-suffix fields. QW auto-sent by CommSys.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# --- Firearm ---
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'gunMake' 'Gun Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';         node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_GUN_2' }
                @{ id = 'ProcessControlNumber_Input'; node = Inp 'processControlNumber' 'PCN' '10' 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';      node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG by serial, NCIC#, PCN.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# --- Article ---
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','2','4','2'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input';  node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
                @{ id = 'ImageIndicator_Input';      node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'NCICNumber_Input';           node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_ART_2' }
                @{ id = 'ProcessControlNumber_Input'; node = Inp 'processControlNumber' 'PCN' '10' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA by serial+type, OAN+type, NCIC#, PCN.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# --- Boat (2 cards: OPTIONS + SEARCH) ---
# OPTIONS: DestState+StolenSearch+Image (State routes BQ Nlets OOS; Stolen routes QB vs FBQ)
# SEARCH: Hull/Reg/CG/Decal/Title/NCIC/PCN + Name/DOB (BQ owner search, restored v4.7)
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_BOA_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'registrationState' 'Destination State (blank for FL, required for name/DOB)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_O1' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_BOA_O1' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_SEARCH'
        title = 'Boat Search'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'boatHullIdNumber' 'Hull ID Number' '62' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'CoastGuardDocumentNumber_Input'; node = Inp 'coastGuardDocumentNumber' 'Coast Guard Doc #' '8' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'DecalNumber_Input';              node = Inp 'decalNumber' 'Decal Number' '10' 'ROW_BOA_2' }
                @{ id = 'TitleLienInformation_Input';     node = Inp 'titleLienInformation' 'Title/Lien Info' '8' 'ROW_BOA_2' }
                @{ id = 'NCICNumber_Input';               node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_BOA_2' }
                @{ id = 'ProcessControlNumber_Input';     node = Inp 'processControlNumber' 'PCN' '10' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Owner Last Name (OOS)'  '30' 'ROW_BOA_3' }
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'Owner First Name (OOS)' '30' 'ROW_BOA_3' }
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Owner DOB (OOS)' 'ROW_BOA_3' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC 2-card: OPTIONS(DestState/Stolen/Image) + SEARCH(Hull/Reg/CG/Decal/Title/NCIC/PCN/OwnerName/DOB).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($personForm, $vehicleForm, $firearmsForm, $articleForm, $boatForm) `
    -DefaultOrder @('Person','Vehicle','Firearm','Article','Boat')

# =====================================================================
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle

# =====================================================================
# FINAL ASSEMBLY + WRITE
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

$phaseDate = Get-Date -Format "yyyy-MM-dd"
Write-ProviderJson -BundleObject $output -OutPath $outPath `
    -PhasePath "$PSScriptRoot\..\phases\FL_FCIC_v${Version}_${phaseDate}.json" `
    -Label "Built FL_FCIC v${Version}"