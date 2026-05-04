# build_az_azdps_basic.ps1
#
# Builds AZ_AZDPS.json from scratch.
# Sources of truth: AZ_AZDPS.xml (field names, sizes, combinations)
#                   NOPD.json (structural template, boilerplate, RMS bundle)
# No other JSON files consulted.
#
# Entities: Vehicle, Person, Firearm, Article, Boat
# CommSys queries:
#   Vehicle  -> VehicleRegistrationQuery  (ACVR -- plate + VIN)
#   Person   -> AzAzdpsDriverLicenseQuery (DQ -- OLN + Name + SSN; ACWL -- BadgeNumber path)
#   Firearm  -> GunQuery                  (ACQG -- serial)
#   Article  -> ArticleSingleQuery        (ACQA -- serial + type)
#   Boat     -> AzAzdpsBoatQuery          (ACQB -- reg + hull; BQ -- reg + hull + name)
#
# Output: AZ_AZDPS.json
# =============================================================================

$DIR      = "C:\Users\RobSgambellone\.local\bin\AZ_AZDPS"
$NOPDPATH = "C:\Users\RobSgambellone\.local\bin\Source jsons\NOPD.json"
$OUT      = "$DIR\AZ_AZDPS.json"

Write-Host ""
Write-Host "========================================"
Write-Host " AZ_AZDPS Basic Build"
Write-Host " Source 1: AZ_AZDPS.xml"
Write-Host " Source 2: NOPD.json (LA_LEMS template)"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path $NOPDPATH)) {
    Write-Host "ERROR: NOPD.json not found: $NOPDPATH" -ForegroundColor Red; exit 1
}

# =============================================================================
# Load NOPD as structural template
# =============================================================================
$nopd    = Get-Content $NOPDPATH -Raw | ConvertFrom-Json
$nopdLa  = $nopd.bundles | Where-Object { $_.name -eq "LA_LEMS" }
$nopdRms = $nopd.bundles | Where-Object { $_.name -eq "RMS" }
function DeepClone($obj) { $obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json }

# =============================================================================
# SECTION 1 -- CommSys boilerplate (cloned from NOPD, provider updated)
# =============================================================================

# Authentication -- ORI / Mnemonic / UserName (identical across CommSys providers)
$azAuth          = DeepClone($nopdLa.configurations | Where-Object { $_.type -eq "AUTHENTICATION" })
$azAuth.name     = "AZ_AZDPS"
$azAuth.provider = "AZ_AZDPS"

# QUERYRESULTDATAMAPPING -- standard CommSys result field mapping
$azQrdm          = DeepClone($nopdLa.configurations | Where-Object { $_.type -eq "QUERYRESULTDATAMAPPING" })
$azQrdm.name     = "AZ_AZDPS_Results"
$azQrdm.provider = "AZ_AZDPS"

# QUERYMESSAGEFORMAT -- CommSys WSI outgoing handler
$azMsgFmt          = DeepClone($nopdLa.configurations | Where-Object { $_.type -eq "QUERYMESSAGEFORMAT" })
$azMsgFmt.provider = "AZ_AZDPS"

Write-Host "Boilerplate: auth + QRDM + MessageFormat cloned from NOPD" -ForegroundColor Cyan

# =============================================================================
# SECTION 2 -- CommSys QIDMs (built directly from AZ_AZDPS.xml)
# =============================================================================

# Shared Attention attribute (auto-populated from user session in all CommSys QIDMs)
function New-AttentionAttr {
    [PSCustomObject]@{
        name        = "Attention"
        size        = 30
        rule        = [PSCustomObject]@{ function = "CommsysGetLastNameFirstNameInitialRuleHandler" }
        sourceField = @("Attention")
        targetField = "Attention"
    }
}

# ---- Vehicle: VehicleRegistrationQuery (v5) ----
# XML fields: BadgeNumber(4), LicensePlateNumber(10), LicensePlateTypeCode(2),
#             LicensePlateYear(4), VehicleIdentificationNumber(20),
#             VehicleMakeCode(4), VehicleYear(4), State(2)
# Combinations (keyRef=ACVR):
#   Plate: set=[BadgeNumber, LicensePlateNumber],         any=[LicensePlateYear, LicensePlateTypeCode, State]
#   VIN:   set=[BadgeNumber, VehicleIdentificationNumber], any=[VehicleMakeCode, VehicleYear, State]

