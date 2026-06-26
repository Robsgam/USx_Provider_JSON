# build_ca_clets.ps1  -- CA_CLETS
# Builds CA_CLETS.json from source\CA_CLETS.xml metadata + KB specs.
# QIDMs expanded to cover ALL 40 metadata combos (40 built, 0 LIMITATION).
# Layout: Vehicle(2), Person(3), Firearm(1), Article(1), Boat(1) -- 8 cards total
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 QIDMs, 40 combos):
#   VehicleRegistrationQuery   NLTS.RQ(P/V) + IN.VP + IV.4V + IA.QVK + IA.QV = 6 combos
#     v2.5: deleted 13 IV.4* plate-type combos (server routes by LicensePlateTypeCode value;
#     wire = MessageType=VehicleRegistrationQuery, keyRef internal) + removed inert State NOT_EQUALS.
#     v2.6: PascalCase USx fieldIds, identifier-priority guardrails (Plate>VIN, OLN>Name, Hull>Reg),
#           CAD defaults on all combos (CAD ignores form initialValue; combo defaults[] required).
#   DriverLicenseQuery         NLTS.DQ(N/O) + IN.L1 + ID.L1 + IR.QVC(OLN/Name/CriminalId/SSN) = 8 combos
#     IR.QVC OLN: criminalIdNumber promoted from any[] to set[] as routing differentiator vs ID.L1
#   DriverHistoryQuery         NLTS.KQ(N/O) = 2 combos, DH-suffix fields
#   GunQuery                   IG.QGH (name) + IG.QGB (serial) = 2 combos
#   ArticleSingleQuery         IP.QA(S/O) = 2 combos
#   BoatQuery                  NLTS.BQ(N/H/R) + IA.QB(H/O/R) + IV.4B = 7 combos
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_ca_clets.ps1 -Version 2.6

param(
    [string]$Version = "2.8"
)

$ErrorActionPreference = "Stop"
$provider = 'CA_CLETS'
$currentYear = [string](Get-Date).Year
$outPath  = "$PSScriptRoot\..\CA_CLETS_v${Version}.json"
$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$phaseDir = "$PSScriptRoot\..\phases\current"
New-Item -ItemType Directory -Force -Path $phaseDir | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_CLETS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_CLETS'

$results = Build-ProviderQrdm -ProviderName 'CA_CLETS'

