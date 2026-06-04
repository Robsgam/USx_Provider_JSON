<#
  simulate_response.ps1 -- Provider-specific CJIS result simulator
  DESCRIBED IN: CLAUDE.md (tools table), README.txt

  Tests the inbound path: synthetic CJIS result XML -> CommSys QRDM -> display fields.
  Companion to test_commsys.ps1 (which tests the outbound path).

  Usage:
    .\simulate_response.ps1 -Path providers\TX_TLETS\TX_TLETS.json
    .\simulate_response.ps1 -Path providers\TX_TLETS\TX_TLETS.json -Entity Vehicle
    .\simulate_response.ps1 -Path providers\TX_TLETS\TX_TLETS.json -Entity Person
    .\simulate_response.ps1 -Path providers\TX_TLETS\TX_TLETS.json -OutFile docs\RESULT_SIM_TX_TLETS.txt
    .\simulate_response.ps1 -Path providers\TX_TLETS\TX_TLETS.json -ResultXml "<root><Name>DOE,JOHN</Name>...</root>"
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [ValidateSet('Vehicle','Person','Firearm','Article','Boat','All')]
    [string]$Entity = 'All',
    [string]$ResultType,    # e.g. VehicleRegistration, DriverLicense, StolenVehicle
    [string]$ResultXml,     # optional: supply your own result XML from a live capture
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$jsonPath  = Resolve-Path $Path
$provName  = [System.IO.Path]::GetFileNameWithoutExtension($jsonPath) -replace '_(BASE|MC)$',''
$json      = [System.IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json

# ── Extract CommSys QRDM (provider bundle, not RMS) ──────────────────────────
$provBundle = $json.bundles | Where-Object { $_.provider -ne 'MARK43' -and $_.provider -ne 'RMS' }
$qrdm = $provBundle.configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' } | Select-Object -First 1
if (-not $qrdm) {
    Write-Host "  [ERROR] No CommSys QUERYRESULTDATAMAPPING in $provName" -ForegroundColor Red; exit 1
}

# ── Synthetic result field templates (all fictional test data, no real PII) ───
$tmplVehicle = [ordered]@{
    LicensePlateNumber           = 'TEST123'
    LicensePlateTypeCode         = 'PC'
    LicensePlateYear             = '2026'
    LicensePlateStateCode        = 'TX'
    ImpliedLicensePlateStateCode = 'TX'
    RegistrationState            = 'TX'
    VehicleIdentificationNumber  = '1HGCM82633A004352'
    VehicleMakeCode              = 'HOND'
    VehicleModelCode             = 'CIV'
    VehicleYear                  = '2022'
    VehicleColorCode             = 'BLK'
    VehicleStyleCode             = '4D'
    VehicleTypeCode              = 'PA'
    AutoInsuranceCarrier         = 'STATE FARM'
    ExpirationDate               = '20261231'
    Hit                          = 'Y'
    IntSystemName                = 'NLETS'
    IntInterfaceName             = 'VEHREG'
}

$tmplPerson = [ordered]@{
    Name                         = 'DOE,JOHN ALAN'
    NormalizedNameLast           = 'DOE'
    NormalizedNameFirst          = 'JOHN'
    NormalizedNameMiddle         = 'ALAN'
    BirthDate                    = '19900115'
    SexCode                      = 'M'
    RaceCode                     = 'W'
    EthnicityCode                = 'N'
    Height                       = '511'
    HeightFeet                   = '5'
    HeightInches                 = '11'
    Weight                       = '175'
    HairColor                    = 'BRO'
    HairColorCode                = 'BRO'
    EyeColor                     = 'BRO'
    EyeColorCode                 = 'BRO'
    AddressStreetNumber          = '123'
    AddressStreetName            = 'MAIN ST'
    AddressStreet                = '123 MAIN ST'
    AddressCity                  = 'AUSTIN'
    AddressStateCode             = 'TX'
    AddressZipCode               = '78701'
    SocialSecurityNumber         = '123-45-6789'
    OperatorLicenseNumber        = 'D999888777'
    OperatorLicenseStateCode     = 'TX'
    OperatorLicenseStatusCode    = 'VALID'
    OperatorLicenseRestrictions  = 'NONE'
    OrganDonor                   = 'Y'
    Image                        = 'Y'
    ImageId                      = 'IMG001'
    Hit                          = 'Y'
    IntSystemName                = 'NLETS'
    IntInterfaceName             = 'DLIC'
}

$tmplFirearm = [ordered]@{
    GunSerialNumber = 'GUN12345'
    GunMake         = 'COLT'
    GunModel        = 'M1911'
    GunCaliber      = '45'
    GunTypeCode     = 'PI'
    SerialNumber    = 'GUN12345'
    Hit             = 'Y'
    IntSystemName   = 'NCIC'
    IntInterfaceName= 'GINQ'
}

$tmplArticle = [ordered]@{
    ArticleSerialNumber = 'ART99999'
    ArticleTypeCode     = 'BICY'
    ArticleBrand        = 'TREK'
    ArticleModel        = 'FX3'
    SerialNumber        = 'ART99999'
    Hit                 = 'Y'
    IntSystemName       = 'NCIC'
    IntInterfaceName    = 'AINQ'
}

$tmplBoat = [ordered]@{
    BoatHullIdNumber    = 'FL1234AB56H7'
    BoatSerialNumber    = 'FL1234AB56H7'
    BoatMakeCode        = 'YAMA'
    BoatBrand           = 'YAMAHA'
    BoatName            = 'SEA BREEZE'
    RegistrationState   = 'FL'
    Hit                 = 'Y'
    IntSystemName       = 'NLETS'
    IntInterfaceName    = 'BOAT'
}

# ── Provider-specific extra fields ────────────────────────────────────────────
function Get-ProvExtra($pName, $entType) {
    $extra = [ordered]@{}
    switch ($pName) {
        'TX_TLETS' {
            if ($entType -eq 'Vehicle') {
                $extra['FinancialResponsibilityType'] = 'V'
                $extra['StickerNumber']               = 'TXS12345'
                $extra['RegionId']                    = 'DTJ'
            }
        }
        'FL_FCIC' {
            if ($entType -eq 'Vehicle') {
                $extra['DecalNumber']          = 'DEC2026FL'
                $extra['TitleLienInformation'] = 'LIENHOLDER:CHASE BANK'
            }
        }
        'NJ_NJCJIS' {
            if ($entType -eq 'Vehicle') {
                $extra['NCICNumber']     = 'NC1234567890'
                $extra['Image']         = 'Y'
            }
        }
        'CA_CLETS' {
            $extra['CaRequestPurposeCode'] = 'C'
            if ($entType -eq 'Vehicle') {
                $extra['AddressCity']         = 'LOS ANGELES'
                $extra['AddressStreetNumber'] = '456'
            }
        }
        'NY_NYSPIN_EJUSTICE' {
            if ($entType -eq 'Vehicle') { $extra['Image'] = 'N' }
        }
    }
    return $extra
}

# ── Build XML string from ordered hashtable ───────────────────────────────────
function Build-XmlStr($fields) {
    $lines = @('<CjisResult>')
    foreach ($k in $fields.Keys) { $lines += "  <$k>$($fields[$k])</$k>" }
    $lines += '</CjisResult>'
    return $lines -join "`n"
}

# ── Parse XML into flat hashtable ─────────────────────────────────────────────
function Parse-XmlStr($xmlStr) {
    [xml]$doc = $xmlStr
    $tbl = @{}
    foreach ($node in $doc.DocumentElement.ChildNodes) {
        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            $tbl[$node.LocalName] = $node.InnerText
        }
    }
    return $tbl
}

