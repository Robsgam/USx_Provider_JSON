<#
  audit_metadata_field_coverage.ps1 -- ADVISORY "form behind the metadata" detector.

  For each BUILT query, compares the authoritative metadata field set (from METADATA_REFERENCE.txt's
  "METADATA FIELDS (N)" list) against the fields actually WIRED into that query's QIDM (the
  attributes[].targetField in the JSON PROVIDER bundle). A metadata field with no matching QIDM
  attribute is a candidate "under-exposed" field -- the class of gap that hid on NY's DGRP (10
  metadata fields, only 3 wired) and that no existing gate caught.

  Emits [FIELD-GAP] lines only; ALWAYS exits 0. Advisory -- classification (real gap vs legit skip:
  response-only field, system/paging token, user-approved skip) is a human call. Cross-check a
  flagged field against the devdoc "Possible Values" before acting.

  Usage: audit_metadata_field_coverage.ps1 -Path <provider.json>
#>
param([Parameter(Mandatory)][string]$Path)

$ErrorActionPreference = 'Stop'
$json     = (Resolve-Path $Path).Path
$dir      = Split-Path $json -Parent
$provider = Split-Path $dir -Leaf

# Locate METADATA_REFERENCE.txt (flat docs/ for legacy, docs/reference/ once migrated).
$mrCandidates = @(
    (Join-Path $dir "docs\${provider}_METADATA_REFERENCE.txt"),
    (Join-Path $dir "docs\reference\${provider}_METADATA_REFERENCE.txt")
)
$mrFile = $mrCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $mrFile) {
    Write-Output "[FIELD-GAP] ${provider}: METADATA_REFERENCE.txt not found -- cannot audit field coverage."
    exit 0
}

# --- Parse METADATA_REFERENCE: query -> set of metadata field names ---
$metaByQuery = [ordered]@{}
$curQuery = $null
$inFields = $false
foreach ($line in (Get-Content $mrFile)) {
    if ($line -match '^\s*\d+[a-z]?\.\s+(\S+)\s+\(version') { $curQuery = $Matches[1]; $inFields = $false; continue }
    if ($line -match '^\s*METADATA FIELDS\s*\(') { $inFields = $true; if ($curQuery) { $metaByQuery[$curQuery] = New-Object System.Collections.Generic.List[string] }; continue }
    if ($inFields) {
        if ($line -match '^\s*METADATA COMBINATIONS' -or $line -match '^\s*BUILD COVERAGE' -or $line.Trim() -eq '') { $inFields = $false; continue }
        if ($line -match '^\s+(\S+)\s') { $metaByQuery[$curQuery].Add($Matches[1]) }
    }
}

# --- Parse JSON: query -> set of wired QIDM attribute fields ---
$wiredByQuery = @{}
$obj = Get-Content $json -Raw | ConvertFrom-Json
foreach ($b in $obj.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and $c.query) {
            $set = New-Object System.Collections.Generic.HashSet[string]
            foreach ($a in $c.attributes) {
                $f = if ($a.targetField) { $a.targetField } else { $a.name }
                if ($f) { [void]$set.Add($f) }
            }
            $wiredByQuery[$c.query] = $set
        }
    }
}

# --- Diff: metadata fields not wired into the built QIDM ---
$gaps = 0
foreach ($q in $metaByQuery.Keys) {
    if (-not $wiredByQuery.ContainsKey($q)) { continue }   # query in metadata but not built as a QIDM -> unbuilt (tracked elsewhere)
    $wired = $wiredByQuery[$q]
    $missing = @($metaByQuery[$q] | Where-Object { -not $wired.Contains($_) } | Sort-Object -Unique)
    if ($missing.Count -gt 0) {
        Write-Output "[FIELD-GAP] ${provider}/${q}: metadata field(s) not wired into the QIDM: $($missing -join ', ')"
        $gaps += $missing.Count
    }
}
if ($gaps -eq 0) { Write-Output "[OK] ${provider}: all built queries wire their full metadata field set." }
exit 0