$qidm_vehicle = [PSCustomObject]@{
    name            = "AZ_AZDPS_VehicleRegistrationQuery"
    type            = "QUERYINPUTDATAMAPPING"
    provider        = "AZ_AZDPS"
    providerType    = "Commsys"
    query           = "VehicleRegistrationQuery"
    queryLabel      = "AZ_AZDPS Vehicle"
    targetEntity    = "Vehicle"
    handlerFunction = "CommsysTransactionRequestHandler"
    description     = "Vehicle Registration Query -- AZ AZDPS (ACVR)"
    autoSelect      = $true
    attributes      = @(
        (New-AttentionAttr),
        [PSCustomObject]@{ name="BadgeNumber";               size=4;  sourceField=@("BadgeNumber");               targetField="BadgeNumber" },
        [PSCustomObject]@{ name="LicensePlateNumber";        size=10; sourceField=@("LicensePlateNumber");        targetField="LicensePlateNumber" },
        [PSCustomObject]@{ name="LicensePlateTypeCode";      size=2;  sourceField=@("LicensePlateTypeCode");      targetField="LicensePlateTypeCode" },
        [PSCustomObject]@{ name="LicensePlateYear";          size=4;  sourceField=@("LicensePlateYear");          targetField="LicensePlateYear" },
        [PSCustomObject]@{ name="State";                     size=2;  sourceField=@("RegistrationState");         targetField="State";  codeTypeProvider="NCIC" },
        [PSCustomObject]@{ name="VehicleIdentificationNumber"; size=20; sourceField=@("VehicleIdentificationNumber"); targetField="VehicleIdentificationNumber" },
        [PSCustomObject]@{ name="VehicleMakeCode";           size=4;  sourceField=@("VehicleMakeCode");           targetField="VehicleMakeCode" },
        [PSCustomObject]@{ name="VehicleYear";               size=4;  sourceField=@("VehicleYear");               targetField="VehicleYear" }
    )
    combinations    = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @("BadgeNumber","LicensePlateNumber"); any = @("Attention","LicensePlateYear","LicensePlateTypeCode","RegistrationState")
                conditions=$null; defaults=$null }
            primaryFieldReference = "LicensePlateNumber"
            keyReference          = "ACVR_Plate"
            state                 = "In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @("BadgeNumber","VehicleIdentificationNumber"); any = @("Attention","VehicleMakeCode","VehicleYear","RegistrationState")
                conditions=$null; defaults=$null }
            primaryFieldReference = "VehicleIdentificationNumber"
            keyReference          = "ACVR_VIN"
            state                 = "In/Out"
        }
    )
}
Write-Host "  QIDM Vehicle: VehicleRegistrationQuery (ACVR -- plate + VIN)" -ForegroundColor Green

# ---- Person: AzAzdpsDriverLicenseQuery (v3) ----
# XML fields: OperatorLicenseNumber(20), SocialSecurityNumber(9), BadgeNumber(4),
#             Name(30: Last,First,Middle,Suffix), BirthDate(8), SexCode(1), State(2)
# Combinations:
#   DQ/OLN:  set=[OperatorLicenseNumber],                      any=[State]
#   DQ/Name: set=[NameLast, NameFirst, SexCode, BirthDate],    any=[State]
#   DQ/SSN:  set=[SocialSecurityNumber],                       any=[]
#   ACWL:    set=[BadgeNumber, BirthDate, NameLast, NameFirst, SexCode], any=[OperatorLicenseNumber, State]

$qidm_person = [PSCustomObject]@{
    name            = "AZ_AZDPS_AzAzdpsDriverLicenseQuery"
    type            = "QUERYINPUTDATAMAPPING"
    provider        = "AZ_AZDPS"
    providerType    = "Commsys"
    query           = "DriverLicenseQuery"
    queryLabel      = "AZ_AZDPS Person"
    targetEntity    = "Person"
    handlerFunction = "CommsysTransactionRequestHandler"
    description     = "Driver License Query -- AZ AZDPS (DQ + ACWL)"
    autoSelect      = $true
    attributes      = @(
        (New-AttentionAttr),
        [PSCustomObject]@{ name="BadgeNumber";          size=4;  sourceField=@("BadgeNumber");          targetField="BadgeNumber" },
        [PSCustomObject]@{
            name="BirthDate"; size=8
            rule        = [PSCustomObject]@{ function="CommsysParseDateRuleHandler"; arguments=@("yyyy-MM-dd","yyyyMMdd") }
            sourceField = @("BirthDate"); targetField="BirthDate"
        },
        [PSCustomObject]@{ name="ImageIndicator";       size=1;  sourceField=@("ImageIndicator");       targetField="ImageIndicator" },
        [PSCustomObject]@{
            name="Name"; size=30
            rule        = [PSCustomObject]@{ function="FormatStringRuleHandler"; arguments=@(", "," "," ") }
            sourceField = @("NameLast","NameFirst","NameMiddle","NameSuffix"); targetField="Name"
        },
        [PSCustomObject]@{ name="OperatorLicenseNumber"; size=20; sourceField=@("OperatorLicenseNumber"); targetField="OperatorLicenseNumber" },
        [PSCustomObject]@{ name="SexCode"; size=1; sourceField=@("SexCode"); targetField="SexCode"; codeTypeProvider="NIBRS" },
        [PSCustomObject]@{ name="SocialSecurityNumber";  size=9;  sourceField=@("SocialSecurityNumber");  targetField="SocialSecurityNumber" },
        [PSCustomObject]@{ name="State";                 size=2;  sourceField=@("RegistrationState");     targetField="State"; codeTypeProvider="NCIC" }
    )
    combinations    = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("OperatorLicenseNumber"); any=@("RegistrationState","ImageIndicator","Attention"); conditions=$null; defaults=$null }
            primaryFieldReference = "OperatorLicenseNumber"
            keyReference          = "DQ_OLN"
            state                 = "In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BirthDate","NameLast","NameFirst","SexCode"); any=@("RegistrationState","Attention","ImageIndicator"); conditions=$null; defaults=$null }
            primaryFieldReference = "Name"
            keyReference          = "DQ_Name"
            state                 = "In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("SocialSecurityNumber"); any=@("RegistrationState","ImageIndicator","Attention"); conditions=$null; defaults=$null }
            primaryFieldReference = "SocialSecurityNumber"
            keyReference          = "DQ_SSN"
            state                 = "In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BadgeNumber","NameLast","NameFirst","SexCode","BirthDate"); any=@("RegistrationState","Attention","ImageIndicator"); conditions=$null; defaults=$null }
            primaryFieldReference = "Name"
            keyReference          = "ACWL"
            state                 = "In/Out"
        }
    )
}
Write-Host "  QIDM Person: AzAzdpsDriverLicenseQuery (DQ -- OLN + Name + SSN; ACWL -- BadgeNumber path)" -ForegroundColor Green

