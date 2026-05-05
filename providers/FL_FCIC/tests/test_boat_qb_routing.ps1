param(
    [string]$Variant = "BASE"
)

$root = (Resolve-Path "$PSScriptRoot\..").Path
$json = if ($Variant -eq 'MC') { "$root\FL_FCIC_MC.json" } else { "$root\FL_FCIC_BASE.json" }
$raw  = Get-Content $json -Raw | ConvertFrom-Json
$log  = "$root\tests\BOAT_QB_ROUTING_TEST_$(Get-Date -Format 'yyyy-MM-dd_HHmm').txt"

$boatQidm = $raw.bundles[1].configurations | Where-Object { $_.query -eq 'BoatQuery' }
$combos   = $boatQidm.combinations

function Test-Scenario {
    param([string]$Name, [hashtable]$Fields, [string]$ExpectedKeyRef, [string]$Why)

    $result = $null
    foreach ($c in $combos) {
        $setOk = $true
        foreach ($f in $c.requirements.set) {
            if (-not $Fields.ContainsKey($f) -or -not $Fields[$f]) { $setOk = $false; break }
        }
        if (-not $setOk) { continue }

        $anyOk = $false
        if ($c.requirements.any.Count -eq 0) { $anyOk = $true }
        foreach ($f in $c.requirements.any) {
            if ($Fields.ContainsKey($f) -and $Fields[$f]) { $anyOk = $true; break }
        }
        if (-not $anyOk) { continue }

        $result = $c
        break
    }

    $fired = if ($result) { $result.keyReference } else { "NONE" }
    $pass  = ($fired -eq $ExpectedKeyRef)
    $mark  = if ($pass) { "PASS" } else { "FAIL" }
    $line  = "[$mark] $Name"
    $det   = "  Fields: $($Fields.Keys -join ', ')  |  Expected: $ExpectedKeyRef  |  Got: $fired"
    $why   = "  Why: $Why"

    Write-Host $line -ForegroundColor $(if ($pass) { 'Green' } else { 'Red' })
    Write-Host $det
    Write-Host $why
    Write-Host ""
    return @{ Name=$Name; Mark=$mark; Expected=$ExpectedKeyRef; Got=$fired; Fields=($Fields.Keys -join ', '); Why=$Why }
}

Write-Host "================================================================"
Write-Host "  FL_FCIC BoatQuery QB Routing Verification"
Write-Host "  JSON: $json"
Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host "  Combos: $($combos.Count)"
Write-Host "================================================================"
Write-Host ""

$results = @()

# --- Scenario 1: Hull only (no stolen flag) -> FBQ (registration) ---
$results += Test-Scenario "Hull only -> FBQ (registration)" @{
    BoatHullIdNumber = "FL1234AB56H7"
    ImageIndicator   = "N"
} -ExpectedKeyRef "FBQBoatHullIdNumber" -Why "No RelatedHitSearchIndicator, no State. FBQ fires (ImageIndicator=N satisfies any[])."

# --- Scenario 2: Hull + Stolen=Y -> QB (NCIC stolen) ---
$results += Test-Scenario "Hull + Stolen=Y -> QB (stolen)" @{
    BoatHullIdNumber          = "FL1234AB56H7"
    RelatedHitSearchIndicator = "Y"
    ImageIndicator            = "N"
} -ExpectedKeyRef "QBBoatHullIdNumber" -Why "RelatedHitSearchIndicator=Y satisfies QB set[]. QB ordered before FBQ."

# --- Scenario 3: Reg only -> FBQ (registration) ---
$results += Test-Scenario "Reg only -> FBQ (registration)" @{
    RegistrationNumber = "FL1234AB"
    ImageIndicator     = "N"
} -ExpectedKeyRef "FBQRegistrationNumber" -Why "No RelatedHitSearchIndicator, no State. FBQ fires."

# --- Scenario 4: Reg + Stolen=Y -> QB (NCIC stolen) ---
$results += Test-Scenario "Reg + Stolen=Y -> QB (stolen)" @{
    RegistrationNumber        = "FL1234AB"
    RelatedHitSearchIndicator = "Y"
    ImageIndicator            = "N"
} -ExpectedKeyRef "QBRegistrationNumber" -Why "RelatedHitSearchIndicator=Y in set[] routes to QB."

# --- Scenario 5: Hull + State -> BQ (Nlets OOS) ---
$results += Test-Scenario "Hull + State -> BQ (OOS)" @{
    BoatHullIdNumber  = "FL1234AB56H7"
    RegistrationState = "GA"
    ImageIndicator    = "N"
} -ExpectedKeyRef "BQBoatHullIdNumber" -Why "State in set[] routes to BQ (Nlets OOS). BQ ordered before QB/FBQ."

# --- Scenario 6: Reg + State -> BQ (Nlets OOS) ---
$results += Test-Scenario "Reg + State -> BQ (OOS)" @{
    RegistrationNumber = "FL1234AB"
    RegistrationState  = "GA"
    ImageIndicator     = "N"
} -ExpectedKeyRef "BQRegistrationNumber" -Why "State in set[] routes to BQ."

