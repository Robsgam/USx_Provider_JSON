# build_ca_contra_costa.ps1  -- CA_CONTRA_COSTA v1.x BASE
# Builds CA_CONTRA_COSTA_BASE.json from source\CA_CONTRA_COSTA.xml (metadata v5) + KB specs.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_contra_costa.ps1 -Version X.X -Phase base
#
# INPUTS:
#   source\CA_CONTRA_COSTA.xml   -- XML metadata (v5) [AUTHORITATIVE]
#   source\CA_CONTRA_COSTA.pdf   -- CommSys devdoc [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
#
# METADATA SUMMARY (CA_CONTRA_COSTA v4/v3):
#   CaContraCostaJawsPersonQuery v4   -- 5 combos: IR.QVC, IW.N, INL1, DQ, DNQ
#   CaContraCostaJawsWarrantQuery v3  -- 1 combo: IW.N
#
# THIS IS NOT CLETS. It is a Contra Costa County regional JAWS interface.
# Devdoc says "Basic Queries Supported: None" and "Expanded Queries Supported" only.
# CLETSPersonSuperQuery is in devdoc but NOT in metadata XML -- not authorized.
#
# CA-SPECIFIC:
#   CaRequestPurposeCode -- required per devdoc (AB 1747). Hidden InpH initialValue='C'.
#     Metadata shows some combos without it (IW.N), but devdoc says mandatory for all.
#     Include as hidden on form; combos that don't need it in set[] will just send it anyway
#     (LIMITATION #1: all populated attrs are sent regardless of combo requirements).
#   RequestingAgencyId -- mandatory (M) in both queries, size=2. Agency-specific JAWS code.
#     Visible input field -- importing agency configures their own code.
#   Name -- composite (type=Name, size=30). FormatStringRuleHandler 'Last, First'.
#   BirthDate -- Date type, size=8 -> yyyyMMdd format (CommsysParseDateRuleHandler).
#   No standard queries (no Vehicle, Firearm, Article, Boat).
#   No ImageIndicator, no VehicleStolenQuery, no RandomRequest.
#   No State initialValue needed -- DQ/DNQ OOS combos use State in set[].
#
# QUERYINPUTDATAMAPPING (CommSys -- 2 configs, 6 combos):
#   CaContraCostaJawsPersonQuery   DQ (OOS Name+DOB+Sex+State), DNQ (OOS Name+State),
#                                   INL1 (Name+Address/City/DOB/Age), IR.QVC (Name+Sex/Race),
#                                   IW.N (Name, catch-all)
#   CaContraCostaJawsWarrantQuery  IW.N (Name+DOB)
#
# ENTITIES (1 QUERYINPUTFORM):
#   Person -- Name + DOB + Sex + Race + Age + State + Address + AddressCity +
#             RequestingAgencyId(visible) + CaPurpose(hidden)
#
# PERSON: Both queries co-fire by design.
#   WarrantQuery fires on Name+DOB (IW.N). PersonQuery fires on broader criteria.
#   Both have autoSelect=true. Officer can uncheck to disable specific queries.

param(
    [string]$Version = "1.0",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\CA_CONTRA_COSTA_BASE.json"
$VEROUT   = "$PHASEDIR\CA_CONTRA_COSTA_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_CONTRA_COSTA PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_CONTRA_COSTA'

$results = Build-ProviderQrdm -ProviderName 'CA_CONTRA_COSTA'

$qmf = Build-Qmf -ProviderName 'CA_CONTRA_COSTA'

# =====================================================================
# 1d. CaContraCostaJawsPersonQuery
# XML v4: 5 combos (IR.QVC, IW.N, INL1, DQ, DNQ)
# Devdoc combos:
#   1. (In) BirthDate, Name, RequestingAgencyId, [Address, AddressCity]
#   2. (In) Age, Name, RequestingAgencyId, [Address, AddressCity]
#   3. (In/Out) Name, RequestingAgencyId, [Age, BirthDate, RaceCode, SexCode]
#   4. (Out) BirthDate, Name, SexCode, State, RequestingAgencyId
#   5. (Out) Age, Name, State, RequestingAgencyId, [AddressCity, SexCode]
#
# Combo ordering: most specific first (LIMITATION #3).
#   DQ > DNQ > INL1 > IR.QVC > IW.N
#
# CaRequestPurposeCode: included in all combos that metadata requires it in set[].
# IW.N does NOT require it in metadata, but devdoc says mandatory for all transactions.
# We include it as hidden field -- LIMITATION #1 means it will be sent anyway.
#
# Address (size=3): tiny field, likely a code. Included as visible FormInput.
# =====================================================================
$personQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Address';     size = 3;  sourceField = @('address');     targetField = 'Address' }
        [PSCustomObject]@{ name = 'AddressCity'; size = 13; sourceField = @('addressCity'); targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'Age';         size = 2;  sourceField = @('age');         targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCode'); targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RequestingAgencyId'; size = 2; sourceField = @('requestingAgencyId'); targetField = 'RequestingAgencyId' }
        [PSCustomObject]@{ name = 'SexCode';  size = 1; sourceField = @('sexCode');  targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';    size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Combo 4 (Out): most specific -- Name+DOB+Sex+State (OOS full)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','birthDate','sexCode','registrationState','requestingAgencyId'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        # Combo 5 (Out): Name+State (OOS general)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','registrationState','requestingAgencyId'); any = @('age','addressCity','sexCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'DNQ'
            state                 = 'In/Out'
        }
        # Combo 1+2 (In): Name + address/age/dob options
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','requestingAgencyId'); any = @('address','addressCity','birthDate','age') }
            primaryFieldReference = 'Name'
            keyReference          = 'INL1'
            state                 = 'In/Out'
        }
        # Combo 3 (In/Out): Name + sex/race options
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','requestingAgencyId'); any = @('sexCode','raceCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC'
            state                 = 'In/Out'
        }
        # Catch-all: Name only (warrant-style)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','requestingAgencyId'); any = @('birthDate') }
            primaryFieldReference = 'Name'
            keyReference          = 'IW.N'
            state                 = 'In/Out'
        }
    )
    description     = 'CaContraCostaJawsPersonQuery -- DQ (OOS Name+DOB+Sex+State), DNQ (OOS Name+State), INL1 (Name+addr/age/dob), IR.QVC (Name+sex/race), IW.N (catch-all).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CONTRA_COSTA_CaContraCostaJawsPersonQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CONTRA_COSTA'
    providerType    = 'Commsys'
    query           = 'CaContraCostaJawsPersonQuery'
    queryLabel      = 'JAWS Person'
    targetEntity    = 'Person'
}

