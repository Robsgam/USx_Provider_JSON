# build_nj_njcjis_sextest.ps1
#
# Diagnostic build: Person entity only, single card, to isolate sex code behavior.
# Sources of truth: NJ_NJCJIS.xml (fields, sizes, combinations)
#                   HIDLE.json    (structural template, boilerplate, RMS bundle)
# No other JSON files consulted.
#
# DriverLicenseQuery fields (from NJ_NJCJIS.xml):
#   BirthDate(8), Name(30: Last,First,Middle,Suffix), ImageIndicator(1),
#   OperatorLicenseNumber(20), SexCode(1), State(2)
#
# Combinations:
#   DQ  (Name path): set=[BirthDate, NameLast, NameFirst], any=[SexCode, ImageIndicator, RegistrationState]
#   DQN (OLN path):  set=[OperatorLicenseNumber],          any=[ImageIndicator, RegistrationState]
#
# Sex field: attributeTypeId=SEX + codeTypeProvider=NIBRS (same as AZ_AZDPS working build)
# RMS: sex attribute kept with useAttributeId=true (no sex patches)
#
# Output: NJ_NJCJIS_sextest.json
# =============================================================================

$DIR       = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$HIDLEPATH = "$DIR\source\HIDLE.json"
$OUT       = "$DIR\NJ_NJCJIS_sextest.json"

Write-Host ""
Write-Host "========================================"
Write-Host " NJ_NJCJIS Sex Code Diagnostic Build"
Write-Host " Source 1: NJ_NJCJIS.xml"
Write-Host " Source 2: HIDLE.json (HI_HCJDC template)"
Write-Host " Entity:   Person only -- single card"
Write-Host "========================================"
Write-Host ""

$hidle    = Get-Content $HIDLEPATH -Raw | ConvertFrom-Json
$hidleNj  = $hidle.bundles | Where-Object { $_.name -eq 'HI_HCJDC' }
$hidleRms = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
function DeepClone($obj) { $obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json }

# =============================================================================
# SECTION 1 -- CommSys boilerplate (cloned from HIDLE, provider updated)
# =============================================================================

$njAuth          = DeepClone($hidleNj.configurations | Where-Object { $_.type -eq 'AUTHENTICATION' })
$njAuth.name     = 'NJ_NJCJIS'
$njAuth.provider = 'NJ_NJCJIS'

