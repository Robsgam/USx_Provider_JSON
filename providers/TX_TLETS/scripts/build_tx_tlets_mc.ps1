# build_tx_tlets_mc.ps1  -- TX_TLETS v2.5 MC
# Multi-card layout. QIDMs identical to BASE. Layout-only changes.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tx_tlets_mc.ps1
#
# MC Card Grouping:
#   Vehicle: OPTIONS (State, RegionId, FRT, Sticker) + PLATE (Plate, PlateType, Year) + VIN (VIN, Make, Year)
#   Person:  OPTIONS (State, Image, Race, ExpandedDOB, RegionId, PurposeCode(DL))
#            + DL OLN (OLN, ReasonCode) + DL NAME (Name, DOB, Sex)
#            + DH OLN (OLN-DH, ReasonCode-DH) + DH NAME (Name-DH, DOB-DH, Sex-DH) + DH OPTIONS (PurposeCode-DH)
#   Firearm: same as BASE (single card)
#   Article: same as BASE (single card)
#   Boat:    OPTIONS (State, Image, RelatedHitSearch) + REGISTRATION (RegNumber) + HULL/NCIC (Hull, NCICNumber)

param(
    [string]$Version = "2.5",
    [string]$Phase   = "mc"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\TX_TLETS_MC.json"
$VEROUT   = "$PHASEDIR\TX_TLETS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS (identical to BASE)
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

function Sel($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $false @() $parentId
}

function Dt($fid, $lbl, $parentId) {
    N 'FormDate' 'Date' @{ fieldId = $fid; label = $lbl } $false $false @() $parentId
}

function BuildMultiCardLayout($cardDefs) {
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
    $def = BuildMultiCardLayout $cardDefs
    $cad = AddCadNodes $def
    $fr  = AddFrNodes $def
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# BUNDLE 1: TX_TLETS PROVIDER (QIDMs identical to BASE)
# =====================================================================

$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');     targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic'); targetField = 'Mnemonic' }
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
    description                = 'Authentication configuration for TX TLETS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'TX_TLETS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'TX_TLETS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

$results = Build-CommsysQrdm -ProviderName 'TX_TLETS'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'TX_TLETS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'TX_TLETS'
}

# QIDMs identical to BASE -- copied verbatim
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'FinancialResponsibilityType'; size = 1;  sourceField = @('FinancialResponsibilityType'); targetField = 'FinancialResponsibilityType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RegionId';                    size = 4;  sourceField = @('RegionId');                    targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'StickerNumber';               size = 10; sourceField = @('StickerNumber');               targetField = 'StickerNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','FinancialResponsibilityType'); any = @('registrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'REGLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode'); any = @('registrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','FinancialResponsibilityType'); any = @('registrationState') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'VINVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('StickerNumber'); any = @('registrationState') }; primaryFieldReference = 'StickerNumber'; keyReference = 'DPSIStickerNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('RegionId','registrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QVLicensePlateNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('registrationState','vehicleMakeCode','vehicleYear') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQVehicleIdentificationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('RegionId') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QVVehicleIdentificationNumber'; state = 'In/Out' }
    )
    description = 'VehicleInsuranceRegistrationQuery -- 7 combos.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_VehicleInsuranceRegistrationQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('VehicleStolenQuery'); provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'VehicleInsuranceRegistrationQuery'; queryLabel = 'Vehicle Registration'; targetEntity = 'Vehicle'
}

# VehicleStolenQuery -- 2 combos (QV plate, QV VIN). Mutual exclusion with VehReg.
$vehStolenQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber'; size = 10; sourceField = @('licensePlateNumber'); targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'RegionId'; size = 4; sourceField = @('RegionId'); targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('RegionId','registrationState') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QV.P'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('RegionId') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QV.V'; state = 'In/Out' }
    )
    description = 'VehicleStolenQuery -- QV.P (plate), QV.V (VIN). NCIC stolen vehicle check.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_VehicleStolenQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $false; queriesToDeselect = @('VehicleInsuranceRegistrationQuery'); provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'VehicleStolenQuery'; queryLabel = 'Vehicle Stolen'; targetEntity = 'Vehicle'
}

