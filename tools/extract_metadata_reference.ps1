<#
  extract_metadata_reference.ps1
  DESCRIBED IN: CLAUDE.md (tools table), README.txt (line ~248)
  Generates a METADATA_REFERENCE.txt for any provider by cross-referencing
  the metadata XML (authoritative source) with the built provider JSON.

  Output: field definitions, combination requirements, build coverage map,
  unbuilt combo tracking, and platform behavior notes.

  Usage:
    .\extract_metadata_reference.ps1 -XmlPath <metadata.xml> -Path <provider.json>
    .\extract_metadata_reference.ps1 -XmlPath <metadata.xml> -Path <provider.json> -OutFile <path>
    .\extract_metadata_reference.ps1 -XmlPath <metadata.xml> -Path <provider.json> -All
      -All: include ALL transactions (not just ones built in JSON)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$XmlPath,
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$OutFile,
    [switch]$All
)

$ErrorActionPreference = "Stop"

$xmlResolved = Resolve-Path $XmlPath
$jsonResolved = Resolve-Path $Path
$providerName = [System.IO.Path]::GetFileNameWithoutExtension($jsonResolved) -replace '_(BASE|MC)$', ''

[xml]$metadata = Get-Content $xmlResolved -Raw
$json = [System.IO.File]::ReadAllText($jsonResolved) | ConvertFrom-Json

$nsm = New-Object System.Xml.XmlNamespaceManager($metadata.NameTable)
$defaultNs = $metadata.DocumentElement.NamespaceURI
if ($defaultNs) { $nsm.AddNamespace('ns', $defaultNs) }
$nsPrefix = if ($defaultNs) { 'ns:' } else { '' }

# ── Extract built QIDMs from JSON ─────────────────────────────────────────────
$providerBundle = $json.bundles | Where-Object { $_.provider -ne 'MARK43' -and $_.provider -ne 'RMS' }
$builtQidms = @{}
$builtCombos = @{}

if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        $query = $cfg.query
        if (-not $builtQidms.ContainsKey($query)) { $builtQidms[$query] = @() }
        $builtQidms[$query] += $cfg

        foreach ($combo in $cfg.combinations) {
            $kr = if ($combo.keyReference) { $combo.keyReference } else { $combo.keyRef }
            if ($kr) {
                $setFields = @()
                $anyFields = @()
                if ($combo.requirements -and $combo.requirements.set) { $setFields = @($combo.requirements.set) }
                if ($combo.requirements -and $combo.requirements.any) { $anyFields = @($combo.requirements.any) }
                $builtCombos[$kr] = @{
                    query = $query
                    set = $setFields
                    any = $anyFields
                    primaryFieldReference = $combo.primaryFieldReference
                }
            }
        }
    }
}

# ── Extract QIDM attributes for field size reference ──────────────────────────
$builtAttrs = @{}
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($attr in $cfg.attributes) {
            $key = "$($cfg.query).$($attr.name)"
            $builtAttrs[$key] = $attr
        }
    }
}

# ── Parse metadata XML ────────────────────────────────────────────────────────
function Parse-Requirements($reqNode, $nsMgr, $pre) {
    $result = @{ set = @(); any = @(); choice = @(); valueRouting = @() }
    if (-not $reqNode) { return $result }

    $setNode = $reqNode.SelectSingleNode("${pre}Set", $nsMgr)
    if (-not $setNode) { return $result }

    foreach ($child in $setNode.ChildNodes) {
        if ($child.LocalName -eq 'Field') {
            $result.set += $child.GetAttribute('reference')
            # Capture value-routing annotations (e.g. "LicensePlateTypeCode has a value of 'AP'")
            # -- the server selects the message key from this field VALUE. Critical for poisoned-array
            # analysis (these describe server-side routing, NOT client conditions). See QIDM_REFERENCE.
            $fd = $child.GetAttribute('description')
            if ($fd) { $result.valueRouting += "$($child.GetAttribute('reference')): $fd" }
        }
        elseif ($child.LocalName -eq 'Any') {
            foreach ($f in $child.ChildNodes) {
                if ($f.LocalName -eq 'Field') {
                    $result.any += $f.GetAttribute('reference')
                }
                elseif ($f.LocalName -eq 'Set') {
                    $subSet = @()
                    foreach ($sf in $f.ChildNodes) {
                        if ($sf.LocalName -eq 'Field') { $subSet += $sf.GetAttribute('reference') }
                    }
                    if ($subSet.Count -gt 0) { $result.choice += ($subSet -join ' + ') }
                }
            }
        }
    }
    return $result
}

$transactions = @{}
$totalTransactions = 0