# ---- Firearm: GunQuery (v3) ----
# XML fields: BadgeNumber(4), GunSerialNumber(11), GunMake(4), GunModel(11),
#             GunCaliber(4), RelatedHitSearchIndicator(1)
# Combinations:
#   ACQG: set=[BadgeNumber, SerialNumber], any=[FirearmMake, FirearmModel, FirearmCaliber, RelatedHitSearchIndicator]

$qidm_firearm = [PSCustomObject]@{
    name            = "AZ_AZDPS_GunQuery"
    type            = "QUERYINPUTDATAMAPPING"
    provider        = "AZ_AZDPS"
    providerType    = "Commsys"
    query           = "GunQuery"
    queryLabel      = "AZ_AZDPS Firearm"
    targetEntity    = "Firearm"
    handlerFunction = "CommsysTransactionRequestHandler"
    description     = "Gun Query -- AZ AZDPS (ACQG)"
    autoSelect      = $true
    attributes      = @(
        (New-AttentionAttr),
        [PSCustomObject]@{ name="BadgeNumber";              size=4;  sourceField=@("BadgeNumber");    targetField="BadgeNumber" },
        [PSCustomObject]@{ name="GunCaliber";               size=4;  sourceField=@("FirearmCaliber"); targetField="GunCaliber" },
        [PSCustomObject]@{ name="GunMake";                  size=4;  sourceField=@("FirearmMake");    targetField="GunMake" },
        [PSCustomObject]@{ name="GunModel";                 size=11; sourceField=@("FirearmModel");   targetField="GunModel" },
        [PSCustomObject]@{ name="GunSerialNumber";          size=11; sourceField=@("SerialNumber");   targetField="GunSerialNumber" },
        [PSCustomObject]@{ name="RelatedHitSearchIndicator"; size=1; sourceField=@("RelatedHitSearchIndicator"); targetField="RelatedHitSearchIndicator" }
    )
    combinations    = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BadgeNumber","SerialNumber"); any=@("Attention","FirearmMake","FirearmModel","FirearmCaliber","RelatedHitSearchIndicator"); conditions=$null; defaults=$null }
            primaryFieldReference = "GunSerialNumber"
            keyReference          = "ACQG"
            state                 = "In/Out"
        }
    )
}
Write-Host "  QIDM Firearm: GunQuery (ACQG -- serial + optional make/model/caliber)" -ForegroundColor Green

# ---- Article: ArticleSingleQuery (v2) ----
# XML fields: BadgeNumber(4), ArticleTypeCode(7), ArticleSerialNumber(11), RelatedHitSearchIndicator(1)
# Combinations:
#   ACQA: set=[BadgeNumber, SerialNumber, ArticleTypeCode], any=[RelatedHitSearchIndicator]

$qidm_article = [PSCustomObject]@{
    name            = "AZ_AZDPS_ArticleSingleQuery"
    type            = "QUERYINPUTDATAMAPPING"
    provider        = "AZ_AZDPS"
    providerType    = "Commsys"
    query           = "ArticleSingleQuery"
    queryLabel      = "AZ_AZDPS Article"
    targetEntity    = "Article"
    handlerFunction = "CommsysTransactionRequestHandler"
    description     = "Article Single Query -- AZ AZDPS (ACQA)"
    autoSelect      = $true
    attributes      = @(
        (New-AttentionAttr),
        [PSCustomObject]@{ name="ArticleSerialNumber";       size=11; sourceField=@("SerialNumber");   targetField="ArticleSerialNumber" },
        [PSCustomObject]@{ name="ArticleTypeCode";           size=7;  sourceField=@("ArticleTypeCode");targetField="ArticleTypeCode" },
        [PSCustomObject]@{ name="BadgeNumber";               size=4;  sourceField=@("BadgeNumber");    targetField="BadgeNumber" },
        [PSCustomObject]@{ name="RelatedHitSearchIndicator"; size=1;  sourceField=@("RelatedHitSearchIndicator"); targetField="RelatedHitSearchIndicator" }
    )
    combinations    = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BadgeNumber","SerialNumber","ArticleTypeCode"); any=@("Attention","RelatedHitSearchIndicator"); conditions=$null; defaults=$null }
            primaryFieldReference = "ArticleSerialNumber"
            keyReference          = "ACQA"
            state                 = "In/Out"
        }
    )
}
Write-Host "  QIDM Article: ArticleSingleQuery (ACQA -- badge + serial + type)" -ForegroundColor Green