# =====================================================================
# 1e. CaContraCostaJawsWarrantQuery
# XML v3: 1 combo (IW.N)
# Devdoc: Name + BirthDate + RequestingAgencyId (all mandatory)
# Co-fires with PersonQuery on Name+DOB -- standard workflow.
# =====================================================================
$warrantQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'RequestingAgencyId'; size = 2; sourceField = @('requestingAgencyId'); targetField = 'RequestingAgencyId' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','requestingAgencyId'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IW.N'
            state                 = 'In/Out'
        }
    )
    description     = 'CaContraCostaJawsWarrantQuery -- IW.N (Name+DOB). Contra Costa warrant search.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CONTRA_COSTA_CaContraCostaJawsWarrantQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CONTRA_COSTA'
    providerType    = 'Commsys'
    query           = 'CaContraCostaJawsWarrantQuery'
    queryLabel      = 'JAWS Warrant'
    targetEntity    = 'Person'
}

$ccBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $personQuery, $warrantQuery)
    description    = "Provider configuration for CA_CONTRA_COSTA v${Version}"
    name           = 'CA_CONTRA_COSTA'
    type           = 'BUNDLE'
    provider       = 'CA_CONTRA_COSTA'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 1 form: Person only. No Vehicle, Firearm, Article, Boat.
# Phase 1: single card.
# CaRequestPurposeCode: hidden InpH initialValue='C' (Criminal Justice).
# RequestingAgencyId: visible FormInput -- agency-specific JAWS code.
# State: NO initialValue -- DQ/DNQ OOS combos use State in set[].
# =====================================================================

# ------------------------------------------------------------------
# Person -- 1 card
# Serves 2 QIDMs: PersonQuery + WarrantQuery (co-fire).
# Both have autoSelect=true. Officer can deselect either.
# Fields: Name (First+Last), DOB, Sex, Race, Age, State,
#         Address, AddressCity, RequestingAgencyId, CaPurpose(hidden)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_1' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                           'ROW_PER_2' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }            'ROW_PER_2' }
                @{ id = 'raceCode_Input';  node = Sel 'raceCode'  'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' }      'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'age_Input';               node = Inp 'age'               'Age'               '2'  'ROW_PER_3' }
                @{ id = 'registrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_3' }
                @{ id = 'requestingAgencyId_Input'; node = Inp 'requestingAgencyId' 'Agency ID' '2' 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'address_Input';     node = Inp 'address'     'Address Code' '3'  'ROW_PER_4' }
                @{ id = 'addressCity_Input'; node = Inp 'addressCity' 'City'         '13' 'ROW_PER_4' }
                @{ id = 'caRequestPurposeCode_Input'; node = InpH 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_4' @{ initialValue = 'C' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- CaContraCostaJawsPersonQuery + CaContraCostaJawsWarrantQuery (co-fire).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($personForm) -DefaultOrder @('Person') -CadOrder @('Person') -FrOrder @('Person')

# =====================================================================
# BUNDLE 3: RMS (from KB specs)
# Person-only provider: Vehicle RMS QIDM kept with autoSelect=true
# (won't fire without Vehicle form fields) but extensively cleaned.
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ccBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built CA_CONTRA_COSTA v${Version}" `
    -Version $Version