foreach ($txNode in $metadata.SelectNodes("//${nsPrefix}Transaction[@name]", $nsm)) {
    $totalTransactions++
    $txName = $txNode.GetAttribute('name')
    $txVersion = $txNode.GetAttribute('version')

    $fields = @()
    $fieldsNode = $txNode.SelectSingleNode("${nsPrefix}Fields", $nsm)
    if ($fieldsNode) {
        foreach ($f in $fieldsNode.ChildNodes) {
            if ($f.LocalName -eq 'Field') {
                $fields += @{
                    name = $f.GetAttribute('name')
                    type = $f.GetAttribute('type')
                    maxLength = $f.GetAttribute('maxLength')
                    description = $f.GetAttribute('description')
                }
            }
        }
    }

    $combos = @()
    $combosNode = $txNode.SelectSingleNode("${nsPrefix}Combinations", $nsm)
    if ($combosNode) {
        foreach ($c in $combosNode.ChildNodes) {
            if ($c.LocalName -ne 'Combination') { continue }
            $kr = $c.GetAttribute('keyReference')
            $pf = $c.GetAttribute('primaryFieldReference')
            $reqNode = $c.SelectSingleNode("${nsPrefix}Requirements", $nsm)
            $reqs = Parse-Requirements $reqNode $nsm $nsPrefix
            $combos += @{
                keyReference = $kr
                primaryField = $pf
                requirements = $reqs
            }
        }
    }

    if (-not $transactions.ContainsKey($txName)) {
        $transactions[$txName] = @{
            version = $txVersion
            fields = $fields
            combos = $combos
        }
    } else {
        $transactions[$txName].combos += $combos
    }
}

# ── Determine which transactions to include ───────────────────────────────────
$builtQueries = @($builtQidms.Keys | Sort-Object)
$includeQueries = if ($All) {
    @($transactions.Keys | Sort-Object)
} else {
    $builtQueries
}

# ── Build output ──────────────────────────────────────────────────────────────
$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("$providerName METADATA REFERENCE")
[void]$sb.AppendLine("=" * ($providerName.Length + 20))
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd')")
[void]$sb.AppendLine("Source: $([System.IO.Path]::GetFileName($xmlResolved)) (metadata) + $([System.IO.Path]::GetFileName($jsonResolved))")
[void]$sb.AppendLine("Metadata: $totalTransactions total transactions, $($builtQueries.Count) queries built in JSON")
[void]$sb.AppendLine("")

# ── CaRequestPurposeCode check ────────────────────────────────────────────────
$hasCaReqPurp = $false
foreach ($txName in $transactions.Keys) {
    foreach ($f in $transactions[$txName].fields) {
        if ($f.name -eq 'CaRequestPurposeCode') { $hasCaReqPurp = $true; break }
    }
    if ($hasCaReqPurp) { break }
}
if ($hasCaReqPurp) {
    [void]$sb.AppendLine("CaRequestPurposeCode: Mandatory on ALL transactions.")
    [void]$sb.AppendLine("  Values: C (Criminal Justice), I (Immigration Enforcement), U (Title 8 violations)")
    [void]$sb.AppendLine("  Default: C")
    [void]$sb.AppendLine("")
}

# ── Per-query sections ────────────────────────────────────────────────────────
$totalMetaCombos = 0
$totalBuiltCombos = 0
$totalSkipped = 0
$unbuiltCombos = @()
$sectionNum = 0