$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('birthDate'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('ExpandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('RaceCode'); targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('ReasonCode'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'RegionId'; size = 4; sourceField = @('RegionId'); targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('imageIndicator','nameMiddle','nameSuffix','ReasonCode','registrationState') }; primaryFieldReference = 'Name'; keyReference = 'DQName'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('ExpandedBirthDateSearchCode','nameMiddle','nameSuffix','RaceCode','RegionId','sexCode') }; primaryFieldReference = 'Name'; keyReference = 'QWName'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator','ReasonCode','registrationState') }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQOperatorLicenseNumber'; state = 'In/Out' }
    )
    description = 'DriverLicenseQuery -- 3 combos. autoSelect+queriesToDeselect.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverLicenseQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverHistoryQuery'); provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverLicenseQuery'; queryLabel = 'Driver License'; targetEntity = 'Person'
}

$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }; size = 30; sourceField = @('attention'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'EmailAddress'; size = 80; sourceField = @('emailAddress'); targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }; size = 30; sourceField = @('nameLastDH','nameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 1; sourceField = @('ReasonCodeDH'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @('imageIndicator','NameMiddleDH','NameSuffixDH','purposeCodeDH','ReasonCodeDH','registrationState') }; primaryFieldReference = 'Name'; keyReference = 'KQName'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('imageIndicator','purposeCodeDH','ReasonCodeDH','registrationState') }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQOperatorLicenseNumber'; state = 'In/Out' }
    )
    description = 'DriverHistoryQuery -- 2 combos. DH-suffix fields. Attention handler-only.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_DriverHistoryQuery'; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true; queriesToDeselect = @('DriverLicenseQuery'); provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'DriverHistoryQuery'; queryLabel = 'Driver History'; targetEntity = 'Person'
}

$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber'; size = 4; sourceField = @('gunCaliber'); targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake'; size = 23; sourceField = @('gunMake'); targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('gunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('ncicNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @('gunCaliber','gunMake','imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'GunSerialNumber'; keyReference = 'QGGunSerialNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'NCICNumber'; keyReference = 'QGNCICNumber'; state = 'In/Out' }
    )
    description = 'GunQuery -- 2 combos.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_GunQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'GunQuery'; queryLabel = 'Firearm'; targetEntity = 'Firearm'
}

$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('articleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode'; size = 7; sourceField = @('articleTypeCode'); targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('ncicNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('articleSerialNumber','articleTypeCode'); any = @('imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'ArticleSerialNumber'; keyReference = 'QAArticleSerialNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'NCICNumber'; keyReference = 'QANCICNumber'; state = 'In/Out' }
    )
    description = 'ArticleSingleQuery -- 2 combos.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_ArticleSingleQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'ArticleSingleQuery'; queryLabel = 'Article'; targetEntity = 'Article'
}

$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber'; size = 20; sourceField = @('boatHullIdNumber'); targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('ncicNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 11; sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('registrationNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'BQRegistrationNumber'; state = 'Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('boatHullIdNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'BQBoatHullIdNumber'; state = 'Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'QBRegistrationNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QBBoatHullIdNumber'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }; primaryFieldReference = 'NCICNumber'; keyReference = 'QBNCICNumber'; state = 'In/Out' }
    )
    description = 'BoatQuery -- 5 combos.'; handlerFunction = 'CommsysTransactionRequestHandler'; name = 'TX_TLETS_BoatQuery'; type = 'QUERYINPUTDATAMAPPING'; provider = 'TX_TLETS'; providerType = 'Commsys'; query = 'BoatQuery'; queryLabel = 'Boat'; targetEntity = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $vehStolenQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for TX_TLETS v$Version MC"
    name           = 'TX_TLETS'
    type           = 'BUNDLE'
    provider       = 'TX_TLETS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC MULTI-CARD LAYOUTS
# =====================================================================

