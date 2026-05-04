# build_codetype_test.ps1
# Generates CODETYPE_TEST.json — a test form with all known codeType
# dropdown combinations for validating which picklists populate on a given instance.
#
# Usage: .\build_codetype_test.ps1 [-Provider <name>] [-OutputPath <path>]
#        Import the output JSON and open the Vehicle query form to see which dropdowns populate.

param(
    [string]$Provider = "CODETYPE_TEST",
    [string]$OutputPath = "$PSScriptRoot\..\templates\CODETYPE_TEST.json"
)

$ErrorActionPreference = 'Stop'

# ============================================================
# TEST FIELD DEFINITIONS
# ============================================================
# Each field becomes a FormSelect dropdown on the test form.
# Group by card. Two approaches tested per attribute:
#   1. codeTypeCategory + codeTypeSource (code type system)
#   2. attributeTypeId + optional codeTypeProvider (attribute system)

$cardDefs = [ordered]@{
    STATE = @{
        title = "STATE CODE TYPES"
        fields = @(
            @{ id="ST01"; label="NJ_NIBRS_STATE / NJ_NIBRS"; codeTypeCategory="NJ_NIBRS_STATE"; codeTypeSource="NJ_NIBRS" }
            @{ id="ST02"; label="NJ_NIBRS_STATE / NCIC"; codeTypeCategory="NJ_NIBRS_STATE"; codeTypeSource="NCIC" }
            @{ id="ST03"; label="NJ_NIBRS_STATE / NIBRS"; codeTypeCategory="NJ_NIBRS_STATE"; codeTypeSource="NIBRS" }
            @{ id="ST04"; label="STATE / NCIC (cat)"; codeTypeCategory="STATE"; codeTypeSource="NCIC" }
            @{ id="ST05"; label="STATE / NIBRS (cat)"; codeTypeCategory="STATE"; codeTypeSource="NIBRS" }
            @{ id="ST06"; label="STATE / NJ_NIBRS (cat)"; codeTypeCategory="STATE"; codeTypeSource="NJ_NIBRS" }
            @{ id="ST07"; label="attrType=STATE (no provider)"; attributeTypeId="STATE" }
            @{ id="ST08"; label="attrType=STATE + provider=NCIC"; attributeTypeId="STATE"; codeTypeProvider="NCIC" }
            @{ id="ST09"; label="attrType=STATE + provider=NIBRS"; attributeTypeId="STATE"; codeTypeProvider="NIBRS" }
            @{ id="ST10"; label="attrType=STATE + provider=NJ_NIBRS"; attributeTypeId="STATE"; codeTypeProvider="NJ_NIBRS" }
        )
    }
    SEX = @{
        title = "SEX CODE TYPES"
        fields = @(
            @{ id="SX01"; label="NIBRS_SEX / NIBRS"; codeTypeCategory="NIBRS_SEX"; codeTypeSource="NIBRS" }
            @{ id="SX02"; label="NIBRS_SEX / NCIC"; codeTypeCategory="NIBRS_SEX"; codeTypeSource="NCIC" }
            @{ id="SX03"; label="SEX / NIBRS (cat)"; codeTypeCategory="SEX"; codeTypeSource="NIBRS" }
            @{ id="SX04"; label="SEX / NCIC (cat)"; codeTypeCategory="SEX"; codeTypeSource="NCIC" }
            @{ id="SX05"; label="attrType=SEX (no provider)"; attributeTypeId="SEX" }
            @{ id="SX06"; label="attrType=SEX + provider=NIBRS"; attributeTypeId="SEX"; codeTypeProvider="NIBRS" }
            @{ id="SX07"; label="attrType=SEX + provider=NCIC"; attributeTypeId="SEX"; codeTypeProvider="NCIC" }
        )
    }
    RACE = @{
        title = "RACE CODE TYPES"
        fields = @(
            @{ id="RC01"; label="NIBRS_RACE / NIBRS"; codeTypeCategory="NIBRS_RACE"; codeTypeSource="NIBRS" }
            @{ id="RC02"; label="NIBRS_RACE / NCIC"; codeTypeCategory="NIBRS_RACE"; codeTypeSource="NCIC" }
            @{ id="RC03"; label="NIBRS_RACE / NJ_NIBRS"; codeTypeCategory="NIBRS_RACE"; codeTypeSource="NJ_NIBRS" }
            @{ id="RC04"; label="RACE / NCIC (cat)"; codeTypeCategory="RACE"; codeTypeSource="NCIC" }
            @{ id="RC05"; label="RACE / NIBRS (cat)"; codeTypeCategory="RACE"; codeTypeSource="NIBRS" }
            @{ id="RC06"; label="attrType=RACE (no provider)"; attributeTypeId="RACE" }
            @{ id="RC07"; label="attrType=RACE + provider=NCIC"; attributeTypeId="RACE"; codeTypeProvider="NCIC" }
        )
    }
    APPEARANCE = @{
        title = "EYE / HAIR / ITEM COLOR"
        fields = @(
            @{ id="AP01"; label="attrType=EYE_COLOR"; attributeTypeId="EYE_COLOR" }
            @{ id="AP02"; label="EYE_COLOR / NCIC (cat)"; codeTypeCategory="EYE_COLOR"; codeTypeSource="NCIC" }
            @{ id="AP03"; label="EYE_COLOR / NIBRS (cat)"; codeTypeCategory="EYE_COLOR"; codeTypeSource="NIBRS" }
            @{ id="AP04"; label="attrType=HAIR_COLOR"; attributeTypeId="HAIR_COLOR" }
            @{ id="AP05"; label="HAIR_COLOR / NCIC (cat)"; codeTypeCategory="HAIR_COLOR"; codeTypeSource="NCIC" }
            @{ id="AP06"; label="HAIR_COLOR / NIBRS (cat)"; codeTypeCategory="HAIR_COLOR"; codeTypeSource="NIBRS" }
            @{ id="AP07"; label="attrType=ITEM_COLOR"; attributeTypeId="ITEM_COLOR" }
            @{ id="AP08"; label="ITEM_COLOR / NCIC (cat)"; codeTypeCategory="ITEM_COLOR"; codeTypeSource="NCIC" }
            @{ id="AP09"; label="ITEM_COLOR / NIBRS (cat)"; codeTypeCategory="ITEM_COLOR"; codeTypeSource="NIBRS" }
        )
    }
    VEHICLE = @{
        title = "VEHICLE CODE TYPES"
        fields = @(
            @{ id="VH01"; label="NCIC_LICENSE_PLATE_TYPE / NCIC"; codeTypeCategory="NCIC_LICENSE_PLATE_TYPE"; codeTypeSource="NCIC" }
            @{ id="VH02"; label="NCIC_LICENSE_PLATE_TYPE / NJ_NIBRS"; codeTypeCategory="NCIC_LICENSE_PLATE_TYPE"; codeTypeSource="NJ_NIBRS" }
            @{ id="VH03"; label="VEHICLE_BODY_STYLE / NJ_NIBRS"; codeTypeCategory="VEHICLE_BODY_STYLE"; codeTypeSource="NJ_NIBRS" }
            @{ id="VH04"; label="VEHICLE_BODY_STYLE / NCIC"; codeTypeCategory="VEHICLE_BODY_STYLE"; codeTypeSource="NCIC" }
            @{ id="VH05"; label="VEHICLE_TYPE / HI_NIBRS"; codeTypeCategory="VEHICLE_TYPE"; codeTypeSource="HI_NIBRS" }
            @{ id="VH06"; label="VEHICLE_TYPE / NCIC"; codeTypeCategory="VEHICLE_TYPE"; codeTypeSource="NCIC" }
            @{ id="VH07"; label="VEHICLE_TYPE / NJ_NIBRS"; codeTypeCategory="VEHICLE_TYPE"; codeTypeSource="NJ_NIBRS" }
            @{ id="VH08"; label="attrType=VEHICLE_MAKE"; attributeTypeId="VEHICLE_MAKE" }
            @{ id="VH09"; label="attrType=VEHICLE_MODEL"; attributeTypeId="VEHICLE_MODEL" }
        )
    }
    FA_MISC = @{
        title = "FIREARM / ARTICLE / MISC"
        fields = @(
            @{ id="FA01"; label="NCIC_FIREARM_MAKE / NCIC"; codeTypeCategory="NCIC_FIREARM_MAKE"; codeTypeSource="NCIC" }
            @{ id="FA02"; label="NCIC_FIREARM_MAKE / NJ_NIBRS"; codeTypeCategory="NCIC_FIREARM_MAKE"; codeTypeSource="NJ_NIBRS" }
            @{ id="FA03"; label="NCIC_FIREARM_CALIBER / NCIC"; codeTypeCategory="NCIC_FIREARM_CALIBER"; codeTypeSource="NCIC" }
            @{ id="FA04"; label="NCIC_FIREARM_CALIBER / NJ_NIBRS"; codeTypeCategory="NCIC_FIREARM_CALIBER"; codeTypeSource="NJ_NIBRS" }
            @{ id="FA05"; label="NCIC_FIREARM_TYPE / NCIC"; codeTypeCategory="NCIC_FIREARM_TYPE"; codeTypeSource="NCIC" }
            @{ id="FA06"; label="NCIC_FIREARM_TYPE / NJ_NIBRS"; codeTypeCategory="NCIC_FIREARM_TYPE"; codeTypeSource="NJ_NIBRS" }
            @{ id="FA07"; label="NCIC_ARTICLE_TYPE / CA_CLETS"; codeTypeCategory="NCIC_ARTICLE_TYPE"; codeTypeSource="CA_CLETS" }
            @{ id="FA08"; label="NCIC_ARTICLE_TYPE / NCIC"; codeTypeCategory="NCIC_ARTICLE_TYPE"; codeTypeSource="NCIC" }
            @{ id="FA09"; label="YES_NO_UNKNOWN / NIBRS"; codeTypeCategory="YES_NO_UNKNOWN"; codeTypeSource="NIBRS" }
            @{ id="FA10"; label="YES_NO_UNKNOWN / NCIC"; codeTypeCategory="YES_NO_UNKNOWN"; codeTypeSource="NCIC" }
        )
    }
}

