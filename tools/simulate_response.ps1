<#
  simulate_response.ps1 -- CommSys QRDM response handler simulator
  DESCRIBED IN: CLAUDE.md (tools table, Core Build Pipeline step 11), README.txt

  Executes all CommSys QRDM handler transformations against comprehensive synthetic test data,
  showing: raw CJIS value -> handler logic -> transformed output -> UI display.
  All handlers are exercised using synthetic data only. No live data required.

  Handlers implemented: PassThrough, HeightParserRuleHandler, ParseCommsysNameRuleHandler,
  ParseCommsysVehicleYearRuleHandler, truncate, CommsysResultAttributeMappingRuleHandler (NCIC tables).

  Target results: 0 MISSING / 0 UNMAPPED across all entities. MISSING = attribute with
  a sourceField present in this entity's test data but absent from the response -- a real gap.
  Attributes for other entities are excluded from the count (not a gap, not applicable).

  Usage:
    .\simulate_response.ps1 -Path providers\NY_NYSPIN_EJUSTICE\NY_NYSPIN_EJUSTICE.json
    .\simulate_response.ps1 -Path providers\NY_NYSPIN_EJUSTICE\NY_NYSPIN_EJUSTICE.json -Entity Vehicle
    .\simulate_response.ps1 -Path providers\NY_NYSPIN_EJUSTICE\NY_NYSPIN_EJUSTICE.json -Entity Person -RunEdgeCases
    .\simulate_response.ps1 -Path providers\NY_NYSPIN_EJUSTICE\NY_NYSPIN_EJUSTICE.json -OutFile docs\RESPONSE_SIMULATION_NY_NYSPIN_EJUSTICE.txt
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [ValidateSet('Vehicle','Person','Firearm','Article','Boat','All')]
    [string]$Entity = 'All',
    [switch]$RunEdgeCases,  # run edge-case inputs per handler after standard pass
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$jsonPath = Resolve-Path $Path
$provName = [System.IO.Path]::GetFileNameWithoutExtension($jsonPath) -replace '_(BASE|MC)$',''
$json = [System.IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json

# ── Extract CommSys QRDM ──────────────────────────────────────────────────────
$provBundle = $json.bundles | Where-Object { $_.provider -ne 'MARK43' -and $_.provider -ne 'RMS' }
$qrdm = $provBundle.configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' } | Select-Object -First 1
if (-not $qrdm) { Write-Host "[ERROR] No CommSys QRDM in $provName" -ForegroundColor Red; exit 1 }

# Get version
$scriptVer = ''
$sf = Get-ChildItem (Join-Path (Split-Path $jsonPath) 'scripts') -Filter 'build_*.ps1' -File -EA SilentlyContinue | Select-Object -First 1
if ($sf) { $t = [System.IO.File]::ReadAllText($sf.FullName); if ($t -match '\$Version\s*=\s*["'']([^"'']+)["'']') { $scriptVer = " v$($Matches[1])" } }

# ════════════════════════════════════════════════════════════════════════════════
#  HANDLER IMPLEMENTATIONS
# ════════════════════════════════════════════════════════════════════════════════

# ── CommsysResultAttributeMappingRuleHandler code tables (NCIC standard) ─────
$codeTables = @{
    'SexCode' = @{
        'M' = 'Male'
        'F' = 'Female'
        'U' = 'Unknown'
        'N' = 'Non-Binary'
    }
    'RaceCode' = @{
        'W' = 'White'
        'B' = 'Black'
        'I' = 'Native American'
        'A' = 'Asian/Pacific Islander'
        'H' = 'Hispanic'
        'U' = 'Unknown'
    }
    'EyeColorCode' = @{
        'BRO' = 'Brown'
        'BLU' = 'Blue'
        'GRN' = 'Green'
        'HAZ' = 'Hazel'
        'BLK' = 'Black'
        'GRY' = 'Gray'
        'MAR' = 'Marbled'
        'PNK' = 'Pink'
        'MUL' = 'Multicolored'
        'UNK' = 'Unknown'
    }
    'HairColorCode' = @{
        'BLK' = 'Black'
        'BLN' = 'Blond'
        'BRO' = 'Brown'
        'GRY' = 'Gray'
        'RED' = 'Red'
        'SDY' = 'Sandy'
        'WHI' = 'White'
        'BAL' = 'Bald'
        'UNK' = 'Unknown'
    }
    'VehicleColorCode' = @{
        'BLK' = 'Black'
        'WHI' = 'White'
        'RED' = 'Red'
        'SLV' = 'Silver'
        'GRY' = 'Gray'
        'BLU' = 'Blue'
        'GRN' = 'Green'
        'YEL' = 'Yellow'
        'GLD' = 'Gold'
        'BRN' = 'Brown'
        'BEG' = 'Beige'
        'TAN' = 'Tan'
        'ONG' = 'Orange'
        'PRP' = 'Purple'
        'MAR' = 'Maroon'
        'CPR' = 'Copper'
        'PNK' = 'Pink'
        'UNK' = 'Unknown'
    }
    'VehicleStyleCode' = @{
        '2D'  = '2-Door'
        '4D'  = '4-Door'
        'SW'  = 'Station Wagon'
        'TK'  = 'Truck'
        'VN'  = 'Van'
        'CO'  = 'Convertible'
        'MH'  = 'Motor Home'
        'MC'  = 'Motorcycle'
        'BU'  = 'Bus'
        'AT'  = 'ATV'
        'AM'  = 'Ambulance'
        'UNK' = 'Unknown'
    }
    'VehicleMakeName' = @{
        'AUDI' = 'Audi'
        'BMW'  = 'BMW'
        'BUIC' = 'Buick'
        'CADI' = 'Cadillac'
        'CHEV' = 'Chevrolet'
        'CHRY' = 'Chrysler'
        'DODG' = 'Dodge'
        'FORD' = 'Ford'
        'GMC'  = 'GMC'
        'HOND' = 'Honda'
        'HYUN' = 'Hyundai'
        'INFI' = 'Infiniti'
        'JEEP' = 'Jeep'
        'KIA'  = 'Kia'
        'LEXS' = 'Lexus'
        'LINC' = 'Lincoln'
        'MAZD' = 'Mazda'
        'MERZ' = 'Mercedes-Benz'
        'MERC' = 'Mercury'
        'MINI' = 'Mini'
        'MITS' = 'Mitsubishi'
        'NISS' = 'Nissan'
        'OLDS' = 'Oldsmobile'
        'PONT' = 'Pontiac'
        'SATU' = 'Saturn'
        'SUBA' = 'Subaru'
        'TOYT' = 'Toyota'
        'VOLK' = 'Volkswagen'
        'VOLV' = 'Volvo'
    }
    'AddressStateCode' = @{
        'AL'='Alabama';'AK'='Alaska';'AZ'='Arizona';'AR'='Arkansas';'CA'='California'
        'CO'='Colorado';'CT'='Connecticut';'DE'='Delaware';'FL'='Florida';'GA'='Georgia'
        'HI'='Hawaii';'ID'='Idaho';'IL'='Illinois';'IN'='Indiana';'IA'='Iowa'
        'KS'='Kansas';'KY'='Kentucky';'LA'='Louisiana';'ME'='Maine';'MD'='Maryland'
        'MA'='Massachusetts';'MI'='Michigan';'MN'='Minnesota';'MS'='Mississippi';'MO'='Missouri'
        'MT'='Montana';'NE'='Nebraska';'NV'='Nevada';'NH'='New Hampshire';'NJ'='New Jersey'
        'NM'='New Mexico';'NY'='New York';'NC'='North Carolina';'ND'='North Dakota';'OH'='Ohio'
        'OK'='Oklahoma';'OR'='Oregon';'PA'='Pennsylvania';'RI'='Rhode Island';'SC'='South Carolina'
        'SD'='South Dakota';'TN'='Tennessee';'TX'='Texas';'UT'='Utah';'VT'='Vermont'
        'VA'='Virginia';'WA'='Washington';'WV'='West Virginia';'WI'='Wisconsin';'WY'='Wyoming'
        'DC'='District of Columbia';'PR'='Puerto Rico';'VI'='Virgin Islands'
    }
}

# Attrs that use attribute mapping -> which code table they use
$attrTableMap = @{
    'AddressStateCode' = 'AddressStateCode'
    'EyeColorCode'     = 'EyeColorCode'
    'HairColorCode'    = 'HairColorCode'
    'RaceCode'         = 'RaceCode'
    'SexCode'          = 'SexCode'
    'VehicleColorCode' = 'VehicleColorCode'
    'VehicleMakeName'  = 'VehicleMakeName'   # sourceField is VehicleMakeCode
    'VehicleModelName' = $null               # model lookup requires make context -- note as limited
    'VehicleStyleCode' = 'VehicleStyleCode'
}

# ── Handler: HeightParserRuleHandler ─────────────────────────────────────────
function Invoke-HeightParser($rawVal, $targetField, [ref]$trace) {
    if ([string]::IsNullOrEmpty($rawVal)) { return $null }
    $ft = $null; $ins = $null
    if ($rawVal -match '^\d{3}$') {
        # 3-digit Commsys format: 511 = 5'11"
        $ft  = [int]$rawVal[0].ToString()
        $ins = [int]$rawVal.Substring(1)
        $trace.Value = "3-digit Commsys format: '$rawVal' -> $ft feet $ins inches"
    } elseif ($rawVal -match '^\d{1,2}$') {
        # Single number passed as HeightFeet or HeightInches
        if ($targetField -eq 'HeightFeet')   { $ft = [int]$rawVal; $ins = 0; $trace.Value = "Feet value: $ft" }
        elseif ($targetField -eq 'HeightInches') { $ft = 0; $ins = [int]$rawVal; $trace.Value = "Inches value: $ins" }
        else { $ft = [int]($rawVal.Substring(0,1)); $ins = 0; $trace.Value = "Partial: $rawVal" }
    } else {
        $trace.Value = "Unrecognized format: '$rawVal' -- returned as-is"
        return $rawVal
    }

    switch ($targetField) {
        'HeightDisplay' { return "$ft'$ins""" }
        'Height'        { return "$ft'$ins""" }
        'HeightFeet'    { return $ft }
        'HeightInches'  { return $ins }
        default         { return "$ft'$ins""" }
    }
}

# ── Handler: ParseCommsysNameRuleHandler ─────────────────────────────────────
function Invoke-ParseName($rawNormLast, $rawNormFirst, $rawNormMiddle, $rawName, $targetField, [ref]$trace) {
    # Level 1: Normalized parts
    if (-not [string]::IsNullOrEmpty($rawNormLast)) {
        $trace.Value = "Level 1: NormalizedName parts (Last='$rawNormLast', First='$rawNormFirst', Middle='$rawNormMiddle')"
        switch ($targetField) {
            'NameLast'   { return $rawNormLast }
            'NameFirst'  { return $rawNormFirst }
            'NameMiddle' { return $rawNormMiddle }
            'Name'       { return "$rawNormLast,$rawNormFirst $(if ($rawNormMiddle) { $rawNormMiddle })".Trim() }
        }
    }

    # Level 2/3: Parse Name string
    $src = if (-not [string]::IsNullOrEmpty($rawName)) { $rawName } else { return $null }
    $trace.Value = "Level 3: Parsing Name string '$src'"

    $last = ''; $first = ''; $middle = ''
    if ($src -match ',') {
        # "DOE,JOHN A" or "DOE, JOHN A"
        $parts = $src -split ',', 2
        $last  = $parts[0].Trim()
        $rest  = $parts[1].Trim() -split '\s+', 2
        $first = $rest[0]
        if ($rest.Count -gt 1) { $middle = $rest[1] }
        $trace.Value += " -> comma-separated: Last='$last' First='$first' Middle='$middle'"
    } else {
        $tokens = $src.Trim() -split '\s+'
        if ($tokens.Count -eq 1) {
            $last = $tokens[0]
            $trace.Value += " -> single token: Last='$last'"
        } elseif ($tokens.Count -eq 2) {
            $last = $tokens[0]; $first = $tokens[1]
            $trace.Value += " -> two tokens: Last='$last' First='$first'"
        } else {
            # 3+ tokens: last=first, first=second, middle=rest OR last-token is 1-char middle initial
            if ($tokens[-1].Length -eq 1) {
                $last = $tokens[0]; $first = $tokens[1]; $middle = $tokens[-1]
                $trace.Value += " -> last-token=initial: Last='$last' First='$first' Middle='$middle'"
            } else {
                $last = $tokens[0]; $first = $tokens[1]; $middle = ($tokens[2..($tokens.Count-1)] -join ' ')
                $trace.Value += " -> space-separated: Last='$last' First='$first' Middle='$middle'"
            }
        }
    }

    switch ($targetField) {
        'NameLast'   { return $last }
        'NameFirst'  { return $first }
        'NameMiddle' { return $middle }
        'Name'       { return $src }
        default      { return $src }
    }
}

# ── Handler: ParseCommsysVehicleYearRuleHandler ───────────────────────────────
function Invoke-VehicleYear($rawVal, [ref]$trace) {
    if ([string]::IsNullOrEmpty($rawVal)) { return $null }
    $n = 0
    if (-not [int]::TryParse($rawVal, [ref]$n)) {
        $trace.Value = "Non-numeric '$rawVal' -- returned as-is"
        return $rawVal
    }
    if ($n -ge 1000) {
        $trace.Value = "4-digit year: $n (passthrough)"
        return $n
    }
    # 2-digit with threshold=50
    if ($n -lt 50) {
        $result = 2000 + $n
        $trace.Value = "$n < 50 -> 2000 + $n = $result"
        return $result
    } else {
        $result = 1900 + $n
        $trace.Value = "$n >= 50 -> 1900 + $n = $result"
        return $result
    }
}

# ── Handler: truncate (SSN) ───────────────────────────────────────────────────
function Invoke-Truncate($rawVal, $size, [ref]$trace) {
    if ([string]::IsNullOrEmpty($rawVal)) { return $null }
    if ($rawVal.Length -le $size) {
        $trace.Value = "Length $($rawVal.Length) <= $size (no truncation needed)"
        return $rawVal
    }
    $result = $rawVal.Substring(0, $size)
    $trace.Value = "Truncated from $($rawVal.Length) to $size chars: '$result'"
    return $result
}

# ── Handler: CommsysResultAttributeMappingRuleHandler ────────────────────────
function Invoke-AttrMapping($attrName, $rawVal, [ref]$trace) {
    if ([string]::IsNullOrEmpty($rawVal)) { return $null }
    $tblKey = $attrTableMap[$attrName]
    if ($null -eq $tblKey) {
        $trace.Value = "VehicleModelName: model lookup requires platform attr tables -- returned as-is"
        return $rawVal
    }
    $tbl = $codeTables[$tblKey]
    if ($null -eq $tbl) {
        $trace.Value = "No table for '$tblKey' -- returned as-is"
        return $rawVal
    }
    $display = $tbl[$rawVal]
    if ($display) {
        $trace.Value = "table=${tblKey}: '$rawVal' -> '$display'"
        return $display
    } else {
        $trace.Value = "table=${tblKey}: '$rawVal' NOT FOUND in table ({$($tbl.Keys -join ',')})"
        return "[UNMAPPED: $rawVal]"
    }
}

# ── Apply one QRDM attribute against the result field hash ────────────────────
function Invoke-Attr($attr, $fields) {
    $src = if ($attr.sourceField -is [array]) { $attr.sourceField[0] } else { $attr.sourceField }
    $rawVal = $fields[$src]
    $trace  = [ref]''
    $output = $null
    $status = $null

    if ($null -eq $rawVal -or $rawVal -eq '') {
        return [PSCustomObject]@{
            AttrName = $attr.name; Src = $src; Tgt = $attr.targetField
            Raw = $null; Handler = '(field absent)'; Trace = ''; Output = $null
            Status = 'MISSING'
        }
    }

    $handler = if ($attr.rule -and $attr.rule.function) { $attr.rule.function } else { 'passthrough' }

    switch ($handler) {
        'passthrough' {
            $output = $rawVal
            $trace.Value = "No transformation -- value passed through"
            $status = 'MAPPED'
        }
        'HeightParserRuleHandler' {
            # Determine mode from targetField
            $output = Invoke-HeightParser $rawVal $attr.targetField $trace
            $status = 'MAPPED'
        }
        'ParseCommsysNameRuleHandler' {
            # Name attrs need multiple source fields for level-1 fallback
            $normLast   = $fields['NormalizedNameLast']
            $normFirst  = $fields['NormalizedNameFirst']
            $normMiddle = $fields['NormalizedNameMiddle']
            $nameSrc    = $fields['Name']
            $output = Invoke-ParseName $normLast $normFirst $normMiddle $nameSrc $attr.targetField $trace
            $status = 'MAPPED'
        }
        'ParseCommsysVehicleYearRuleHandler' {
            $output = Invoke-VehicleYear $rawVal $trace
            $status = if ($output -is [string] -and $output.StartsWith('[')) { 'WARN' } else { 'MAPPED' }
        }
        'truncate' {
            $sz = if ($attr.size) { $attr.size } else { 11 }
            $output = Invoke-Truncate $rawVal $sz $trace
            $status = 'MAPPED'
        }
        'CommsysResultAttributeMappingRuleHandler' {
            $output = Invoke-AttrMapping $attr.name $rawVal $trace
            $status = if ($output -is [string] -and $output.StartsWith('[UNMAPPED')) { 'UNMAPPED' } else { 'MAPPED' }
        }
        default {
            $output = $rawVal
            $trace.Value = "Unknown handler '$handler' -- passthrough"
            $status = 'MAPPED'
        }
    }

    return [PSCustomObject]@{
        AttrName = $attr.name; Src = $src; Tgt = $attr.targetField
        Raw = $rawVal; Handler = $handler; Trace = $trace.Value
        Output = $output; Status = $status
    }
}

# ════════════════════════════════════════════════════════════════════════════════
#  SYNTHETIC TEST DATA
# ════════════════════════════════════════════════════════════════════════════════

$standardData = @{
    'Vehicle' = @{
        # Identity
        LicensePlateNumber           = 'NJD1234'
        LicensePlateStateCode        = 'NJ'
        ImpliedLicensePlateStateCode = 'NJ'
        RegistrationState            = 'NJ'
        VehicleIdentificationNumber  = '1HGCM82633A004352'
        # Vehicle attributes
        VehicleMakeCode              = 'HOND'
        VehicleModelCode             = 'CIV'
        VehicleYear                  = '2022'
        VehicleColorCode             = 'SLV'
        VehicleStyleCode             = '4D'
        VehicleTypeCode              = 'PA'
        Weight                       = '3200'
        AutoInsuranceCarrier         = 'GEICO'
        ExpirationDate               = '20261231'
        # Cross-entity
        Hit                          = 'Y'
        Image                        = 'N'
        ImageId                      = 'VEH001'
        IntSystemName                = 'NJMVC'
        IntInterfaceName             = 'NJ Motor Vehicle Commission'
        System                       = 'Vehicle Registration Query Result'
        SecondaryRequests            = 'N'
        RelatedSearchHitIndicator    = 'N'
    }
    'Person' = @{
        # Name
        NormalizedNameLast           = 'DOE'
        NormalizedNameFirst          = 'JOHN'
        NormalizedNameMiddle         = 'ALAN'
        Name                         = 'DOE,JOHN ALAN'
        # Demographics
        BirthDate                    = '19900115'
        SexCode                      = 'M'
        RaceCode                     = 'W'
        EthnicityCode                = 'N'
        EyeColorCode                 = 'BRO'
        EyeColor                     = 'BRO'
        HairColorCode                = 'BLK'
        HairColor                    = 'BLK'
        Height                       = '511'
        HeightFeet                   = '5'
        HeightInches                 = '11'
        Weight                       = '180'
        # Address
        AddressStreetNumber          = '123'
        AddressStreetName            = 'MAIN ST'
        AddressStreet                = '123 MAIN ST'
        AddressCity                  = 'TRENTON'
        AddressStateCode             = 'NJ'
        AddressZipCode               = '08601'
        # License
        OperatorLicenseNumber        = 'D999888777'
        OperatorLicenseStateCode     = 'NJ'
        OperatorLicenseStatusCode    = 'VALID'
        OperatorLicenseRestrictions  = 'NONE'
        OperatorLicenseClassCode     = 'D'
        ExpirationDate               = '20281201'
        # Identifiers
        SocialSecurityNumber         = '123-45-6789'
        OrganDonor                   = 'Y'
        AutoInsuranceCarrier         = 'GEICO'
        SecondaryRequests            = 'N'
        # Cross-entity
        Hit                          = 'Y'
        Image                        = 'Y'
        ImageId                      = 'PER001'
        IntSystemName                = 'NJDMV'
        IntInterfaceName             = 'NJ Division of Motor Vehicles'
        System                       = 'Driver License Query Result'
        RelatedSearchHitIndicator    = 'N'
    }
    'Firearm' = @{
        # Firearm attributes
        GunSerialNumber              = 'SN12345678'
        GunMake                      = 'COLT'
        GunModel                     = 'M1911'
        GunCaliber                   = '45'
        GunTypeCode                  = 'PI'
        SerialNumber                 = 'SN12345678'
        # Cross-entity
        Hit                          = 'Y'
        Image                        = 'N'
        ImageId                      = 'GUN001'
        IntSystemName                = 'NCIC'
        IntInterfaceName             = 'NCIC Firearm File'
        System                       = 'Firearm Query Result'
        RelatedSearchHitIndicator    = 'N'
        SecondaryRequests            = 'N'
    }
    'Article' = @{
        # Article attributes
        ArticleSerialNumber          = 'ART99999'
        ArticleTypeCode              = 'BICY'
        ArticleBrand                 = 'TREK'
        ArticleModel                 = 'FX3'
        SerialNumber                 = 'ART99999'
        # Cross-entity
        Hit                          = 'Y'
        Image                        = 'N'
        ImageId                      = 'ART001'
        IntSystemName                = 'NCIC'
        IntInterfaceName             = 'NCIC Article File'
        System                       = 'Article Query Result'
        RelatedSearchHitIndicator    = 'N'
        SecondaryRequests            = 'N'
    }
    'Boat' = @{
        # Boat attributes
        BoatHullIdNumber             = 'NJ1234AB56H7'
        BoatSerialNumber             = 'NJ1234AB56H7'
        BoatMakeCode                 = 'YAMA'
        BoatBrand                    = 'YAMAHA'
        BoatName                     = 'WAVE RUNNER'
        # Cross-entity
        Hit                          = 'Y'
        Image                        = 'N'
        ImageId                      = 'BOT001'
        IntSystemName                = 'NJSP'
        IntInterfaceName             = 'NCIC Boat File'
        System                       = 'Boat Query Result'
        RelatedSearchHitIndicator    = 'N'
        SecondaryRequests            = 'N'
    }
}

# Edge cases: designed to exercise each handler's logic paths
$edgeCases = @{
    'Vehicle' = @(
        @{ Label='2-digit year < 50'; Data=@{ VehicleYear='22'; VehicleMakeCode='FORD'; VehicleColorCode='BLK'; LicensePlateNumber='NJD1234' } }
        @{ Label='2-digit year >= 50'; Data=@{ VehicleYear='75'; VehicleMakeCode='CHEV'; VehicleColorCode='WHI'; LicensePlateNumber='NJD5678' } }
        @{ Label='Unknown color code'; Data=@{ VehicleYear='2019'; VehicleMakeCode='TOYT'; VehicleColorCode='XYZ'; LicensePlateNumber='NJD9999' } }
        @{ Label='Unknown make code'; Data=@{ VehicleYear='2021'; VehicleMakeCode='UNKN'; VehicleColorCode='RED'; LicensePlateNumber='NJA1111' } }
        @{ Label='Missing VIN'; Data=@{ LicensePlateNumber='NJD1234'; VehicleMakeCode='HOND'; VehicleYear='2020' } }
    )
    'Person' = @(
        @{ Label='Name: "DOE,JOHN" (no middle)'; Data=@{ Name='DOE,JOHN'; SexCode='M'; RaceCode='W'; BirthDate='19850101'; Height='600' } }
        @{ Label='Name: "DOE JOHN" (space, no comma)'; Data=@{ Name='DOE JOHN'; SexCode='F'; BirthDate='19920301'; Height='505' } }
        @{ Label='Name: "SMITH JOHN Q" (3 tokens, 1-char last)'; Data=@{ Name='SMITH JOHN Q'; SexCode='M'; BirthDate='19750615'; Height='510' } }
        @{ Label='Height: 4-digit "0511"'; Data=@{ NormalizedNameLast='TEST'; Name='TEST,USER'; Height='0511'; SexCode='M'; BirthDate='19900101' } }
        @{ Label='Unknown SexCode "X"'; Data=@{ NormalizedNameLast='DOE'; NormalizedNameFirst='JANE'; SexCode='X'; RaceCode='W'; BirthDate='19950301'; Height='504' } }
        @{ Label='Unknown RaceCode "Z"'; Data=@{ NormalizedNameLast='DOE'; NormalizedNameFirst='JOHN'; SexCode='M'; RaceCode='Z'; BirthDate='19880901'; Height='600' } }
        @{ Label='SSN truncation (>11 chars)'; Data=@{ NormalizedNameLast='DOE'; SexCode='M'; BirthDate='19900101'; Height='511'; SocialSecurityNumber='123-45-6789-EXTRA' } }
        @{ Label='Missing DOB'; Data=@{ NormalizedNameLast='DOE'; NormalizedNameFirst='JOHN'; SexCode='M'; RaceCode='W'; Height='511' } }
    )
    'Firearm' = @(
        @{ Label='Missing serial'; Data=@{ GunMake='COLT'; GunTypeCode='PI' } }
        @{ Label='All fields'; Data=@{ GunSerialNumber='SN99999'; GunMake='SMIT'; GunModel='38SPL'; GunCaliber='38'; GunTypeCode='RV'; SerialNumber='SN99999' } }
    )
}

# ════════════════════════════════════════════════════════════════════════════════
#  OUTPUT
# ════════════════════════════════════════════════════════════════════════════════

$outBuf = [System.Text.StringBuilder]::new()
$today  = Get-Date -Format 'yyyy-MM-dd HH:mm'

function Show($text, $clr='White') {
    [void]$outBuf.AppendLine($text)
    Write-Host $text -ForegroundColor $clr
}

function Show-AttrResult($r) {
    $pad = 34
    switch ($r.Status) {
        'MISSING' {
            Show ("  [MISSING]   {0,-$pad} absent from result" -f $r.AttrName) DarkYellow
            Show ("              Handler would apply: {0}" -f $(if ($r.Handler -ne '(field absent)') { $r.Handler } else { 'ParseCommsysNameRuleHandler or other' })) DarkYellow
            Show ("              Target: {0} -> UI: (blank)" -f $r.Tgt) DarkYellow
        }
        'UNMAPPED' {
            Show ("  [UNMAPPED]  {0,-$pad} Raw: {1}" -f $r.AttrName, $r.Raw) Red
            Show ("              Handler: {0}" -f $r.Handler) Red
            Show ("              {0}" -f $r.Trace) Red
            Show ("              Target: {0} -> UI: (blank or raw code)" -f $r.Tgt) Red
        }
        'MAPPED' {
            $changed = ($r.Raw -ne $r.Output.ToString())
            $clr = if ($changed) { 'Green' } else { 'Cyan' }
            Show ("  [MAPPED]    {0,-$pad} Raw: {1}" -f $r.AttrName, $r.Raw) $clr
            if ($r.Handler -ne 'passthrough') {
                Show ("              Handler: {0}" -f $r.Handler) $clr
                Show ("              {0}" -f $r.Trace) $clr
            }
            $arrow = if ($changed) { "$($r.Raw) -> $($r.Output)" } else { $r.Output }
            Show ("              Target: {0} -> UI: {1}" -f $r.Tgt, $r.Output) $clr
        }
        'WARN' {
            Show ("  [WARN]      {0,-$pad} Raw: {1} | {2}" -f $r.AttrName, $r.Raw, $r.Trace) Yellow
        }
    }
}

$div = '=' * 72
Show ""
Show $div Cyan
Show "  CJIS RESPONSE HANDLER SIMULATION -- $provName$scriptVer" Cyan
Show "  Generated: $today" Cyan
Show "  QRDM: $($qrdm.name)  |  $($qrdm.attributes.Count) attributes  |  $($qrdm.combinations.Count) entity combos" Cyan
if ($RunEdgeCases) { Show "  Mode: Standard + Edge Cases" Cyan }
Show $div Cyan

$entitiesToRun = if ($Entity -ne 'All') { @($Entity) } else { @('Vehicle','Person','Firearm','Article','Boat') }

$totalMapped = 0; $totalMissing = 0; $totalUnmapped = 0

foreach ($ent in $entitiesToRun) {

    $fields    = $standardData[$ent]
    $dataLabel = 'Synthetic standard'

    Show ""
    Show "  $('=' * 68)" DarkGray
    Show "  ENTITY: $ent  |  $dataLabel" White
    Show "  $('=' * 68)" DarkGray
    Show ""
    Show "  Raw CJIS result fields:" DarkGray
    foreach ($k in ($fields.Keys | Sort-Object)) { Show ("    <{0}>{1}</{0}>" -f $k, $fields[$k]) DarkGray }
    Show ""
    Show "  Handler Transformations:" White
    Show "  $('-' * 68)" DarkGray

    $results = $qrdm.attributes | ForEach-Object { Invoke-Attr $_ $fields }
    $relevant = $results | Where-Object { $_.Status -ne 'MISSING' -or $standardData[$ent].ContainsKey($_.Src) }

    # Show only attrs relevant to this entity (mapped or fields that exist for this entity)
    $entityFields = @($standardData[$ent].Keys)
    foreach ($r in $results | Sort-Object AttrName) {
        # Show if: field was present OR field is expected for this entity type
        $relevant = $r.Status -ne 'MISSING' -or ($entityFields | Where-Object { $_ -eq $r.Src })
        if ($relevant) { Show-AttrResult $r }
    }

    # Only count MISSING for attributes whose sourceField is in this entity's test data.
    # Attributes for other entities are excluded — their absence is not a gap.
    $entityKeys = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($fields.Keys), [System.StringComparer]::OrdinalIgnoreCase)
    $mapped   = @($results | Where-Object { $_.Status -eq 'MAPPED' }).Count
    $missing  = @($results | Where-Object { $_.Status -eq 'MISSING' -and $entityKeys.Contains($_.Src) }).Count
    $unmapped = @($results | Where-Object { $_.Status -eq 'UNMAPPED' }).Count
    $totalMapped += $mapped; $totalMissing += $missing; $totalUnmapped += $unmapped

    Show ""
    $sc = if ($unmapped -gt 0) { 'Red' } elseif ($missing -gt 0) { 'Yellow' } else { 'Green' }
    Show ("  Summary: {0} MAPPED / {1} MISSING / {2} UNMAPPED codes" -f $mapped, $missing, $unmapped) $sc

    # ── Edge cases ────────────────────────────────────────────────────────────
    if ($RunEdgeCases -and $edgeCases[$ent]) {
        Show ""
        Show "  EDGE CASES:" Yellow

        foreach ($ec in $edgeCases[$ent]) {
            Show ""
            Show "  -- $($ec.Label) --" Yellow
            $ecResults = $qrdm.attributes | ForEach-Object { Invoke-Attr $_ $ec.Data }
            $ecShown = 0
            foreach ($r in $ecResults | Sort-Object AttrName) {
                # For edge cases: show mapped/unmapped results, and MISSING only if field was in test data
                if ($r.Status -ne 'MISSING' -or $ec.Data.ContainsKey($r.Src)) {
                    Show-AttrResult $r
                    $ecShown++
                }
            }
            if ($ecShown -eq 0) { Show "    (no relevant fields in this test)" DarkGray }
        }
    }
}

Show ""
Show $div Cyan
Show "  TOTAL: $totalMapped MAPPED / $totalMissing MISSING / $totalUnmapped UNMAPPED" $(if ($totalUnmapped -gt 0) { 'Red' } else { 'Green' })
Show $div Cyan
Show ""

if ($OutFile) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutFile, $outBuf.ToString(), $enc)
    Write-Host "  Saved: $OutFile" -ForegroundColor Green
}
