<#
  audit_log_content.ps1 -- saved-log integrity audit: every test log's QUERY STRING must
  satisfy its plan test's FULL fill-set (not identifier-only -- an identifier-only audit
  passed a rotated Firearm log on 2026-07-02), and guardrail logs must show winner-only XML
  (losing identifier absent from the wire). Matching core shared with relabel_batch.ps1
  via _content_match.ps1.

  Exit 0 only when: 0 stale (log label not in plan), 0 mismatch, 0 guardrail wire failures.
  Wired into enforce.ps1 PHASE 6 for providers that have a TEST_PLAN.

  Usage: .\tools\audit_log_content.ps1 -Provider <name> [-Quiet]
#>
param(
    [Parameter(Mandatory)][string]$Provider,
    [switch]$Quiet
)

. (Join-Path $PSScriptRoot '_content_match.ps1')

function Out-Line($msg, $color = 'Gray') { if (-not $Quiet) { Write-Host $msg -ForegroundColor $color } }

$provDir = Join-Path (Join-Path $PSScriptRoot '..\providers') $Provider
$planPath = Get-ChildItem (Join-Path $provDir 'logs') -Filter "${Provider}_TEST_PLAN_v*.json" -ErrorAction SilentlyContinue |
            Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
if (-not $planPath) { Write-Host "[audit-log] no TEST_PLAN for $Provider -- nothing to audit (PASS by absence)"; exit 0 }
$plan = Get-Content $planPath -Raw | ConvertFrom-Json
$version = $plan.version

# A label can carry SEVERAL plan tests (two guardrail variants share one file name) --
# keep them all and accept a log matching ANY of them.
$byLabel = @{}
foreach ($t in $plan.tests) { $lbl = Get-CmPlanLabel $t; if (-not $byLabel[$lbl]) { $byLabel[$lbl] = @() }; $byLabel[$lbl] += $t }
$familyFillable = Build-CmFamilyFillable $plan