$njQrdm          = DeepClone($hidleNj.configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' })
$njQrdm.name     = 'NJ_NJCJIS_Results'
$njQrdm.provider = 'NJ_NJCJIS'

$njMsgFmt          = DeepClone($hidleNj.configurations | Where-Object { $_.type -eq 'QUERYMESSAGEFORMAT' })
$njMsgFmt.provider = 'NJ_NJCJIS'

Write-Host "Boilerplate: auth + QRDM + MessageFormat cloned from HIDLE" -ForegroundColor Cyan

# =============================================================================
# SECTION 2 -- Person QIDM (from NJ_NJCJIS.xml)
# =============================================================================

function New-AttentionAttr {
    [PSCustomObject]@{
        name        = 'Attention'
        size        = 30
        rule        = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        sourceField = @('Attention')
        targetField = 'Attention'
    }
}

$qidm_person = [PSCustomObject]@{
    name            = 'NJ_NJCJIS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'NJ_NJCJIS Person'
    targetEntity    = 'Person'
    handlerFunction = 'CommsysTransactionRequestHandler'
    description     = 'Driver License Query -- NJ NJCJIS (DQ + DQN)'
    autoSelect      = $true
    attributes      = @(
        (New-AttentionAttr),
        [PSCustomObject]@{
            name        = 'BirthDate'
            size        = 8
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            sourceField = @('BirthDate')
            targetField = 'BirthDate'
        },
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1;  sourceField = @('ImageIndicator');       targetField = 'ImageIndicator' },
        [PSCustomObject]@{
            name        = 'Name'
            size        = 30
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix')
            targetField = 'Name'
        },
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' },
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' },
        [PSCustomObject]@{ name = 'State';   size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations    = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BirthDate','NameLast','NameFirst')
                any        = @('SexCode','ImageIndicator','RegistrationState','Attention')
                conditions = $null
                defaults   = $null
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('OperatorLicenseNumber')
                any        = @('ImageIndicator','RegistrationState','Attention')
                conditions = $null
                defaults   = $null
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
    )
}
Write-Host "  QIDM Person: DriverLicenseQuery (DQ -- Name+DOB+Sex; DQN -- OLN)" -ForegroundColor Green

# =============================================================================
# SECTION 3 -- Person QIF (single card)
# =============================================================================

$qif_person = [PSCustomObject]@{
    description  = 'Input query layout for person entity -- NJ sex code diagnostic'
    label        = 'Person'
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
    provider     = 'MARK43'
    layout       = [PSCustomObject]@{
        default = [ordered]@{
            ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Root'}; displayName='Root'; props=[PSCustomObject]@{}
                isCanvas=$false; hidden=$false; nodes=@('FORM_ROOT'); linkedNodes=[PSCustomObject]@{} }
            FORM_ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Form'}; displayName='Form'
                props=[PSCustomObject]@{hidePageItems=$true; layout='page'}
                isCanvas=$true; hidden=$false; nodes=@('ROOT_PAGE'); parent='ROOT'; linkedNodes=[PSCustomObject]@{} }
            ROOT_PAGE = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Page'}; displayName='Page'
                props=[PSCustomObject]@{title='Page 1'}
                isCanvas=$true; hidden=$false; nodes=@('ROOT_CARD'); parent='FORM_ROOT'; linkedNodes=[PSCustomObject]@{} }
            ROOT_CARD = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Card'}; displayName='Card'
                props=[PSCustomObject]@{title='Person'}
                isCanvas=$true; hidden=$false; nodes=@('ROW_1','ROW_2','ROW_3','ROW_4','ROW_5')
                parent='ROOT_PAGE'; linkedNodes=[PSCustomObject]@{} }
            ROW_1 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Row'}; displayName='Row'
                props=[PSCustomObject]@{templateColumns=@('12')}
                isCanvas=$true; hidden=$false; nodes=@('OLN_Input'); parent='ROOT_CARD'; linkedNodes=[PSCustomObject]@{} }
            ROW_2 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Row'}; displayName='Row'
                props=[PSCustomObject]@{templateColumns=@('12')}
                isCanvas=$true; hidden=$false; nodes=@('State_Input'); parent='ROOT_CARD'; linkedNodes=[PSCustomObject]@{} }
            ROW_3 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Row'}; displayName='Row'
                props=[PSCustomObject]@{templateColumns=@('6','6')}
                isCanvas=$true; hidden=$false; nodes=@('LastName_Input','FirstName_Input'); parent='ROOT_CARD'; linkedNodes=[PSCustomObject]@{} }
            ROW_4 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Row'}; displayName='Row'
                props=[PSCustomObject]@{templateColumns=@('6','6')}
                isCanvas=$true; hidden=$false; nodes=@('DOB_Input','Sex_Input'); parent='ROOT_CARD'; linkedNodes=[PSCustomObject]@{} }
            ROW_5 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='Row'}; displayName='Row'
                props=[PSCustomObject]@{templateColumns=@('12')}
                isCanvas=$true; hidden=$false; nodes=@('ImageIndicator_Input'); parent='ROOT_CARD'; linkedNodes=[PSCustomObject]@{} }
            OLN_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormInput'}; displayName='Input'
                props=[PSCustomObject]@{fieldId='OperatorLicenseNumber'; label='OLN'}
                isCanvas=$false; hidden=$false; nodes=@(); parent='ROW_1'; linkedNodes=[PSCustomObject]@{} }
            State_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormSelect'}; displayName='Select'
                props=[PSCustomObject]@{attributeTypeId='STATE'; fieldId='RegistrationState'; initialValue='NJ'; label='State'}
                isCanvas=$false; hidden=$false; nodes=@(); parent='ROW_2'; linkedNodes=[PSCustomObject]@{} }
            LastName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormInput'}; displayName='Input'
                props=[PSCustomObject]@{fieldId='NameLast'; label='Last Name'}
                isCanvas=$false; hidden=$false; nodes=@(); parent='ROW_3'; linkedNodes=[PSCustomObject]@{} }
            FirstName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormInput'}; displayName='Input'
                props=[PSCustomObject]@{fieldId='NameFirst'; label='First Name'}
                isCanvas=$false; hidden=$false; nodes=@(); parent='ROW_3'; linkedNodes=[PSCustomObject]@{} }
            DOB_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormDate'}; displayName='Date'
                props=[PSCustomObject]@{fieldId='BirthDate'; label='Date Of Birth'}
                isCanvas=$false; hidden=$false; nodes=@(); parent='ROW_4'; linkedNodes=[PSCustomObject]@{} }
            Sex_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormSelect'}; displayName='Select'
                props=[PSCustomObject]@{attributeTypeId='SEX'; codeTypeProvider='NIBRS'; fieldId='SexCode'; label='Sex'}
                isCanvas=$false; hidden=$false; nodes=@(); parent='ROW_4'; linkedNodes=[PSCustomObject]@{} }
            ImageIndicator_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormSelect'}; displayName='Select'
                props=[PSCustomObject]@{codeTypeCategory='YES_NO_UNKNOWN'; codeTypeSource='NCIC'; fieldId='ImageIndicator'; initialValue='Y'; label='Image Indicator'}
                isCanvas=$false; hidden=$false; nodes=@(); parent='ROW_5'; linkedNodes=[PSCustomObject]@{} }
        }
    }
}