# --- Scenario 7: CG# only -> QB (already reachable) ---
$results += Test-Scenario "CG# only -> QB (stolen)" @{
    CoastGuardDocumentNumber = "CG123456"
    ImageIndicator           = "N"
} -ExpectedKeyRef "QBCoastGuardDocumentNumber" -Why "CG# is unique to QB. No routing conflict."

# --- Scenario 8: NCIC# only -> QB ---
$results += Test-Scenario "NCIC# only -> QB (stolen)" @{
    NCICNumber     = "B123456789"
    ImageIndicator = "N"
} -ExpectedKeyRef "QBNCICNumber" -Why "NCICNumber unique to QB."

# --- Scenario 9: PCN only -> QB ---
$results += Test-Scenario "PCN only -> QB (stolen)" @{
    ProcessControlNumber = "0000012345"
    ImageIndicator       = "N"
} -ExpectedKeyRef "QBProcessControlNumber" -Why "PCN unique to QB."

# --- Scenario 10: Decal only -> FBQ ---
$results += Test-Scenario "Decal only -> FBQ (registration)" @{
    DecalNumber    = "FL12345678"
    ImageIndicator = "N"
} -ExpectedKeyRef "FBQDecalNumber" -Why "Decal unique to FBQ."

# --- Scenario 11: Title only -> FBQ ---
$results += Test-Scenario "Title only -> FBQ (registration)" @{
    TitleLienInformation = "ABCD1234"
    ImageIndicator       = "N"
} -ExpectedKeyRef "FBQTitleLienInformation" -Why "Title unique to FBQ."

# --- Scenario 12: Name+DOB+State -> BQ Name ---
$results += Test-Scenario "Name+DOB+State -> BQ Name (OOS)" @{
    NameLast          = "Doe"
    NameFirst         = "John"
    BirthDate         = "1990-01-15"
    RegistrationState = "GA"
    ImageIndicator    = "N"
} -ExpectedKeyRef "BQName" -Why "Name+DOB+State all in BQ Name set[]. BQ ordered first."

# --- Scenario 13: Hull + Stolen=Y + State -> BQ (State takes priority) ---
$results += Test-Scenario "Hull + Stolen + State -> BQ (State wins)" @{
    BoatHullIdNumber          = "FL1234AB56H7"
    RelatedHitSearchIndicator = "Y"
    RegistrationState         = "GA"
    ImageIndicator            = "N"
} -ExpectedKeyRef "BQBoatHullIdNumber" -Why "BQ ordered before QB. State+Hull satisfies BQ set[]. BQ fires first."

# --- Scenario 14: Hull only, no ImageIndicator -> FBQ still fires ---
$results += Test-Scenario "Hull only, ImageIndicator blank -> FBQ (still fires)" @{
    BoatHullIdNumber = "FL1234AB56H7"
} -ExpectedKeyRef "FBQBoatHullIdNumber" -Why "Platform behavior: any[] is NOT a min-one gate. set[] satisfied = combo fires. Confirmed live 2026-05-05."

# --- Scenario 15: Hull + Reg (no state, no stolen) -> FBQ Hull ---
$results += Test-Scenario "Hull + Reg -> FBQ Hull (most specific)" @{
    BoatHullIdNumber   = "FL1234AB56H7"
    RegistrationNumber = "FL1234AB"
    ImageIndicator     = "N"
} -ExpectedKeyRef "FBQBoatHullIdNumber" -Why "Both Hull and Reg filled. FBQ+Hull matches first (combo ordering)."

# ================================================================
# Summary
# ================================================================
$pass = ($results | Where-Object { $_.Mark -eq 'PASS' }).Count
$fail = ($results | Where-Object { $_.Mark -eq 'FAIL' }).Count
$total = $results.Count

Write-Host "================================================================"
Write-Host "  RESULTS: $pass PASS / $fail FAIL  ($total scenarios)"
Write-Host "================================================================"
Write-Host ""

if ($fail -gt 0) {
    Write-Host "FAILURES:" -ForegroundColor Red
    foreach ($r in ($results | Where-Object { $_.Mark -eq 'FAIL' })) {
        Write-Host "  $($r.Name): expected $($r.Expected), got $($r.Got)" -ForegroundColor Red
    }
}

# Write log
$logLines = @()
$logLines += "FL_FCIC BoatQuery QB Routing Verification"
$logLines += "=========================================="
$logLines += "JSON: $json"
$logLines += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$logLines += "Combos: $($combos.Count)"
$logLines += ""
foreach ($r in $results) {
    $logLines += "[$($r.Mark)] $($r.Name)"
    $logLines += "  Fields: $($r.Fields)  |  Expected: $($r.Expected)  |  Got: $($r.Got)"
    $logLines += "  Why: $($r.Why)"
    $logLines += ""
}
$logLines += "RESULTS: $pass PASS / $fail FAIL  ($total scenarios)"
$logLines -join "`n" | Set-Content $log -Encoding UTF8
Write-Host "Log saved: $log"
