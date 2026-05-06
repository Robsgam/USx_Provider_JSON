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

[xml]$xml = Get-Content $XmlPath -Raw -Encoding UTF8

$fileName = [System.IO.Path]::GetFileNameWithoutExtension($XmlPath)
$lines = @()
$lines += "=" * 78
$lines += "  SUPPORTED QUERIES EXTRACTED FROM METADATA"
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

# Categorize by ConnectCIC query type
$categories = [ordered]@{
    'Basic Queries'    = @()
    'CAI (In-State)'   = @()
    'CBI (Canadian)'   = @()
    'CCH (Criminal History)' = @()
    'Expanded'         = @()
    'Other'            = @()
}

$basicNames = @(
    'ArticleSingleQuery','BoatQuery','DriverHistoryQuery','DriverLicenseQuery',
    'GunQuery','VehicleRegistrationQuery','HazardousMaterialQuery','QueryPassThrough',
    'EISDriverQuery'
)
$wmpiNames = @('WMPIWantedPersonQuery','WMPIMissingPersonQuery','WMPIProtectionOrderQuery',
    'WMPISexOffenderQuery','WMPISupervisedReleaseQuery','WMPIUnidentifiedPersonQuery')

foreach ($txn in $queryTxns) {
    $name = $txn.name
    if ($name -in $basicNames -or $name -in $wmpiNames) {
        $categories['Basic Queries'] += $txn
    } elseif ($name -match '^CAI') {
        $categories['CAI (In-State)'] += $txn
    } elseif ($name -match '^CBI') {
        $categories['CBI (Canadian)'] += $txn
    } elseif ($name -match '^CCH') {
        $categories['CCH (Criminal History)'] += $txn
    } elseif ($name -match '^CaClets|^APPS|^AOS|^Dmv|^CLETSPerson|^CaPerson') {
        $categories['Expanded'] += $txn
    } else {
        $categories['Other'] += $txn
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

            $setFields = @()
            $anyFields = @()

            if ($c.Requirements -and $c.Requirements.Set) {
                $setNode = $c.Requirements.Set
                foreach ($child in $setNode.ChildNodes) {
                    if ($child.LocalName -eq 'Field') {
                        $setFields += $child.reference
                    } elseif ($child.LocalName -eq 'Any') {
                        foreach ($af in $child.ChildNodes) {
                            if ($af.LocalName -eq 'Field') {
                                $anyFields += $af.reference
                            }
                        }
                    }
                }
            }

            $combos += [PSCustomObject]@{
                KeyRef = $keyRef
                Primary = $primary
                Set = $setFields
                Any = $anyFields
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
            $setStr = ($c.Set -join ', ')
            $anyStr = if ($c.Any.Count -gt 0) { "[" + ($c.Any -join ', ') + "]" } else { '' }
            $lines += ""
            $lines += "  $ci. keyRef: $($c.KeyRef)"
            $lines += "     primary: $($c.Primary)"
            $lines += "     set: $setStr"
            if ($anyStr) { $lines += "     any: $anyStr" }
        }
    } else {
        $lines += ""
        $lines += "  (no combinations defined)"
    }

    $lines += ""
}

$lines += "=" * 78
$lines += "TOTALS: $($queryTxns.Count) query transactions, $comboTotal combinations"
$lines += "=" * 78

# Output
$output = $lines -join "`r`n"

if ($OutFile) {
    $output | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "Written to: $OutFile"
} else {
    Write-Output $output
}