# Vehicle -- 3 cards: OPTIONS + PLATE SEARCH + VIN SEARCH
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';          node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_O1' }
                @{ id = 'RegionId_Input';                   node = Inp 'RegionId' 'Region ID' '4' 'ROW_VEH_O1' }
                @{ id = 'FinancialResponsibilityType_Input'; node = Inp 'FinancialResponsibilityType' 'Financial Resp Type' '1' 'ROW_VEH_O1' }
            )}
            @{ id = 'ROW_VEH_O2'; cols = @('6'); fields = @(
                @{ id = 'StickerNumber_Input'; node = Inp 'StickerNumber' 'Sticker Number (DPSI)' '10' 'ROW_VEH_O2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_P1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_P1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_P1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_P1' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_V1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_V1' }
            )}
            @{ id = 'ROW_VEH_V2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_V2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_V2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS + PLATE SEARCH + VIN SEARCH. VehReg + VehStolen.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 6 cards: OPTIONS + DL OLN + DL NAME + DH OLN + DH NAME + DH OPTIONS
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_O1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_O1' }
                @{ id = 'RaceCode_Input';          node = Sel 'RaceCode' 'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_O1' }
            )}
            @{ id = 'ROW_PER_O2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ExpandedBirthDateSearchCode_Input'; node = Inp 'ExpandedBirthDateSearchCode' 'Expanded DOB Search' '1' 'ROW_PER_O2' }
                @{ id = 'RegionId_Input';                    node = Inp 'RegionId' 'Region ID' '4' 'ROW_PER_O2' }
                @{ id = 'PurposeCode_Input';                 node = Inp 'purposeCode' 'Purpose Code (DL)' '1' 'ROW_PER_O2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'DL - LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_PER_L1'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number (DL)' '20' 'ROW_PER_L1' }
                @{ id = 'ReasonCode_Input';            node = Inp 'ReasonCode' 'Reason Code' '1' 'ROW_PER_L1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'DL - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_N1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameLast_Input';   node = Inp 'nameLast'   'Last Name'   '30' 'ROW_PER_N1' }
                @{ id = 'NameFirst_Input';  node = Inp 'nameFirst'  'First Name'  '30' 'ROW_PER_N1' }
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_N1' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '30' 'ROW_PER_N1' }
            )}
            @{ id = 'ROW_PER_N2'; cols = @('4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_N2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_N2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DH - LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_PER_DHL1'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DHL1' }
                @{ id = 'ReasonCodeDH_Input';            node = Inp 'ReasonCodeDH' 'Reason Code (DH)' '1' 'ROW_PER_DHL1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_NAME'
        title = 'DH - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DHN1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameLastDH_Input';   node = Inp 'nameLastDH'   'Last Name (DH)'   '30' 'ROW_PER_DHN1' }
                @{ id = 'NameFirstDH_Input';  node = Inp 'nameFirstDH'  'First Name (DH)'  '30' 'ROW_PER_DHN1' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'Middle Name (DH)' '30' 'ROW_PER_DHN1' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix (DH)'      '30' 'ROW_PER_DHN1' }
            )}
            @{ id = 'ROW_PER_DHN2'; cols = @('4','4'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_DHN2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DHN2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OPT'
        title = 'DH - OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_DHO1'; cols = @('6'); fields = @(
                @{ id = 'PurposeCodeDH_Input'; node = Inp 'purposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_DHO1' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS + DL (OLN/NAME) + DH (OLN/NAME/OPTIONS). DH-suffix fields.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- same as BASE (single card)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'gunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'NCICNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('6'); fields = @(
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_3' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{ description = 'Firearm query -- QG (Serial/NCIC).'; label = 'Firearm'; layout = $faLayout; name = 'ENTITY_Firearm'; type = 'QUERYINPUTFORM'; targetEntity = 'Firearm' }

# Article -- same as BASE (single card)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_ART_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{ description = 'Article query -- QA (Serial+Type / NCIC).'; label = 'Article'; layout = $artLayout; name = 'ENTITY_Article'; type = 'QUERYINPUTFORM'; targetEntity = 'Article' }

# Boat -- 3 cards: OPTIONS + REGISTRATION + HULL/NCIC
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_BOA_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_O1' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_O1' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_R1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '11' 'ROW_BOA_R1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL / NCIC'
        rows  = @(
            @{ id = 'ROW_BOA_H1'; cols = @('6','6'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_H1' }
                @{ id = 'NCICNumber_Input';       node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_BOA_H1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{ description = 'Boat queries -- MC: OPTIONS + REGISTRATION + HULL/NCIC.'; label = 'Boat'; layout = $boaLayout; name = 'ENTITY_Boat'; type = 'QUERYINPUTFORM'; targetEntity = 'Boat' }

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations -- MC variant (5 QIFs, multi-card, DH-suffix)'
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
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{ bundles = @($entitiesBundle, $provBundle, $rmsBundle) }

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100

$OUTREADABLE = "$DIR\TX_TLETS_MC_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built TX_TLETS_MC.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

$VALIDATOR = (Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1").Path
if (Test-Path $VALIDATOR) {
    Write-Host ""
    Write-Host "Running structural validation..." -ForegroundColor Cyan
    powershell.exe -ExecutionPolicy Bypass -File $VALIDATOR -Path $OUT
    Write-Host "Validation complete." -ForegroundColor Green
} else {
    Write-Host "Validator not found at $VALIDATOR -- skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."
