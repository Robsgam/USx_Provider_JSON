# build_nj_njcjis.ps1  -- NJ_NJCJIS canonical build (single JSON, multi-card)
# =====================================================================
# v4.12 (2026-07-27, DEX-1284 Person consolidation -- direct Rob feedback, layout-only, NO
#   functional change): collapsed the 3-card Person split (SEARCH OPTIONS + LICENSE NUMBER +
#   NAME SEARCH) into ONE "Driver License Search by OLN, \"OR\" Name" card, matching NY/TX/FL.
#   OLN + State + NCIC Image lead the top row (the Rob-confirmed FL model), then Name (First/Last),
#   then DOB/Sex. The DriverLicense QIDM (FULL=OLN / FULLN=Name combos) is unchanged -- both combos
#   read from this single card now. State keeps initialValue=NJ + its RegistrationState
#   LABEL-OVERRIDE (line ~432). Layout-only, no combo/QIDM/routing/fieldId/default change. Vehicle
#   keeps its own OPTIONS card (only Person was consolidated). ALL 5 ENTITIES RESET for re-test at
#   v4.12 (block by version). NOT yet re-tested.
# v4.11 (2026-07-27, DEX-1284 relabel/naming-convention pass -- direct Rob feedback, NO functional
#   change): applied the portfolio conventions established on NY/TX/FL. OLN (OperatorLicenseNumber
#   DL "License Number (or search by Name + DOB)" -> "OLN"). Canonical bare "NCIC Image" on every
#   image field (Vehicle/Person OPTIONS + Gun/Article/Boat -- was "Image (optional)"). NJ has no DH
#   card and no relatedHitSearchIndicator/stolen toggle (VehicleStolenQuery is a USER-APPROVED skip),
#   so "Stolen Check" does not apply here. Person keeps its existing 3-card structure (SEARCH
#   OPTIONS / LICENSE NUMBER / NAME SEARCH) -- OLN already sits alone on its own full-width card, so
#   no DL top-row restructure was needed (the consolidation-to-one-card question is deferred to Rob).
#   Label-only, no combo/QIDM/routing/fieldId/default change. ALL 5 ENTITIES RESET for re-test at
#   v4.11 (block by version). NOT yet re-tested.
# v4.10 (2026-07-20): Firearm CAD auto-population fix (direct feedback, mirrors NY_NYSPIN_EJUSTICE
#   v4.10 + CA_CLETS v2.9 precedent). CAD sends the gun serial number as the camelCase field
#   'serialNumber', not the PascalCase USx token 'GunSerialNumber' -- so the USx-query button in a
#   CAD event never populated the Firearm form (worked for Person, failed for Firearm). Changed the
#   form fieldId, the GunQuery QIDM sourceField, and the combo set[] from 'GunSerialNumber' to
#   'serialNumber'; the QIDM attribute name + targetField stay 'GunSerialNumber' (the XML element
#   name is unchanged, so the wire request is identical). Firearm re-tests from T1; all other
#   entities unaffected (no functional change -- fingerprints unchanged, stay preserved).
# v4.8 (2026-07-01): Metadata-driven keyRef rename (user audit finding: synthetic keyRefs
#   DQ/DQN/RQ/RQN did not match NJCJIS devdoc at all -- verified against the raw devdoc XML
#   (providers/NJ_NJCJIS/source/NJ_NJCJIS.xml), not just the generated METADATA_REFERENCE.txt).
#   DriverLicenseQuery: devdoc keyReference is FULL for BOTH combos (Name+DOB and OLN) --
#   DQ->FULL (real term, Name+DOB combo), DQN->FULLN (synthetic N-suffix per
#   PLATFORM_CONSTRAINTS.txt convention, OLN combo). VehicleRegistrationQuery: devdoc defines
#   FOUR combos -- keyReference RAND and keyReference FULL, each for Plate and VIN -- and
#   RAND's Set/Any fields are IDENTICAL to FULL's for a given identifier (confirmed in the raw
#   XML: same Set fields, same Any fields), so ConnectCIC (routes by field presence only) cannot
#   distinguish them; ONE physical combo per identifier is required, which is why an earlier
#   build already merged them (RandomRequest EQUALS-value conditions that would have
#   discriminated RAND vs FULL are inert on this platform -- QIDM_REFERENCE Sec 2a). RQ->RANDFULL,
#   RQN->RANDFULLN: a compound synthetic label naming BOTH real devdoc terms it serves, instead
#   of an unrelated invented root borrowed from another provider's build-script convention.
#   'RQ'/'RQN'/'DQ'/'DQN' do not exist in NJ's devdoc under any name -- they were carried over
#   from a cross-provider <Entity>Q/<Entity>QN naming habit (confirmed also in HI_HCJDC_OFML's
#   build script, where 'RQ' happens to be HI's own real devdoc term -- it is not NJ's).
#   Version bump invalidates all prior test evidence under the old keyRef names; full re-test
#   required (reset_test_package.ps1 -Force).
# =====================================================================
# v4.7 (2026-06-26): VehicleMakeName code-source correction (RND-62365). v4.5's
#   codeTypeCategory='VehicleType'/codeTypeSource='VEHICLE' was WRONG: the CODETYPE_TEST probe
#   proved that table is ABSENT on the Newark instance (empty), which broke v4.6 vehicle result
#   mapping ("Mock results processed"). Corrected in tools/_build_rms_bundle.ps1 Build-CommsysQrdm
#   to attributeType='VEHICLE_MAKE'/codeTypeSource='NCIC' (probe-confirmed present VM04; matches
#   RND-54190 runbook + sibling VehicleModelName). Shared-module change but ONLY NJ rebuilt this
#   pass (others tabled). Re-opens Vehicle response mapping; full re-test + re-import required.
#   Detail: providers/NJ_NJCJIS/RND-62365/CATALOG_RND-62365.md.
# =====================================================================
# v4.5 (2026-06-24): VehicleMakeName QRDM fix (shared module). VehicleMakeName resolved against
#   the wrong code table -- codeTypeCategory=NCIC_FIREARM_MAKE/codeTypeSource=NJ_NIBRS (FIREARM
#   makes, AP #24) -- so vehicle make mis-resolved (only the regex fallback saved it). Corrected
#   in tools/_build_rms_bundle.ps1 Build-CommsysQrdm to codeTypeSource='VEHICLE',
#   codeTypeCategory='VehicleType' (vehicle codes live in the VehicleType table under VEHICLE;
#   user-verified vs platform registry 2026-06-24). Shared-module change -> propagates to every
#   provider on its next rebuild. KB: RULE_HANDLERS #16 + CLAUDE.md code-type pairings updated.
#   Re-opens Vehicle response mapping; full re-test + re-import (USx + Newark) required.
# =====================================================================
# v4.4 (2026-06-23): Gap-audit remediation. (1) Boat Hull>Reg guardrail -- added BoatHullIdNumber
#   NOT_EXISTS (PascalCase sourceField) to the QB Reg combo so Hull+Reg co-entry doesn't bleed
#   RegistrationNumber into the Hull XML (verify_build CHECK 12, now FAIL-level). (2) VehReg
#   synthetic-keyRef doc added for CHECK 9 (RQN). Part of the TX/FL/HI/NJ portfolio gap audit
#   (tooling hardened: CHECK 12->FAIL, CHECK 14 gate-xor-companion, conductor exact-match,
#   audit_cad set[]-scan + case-fix, verify_build + audit_cad wired into enforce). Re-opens Boat;
#   re-import to USx test + Newark Foundation required.
# =====================================================================
# CANONICAL MAINLINE BUILD. Produces providers/NJ_NJCJIS/NJ_NJCJIS.json.
# Design (promoted to mainline 2026-06-17, v4.0):
#   1. VehicleStolenQuery (QV) NOT built -- USER-APPROVED SKIP of the 3 metadata
#      QV combos. NJCJIS runs the QV stolen check automatically state-side with
#      registration queries; its response tags are still data-mined via the QRDM.
#      Vehicle layout therefore omits ncicNumber + vehicleMakeCode (stolen-only).
#   2. VehicleRegistrationQuery = 2 combos (RANDFULL plate, RANDFULLN VIN) -- named
#      for BOTH devdoc keyRefs they serve (RAND + FULL are structurally identical
#      per identifier in the raw devdoc XML, so one physical combo covers both;
#      v4.8 renamed from the non-devdoc RQ/RQN). RandomRequest is user-controlled
#      in any[] (form default N); the inert poisoned-array RandomRequest=Y
#      conditions + synthetic RQ_RAND/RQN_RAND combos were removed
#      (behavior-preserving; QIDM_REFERENCE Sec 2a; cf. FL v5.0).
#   3. RMS handler arguments are populated by the fixed _R helper in
#      tools/_build_rms_bundle.ps1 (the $args reserved-name collision that dropped
#      them was repaired 2026-06-17; matches the HIDLE engineering baseline).
#   4. USx CAD-integration field names are authored in PascalCase DIRECTLY (layout
#      fieldIds, QIDM sourceField, combo set[]/any[]) to match Cringer's reference;
#      Mark43/RMS internal keys stay camelCase. RMS form-fed fields recased via
#      Build-RmsBundle -PascalCaseUsxFields. The old Convert-UsxCasing whole-tree
#      post-transform was removed 2026-06-18 (it collapsed Craft.js `nodes` arrays
#      to scalars/null and broke form rendering).
# =====================================================================
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nj_njcjis.ps1