# ============================================================
# HELPER: build a Craft.js node
# ============================================================
function New-Node {
    param(
        [string]$ResolvedName,
        [string]$DisplayName,
        [hashtable]$Props = @{},
        [bool]$IsCanvas = $false,
        [string[]]$ChildNodes = @(),
        [string]$Parent = $null
    )
    $node = [ordered]@{
        type        = [ordered]@{ resolvedName = $ResolvedName }
        displayName = $DisplayName
        props       = $Props
        isCanvas    = $IsCanvas
        hidden      = $false
        nodes       = $ChildNodes
        linkedNodes = [ordered]@{}
    }
    if ($Parent) { $node.parent = $Parent }
    return $node
}

# ============================================================
# BUILD LAYOUT
# ============================================================
function Build-Layout {
    $nodes = [ordered]@{}
    $cardIds = @()

    foreach ($cardName in $cardDefs.Keys) {
        $card = $cardDefs[$cardName]
        $cardId = "CARD_$cardName"
        $cardIds += $cardId
        $rowIds = @()
        $fields = $card.fields

        for ($i = 0; $i -lt $fields.Count; $i += 2) {
            $rowIdx = [Math]::Floor($i / 2)
            $rowId = "ROW_${cardName}_${rowIdx}"
            $rowIds += $rowId
            $fieldIds = @()

            # Process up to 2 fields per row
            $fieldsInRow = @($fields[$i])
            if ($i + 1 -lt $fields.Count) { $fieldsInRow += $fields[$i + 1] }

            $cols = @()
            foreach ($f in $fieldsInRow) {
                $fieldId = "FIELD_$($f.id)"
                $fieldIds += $fieldId
                $cols += "6"

                # Build props for this FormSelect
                $fProps = [ordered]@{
                    fieldId = $f.id
                    label   = $f.label
                }
                if ($f.codeTypeCategory) { $fProps.codeTypeCategory = $f.codeTypeCategory }
                if ($f.codeTypeSource)   { $fProps.codeTypeSource   = $f.codeTypeSource }
                if ($f.attributeTypeId)  { $fProps.attributeTypeId  = $f.attributeTypeId }
                if ($f.codeTypeProvider) { $fProps.codeTypeProvider = $f.codeTypeProvider }

                $nodes[$fieldId] = New-Node -ResolvedName "FormSelect" -DisplayName "Select" `
                    -Props $fProps -IsCanvas $false -ChildNodes @() -Parent $rowId
            }

            # PS 5.1: force single-element array
            if ($cols.Count -eq 1) { $cols = @(,$cols[0]) }
            if ($fieldIds.Count -eq 1) { $fieldIds = @(,$fieldIds[0]) }

            $nodes[$rowId] = New-Node -ResolvedName "Row" -DisplayName "Row" `
                -Props ([ordered]@{ templateColumns = $cols }) `
                -IsCanvas $true -ChildNodes $fieldIds -Parent $cardId
        }

        # PS 5.1: force single-element array
        if ($rowIds.Count -eq 1) { $rowIds = @(,$rowIds[0]) }

        $nodes[$cardId] = New-Node -ResolvedName "Card" -DisplayName "Card" `
            -Props ([ordered]@{ title = $card.title }) `
            -IsCanvas $true -ChildNodes $rowIds -Parent "ROOT_PAGE"
    }

    # PS 5.1: force array
    if ($cardIds.Count -eq 1) { $cardIds = @(,$cardIds[0]) }

    # Scaffold nodes
    $nodes["ROOT_PAGE"] = New-Node -ResolvedName "Page" -DisplayName "Page" `
        -Props ([ordered]@{ title = "Page 1" }) `
        -IsCanvas $true -ChildNodes $cardIds -Parent "FORM_ROOT"

    $nodes["FORM_ROOT"] = New-Node -ResolvedName "Form" -DisplayName "Form" `
        -Props ([ordered]@{ hidePageItems = $true; layout = "page" }) `
        -IsCanvas $true -ChildNodes @("ROOT_PAGE") -Parent "ROOT"

    $nodes["ROOT"] = New-Node -ResolvedName "Root" -DisplayName "Root" `
        -Props ([ordered]@{}) -IsCanvas $false -ChildNodes @("FORM_ROOT")

    # Insert ROOT at the beginning (move to front of ordered dict)
    $ordered = [ordered]@{}
    $ordered["ROOT"] = $nodes["ROOT"]
    $ordered["FORM_ROOT"] = $nodes["FORM_ROOT"]
    $ordered["ROOT_PAGE"] = $nodes["ROOT_PAGE"]
    foreach ($k in $nodes.Keys) {
        if ($k -notin @("ROOT","FORM_ROOT","ROOT_PAGE")) {
            $ordered[$k] = $nodes[$k]
        }
    }
    return $ordered
}

# ============================================================
# BUILD JSON STRUCTURE
# ============================================================
Write-Host "Building CODETYPE_TEST for provider: $Provider" -ForegroundColor Cyan

$layout = Build-Layout

# Count total fields
$totalFields = 0
foreach ($c in $cardDefs.Values) { $totalFields += $c.fields.Count }
Write-Host "  $($cardDefs.Count) cards, $totalFields dropdown fields" -ForegroundColor Gray

# Collect all fieldIds for QIDM combination
$allFieldIds = @()
foreach ($c in $cardDefs.Values) {
    foreach ($f in $c.fields) {
        $allFieldIds += $f.id
    }
}

# --- Bundle 1: PROVIDER (AUTH + dummy QIDM) ---
$authConfig = [ordered]@{
    attributes = @(
        [ordered]@{
            name = "ORI"
            size = 12
            sourceField = @("ORI")
            targetField = "ORI"
        }
        [ordered]@{
            name = "Mnemonic"
            size = 25
            sourceField = @("mnemonic")
            targetField = "Mnemonic"
        }
        [ordered]@{
            description = "dexUserStateid from RMS profile"
            name = "UserName"
            rule = [ordered]@{
                function = "CommsysGetDexStateUserIdRuleHandler"
                arguments = @("true")
            }
            sourceField = @("dexStateUserId")
            targetField = "UserName"
        }
    )
    combinations = @(
        [ordered]@{
            requirements = [ordered]@{
                set = @("ORI","Mnemonic")
                any = @("dexStateUserId")
            }
        }
    )
    description = "Authentication for $Provider code type test"
    handlerFunction = "CommsysOriAuthenticationHandler"
    name = $Provider
    type = "AUTHENTICATION"
    deviceRegistrationOptional = $false
    provider = $Provider
    providerType = "Commsys"
    signInRequired = $false
}

$qmfConfig = [ordered]@{
    description = "QMF for $Provider"
    handlerFunction = "CommsysWsiOutgoingMessageHandler"
    name = "${Provider}_MessageFormat"
    type = "QUERYMESSAGEFORMAT"
    provider = $Provider
    providerType = "Commsys"
}

# Minimal QIDM — just needs one combo so the form is queryable
$dummyQidm = [ordered]@{
    attributes = @(
        [ordered]@{
            name = "DummyField"
            sourceField = @("ST01")
            targetField = "DummyField"
        }
    )
    combinations = @(
        [ordered]@{
            requirements = [ordered]@{
                set = @("ST01")
                any = @()
            }
            primaryFieldReference = "DummyField"
            keyReference = "TEST"
            state = "In/Out"
        }
    )
    description = "Dummy QIDM for code type test form"
    handlerFunction = "CommsysTransactionRequestHandler"
    name = "${Provider}_VehicleRegistrationQuery"
    type = "QUERYINPUTDATAMAPPING"
    provider = $Provider
    providerType = "Commsys"
    query = "VehicleRegistrationQuery"
    queryLabel = "Code Type Test"
    targetEntity = "Vehicle"
}

$providerBundle = [ordered]@{
    configurations = @($authConfig, $qmfConfig, $dummyQidm)
    description = "Code Type Test Provider v1.0"
    name = $Provider
    type = "BUNDLE"
    provider = $Provider
}

# --- Bundle 2: ENTITIES (one QIF with all test dropdowns) ---
$qifConfig = [ordered]@{
    description = "Code type test form - all known codeTypeCategory/codeTypeSource and attributeTypeId combinations"
    label = "Code Type Test"
    layout = [ordered]@{
        default         = $layout
        CAD_DISPATCH    = $layout
        FIRST_RESPONDER = $layout
    }
    name = "${Provider}_CodeTypeTest"
    query = "VehicleRegistrationQuery"
    targetEntity = "Vehicle"
    type = "QUERYINPUTFORM"
}

$entitiesBundle = [ordered]@{
    configurations = @(
        $qifConfig,
        [ordered]@{
            description = "Entity display order"
            name = "order"
            type = "ENTITY_DISPLAY_ORDER"
            order = [ordered]@{
                default         = @("Vehicle")
                CAD_DISPATCH    = @("Vehicle")
                FIRST_RESPONDER = @("Vehicle")
            }
        }
    )
    description = "ENTITIES for $Provider code type test"
    name = "ENTITIES"
    type = "BUNDLE"
    provider = "MARK43"
}

# --- Assemble full JSON ---
$data = [ordered]@{
    bundles = @($providerBundle, $entitiesBundle)
}

# ============================================================
# SERIALIZE AND WRITE
# ============================================================
$json = $data | ConvertTo-Json -Depth 30

# Strip BOM if present
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)

$fileSize = (Get-Item $OutputPath).Length
$sizeKb = [Math]::Round($fileSize/1024, 1)
Write-Host "`nOutput: $OutputPath ($sizeKb KB)" -ForegroundColor Green
Write-Host "Provider: $Provider" -ForegroundColor Green
Write-Host "Cards: $($cardDefs.Count) | Fields: $totalFields" -ForegroundColor Green
Write-Host "`nTo use:" -ForegroundColor Yellow
Write-Host "  1. Change -Provider to match your target instance provider name" -ForegroundColor Gray
Write-Host "  2. Import the JSON" -ForegroundColor Gray
Write-Host "  3. Open the Vehicle query form" -ForegroundColor Gray
Write-Host "  4. Check which dropdowns populate and which are empty" -ForegroundColor Gray
Write-Host "  5. Record results per card per instance" -ForegroundColor Gray
