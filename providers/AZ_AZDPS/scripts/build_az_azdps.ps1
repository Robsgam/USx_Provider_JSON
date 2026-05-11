# build_az_azdps.ps1
# Builds AZ_AZDPS_BASE.json from source\AZ_AZDPS.xml + HIDLE.json (RMS template).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_az_azdps.ps1
#
# QUERYINPUTDATAMAPPING (CommSys -- 8 QIDMs):
#   VehicleRegistrationQuery         ACVR (Plate+Badge), ACVRV (VIN+Badge -- invented)
#   AzAzdpsDriverLicenseQuery        DQ (OLN), DQN (Name), DQSS (SSN), ACWL (Badge+Name)
#   DriverHistoryQuery               KQ (OLN+State), KQH (Name+State -- invented)
#   GunQuery                         ACQG (Badge+Serial)
#   ArticleSingleQuery               ACQA (Badge+Type+Serial)
#   BoatQuery                        ACQB (Reg+Badge), ACQBH (Hull+Badge), BQ (Reg), BQH (Hull)
#   WMPIWantedPersonInquiry          ACQW (Name+DOB+Sex+Race), ACQWN (NCICNumber -- invented)
#   WMPIMissingPersonInquiry         ACQM (Name+descriptors), ACQMN (NCICNumber -- invented)
#
# ENTITIES (5 QUERYINPUTFORM -- single card each):
#   Vehicle, Person, Firearm, Article, Boat
#
# STATE: NCIC pattern confirmed (attributeTypeId=STATE, codeTypeProvider=NCIC)
# SEX: NIBRS confirmed (attributeTypeId=SEX, codeTypeProvider=NIBRS)
# DH-SUFFIX: OperatorLicenseNumberDH, NameLastDH, etc. -- isolates DH from DL field pool
# BadgeNumber: hidden field auto-populated via dexStateUserId (CommsysGetDexStateUserIdRuleHandler)
# Date format: yyyyMMdd (AZ)

$ErrorActionPreference = "Stop"
$Version = '2.1'
$currentYear = [string](Get-Date).Year
$DIR    = (Resolve-Path "$PSScriptRoot\..").Path
$OUT    = "$DIR\AZ_AZDPS_BASE.json"
$VEROUT = "$DIR\phases\base\AZ_AZDPS_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"
$hidle  = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS
# =====================================================================
function N($type, $display, $props, $isCanvas, $hidden, $nodes, $parent) {
    $nodeList = [System.Collections.Generic.List[string]]::new()
    if ($nodes) { foreach ($n in @($nodes)) { $nodeList.Add([string]$n) } }
    $obj = [ordered]@{
        type        = [PSCustomObject]@{ resolvedName = $type }
        displayName = $display
        props       = [PSCustomObject]$props
        isCanvas    = [bool]$isCanvas
        hidden      = [bool]$hidden
        nodes       = $nodeList
        linkedNodes = [PSCustomObject]@{}
    }
    if ($parent -ne '') { $obj['parent'] = "$parent" }
    [PSCustomObject]$obj
}

function Inp($fid, $lbl, $maxLen, $parentId, $extra = @{}) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    if ($maxLen) { $p['maxLength'] = $maxLen }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormInput' 'Input' $p $false $false @() $parentId
}

function InpH($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormInput' 'Input' $p $false $true @() $parentId
}

function Sel($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $false @() $parentId
}

function SelH($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $true @() $parentId
}

function Dt($fid, $lbl, $parentId) {
    N 'FormDate' 'Date' @{ fieldId = $fid; label = $lbl } $false $false @() $parentId
}