# Add CAD_DISPATCH and FIRST_RESPONDER variants
$qif_person.layout | Add-Member -MemberType NoteProperty -Name 'CAD_DISPATCH'    -Value (DeepClone($qif_person.layout.default)) -Force
$qif_person.layout | Add-Member -MemberType NoteProperty -Name 'FIRST_RESPONDER' -Value (DeepClone($qif_person.layout.default)) -Force

Write-Host "  QIF Person: OLN / State(NJ) / Last / First / DOB / Sex / ImageIndicator" -ForegroundColor Green

# =============================================================================
# SECTION 4 -- RMS bundle (cloned from HIDLE, no sex patches)
# =============================================================================
$njRms = DeepClone($hidleRms)
Write-Host ""
Write-Host "RMS bundle: cloned from HIDLE (sex attribute kept -- no patches)" -ForegroundColor Cyan

# =============================================================================
# SECTION 5 -- Assemble and write
# =============================================================================

$njBundle = [PSCustomObject]@{
    name             = 'NJ_NJCJIS'
    description      = 'Provider configuration for NJ_NJCJIS -- sex code diagnostic'
    type             = 'BUNDLE'
    codeTypeProvider = 'NJ_NJCJIS'
    provider         = 'NJ_NJCJIS'
    configurations   = @($njAuth, $njQrdm, $njMsgFmt, $qidm_person)
}

$entitiesBundle = [PSCustomObject]@{
    name             = 'ENTITIES'
    description      = 'Query forms of entities'
    type             = 'BUNDLE'
    codeTypeProvider = 'NCIC'
    provider         = 'MARK43'
    order            = [PSCustomObject]@{
        default         = @('Person')
        CAD_DISPATCH    = @('Person')
        FIRST_RESPONDER = @('Person')
    }
    configurations   = @($qif_person)
}

$output = [PSCustomObject]@{
    bundles = @($njBundle, $entitiesBundle, $njRms)
}

($output | ConvertTo-Json -Depth 100) | Set-Content $OUT -Encoding UTF8

Write-Host ""
Write-Host "========================================"
Write-Host " Output: $OUT"
Write-Host "========================================"
Write-Host ""
Write-Host "NJ_NJCJIS bundle (CommSys):"
Write-Host "  Authentication      -- cloned from HIDLE (provider -> NJ_NJCJIS)"
Write-Host "  QUERYRESULTDATAMAPPING  -- cloned from HIDLE (provider -> NJ_NJCJIS)"
Write-Host "  QUERYMESSAGEFORMAT  -- cloned from HIDLE (provider -> NJ_NJCJIS)"
Write-Host "  QIDM Person         -- DriverLicenseQuery (DQ + DQN)"
Write-Host "    SexCode attr:       codeTypeProvider=NIBRS  (same as AZ_AZDPS)"
Write-Host "    Sex form field:     attributeTypeId=SEX + codeTypeProvider=NIBRS  (same as AZ_AZDPS)"
Write-Host ""
Write-Host "ENTITIES bundle:  Person only (single card)"
Write-Host "RMS bundle:       cloned from HIDLE -- sex attribute present, useAttributeId=true"
Write-Host ""
Write-Host "NOTE: This is a diagnostic build. Import and test sex code behavior."
Write-Host "      Expected if NJ has same registration as AZ: <SexCode>F</SexCode>"
Write-Host "      If NJ lacks registration:                   <SexCode>69585932695</SexCode>"
Write-Host ""
