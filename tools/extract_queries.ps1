# extract_queries.ps1
# Parses a ConnectCIC metadata XML and extracts all query transactions,
# fields, and combinations into a structured SQVR-ready tracking file.
#
# Usage: .\extract_queries.ps1 -XmlPath <metadata.xml> [-OutFile <path>] [-QueryFilter <pattern>]
# Example: .\extract_queries.ps1 -XmlPath source\CA_CLETS.xml
# Example: .\extract_queries.ps1 -XmlPath source\CA_CLETS.xml -QueryFilter "DriverLicense|BoatQuery"

param(
    [Parameter(Mandatory)][string]$XmlPath,
    [string]$OutFile,
    [string]$QueryFilter
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $XmlPath)) { Write-Error "File not found: $XmlPath"; return }

# A <Set> can contain a nested <Choice> of 2+ alternative <Set> branches (each representing a
# distinct required-field path under the SAME <Combination>/keyRef -- e.g. NY's RVEH combo has
# an in-state minimal-plate path and an out-of-state plate+year+type+state path, both inside one
# <Combination keyReference="RVEH">). Branches can themselves nest further <Any>/<Choice>
# (confirmed live in NY_NYSPIN_EJUSTICE.XML). Recurse so every alternative path's real fields
# surface, instead of the Choice node being silently skipped (which previously produced an
# empty set[] for the whole combo, or dropped the OOS/expanded path from view entirely).
function Resolve-RequirementPaths {
    param($SetNode)
    $directFields = @()
    $anyFields = @()
    $choiceNode = $null
    foreach ($child in $SetNode.ChildNodes) {
        switch ($child.LocalName) {
            'Field'  { $directFields += $child.reference }
            'Any'    {
                foreach ($af in $child.ChildNodes) {
                    if ($af.LocalName -eq 'Field') { $anyFields += $af.reference }
                }
            }
            'Choice' { $choiceNode = $child }
        }
    }
    if (-not $choiceNode) {
        return @([PSCustomObject]@{ Set = $directFields; Any = $anyFields })
    }
    $paths = @()
    foreach ($altSet in $choiceNode.ChildNodes) {
        if ($altSet.LocalName -ne 'Set') { continue }
        foreach ($sub in (Resolve-RequirementPaths $altSet)) {
            $paths += [PSCustomObject]@{
                Set = @($directFields + $sub.Set)
                Any = @($anyFields + $sub.Any)
            }
        }
    }
    return $paths
}

[xml]$xml = Get-Content $XmlPath -Raw -Encoding UTF8

$fileName = [System.IO.Path]::GetFileNameWithoutExtension($XmlPath)
$lines = @()
$lines += "=" * 78
$lines += "  QUERY TRANSACTIONS IN METADATA (check devdoc for supported query list)"
$lines += "  Source: $(Split-Path $XmlPath -Leaf)"
$lines += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$lines += "=" * 78
$lines += ""

$system = $xml.InterfaceSchema.States.State.Systems.System
if (-not $system) {
    Write-Error "Could not find System element in XML"; return
}

$stateName = $xml.InterfaceSchema.States.State.name
$systemName = $system.name
$lines += "State: $stateName  System: $systemName  Version: $($system.version)"
$lines += ""

# Collect all transactions
$transactions = $system.Transactions.Transaction

# Filter to query types (name ends with "Query") unless overridden
$queryTxns = @()
foreach ($txn in $transactions) {
    $name = $txn.name
    if ($QueryFilter) {
        if ($name -match $QueryFilter) { $queryTxns += $txn }
    } else {
        if ($name -match 'Query$') { $queryTxns += $txn }
    }
}

$lines += "QUERY TRANSACTIONS FOUND: $($queryTxns.Count)"
$lines += "-" * 78

# Group by name prefix -- NO "Basic" or "Supported" labels.
# Which queries are supported is defined by the DEVDOC, not by metadata naming patterns.
$categories = [ordered]@{
    'Standard'                  = @()
    'WMPI'                      = @()
    'CAI (state-prefixed)'      = @()
    'CBI (state-prefixed)'      = @()
    'CCH (state-prefixed)'      = @()
    'Provider-specific'         = @()
}

$standardNames = @(
    'ArticleSingleQuery','BoatQuery','DriverHistoryQuery','DriverLicenseQuery',
    'GunQuery','VehicleRegistrationQuery','VehicleStolenQuery',
    'HazardousMaterialQuery','EISDriverQuery','QueryPassThrough'
)

foreach ($txn in $queryTxns) {
    $name = $txn.name
    if ($name -in $standardNames) {
        $categories['Standard'] += $txn
    } elseif ($name -match '^WMPI') {
        $categories['WMPI'] += $txn
    } elseif ($name -match '^CAI') {
        $categories['CAI (state-prefixed)'] += $txn
    } elseif ($name -match '^CBI') {
        $categories['CBI (state-prefixed)'] += $txn
    } elseif ($name -match '^CCH') {
        $categories['CCH (state-prefixed)'] += $txn
    } else {
        $categories['Provider-specific'] += $txn
    }
}

