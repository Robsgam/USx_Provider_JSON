<#
  audit_metadata_field_coverage.ps1 -- ADVISORY "form behind the metadata" detector (refined).

  Flags a metadata field ONLY when all three hold:
    1. it appears in the Set/Any (incl. Choice sub-sets) of a BUILT combo (per the source XML +
       Resolve-XmlKeyRefBuild, which handles synthetic-keyRef renames), AND
    2. it is NOT wired into that query's QIDM (no attributes[].targetField == field), AND
    3. it is NOT on the curated SKIP list of optional/non-search modifier fields below.

  This is exactly the class that hid on NY DGRP (address block + DOB-range in a built combo's any[],
  not exposed). It deliberately does NOT flag: orphan metadata fields (in no combo), fields only in
  UNBUILT combos, or the known optional modifiers on $SKIP.

  Emits [FIELD-GAP]/[OK] only; ALWAYS exits 0. Advisory (over/under-coverage of $SKIP is a human
  call). Not gated by default -- see knowledge-base/README.txt.

  Usage: audit_metadata_field_coverage.ps1 -Path <provider.json>
#>
param([Parameter(Mandatory)][string]$Path)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_metadata_keyref_match.ps1')

$json     = (Resolve-Path $Path).Path
$dir      = Split-Path $json -Parent
$provider = Split-Path $dir -Leaf

# Curated skip-list: optional/non-search modifier fields that live in built combos' any[] but are
# deliberately not exposed as officer search inputs. KEEP MINIMAL -- a mislisted field hides a real
# gap. Each entry justified:
$SKIP = @(
    'Requestor', 'Attention',              # officer attention/routing line -- optional / auto-populated, not a search key
    'RelatedHitSearchIndicator',           # stolen-hit toggle -- exposed selectively by design (e.g. Boat only)
    'State2', 'State3', 'State4', 'State5', # additional-state multi-state search -- rare; single State covers normal use
    'VINSequenceNumber',                   # niche VIN disambiguation, not a primary search input
    'MessageContinueKeyCode',              # DMV-generated paging/continuation token (system field)
    'ExpandedNameSearchCode',              # name-broadening toggle -- optional modifier
    'MessageKeyModifier'                   # message-routing modifier, not a search field
)
$skipSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($s in $SKIP) { [void]$skipSet.Add($s) }

# Source XML (case-insensitive .xml/.XML).
$xmlFile = Get-ChildItem (Join-Path $dir 'source') -Filter "$provider.*" -ErrorAction SilentlyContinue |
           Where-Object { $_.Extension -in '.xml', '.XML' } | Select-Object -First 1
if (-not $xmlFile) {
    Write-Output "[OK] ${provider}: no source XML found -- field-coverage skipped."
    exit 0
}

# --- JSON: built keyRefs + wired fields, per query (Commsys QIDMs only) ---
$obj = Get-Content $json -Raw | ConvertFrom-Json
$builtKrsByQuery = @{}
$wiredByQuery    = @{}
foreach ($b in $obj.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTDATAMAPPING' -or -not $c.query) { continue }
        if ($c.providerType -and $c.providerType -ne 'Commsys') { continue }
        $krs = @($c.combinations | ForEach-Object { $_.keyReference } | Where-Object { $_ })
        $builtKrsByQuery[$c.query] = $krs
        $w = New-Object System.Collections.Generic.HashSet[string]
        foreach ($a in $c.attributes) { $f = if ($a.targetField) { $a.targetField } else { $a.name }; if ($f) { [void]$w.Add($f) } }
        $wiredByQuery[$c.query] = $w
    }
}

$declarations = Get-KeyRefDeclarations -JsonDir $dir -ProviderName $provider

# --- XML: parse combos, collect BUILT-combo field references per query ---
[xml]$m = Get-Content $xmlFile.FullName
$nsm = New-Object System.Xml.XmlNamespaceManager($m.NameTable)
$defaultNs = $m.DocumentElement.NamespaceURI
$pre = ''
if ($defaultNs) { $nsm.AddNamespace('ns', $defaultNs); $pre = 'ns:' }

function Get-ComboFields($combo, $nsm, $pre) {
    $out = @()
    $req = $combo.SelectSingleNode("${pre}Requirements", $nsm)
    if (-not $req) { return $out }
    $setNode = $req.SelectSingleNode("${pre}Set", $nsm)
    if (-not $setNode) { return $out }
    foreach ($child in $setNode.ChildNodes) {
        if ($child.LocalName -eq 'Field') { $out += $child.GetAttribute('reference') }
        elseif ($child.LocalName -eq 'Any') {
            foreach ($f in $child.ChildNodes) {
                if ($f.LocalName -eq 'Field') { $out += $f.GetAttribute('reference') }
                elseif ($f.LocalName -eq 'Set') {
                    foreach ($sf in $f.ChildNodes) { if ($sf.LocalName -eq 'Field') { $out += $sf.GetAttribute('reference') } }
                }
            }
        }
    }
    return $out
}

$expectedByQuery = @{}   # query -> HashSet of fields in BUILT combos
foreach ($tx in $m.SelectNodes("//${pre}Transaction[@name]", $nsm)) {
    $q = $tx.GetAttribute('name')
    if (-not $builtKrsByQuery.ContainsKey($q)) { continue }   # query not built as a QIDM -> unbuilt, ignore
    $builtKrs = $builtKrsByQuery[$q]
    $combosNode = $tx.SelectSingleNode("${pre}Combinations", $nsm)
    if (-not $combosNode) { continue }
    if (-not $expectedByQuery.ContainsKey($q)) { $expectedByQuery[$q] = New-Object System.Collections.Generic.HashSet[string] }
    foreach ($c in $combosNode.ChildNodes) {
        if ($c.LocalName -ne 'Combination') { continue }
        $kr = $c.GetAttribute('keyReference')
        $pf = $c.GetAttribute('primaryFieldReference')
        $res = Resolve-XmlKeyRefBuild -XmlKeyRef $kr -XmlPrimaryField $pf -Query $q -BuiltKeyRefs $builtKrs -Declarations $declarations
        if ($res.Status -ne 'built') { continue }
        foreach ($f in (Get-ComboFields $c $nsm $pre)) { if ($f) { [void]$expectedByQuery[$q].Add($f) } }
    }
}

# --- Diff: expected(built combos) - wired - SKIP ---
$gaps = 0
foreach ($q in ($expectedByQuery.Keys | Sort-Object)) {
    $wired = $wiredByQuery[$q]
    $missing = @($expectedByQuery[$q] | Where-Object { -not $wired.Contains($_) -and -not $skipSet.Contains($_) } | Sort-Object -Unique)
    if ($missing.Count -gt 0) {
        Write-Output "[FIELD-GAP] ${provider}/${q}: metadata field(s) in a built combo but not exposed: $($missing -join ', ')"
        $gaps += $missing.Count
    }
}
if ($gaps -eq 0) { Write-Output "[OK] ${provider}: every built combo's fields are exposed (or are known optional modifiers)." }
exit 0