# Collect logs + parse snapshots first (defaults need the full population).
$logs = @(Get-ChildItem (Join-Path $provDir 'logs') -Recurse -Filter "${Provider}_v${version}_*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]_archive_' })
$parsed = @()
foreach ($f in $logs) {
    $label = $f.BaseName -replace "^$([regex]::Escape("${Provider}_v${version}_"))", ''
    $content = Get-Content $f.FullName -Raw
    $fs = $null
    if ($content -match '(?s)QUERY STRING\s*-+\s*(\{.*?\})') { try { $fs = $Matches[1] | ConvertFrom-Json } catch {} }
    $mt = $null
    if ($content -match '<MessageType>([^<]+)</MessageType>') { $mt = $Matches[1] }
    $parsed += [pscustomobject]@{ File = $f; Label = $label; Fs = $fs; MessageType = $mt; Content = $content }
}
# pscustomobject, NOT hashtable: Windows PowerShell 5.1's Group-Object cannot resolve
# properties on hashtables (defaults map came back empty under enforce's powershell.exe).
# With authoritative plan formDefaults, dynamic dominance is OFF (it blessed vehicleYear
# residue as a "default" and passed mislabeled RQV logs, 2026-07-02).
$defaultsByMt = if ($plan.formDefaults) { @{} }
                else { Build-CmDefaults @($parsed | ForEach-Object { [pscustomobject]@{ messageType = $_.MessageType; fs = $_.Fs } }) }

$stale = @(); $mismatch = @(); $guardFail = @(); $ok = 0
foreach ($p in $parsed) {
    $cands = @($byLabel[$p.Label])
    if (-not $cands.Count) { $stale += "$($p.File.Directory.Name)\$($p.File.Name)"; continue }
    if (-not $p.Fs) { $mismatch += "$($p.Label): no parseable QUERY STRING"; continue }
    $t = $null
    foreach ($cand in $cands) {
        $fd = if ($plan.formDefaults) { $plan.formDefaults.PSObject.Properties[$cand.entity].Value } else { $null }
        if (Test-CmSnapshotMatchesTest $p.Fs $p.MessageType $cand $familyFillable $defaultsByMt $fd) { $t = $cand; break }
    }
    if (-not $t) {
        $mismatch += "$($p.Label): QUERY STRING does not satisfy any plan test with this label"
        continue
    }
    # Guardrail wire check. The LOSING identifiers = the guardrail's identifier fills MINUS
    # the winner base test's identifier fills (a winner like IR.QVC.O legitimately carries
    # BOTH OLN and CII -- "not all ids on the wire" was the wrong rule). Losers must be
    # ABSENT from the XML; winner ids must be PRESENT. Values are matched inside element
    # text (Name serializes as "DOE, JOHN", so exact >VALUE< never matches NameLast=DOE).
    if ($t.kind -eq 'guardrail') {
        $idRe = '(?i)(Number$|^operatorLicense|^nameLast|Serial|Hull|^registrationNumber)'
        $gIds = @($t.fills) | Where-Object { $_ -and $_.fieldId -match $idRe }
        # Scope the winner lookup to the guardrail test's OWN entity: some providers reuse a keyRef
        # across entities (NY Boat & Vehicle both use RVEH/RCAR), so an un-scoped first-match picks
        # the wrong entity's combo (Vehicle RCAR=VIN) and mis-labels the real winner id (Boat
        # RCAR=Hull) as a "losing identifier on the wire" -- a false GUARDRAIL WIRE FAIL.
        $winner = $plan.tests | Where-Object { $_.kind -eq 'combo' -and $_.comboKeyRef -eq $t.expectedKeyRef -and $_.entity -eq $t.entity } | Select-Object -First 1
        if (-not $winner) { $winner = $plan.tests | Where-Object { $_.kind -eq 'combo' -and $_.comboKeyRef -eq $t.expectedKeyRef } | Select-Object -First 1 }
        $wIdNames = @()
        if ($winner) { $wIdNames = @(@($winner.fills) | Where-Object { $_ -and $_.fieldId -match $idRe } | ForEach-Object { $_.fieldId.ToUpper() }) }
        $xmlBody = if ($p.Content -match '(?s)COMMSYS XML\s*-+\s*(.*?)(COMMSYS XML RESPONSE|RMS QUERY|FIELD ANALYSIS)') { $Matches[1] } else { $p.Content }
        # Collision-aware: when a value is a substring of ANOTHER fill's value in the same test
        # (CA boat: RegistrationNumber FL1234AB is a prefix of hull FL1234AB56H7), a loose
        # contains-match false-positives inside the other identifier's element -- use exact
        # element-text equality for such values, loose contains otherwise (Name serializes
        # as 'DOE, JOHN', so NameLast=DOE needs contains).
        $allVals = @(@($t.fills) | Where-Object { $_ } | ForEach-Object { "$($_.value)" })
        $onWire = { param($v)
            $collides = @($allVals | Where-Object { $_ -ne $v -and $_.Contains($v) }).Count -gt 0
            if ($collides) { $xmlBody -match ('>' + [regex]::Escape($v) + '<') }
            else { $xmlBody -match ('>[^<]*' + [regex]::Escape($v) + '[^<]*<') }
        }
        $losers  = @($gIds | Where-Object { $wIdNames -notcontains $_.fieldId.ToUpper() })
        $badLoser  = @($losers | Where-Object { & $onWire $_.value })
        $missWinner = @($gIds | Where-Object { $wIdNames -contains $_.fieldId.ToUpper() } | Where-Object { -not (& $onWire $_.value) })
        if ($badLoser.Count)  { $guardFail += "$($p.Label): losing identifier(s) on the wire: $(($badLoser | ForEach-Object { $_.fieldId }) -join ', ')"; continue }
        if ($missWinner.Count){ $guardFail += "$($p.Label): winning identifier(s) missing from the wire: $(($missWinner | ForEach-Object { $_.fieldId }) -join ', ')"; continue }
    }
    $ok++
}

Out-Line "[audit-log] $Provider v$version -- $($parsed.Count) log(s) vs $($plan.tests.Count) plan test(s)" 'Cyan'
Out-Line "  OK: $ok" 'Green'
if ($stale.Count)    { Out-Line "  STALE (label not in plan):" 'Red';    $stale    | ForEach-Object { Out-Line "    $_" 'Red' } }
if ($mismatch.Count) { Out-Line "  MISMATCH (content vs label):" 'Red';  $mismatch | ForEach-Object { Out-Line "    $_" 'Red' } }
if ($guardFail.Count){ Out-Line "  GUARDRAIL WIRE FAIL:" 'Red';          $guardFail| ForEach-Object { Out-Line "    $_" 'Red' } }

if ($stale.Count -or $mismatch.Count -or $guardFail.Count) {
    Write-Host "[audit-log] $Provider FAIL: $($stale.Count) stale / $($mismatch.Count) mismatch / $($guardFail.Count) guardrail-wire" -ForegroundColor Red
    exit 1
}
Write-Host "[audit-log] $Provider PASS: $ok/$($parsed.Count) log(s) content-verified" -ForegroundColor Green
exit 0
