<#
  compare_captures.ps1 -- validate that the browser automation reproduces the SAME query as a
  trusted reference, WITHOUT importing anything. Comparison-only.

  For each record in an automation capture file (usx_captured_*.json), find the matching reference
  -- either an existing committed test log in providers/<P>/tests/ (default) or a second capture
  file (-ReferenceFile, e.g. yesterday's recovered NJ logs) -- and diff the ConnectCic <Request>
  field set, normalizing out the per-run Transaction id + <Id>. Reports MATCH / DIFF per combo.

  Use FL_FCIC (trusted logs) to prove the process; use a recovered-yesterday capture as the
  reference for NJ before its clean full re-run.

  Usage:
    .\compare_captures.ps1 -CaptureFile <auto.json> -Provider FL_FCIC
    .\compare_captures.ps1 -CaptureFile <rerun.json> -ReferenceFile <recovered.json>
#>

param(
    [Parameter(Mandatory)][string]$CaptureFile,
    [string]$Provider,
    [string]$ReferenceFile
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

function Get-CicXml([string]$text) {
    if (-not $text) { return $null }
    $m = [regex]::Match($text, '<\?xml[\s\S]*?</api:ConnectCicApi>')
    if (-not $m.Success) { $m = [regex]::Match($text, '<api:ConnectCicApi[\s\S]*?</api:ConnectCicApi>') }
    if ($m.Success) { return $m.Value } else { return $null }
}
# Field set of the <Request>, excluding the volatile <Id> (per-run transaction id).
function Get-FieldSet([string]$xml) {
    $set = [ordered]@{}
    if (-not $xml) { return $set }
    $req = [regex]::Match($xml, '<Request>([\s\S]*?)</Request>')
    $scope = if ($req.Success) { $req.Groups[1].Value } else { $xml }
    foreach ($mm in [regex]::Matches($scope, '<(\w+)>([^<]*)</\1>')) {
        $name = $mm.Groups[1].Value; if ($name -eq 'Id') { continue }
        $set[$name] = $mm.Groups[2].Value
    }
    return $set
}
function Compare-Sets($a, $b) {
    $diffs = @()
    foreach ($k in $a.Keys) { if (-not $b.Contains($k)) { $diffs += "auto-only: $k=$($a[$k])" } elseif ($a[$k] -ne $b[$k]) { $diffs += "differ: $k auto=$($a[$k]) ref=$($b[$k])" } }
    foreach ($k in $b.Keys) { if (-not $a.Contains($k)) { $diffs += "ref-only: $k=$($b[$k])" } }
    return $diffs
}

$caps = @(Get-Content $CaptureFile -Raw | ConvertFrom-Json)

# Build the reference index: keyRef-ish token -> XML.
$refIndex = @()   # list of @{ key=<lowercased filename or combo>; xml=... }
if ($ReferenceFile) {
    foreach ($r in @(Get-Content $ReferenceFile -Raw | ConvertFrom-Json)) {
        $x = Get-CicXml $r.requestXml
        if ($x) { $refIndex += @{ key = ("" + $r.comboKeyRef + " " + $r.combo).ToLower(); xml = $x; label = "$($r.comboKeyRef)" } }
    }
} elseif ($Provider) {
    $testsDir = Join-Path $repoRoot "providers\$Provider\tests"
    foreach ($f in (Get-ChildItem $testsDir -Filter '*.txt' -File -ErrorAction SilentlyContinue)) {
        $x = Get-CicXml ([System.IO.File]::ReadAllText($f.FullName))
        if ($x) { $refIndex += @{ key = $f.Name.ToLower(); xml = $x; label = $f.Name } }
    }
} else {
    Write-Host "  [ERROR] supply -Provider or -ReferenceFile" -ForegroundColor Red; exit 1
}

Write-Host ""
Write-Host "  Comparing $($caps.Count) captured record(s) vs $(if($ReferenceFile){'reference file'}else{"$Provider logs"}) ($($refIndex.Count) ref XMLs)" -ForegroundColor Cyan

$match = 0; $diff = 0; $noref = 0
foreach ($c in $caps) {
    $kr = "$($c.comboKeyRef)"; if (-not $kr) { $kr = "$($c.combo)" }
    $autoXml = Get-CicXml $c.requestXml
    if (-not $autoXml) { Write-Host "  [SKIP] capture has no XML (combo=$kr)" -ForegroundColor DarkYellow; continue }

    # Match a reference whose key contains the keyRef; prefer same MessageType.
    $autoMt = ([regex]::Match($autoXml, '<MessageType>([^<]+)</MessageType>')).Groups[1].Value
    $cand = $refIndex | Where-Object { $kr -and $_.key.Contains($kr.ToLower()) }
    if (-not $cand) { $cand = $refIndex | Where-Object { (Get-FieldSet $_.xml)['MessageType'] -eq $autoMt } }
    $ref = $cand | Select-Object -First 1
    if (-not $ref) { Write-Host "  [NO REF] $kr ($autoMt) -- no matching reference" -ForegroundColor DarkYellow; $noref++; continue }

    $d = Compare-Sets (Get-FieldSet $autoXml) (Get-FieldSet $ref.xml)
    if ($d.Count -eq 0) {
        Write-Host "  [MATCH] $kr ($autoMt)  vs  $($ref.label)" -ForegroundColor Green; $match++
    } else {
        Write-Host "  [DIFF]  $kr ($autoMt)  vs  $($ref.label)" -ForegroundColor Red
        foreach ($line in $d) { Write-Host "            $line" -ForegroundColor DarkYellow }
        $diff++
    }
}

Write-Host ""
Write-Host "  Result: $match MATCH / $diff DIFF / $noref no-ref" -ForegroundColor Cyan
if ($diff -gt 0) { exit 1 } else { exit 0 }