# ---- Boat: AzAzdpsBoatQuery (v2) ----
# XML fields: BadgeNumber(4), BirthDate(8), Name(30: First,Middle,Last,Suffix),
#             RegistrationNumber(8), BoatHullIdNumber(20), RelatedHitSearchIndicator(1), State(2)
# Combinations:
#   ACQB/Reg:  set=[BadgeNumber, RegistrationNumber],           any=[BoatHullIdNumber, RelatedHitSearchIndicator]
#   ACQB/Hull: set=[BadgeNumber, BoatHullIdNumber],             any=[RegistrationNumber, RelatedHitSearchIndicator]
#   BQ/Reg:    set=[RegistrationNumber],                        any=[BoatHullIdNumber, State]
#   BQ/Hull:   set=[BoatHullIdNumber],                          any=[RegistrationNumber, State]
#   BQ/Name:   set=[BirthDate, NameLast, NameFirst],            any=[State]

$qidm_boat = [PSCustomObject]@{
    name            = "AZ_AZDPS_AzAzdpsBoatQuery"
    type            = "QUERYINPUTDATAMAPPING"
    provider        = "AZ_AZDPS"
    providerType    = "Commsys"
    query           = "BoatQuery"
    queryLabel      = "AZ_AZDPS Boat"
    targetEntity    = "Boat"
    handlerFunction = "CommsysTransactionRequestHandler"
    description     = "Boat Query -- AZ AZDPS (ACQB + BQ)"
    autoSelect      = $true
    attributes      = @(
        (New-AttentionAttr),
        [PSCustomObject]@{ name="BadgeNumber";      size=4;  sourceField=@("BadgeNumber");      targetField="BadgeNumber" },
        [PSCustomObject]@{
            name="BirthDate"; size=8
            rule        = [PSCustomObject]@{ function="CommsysParseDateRuleHandler"; arguments=@("yyyy-MM-dd","yyyyMMdd") }
            sourceField = @("BirthDate"); targetField="BirthDate"
        },
        [PSCustomObject]@{ name="BoatHullIdNumber";  size=20; sourceField=@("BoatHullIdNumber"); targetField="BoatHullIdNumber" },
        [PSCustomObject]@{
            name="Name"; size=30
            rule        = [PSCustomObject]@{ function="FormatStringRuleHandler"; arguments=@(", "," "," ") }
            sourceField = @("NameLast","NameFirst","NameMiddle"); targetField="Name"
        },
        [PSCustomObject]@{ name="RegistrationNumber";        size=8;  sourceField=@("RegistrationNumber");        targetField="RegistrationNumber" },
        [PSCustomObject]@{ name="RelatedHitSearchIndicator"; size=1;  sourceField=@("RelatedHitSearchIndicator"); targetField="RelatedHitSearchIndicator" },
        [PSCustomObject]@{ name="State";                     size=2;  sourceField=@("RegistrationState");         targetField="State"; codeTypeProvider="NCIC" }
    )
    combinations    = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BadgeNumber","RegistrationNumber"); any=@("Attention","BoatHullIdNumber","RelatedHitSearchIndicator"); conditions=$null; defaults=$null }
            primaryFieldReference = "RegistrationNumber"; keyReference="ACQB_Reg"; state="In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BadgeNumber","BoatHullIdNumber"); any=@("Attention","RegistrationNumber","RelatedHitSearchIndicator"); conditions=$null; defaults=$null }
            primaryFieldReference = "BoatHullIdNumber"; keyReference="ACQB_Hull"; state="In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("RegistrationNumber"); any=@("Attention","BoatHullIdNumber","RegistrationState"); conditions=$null; defaults=$null }
            primaryFieldReference = "RegistrationNumber"; keyReference="BQ_Reg"; state="In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BoatHullIdNumber"); any=@("Attention","RegistrationNumber","RegistrationState"); conditions=$null; defaults=$null }
            primaryFieldReference = "BoatHullIdNumber"; keyReference="BQ_Hull"; state="In/Out"
        },
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set=@("BirthDate","NameLast","NameFirst"); any=@("Attention","RegistrationState"); conditions=$null; defaults=$null }
            primaryFieldReference = "Name"; keyReference="BQ_Name"; state="In/Out"
        }
    )
}
Write-Host "  QIDM Boat: AzAzdpsBoatQuery (ACQB -- reg/hull with badge; BQ -- reg/hull/name)" -ForegroundColor Green

# =============================================================================
# SECTION 3 -- ENTITIES QIFs (form layouts built from NOPD structure + XML fields)
# =============================================================================
#
# Layout structure (from NOPD):
#   ROOT (Root, no parent) -> FORM_ROOT (Form, isCanvas) -> ROOT_PAGE (Page)
#   -> ROOT_CARD (Card, title=entity) -> ROW_N (Row, templateColumns) -> field nodes
#
# Form field types:
#   FormInput  -- text / numeric fields (fieldId, label, maxLength)
#   FormSelect -- attributeTypeId fields (fieldId, label, attributeTypeId, [initialValue])
#   FormSelect -- codeType fields       (fieldId, label, codeTypeCategory, codeTypeSource, [initialValue])
#   FormDate   -- date picker            (fieldId, label)

