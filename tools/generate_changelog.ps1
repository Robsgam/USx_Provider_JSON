<#
  generate_changelog.ps1 -- Per-provider changelog (Markdown) from BUILD_NOTES.txt

  Renders docs/CHANGELOG_<PROVIDER>.md as a clean, deterministic Markdown changelog
  derived from the authoritative docs/<PROVIDER>_BUILD_NOTES.txt version history.
  BUILD_NOTES.txt remains the source of truth (its dates are kept in sync with the
  JSON by sync_version_docs.ps1); this tool just presents it as Markdown for
  Jira/GitHub/release reference.

  Pure function of BUILD_NOTES -> output is reproducible (same input = same bytes,
  apart from the Generated: date line). Wired into build_report.ps1 and re-run by
  sync_version_docs.ps1 after the BUILD_NOTES date checksum.

  Parsing: a version entry is a line starting `v<X.Y>[-SUFFIX] [(]YYYY-MM-DD[)] title`.
  Its body is the immediately-following INDENTED lines (CHANGED/REASON/RESULT blocks),
  stopping at the first blank or non-indented line. Free-form notes between sections
  (not directly under an entry header) are ignored.

  Usage:
    .\generate_changelog.ps1 -Path providers\NJ_NJCJIS\NJ_NJCJIS_v4.6.json
    .\generate_changelog.ps1 -Provider NJ_NJCJIS
    .\generate_changelog.ps1 -Provider NJ_NJCJIS -OutFile out.md
#>

param(
    [string]$Path,
    [string]$Provider,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

# Resolve provider + docs dir from -Path or -Provider
if ($Path) {
    $resolved = (Resolve-Path $Path).Path
    $provDir  = Split-Path $resolved -Parent
    $Provider = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '_v[\d.]+$','' -replace '(?i)_(BASE|MC)$',''
} elseif ($Provider) {
    $provDir = Join-Path $repoRoot "providers\$Provider"
} else {
    Write-Host "  [ERROR] specify -Path <json> or -Provider <name>" -ForegroundColor Red
    exit 1
}

$docsDir   = Join-Path $provDir "docs"
$notesFile = Join-Path $docsDir "${Provider}_BUILD_NOTES.txt"
if (-not $OutFile) { $OutFile = Join-Path $docsDir "CHANGELOG_${Provider}.md" }

if (-not (Test-Path $notesFile)) {
    Write-Host "  [ERROR] BUILD_NOTES not found: $notesFile" -ForegroundColor Red
    exit 1
}

$today = Get-Date -Format "yyyy-MM-dd"

# Header regex: vX.Y or vX.Y-SUFFIX, optional (date) or date, then optional `--`, then title.
$headerRe = '^v(?<ver>\d+\.\d+(?:-[A-Za-z0-9]+)?)\s+\(?(?<date>\d{4}-\d{2}-\d{2})\)?\s*(?:--\s*)?(?<title>.*)$'

$lines = [System.IO.File]::ReadAllLines($notesFile)

# ── Parse version entries ─────────────────────────────────────────────────────
$entries = [System.Collections.Generic.List[object]]::new()
$i = 0
while ($i -lt $lines.Count) {
    $line = $lines[$i]
    $m = [regex]::Match($line, $headerRe)
    if ($m.Success) {
        $body = [System.Collections.Generic.List[string]]::new()
        $j = $i + 1
        while ($j -lt $lines.Count) {
            $bl = $lines[$j]
            if ($bl -match '^\s+\S') { $body.Add($bl); $j++ }
            else { break }   # blank or non-indented line ends the entry body
        }
        $entries.Add([pscustomobject]@{
            Version = $m.Groups['ver'].Value
            Date    = $m.Groups['date'].Value
            Title   = $m.Groups['title'].Value.Trim()
            Body    = $body
        })
        $i = $j
    } else {
        $i++
    }
}

if ($entries.Count -eq 0) {
    # No version history yet (e.g. an incomplete provider). Write a valid stub so the
    # artifact always exists; do not hard-fail the build.
    $stub = @(
        "# $Provider -- Changelog",
        "",
        "Auto-generated from ``${Provider}_BUILD_NOTES.txt`` by ``tools/generate_changelog.ps1``. Do not edit by hand.",
        "",
        "Generated: $today",
        "",
        "---",
        "",
        "_No version history yet._",
        ""
    )
    $enc0 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutFile, ($stub -join "`r`n"), $enc0)
    Write-Host "  [OK] $Provider -- no version entries; wrote stub -> $(Split-Path $OutFile -Leaf)" -ForegroundColor Yellow
    exit 0
}

# ── Render body block to readable Markdown ────────────────────────────────────
function Render-Body($bodyLines) {
    if (-not $bodyLines -or $bodyLines.Count -eq 0) { return @() }
    # Dedent by the smallest leading-whitespace width among non-empty lines
    $indents = $bodyLines | Where-Object { $_ -match '\S' } | ForEach-Object {
        ([regex]::Match($_, '^(\s*)')).Groups[1].Value.Length
    }
    $minIndent = ($indents | Measure-Object -Minimum).Minimum
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($bl in $bodyLines) {
        $t = if ($bl.Length -ge $minIndent) { $bl.Substring($minIndent) } else { $bl.TrimStart() }
        if ($t -match '^(CHANGED|REASON|RESULT|NOTE)(:)?(.*)$') {
            $lbl = $Matches[1]; $colon = $Matches[2]; $rest = $Matches[3]
            $out.Add("**$lbl$colon**$rest")
        } elseif ($t -match '^[-*]\s+') {
            $out.Add(($t -replace '^[*]\s+','- '))
        } else {
            # plain continuation line -- trailing two spaces = Markdown hard break
            $out.Add("$t  ")
        }
    }
    return $out
}

# ── Build Markdown ────────────────────────────────────────────────────────────
$md = [System.Collections.Generic.List[string]]::new()
$md.Add("# $Provider -- Changelog")
$md.Add("")
$md.Add("Auto-generated from ``${Provider}_BUILD_NOTES.txt`` by ``tools/generate_changelog.ps1``. Do not edit by hand.")
$md.Add("")
$md.Add("Current: **v$($entries[0].Version)** | Generated: $today")
$md.Add("")
$md.Add("---")
foreach ($e in $entries) {
    $md.Add("")
    $titlePart = if ($e.Title) { " -- $($e.Title)" } else { "" }
    $md.Add("## v$($e.Version) -- $($e.Date)$titlePart")
    $md.Add("")
    foreach ($b in (Render-Body $e.Body)) { $md.Add($b) }
}
$md.Add("")

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutFile, ($md -join "`r`n"), $enc)
Write-Host "  [OK] $Provider -- $($entries.Count) version entries -> $(Split-Path $OutFile -Leaf)" -ForegroundColor Green
