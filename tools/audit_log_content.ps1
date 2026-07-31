<#
  audit_log_content.ps1 -- saved-log integrity audit: every test log's QUERY STRING must
  satisfy its plan test's FULL fill-set (not identifier-only -- an identifier-only audit
  passed a rotated Firearm log on 2026-07-02), and guardrail logs must show winner-only XML
  (losing identifier absent from the wire). Matching core shared with relabel_batch.ps1
  via _content_match.ps1.

  Exit 0 only when: 0 stale (log label not in plan), 0 mismatch, 0 guardrail wire failures.
  Wired into enforce.ps1 PHASE 6 for providers that have a TEST_PLAN.

  Usage: .\tools\audit_log_content.ps1 -Provider <name> [-Quiet] [-Path <json>]

  -Path overrides ONLY the provider JSON used for the guardrail winner-pool lookup; logs and the
  test plan still come from the provider directory. It exists so audit_gate_efficacy can point the
  guardrail-wire check at a mutated JSON copy (LAW 2 -- a gate that cannot fail is not a gate).
  Same convention as audit_requirement_fidelity.ps1. If -Path is omitted the active root JSON is
  resolved normally, so ordinary runs are unchanged.
#>
param(
    [string]$Provider,
    [switch]$Quiet,
    [string]$Path
)
# -Path alone is enough: derive the provider from the JSON filename so the efficacy harness can
# invoke this gate the same way it invokes every other one (@('-Path',$workJson)).
if (-not $Provider) {
    if (-not $Path) { Write-Host "[audit-log] need -Provider or -Path" -ForegroundColor Red; exit 1 }
    $Provider = [System.IO.Path]::GetFileNameWithoutExtension($Path) -replace '_v[0-9]+\.[0-9]+$', ''
}

. (Join-Path $PSScriptRoot '_content_match.ps1')
. (Join-Path $PSScriptRoot '_sim_helpers.ps1')
. (Join-Path $PSScriptRoot '_resolve_provider_json.ps1')

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