function BuildLayout($cardDefs) {
    $l = [ordered]@{}
    $cardIds = @($cardDefs | ForEach-Object { $_.id })
    $l['ROOT']      = N 'Root' 'Root' @{} $false $false @('FORM_ROOT') ''
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false $cardIds 'FORM_ROOT'
    foreach ($cardDef in $cardDefs) {
        $rowIds    = @($cardDef.rows | ForEach-Object { $_.id })
        $cardProps = if ($cardDef.title) { @{ title = $cardDef.title } } else { @{} }
        $l[$cardDef.id] = N 'Card' 'Card' $cardProps $true $false $rowIds 'ROOT_PAGE'
        foreach ($rowDef in $cardDef.rows) {
            $fieldIds  = @($rowDef.fields | ForEach-Object { $_.id })
            $rowHidden = if ($rowDef['hidden']) { $true } else { $false }
            $l[$rowDef.id] = N 'Row' 'Row' @{ templateColumns = [array]$rowDef.cols } $true $rowHidden $fieldIds $cardDef.id
            foreach ($f in $rowDef.fields) { $l[$f.id] = $f.node }
        }
    }
    return [PSCustomObject]$l
}

function AddCadNodes($layout) {
    $clone = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $pageNodes = [System.Collections.Generic.List[string]]($clone.ROOT_PAGE.nodes)
    $pageNodes.Insert(0, 'CONTEXT_INFO_CARD')
    $clone.ROOT_PAGE.nodes = $pageNodes.ToArray()
    $clone | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (N 'Card' 'Card' @{} $true $false @('ROW_0') 'ROOT_PAGE') -Force
    $clone | Add-Member -NotePropertyName 'ROW_0'             -NotePropertyValue (N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('CadUnit_Input','CadEvent_Input') 'CONTEXT_INFO_CARD') -Force
    $clone | Add-Member -NotePropertyName 'CadUnit_Input'     -NotePropertyValue (Sel 'CAD_UNIT_SELECT_VALUE'  'Requesting Unit' @{ attributeTypeId = 'CAD_UNIT_SELECT_VALUE' } 'ROW_0') -Force
    $clone | Add-Member -NotePropertyName 'CadEvent_Input'    -NotePropertyValue (Sel 'CAD_EVENT_SELECT_VALUE' 'Event' @{ attributeTypeId = 'CAD_EVENT_SELECT_VALUE'; performSearchAhead = $true } 'ROW_0') -Force
    return $clone
}

function AddFrNodes($layout) {
    $clone = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $pageNodes = [System.Collections.Generic.List[string]]($clone.ROOT_PAGE.nodes)
    $pageNodes.Insert(0, 'CONTEXT_INFO_CARD')
    $clone.ROOT_PAGE.nodes = $pageNodes.ToArray()
    $clone | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (N 'Card' 'Card' @{} $true $false @('LinkToEvent_Input') 'ROOT_PAGE') -Force
    $clone | Add-Member -NotePropertyName 'LinkToEvent_Input' -NotePropertyValue (N 'FormCheckbox' 'Checkbox' @{ fieldId = 'LINK_CURRENT_ASSIGNED_EVENT'; label = ' '; checkboxLabel = 'Link to the current assigned event' } $false $false @() 'CONTEXT_INFO_CARD') -Force
    return $clone
}

