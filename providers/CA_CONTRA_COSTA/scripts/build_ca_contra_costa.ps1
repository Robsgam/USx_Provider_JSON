# build_ca_contra_costa.ps1  -- CA_CONTRA_COSTA (SPECIAL CASE: CA_CLETS copy + CC JAWS)
# Cloned from build_ca_clets.ps1. Builds the 6 CA_CLETS basic-supported families as CC's framework.
# CC's own JAWS transactions + CLETSPersonSuperQuery live in the merged metadata (source/CA_CONTRA_COSTA.xml
# = CA_CLETS.xml + CC JAWS) but are NOT built here (CC "Expanded", not "Basic" -- backfill if devdoc changes).
# CC's original 2-transaction metadata preserved as source/CA_CONTRA_COSTA_JAWS_ONLY.xml.
# NOTE: Article codeTypeSource='CA_CLETS' below is a PLATFORM code-type source, NOT the provider id -- do not rename.
# v2.15 (2026-07-21): metadata correctness fix, found by live testing. DriverLicenseQuery IR.QVC.N
#   combo sent APPSRequestIndicator on the wire (default 'N') -- audit_log_metadata.ps1 FAILed 9/9
#   IR.QVC.N test logs ("wire field(s) not defined in metadata"). Checked the real metadata XML
#   (DriverLicenseQuery v36, keyRef IR.QVC, primaryFieldReference=Name): its field list is
#   CaRequestPurposeCode/Age/BirthDate/CriminalIdNumber/Name/OperatorLicenseNumber/RaceCode/
#   SexCode/SocialSecurityNumber/State/AddressCounty/Height -- NO APPSRequestIndicator anywhere in
#   the XML. It was a devdoc-inspired invention (v2.6-era comment: "triggers APPS prohibited-person
#   check") that violated the field-authority rule (metadata is field-authority, devdoc is
#   query-authority) and was never metadata-verified until this live-test pass caught it. Removed
#   entirely: attribute, combo any[]/defaults, form field, form row (rebalanced 5-field row to 4).
#   This is a functional wire change (IR.QVC.N no longer sends APPSRequestIndicator) -- all 5
#   entities reopened for full re-test.
# v2.14 (2026-07-21): cosmetic layout + helper pass (NO functional change). Vehicle collapsed from
#   2 cards (Search Options + Vehicle Search) to 1 -- Plate/Type/Year stays row 1, State+Purpose
#   moves onto row 2, VIN/Make/Year and Name/City/StreetNumber shift down to rows 3-4. Added
#   '(optional)' helpers to genuinely-optional any[]-only fields that had none: Vehicle Make/Year,
#   City/Street Number ('with Name, optional'; only relevant to the IN.VP name path); DL Date of
#   Birth/Age/Height/County/Race; Article Type/Brand/Category (Article previously had zero helpers).
#   DL Sex stays bare -- it's set[]-required for the IR.QVC.N criminal-name combo (not purely
#   optional), same reasoning as the TX_TLETS precedent for dual-role fields. DH card unchanged --
#   Name/DOB/Sex are a required trio for NLTS.KQ.N, not optional. Boat unchanged (already has
#   helpers). Label/layout-only, no combo/QIDM/routing change. All 5 entities reopened for retest.
# v2.13 (2026-07-20): cosmetic label cleanup pass (NO functional change). Stripped cross-reference
#   helpers from all entities: Vehicle Plate Number/VIN/Name bare, VIN spelled out "Vehicle
#   Identification Number"; Person DL License Number/CII/SSN/Sex/APPS bare, DH labels dropped
#   "(DH)" qualifier per portfolio convention; Firearm Serial/Name bare, Purpose Code moved onto
#   Name row; Article Serial/OAN bare; Boat Hull/Reg/OAN bare, Name "(out-of-state only)" kept
#   as minimal hint. Label-only, no combo/QIDM/routing change. All 5 entities reopened for retest.
# v2.12 (2026-07-01): RESTORED in-state DriverLicenseQuery combos ID.L1 (OLN) + IN.L1 (name),
#   DL 6 -> 8 combos. v2.11 removed them expecting "CommSys auto-dispatches, consistent with
#   Vehicle pattern" -- but Vehicle keeps an unconditioned in-state catchall (IA.QV/IA.QVK) and
#   DL kept none, so a plain in-state driver lookup (OLN-only or name-only, no State) fired
#   nothing (NLTS gated State EXISTS; IR.QVC needs CII/SSN/Sex). ID.L1/IN.L1 are REAL devdoc
#   keyRefs, restored as gated catchalls; IR.QVC.O gets CriminalIdNumber EXISTS and IR.QVC.N
#   gets RegistrationState NOT_EXISTS + SexCode EXISTS so all 8 combos are mutually exclusive
#   and reachable (verify_build CHECK 16). Full re-test from T1.
# v2.11 (2026-06-29): RegistrationState EXISTS condition added to all 6 NLTS combos
#   (NLTS.DQ, NLTS.DQ.N, NLTS.RQ.V, NLTS.BQ.N, NLTS.BQ.H, NLTS.BQ.R). Platform fires
#   combos on primaryFieldReference presence -- NOT on all-set[] presence. Without this
#   condition, NLTS combos shadowed in-state equivalents (ID.L1, IN.L1, IA.QVK, IA.QB.R)
#   when State was left blank. Caught by new verify_build CHECK 16 (combo reachability).
# v2.10 (2026-06-26): VehicleMakeName code-source correction (RND-62365, shared module
#   tools/_build_rms_bundle.ps1): VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC
#   (probe-confirmed present; matches RND-54190 runbook + sibling VehicleModelName). Result-mapping
#   only; request-side combos unchanged. Full re-test from T1 per rebuild mandate.
# Builds CA_CONTRA_COSTA_v<X.Y>.json from the derived merged metadata + KB specs.
# QIDMs expanded to cover ALL 40 metadata combos (40 built, 0 LIMITATION).
# Layout: Vehicle(2), Person(3), Firearm(1), Article(1), Boat(1) -- 8 cards total
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 QIDMs, 40 combos):
#   VehicleRegistrationQuery   NLTS.RQ(P/V) + IN.VP + IV.4V + IA.QVK + IA.QV = 6 combos
#     v2.5: deleted 13 IV.4* plate-type combos (server routes by LicensePlateTypeCode value;
#     wire = MessageType=VehicleRegistrationQuery, keyRef internal) + removed inert State NOT_EQUALS.
#     v2.6: PascalCase USx fieldIds, identifier-priority guardrails (Plate>VIN, OLN>Name, Hull>Reg),
#           CAD defaults on all combos (CAD ignores form initialValue; combo defaults[] required).
#   DriverLicenseQuery         NLTS.DQ(N/O) + IR.QVC(OLN/Name/CriminalId/SSN) + ID.L1 + IN.L1 = 8 combos
#     v2.12: restored in-state ID.L1 (OLN) + IN.L1 (name) catchalls (DL had no in-state backstop
#     unlike Vehicle IA.QV); real devdoc keyRefs, gated NOT_EXISTS for mutual exclusion.
#   DriverHistoryQuery         NLTS.KQ(N/O) = 2 combos, DH-suffix fields
#   GunQuery                   IG.QGH (name) + IG.QGB (serial) = 2 combos
#   ArticleSingleQuery         IP.QA(S/O) = 2 combos
#   BoatQuery                  NLTS.BQ(N/H/R) + IA.QB(H/O/R) + IV.4B = 7 combos
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_ca_clets.ps1 -Version 2.6

