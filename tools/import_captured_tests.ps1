<#
  import_captured_tests.ps1 -- ingest browser-captured test records into post_test.ps1.

  The automation extension (automation/extension/) downloads usx_captured_*.json files,
  each an array of records:
    { provider, entity, query, combo, tier, expectedKeyRef, messageType,
      transactionId, requestXml, formState, rmsRequestJson, rmsResponse, capturedAt }

  This script feeds each record to post_test.ps1 -- which stamps JSON Version + Entity
  Fingerprint + Tier and writes the log. Result is computed: PASS when the fired query
  (messageType in the captured XML) matches the intended query, else FAIL.

  Usage:
    .\import_captured_tests.ps1                       # newest usx_captured_*.json in ~/Downloads
    .\import_captured_tests.ps1 -Path C:\path\file.json
    .\import_captured_tests.ps1 -Path C:\dir          # all usx_captured_*.json in a dir
    .\import_captured_tests.ps1 -Commit               # commit+push after importing
#>

param(
    [string]$Path,
    [switch]$Commit,
    [switch]$KeepSource   # copy (not move) the source capture when archiving
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path

# query -> entity fallback (records from the driver already carry entity).
$QueryEntity = @{
    'VehicleRegistrationQuery' = 'Vehicle'; 'VehicleStolenQuery' = 'Vehicle'
    'DriverLicenseQuery' = 'Person'; 'DriverHistoryQuery' = 'Person'
    'GunQuery' = 'Firearm'; 'ArticleSingleQuery' = 'Article'; 'BoatQuery' = 'Boat'
}

# Combo inference for captures that carry no combo (e.g. recovered existing dex-log entries):
# the firing combo is the one whose ENTIRE set[] appears as elements in the request XML; the
# most-specific (most set fields) wins. Lets us recover arbitrary tenant queries.
. "$toolDir\_resolve_provider_json.ps1"
$script:jsonCache = @{}
function Get-ProviderJsonCached($provider) {
    if ($script:jsonCache.ContainsKey($provider)) { return $script:jsonCache[$provider] }
    $pd = Join-Path $repoRoot "providers\$provider"
    $jp = Get-ProviderRootJson -ProvDir $pd -Provider $provider
    $o = $null; if ($jp) { try { $o = Get-Content $jp -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
    $script:jsonCache[$provider] = $o; return $o
}
function Get-QidmForQuery($provider, $query) {
    $o = Get-ProviderJsonCached $provider; if (-not $o) { return $null }
    foreach ($b in $o.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and $c.handlerFunction -eq 'CommsysTransactionRequestHandler' -and $c.query -eq $query) { return $c }
    } }
    return $null
}
function Infer-ComboFromXml($provider, $query, $xml) {
    $qidm = Get-QidmForQuery $provider $query; if (-not $qidm) { return $null }
    $present = @{}; foreach ($mt in [regex]::Matches($xml, '<(\w+)>')) { $present[$mt.Groups[1].Value.ToLower()] = $true }
    $best = $null; $bestScore = -1
    foreach ($c in $qidm.combinations) {
        $set = @($c.requirements.set); if (-not $set) { continue }
        $allPresent = $true; $score = 0
        foreach ($s in $set) {
            $elem = $s
            $attr = $qidm.attributes | Where-Object { $_.name -ieq $s -or (@($_.sourceField) -contains $s) } | Select-Object -First 1
            # targetField (not name) drives wire serialization -- attribute NAME can be made
            # unique/synthetic (e.g. OperatorLicenseNumberDH) purely so a NOT_EXISTS guardrail
            # condition can reference it without colliding with a sibling combo's same-named
            # attribute (FL_FCIC build script v5.1). Using .name here mis-inferred the combo
            # for every such field (FL_FCIC KQOperatorLicenseNumber guardrail, 2026-07-02).
            if ($attr) { $elem = if ($attr.targetField) { $attr.targetField } else { $attr.name } }
            if ($present.ContainsKey($elem.ToLower()) -or $present.ContainsKey($s.ToLower())) { $score++ } else { $allPresent = $false }
        }
        if ($allPresent -and $score -gt $bestScore) { $best = $c; $bestScore = $score }
    }
    if ($best) { if ($best.keyReference) { return $best.keyReference } else { return $best.keyRef } }
    return $null
}
# Infer whether a captured record is a base combo, any-field, or any test by checking
# which optional (any[]) fields appear in the XML beyond the required set[] fields.
# Returns @{ kind; anyField } or null if QIDM / combo not found.
function Infer-TestKindFromXml($provider, $query, $inferredCombo, $xml) {
    $qidm = Get-QidmForQuery $provider $query; if (-not $qidm) { return $null }
    $comboObj = $qidm.combinations | Where-Object { $kr = if ($_.keyReference) { $_.keyReference } else { $_.keyRef }; $kr -eq $inferredCombo } | Select-Object -First 1
    if (-not $comboObj) { return $null }
    $anyNames = @($comboObj.requirements.any); if (-not $anyNames) { return @{ kind='combo'; anyField=$null } }
    $present = @{}; foreach ($mt in [regex]::Matches($xml, '<(\w+)>')) { $present[$mt.Groups[1].Value.ToLower()] = $true }
    $optPresent = @()
    foreach ($af in $anyNames) {
        $elem = $af
        $attr = $qidm.attributes | Where-Object { $_.name -ieq $af -or (@($_.sourceField) -contains $af) } | Select-Object -First 1
        if ($attr) { $elem = if ($attr.targetField) { $attr.targetField } else { $attr.name } }
        if ($present.ContainsKey($elem.ToLower()) -or $present.ContainsKey($af.ToLower())) { $optPresent += $af }
    }
    if ($optPresent.Count -eq 0) { return @{ kind='combo'; anyField=$null } }
    if ($optPresent.Count -eq 1) { return @{ kind='any-field'; anyField=$optPresent[0] } }
    return @{ kind='any'; anyField=$null }
}

# --- Resolve input files ---
if (-not $Path) { $Path = Join-Path $env:USERPROFILE 'Downloads' }
$files = @()
if (Test-Path $Path -PathType Container) {
    $files = Get-ChildItem $Path -Filter 'usx_captured_*.json' -File | Sort-Object LastWriteTime
    if (-not $files) { Write-Host "  [ERROR] No usx_captured_*.json in $Path" -ForegroundColor Red; exit 1 }
} elseif (Test-Path $Path -PathType Leaf) {
    $files = @(Get-Item $Path)
} else {
    Write-Host "  [ERROR] Path not found: $Path" -ForegroundColor Red; exit 1
}

Write-Host ""
Write-Host "  Importing captured tests from $($files.Count) file(s)" -ForegroundColor Cyan

$imported = 0; $failed = 0; $skipped = 0; $errored = 0
foreach ($file in $files) {
    $records = @()
    # ASSIGN the ConvertFrom-Json result to a variable BEFORE wrapping in @(). In Windows
    # PowerShell 5.1, `@(Get-Content -Raw | ConvertFrom-Json)` on a JSON array collapses to a
    # SINGLE element (the whole array), so `foreach ($r in $records)` then iterates once with
    # $r = the entire array -> every field is array-valued -> post_test's -Tier arg-transform
    # throws and 0 records import. pwsh 7 enumerates fine, which is why it only broke under the
    # 5.1 watcher. Assign-first ($parsed) then @($parsed) yields the correct N records in both.
    try { $parsed = Get-Content $file.FullName -Raw | ConvertFrom-Json; $records = @($parsed) } catch { Write-Host "  [SKIP] bad JSON: $($file.Name)" -ForegroundColor DarkYellow; $skipped++; continue }

    # Content-based relabel: browser labels are unreliable; formState is ground truth.
    try { & (Join-Path $PSScriptRoot 'relabel_batch.ps1') -BatchPath $file.FullName *>&1 | ForEach-Object { Write-Host "  $_" } } catch { Write-Host "  [WARN] relabel errored (importing as-is): $_" -ForegroundColor DarkYellow }
    try { $parsed = Get-Content $file.FullName -Raw | ConvertFrom-Json; $records = @($parsed) } catch { Write-Host "  [SKIP] bad JSON after relabel: $($file.Name)" -ForegroundColor DarkYellow; $skipped++; continue }

    foreach ($r in $records) {
        $entity = $r.entity; if (-not $entity -and $r.query -and $QueryEntity.ContainsKey($r.query)) { $entity = $QueryEntity[$r.query] }
        $combo = $r.combo
        if (-not $combo -and $r.requestXml -and $r.query) {
            $combo = Infer-ComboFromXml $r.provider $r.query $r.requestXml
            if ($combo) { Write-Host "  [infer] combo=$combo (from XML)" -ForegroundColor DarkCyan }
        }
        if (-not ($r.provider -and $entity -and $r.query -and $combo -and $r.requestXml)) {
            Write-Host "  [SKIP] record missing provider/entity/query/combo/requestXml (query=$($r.query) combo=$combo)" -ForegroundColor DarkYellow
            $skipped++; continue
        }

        # PASS when the query that actually fired (messageType in the XML) matches intent.
        $fired = $r.messageType
        $result = if ($fired -and ($fired -eq $r.query)) { 'PASS' } else { 'FAIL' }
        # Resolve test kind: use explicit kind from record (labeled capture), else infer from XML.
        $testKind = $r.kind; $testAnyField = $r.anyField
        if (-not $testKind -and $combo -and $r.requestXml) {
            $ki = Infer-TestKindFromXml $r.provider $r.query $combo $r.requestXml
            if ($ki) { $testKind = $ki.kind; $testAnyField = $ki.anyField }
        }
        # Unique combo label per test kind so any-field/guardrail tests don't overwrite the base
        # combo log. Guardrail's combo is inferred from the XML (the WINNER fires; combo/comboKeyRef
        # is null by design in emit_test_plan.ps1 -- expectedKeyRef carries the winner instead), so
        # without this suffix a guardrail capture lands on the SAME filename as the winner's plain
        # combo test and silently overwrites it (found live, NJ v4.8 -- 3 logs clobbered this way).
        $comboLabel = $combo
        if ($testKind -eq 'any-field' -and $testAnyField) { $comboLabel = "${combo}_af_${testAnyField}" }
        elseif ($testKind -eq 'any') { $comboLabel = "${combo}_any" }
        elseif ($testKind -eq 'guardrail') {
            # guardrailLoser (stamped by relabel_batch.ps1 from the matched plan test) disambiguates
            # the rare case where >1 loser combo resolves to the SAME winner -- e.g. FL_FCIC Boat's
            # relatedHitSearchIndicator routes Hull between the FBQ and QB combo families, and both
            # "Hull wins" scenarios simulate to the same expectedKeyRef (2026-07-02).
            $comboLabel = if ($r.guardrailLoser) { "${combo}_guardrail_vs_$($r.guardrailLoser)" } else { "${combo}_guardrail" }
        }
        $underFilledNote = if ($r.underFilled) { ' UNDER-FILLED (a form field failed to fill on submit -- verify this combo).' } else { '' }
        $note = "Automated capture (txId $($r.transactionId)). kind=${testKind}; anyField=${testAnyField}; expectedKeyRef=$($r.expectedKeyRef); firedMessageType=$fired.$underFilledNote"
        $desc = "$comboLabel (auto)"

        $ptArgs = @{
            Provider = $r.provider; Entity = $entity; Query = $r.query
            Combo = $comboLabel; Result = $result; Description = $desc
            XmlRequest = $r.requestXml; Notes = $note; NoCommit = $true
        }
        # formState is a STRING already containing JSON in the standard bulk-fetch capture batch
        # (verified against the raw capture file: "formState": "{\"Key\":\"Value\"}") -- pass it
        # through as-is. Only ConvertTo-Json if some other capture path (e.g. individual popup
        # captures) ever hands us a live PSCustomObject/hashtable instead of a pre-serialized
        # string -- ConvertTo-Json on an already-JSON string double-encodes it (wraps + escapes),
        # which is exactly what broke HI_HCJDC_OFML's v4.9 retest batch (46/46 "no parseable
        # QUERY STRING" -- caught 2026-07-17, see feedback_no_double_json_encode_formstate).
        if ($r.formState) {
            $ptArgs['FormState'] = if ($r.formState -is [string]) { $r.formState } else { $r.formState | ConvertTo-Json -Depth 8 -Compress }
        }
        if ($r.tier)      { $ptArgs['Tier'] = $r.tier }
        # RMS pair (Person/Vehicle only -- absent for Gun/Article/Boat/DH is normal, not a gap).
        if ($r.rmsRequestJson) { $ptArgs['RmsRequestJson'] = ($r.rmsRequestJson | ConvertTo-Json -Depth 8 -Compress) }
        if ($r.rmsResponse)    { $ptArgs['RmsResponse'] = $r.rmsResponse }

        $color = if ($result -eq 'PASS') { 'Green' } else { 'Red' }
        if ($r.underFilled) { Write-Host "  [under-filled] $($r.provider)/$entity $($r.query) $comboLabel" -ForegroundColor DarkYellow }
        Write-Host "  -> $($r.provider)/$entity $($r.query) $combo => $result" -ForegroundColor $color
        # Guard: one bad record must not abort the whole batch (script runs ErrorAction Stop).
        try {
            & (Join-Path $toolDir 'post_test.ps1') @ptArgs | Out-Null
            if ($result -eq 'PASS') { $imported++ } else { $failed++ }
        } catch {
            Write-Host "  [ERROR] post_test failed for ${comboLabel}: $_" -ForegroundColor Red
            $errored++
        }
    }

    # Archive the raw capture into the repo (timestamped) for traceability; clears Downloads.
    $arch = Join-Path $repoRoot 'automation\captures'
    if (-not (Test-Path $arch)) { New-Item -ItemType Directory -Path $arch -Force | Out-Null }
    $dest = Join-Path $arch ((Get-Date -Format 'yyyy-MM-dd_HHmmss') + '_' + $file.Name)
    if ($KeepSource) { Copy-Item $file.FullName $dest -Force } else { Move-Item $file.FullName $dest -Force }
    Write-Host "  archived -> automation/captures/$(Split-Path $dest -Leaf)" -ForegroundColor Gray
}

Write-Host ""
$summary = "  Imported: $imported PASS / $failed FAIL / $skipped skipped"
if ($errored -gt 0) { $summary += " / $errored errored" }
Write-Host $summary -ForegroundColor Cyan
if ($errored -gt 0) { Write-Host "  [WARN] $errored record(s) errored in post_test -- batch continued; re-check those." -ForegroundColor Yellow }

if ($Commit -and ($imported + $failed) -gt 0) {
    Push-Location $repoRoot
    # Native git commands write routine info (e.g. CRLF autocrlf notices) to stderr. Under the
    # script-wide $ErrorActionPreference = "Stop", PowerShell promotes ANY stderr line from a
    # native command into a terminating error, so a harmless git warning was aborting this block
    # before `git commit`/`git push` ever ran -- tests looked "committed" (no visible failure)
    # but silently stayed local. Scope ErrorActionPreference down to 'Continue' for these calls
    # and gate success on $LASTEXITCODE instead of exception-catching stderr noise.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        git add -- providers automation/captures 2>&1 | Out-Null
        git commit -m "Import automated USx Tenant Testing captures ($imported PASS / $failed FAIL)`n`nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" 2>&1 | Out-Null
        $commitExit = $LASTEXITCODE
        git push 2>&1 | Out-Null
        $pushExit = $LASTEXITCODE
        if ($commitExit -eq 0 -and $pushExit -eq 0) {
            Write-Host "  Git: committed + pushed" -ForegroundColor Gray
        } else {
            Write-Host "  [WARN] git step failed: commit exit=$commitExit push exit=$pushExit" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [WARN] git step failed: $_" -ForegroundColor Yellow
    } finally {
        $ErrorActionPreference = $prevEap
        Pop-Location
    }
}
exit 0