# ── Map QRDM attributes against result fields ─────────────────────────────────
function Invoke-Mapping($attrs, $tbl) {
    $mapped    = [System.Collections.Generic.List[object]]::new()
    $unreached = [System.Collections.Generic.List[object]]::new()
    foreach ($attr in $attrs) {
        $src = if ($attr.sourceField -is [array]) { $attr.sourceField[0] } else { $attr.sourceField }
        $val = $tbl[$src]
        if ($val) {
            $mapped.Add([PSCustomObject]@{
                AttrName = $attr.name; Src = $src; Val = $val
                Tgt = $attr.targetField
                Rule = if ($attr.rule -and $attr.rule.function) { $attr.rule.function } else { '' }
            })
        } else {
            $unreached.Add([PSCustomObject]@{ AttrName = $attr.name; Src = $src; Tgt = $attr.targetField })
        }
    }
    $allSrc = $attrs | ForEach-Object {
        if ($_.sourceField -is [array]) { $_.sourceField } else { @($_.sourceField) }
    } | Sort-Object | Get-Unique
    $orphans = $tbl.Keys | Where-Object { $_ -notin $allSrc } | Sort-Object
    return @{ Mapped = $mapped; Unreached = $unreached; Orphans = $orphans }
}

# ── Output helper ─────────────────────────────────────────────────────────────
$outBuf = [System.Text.StringBuilder]::new()
function Show($text, $clr = 'White') {
    [void]$outBuf.AppendLine($text)
    Write-Host $text -ForegroundColor $clr
}