param(
    [string]$Version = "2.0"
)

$ErrorActionPreference = "Stop"
$provider = 'CA_CONTRA_COSTA'
$currentYear = [string](Get-Date).Year
$outPath  = "$PSScriptRoot\..\CA_CONTRA_COSTA_v${Version}.json"
$DATE     = (Get-Date -Format 'yyyy-MM-dd')

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# LABEL-OVERRIDE: gunCaliber -- v2.13 cosmetic pass, any[]-only optional field, Rob-directed bare label
# LABEL-OVERRIDE: GunMake -- v2.13 cosmetic pass, any[]-only optional field, Rob-directed bare label
# LABEL-OVERRIDE: gunTypeCode -- v2.13 cosmetic pass, any[]-only optional field, Rob-directed bare label
# LABEL-OVERRIDE: SexCode -- v2.14 cosmetic pass, set[]-required on IR.QVC.N (not purely optional), bare label kept (TX_TLETS precedent)

# =====================================================================
# BUNDLE 1: CA_CLETS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_CONTRA_COSTA'

$results = Build-ProviderQrdm -ProviderName 'CA_CONTRA_COSTA'

$qmf = Build-Qmf -ProviderName 'CA_CONTRA_COSTA'

# --- 1. VehicleRegistrationQuery -- 6 combos (v2.5: IV.4* server-routed by plate type) ---
# NLTS.RQ (OOS plate/VIN) + IV.4* (13 plate-type-routed) + IV.4A (PC/AQ fallback)
# + IN.VP (name) + IV.4V (VIN) + IA.QVK (VIN+make) + IA.QV (plate catchall)
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'NLTS.RQ' for OOS plate and VIN; dot-suffixes .P (plate) and .V (VIN)
# are synthetic. IV.4* are real CLETS transaction codes (no suffix needed).
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCity';                  size = 13; sourceField = @('addressCity');                  targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'AddressStreetNumber';          size = 3;  sourceField = @('addressStreetNumber');          targetField = 'AddressStreetNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';        size = 1;  sourceField = @('purposeCode');                  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';           size = 10; sourceField = @('LicensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 35; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 30; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # --- OOS combos (most specific: State required + NOT CA condition) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState')
                any      = @('VehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode';          value = 'C' }
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode';  value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';      value = $currentYear }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'NLTS.RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','VehicleIdentificationNumber','RegistrationState')
                any        = @('VehicleMakeCode','vehicleYear')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'NLTS.RQ.V'
            state                 = 'In/Out'
        }
        # --- Plate + type (in-state): handled by the IA.QV catchall below. ---
        # v2.5 POISONED-ARRAY cleanup: the 12 IV.4* plate-type combos (IV.4I/C/M/L/T/F/S/E,
        # IL.A1, IV.4H/P/K) + IV.4A were DELETED. They shared one field signature
        # [purposeCode, licensePlateNumber, licensePlateTypeCode] and differed only by
        # LicensePlateTypeCode VALUE -- which the CommSys SERVER reads to pick the IV.4* message
        # key. The wire carries MessageType=VehicleRegistrationQuery + fields (keyReference is
        # internal, never sent -- confirmed by 12 live VehReg logs), so all 13 produced an
        # identical wire message and their EQUALS conditions were inert (poisoned-array).
        # IA.QV already sends licensePlateNumber + licensePlateTypeCode (any[]) -> server routes.
        # --- IN.VP name search (cross-entity) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','NameLast','NameFirst')
                any      = @('addressCity','addressStreetNumber')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.VP'
            state                 = 'In/Out'
        }
        # (IV.4A PC/AQ combo DELETED v2.5 -- redundant with IA.QV; same plate+optional-type signature.)
        # (IV.4V VIN combo DELETED v2.5 -- identical required set to IA.QVK; server routes; wire=VehicleRegistrationQuery+VIN.)
        # --- IA.QVK VIN + optional make/state (Plate>VIN guardrail) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','VehicleIdentificationNumber')
                any        = @('VehicleMakeCode','RegistrationState')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'IA.QVK'
            state                 = 'In/Out'
        }
        # --- IA.QV plate catchall (no conditions, fires for any plate type not matched above) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','LicensePlateNumber')
                any      = @('RegistrationState','LicensePlateTypeCode','LicensePlateYear','VehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode';          value = 'C' }
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode';  value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';      value = $currentYear }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IA.QV'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- 6 combos: NLTS.RQ.P/V (OOS), IN.VP (name), IV.4V/IA.QVK (VIN), IA.QV (plate+optional type; server routes IV.4* by plate-type value). v2.5: 13 IV.4* combos deleted (redundant; server-side value routing), inert State conditions removed. v2.6: PascalCase fieldIds, Plate>VIN guardrail on NLTS.RQ.V+IA.QVK, CAD defaults on all combos.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = "${provider}_VehicleRegistrationQuery"
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = $provider
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# --- 2. DriverLicenseQuery -- 8 combos ---
# NLTS.DQ(N/O) = OOS name/OLN, IR.QVC(OLN/CriminalId/SSN/Name) = criminal records search,
# ID.L1/IN.L1 = pure in-state OLN/name lookups.
# v2.12 RESTORE: ID.L1 (OLN) + IN.L1 (name) were removed v2.11 on the theory "CommSys
# auto-dispatches pure (In) queries, consistent with Vehicle pattern" -- but the Vehicle
# analogy did NOT hold for DL. Vehicle keeps an unconditioned in-state catchall (IA.QV/IA.QVK)
# so plate/VIN-only-no-State still fires and the server routes in-state; DL kept NO OLN-only /
# name-only catchall, so after v2.11 a plain in-state driver lookup (local driver, no State
# entered -- the common case) fired nothing (NLTS gated State EXISTS, IR.QVC needs CII/SSN/Sex).
# ID.L1/IN.L1 are REAL devdoc keyReferences (not synthetic), restored as the last (catchall)
# combos, gated NOT_EXISTS so the OOS + criminal paths win when their discriminators are present.
# Firing cascade (OLN): OLN+State->NLTS.DQ; OLN+CII(noState)->IR.QVC.O; OLN-only->ID.L1.
# Firing cascade (Name): Name+State->NLTS.DQ.N; Name+Sex(noState)->IR.QVC.N; Name-only->IN.L1.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'NLTS.DQ' for OOS combos (synthetic: NLTS.DQ.N=name, NLTS.DQ=OLN)
# and 'IR.QVC' for criminal records combos (synthetic: IR.QVC.O/.N/.C/.S per field path).
# ID.L1 + IN.L1 are the metadata's own keyRefs (real CLETS transaction codes, no suffix).
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCounty';        size = 3;  sourceField = @('addressCounty');        targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'Age';                   size = 2;  sourceField = @('age');                   targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCode');           targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'CriminalIdNumber';      size = 11; sourceField = @('criminalIdNumber');      targetField = 'CriminalIdNumber' }
        [PSCustomObject]@{ name = 'Height';                size = 3;  sourceField = @('height');                targetField = 'Height' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';              size = 1;  sourceField = @('raceCode');              targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';  size = 9;  sourceField = @('socialSecurityNumber');  targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # --- NLTS.DQ.N: OOS name search (most specific — name + state required + OLN>Name guardrail) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','NameLast','NameFirst','RegistrationState')
                any        = @('BirthDate')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.DQ.N'
            state                 = 'In/Out'
        }
        # --- NLTS.DQ: OOS OLN search ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','OperatorLicenseNumber','RegistrationState')
                any        = @()
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.DQ'
            state                 = 'In/Out'
        }
        # --- IR.QVC.Name: criminal/demographic name search. Metadata field-verified 2026-07-21
        #     (DriverLicenseQuery v36, keyRef IR.QVC, primaryFieldReference=Name): set=[Name,SexCode]
        #     any=[BirthDate,Age,AddressCounty,Height,RaceCode]. APPSRequestIndicator REMOVED v2.15 --
        #     it was never a metadata field for this transaction (any transaction in the XML); the
        #     devdoc-inspired comment that introduced it violated the field-authority rule (metadata
        #     is field-authority, devdoc is query-authority) and was only caught by live testing
        #     (audit_log_metadata.ps1 FAIL, 9/9 IR.QVC.N logs, 2026-07-21).
        #     (keyRef IR.QVC = server-routed Supervised Release Super Inquiry; basic per devdoc DL.) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','NameLast','NameFirst','SexCode')
                any        = @('BirthDate','age','addressCounty','height','raceCode')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode';           value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    # v2.12: State NOT_EXISTS (State-present name search routes OOS NLTS.DQ.N) +
                    # SexCode EXISTS (name-without-Sex routes in-state IN.L1). Keeps IR.QVC.N,
                    # NLTS.DQ.N, and IN.L1 mutually exclusive on the Name path.
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('SexCode');           operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC.N'
            state                 = 'In/Out'
        }
        # --- IR.QVC.OLN: Criminal records by OLN + CII. NLTS.DQ fires first when State present
        #     (RegistrationState EXISTS condition); IR.QVC.O fires OLN+CII when no State. ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','OperatorLicenseNumber','criminalIdNumber')
                any        = @('socialSecurityNumber','age')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                    # v2.12: criminalIdNumber EXISTS -- OLN-without-CII routes in-state ID.L1;
                    # OLN+CII fires this criminal super-inquiry. Keeps IR.QVC.O and ID.L1
                    # mutually exclusive on the OLN path (both State NOT_EXISTS).
                    [PSCustomObject]@{ field = @('criminalIdNumber');  operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'IR.QVC.O'
            state                 = 'In/Out'
        }
        # --- IR.QVC.CriminalId: Criminal records by CII only. Blocked when OLN present.
        #     OperatorLicenseNumber removed from any[] -- NOT_EXISTS XOR guard; SSN/Age stay. ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','criminalIdNumber')
                any        = @('socialSecurityNumber','age')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'CriminalIdNumber'
            keyReference          = 'IR.QVC.C'
            state                 = 'In/Out'
        }
        # --- IR.QVC.SSN: Criminal records by SSN only. Blocked when OLN present.
        #     OperatorLicenseNumber removed from any[] -- NOT_EXISTS XOR guard; CII/Age stay. ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','socialSecurityNumber')
                any        = @('criminalIdNumber','age')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'IR.QVC.S'
            state                 = 'In/Out'
        }
        # --- ID.L1: pure in-state OLN lookup (catchall). Real devdoc keyRef. Fires when OLN
        #     present with no State (OOS NLTS.DQ needs State EXISTS) and no CII (IR.QVC.O needs
        #     CriminalIdNumber EXISTS) -- i.e. the plain "look up a local driver by OLN" case.
        #     v2.12 restore: closed the in-state backstop gap left by v2.11's removal. ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','OperatorLicenseNumber')
                any        = @()
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('criminalIdNumber');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.L1'
            state                 = 'In/Out'
        }
        # --- IN.L1: pure in-state name lookup (catchall). Real devdoc keyRef. Fires when Name
        #     present with no OLN (OLN>Name priority), no State (OOS NLTS.DQ.N needs State EXISTS)
        #     and no SexCode (IR.QVC.N needs SexCode EXISTS) -- the plain "look up a local driver
        #     by name" case. v2.12 restore. ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','NameLast','NameFirst')
                any        = @('BirthDate')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('SexCode');               operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.L1'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- 8 combos: NLTS.DQ.N/NLTS.DQ (OOS name/OLN), IR.QVC.N/IR.QVC.O/IR.QVC.C/IR.QVC.S (criminal records by name/OLN+CII/CII/SSN), ID.L1/IN.L1 (in-state OLN/name). v2.12: restored in-state ID.L1/IN.L1 (real devdoc keyRefs) as catchalls -- v2.11 removal left DL with no OLN-only/name-only backstop (unlike Vehicle IA.QV). OLN cascade: OLN+State->NLTS.DQ, OLN+CII->IR.QVC.O, OLN-only->ID.L1. Name cascade: Name+State->NLTS.DQ.N, Name+Sex->IR.QVC.N, Name-only->IN.L1. CII->IR.QVC.C, SSN->IR.QVC.S.'
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