param(
    [string]$Version = "4.12"
)

$ErrorActionPreference = 'Stop'
$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
# Root JSON name carries the version (<PROVIDER>_v<X.Y>.json). Write-ProviderJson
# removes any stale bare/versioned sibling so one-JSON-in-root holds on every bump.
$OUT      = "$DIR\NJ_NJCJIS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }
# phases/ snapshot mechanism retired 2026-07-01 (NJ only, pilot for the new standard) -- every
# version is already fully recoverable from git commit history; phases/ only duplicated that
# while accumulating same-version-rebuild noise (3 separate v3.6 snapshots, 2x v4.1, 2x v4.5).

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: NJ_NJCJIS PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'NJ_NJCJIS'

# QUERYRESULTDATAMAPPING (from KB specs) -- kept intact (QV response tags still
# data-mined if the state auto-runs QV with registration queries)
$results = Build-ProviderQrdm -ProviderName 'NJ_NJCJIS'

$qmf = Build-Qmf -ProviderName 'NJ_NJCJIS'

# =====================================================================
# 1d. VehicleRegistrationQuery
#     autoSelect=true, NO queriesToDeselect.
#     Defaulted fields in any[] per LIMITATION #31.
#     PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
#     v4.8 RENAME (metadata-driven naming audit): the raw devdoc XML
#     (source/NJ_NJCJIS.xml) defines FOUR real combos here -- keyReference 'RAND' and
#     keyReference 'FULL', each for Plate and for VIN -- and RAND's Set/Any fields are
#     IDENTICAL to FULL's for a given identifier, so ConnectCIC (routes by field
#     presence only) cannot tell them apart; ONE physical combo per identifier is
#     required. keyReference 'RANDFULL' (Plate) / 'RANDFULLN' (VIN, N-suffix per
#     PLATFORM_CONSTRAINTS.txt's synthetic-keyRef convention) names BOTH real devdoc
#     terms the merged combo serves. (Formerly 'RQ'/'RQN' -- an unrelated root that
#     does not exist anywhere in NJ's devdoc; see v4.8 changelog header.)
#     RandomRequest is user-controlled (any[], form default N) and routed
#     server-side by its value -- it does NOT need separate combos. The earlier
#     synthetic RQ_RAND/RQN_RAND combos used value-comparison conditions
#     (RandomRequest EQUALS Y) which the platform treats as INERT (poisoned-array,
#     QIDM_REFERENCE Sec 2a): the conditions were disabled, so those combos already
#     fired unconditioned and duplicated RQ/RQN. Removed (behavior-preserving).
#     Cf. FL v5.0 poisoned-array cleanup.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('LicensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RandomRequest';                size = 1;  sourceField = @('RandomRequest');                targetField = 'RandomRequest' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('LicensePlateNumber')
                any      = @('RandomRequest','RegistrationState','LicensePlateTypeCode','ImageIndicator','LicensePlateYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'RandomRequest';        value = 'N' }
                    [PSCustomObject]@{ field = 'ImageIndicator';       value = 'N' }
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                    [PSCustomObject]@{ field = 'State';                value = 'NJ' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RANDFULL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('VehicleIdentificationNumber')
                any      = @('RandomRequest','RegistrationState','ImageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'RandomRequest';  value = 'N' }
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                    [PSCustomObject]@{ field = 'State';          value = 'NJ' }
                )
                conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RANDFULLN'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- 2 combos: RANDFULL (plate), RANDFULLN (VIN) -- each merges devdoc keyRefs RAND+FULL (identical Set/Any per identifier, platform cannot discriminate). RandomRequest user-controlled in any[] (form default N), default N in defaults[] for CAD. Poisoned-array RandomRequest=Y conditions removed (inert; QIDM_REFERENCE Sec 2a) and synthetic RQ_RAND/RQN_RAND combos collapsed -- behavior-preserving since conditions were already disabled.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'NJ_NJCJIS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'NJ_NJCJIS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. VehicleStolenQuery -- BRANCH DELTA: REMOVED ENTIRELY.
#     QVN/QVP/QVV (metadata keyRef 'QV', 3 combos) are a USER-APPROVED SKIP in
#     this variant (2026-06-10): premise is the state runs QV automatically
#     with registration queries. No JSON-side stolen query, no Stolen checkbox.
# =====================================================================

# =====================================================================
# 1f. DriverLicenseQuery
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# v4.8 RENAME (metadata-driven naming audit): the raw devdoc XML (source/NJ_NJCJIS.xml)
# uses keyReference 'FULL' for BOTH combos (Name+DOB and OLN) -- confirmed directly in the
# XML, not just the generated METADATA_REFERENCE.txt. keyReference 'FULL' (real devdoc
# term, Name+DOB combo) / 'FULLN' (synthetic N-suffix per PLATFORM_CONSTRAINTS.txt's
# convention, OLN combo). (Formerly 'DQ'/'DQN' -- an unrelated root that does not exist
# anywhere in NJ's devdoc; see v4.8 changelog header.)
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size        = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('BirthDate','NameLast','NameFirst')
                any      = @('ImageIndicator','SexCode','RegistrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                    [PSCustomObject]@{ field = 'State';          value = 'NJ' }
                )
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'FULL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('OperatorLicenseNumber')
                any      = @('ImageIndicator','RegistrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                    [PSCustomObject]@{ field = 'State';          value = 'NJ' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'FULLN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- FULL (Name+DOB), FULLN (OLN) -- devdoc keyRef is FULL for both combos; FULLN is the synthetic N-suffix disambiguation. OLN>Name guardrail: FULL has OperatorLicenseNumber NOT_EXISTS so OLN wins when both entered (identifier-priority guardrail).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery -- UNCHANGED from mainline
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('GunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('GunMake');          targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';        size = 20; sourceField = @('GunModel');         targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 11; sourceField = @('serialNumber');     targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';  size = 1;  sourceField = @('ImageIndicator');   targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('serialNumber')
                any      = @('GunCaliber','GunMake','GunModel','ImageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. Adds GunModel + ImageIndicator in v2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- UNCHANGED from mainline
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';      size = 1;  sourceField = @('ImageIndicator');      targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('ArticleSerialNumber','ArticleTypeCode')
                any      = @('ImageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA. Adds ImageIndicator in v2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- UNCHANGED from mainline
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QB' for both combos (Reg# and Hull ID); synthetic label 'QBN'
# (N=Hull path) invented for platform routing only. NOT a real NJCJIS transaction code.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('ImageIndicator');      targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 20; sourceField = @('RegistrationNumber');  targetField = 'RegistrationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('RegistrationNumber')
                any      = @('ImageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
                # Hull>Reg guardrail: Hull ID (HIN) is the unique permanent identifier; Reg# is
                # reassignable. When a Hull is entered this Reg combo exits the union pool so Reg#
                # doesn't bleed into the Hull XML (LIMITATION #1). conditions[].field = sourceField.
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('BoatHullIdNumber')
                any      = @('ImageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBN'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- QB (Reg), QBN (Hull). State removed in v2. RegNum maxLength 20.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# BRANCH DELTA: $vehStolenQuery omitted from configurations
$njBundle = [PSCustomObject]@{
    description    = "Provider configuration for NJ_NJCJIS v${Version}"
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (multi-card layouts)
# BRANCH DELTA -- Vehicle: 3 cards, VIN card = VIN only (ncicNumber and
# vehicleMakeCode removed -- both served ONLY the deleted stolen query)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards: OPTIONS, PLATE SEARCH, VIN SEARCH
# OPTIONS: State+Random+Image (shared routing fields for all combos)
# PLATE SEARCH: Plate+PlateType+PlateYear
# VIN SEARCH: VIN only (BRANCH DELTA)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_VEH_O1'; cols = @('4','4','4'); fields = @(
                # LABEL-OVERRIDE: RegistrationState -- Rob's explicit cosmetic call (NJ v4.9); bare
                # "State" per the FL/TX precedent. State is a defaulted any[] field (initialValue=NJ,
                # officer-editable for out-of-state), NOT an in-state/OOS routing toggle, so no routing
                # hint is load-bearing. Same fieldId covers the Person card's State too.
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_VEH_O1' }
                @{ id = 'RandomRequest_Input';     node = Sel 'RandomRequest' 'Random Request (N = full record; Y = random)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_O1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_P1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';  node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_P1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (optional)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_P1' }
                @{ id = 'LicensePlateYear_Input';    node = Inp 'LicensePlateYear' 'Plate Year (optional)' '4' 'ROW_VEH_P1' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_V1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_V1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- RANDOM-REMOVED branch: OPTIONS + PLATE + VIN cards. VehicleStolenQuery eliminated; ncicNumber/vehicleMakeCode removed (stolen-only fields).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- CONSOLIDATED (v4.12): the 3-card split (OPTIONS + LICENSE NUMBER +
# NAME SEARCH) collapsed to ONE "Driver License" card, matching NY/TX/FL. OLN +
# State + NCIC Image lead the top row (Rob-confirmed FL model), then Name, then
# DOB/Sex. QIDM unchanged -- DriverLicense's FULL (OLN) + FULLN (Name) combos both
# read from this single card. State keeps initialValue=NJ + its LABEL-OVERRIDE.
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'Driver License Search by OLN, "OR" Name'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_PER_1' }
                @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (required with Name)'                             'ROW_PER_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex (optional)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 1 card (v4.12, consolidated from OPTIONS+LICENSE NUMBER+NAME SEARCH): OLN+State+Image top row, Name, DOB/Sex.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- UNCHANGED: 1 card
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake'         'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunCaliber_Input';      node = Sel 'GunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_2' }
                @{ id = 'GunModel_Input';        node = Inp 'GunModel'   'Model (optional)'   '20' 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';  node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG. Adds GunModel + ImageIndicator in v2.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- UNCHANGED: 1 card
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type (required)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA. Serial+Type+Image on one row.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- UNCHANGED: 1 card
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('5','5','2'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '20' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'ImageIndicator_Input';     node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- QB (Reg) and QBN (Hull). Reg+Hull+Image on one row.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm) `
        -Description "Provider configuration for NJ_NJCJIS v${Version} -- entity forms"

# =====================================================================
# BUNDLE 3: RMS (from KB specs — PascalCase USx fields, registrationState, autoSelect)
# RMS Vehicle uses LicensePlateNumber/VIN/RegistrationState only. The
# -PascalCaseUsxFields switch recases the form-fed sourceField/set/any to match
# the PascalCase form fieldIds (Mark43 internal targetFields stay camelCase).
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields `
        -Description "Provider configuration for NJ_NJCJIS v${Version} -- RMS bundle"
# =====================================================================
# WRITE OUTPUT
# =====================================================================
# NOTE: The 22 USx CAD-integration field names (the ones CAD/OnScene populate)
# are authored in PascalCase DIRECTLY above -- in the layout Inp/Sel/Dt calls,
# the QIDM sourceField arrays, and the combo set[]/any[] lists -- matching
# Cringer's reference JSON. Mark43/RMS internal keys (firstName, vinNumber,
# dlNumber, ...) stay camelCase. There is NO post-build recase pass: the prior
# Convert-UsxCasing whole-tree transform was removed (2026-06-18) because it
# enumerated the Craft.js layout `nodes` lists and collapsed single-child lists
# to a bare string and empty lists to null, which broke form rendering.
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $njBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built NJ_NJCJIS v${Version} (VehStolenRemoved mainline, native PascalCase USx fields, restored RMS args)" `
    -Version $Version

Write-Host ""
Write-Host "Build complete -- NJ_NJCJIS v${Version}: VehStolenRemoved + PascalCase USx fields + restored RMS handler args."