$qmf = Build-Qmf -ProviderName 'CA_CLETS'

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
# NLTS.DQ(N/O) = OOS name/OLN, IN.L1 = name in-state, ID.L1 = OLN in-state,
# IR.QVC(OLN/CriminalId/SSN/Name) = criminal records search.
# IR.QVC OLN: criminalIdNumber promoted from any[] to set[] — differentiates from ID.L1.
#   OLN alone → ID.L1 (DL lookup). OLN + CII → IR.QVC.O (criminal records).
# IR.QVC.Name: broadest fallback (set=[purposeCode] only), fires when no specific combo matches.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'NLTS.DQ' for OOS combos (synthetic: NLTS.DQ.N=name, NLTS.DQ=OLN)
# and 'IR.QVC' for criminal records combos (synthetic: IR.QVC.O/.N/.C/.S per field path).
# IN.L1, ID.L1 are real CLETS codes. NOT real CA CLETS transaction codes where synthetic.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCounty';        size = 3;  sourceField = @('addressCounty');        targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'Age';                   size = 2;  sourceField = @('age');                   targetField = 'Age' }
        [PSCustomObject]@{ name = 'APPSRequestIndicator';  size = 1;  sourceField = @('appsRequestIndicator');  targetField = 'APPSRequestIndicator' }
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
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.DQ.N'
            state                 = 'In/Out'
        }
        # --- NLTS.DQ: OOS OLN search ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','OperatorLicenseNumber','RegistrationState')
                any      = @()
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.DQ'
            state                 = 'In/Out'
        }
        # --- IR.QVC.Name: criminal/demographic name search. Devdoc combos #3/#4 require
        #     Name + SexCode (+ BirthDate/Age + optional APPSRequestIndicator). v2.5 fix: sexCode
        #     PROMOTED to set[] so this is MORE specific than IN.L1 (name-only) and ordered FIRST.
        #     APPSRequestIndicator (devdoc Optional, size 1): triggers APPS prohibited-person check.
        #     (keyRef IR.QVC = server-routed Supervised Release Super Inquiry; basic per devdoc DL.) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','NameLast','NameFirst','SexCode')
                any        = @('BirthDate','age','addressCounty','height','raceCode','appsRequestIndicator')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode';           value = 'C' }
                    [PSCustomObject]@{ field = 'appsRequestIndicator';  value = 'N' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC.N'
            state                 = 'In/Out'
        }
        # --- IN.L1: In-state DMV name search (plain name; devdoc combo #1) ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','NameLast','NameFirst')
                any        = @('BirthDate','RegistrationState')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.L1'
            state                 = 'In/Out'
        }
        # --- IR.QVC.OLN: Criminal records by OLN + CII (set=3, before ID.L1 set=2).
        #     OLN wins: RegistrationState NOT_EXISTS so NLTS.DQ (OLN+State) always fires first
        #     when State is present; IR.QVC.O only fires OLN+CII when no State. ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','OperatorLicenseNumber','criminalIdNumber')
                any        = @('socialSecurityNumber','age')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'IR.QVC.O'
            state                 = 'In/Out'
        }
        # --- ID.L1: In-state OLN search (set=2). Fires only when OLN alone -- no State
        #     (NLTS.DQ covers OLN+State) and no CII (IR.QVC.O covers OLN+CII).
        #     RegistrationState removed from any[] -- NOT_EXISTS XOR guard; SSN/Age stay. ---
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCode','OperatorLicenseNumber')
                any        = @('socialSecurityNumber','age')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('criminalIdNumber');    operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.L1'
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
    )
    description     = 'DriverLicenseQuery -- 8 combos: NLTS.DQ (OOS name/OLN), IN.L1 (name), ID.L1 (OLN), IR.QVC (OLN+CII/CII/SSN/Name). 100% metadata coverage. v2.7: APPSRequestIndicator added (devdoc O field, any[] on IR.QVC.N); mutual-exclusion conditions for OLN-wins routing (IR.QVC.O/ID.L1/IR.QVC.C/IR.QVC.S); OLN cascade: OLN+State->NLTS.DQ, OLN+CII->IR.QVC.O, OLN->ID.L1, CII->IR.QVC.C, SSN->IR.QVC.S.'
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
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('purposeCodeDH','BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH')
                any        = @('RegistrationState')
                defaults   = @(
                    [PSCustomObject]@{ field = 'purposeCodeDH'; value = 'C' }
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
                any      = @('RegistrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCodeDH'; value = 'C' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.KQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- NLTS.KQ (Name+DOB+Sex), NLTS.KQ (OLN). DH-suffix fields. All via Nlets. v2.6: PascalCase fieldIds, OLN>Name guardrail on NLTS.KQ.N, CAD defaults on all combos.'
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
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('GunSerialNumber');       targetField = 'GunSerialNumber' }
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
                set      = @('purposeCode','GunSerialNumber')
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
    description     = 'GunQuery -- IG.QGH (name) + IG.QGB (serial). Most-specific first. MC cross-entity. v2.6: PascalCase fieldIds (GunSerialNumber, GunMake, NameLast/NameFirst), CAD defaults on all combos.'
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
                set      = @('purposeCode','NameLast','NameFirst','BirthDate','RegistrationState')
                any      = @()
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.BQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','BoatHullIdNumber','RegistrationState')
                any      = @()
                defaults = @(
                    [PSCustomObject]@{ field = 'purposeCode'; value = 'C' }
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
# Vehicle:  2 cards (OPTIONS + VEHICLE SEARCH)
# Person:   3 cards (OPTIONS + DRIVER LICENSE SEARCH + DRIVER HISTORY SEARCH)
# Firearm:  1 card  (FIREARM SEARCH -- Purpose merged in)
# Article:  1 card  (ARTICLE SEARCH -- Purpose merged in)
# Boat:     1 card  (BOAT SEARCH -- State + Purpose merged in)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState,
# CaRequestPurposeCode) live on a separate card to avoid duplicate fieldId
# across cards (= ISE). NCIC state pattern: visible RegistrationState,
# NO initialValue (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 2 cards (MC collapsed)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# VEHICLE SEARCH: Plate + PlateType + PlateYear + VIN + Make + Year + Name + City + StreetNum
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_VEH_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SEARCH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number (or search by VIN or Owner Name)' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (out-of-state plates)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (out-of-state plates)' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN (Plate wins if both entered)' '30' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year (optional)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name (vehicle owner search)' '30' 'ROW_VEH_3' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name (vehicle owner search)'  '30' 'ROW_VEH_3' }
                @{ id = 'AddressCity_Input';         node = Inp 'addressCity'         'City (optional)'          '13' 'ROW_VEH_3' }
                @{ id = 'AddressStreetNumber_Input'; node = Inp 'addressStreetNumber' 'Street Number (optional)' '3'  'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC collapsed: OPTIONS (State + Purpose) + SEARCH (Plate/VIN/Name all on one card)'
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
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number (or search by Name + Sex)' '20' 'ROW_PER_DL_1' }
                @{ id = 'CriminalIdNumber_Input';     node = Inp 'criminalIdNumber'     'Criminal ID (CII) - criminal records' '11' 'ROW_PER_DL_1' }
                @{ id = 'SocialSecurityNumber_Input';  node = Inp 'socialSecurityNumber'  'SSN - criminal records (no OLN)'       '9'  'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (optional)'                                              'ROW_PER_DL_2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex (required with Name)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('2','2','2','3','3'); fields = @(
                @{ id = 'Age_Input';            node = Inp 'age'            'Age (optional)'    '2' 'ROW_PER_DL_3' }
                @{ id = 'Height_Input';         node = Inp 'height'         'Height (optional)' '3' 'ROW_PER_DL_3' }
                @{ id = 'AddressCounty_Input';  node = Inp 'addressCounty'  'County (optional)' '3' 'ROW_PER_DL_3' }
                @{ id = 'RaceCode_Input'; node = Sel 'raceCode' 'Race (optional)' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_DL_3' }
                @{ id = 'AppsRequestIndicator_Input'; node = Sel 'appsRequestIndicator' 'APPS Check - prohibited persons (Name search)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_PER_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('6','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number (DH) - or Name + DOB + Sex' '20' 'ROW_PER_DH_1' }
                @{ id = 'PurposeCodeDH_Input';  node = Inp 'purposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_DH_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH_2' }
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH_2' }
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth (DH) - required with Name'                                   'ROW_PER_DH_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex (DH) - required with Name' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_2' }
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
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number (or search by Owner Name)' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';  node = Sel 'GunMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type (optional)'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name (owner search)' '30' 'ROW_GUN_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name (owner search)'  '30' 'ROW_GUN_2' }
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (optional)'               'ROW_GUN_2' }
                @{ id = 'Age_Input';       node = Inp 'age'       'Age (optional)' '2'                     'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('4'); fields = @(
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_GUN_3' @{ initialValue = 'C' } }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC collapsed: OPTIONS (Purpose) + SEARCH (Serial/Make/Caliber/Type/Name). v2.6: PascalCase fieldIds (GunSerialNumber, GunMake), CAD defaults on all combos.'
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
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number (or Owner Applied Number)' '20' 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number (OAN)' '20' 'ROW_ART_1' }
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
    description  = 'Article query -- MC collapsed: single card (Serial/OAN/Purpose/Type/Brand). v2.6: PascalCase fieldIds (ArticleSerialNumber, ArticleTypeCode), CAD defaults on all combos.'
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
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber'   'Hull ID (or Reg Number; Hull wins if both)'  '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number (or Hull ID)'           '8'  'ROW_BOA_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number (OAN)'                 '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name (out-of-state only; State + DOB required)' '30' 'ROW_BOA_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name (out-of-state only; State + DOB required)'  '30' 'ROW_BOA_2' }
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
    -PhasePath "$phaseDir\${provider}_v${Version}_${DATE}.json" `
    -Label "Built ${provider} v${Version} MC" `
    -Version $Version