$div = '=' * 72
Show ""
Show $div Cyan
Show "  simulate_result -- $provName" Cyan
Show "  QRDM: $($qrdm.name)  |  $($qrdm.attributes.Count) attrs  |  $($qrdm.combinations.Count) combos" Cyan
Show $div Cyan

$entitiesToRun = if ($Entity -ne 'All') { @($Entity) } else { @('Vehicle','Person','Firearm','Article','Boat') }

foreach ($ent in $entitiesToRun) {

    if ($ResultXml) {
        $xmlStr   = $ResultXml
        $typeName = 'Custom (live capture)'
    } else {
        $base = switch ($ent) {
            'Vehicle' { $tmplVehicle }
            'Person'  { $tmplPerson  }
            'Firearm' { $tmplFirearm }
            'Article' { $tmplArticle }
            'Boat'    { $tmplBoat    }
        }
        $flds = [ordered]@{}
        foreach ($k in $base.Keys)                    { $flds[$k] = $base[$k] }
        foreach ($k in (Get-ProvExtra $provName $ent).Keys) { $flds[$k] = (Get-ProvExtra $provName $ent)[$k] }
        $xmlStr   = Build-XmlStr $flds
        $typeName = if ($ResultType) { $ResultType } else { "$ent standard (synthetic)" }
    }

    $tbl    = Parse-XmlStr $xmlStr
    $result = Invoke-Mapping $qrdm.attributes $tbl

    Show ""
    Show "  --- $ent  |  $typeName ---" Yellow
    Show ""
    Show "  Synthetic result fields ($($tbl.Count)):" DarkGray
    foreach ($k in $tbl.Keys | Sort-Object) {
        Show "    <$k>$($tbl[$k])</$k>" DarkGray
    }
    Show ""
    Show "  MAPPING:" White
    Show "  $('-'*70)" DarkGray

    foreach ($m in $result.Mapped | Sort-Object AttrName) {
        $rule = if ($m.Rule) { "  [$($m.Rule)]" } else { '' }
        Show ("  [MAPPED]    {0,-34} {1,-22} -> {2}{3}" -f $m.AttrName, $m.Val, $m.Tgt, $rule) Green
    }
    foreach ($u in $result.Unreached | Sort-Object AttrName) {
        Show ("  [UNREACHED] {0,-34} (not in result -> {1} blank in UI)" -f $u.AttrName, $u.Tgt) DarkYellow
    }
    foreach ($o in $result.Orphans) {
        Show ("  [ORPHAN]    {0,-34} (result field not in QRDM -- ignored by platform)" -f $o) DarkGray
    }

    Show ""
    $mc = $result.Mapped.Count; $uc = $result.Unreached.Count; $oc = @($result.Orphans).Count
    $sc = if ($uc -gt 0) { 'Yellow' } else { 'Green' }
    Show "  Summary: $mc MAPPED / $uc UNREACHED / $oc ORPHAN" $sc
}

Show ""
Show $div Cyan
Show ""

if ($OutFile) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutFile, $outBuf.ToString(), $enc)
    Write-Host "  Saved: $OutFile" -ForegroundColor Green
}
