# build_ca_contra_costa_mc.ps1  -- CA_CONTRA_COSTA MC (multi-card)
# MC variant: camelCase fieldIds for CAD auto-populate. KB specs (no external template).
# Person-only provider. Both QIDMs co-fire (PersonQuery + WarrantQuery).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_contra_costa_mc.ps1
#
# INPUTS:
#   source\CA_CONTRA_COSTA.xml            -- XML metadata (v5/v4) [AUTHORITATIVE]
#   source\CA_CONTRA_COSTA.pdf            -- CommSys devdoc [CROSS-CHECK]
#   tools\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs, no external template)
#
# QUERYINPUTDATAMAPPING (CommSys -- 2 configs, 6 combos):
#   CaContraCostaJawsPersonQuery   DQ (OOS Name+DOB+Sex+State), DNQ (OOS Name+State),
#                                   INL1 (Name+addr/age/dob), IR.QVC (Name+sex/race),
#                                   IW.N (catch-all Name)
#   CaContraCostaJawsWarrantQuery  IW.N (Name+DOB)
#
# ENTITIES (1 QUERYINPUTFORM):
#   Person -- Name + DOB + Sex + Race + Age + State + Address + AddressCity +
#             RequestingAgencyId(visible) + CaPurpose(hidden)
#
# CA-SPECIFIC:
#   CaRequestPurposeCode -- hidden InpH initialValue='C' (AB 1747).
#   RequestingAgencyId -- visible FormInput (agency-specific JAWS code).
#   Date format: yyyyMMdd (CommsysParseDateRuleHandler).
#   Name format: 'Last, First' (FormatStringRuleHandler).
#   No Vehicle/Firearm/Article/Boat entities.
#   No ImageIndicator, no VehicleStolenQuery, no RandomRequest.

param(
    [string]$Version = "1.0",
    [string]$Phase   = "mc"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\CA_CONTRA_COSTA_MC.json"
$OUTREAD  = "$DIR\CA_CONTRA_COSTA_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\CA_CONTRA_COSTA_MC_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_CONTRA_COSTA PROVIDER (camelCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_CONTRA_COSTA'

$results = Build-ProviderQrdm -ProviderName 'CA_CONTRA_COSTA'

$qmf = Build-Qmf -ProviderName 'CA_CONTRA_COSTA'

# =====================================================================
# 1d. CaContraCostaJawsPersonQuery
# XML v4: 5 combos (IR.QVC, IW.N, INL1, DQ, DNQ)
# Combo ordering: most specific first (DQ > DNQ > INL1 > IR.QVC > IW.N)
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
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','birthDate','sexCode','registrationState','requestingAgencyId'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','registrationState','requestingAgencyId'); any = @('age','addressCity','sexCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'DNQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','requestingAgencyId'); any = @('address','addressCity','birthDate','age') }
            primaryFieldReference = 'Name'
            keyReference          = 'INL1'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','requestingAgencyId'); any = @('sexCode','raceCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC'
            state                 = 'In/Out'
        }
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
# XML v3: 1 combo (IW.N). Co-fires with PersonQuery on Name+DOB.
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
# 1 form: Person only. MC layout: 2 cards (Name Search + Options).
# =====================================================================

$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_NAME_1' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_NAME_1' }
            )}
            @{ id = 'ROW_NAME_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                           'ROW_NAME_2' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }            'ROW_NAME_2' }
                @{ id = 'raceCode_Input';  node = Sel 'raceCode'  'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' }      'ROW_NAME_2' }
            )}
            @{ id = 'ROW_NAME_3'; cols = @('6','6'); fields = @(
                @{ id = 'age_Input';       node = Inp 'age'       'Age' '2' 'ROW_NAME_3' }
                @{ id = 'address_Input';   node = Inp 'address'   'Address Code' '3' 'ROW_NAME_3' }
            )}
        )
    }
    @{
        id    = 'CARD_OPTIONS'
        title = 'SEARCH OPTIONS'
        rows  = @(
            @{ id = 'ROW_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationState_Input';   node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_OPT_1' }
                @{ id = 'addressCity_Input';          node = Inp 'addressCity' 'City' '13' 'ROW_OPT_1' }
                @{ id = 'requestingAgencyId_Input';   node = Inp 'requestingAgencyId' 'Agency ID' '2' 'ROW_OPT_1' }
            )}
            @{ id = 'ROW_OPT_2'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'caRequestPurposeCode_Input'; node = InpH 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_OPT_2' @{ initialValue = 'C' } }
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
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ccBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -ReadablePath $OUTREAD -PhasePath $VEROUT `
    -Label "Built CA_CONTRA_COSTA v${Version}"