# ---- Vehicle QIF ----
# Rows:
#   R1: LicensePlateNumber | State (AZ default)
#   R2: LicensePlateTypeCode | LicensePlateYear
#   R3: VehicleIdentificationNumber | VehicleMakeCode | VehicleYear
#   R4: BadgeNumber (required for ACVR)

$qif_vehicle = [PSCustomObject]@{
    description  = "Input query layout for vehicle entity"
    label        = "Vehicle"
    name         = "ENTITY_Vehicle"
    type         = "QUERYINPUTFORM"
    targetEntity = "Vehicle"
    provider     = "MARK43"
    layout       = [PSCustomObject]@{
        default = [ordered]@{
            ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Root"}; displayName="Root"; props=[PSCustomObject]@{}
                isCanvas=$false; hidden=$false; nodes=@("FORM_ROOT"); linkedNodes=[PSCustomObject]@{} }
            FORM_ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Form"}; displayName="Form"
                props=[PSCustomObject]@{hidePageItems=$true; layout="page"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_PAGE"); parent="ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_PAGE = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Page"}; displayName="Page"
                props=[PSCustomObject]@{title="Page 1"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_CARD"); parent="FORM_ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_CARD = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Card"}; displayName="Card"
                props=[PSCustomObject]@{title="Vehicle"}
                isCanvas=$true; hidden=$false; nodes=@("ROW_1","ROW_2","ROW_3","ROW_4"); parent="ROOT_PAGE"; linkedNodes=[PSCustomObject]@{} }
            ROW_1 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("LicensePlateNumber_Input","State_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_2 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("LicensePlateTypeCode_Input","LicensePlateYear_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_3 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("4","4","4")}
                isCanvas=$true; hidden=$false; nodes=@("VehicleIdentificationNumber_Input","VehicleMakeCode_Input","VehicleYear_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_4 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("BadgeNumber_Input","OwnerFirstName_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            LicensePlateNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="LicensePlateNumber"; label="Plate Number"; maxLength="10"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            State_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{attributeTypeId="STATE"; fieldId="RegistrationState"; initialValue="AZ"; label="State"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            LicensePlateTypeCode_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="LicensePlateTypeCode"; label="Plate Type"; maxLength="2"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_2"; linkedNodes=[PSCustomObject]@{} }
            LicensePlateYear_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="LicensePlateYear"; label="Plate Year"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_2"; linkedNodes=[PSCustomObject]@{} }
            VehicleIdentificationNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="VehicleIdentificationNumber"; label="VIN"; maxLength="20"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
            VehicleMakeCode_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="VehicleMakeCode"; label="Vehicle Make"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
            VehicleYear_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="VehicleYear"; label="Vehicle Year"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
            BadgeNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="BadgeNumber"; label="Badge Number"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_4"; linkedNodes=[PSCustomObject]@{} }
            OwnerFirstName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="OwnerFirstName"; label="Owner First Name"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_4"; linkedNodes=[PSCustomObject]@{} }
        }
    }
}
Write-Host "  QIF Vehicle: Plate / State / Plate Type / Plate Year / VIN / Make / Year / Badge" -ForegroundColor Green

# ---- Person QIF ----
# Rows:
#   R1: OLN | SSN
#   R2: State (AZ default)
#   R3: LastName | FirstName
#   R4: MiddleName | Suffix | DateOfBirth
#   R5: Sex | Race
#   R6: BadgeNumber | ImageIndicator

$qif_person = [PSCustomObject]@{
    description  = "Input query layout for person entity"
    label        = "Person"
    name         = "ENTITY_Person"
    type         = "QUERYINPUTFORM"
    targetEntity = "Person"
    provider     = "MARK43"
    layout       = [PSCustomObject]@{
        default = [ordered]@{
            ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Root"}; displayName="Root"; props=[PSCustomObject]@{}
                isCanvas=$false; hidden=$false; nodes=@("FORM_ROOT"); linkedNodes=[PSCustomObject]@{} }
            FORM_ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Form"}; displayName="Form"
                props=[PSCustomObject]@{hidePageItems=$true; layout="page"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_PAGE"); parent="ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_PAGE = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Page"}; displayName="Page"
                props=[PSCustomObject]@{title="Page 1"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_CARD"); parent="FORM_ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_CARD = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Card"}; displayName="Card"
                props=[PSCustomObject]@{title="Person"}
                isCanvas=$true; hidden=$false; nodes=@("ROW_1","ROW_2","ROW_3","ROW_4","ROW_5","ROW_6"); parent="ROOT_PAGE"; linkedNodes=[PSCustomObject]@{} }
            ROW_1 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("OLN_Input","SSN_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_2 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("12")}
                isCanvas=$true; hidden=$false; nodes=@("State_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_3 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("LastName_Input","FirstName_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_4 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("3","3","6")}
                isCanvas=$true; hidden=$false; nodes=@("MiddleName_Input","Suffix_Input","DateOfBirth_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_5 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("Sex_Input","Race_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_6 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("BadgeNumber_Input","ImageIndicator_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            OLN_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="OperatorLicenseNumber"; label="OLN"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            SSN_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="SocialSecurityNumber"; label="SSN"; maxLength="9"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            State_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{attributeTypeId="STATE"; fieldId="RegistrationState"; initialValue="AZ"; label="State"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_2"; linkedNodes=[PSCustomObject]@{} }
            LastName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="NameLast"; label="Last Name"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
            FirstName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="NameFirst"; label="First Name"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
            MiddleName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="NameMiddle"; label="M.I."}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_4"; linkedNodes=[PSCustomObject]@{} }
            Suffix_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="NameSuffix"; label="Suffix"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_4"; linkedNodes=[PSCustomObject]@{} }
            DateOfBirth_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormDate"}; displayName="Date"
                props=[PSCustomObject]@{fieldId="BirthDate"; label="Date Of Birth"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_4"; linkedNodes=[PSCustomObject]@{} }
            Sex_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{attributeTypeId="SEX"; codeTypeProvider="NIBRS"; fieldId="SexCode"; label="Sex"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_5"; linkedNodes=[PSCustomObject]@{} }
            Race_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{attributeTypeId="RACE"; fieldId="RaceCode"; label="Race"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_5"; linkedNodes=[PSCustomObject]@{} }
            BadgeNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="BadgeNumber"; label="Badge Number"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_6"; linkedNodes=[PSCustomObject]@{} }
            ImageIndicator_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{codeTypeCategory="YES_NO_UNKNOWN"; codeTypeSource="NCIC"; fieldId="ImageIndicator"; initialValue="Y"; label="Image Indicator"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_6"; linkedNodes=[PSCustomObject]@{} }
        }
    }
}
Write-Host "  QIF Person: OLN / SSN / State / Name / DOB / Sex / Race / Badge / Image" -ForegroundColor Green

# ---- Firearm QIF ----
# Rows:
#   R1: BadgeNumber | SerialNumber
#   R2: GunMake (select) | GunModel (input)
#   R3: GunCaliber (select)

$qif_firearm = [PSCustomObject]@{
    description  = "Input query layout for firearm entity"
    label        = "Firearm"
    name         = "ENTITY_Firearm"
    type         = "QUERYINPUTFORM"
    targetEntity = "Firearm"
    provider     = "MARK43"
    layout       = [PSCustomObject]@{
        default = [ordered]@{
            ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Root"}; displayName="Root"; props=[PSCustomObject]@{}
                isCanvas=$false; hidden=$false; nodes=@("FORM_ROOT"); linkedNodes=[PSCustomObject]@{} }
            FORM_ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Form"}; displayName="Form"
                props=[PSCustomObject]@{hidePageItems=$true; layout="page"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_PAGE"); parent="ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_PAGE = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Page"}; displayName="Page"
                props=[PSCustomObject]@{title="Page 1"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_CARD"); parent="FORM_ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_CARD = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Card"}; displayName="Card"
                props=[PSCustomObject]@{title="Firearm"}
                isCanvas=$true; hidden=$false; nodes=@("ROW_1","ROW_2","ROW_3"); parent="ROOT_PAGE"; linkedNodes=[PSCustomObject]@{} }
            ROW_1 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("BadgeNumber_Input","SerialNumber_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_2 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("GunMake_Input","GunModel_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_3 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("12")}
                isCanvas=$true; hidden=$false; nodes=@("GunCaliber_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            BadgeNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="BadgeNumber"; label="Badge Number"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            SerialNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="SerialNumber"; label="Serial Number"; maxLength="11"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            GunMake_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{codeTypeCategory="NCIC_FIREARM_MAKE"; codeTypeSource="NJ_NIBRS"; fieldId="FirearmMake"; label="Make"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_2"; linkedNodes=[PSCustomObject]@{} }
            GunModel_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="FirearmModel"; label="Model"; maxLength="11"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_2"; linkedNodes=[PSCustomObject]@{} }
            GunCaliber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{codeTypeCategory="NCIC_FIREARM_CALIBER"; codeTypeSource="NJ_NIBRS"; fieldId="FirearmCaliber"; label="Caliber"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
        }
    }
}
Write-Host "  QIF Firearm: Badge / Serial / Make / Model / Caliber" -ForegroundColor Green

# ---- Article QIF ----
# Rows:
#   R1: BadgeNumber | SerialNumber
#   R2: ArticleTypeCode (select)

$qif_article = [PSCustomObject]@{
    description  = "Input query layout for article entity"
    label        = "Article"
    name         = "ENTITY_Article"
    type         = "QUERYINPUTFORM"
    targetEntity = "Article"
    provider     = "MARK43"
    layout       = [PSCustomObject]@{
        default = [ordered]@{
            ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Root"}; displayName="Root"; props=[PSCustomObject]@{}
                isCanvas=$false; hidden=$false; nodes=@("FORM_ROOT"); linkedNodes=[PSCustomObject]@{} }
            FORM_ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Form"}; displayName="Form"
                props=[PSCustomObject]@{hidePageItems=$true; layout="page"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_PAGE"); parent="ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_PAGE = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Page"}; displayName="Page"
                props=[PSCustomObject]@{title="Page 1"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_CARD"); parent="FORM_ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_CARD = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Card"}; displayName="Card"
                props=[PSCustomObject]@{title="Article"}
                isCanvas=$true; hidden=$false; nodes=@("ROW_1","ROW_2"); parent="ROOT_PAGE"; linkedNodes=[PSCustomObject]@{} }
            ROW_1 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("BadgeNumber_Input","SerialNumber_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_2 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("12")}
                isCanvas=$true; hidden=$false; nodes=@("ArticleTypeCode_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            BadgeNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="BadgeNumber"; label="Badge Number"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            SerialNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="SerialNumber"; label="Serial Number / OAN"; maxLength="11"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            ArticleTypeCode_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{codeTypeCategory="NCIC_ARTICLE_TYPE"; codeTypeSource="CA_CLETS"; fieldId="ArticleTypeCode"; label="Article Type"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_2"; linkedNodes=[PSCustomObject]@{} }
        }
    }
}
Write-Host "  QIF Article: Badge / Serial / Type" -ForegroundColor Green

# ---- Boat QIF ----
# Rows:
#   R1: RegistrationNumber | State (AZ default)
#   R2: BoatHullIdNumber
#   R3: LastName | FirstName
#   R4: DateOfBirth | BadgeNumber

$qif_boat = [PSCustomObject]@{
    description  = "Input query layout for boat entity"
    label        = "Boat"
    name         = "ENTITY_Boat"
    type         = "QUERYINPUTFORM"
    targetEntity = "Boat"
    provider     = "MARK43"
    layout       = [PSCustomObject]@{
        default = [ordered]@{
            ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Root"}; displayName="Root"; props=[PSCustomObject]@{}
                isCanvas=$false; hidden=$false; nodes=@("FORM_ROOT"); linkedNodes=[PSCustomObject]@{} }
            FORM_ROOT = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Form"}; displayName="Form"
                props=[PSCustomObject]@{hidePageItems=$true; layout="page"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_PAGE"); parent="ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_PAGE = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Page"}; displayName="Page"
                props=[PSCustomObject]@{title="Page 1"}
                isCanvas=$true; hidden=$false; nodes=@("ROOT_CARD"); parent="FORM_ROOT"; linkedNodes=[PSCustomObject]@{} }
            ROOT_CARD = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Card"}; displayName="Card"
                props=[PSCustomObject]@{title="Boat"}
                isCanvas=$true; hidden=$false; nodes=@("ROW_1","ROW_2","ROW_3","ROW_4"); parent="ROOT_PAGE"; linkedNodes=[PSCustomObject]@{} }
            ROW_1 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("RegistrationNumber_Input","State_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_2 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("12")}
                isCanvas=$true; hidden=$false; nodes=@("BoatHullIdNumber_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_3 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("LastName_Input","FirstName_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            ROW_4 = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="Row"}; displayName="Row"
                props=[PSCustomObject]@{templateColumns=@("6","6")}
                isCanvas=$true; hidden=$false; nodes=@("DateOfBirth_Input","BadgeNumber_Input"); parent="ROOT_CARD"; linkedNodes=[PSCustomObject]@{} }
            RegistrationNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="RegistrationNumber"; label="Registration Number"; maxLength="8"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            State_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormSelect"}; displayName="Select"
                props=[PSCustomObject]@{attributeTypeId="STATE"; fieldId="RegistrationState"; initialValue="AZ"; label="State"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_1"; linkedNodes=[PSCustomObject]@{} }
            BoatHullIdNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="BoatHullIdNumber"; label="Hull ID Number"; maxLength="20"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_2"; linkedNodes=[PSCustomObject]@{} }
            LastName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="NameLast"; label="Last Name"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
            FirstName_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="NameFirst"; label="First Name"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_3"; linkedNodes=[PSCustomObject]@{} }
            DateOfBirth_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormDate"}; displayName="Date"
                props=[PSCustomObject]@{fieldId="BirthDate"; label="Date Of Birth"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_4"; linkedNodes=[PSCustomObject]@{} }
            BadgeNumber_Input = [PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName="FormInput"}; displayName="Input"
                props=[PSCustomObject]@{fieldId="BadgeNumber"; label="Badge Number"; maxLength="4"}
                isCanvas=$false; hidden=$false; nodes=@(); parent="ROW_4"; linkedNodes=[PSCustomObject]@{} }
        }
    }
}
Write-Host "  QIF Boat: Reg / State / Hull / LastName / FirstName / DOB / Badge" -ForegroundColor Green

# Add CAD_DISPATCH and FIRST_RESPONDER layout variants to all QIFs (copies of default)
foreach ($qif in @($qif_vehicle, $qif_person, $qif_firearm, $qif_article, $qif_boat)) {
    $defaultLayout = DeepClone($qif.layout.default)
    $qif.layout | Add-Member -MemberType NoteProperty -Name "CAD_DISPATCH"    -Value (DeepClone($qif.layout.default)) -Force
    $qif.layout | Add-Member -MemberType NoteProperty -Name "FIRST_RESPONDER" -Value (DeepClone($qif.layout.default)) -Force
}
Write-Host "  QIF layouts: CAD_DISPATCH + FIRST_RESPONDER variants added (copies of default)" -ForegroundColor Cyan

# =============================================================================
# SECTION 4 -- RMS bundle (cloned directly from NOPD)
# =============================================================================
$azRms = DeepClone($nopdRms)

# Patch: RMS Vehicle QIDM -- remove LicensePlateYear from combination any[] arrays.
# LicensePlateYear has no RMS elastic mapping and is not defined as an attribute,
# causing "Missing attributes" import error. NOPD combination any[] arrays include it
# but RMS does not support plate year filtering.
$rmsVehicleQidm = ($azRms.configurations | Where-Object {
    $_.type -eq "QUERYINPUTDATAMAPPING" -and $_.targetEntity -eq "Vehicle"
})
foreach ($combo in $rmsVehicleQidm.combinations) {
    $any = [System.Collections.Generic.List[string]]($combo.requirements.any)
    $removed = $any.Remove("LicensePlateYear")
    if ($removed) { $combo.requirements.any = $any.ToArray() }
}

# Patch: RMS QIDMs need autoSelect=true so the RMS checkbox fires automatically
# NOPD clones have autoSelect=false or absent; without this the RMS checkbox never activates
foreach ($cfg in $azRms.configurations) {
    if ($cfg.type -eq "QUERYINPUTDATAMAPPING") {
        $cfg | Add-Member -MemberType NoteProperty -Name "autoSelect" -Value $true -Force
    }
}

# No sex patches: form uses attributeTypeId=SEX + codeTypeProvider=NIBRS.
# CommSys QIDM SexCode has codeTypeProvider=NIBRS (reverse-lookup: attribute ID -> NIBRS "F").
# RMS QIDM sex attribute uses useAttributeId=true (attribute ID passes through directly).
# Both paths satisfied simultaneously via NIBRS registration under AZ_AZDPS provider.

Write-Host ""
Write-Host "RMS bundle: cloned from NOPD (Person + Vehicle QIDMs, QRDM, layout)" -ForegroundColor Cyan
Write-Host "  Patch: LicensePlateYear removed from RMS Vehicle QIDM combination any[] arrays" -ForegroundColor Yellow
Write-Host "  Patch: autoSelect=true added to all RMS QIDMs" -ForegroundColor Yellow

# =============================================================================
# SECTION 5 -- Assemble and write
# =============================================================================

$azBundle = [PSCustomObject]@{
    name             = "AZ_AZDPS"
    description      = "Provider configuration for AZ_AZDPS"
    type             = "BUNDLE"
    codeTypeProvider = "AZ_AZDPS"
    provider         = "AZ_AZDPS"
    configurations   = @(
        $azAuth, $azQrdm, $azMsgFmt,
        $qidm_vehicle, $qidm_person, $qidm_firearm, $qidm_article, $qidm_boat
    )
}

$entitiesBundle = [PSCustomObject]@{
    name             = "ENTITIES"
    description      = "Query forms of entities"
    type             = "BUNDLE"
    codeTypeProvider = "NCIC"
    provider         = "MARK43"
    order            = [PSCustomObject]@{
        default        = @("Person","Vehicle","Firearm","Article","Boat")
        CAD_DISPATCH   = @("Vehicle","Person","Firearm","Article","Boat")
        FIRST_RESPONDER = @("Vehicle","Person","Firearm","Article","Boat")
    }
    configurations   = @(
        $qif_article, $qif_vehicle, $qif_person, $qif_firearm, $qif_boat
    )
}

$azJson = [PSCustomObject]@{
    bundles = @($azBundle, $entitiesBundle, $azRms)
}

($azJson | ConvertTo-Json -Depth 100) | Set-Content $OUT -Encoding UTF8

Write-Host ""
Write-Host "========================================"
Write-Host " Output: $OUT"
Write-Host "========================================"
Write-Host ""
Write-Host "CommSys bundle (AZ_AZDPS):"
Write-Host "  Authentication      -- cloned from NOPD"
Write-Host "  QUERYRESULTDATAMAPPING  -- cloned from NOPD (provider -> AZ_AZDPS)"
Write-Host "  QUERYMESSAGEFORMAT  -- cloned from NOPD (provider -> AZ_AZDPS)"
Write-Host "  QIDM Vehicle        -- VehicleRegistrationQuery (ACVR)"
Write-Host "  QIDM Person         -- AzAzdpsDriverLicenseQuery (DQ + ACWL)"
Write-Host "  QIDM Firearm        -- GunQuery (ACQG)"
Write-Host "  QIDM Article        -- ArticleSingleQuery (ACQA)"
Write-Host "  QIDM Boat           -- AzAzdpsBoatQuery (ACQB + BQ)"
Write-Host ""
Write-Host "ENTITIES bundle:"
Write-Host "  QIF Article  -- Badge / Serial / Type"
Write-Host "  QIF Vehicle  -- Plate / State / PlateType / PlateYear / VIN / Make / Year / Badge / OwnerFirst"
Write-Host "  QIF Person   -- OLN / SSN / State / Name / DOB / Sex / Race / Badge / Image"
Write-Host "  QIF Firearm  -- Badge / Serial / Make / Model / Caliber"
Write-Host "  QIF Boat     -- Reg / State / Hull / Name / DOB / Badge"
Write-Host ""
Write-Host "RMS bundle:  cloned from NOPD (Person + Vehicle search, QRDM)"
Write-Host ""
Write-Host "NOTE: Badge Number is a required field for ACVR (vehicle), ACQG (firearm),"
Write-Host "      ACQA (article), ACQB (boat), and ACWL (person) combinations."
Write-Host "      DQ person and BQ boat combinations do NOT require Badge Number."
Write-Host ""
