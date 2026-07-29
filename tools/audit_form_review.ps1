<#
  audit_form_review.ps1 -- has a HUMAN looked at the rendered form for THIS build?

  WHY THIS EXISTS
  ---------------
  Every automated gate in this repo answers "is the request we send correct?". Not one of them
  answers "would an officer understand this form?". Throughout 2026-07 every label, title, card
  and layout defect was caught the same way: Rob opened the rendered form and looked at it.
  Examples that NO tool flagged -- a card titled "NCIC FIREARM QUERY" while every sibling said
  "SEARCH BY <identifier>"; "Sex (optional)" sitting next to "Date of Birth (required with Name)"
  on the same card; a State field stranded in a half-width box; fields wrapping mid-row.

  That makes the visual review the single most productive check in the project AND the only one
  that was never recorded. Nothing said which build had been reviewed, so a provider could ship a
  form nobody had ever seen. This tool makes that step an artifact instead of a habit.

  It deliberately does NOT try to judge the form -- a script cannot. It only asks whether a human
  recorded a review AT THE CURRENT BUILD VERSION.

  ADVISORY BY DESIGN (exit 0 always). It reports [NOTE] for a missing/stale review rather than
  failing, because a review is a human act that cannot be manufactured to satisfy a gate, and
  because a hard fail here would block work on the 14 providers that have never been reviewed.
  Promote it to a blocking gate per-provider when a provider is being prepared to ship.

  RECORD FORMAT -- providers/<P>/docs/tracking/<P>_FORM_REVIEW.txt, one line per review:
    <version> | <yyyy-MM-dd> | <reviewer> | <verdict> | <notes/evidence>
  verdict: APPROVED | CHANGES-REQUESTED
  Append with -Record, or by hand.

  Usage:
    .\audit_form_review.ps1 -Path <provider.json>
    .\audit_form_review.ps1 -Path <provider.json> -Record -Reviewer "Rob" -Verdict APPROVED -Notes "..."
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [switch]$Record,
    [string]$Reviewer,
    [ValidateSet('APPROVED','CHANGES-REQUESTED')][string]$Verdict = 'APPROVED',
    [string]$Notes = '',
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

$jsonPath = (Resolve-Path $Path).Path
$provDir  = Split-Path $jsonPath -Parent
$provName = [IO.Path]::GetFileNameWithoutExtension($jsonPath) -replace '_v[\d.]+$',''
$vm = [regex]::Match([IO.Path]::GetFileName($jsonPath), '_v([0-9]+\.[0-9]+)\.json$')
$version = if ($vm.Success) { "v$($vm.Groups[1].Value)" } else { 'unversioned' }

# 4-category docs layout if present, else flat docs/
$trackingDir = Join-Path $provDir 'docs\tracking'
if (-not (Test-Path $trackingDir)) { $trackingDir = Join-Path $provDir 'docs' }
$recordFile = Join-Path $trackingDir "${provName}_FORM_REVIEW.txt"

$lines = @()
function Emit($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c; $script:lines += $t }

if ($Record) {
    if (-not $Reviewer) { Write-Host "  -Record requires -Reviewer" -ForegroundColor Red; exit 2 }
    if (-not (Test-Path $trackingDir)) { New-Item -ItemType Directory -Path $trackingDir -Force | Out-Null }
    if (-not (Test-Path $recordFile)) {
        $hdr = @(
            "# $provName -- RENDERED FORM REVIEW LOG",
            "# A human opened the rendered form for this build and looked at it. Automated gates",
            "# prove the request is correct; only this proves the form is usable.",
            "# Format: <version> | <yyyy-MM-dd> | <reviewer> | APPROVED|CHANGES-REQUESTED | <notes>",
            "#"
        )
        Set-Content -Path $recordFile -Value $hdr -Encoding utf8
    }
    $safeNotes = ($Notes -replace '\|', '/')
    Add-Content -Path $recordFile -Value "$version | $(Get-Date -Format 'yyyy-MM-dd') | $Reviewer | $Verdict | $safeNotes" -Encoding utf8
    Write-Host "  [OK] recorded $version $Verdict by $Reviewer" -ForegroundColor Green
    exit 0
}

Emit "================================================================"
Emit "  RENDERED FORM REVIEW -- $provName $version"
Emit "================================================================"

if (-not (Test-Path $recordFile)) {
    Emit "  [NOTE] no form-review record exists for this provider." 'DarkYellow'
    Emit "         Automated gates cannot tell whether an officer would understand this form."
    Emit "         Record one:  tools\audit_form_review.ps1 -Path <json> -Record -Reviewer <name>"
} else {
    $recs = @(Get-Content $recordFile | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() })
    $forThis = @($recs | Where-Object { ($_ -split '\|')[0].Trim() -eq $version })
    if ($forThis.Count -eq 0) {
        $latest = if ($recs.Count -gt 0) { ($recs[-1] -split '\|')[0].Trim() } else { 'none' }
        Emit "  [NOTE] no review recorded at $version (most recent reviewed build: $latest)." 'DarkYellow'
        Emit "         Label/layout changes since then have not been seen by a human."
    } else {
        $last = $forThis[-1] -split '\|'
        $v = $last[3].Trim()
        if ($v -eq 'APPROVED') {
            Emit "  [PASS] $version reviewed $($last[1].Trim()) by $($last[2].Trim()) -- APPROVED" 'Green'
        } else {
            Emit "  [NOTE] $version reviewed $($last[1].Trim()) by $($last[2].Trim()) -- CHANGES-REQUESTED" 'DarkYellow'
            if ($last.Count -ge 5 -and $last[4].Trim()) { Emit "         $($last[4].Trim())" }
        }
    }
}

Emit ""
Emit "  Reference: docs/deliverables/OFFICER_GUIDE_$provName.html is the customer-facing view"
Emit "  of the same form; render_html.ps1 / render_layout.ps1 show the build-side view."
Emit "================================================================"

if ($OutFile) {
    $d = Split-Path $OutFile -Parent
    if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}
exit 0