# DriverHistoryQuery -- PascalCase + DH-suffix fieldIds (AP #14 / LIMITATION #24-25)
# PurposeCode: DH attr maps from purposeCodeDH (DH-suffix form field)
# DIVERGENCE: purposeCodeDH is in set[] (metadata has it in any[]/defaulted). Recorded in
# CA_CLETS_ACCEPTED_DIVERGENCES.txt -- DH purpose is required to form a valid KQ query.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'NLTS.KQ' for both combos; synthetic labels NLTS.KQ.N (name path)
# and NLTS.KQ.O (OLN path) differentiate routing. NOT real CA CLETS transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCodeDH'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{
            name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCodeDH','BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH')
                any        = @('RegistrationState','Attention')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCodeDH'; value = 'C' }
                    [PSCustomObject]@{ field = 'Attention';      value = 'X' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.KQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCodeDH','OperatorLicenseNumberDH')
                any      = @('RegistrationState','Attention')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCodeDH'; value = 'C' }
                    [PSCustomObject]@{ field = 'Attention';      value = 'X' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.KQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- NLTS.KQ (Name+DOB+Sex), NLTS.KQ (OLN). DH-suffix fields. All via Nlets. v2.9: Attention auto-populate (CommsysGetLastNameFirstNameInitialRuleHandler, size 30, gate-feeder on DH card).'
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

# GunQuery -- PascalCase + cross-entity (Name for IG.QGH combo)
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# keyRefs IG.QGH and IG.QGB are real CLETS transaction codes (not synthetic). No suffix needed.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Age'; size = 2; sourceField = @('age'); targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('GunMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
    )
    combinations = @(
        # IG.QGH: owner name search. Devdoc combos 2+3 add Age or BirthDate optionally.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','NameLast','NameFirst')
                any      = @('BirthDate','age')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IG.QGH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','serialNumber')
                any      = @('gunCaliber','GunMake','gunTypeCode')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'IG.QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- IG.QGH (name) + IG.QGB (serial). Most-specific first. MC cross-entity. v2.9: serialNumber fieldId (was GunSerialNumber) enables CAD-triggered IG.QGB; GunSerialNumber targetField (XML element) unchanged.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_GunQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# ArticleSingleQuery -- PascalCase
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'IP.QA' for both combos; synthetic labels IP.QA.S (serial) and
# IP.QA.O (owner-applied) differentiate routing. NOT real CA CLETS transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('purposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','ArticleSerialNumber')
                any      = @('articleBrand','ArticleTypeCode','articleCategory')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'IP.QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','ownerAppliedNumber')
                any      = @('articleBrand','ArticleTypeCode','articleCategory')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IP.QA.O'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- IP.QA (serial, OAN). CA property inquiry. v2.6: PascalCase fieldIds (ArticleSerialNumber, ArticleTypeCode), CAD defaults on all combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_ArticleSingleQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# BoatQuery -- PascalCase + cross-entity (Name+DOB for NLTS.BQ Name combo)
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'NLTS.BQ' and 'IA.QB' for multiple combos each; dot-suffixes
# (.N/.H/.R) are synthetic routing labels. NOT real CA CLETS transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('BoatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('purposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('RegistrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # --- NLTS.BQ OOS combos ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','NameLast','NameFirst','BirthDate','RegistrationState')
                any        = @()
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.BQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','BoatHullIdNumber','RegistrationState')
                any        = @()
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'NLTS.BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','RegistrationNumber','RegistrationState')
                any        = @()
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'NLTS.BQ.R'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','BoatHullIdNumber')
                any      = @('RegistrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'IA.QB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','ownerAppliedNumber')
                any      = @('RegistrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IA.QB.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','RegistrationNumber')
                any        = @('RegistrationState')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'IA.QB.R'
            state                 = 'In/Out'
        }
        # (IV.4B boat-reg combo DELETED v2.5 -- identical required set to IA.QB.R; server routes; wire=BoatQuery+regNumber.)
    )
    description     = 'BoatQuery -- 7 combos: NLTS.BQ OOS (name, hull, reg) + IA.QB (hull, OAN, reg) + IV.4B (covered by IA.QB.R). MC cross-entity. v2.6: PascalCase fieldIds, Hull>Reg guardrail on NLTS.BQ.R+IA.QB.R, CAD defaults on all combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_BoatQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for ${provider} v${Version} MC -- 6 QIDMs, 40 combos, 100% metadata coverage"
    name           = $provider
    type           = 'BUNDLE'
    provider       = $provider
}

