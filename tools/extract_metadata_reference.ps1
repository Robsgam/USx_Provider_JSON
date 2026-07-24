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
    [string]$DevdocPath = "",
    [switch]$All
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_metadata_keyref_match.ps1')

$xmlResolved = Resolve-Path $XmlPath
$jsonResolved = Resolve-Path $Path
$providerName = [System.IO.Path]::GetFileNameWithoutExtension($jsonResolved) -replace '_v[\d.]+$', '' -replace '_(BASE|MC)$', ''
# Separate, fully-stripped name (version suffix too) for locating <PROVIDER>_ACCEPTED_DIVERGENCES.txt,
# which is never version-suffixed. Kept distinct from $providerName above (used verbatim in the report
# header) to avoid changing existing report output for versioned providers.
$declProviderName = $providerName -replace '_v[\d.]+$', ''
$keyRefDeclarations = Get-KeyRefDeclarations -JsonDir ([System.IO.Path]::GetDirectoryName($jsonResolved)) -ProviderName $declProviderName

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
                # Keyed by (query, keyRef), not bare keyRef: two QIDMs in the same provider can
                # reuse a keyRef name with different field semantics (NY_NYSPIN_EJUSTICE's Boat
                # vs Vehicle both define RVEH/RCAR) -- a bare-keyRef key lets whichever QIDM is
                # processed last silently overwrite the other's entry.
                $builtCombos["$query::$kr"] = @{
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

# ── Parse devdoc for conditional field constraints ────────────────────────────
# Auto-discovers devdoc at source/<PROVIDER>_DEVDOC.txt if -DevdocPath not specified.
# Scans each transaction section for "Must be filled if X = Y" lines (PDF-extracted
# devdocs don't reliably preserve table structure, so we capture raw constraint text
# within section boundaries and let the reader cross-reference the field list above).
# Collect EVERY conditional constraint provider-wide (trigger field + one value per code), then
# associate each to the built QIDMs whose field list carries the trigger field (emit loop below).
# The old per-transaction capture keyed off a bare transaction name landing on its own devdoc line,
# which pdftotext almost never produces -- so it silently found nothing (no provider ever got a
# FIELD CONSTRAINTS section). Matches both "Must be filled if" and "Mandatory if" (AZ's synonym).
$devdocConstraints = New-Object System.Collections.Generic.List[object]
$devdocResolved = $DevdocPath
if (-not $devdocResolved) {
    $jsonDir = [System.IO.Path]::GetDirectoryName($jsonResolved)
    $candidate = [System.IO.Path]::Combine($jsonDir, "source", "${providerName}_DEVDOC.txt")
    if (Test-Path $candidate) { $devdocResolved = $candidate }
}
if ($devdocResolved -and (Test-Path $devdocResolved)) {
    foreach ($dLine in (Get-Content $devdocResolved)) {
        # Capture the trigger field + a comma-separated list of short codes; the value pattern stops
        # before trailing possible-values prose (e.g. AZ "= CA, CO CI - ..." -> CA,CO; TX "= Y Y,N..." -> Y).
        if ($dLine -match '(?:Must be filled if|Mandatory if)\s+(\w+)\s*=\s*([A-Za-z0-9]{1,4}(?:\s*,\s*[A-Za-z0-9]{1,4})*)') {
            $tField = $Matches[1]
            foreach ($tv in @($Matches[2] -split '\s*,\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                $devdocConstraints.Add([PSCustomObject]@{ field = $tField; value = $tv })
            }
        }
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
            $comboData = $builtCombos["$qName::$kr"]
            $setStr = if ($comboData.set.Count -gt 0) { "set[$($comboData.set -join ', ')]" } else { "" }
            [void]$sb.AppendLine("  BUILT   $($kr.PadRight(14)) $setStr")
        }

        foreach ($c in $metaCombos) {
            # Matching delegated to _metadata_keyref_match.ps1 (shared with audit_metadata.ps1's
            # CHECK 4) -- declaration-first (ACCEPTED_DIVERGENCES built-as/not-built), mechanical
            # keyRef/dotted-base/synthetic-suffix rule as the fallback for providers/keyRefs with
            # no declaration. See that module's header for why a pure mechanical rule is
            # insufficient (NJ_NJCJIS's RANDFULL/RANDFULLN compound rename).
            $resolved = Resolve-XmlKeyRefBuild -XmlKeyRef $c.keyReference -XmlPrimaryField $c.primaryField `
                -Query $qName -BuiltKeyRefs $builtKrs -Declarations $keyRefDeclarations
            if ($resolved.Status -ne 'built') {
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

    # Field constraints from devdoc -- emit each provider-wide conditional whose trigger field is a
    # field of THIS built QIDM, in the exact grammar check_test_preconditions.ps1 parses
    # ("  Must be filled if <Field> = <Value>", 2-space indent). Field match is substring-tolerant
    # (devdoc "PurposeCode" vs metadata "CaRequestPurposeCode"); we emit the QIDM's actual field name
    # to give the consumer's exact defaults[].field comparison the best chance. Over-association is
    # harmless -- the consumer only flags a QIDM whose combo actually defaults the field to the value.
    if ($isBuilt -and $devdocConstraints.Count -gt 0) {
        $qidmFieldNames = @($transactions[$qName].fields | ForEach-Object { $_.name })
        $conLines = @(); $emitted = @{}
        foreach ($dc in $devdocConstraints) {
            $hit = $qidmFieldNames | Where-Object { $_ -and (($_ -ieq $dc.field) -or ($_ -like "*$($dc.field)*") -or ($dc.field -like "*$_*")) } | Select-Object -First 1
            if ($hit) {
                $key = "$hit=$($dc.value)"
                if (-not $emitted.ContainsKey($key)) { $emitted[$key] = $true; $conLines += "  Must be filled if $hit = $($dc.value)" }
            }
        }
        if ($conLines.Count -gt 0) {
            [void]$sb.AppendLine("FIELD CONSTRAINTS (from devdoc -- conditional requirements; verify the constrained field has a default/handler):")
            foreach ($cl in $conLines) { [void]$sb.AppendLine($cl) }
            [void]$sb.AppendLine("")
        }
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