# QIDMs for the winner-pool lookup in the guardrail check below (see the comment there).
$allQidms = @()
$provJsonPath = if ($Path) { $Path } else { Get-ProviderRootJson -ProvDir $provDir -Provider $Provider }
if ($provJsonPath) {
    try {
        $pj = Get-Content $provJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($b in $pj.bundles) { foreach ($c in $b.configurations) {
            if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and "$($c.provider)" -ne 'RMS') { $allQidms += $c }
        } }
    } catch { }
}
# Uppercased set[] u any[] pool of a combo, in BOTH name spaces (attribute name and sourceField),
# so it can be compared against a plan fill's fieldId whichever convention the provider uses.
function Get-WinnerPoolIds($qidm, $combo) {
    $pool = @()
    foreach ($r in @(@($combo.requirements.set) + @($combo.requirements.any)) | Where-Object { $_ }) {
        $pool += "$r".ToUpper()
        $attr = @($qidm.attributes) | Where-Object { $_.name -ieq $r -or (@($_.sourceField) -contains $r) } | Select-Object -First 1
        if ($attr) {
            if ($attr.name) { $pool += "$($attr.name)".ToUpper() }
            foreach ($sf in @($attr.sourceField | Where-Object { $_ })) { $pool += "$sf".ToUpper() }
        }
    }
    return ($pool | Select-Object -Unique)
}

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
        # ...but the winner's BASE combo test is minimum-required-only, so a devdoc-sanctioned
        # OPTIONAL identifier on the winner (an any[] entry) can never show up in $wIdNames -- and
        # was therefore scored as a "losing identifier on the wire". Add the winner combo's real
        # pool (set[] u any[]) from the JSON, which is the authoritative statement of what that
        # combo may legitimately carry.
        #
        # Live-caught NJ_NJCJIS v4.15 Boat, 2026-07-31. devdoc BoatQuery #1 is
        # mand=[BoatHullIdNumber] opt=[ImageIndicator, RegistrationNumber] -- the hull query is
        # EXPLICITLY allowed to carry the registration number, which is exactly why v4.15 put
        # RegistrationNumber in QBN's any[] (Rob's devdoc-order ruling: on a hull+regnum over-fill
        # hull wins AND rides the regnum). The old rule called that a leak. Acting on it would have
        # meant deleting the any[] entry and re-breaking the ruling -- the same error already made
        # once on this exact field (see memory feedback_combo_order_devdoc_is_tiebreaker).
        #
        # This does NOT make the gate unfailable: a losing identifier that is NOT in the winner's
        # pool still FAILs, which is the real signal (wrong combo fired, or the platform over-sent
        # beyond the winner's pool -- LIMITATION #1).
        # NOT gated on $winner. The pool comes from the JSON, which is always present and is the
        # authority on what a combo may carry; $winner is a PLAN lookup that legitimately fails for
        # a combo with no kind='combo' base test. Tying the two together made this exemption silently
        # unavailable for exactly the newest combos -- CA_CLETS v2.23 IR.QVC.O and IR.QVC.OS have 0
        # kind='combo' plan tests, so $wIdNames stayed EMPTY and every identifier in the fill was
        # scored a "loser", producing 5 FAILs that named the WINNER'S OWN set[]/any[] fields as leaks.
        # The diagnostic NOTE was inside this same branch, so nothing explained it either. Found
        # 2026-07-31 mid-sweep; the fix I shipped that morning had this hole from the start.
        if ($allQidms.Count) {
            $wh = Get-ComboByKeyRef $allQidms $t.expectedKeyRef $t.query
            if ($wh) { $wIdNames += (Get-WinnerPoolIds $wh.qidm $wh.combo) }
            else { Out-Line "  [NOTE] $($p.Label): winner combo '$($t.expectedKeyRef)' not resolvable (query='$($t.query)') -- pool exemption unavailable, base-test fills only" 'DarkYellow' }
        }
        $wIdNames = @($wIdNames | Select-Object -Unique)
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
# Detail lines carry an explicit [FAIL] marker and the run always prints a RESULT total. Without
# both, audit_gate_efficacy could not see this gate AT ALL: its vacuous-run detector needs a verdict
# marker or a parseable RESULT to know the gate even looked, and its detection needs [FAIL]/[WARN]
# to know it fired. This gate emitted neither, so registering a mutation against it returned
# [INVALID] baseline VACUOUS -- i.e. one of the four log gates was exempt from mutation testing
# while reporting green (found 2026-07-31).
if ($stale.Count)    { Out-Line "  STALE (label not in plan):" 'Red';    $stale    | ForEach-Object { Out-Line "    [FAIL] $_" 'Red' } }
if ($mismatch.Count) { Out-Line "  MISMATCH (content vs label):" 'Red';  $mismatch | ForEach-Object { Out-Line "    [FAIL] $_" 'Red' } }
if ($guardFail.Count){ Out-Line "  GUARDRAIL WIRE FAIL:" 'Red';          $guardFail| ForEach-Object { Out-Line "    [FAIL] $_" 'Red' } }
# Wording avoids the bare token FAIL: consumers substring-match it, and a summary line saying
# "0 FAIL" read as a failure in test_phase2 the moment this line was added (2026-07-31).
Out-Line ("  RESULT: {0} failing / {1} verified" -f ($stale.Count + $mismatch.Count + $guardFail.Count), $ok) 'Gray'

if ($stale.Count -or $mismatch.Count -or $guardFail.Count) {
    Write-Host "[audit-log] $Provider FAIL: $($stale.Count) stale / $($mismatch.Count) mismatch / $($guardFail.Count) guardrail-wire" -ForegroundColor Red
    exit 1
}
Write-Host "[audit-log] $Provider PASS: $ok/$($parsed.Count) log(s) content-verified" -ForegroundColor Green
exit 0
