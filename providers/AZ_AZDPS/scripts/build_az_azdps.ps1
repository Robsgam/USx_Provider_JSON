# build_az_azdps.ps1
# Builds AZ_AZDPS_v<X.Y>.json from source\AZ_AZDPS.xml + tools\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
# SINGLE-JSON multi-card build (consolidated from the retired BASE + MC scripts at v3.0).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_az_azdps.ps1
#
# v3.4 (2026-08-01, ONE WIRE FIX + FOUR REGISTRATIONS -- all decided from AZ's OWN devdoc + metadata):
#   WIRE FIX -- Boat hull searches were SILENTLY DROPPING a registration number the provider accepts.
#     v3.1 hardened Hull>Reg by gating the Reg combos `BoatHullIdNumber NOT_EXISTS` (correct, kept) AND
#     by removing RegistrationNumber from the HULL combos' any[] "so the hull pool never carries the
#     reg number". That second half conflated two different things. WHICH COMBO FIRES is the guardrail
#     and the NOT_EXISTS gate already enforces it. WHAT THE WINNER TRANSMITS is separate, and both
#     authorities say carry it: metadata ACQB{BoatHullIdNumber} = Set[BadgeNumber, BoatHullIdNumber]
#     Any[RegistrationNumber, RelatedHitSearchIndicator], and devdoc BoatQuery #1 lists
#     RegistrationNumber as a legal optional. audit_devdoc_optionals reported it on 4 fills ("fires
#     ACQBH but optional(s) RegistrationNumber are in NO matching combo's set[]/any[]").
#     RESTORED to ACQBH + BQH any[]. NOT reversed on ACQB/BQ -- those are gated hull-NOT_EXISTS, so
#     hull can never be present when they fire and listing it would be dead config.
#     Identifier priority is about ROUTING, never about deleting a permitted field from the payload.
#   REGISTERED (4 audit_metadata CHECK 4e FAILs, all variant-matching artefacts, none a real defect):
#     KQ | BirthDateDH + SexCodeDH -- built KQ declares PF=OperatorLicenseNumber and implements
#       metadata KQ{OperatorLicenseNumber} = Set[State, OperatorLicenseNumber] EXACTLY; the finding
#       pairs it against the sibling KQ{Name} variant, which KQH implements. Promoting them would make
#       the OLN-only driver-history search -- the commonest one -- unreachable.
#     DQSS | BirthDate + SexCode -- DQSS is a SYNTHETIC keyRef, so the auditor resolves it by PREFIX to
#       the DQ family and compares against DQ{Name}. Its real variant is DQ{SocialSecurityNumber} =
#       Set[SocialSecurityNumber], which requires nothing else at all.
#   REGISTERED (2 devdoc-optionals NO-FIRE): devdoc brackets SexCode as optional on the name searches
#     (#1 "BadgeNumber, BirthDate, Name, [SexCode]" and #3 "Name, [SexCode]") but metadata makes it
#     MANDATORY on every name variant -- ACWL{Name} and DQ{Name} both put SexCode in <Set>, and there
#     is no looser one. Metadata is FIELD-authority. Building to the brackets would emit a request no
#     variant accepts. The gate itself confirms the build is right: "#1 +[SexCode] -> ACWL" is OK.
#   GATE DEFECT FOUND, NOT YET FIXED (recorded so it is not mistaken for coverage): the devdoc parser
#     DROPS combination items containing an `="Y"` literal and SILENTLY RENUMBERS the rest, so AZ's
#     devdoc items #2 and #5 (the ImageIndicator="Y" + Requestor image-request variants) are invisible
#     to audit_devdoc_combinations, and its printed item numbers do NOT match the devdoc's. Neither is
#     buildable anyway (metadata ACWL has no ImageIndicator/Requestor field), but a silently skipped
#     item is the same class as a gate reading the wrong authority.
#   No re-sweep cost: AZ has never been USx-tenant-tested. ALL 5 ENTITIES RESET at v3.4.
# v3.3 (2026-07-28, SCOPE CORRECTION -- direct Rob directive): build ONLY the devdoc "Basic Queries
#   Supported" section. The AZ Basic list is exactly 6 queries (ArticleSingleQuery, BoatQuery,
#   DriverHistoryQuery, DriverLicenseQuery, GunQuery, VehicleRegistrationQuery). WMPIWantedPersonInquiry
#   + WMPIMissingPersonInquiry are NOT in it (they live in a separate "Wanted Missing Person Inquiries
#   (WMP-I)" devdoc section) -- so they are REMOVED: both QIDMs deleted, the Person WANTED/MISSING card
#   removed, Person is now 2 cards (DRIVER LICENSE + DRIVER HISTORY) like the rest of the portfolio.
#   raceCode was the only WMPI-card field the RMS person search still needs (race <- raceCode), so it
#   was RELOCATED to the DL card (bare "Race", NJ/CA pattern). The other WMPI-only fields (NCICNumber,
#   ExpandedName/BirthDate, Age/Height/Weight/Eye/Hair/AreaCode/FormORI, Person relatedHitSearchIndicator)
#   are gone with the card. This clears the 18 audit_metadata WARNs (they were the metadata-vs-Basic
#   delta for the out-of-scope WMPI paths -- the "no combo left behind rule is BASIC-scoped" lesson).
#   Rationale: I had proposed BUILDING the unbuilt WMPI paths to satisfy those WARNs -- the inverse of
#   the devdoc-authority rule; Rob corrected it. Layout + query-set change (removes 2 non-Basic queries),
#   no change to the 6 retained queries' wire. ALL 5 ENTITIES RESET at v3.3. NOT yet USx-tenant-tested.
# v3.2 (2026-07-28, DEX-1284 convention pass -- direct Rob feedback, layout/label-only, NO functional
#   change): brought AZ from the pre-DEX-1284 methodology in line with the FL/NJ/HI/NY/TX/CA portfolio.
#   STRUCTURE: Vehicle 3 cards (OPTIONS+PLATE+VIN) -> 1; Boat 3 cards (OPTIONS+REG+HULL) -> 1; Person
#   7 cards -> 3 (DRIVER LICENSE / DRIVER HISTORY / WANTED-MISSING). The shared hidden badge
#   (dexStateUserId, per-entity), RegistrationStateDH SelH, and Attention feeder all fold onto the
#   card that consumes them -- preserved exactly (fieldIds/initialValues/InpH/SelH unchanged).
#   CA-LESSON CHECK applied: verified from the QIDM set[]/any[] that BOTH WMPI queries source the DL
#   card's shared Name/DOB/Sex, so the DL name stays VISIBLE (WMPI reads it from the pool -- no orphan);
#   a Wanted/Missing name search enters Name on the Driver License card + descriptors on the
#   Wanted/Missing card (shared-name design, unchanged wire).
#   LABELS: OLN (License Number (DL)/(DH) -> "OLN"); "Related Hit (Y)" -> "Stolen Check"
#   (Firearm/Article/Boat/WMPI); stripped every "(optional)"/"(DH)" helper -> bare + LABEL-OVERRIDE
#   (Make/Year, MI/Suffix, Exp Name/DOB, Area Code/Form ORI, Gun Make/Model/Caliber); State
#   "(default AZ - change for out-of-state)" -> bare "State" (initialValue=AZ kept, NJ pattern,
#   LABEL-OVERRIDE); card titles enumerate query paths; M.I. -> MI; dropped "(DH)" field qualifiers.
#   AZ has NO ImageIndicator (NCIC Image N/A). No combo/QIDM/routing/fieldId/default/wire change.
#   ALL 5 ENTITIES RESET at v3.2. NOT yet USx-tenant-tested.
# v3.1 (2026-07-24): identifier-priority guardrails HARDENED from demotion-only to existence-gate.
#   v3.0 had ZERO conditions on its CommSys combos -- "priority" was implemented only by demoting the
#   lower identifier to any[], which does NOT create mutual exclusivity (LIMITATION #1: any[] fields
#   still enter the union pool). Multi-identifier input over-sent (plate query also serialized VIN; DL
#   name query also serialized OLN+SSN; DH name also OLN; boat reg also Hull; WMPI name also NCIC).
#   v3.1 adds existence-only EXISTS/NOT_EXISTS conditions (the proven CA_VENTURA/CA_eSUN pattern):
#     Vehicle Plate>VIN   : ACVRV gets LicensePlateNumber NOT_EXISTS (+ VIN dropped from ACVR any[])
#     DL      OLN>SSN>Name: DQSS gets OLN NOT_EXISTS; ACWL/DQN get OLN+SSN NOT_EXISTS
#                           (+ Name/SSN dropped from DQ any[], Name dropped from DQSS any[])
#     DH      OLN>Name     : KQH gets OperatorLicenseNumberDH NOT_EXISTS (DH-suffix pool)
#     Boat    Hull>Reg     : ACQB/BQ get BoatHullIdNumber NOT_EXISTS (+ Hull dropped from their any[])
#     WMPI    NCIC>Name    : ACQW/ACQM get NCICNumber NOT_EXISTS (+ NCIC dropped from their any[])
#   No State gates added: AZ has NO in-state/OOS keyRef split (single combo per identifier, State
#   default AZ in any[]) -- LIMITATION #30 does not apply. Query set/keyRefs/DH-suffix/badge/Attention
#   feeder/-KeepSsn all unchanged. Guardrail-hardening only. NOT yet live-tested at v3.1.
#
# METHODOLOGY (v3.0 rebuild, 2026-07-22):
#   - USx CAD-integration field names authored in PascalCase DIRECTLY (layout fieldIds, QIDM
#     sourceField, combo set[]/any[]) to match Cringer's reference. Mark43/RMS-internal keys
#     (dexStateUserId, vehicleYear, nameMiddle/nameSuffix, relatedHitSearchIndicator, attention,
#     purposeCode, WMPI descriptors, SocialSecurityNumber) stay camelCase / as-authored.
#     RMS form-fed fields recased via Build-RmsBundle -PascalCaseUsxFields. NEVER a whole-tree
#     recase post-transform (the removed Convert-UsxCasing collapsed Craft.js nodes arrays).
#   - QIDM attribute `name` and `targetField` are the metadata wire contract and are UNCHANGED
#     by the casing pass (e.g. State attribute keeps name/targetField='State'; only its
#     sourceField recases registrationState -> RegistrationState).
#   - GunQuery serial number uses fieldId/sourceField/set 'serialNumber' (CAD sends camelCase
#     serialNumber) while attribute name + targetField + primaryFieldReference stay
#     'GunSerialNumber' -- same class of CAD fix already applied to NJ/FL/HI/TX.
#   - Single versioned root JSON (AZ_AZDPS_v${Version}.json); phases/ retired (git history is the
#     archive); Write-ProviderJson deletes any stale root sibling (incl. legacy AZ_AZDPS_MC.json).
#
# QUERYINPUTDATAMAPPING (CommSys -- 8 QIDMs):
#   VehicleRegistrationQuery         ACVR (Plate+Badge), ACVRV (VIN+Badge -- invented)
#   AzAzdpsDriverLicenseQuery        DQ (OLN), DQN (Name), DQSS (SSN), ACWL (Badge+Name)
#   DriverHistoryQuery               KQ (OLN+State), KQH (Name+State -- invented)
#   GunQuery                         ACQG (Badge+Serial)
#   ArticleSingleQuery               ACQA (Badge+Type+Serial)
#   BoatQuery                        ACQB (Reg+Badge), ACQBH (Hull+Badge), BQ (Reg), BQH (Hull)
#   (WMPI Wanted/Missing REMOVED v3.3 -- not in the devdoc "Basic Queries Supported" section.)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle (1 card), Person (2 cards: DL+DH), Firearm (1 card), Article (1 card), Boat (1 card)
#
# STATE: NCIC pattern confirmed (attributeTypeId=STATE, codeTypeProvider=NCIC)
# SEX: NIBRS confirmed (attributeTypeId=SEX, codeTypeProvider=NIBRS)
# DH-SUFFIX: OperatorLicenseNumberDH, NameLastDH, etc. -- isolates DH from DL field pool
# BadgeNumber: hidden field auto-populated via dexStateUserId (CommsysGetDexStateUserIdRuleHandler)
# KeepSsn: AZ includes socialSecurityNumber in the RMS Person bundle.
# Date format: yyyyMMdd (AZ)
#
# CRITICAL: Same fieldId CANNOT appear on multiple cards -- causes Internal Server Error.
#           Shared fields (RegistrationState, dexStateUserId, RegistrationStateDH) go on shared
#           OPTIONS cards.
#
# keyRef INVENTORY (LIMITATION #21 -- ConnectCIC requires unique keyRefs per QIDM; multi-combo
# QIDMs below reuse metadata keyRefs + invented distinct keyRefs where two combos share one):
#   VehicleRegistrationQuery   : ACVR (Plate), ACVRV (VIN -- invented)
#   AzAzdpsDriverLicenseQuery  : ACWL (Badge+Name), DQN (Name -- invented), DQ (OLN), DQSS (SSN)
#   DriverHistoryQuery         : KQ (OLN), KQH (Name -- invented)
#   BoatQuery                  : ACQB (Reg+Badge), ACQBH (Hull+Badge), BQ (Reg), BQH (Hull)
#
# LABEL-OVERRIDE: LicensePlateTypeCode -- merely-defaulted convenience field (initialValue PC), no
#   routing meaning; bare label is the accepted portfolio pattern (NY/TX precedent, CHECK 15 Rule 3)
# LABEL-OVERRIDE: LicensePlateYear -- merely-defaulted convenience field (initialValue current year),
#   no routing meaning; bare label accepted (NY/TX precedent, CHECK 15 Rule 3)

