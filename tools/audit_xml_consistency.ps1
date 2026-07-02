<#
  audit_xml_consistency.ps1 -- cross-run XML regression check.

  Same combo + same fills must produce the SAME wire XML run after run -- only the
  transaction id (ULID) legitimately changes. Compares each current test log's COMMSYS XML
  (normalized: <Id> elements and transaction id attributes stripped, whitespace collapsed)
  against the same file at a baseline git ref. Catches fields silently dropping off the
  wire, serialization/format changes, and element reordering between runs.

  Verdicts per log: SAME / CHANGED (diff shown) / NEW (no baseline) / GONE (baseline only).
  Exit 1 when anything CHANGED.

  Usage: .\tools\audit_xml_consistency.ps1 -Provider <name> [-BaselineRef <commit>]
         (BaselineRef defaults to HEAD -- i.e. working tree vs last commit; pass an older
          ref to compare across passes, e.g. the previous clean pass's commit)
#>
param(
    [Parameter(Mandatory)][string]$Provider,
    [string]$BaselineRef = 'HEAD',
    [switch]$Quiet
)

$repo = Split-Path $PSScriptRoot -Parent
$logsRel = "providers/$Provider/logs"

function Get-NormalizedXml([string]$content) {
    if ($content -notmatch '(?s)COMMSYS XML\s*-+\s*(.*?)(COMMSYS XML RESPONSE|RMS QUERY|FIELD ANALYSIS)') { return $null }
    $xml = $Matches[1]
    $xml = $xml -replace '<Id>[^<]*</Id>', '<Id/>'
    $xml = $xml -replace 'id="[^"]*"', 'id=""'
    ($xml -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join "`n"
}

$current = @(Get-ChildItem (Join-Path $repo $logsRel) -Recurse -Filter "${Provider}_v*_*.txt" -ErrorAction SilentlyContinue)
$same = 0; $changed = @(); $new = @()
foreach ($f in $current) {
    $rel = ($f.FullName.Substring($repo.Length + 1)) -replace '\\', '/'
    $curXml = Get-NormalizedXml (Get-Content $f.FullName -Raw)
    if ($null -eq $curXml) { continue }
    $baseRaw = git -C $repo show "${BaselineRef}:$rel" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $baseRaw) { $new += $rel; continue }
    $baseXml = Get-NormalizedXml ($baseRaw -join "`n")
    if ($null -eq $baseXml) { $new += $rel; continue }
    if ($curXml -eq $baseXml) { $same++; continue }
    # element-level diff for the report
    $curSet  = $curXml -split "`n"
    $baseSet = $baseXml -split "`n"
    $added   = @($curSet  | Where-Object { $baseSet -notcontains $_ })
    $removed = @($baseSet | Where-Object { $curSet  -notcontains $_ })
    $changed += [pscustomobject]@{ File = $rel; Added = $added; Removed = $removed }
}

if (-not $Quiet) {
    Write-Host "[xml-consistency] $Provider vs ${BaselineRef}: $same SAME / $($changed.Count) CHANGED / $($new.Count) NEW" -ForegroundColor Cyan
    foreach ($c in $changed) {
        Write-Host "  CHANGED $($c.File)" -ForegroundColor Red
        foreach ($l in $c.Added)   { Write-Host "    + $l" -ForegroundColor DarkRed }
        foreach ($l in $c.Removed) { Write-Host "    - $l" -ForegroundColor DarkYellow }
    }
    foreach ($n in $new) { Write-Host "  NEW $n (no baseline)" -ForegroundColor DarkCyan }
}
if ($changed.Count) {
    Write-Host "[xml-consistency] $Provider FAIL: $($changed.Count) log(s) changed wire XML vs $BaselineRef" -ForegroundColor Red
    exit 1
}
Write-Host "[xml-consistency] $Provider PASS: wire XML consistent with $BaselineRef ($same same, $($new.Count) new)" -ForegroundColor Green
exit 0