foreach ($qName in $includeQueries) {
    $sectionNum++
    $tx = $transactions[$qName]
    if (-not $tx) {
        [void]$sb.AppendLine("=" * 80)
        [void]$sb.AppendLine("$sectionNum. $qName -- NOT IN METADATA")
        [void]$sb.AppendLine("=" * 80)
        [void]$sb.AppendLine("")
        continue
    }

    $isBuilt = $builtQidms.ContainsKey($qName)

    [void]$sb.AppendLine("=" * 80)
    [void]$sb.AppendLine("$sectionNum. $qName (version $($tx.version))" + $(if (-not $isBuilt) { " -- NOT BUILT" } else { "" }))
    [void]$sb.AppendLine("=" * 80)
    [void]$sb.AppendLine("")

    # Fields
    [void]$sb.AppendLine("METADATA FIELDS ($($tx.fields.Count)):")
    $maxNameLen = ($tx.fields | ForEach-Object { $_.name.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxNameLen) { $maxNameLen = 20 }
    $maxNameLen = [Math]::Max($maxNameLen, 10)

    foreach ($f in ($tx.fields | Sort-Object { $_.name })) {
        $padName = $f.name.PadRight($maxNameLen)
        $padType = $f.type.PadRight(13)
        $desc = if ($f.description.Length -gt 60) { $f.description.Substring(0, 57) + "..." } else { $f.description }
        [void]$sb.AppendLine("  $padName $padType maxLen=$($f.maxLength.PadLeft(2))  $desc")
    }
    [void]$sb.AppendLine("")

    # Combinations
    $metaCombos = $tx.combos
    $totalMetaCombos += $metaCombos.Count

    [void]$sb.AppendLine("METADATA COMBINATIONS ($($metaCombos.Count) total):")
    [void]$sb.AppendLine("  KeyRef".PadRight(14) + "Primary".PadRight(24) + "Set".PadRight(55) + "Any")
    [void]$sb.AppendLine("  " + ("-" * 12) + "  " + ("-" * 22) + "  " + ("-" * 53) + "  " + ("-" * 30))

    foreach ($c in $metaCombos) {
        $setStr = ($c.requirements.set -join ', ')
        if ($c.requirements.choice.Count -gt 0) {
            $setStr += " + Choice[" + ($c.requirements.choice -join ' | ') + "]"
        }
        $anyStr = if ($c.requirements.any.Count -gt 0) { ($c.requirements.any -join ', ') } else { "--" }
        if ($setStr.Length -gt 53) { $setStr = $setStr.Substring(0, 50) + "..." }
        if ($anyStr.Length -gt 30) { $anyStr = $anyStr.Substring(0, 27) + "..." }

        [void]$sb.AppendLine("  $($c.keyReference.PadRight(12))  $($c.primaryField.PadRight(22))  $($setStr.PadRight(53))  $anyStr")
        # Value-routing annotations: the server selects this keyRef from a field VALUE (NOT client
        # conditions). E.g. multiple keyRefs sharing one field signature = server-side value routing.
        if ($c.requirements.valueRouting -and $c.requirements.valueRouting.Count -gt 0) {
            foreach ($vr in $c.requirements.valueRouting) {
                [void]$sb.AppendLine("                -> server-routes on $vr")
            }
        }
    }
    [void]$sb.AppendLine("")

    # Build coverage
    if ($isBuilt) {
        $qidmConfigs = $builtQidms[$qName]
        $builtKrs = @()
        foreach ($cfg in $qidmConfigs) {
            foreach ($combo in $cfg.combinations) {
                $kr = if ($combo.keyReference) { $combo.keyReference } else { $combo.keyRef }
                if ($kr) { $builtKrs += $kr }
            }
        }
        $totalBuiltCombos += $builtKrs.Count

        [void]$sb.AppendLine("BUILD COVERAGE ($($builtKrs.Count) of $($metaCombos.Count) built):")

        $metaKrGroups = @{}
        foreach ($c in $metaCombos) {
            $baseKr = $c.keyReference
            if (-not $metaKrGroups.ContainsKey($baseKr)) { $metaKrGroups[$baseKr] = @() }
            $metaKrGroups[$baseKr] += $c
        }

        foreach ($kr in $builtKrs) {
            $baseKr = $kr -replace '\.[A-Z0-9]+$', ''
            $comboData = $builtCombos[$kr]
            $setStr = if ($comboData.set.Count -gt 0) { "set[$($comboData.set -join ', ')]" } else { "" }
            [void]$sb.AppendLine("  BUILT   $($kr.PadRight(14)) $setStr")
        }

        foreach ($c in $metaCombos) {
            $isComboBuilt = $false
            $syntheticKr = "$($c.keyReference)$($c.primaryField)"
            foreach ($bkr in $builtKrs) {
                $bBase = $bkr -replace '\.[A-Z0-9]+$', ''
                # Match exact keyRef, dotted-variant base, or synthetic keyRef
                # (built combos use keyRef + primaryField, e.g. KQ + Name -> KQName,
                #  per LIMITATION #21 invented-keyRef pattern)
                if ($bBase -eq $c.keyReference -or $bkr -eq $c.keyReference -or
                    $bkr -eq $syntheticKr -or $bkr.StartsWith($syntheticKr)) {
                    $isComboBuilt = $true
                    break
                }
            }
            if (-not $isComboBuilt) {
                $totalSkipped++
                [void]$sb.AppendLine("  UNBUILT $($c.keyReference.PadRight(14)) $($c.primaryField)")
                $unbuiltCombos += @{ query = $qName; keyRef = $c.keyReference; primaryField = $c.primaryField }
            }
        }
        [void]$sb.AppendLine("")
    } else {
        $totalSkipped += $metaCombos.Count
        [void]$sb.AppendLine("BUILD COVERAGE: NOT BUILT (0 of $($metaCombos.Count))")
        foreach ($c in $metaCombos) {
            $unbuiltCombos += @{ query = $qName; keyRef = $c.keyReference; primaryField = $c.primaryField }
        }
        [void]$sb.AppendLine("")
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
[void]$sb.AppendLine("=" * 80)
[void]$sb.AppendLine("BUILD SUMMARY")
[void]$sb.AppendLine("=" * 80)
[void]$sb.AppendLine("")

$summaryData = @{}
foreach ($qName in $includeQueries) {
    $tx = $transactions[$qName]
    $metaCount = if ($tx) { $tx.combos.Count } else { 0 }
    $builtCount = 0
    if ($builtQidms.ContainsKey($qName)) {
        foreach ($cfg in $builtQidms[$qName]) {
            $builtCount += $cfg.combinations.Count
        }
    }
    $skipCount = $metaCount - $builtCount
    if ($skipCount -lt 0) { $skipCount = 0 }
    $pct = if ($metaCount -gt 0) { [math]::Round(($builtCount / $metaCount) * 100) } else { 0 }
    $summaryData[$qName] = @{ meta = $metaCount; built = $builtCount; skip = $skipCount; pct = $pct }
}

[void]$sb.AppendLine("  Query".PadRight(36) + "Metadata  Built  Skip  Coverage")
[void]$sb.AppendLine("  " + ("-" * 34) + "  " + ("-" * 8) + "  " + ("-" * 5) + "  " + ("-" * 4) + "  " + ("-" * 8))

$grandMeta = 0; $grandBuilt = 0; $grandSkip = 0
foreach ($qName in ($includeQueries | Sort-Object)) {
    $s = $summaryData[$qName]
    $grandMeta += $s.meta; $grandBuilt += $s.built; $grandSkip += $s.skip
    $covStr = if ($s.meta -gt 0) { "$($s.pct)%" + $(if ($s.pct -eq 100) { " (COMPLETE)" } else { "" }) } else { "N/A" }
    [void]$sb.AppendLine("  $($qName.PadRight(34))  $($s.meta.ToString().PadLeft(8))  $($s.built.ToString().PadLeft(5))  $($s.skip.ToString().PadLeft(4))  $covStr")
}
$grandPct = if ($grandMeta -gt 0) { [math]::Round(($grandBuilt / $grandMeta) * 100) } else { 0 }
[void]$sb.AppendLine("  " + ("-" * 34) + "  " + ("-" * 8) + "  " + ("-" * 5) + "  " + ("-" * 4) + "  " + ("-" * 8))
[void]$sb.AppendLine("  TOTAL".PadRight(36) + "$($grandMeta.ToString().PadLeft(8))  $($grandBuilt.ToString().PadLeft(5))  $($grandSkip.ToString().PadLeft(4))  $grandPct%")
[void]$sb.AppendLine("")

# ── Unbuilt Combos ────────────────────────────────────────────────────────────
if ($unbuiltCombos.Count -gt 0) {
    [void]$sb.AppendLine("=" * 80)
    [void]$sb.AppendLine("UNBUILT METADATA COMBOS ($($unbuiltCombos.Count) combos in metadata, not in JSON)")
    [void]$sb.AppendLine("=" * 80)
    [void]$sb.AppendLine("")
    foreach ($ub in $unbuiltCombos) {
        [void]$sb.AppendLine("  $($ub.keyRef.PadRight(14)) $($ub.primaryField.PadRight(24)) ($($ub.query))")
    }
    [void]$sb.AppendLine("")
}

# ── Unbuilt transactions ─────────────────────────────────────────────────────
$unbuiltTx = @($transactions.Keys | Where-Object { -not $builtQidms.ContainsKey($_) } | Sort-Object)
if ($unbuiltTx.Count -gt 0) {
    [void]$sb.AppendLine("=" * 80)
    [void]$sb.AppendLine("ALL UNBUILT TRANSACTIONS ($($unbuiltTx.Count) of $totalTransactions in metadata)")
    [void]$sb.AppendLine("=" * 80)
    [void]$sb.AppendLine("")
    foreach ($txName in $unbuiltTx) {
        $tx = $transactions[$txName]
        $comboCount = $tx.combos.Count
        [void]$sb.AppendLine("  $($txName.PadRight(40)) v$($tx.version.PadRight(4)) $comboCount combos")
    }
    [void]$sb.AppendLine("")
}

$output = $sb.ToString()

if ($OutFile) {
    $output | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "Metadata reference written to: $OutFile" -ForegroundColor Green
} else {
    Write-Host $output
}

Write-Host ""
Write-Host "Summary: $grandBuilt of $grandMeta metadata combos built ($grandPct%). $($unbuiltCombos.Count) unbuilt. $totalTransactions total transactions in metadata." -ForegroundColor Cyan