$ErrorActionPreference = "Stop"
$Version = '3.4'
$currentYear = [string](Get-Date).Year
$DIR    = (Resolve-Path "$PSScriptRoot\..").Path
$OUT    = "$DIR\AZ_AZDPS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }
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
        [PSCustomObject]@{ name = 'BadgeNumber';                 size = 4;  sourceField = @('dexStateUserId');              targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('RegistrationState');           targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Plate>VIN guardrail: VIN removed from any[] so the plate combo's serialized
                # pool never carries VehicleIdentificationNumber (VIN has its own combo ACVRV).
                set = @('dexStateUserId','LicensePlateNumber')
                any = @('LicensePlateYear','LicensePlateTypeCode','RegistrationState','VehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                    [PSCustomObject]@{ field = 'State';                value = 'AZ' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ACVR'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Plate>VIN guardrail: LicensePlateNumber NOT_EXISTS gates this VIN combo OUT when
                # a plate is present, so plate+VIN co-entry fires ACVR (plate) only and VIN is not
                # double-sent. Plate removed from any[] per gate-xor-companion (CHECK 14).
                set = @('dexStateUserId','VehicleIdentificationNumber')
                any = @('LicensePlateTypeCode','LicensePlateYear','RegistrationState','VehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                    [PSCustomObject]@{ field = 'State';                value = 'AZ' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                )
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
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';  size = 9;  sourceField = @('SocialSecurityNumber');  targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationState');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN>SSN>Name cascade: this Name combo is gated OUT when OLN or SSN is present, so
                # the higher-priority identifier's combo (DQ/DQSS) fires alone. OLN+SSN removed from
                # any[] per gate-xor-companion (CHECK 14).
                set = @('dexStateUserId','BirthDate','NameLast','NameFirst','SexCode')
                any = @('nameMiddle','nameSuffix','RegistrationState')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    # Badge-present gate: ACWL is the metadata badge+Name transaction; DQN is the
                    # no-badge Name fallback (metadata DQ-Name has no BadgeNumber). dexStateUserId
                    # EXISTS makes ACWL fire only when the badge is present, so it no longer shadows
                    # DQN's badge-absent path (CHECK 16). Badge is auto-populated, so in practice
                    # ACWL is the live name-search combo; DQN is the metadata-faithful fallback.
                    [PSCustomObject]@{ field = @('dexStateUserId');        operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('SocialSecurityNumber');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACWL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN>SSN>Name cascade: gated OUT when OLN or SSN is present (higher-priority combo
                # fires alone). OLN+SSN removed from any[] per gate-xor-companion (CHECK 14).
                set = @('NameLast','NameFirst','SexCode','BirthDate')
                any = @('dexStateUserId','nameMiddle','nameSuffix','RegistrationState')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('SocialSecurityNumber');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN is the top of the OLN>SSN>Name cascade -- no NOT_EXISTS gate needed (it always
                # wins). Lower-priority identifiers (Name-composite + SSN) removed from any[] so the
                # OLN combo's serialized pool never carries Name or SSN. SexCode/BirthDate kept as
                # demoted-to-any companions (metadata DQ-Name descriptors; see ACCEPTED_DIVERGENCES).
                set = @('OperatorLicenseNumber')
                any = @('dexStateUserId','BirthDate','RegistrationState','SexCode')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN>SSN>Name cascade: SSN sits below OLN, above Name. OperatorLicenseNumber
                # NOT_EXISTS gates this combo OUT when OLN is present (DQ fires alone). Name-composite
                # removed from any[] so the SSN pool never carries Name; OLN removed per CHECK 14.
                set = @('SocialSecurityNumber')
                any = @('dexStateUserId','BirthDate','RegistrationState','SexCode')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
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
# DH-suffix isolation. RegistrationStateDH hidden with initialValue='AZ'. Date: yyyyMMdd.
# =====================================================================
$dhistQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'Attention'
            rule        = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size        = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCode');             targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationStateDH');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN>Name guardrail (DH-suffix pool): OperatorLicenseNumberDH NOT_EXISTS gates this
                # DH Name combo OUT when a DH OLN is present, so KQ (OLN) fires alone. OLN-DH removed
                # from any[] per gate-xor-companion (CHECK 14).
                set = @('RegistrationStateDH','NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH')
                any = @('attention','NameMiddleDH','NameSuffixDH','purposeCode')
                defaults = @(
                    [PSCustomObject]@{ field = 'Attention'; value = 'X' }
                    [PSCustomObject]@{ field = 'State';     value = 'AZ' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN is top of the DH OLN>Name pair -- no gate needed. Name-composite (DH-suffix)
                # removed from any[] so the OLN pool never carries the DH Name. BirthDateDH/SexCodeDH
                # kept as demoted-to-any companions (metadata KQ-Name descriptors; see DIVERGENCES).
                set = @('RegistrationStateDH','OperatorLicenseNumberDH')
                any = @('attention','BirthDateDH','purposeCode','SexCodeDH')
                defaults = @(
                    [PSCustomObject]@{ field = 'Attention'; value = 'X' }
                    [PSCustomObject]@{ field = 'State';     value = 'AZ' }
                )
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
# CAD sends camelCase serialNumber -> fieldId/sourceField/set use 'serialNumber';
# attribute name + targetField + primaryFieldReference stay 'GunSerialNumber' (wire unchanged).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'GunCaliber';               size = 4;  sourceField = @('GunCaliber');               targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                  size = 4;  sourceField = @('GunMake');                  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                 size = 11; sourceField = @('GunModel');                 targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';          size = 11; sourceField = @('serialNumber');             targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','serialNumber')
                any = @('GunCaliber','GunMake','GunModel','relatedHitSearchIndicator')
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
        [PSCustomObject]@{ name = 'ArticleSerialNumber';      size = 11; sourceField = @('ArticleSerialNumber');      targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';          size = 7;  sourceField = @('ArticleTypeCode');          targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','ArticleTypeCode','ArticleSerialNumber')
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
        [PSCustomObject]@{ name = 'BoatHullIdNumber';         size = 20; sourceField = @('BoatHullIdNumber');         targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';       size = 8;  sourceField = @('RegistrationNumber');       targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State';                    size = 2;  sourceField = @('RegistrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull>Reg guardrail: BoatHullIdNumber NOT_EXISTS gates this Reg combo OUT when a
                # hull is present (ACQBH fires alone). Hull removed from any[] per CHECK 14.
                set = @('dexStateUserId','RegistrationNumber')
                any = @('RegistrationState','relatedHitSearchIndicator')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    # Badge-present gate (see ACWL): ACQB/ACQBH are the badge boat transactions;
                    # BQ/BQH are the no-badge fallbacks. dexStateUserId EXISTS stops the badge combo
                    # shadowing the no-badge combo's payload (CHECK 16).
                    [PSCustomObject]@{ field = @('dexStateUserId');    operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ACQB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull is top of the Hull>Reg pair -- no Hull/Reg gate. Badge-present gate (see ACQB)
                # keeps the badge/no-badge routing symmetric (ACQBH is badge, BQH is fallback).
                #
                # v3.4: RegistrationNumber RESTORED to any[]. It had been removed "so the hull pool
                # never carries the reg number", but that conflated two different things:
                #   * WHICH COMBO FIRES is the guardrail, and it is already enforced by the
                #     `BoatHullIdNumber NOT_EXISTS` condition on the Reg combos (ACQB / BQ) -- enter
                #     both and the hull combo still wins, unchanged.
                #   * WHAT THE WINNER TRANSMITS is a separate question, and BOTH authorities say
                #     carry it: metadata ACQB{BoatHullIdNumber} is
                #     Set[BadgeNumber, BoatHullIdNumber] Any[RegistrationNumber, RelatedHitSearchIndicator],
                #     and devdoc BoatQuery #1 lists RegistrationNumber as a legal optional.
                # Scrubbing it meant an officer could type a registration number the provider accepts
                # as a refinement and have it SILENTLY DROPPED -- audit_devdoc_optionals reported
                # exactly that on 4 fills ("fires ACQBH but optional(s) RegistrationNumber are in NO
                # matching combo's set[]/any[]"). Priority is about routing, never about deleting a
                # permitted field from the winner's payload.
                # NOT done in the reverse direction: BoatHullIdNumber must NOT go into the Reg combos'
                # any[], because they are gated hull-NOT_EXISTS -- a field that can never be present
                # when the combo fires is dead config (verify_build rejects gate-XOR-companion).
                set = @('dexStateUserId','BoatHullIdNumber')
                any = @('RegistrationNumber','RegistrationState','relatedHitSearchIndicator')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('dexStateUserId'); operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ACQBH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull>Reg guardrail (no-Badge path): BoatHullIdNumber NOT_EXISTS gates this Reg
                # combo OUT when a hull is present (BQH fires alone). Hull removed from any[].
                set = @('RegistrationNumber')
                any = @('dexStateUserId','RegistrationState','relatedHitSearchIndicator')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull is top of the Hull>Reg pair (no-Badge path) -- no gate.
                # v3.4: RegistrationNumber RESTORED to any[], same reasoning as ACQBH above -- the
                # Hull>Reg guardrail is the `BoatHullIdNumber NOT_EXISTS` gate on BQ, not the removal
                # of a metadata-permitted, devdoc-listed optional from the winner's payload.
                set = @('BoatHullIdNumber')
                any = @('RegistrationNumber','dexStateUserId','RegistrationState','relatedHitSearchIndicator')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
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
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43) -- MULTI-CARD
# =====================================================================

# VEHICLE -- 3 cards: OPTIONS, PLATE SEARCH, VIN SEARCH
# RegistrationState + dexStateUserId on shared OPTIONS card (no duplicate fieldIds)
# v3.2: collapsed 3 cards (OPTIONS+PLATE+VIN) -> 1. State + hidden badge fold onto the single card.
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE REGISTRATION SEARCH BY LICENSE PLATE, "OR" VIN'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicPlate_Input';  node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'PlateType_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'PlateYear_Input'; node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'VIN_Input';       node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                # LABEL-OVERRIDE: VehicleMakeCode -- bare per DEX-1284 lean pass (any[] optional VIN qualifier)
                @{ id = 'Make_Veh_Input';  node = Sel 'VehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                # LABEL-OVERRIDE: vehicleYear -- bare per DEX-1284 lean pass (any[] optional VIN qualifier)
                @{ id = 'Year_Veh_Input';  node = Inp 'vehicleYear' 'Year' '4' 'ROW_VEH_2' }
            )}
            # LABEL-OVERRIDE: RegistrationState -- bare "State" (NJ pattern); initialValue=AZ kept, officer-editable for OOS, not an in/out routing toggle
            @{ id = 'ROW_VEH_3'; cols = @('6'); fields = @(
                @{ id = 'State_Veh_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Veh'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_VEH_BADGE' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card (v3.2, collapsed from OPTIONS+PLATE+VIN): Plate/Type/Year, VIN/Make/Year, State, hidden badge. Plate+Badge (ACVR) and VIN+Badge (ACVRV).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# PERSON -- 2 cards (v3.3): DRIVER LICENSE + DRIVER HISTORY. (v3.2 consolidated the old 7 cards to 3;
# v3.3 then removed the WANTED/MISSING card with the out-of-Basic-scope WMPI queries.) Shared hidden
# fields fold onto the consuming card: dexStateUserId badge on DL; RegistrationStateDH (SelH) +
# Attention feeder on DH. raceCode (RMS person-search "race") lives on the DL card.
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, SSN, "OR" NAME'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('6','6'); fields = @(
                @{ id = 'OLN_Per_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                @{ id = 'SSN_Per_Input'; node = Inp 'SocialSecurityNumber' 'SSN' '9' 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '20' 'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('3','3','3','3'); fields = @(
                # LABEL-OVERRIDE: nameMiddle -- bare "MI" per DEX-1284 lean pass (any[] optional)
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'MI'     '20' 'ROW_PER_DL_3' }
                # LABEL-OVERRIDE: nameSuffix -- bare "Suffix" per DEX-1284 lean pass (any[] optional)
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'  '4' 'ROW_PER_DL_3' }
                @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'  'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
            @{ id = 'ROW_PER_DL_4'; cols = @('6','6'); fields = @(
                # LABEL-OVERRIDE: RegistrationState -- bare "State" (NJ pattern); initialValue=AZ kept
                @{ id = 'State_Per_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_PER_DL_4' }
                # LABEL-OVERRIDE: raceCode -- bare "Race" (any[]/RMS-only person-search field; relocated from the removed WMPI card, v3.3)
                @{ id = 'RaceCode_Input'; node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_4' }
            )}
            @{ id = 'ROW_PER_DL_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Per'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_PER_DL_BADGE' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, "OR" NAME'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('8','4'); fields = @(
                @{ id = 'OLN_DH_Input';     node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_1' }
                @{ id = 'Purpose_DH_Input';  node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_PER_DH_1' }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name'  '30' 'ROW_PER_DH_2' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name' '20' 'ROW_PER_DH_2' }
            )}
            @{ id = 'ROW_PER_DH_3'; cols = @('3','3','3','3'); fields = @(
                # LABEL-OVERRIDE: NameMiddleDH -- bare "MI" per DEX-1284 lean pass (any[] optional)
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'MI'     '20' 'ROW_PER_DH_3' }
                # LABEL-OVERRIDE: NameSuffixDH -- bare "Suffix" per DEX-1284 lean pass (any[] optional)
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix'  '4' 'ROW_PER_DH_3' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'BirthDateDH'  'Date of Birth'  'ROW_PER_DH_3' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'SexCodeDH' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_3' }
            )}
            # DH self-contained: hidden RegistrationStateDH (SelH, initialValue AZ) + Attention feeder.
            @{ id = 'ROW_PER_DH_STEDH'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'StateDH_Input'; node = SelH 'RegistrationStateDH' 'State (DH)' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_PER_DH_STEDH' }
            )}
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'X' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards (v3.3): DRIVER LICENSE (OLN/SSN/Name/DOB/Sex/State/Race + hidden badge) + DRIVER HISTORY (DH-suffix + hidden StateDH/Attention). WMPI Wanted/Missing removed v3.3 (out of devdoc Basic Queries Supported scope); Race relocated to the DL card for RMS person search.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# FIREARM -- 1 card
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('12'); fields = @(
                @{ id = 'Serial_FA_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_FA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_GUN_BADGE' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                # LABEL-OVERRIDE: GunMake -- bare per DEX-1284 lean pass (any[] optional)
                @{ id = 'Make_FA_Input';   node = Sel 'GunMake'    'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                # LABEL-OVERRIDE: GunModel -- bare per DEX-1284 lean pass (any[] optional)
                @{ id = 'Model_FA_Input';  node = Inp 'GunModel'   'Model'   '11' 'ROW_GUN_2' }
                # LABEL-OVERRIDE: GunCaliber -- bare per DEX-1284 lean pass (any[] optional)
                @{ id = 'Cal_FA_Input';    node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
            # LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
            @{ id = 'ROW_GUN_3'; cols = @('4'); fields = @(
                @{ id = 'RelHit_FA_Input'; node = Inp 'relatedHitSearchIndicator' 'Stolen Check' '1' 'ROW_GUN_3' }
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

# ARTICLE -- 1 card
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY TYPE + SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('5','7'); fields = @(
                @{ id = 'Type_ART_Input';   node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'Serial_ART_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '11' 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_ART'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_ART_BADGE' }
            )}
            # LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
            @{ id = 'ROW_ART_2'; cols = @('4'); fields = @(
                @{ id = 'RelHit_ART_Input'; node = Inp 'relatedHitSearchIndicator' 'Stolen Check' '1' 'ROW_ART_2' }
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
# v3.2: collapsed 3 cards (OPTIONS+REGISTRATION+HULL) -> 1. Both identifiers on row 1, State + Stolen
# Check on row 2, hidden badge.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY REGISTRATION NUMBER, "OR" HULL ID'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'Reg_BOA_Input';  node = Inp 'RegistrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'Hull_BOA_Input'; node = Inp 'BoatHullIdNumber'   'Hull ID Number'      '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4'); fields = @(
                # LABEL-OVERRIDE: RegistrationState -- bare "State" (NJ pattern); initialValue=AZ kept
                @{ id = 'State_BOA_Input';  node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_BOA_2' }
                # LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
                @{ id = 'RelHit_BOA_Input'; node = Inp 'relatedHitSearchIndicator' 'Stolen Check' '1' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_BOA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_BOA_BADGE' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card (v3.2, collapsed from OPTIONS+REGISTRATION+HULL): Reg/Hull, State/Stolen Check, hidden badge. ACQB/ACQBH (Badge) and BQ/BQH (no Badge).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs -- PascalCase USx fields, KeepSsn, registrationState/autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -KeepSsn -PascalCaseUsxFields `
    -Description "Provider configuration for AZ_AZDPS v${Version} -- RMS bundle"

# =====================================================================
# FINAL ASSEMBLY
# =====================================================================
$provBundle = [PSCustomObject]@{
    name           = 'AZ_AZDPS'
    type           = 'BUNDLE'
    description    = "Provider configuration for AZ_AZDPS v${Version}"
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhistQuery, $gunQuery, $artQuery, $boatQuery)
    provider       = 'AZ_AZDPS'
}

$final = [PSCustomObject]@{
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

# =====================================================================
# OUTPUT
# =====================================================================
Write-ProviderJson -BundleObject $final -OutPath $OUT `
    -Label "Built AZ_AZDPS v${Version} (single-JSON consolidation, native PascalCase USx fields, GunQuery serialNumber CAD fix, KeepSsn)" `
    -Version $Version
