<#
  check_test_preconditions.ps1
  Cross-checks combo defaults against devdoc conditional field constraints.
  Emits WARN to stderr if a default triggers a "Must be filled if" requirement
  that has no corresponding default or handler in the same QIDM.

  Called by PreToolUse hook before post_test.ps1 invocations, and directly
  from the CLI for manual checks.

  Usage:
    .\check_test_preconditions.ps1 -Provider TX_TLETS -Query DriverHistoryQuery
    .\check_test_preconditions.ps1 -Provider TX_TLETS  (checks all QIDMs)
    .\check_test_preconditions.ps1 -FromHook           (reads PowerShell command from stdin)

  Exit 0 always (warn-only; last-line gate, not a blocker).
#>

param(
    [string]$Provider = "",
    [string]$Query    = "",
    [switch]$FromHook
)

$ErrorActionPreference = "Stop"

# ── Hook mode: parse Provider + Query from post_test.ps1 invocation on stdin ──
if ($FromHook) {
    $stdinJson = $null
    try { $stdinJson = $input | ConvertFrom-Json } catch {}
    if ($stdinJson -and $stdinJson.tool_input -and $stdinJson.tool_input.command) {
        $cmd = $stdinJson.tool_input.command
        if ($cmd -notmatch 'post_test\.ps1') { exit 0 }  # Not a test command — no-op
        if ($cmd -match '-Provider\s+(\S+)') { $Provider = $Matches[1] }
        if ($cmd -match '-Query\s+(\S+)')    { $Query    = $Matches[1] }
    } else { exit 0 }
}

if (-not $Provider) { exit 0 }

# ── Locate provider root ──
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$providerRoot = [System.IO.Path]::Combine($repoRoot, "providers", $Provider)
if (-not (Test-Path $providerRoot)) { exit 0 }

# docs/ reorg pilot (2026-07-01, NJ_NJCJIS first) -- METADATA_REFERENCE is "reference" category.
. "$PSScriptRoot\_resolve_docs_path.ps1"
. "$PSScriptRoot\_resolve_provider_json.ps1"

# ── Load METADATA_REFERENCE.txt to find FIELD CONSTRAINTS ──
$metaRefPath = Find-DocsPath $providerRoot 'reference' "${Provider}_METADATA_REFERENCE.txt"
if (-not (Test-Path $metaRefPath)) { exit 0 }

$mrLines = Get-Content $metaRefPath
$qidmConstraints = @{}
$currentQidm = $null; $inConstraints = $false
foreach ($ml in $mrLines) {
    if ($ml -match '^\d+\.\s+(\w+Query)\s') { $currentQidm = $Matches[1]; $inConstraints = $false }
    elseif ($ml -match '^FIELD CONSTRAINTS') { $inConstraints = $true }
    elseif ($inConstraints -and $ml -match '^\s{2}(.+)') {
        if ($currentQidm) {
            if (-not $qidmConstraints.ContainsKey($currentQidm)) { $qidmConstraints[$currentQidm] = @() }
            $qidmConstraints[$currentQidm] += $Matches[1].Trim()
        }
    }
    elseif ($inConstraints -and ($ml -match '^[A-Z]' -or $ml -match '^={4}')) { $inConstraints = $false }
}

if ($qidmConstraints.Count -eq 0) { exit 0 }

# ── Load provider JSON (resolve versioned/_MC/_BASE, not just bare <PROVIDER>.json) ──
$jsonPath = Get-ProviderRootJson -ProvDir $providerRoot -Provider $Provider
if (-not $jsonPath -or -not (Test-Path $jsonPath)) { exit 0 }

$json = [System.IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json
$provBundle = $json.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' }
if (-not $provBundle) { exit 0 }

# ── Determine which QIDMs to check ──
$targetQidms = if ($Query) { @($Query) } else { @($qidmConstraints.Keys) }

$violations = @()
foreach ($qName in $targetQidms) {
    if (-not $qidmConstraints.ContainsKey($qName)) { continue }
    $constraints = $qidmConstraints[$qName]

    $cfg = $provBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.query -eq $qName }
    if (-not $cfg) { continue }

    # Extract "Must be filled if <TriggerField> = <Value>" patterns
    foreach ($con in $constraints) {
        if ($con -match 'Must be filled if\s+(\w+)\s*=\s*(\S+)') {
            $triggerField = $Matches[1]
            $triggerValue = $Matches[2].TrimEnd('.,;')

            # Find combos that set TriggerField to TriggerValue in defaults[]
            foreach ($combo in $cfg.combinations) {
                $kr = if ($combo.keyReference) { $combo.keyReference } else { $combo.keyRef }
                $defaults = @()
                if ($combo.defaults) { $defaults = @($combo.defaults) }

                $triggerSet = $defaults | Where-Object { $_.field -eq $triggerField -and $_.value -eq $triggerValue }
                if (-not $triggerSet) { continue }

                # Check if any default satisfies a "constrained" field
                # We don't know exactly which field is constrained from the raw devdoc text,
                # so flag the trigger combo for manual review.
                $violations += "  $Provider $qName combo [$kr]: default sets $triggerField=$triggerValue -- verify constrained field has a default or handler per devdoc."
                $violations += "    Constraint text: $con"
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host ""
    Write-Host "WARN: check_test_preconditions.ps1 -- conditional field constraint violations detected" -ForegroundColor Yellow
    foreach ($v in $violations) { Write-Host $v -ForegroundColor Yellow }
    Write-Host "  Action: fix build defaults before running tests (see METADATA_REFERENCE.txt FIELD CONSTRAINTS)." -ForegroundColor Yellow
    Write-Host ""
}

exit 0
