<#
  _json_canonical.ps1 -- shared canonical JSON serialization + hashing.

  Extracted from get_entity_fingerprints.ps1 so the fingerprinter AND
  audit_reproducible.ps1 use ONE canonicalizer (no drift). Canonical form:
  object keys sorted, array order preserved -> a stable string whose hash only
  changes when meaningful structure changes (whitespace / property-order
  independent).

  Dot-source: . (Join-Path $PSScriptRoot '_json_canonical.ps1')
#>

# Canonical, deterministic serialization: object keys sorted, arrays keep order.
function ConvertTo-Canonical {
    param($o)
    if ($null -eq $o) { return 'null' }
    if ($o -is [bool]) { return $o.ToString().ToLowerInvariant() }
    if ($o -is [string]) { return '"' + ($o -replace '\\','\\\\' -replace '"','\"') + '"' }
    if ($o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) { return [string]$o }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) {
        $items = @($o | ForEach-Object { ConvertTo-Canonical $_ })
        return '[' + ($items -join ',') + ']'
    }
    if ($o -is [System.Management.Automation.PSCustomObject] -or $o.PSObject.Properties.Count -gt 0) {
        $props = @($o.PSObject.Properties | Sort-Object Name)
        $parts = foreach ($p in $props) { '"' + $p.Name + '":' + (ConvertTo-Canonical $p.Value) }
        return '{' + ($parts -join ',') + '}'
    }
    return '"' + [string]$o + '"'
}

function Get-Sha256Hex {
    param([string]$s)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
        return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    } finally { $sha.Dispose() }
}

# Recursively clone a parsed-JSON object, normalizing INTENTIONALLY time-/version-
# variant fields so a reproducibility comparison does not false-flag them:
#   - top-level `version` property is dropped (added by Write-ProviderJson; a
#     same-content rebuild of a pre-version JSON would otherwise always "differ").
#   - any layout node carrying a plate-year fieldId has its initialValue replaced
#     with <YEAR> (PlateYear = current year by design -> reproducible only within
#     a calendar year; normalizing keeps the gate stable across Jan 1).
# Pass -Top on the root call so the version drop only applies at top level.
function New-NormalizedClone {
    param($o, [switch]$Top)
    if ($null -eq $o) { return $null }
    if ($o -is [string] -or $o -is [bool] -or $o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) {
        return $o
    }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) {
        return @($o | ForEach-Object { New-NormalizedClone $_ })
    }
    if ($o.PSObject -and $o.PSObject.Properties.Count -gt 0) {
        # Detect a plate-year layout node: has a fieldId matching plate year + an initialValue.
        $fieldIdProp = $o.PSObject.Properties['fieldId']
        $isPlateYearNode = $false
        if (-not $fieldIdProp) {
            # Craft.js nodes nest fieldId under .props
            $propsProp = $o.PSObject.Properties['props']
            if ($propsProp -and $propsProp.Value -and $propsProp.Value.PSObject.Properties['fieldId']) {
                $fieldIdProp = $propsProp.Value.PSObject.Properties['fieldId']
            }
        }
        if ($fieldIdProp -and "$($fieldIdProp.Value)" -match '(?i)(licensePlateYear|plateYear)') { $isPlateYearNode = $true }

        $clone = [ordered]@{}
        foreach ($p in $o.PSObject.Properties) {
            if ($Top -and $p.Name -eq 'version') { continue }   # drop top-level version
            $val = $p.Value
            if ($p.Name -eq 'initialValue' -and $isPlateYearNode) {
                $clone[$p.Name] = '<YEAR>'
            } elseif ($p.Name -eq 'props' -and $isPlateYearNode -and $val -and $val.PSObject.Properties['initialValue']) {
                # normalize initialValue inside a props sub-object too
                $sub = [ordered]@{}
                foreach ($pp in $val.PSObject.Properties) {
                    $sub[$pp.Name] = if ($pp.Name -eq 'initialValue') { '<YEAR>' } else { New-NormalizedClone $pp.Value }
                }
                $clone[$p.Name] = [pscustomobject]$sub
            } else {
                $clone[$p.Name] = New-NormalizedClone $val
            }
        }
        return [pscustomobject]$clone
    }
    return $o
}

# Read a JSON file and return its canonical string. -Normalize applies
# New-NormalizedClone (drop top-level version, normalize plate year).
function Get-CanonicalJsonString {
    param([Parameter(Mandatory)][string]$Path, [switch]$Normalize)
    $obj = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Normalize) { $obj = New-NormalizedClone $obj -Top }
    return (ConvertTo-Canonical $obj)
}