# =====================================================================
# BUNDLE 2: ENTITIES (5 QIFs, collapsed card layouts)
#
# Vehicle:  1 card  (VEHICLE SEARCH -- State + Purpose merged in, v2.14 collapse)
# Person:   3 cards (OPTIONS + DRIVER LICENSE SEARCH + DRIVER HISTORY SEARCH)
# Firearm:  1 card  (FIREARM SEARCH -- Purpose merged in)
# Article:  1 card  (ARTICLE SEARCH -- Purpose merged in)
# Boat:     1 card  (BOAT SEARCH -- State + Purpose merged in)
#
# Person's shared OPTIONS card: RegistrationState + CaRequestPurposeCode live on a
# separate card because DL and DH are two distinct cards sharing the same fieldId
# (avoids duplicate fieldId across cards = ISE). Vehicle/Firearm/Article/Boat have
# only one search card each, so State/Purpose fold directly into it. NCIC state
# pattern: visible RegistrationState, NO initialValue (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card (v2.14 collapse: Search Options folded into Vehicle Search, matching
# Firearm/Article/Boat's single-card pattern). Plate/Type/Year stays row 1; State+Purpose
# moves to row 2; VIN/Make/Year and Name/City/StreetNumber shift down to rows 3-4.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_SEARCH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_2' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_VEH_2' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '30' 'ROW_VEH_3' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year (optional)' '4' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_VEH_4' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_VEH_4' }
                @{ id = 'AddressCity_Input';         node = Inp 'addressCity'         'City (with Name, optional)'          '13' 'ROW_VEH_4' }
                @{ id = 'AddressStreetNumber_Input'; node = Inp 'addressStreetNumber' 'Street Number (with Name, optional)' '3'  'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- v2.14 collapsed to 1 card (State+Purpose folded onto row 2, was a separate Options card): Plate/Type/Year, State/Purpose, VIN/Make/Year, Name/City/StreetNumber.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC collapsed)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by DL combos)
# DRIVER LICENSE SEARCH: OLN + CII + SSN + Name + DOB + Sex + Age + Height + County + Race
# DRIVER HISTORY SEARCH: OLN_DH + PurposeCode_DH + Name_DH + DOB_DH + Sex_DH
# DH-suffix fieldIds isolate DH from DL field pool (AP #14 / LIMITATION #24-25)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_PER_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_DL_1' }
                @{ id = 'CriminalIdNumber_Input';     node = Inp 'criminalIdNumber'     'CII' '11' 'ROW_PER_DL_1' }
                @{ id = 'SocialSecurityNumber_Input';  node = Inp 'socialSecurityNumber'  'SSN' '9'  'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (optional)'                                    'ROW_PER_DL_2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'Age_Input';            node = Inp 'age'            'Age (optional)'    '2' 'ROW_PER_DL_3' }
                @{ id = 'Height_Input';         node = Inp 'height'         'Height (optional)' '3' 'ROW_PER_DL_3' }
                @{ id = 'AddressCounty_Input';  node = Inp 'addressCounty'  'County (optional)' '3' 'ROW_PER_DL_3' }
                @{ id = 'RaceCode_Input'; node = Sel 'raceCode' 'Race (optional)' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('6','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number' '20' 'ROW_PER_DH_1' }
                @{ id = 'PurposeCodeDH_Input';  node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DH_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name' '30' 'ROW_PER_DH_2' }
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name'  '30' 'ROW_PER_DH_2' }
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth'                                   'ROW_PER_DH_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_2' }
            )}
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); fields = @(
                @{ id = 'Attention_Input'; node = InpH 'Attention' 'Attention (auto-populated from officer profile)' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'X' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC collapsed: OPTIONS + DL SEARCH (OLN/CII/SSN/Name/DOB/Sex/Age/Height/County/Race) + DH SEARCH (DH-suffix fields).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (MC collapsed, OPTIONS merged into search)
# FIREARM SEARCH: Serial + Make + Caliber + Type + Name (cross-entity IG.QGH) + Purpose
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN_SEARCH'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';  node = Sel 'GunMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('3','3','2','2','2'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_GUN_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_GUN_2' }
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'               'ROW_GUN_2' }
                @{ id = 'Age_Input';       node = Inp 'age'       'Age' '2'                     'ROW_GUN_2' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_GUN_2' @{ initialValue = 'C' } }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC collapsed: OPTIONS (Purpose) + SEARCH (Serial/Make/Caliber/Type/Name). v2.9: serialNumber fieldId (was GunSerialNumber) enables CAD-triggered IG.QGB.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (MC collapsed, OPTIONS merged into search)
# ARTICLE SEARCH: Serial + OAN + PurposeCode + ArticleType + Brand
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART_SEARCH'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_ART_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleTypeCode_Input';  node = Sel 'ArticleTypeCode'  'Article Type (optional)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_2' }
                @{ id = 'ArticleBrand_Input';     node = Inp 'articleBrand'     'Brand (optional)'        '6'                                                                     'ROW_ART_2' }
                @{ id = 'ArticleCategory_Input';  node = Inp 'articleCategory'  'Category (optional)'     '1'                                                                     'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC collapsed: single card (Serial/OAN/Purpose/Type/Brand). v2.6: PascalCase fieldIds (ArticleSerialNumber, ArticleTypeCode), CAD defaults on all combos. v2.14: added (optional) helpers to Type/Brand/Category (previously had none).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (MC collapsed, OPTIONS merged into search)
# BOAT SEARCH: Hull + Reg + OAN + Name + DOB + State + PurposeCode
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_SEARCH'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber'   'Hull ID'             '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name (out-of-state only)' '30' 'ROW_BOA_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name (out-of-state only)'  '30' 'ROW_BOA_2' }
                @{ id = 'BirthDate_Input'; node = Dt 'BirthDate' 'Date of Birth (required with Name)' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA; required with Name)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_3' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_BOA_3' @{ initialValue = 'C' } }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC collapsed: single card (Hull/Reg/OAN/Name/DOB/State/Purpose). v2.6: PascalCase fieldIds, Hull>Reg guardrail, CAD defaults on all combos.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs -- PascalCase USx fields, SkipRace, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace -PascalCaseUsxFields
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $caBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $outPath `
    -Label "Built ${provider} v${Version} MC" `
    -Version $Version