function MakeLayouts($cardDefs) {
    $def = BuildLayout $cardDefs
    $cad = AddCadNodes $def
    $fr  = AddFrNodes  $def
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# BUNDLE 1: AZ_AZDPS PROVIDER
# =====================================================================

# 1a. AUTHENTICATION
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');       targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic');   targetField = 'Mnemonic' }
        [PSCustomObject]@{
            description = 'dexUserStateid from RMS profile'
            name        = 'UserName'
            rule        = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }
            sourceField = @('dexStateUserId')
            targetField = 'UserName'
        }
    )
    combinations = @(
        [PSCustomObject]@{
            keyReference = 'AUTH'
            requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for AZ AZDPS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'AZ_AZDPS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'AZ_AZDPS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'AZ_AZDPS_Results'
$results.description = 'Results mapping for AZ AZDPS'
$results.provider    = 'AZ_AZDPS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'AZ_AZDPS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'AZ_AZDPS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery -- ACVR (Plate) + ACVRV (VIN, invented)
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';                 size = 4;  sourceField = @('dexStateUserId');            targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');       targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');      targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');          targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('RegistrationState');         targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');           targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('VehicleYear');               targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','LicensePlateNumber')
                any = @('LicensePlateYear','LicensePlateTypeCode','RegistrationState','VehicleIdentificationNumber','VehicleMakeCode','VehicleYear')
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ACVR'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','VehicleIdentificationNumber')
                any = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState','VehicleMakeCode','VehicleYear')
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
            size        = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';  size = 9;  sourceField = @('SocialSecurityNumber');  targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationState');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber')
                any = @('dexStateUserId','BirthDate','NameFirst','NameLast','NameMiddle','NameSuffix','RegistrationState','SexCode','SocialSecurityNumber')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','SexCode','BirthDate')
                any = @('dexStateUserId','NameMiddle','NameSuffix','OperatorLicenseNumber','RegistrationState','SocialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('SocialSecurityNumber')
                any = @('dexStateUserId','BirthDate','NameFirst','NameLast','NameMiddle','NameSuffix','OperatorLicenseNumber','RegistrationState','SexCode')
            }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'DQSS'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','BirthDate','NameLast','NameFirst','SexCode')
                any = @('NameMiddle','NameSuffix','OperatorLicenseNumber','RegistrationState','SocialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACWL'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for AzAzdpsDriverLicenseQuery (DQ OLN + DQN Name + DQSS SSN + ACWL Badge)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_AzAzdpsDriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'AzAzdpsDriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- KQ (OLN), KQH (Name, invented)
# DH-suffix isolation. StateDH hidden with initialValue='AZ'. Date: yyyyMMdd.
# =====================================================================
$dhistQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention';             size = 30; sourceField = @('Attention');               targetField = 'Attention' }
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
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('PurposeCode');             targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('StateDH');                 targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('StateDH','OperatorLicenseNumberDH')
                any = @('Attention','BirthDateDH','NameFirstDH','NameLastDH','NameMiddleDH','NameSuffixDH','PurposeCode','SexCodeDH')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('StateDH','NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH')
                any = @('Attention','NameMiddleDH','NameSuffixDH','OperatorLicenseNumberDH','PurposeCode')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQH'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverHistoryQuery (KQ OLN + KQH Name -- DH-suffix isolation)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery -- ACQG (Badge+Serial)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'GunCaliber';               size = 4;  sourceField = @('GunCaliber');               targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                  size = 4;  sourceField = @('GunMake');                  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                 size = 11; sourceField = @('GunModel');                 targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';          size = 11; sourceField = @('GunSerialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','GunSerialNumber')
                any = @('GunCaliber','GunMake','GunModel','RelatedHitSearchIndicator')
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
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','ArticleTypeCode','ArticleSerialNumber')
                any = @('RelatedHitSearchIndicator')
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
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State';                    size = 2;  sourceField = @('RegistrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','RegistrationNumber')
                any = @('BoatHullIdNumber','RegistrationState','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ACQB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','BoatHullIdNumber')
                any = @('RegistrationNumber','RegistrationState','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ACQBH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber')
                any = @('dexStateUserId','BoatHullIdNumber','RegistrationState','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber')
                any = @('dexStateUserId','RegistrationNumber','RegistrationState','RelatedHitSearchIndicator')
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
# 1j. WMPIWantedPersonInquiry -- ACQW (Name+DOB+Sex+Race), ACQWN (NCIC, invented)
# =====================================================================
$wantedQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('ExpandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';    size = 1;  sourceField = @('ExpandedNameSearchCode');    targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('NCICNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                  size = 1;  sourceField = @('RaceCode');                  targetField = 'RaceCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                   size = 1;  sourceField = @('SexCode');                   targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode','RaceCode')
                any = @('ExpandedBirthDateSearchCode','ExpandedNameSearchCode','NameMiddle','NameSuffix','NCICNumber','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQW'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NCICNumber')
                any = @('BirthDate','ExpandedBirthDateSearchCode','ExpandedNameSearchCode','NameFirst','NameLast','NameMiddle','NameSuffix','RaceCode','RelatedHitSearchIndicator','SexCode')
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'ACQWN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for WMPIWantedPersonInquiry (ACQW Name+DOB+Sex+Race + ACQWN NCIC)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_WMPIWantedPersonInquiry'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'WMPIWantedPersonInquiry'
    queryLabel      = 'Wanted Person'
    targetEntity    = 'Person'
}

# =====================================================================
# 1k. WMPIMissingPersonInquiry -- ACQM (Name+descriptors), ACQMN (NCIC, invented)
# =====================================================================
$missingQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Age';                      size = 2;  sourceField = @('Age');                      targetField = 'Age' }
        [PSCustomObject]@{ name = 'AreaCode';                 size = 3;  sourceField = @('AreaCode');                 targetField = 'AreaCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';   size = 1;  sourceField = @('ExpandedNameSearchCode');   targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{ name = 'EyeColorCode';             size = 3;  sourceField = @('EyeColorCode');             targetField = 'EyeColorCode' }
        [PSCustomObject]@{ name = 'FormORI';                  size = 9;  sourceField = @('FormORI');                  targetField = 'FormORI' }
        [PSCustomObject]@{ name = 'HairColorCode';            size = 3;  sourceField = @('HairColorCode');            targetField = 'HairColorCode' }
        [PSCustomObject]@{ name = 'Height';                   size = 3;  sourceField = @('Height');                   targetField = 'Height' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';               size = 10; sourceField = @('NCICNumber');               targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                 size = 1;  sourceField = @('RaceCode');                 targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                  size = 1;  sourceField = @('SexCode');                  targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'Weight';                   size = 3;  sourceField = @('Weight');                   targetField = 'Weight' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('Age','SexCode','RaceCode','Height','Weight','EyeColorCode','HairColorCode','NameLast','NameFirst')
                any = @('AreaCode','ExpandedNameSearchCode','FormORI','NameMiddle','NameSuffix','NCICNumber','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQM'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NCICNumber')
                any = @('Age','AreaCode','ExpandedNameSearchCode','EyeColorCode','FormORI','HairColorCode','Height','NameFirst','NameLast','NameMiddle','NameSuffix','RaceCode','RelatedHitSearchIndicator','SexCode','Weight')
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'ACQMN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for WMPIMissingPersonInquiry (ACQM Name+descriptors + ACQMN NCIC)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_WMPIMissingPersonInquiry'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'WMPIMissingPersonInquiry'
    queryLabel      = 'Missing Person'
    targetEntity    = 'Person'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# =====================================================================

# VEHICLE -- 1 card
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','6'); fields = @(
                @{ id = 'LicPlate_Input';  node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'State_Veh_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Veh'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_VEH_BADGE' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'PlateType_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'PlateYear_Input'; node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
                @{ id = 'VIN_Input';       node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'Make_Veh_Input'; node = Sel 'VehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'Year_Veh_Input'; node = Inp 'VehicleYear' 'Year' '4' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate+Badge (ACVR) and VIN+Badge (ACVRV) on single card.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# PERSON -- 1 card (DL + DH + Wanted + Missing all on one card)
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'OLN_Per_Input';   node = Inp 'OperatorLicenseNumber' 'License Number (DL)' '20' 'ROW_PER_1' }
                @{ id = 'SSN_Per_Input';   node = Inp 'SocialSecurityNumber' 'SSN' '9' 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Per'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_PER_BADGE' }
            )}
            @{ id = 'ROW_PER_1B'; cols = @('6'); fields = @(
                @{ id = 'State_Per_Input'; node = Sel 'RegistrationState' 'State (DL)' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_PER_1B' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_2' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '20' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'M.I.'         '20' 'ROW_PER_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'        '4' 'ROW_PER_3' }
                @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'     'ROW_PER_3' }
                @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('8','4'); fields = @(
                @{ id = 'OLN_DH_Input';    node = Inp 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_4' }
                @{ id = 'Purpose_DH_Input';node = Inp 'PurposeCode' 'Purpose Code' '1' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_4B'; cols = @('12'); fields = @(
                @{ id = 'Attention_DH_Input'; node = Inp 'Attention' 'Attention (DH)' '30' 'ROW_PER_4B' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_5' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name (DH)' '20' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'M.I. (DH)'    '20' 'ROW_PER_6' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix (DH)'   '4' 'ROW_PER_6' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'BirthDateDH'  'DOB (DH)'          'ROW_PER_6' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'SexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_6' }
            )}
            @{ id = 'ROW_PER_7'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCIC_Input';    node = Inp 'NCICNumber'             'NCIC Number'        '10' 'ROW_PER_7' }
                @{ id = 'RaceCode_Input';node = Sel 'RaceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_7' }
                @{ id = 'RelHit_Input';  node = Inp 'RelatedHitSearchIndicator' 'Related Hit'     '1'  'ROW_PER_7' }
            )}
            @{ id = 'ROW_PER_8'; cols = @('2','2','2','3','3'); fields = @(
                @{ id = 'Age_Input';    node = Inp 'Age'    'Age'    '2' 'ROW_PER_8' }
                @{ id = 'Height_Input'; node = Inp 'Height' 'Height' '3' 'ROW_PER_8' }
                @{ id = 'Weight_Input'; node = Inp 'Weight' 'Weight' '3' 'ROW_PER_8' }
                @{ id = 'Eye_Input';    node = Sel 'EyeColorCode'  'Eye Color'  @{ codeTypeCategory = 'NCIC_EYE_COLOR';  codeTypeSource = 'NCIC' } 'ROW_PER_8' }
                @{ id = 'Hair_Input';   node = Sel 'HairColorCode' 'Hair Color' @{ codeTypeCategory = 'NCIC_HAIR_COLOR'; codeTypeSource = 'NCIC' } 'ROW_PER_8' }
            )}
            @{ id = 'ROW_PER_9'; cols = @('4','4','4'); fields = @(
                @{ id = 'ExpandName_Input'; node = Inp 'ExpandedNameSearchCode'      'Exp Name Search' '1' 'ROW_PER_9' }
                @{ id = 'ExpandDOB_Input';  node = Inp 'ExpandedBirthDateSearchCode' 'Exp DOB Search'  '1' 'ROW_PER_9' }
                @{ id = 'AreaCode_Input';   node = Inp 'AreaCode'                    'Area Code'       '3' 'ROW_PER_9' }
            )}
            @{ id = 'ROW_PER_10'; cols = @('6'); fields = @(
                @{ id = 'FormORI_Input'; node = Inp 'FormORI' 'Form ORI' '9' 'ROW_PER_10' }
            )}
            @{ id = 'ROW_PER_STATE_DH'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'StateDH_Input'; node = InpH 'StateDH' 'State (DH)' @{ initialValue = 'AZ' } 'ROW_PER_STATE_DH' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL + DH + Wanted + Missing on single card.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# FIREARM -- 1 card (ACQG)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_FA'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_FA_1'; cols = @('12'); fields = @(
                @{ id = 'Serial_FA_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '11' 'ROW_FA_1' }
            )}
            @{ id = 'ROW_FA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_FA'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_FA_BADGE' }
            )}
            @{ id = 'ROW_FA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'Make_FA_Input';   node = Sel 'GunMake'    'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_FA_2' }
                @{ id = 'Model_FA_Input';  node = Inp 'GunModel'   'Model'   '11' 'ROW_FA_2' }
                @{ id = 'Cal_FA_Input';    node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_FA_2' }
            )}
            @{ id = 'ROW_FA_3'; cols = @('4'); fields = @(
                @{ id = 'RelHit_FA_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_FA_3' }
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

# ARTICLE -- 1 card (ACQA)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('5','7'); fields = @(
                @{ id = 'Type_ART_Input';   node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'Serial_ART_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '11' 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_ART'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_ART_BADGE' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4'); fields = @(
                @{ id = 'RelHit_ART_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_ART_2' }
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

# BOAT -- 1 card
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'Reg_BOA_Input';   node = Inp 'RegistrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'State_BOA_Input'; node = Sel 'RegistrationState'  'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_BOA'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_BOA_BADGE' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('8','4'); fields = @(
                @{ id = 'Hull_BOA_Input';   node = Inp 'BoatHullIdNumber'          'Hull ID Number'  '20' 'ROW_BOA_2' }
                @{ id = 'RelHit_BOA_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y)'  '1' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- ACQB/ACQBH (Badge) and BQ/BQH (no Badge) on single card.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Vehicle','Person','Firearm','Article','Boat')
        CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
        FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE, with AZ patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
if (-not $rmsBundle) {
    $rmsBundle = $hidle.bundles | Where-Object { $_.name -notin @('AZ_AZDPS','ENTITIES') } | Select-Object -First 1
}

$providerConfigs = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhistQuery, $gunQuery, $artQuery, $boatQuery, $wantedQuery, $missingQuery)
$entityConfigs   = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

$final = [PSCustomObject]@{
    bundles = @(
        [PSCustomObject]@{
            name           = 'ENTITIES'
            type           = 'BUNDLE'
            order          = [PSCustomObject]@{
                default         = @('Vehicle','Person','Firearm','Article','Boat')
                CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
                FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
            }
            configurations = $entityConfigs
            provider       = 'MARK43'
        }
        [PSCustomObject]@{
            name           = 'AZ_AZDPS'
            type           = 'BUNDLE'
            description    = "Provider configuration for AZ_AZDPS v${Version}"
            configurations = $providerConfigs
            provider       = 'AZ_AZDPS'
        }
        $rmsBundle
    )
}

# RMS PATCHES

# PATCH 1: Remove LicensePlateYear from RMS Vehicle combination any[] (no elastic mapping)
$rmsVehicleQidm = $final.bundles | Where-Object { $_.name -eq 'RMS' } |
    ForEach-Object { $_.configurations } |
    Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Vehicle' } |
    Select-Object -First 1
if ($rmsVehicleQidm) {
    foreach ($combo in $rmsVehicleQidm.combinations) {
        if ($combo.requirements.any) {
            $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'LicensePlateYear' })
        }
    }
}

# PATCH 2: autoSelect=true on all RMS QIDMs
$rmsBundleRef = $final.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
foreach ($cfg in $rmsBundleRef.configurations) {
    if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') {
        $cfg | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
    }
}

# PATCH 3: add registrationState attr to RMS Person QIDM + RegistrationState to all person combo any[]
$rmsPersonQidm = $rmsBundleRef.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'registrationState'
    sourceField    = @('RegistrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'RegistrationState'
}

# =====================================================================
# PATCH 6: RMS CLEANUP -- remove unused HIDLE fields
# Vehicle: OOS dual-field plate, Owner search
# Person: OOS-suffixed attrs + combos (no OOS fieldIds on AZ form)
# NOTE: keep socialSecurityNumber (AZ uses SSN on DL form)
# =====================================================================
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehicleQidm.attributes = @($rmsVehicleQidm.attributes | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehicleQidm.combinations = @($rmsVehicleQidm.combinations | Where-Object {
    $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName')
})
foreach ($combo in $rmsVehicleQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

$deadPerAttrs = @('firstNameOOS','lastNameOOS','dateOfBirthOOS','licenseNumberOOS','sexOOS')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS',
        'firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

# =====================================================================
# OUTPUT
# =====================================================================
$json = $final | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $final | ConvertTo-Json -Depth 100

# Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)
$json = $json -replace 'LicensePlateNumberIn', 'licensePlateNumber'
$jsonReadable = $jsonReadable -replace 'LicensePlateNumberIn', 'licensePlateNumber'

$OUTREADABLE = "$DIR\AZ_AZDPS_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         (New-Object System.Text.UTF8Encoding $false))

Write-Host "Built AZ_AZDPS_BASE.json v${Version}" -ForegroundColor Green
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
# =====================================================================
Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green