# Summary table
$lines += ""
$lines += "CATEGORY SUMMARY"
$lines += "-" * 40
foreach ($cat in $categories.Keys) {
    $count = $categories[$cat].Count
    if ($count -gt 0) {
        $names = ($categories[$cat] | ForEach-Object { $_.name }) -join ', '
        $lines += "  $cat ($count):"
        # Wrap long lines
        $wrapped = $names
        if ($wrapped.Length -gt 70) {
            $parts = $names -split ', '
            $current = "    "
            foreach ($p in $parts) {
                if (($current.Length + $p.Length + 2) -gt 76) {
                    $lines += $current.TrimEnd(', ')
                    $current = "    $p, "
                } else {
                    $current += "$p, "
                }
            }
            if ($current.Trim().Length -gt 0) { $lines += $current.TrimEnd(', ') }
        } else {
            $lines += "    $names"
        }
        $lines += ""
    }
}

$lines += "=" * 78
$lines += ""

# Detail for each query
$comboTotal = 0
$pathTotal = 0
foreach ($txn in $queryTxns) {
    $name = $txn.name
    $ver = $txn.version

    $lines += "-" * 78
    $lines += "$name (v$ver)"
    $lines += "-" * 78

    # Fields
    $fields = @()
    if ($txn.Fields -and $txn.Fields.Field) {
        foreach ($f in $txn.Fields.Field) {
            $fields += [PSCustomObject]@{
                Name = $f.name
                Type = $f.type
                MaxLen = $f.maxLength
                Desc = if ($f.description.Length -gt 60) { $f.description.Substring(0,57) + '...' } else { $f.description }
                ValueList = $f.valueListName
            }
        }
    }

    if ($fields.Count -gt 0) {
        $lines += ""
        $lines += "  FIELDS ($($fields.Count)):"
        $maxNameLen = ($fields | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
        if ($maxNameLen -lt 25) { $maxNameLen = 25 }
        $lines += "  " + "Name".PadRight($maxNameLen + 2) + "Type".PadRight(14) + "Size" + "  ValueList"
        $lines += "  " + ("-" * $maxNameLen) + "  " + ("-" * 12) + "  " + "----" + "  " + ("-" * 20)
        foreach ($f in $fields) {
            $vl = if ($f.ValueList) { $f.ValueList } else { '' }
            $lines += "  " + $f.Name.PadRight($maxNameLen + 2) + $f.Type.PadRight(14) + ("$($f.MaxLen)".PadRight(6)) + $vl
        }
    }

    # Combinations
    $combos = @()
    if ($txn.Combinations -and $txn.Combinations.Combination) {
        $comboNodes = @($txn.Combinations.Combination)
        foreach ($c in $comboNodes) {
            $keyRef = $c.keyReference
            $primary = $c.primaryFieldReference

            $paths = @()
            if ($c.Requirements -and $c.Requirements.Set) {
                # @(...) around the call is required, not decorative: PowerShell silently
                # collapses a 1-element array returned from a function back to a bare scalar on
                # assignment, which made $paths.Count (and later $c.Paths.Count) return $null for
                # every non-Choice combo (the common case), mis-routing into the empty-fallback
                # branch below. @() guarantees array-ness for 0/1/N results alike.
                $paths = @(Resolve-RequirementPaths $c.Requirements.Set)
            }

            $combos += [PSCustomObject]@{
                KeyRef = $keyRef
                Primary = $primary
                Paths = $paths
            }
        }
    }

    if ($combos.Count -gt 0) {
        $lines += ""
        $lines += "  COMBINATIONS ($($combos.Count)):"
        $comboTotal += $combos.Count
        $ci = 0
        foreach ($c in $combos) {
            $ci++
            $lines += ""
            $lines += "  $ci. keyRef: $($c.KeyRef)"
            $lines += "     primary: $($c.Primary)"
            if ($c.Paths.Count -le 1) {
                $p = if ($c.Paths.Count -eq 1) { $c.Paths[0] } else { [PSCustomObject]@{ Set = @(); Any = @() } }
                $setStr = ($p.Set -join ', ')
                $anyStr = if ($p.Any.Count -gt 0) { "[" + ($p.Any -join ', ') + "]" } else { '' }
                $lines += "     set: $setStr"
                if ($anyStr) { $lines += "     any: $anyStr" }
            } else {
                # <Choice> gave 2+ alternative required-field paths under this one keyRef --
                # e.g. an in-state path and an out-of-state path. Providers typically build each
                # alternative as its own synthetic keyRef (LIMITATION #21/#36) -- surface all of
                # them here so that split isn't missed at extraction time.
                $lines += "     (Choice -- $($c.Paths.Count) alternative required-field paths; likely built as $($c.Paths.Count) separate synthetic keyRefs)"
                $pi = 0
                foreach ($p in $c.Paths) {
                    $pi++
                    $setStr = ($p.Set -join ', ')
                    $anyStr = if ($p.Any.Count -gt 0) { "[" + ($p.Any -join ', ') + "]" } else { '' }
                    $lines += "       path ${pi}: set: $setStr"
                    if ($anyStr) { $lines += "               any: $anyStr" }
                }
            }
            $pathTotal += [Math]::Max($c.Paths.Count, 1)
        }
    } else {
        $lines += ""
        $lines += "  (no combinations defined)"
    }

    $lines += ""
}

$lines += "=" * 78
if ($pathTotal -ne $comboTotal) {
    $lines += "TOTALS: $($queryTxns.Count) query transactions, $comboTotal XML <Combination> elements, $pathTotal required-field paths (some combos contain a <Choice> of 2+ alternative paths -- see 'likely built as N separate synthetic keyRefs' notes above)"
} else {
    $lines += "TOTALS: $($queryTxns.Count) query transactions, $comboTotal combinations"
}
$lines += "=" * 78

# Output
$output = $lines -join "`r`n"

if ($OutFile) {
    $output | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "Written to: $OutFile"
} else {
    Write-Output $output
}
