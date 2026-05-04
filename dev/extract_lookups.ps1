param(
    [string]$DevFolder = "C:\Users\RobSgambellone\.local\bin\dev"
)

# ------------------------------------------------------------------
# Lookup field definition:
#   A field whose Possible Values column contains specific code values,
#   code manual references, or enumerated lists -- NOT free text
#   format descriptions (Alphanumeric, YYYYMMDD, Numeric, etc.)
# ------------------------------------------------------------------

$pdfFiles = Get-ChildItem "$DevFolder\*.pdf" | Sort-Object Name

# fieldName -> { Values: HashSet, Interfaces: List, Queries: HashSet }
$fields = [System.Collections.Specialized.OrderedDictionary]::new()

$sectionPattern = 'Basic Quer(ies|y) (Supported|Transactions Supported|Transactions)\s*:'

function IsLookup([string]$val) {
    if (-not $val -or $val.Trim() -eq '') { return $false }
    $v = $val.Trim()

    # Length guard: overly long values are description paragraphs, not code lists
    if ($v.Length -gt 80) { return $false }

    # Exclude narrative text (natural language sentences)
    if ($v -match '\b(provided|providing|without|including|inquiry|inquiries|description|request|requires|allowed|configured|default|obtained|response|process|above|routing|controls|where|when|how|routed)\b') { return $false }
    if ($v -match '\b(may be|must be|will be|can be|should be|is used|is the|is a)\b') { return $false }
    if ($v -match '\.\s+[A-Z]') { return $false }   # two sentences
    if ($v -match '^[A-Z][a-z]{4,}\s+[A-Za-z]{4,}.*[a-z]{4,}') { return $false }  # plain sentence start

    # Exclude pure format descriptions (not lookups)
    if ($v -match '^(Alphanumeric|Numeric|YYYYMMDD|MMDDYYYY|Date format|Free\s*[Tt]ext)\b' -and
        $v -notmatch '(See |code|Code|manual|Manual|NCIC|NLETS|,\s*[A-Z])') { return $false }
    if ($v -match '^\d[\d\s\-]*$') { return $false }   # just numbers

    # Include if it has code indicators
    if ($v -match '(See |code [Mm]anual|Code [Mm]anual|NCIC|NLETS|[Mm]anual)') { return $true }
    if ($v -match '(state code|region code|province code)') { return $true }
    if ($v -match '[A-Z],\s*[A-Z]') { return $true }   # enumerated codes like M,F,U
    if ($v -match '\bor\s+(BLANK|blank)\b') { return $true }
    if ($v -match '^[A-Z](,\s*[A-Z])+') { return $true }   # short code list at start
    if ($v -match '(true.*false|false.*true)') { return $true }
    if ($v -match '\bORI\b') { return $true }
    if ($v -match '(STA\b|char STA)') { return $true }
    return $false
}

function SafeSub([string]$s, [int]$start, [int]$len) {
    if ($start -ge $s.Length) { return '' }
    $end = [Math]::Min($start + $len, $s.Length)
    return $s.Substring($start, $end - $start).Trim()
}

$processed = 0

foreach ($pdf in $pdfFiles) {
    $interfaceId = $pdf.BaseName
    $rawText = & pdftotext -layout $pdf.FullName - 2>$null
    if (-not $rawText) { continue }
    $lines = ($rawText -replace '\r', '') -split "`n"

    # Interface name
    $interfaceName = $interfaceId
    foreach ($ln in $lines) {
        $cleaned = ($ln -replace '\s{3,}.*$', '').Trim()
        if ($cleaned -ne '' -and $cleaned -notmatch '^(Disclaimer|Statement|Transport|Routing|Security|Logon|Certification|Data|©|\*|Page)') {
            $interfaceName = $cleaned
            break
        }
    }

    # Find Basic Queries section
    $basicStart = -1
    $basicEnd   = $lines.Count - 1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sectionPattern) {
            if ($lines[$i] -match 'None\s*$') { break }
            $basicStart = $i + 1
            continue
        }
        if ($basicStart -ge 0 -and $i -gt $basicStart) {
            if ($lines[$i] -match '^\s*(Transactions|Expanded|Hardware|References)\s+(Supported|Requirements|:)') {
                $basicEnd = $i - 1
                break
            }
        }
    }
    if ($basicStart -lt 0) { continue }

    $basicLines = $lines[$basicStart..$basicEnd]

    # Parse query blocks
    $currentQuery = $null
    $inCombos     = $false
    $tableHeaderIdx = -1
    $xmlTagPos    = -1
    $mcoPos       = -1
    $sizePos      = -1
    $possiblePos  = -1
    $blockLines   = [System.Collections.Generic.List[string]]::new()

    function ProcessBlock {
        param([string]$queryName, [System.Collections.Generic.List[string]]$bLines,
              [string]$iface, [string]$ifaceId)

        # Find the column header line that contains "Possible Values"
        $hIdx = -1
        $pPos = -1
        for ($bi = 0; $bi -lt $bLines.Count; $bi++) {
            if ($bLines[$bi] -match '\bPossible Values\b') {
                $hIdx = $bi
                $pPos = $bLines[$bi].IndexOf("Possible Values")
                break
            }
        }
        if ($hIdx -lt 0 -or $pPos -lt 0) { return }

        for ($bi = $hIdx + 1; $bi -lt $bLines.Count; $bi++) {
            $bl = $bLines[$bi]
            $bt = $bl.Trim()
            if ($bt -eq '') { continue }
            if ($bt -match 'CommSys|Confidential|Page \d') { continue }

            # ---- Extract Possible Values ----
            # Use pPos from the header; scan left to catch a word that started before pPos.
            $pvStart = $pPos
            if ($pvStart -lt $bl.Length -and $pvStart -gt 0) {
                $scan = $pvStart
                while ($scan -gt [Math]::Max(0, $pPos - 8) -and $bl[$scan] -ne ' ') { $scan-- }
                if ($pPos - $scan -le 8) { $pvStart = $scan + 1 }
            }
            if ($pvStart -ge $bl.Length) { continue }
            $pv = $bl.Substring($pvStart).Trim()
            if (-not (IsLookup $pv)) { continue }
            $pv = ($pv -replace '\s+', ' ').Trim()

            # ---- Extract XML Tag Name (token-based, no column-position dependency) ----
            # Split on runs of 2+ spaces to get column tokens.
            # Token[0]: either the human-readable field label (if it contains a space, NJ-style)
            #           or the XML tag name itself (FL/NY-style, no space within the token).
            # Token[1]: if Token[0] is a label with a space, Token[1] is the XML tag name.
            $tokens = @($bt -split '\s{2,}' | Where-Object { $_ -ne '' })
            if ($tokens.Count -eq 0) { continue }

            $xmlTag = ''
            $t0 = $tokens[0]

            # If the first token itself encodes M/C/O + Size (e.g. "NCICNumber C 10 See NCIC..."),
            # strip everything from the first MCO-number pattern to recover just the tag.
            if ($t0 -match '^(\S+)\s+[MCO]\s+\d') {
                $xmlTag = $Matches[1]
            }
            elseif ($t0 -match '\s') {
                # Token has internal spaces:
                # NJ-style: "Article Type" → XML tag is the second 2+-space-split token
                if ($tokens.Count -ge 2) {
                    $xmlTag = $tokens[1]
                }
                else {
                    # Only one big token — try to recover tag before MCO pattern
                    $xmlTag = ($t0 -replace '\s+[MCO]\s+\d.*$', '').Trim()
                    if ($xmlTag -match '\s') {
                        # Still has spaces → take last space-separated word
                        $xmlTag = ($xmlTag -split '\s+')[-1]
                    }
                }
            }
            else {
                # FL/NY-style: first token IS the XML tag name (no internal spaces)
                $xmlTag = $t0
            }

            # Strip any stray trailing content
            $xmlTag = ($xmlTag -replace '\s.*$', '').Trim()

            # Validate: must look like a real XML tag name
            # - No commas (that's a value list)
            # - No common English words
            # - Reasonable length (2-50 chars)
            # - No sentence-ending punctuation
            if ($xmlTag -match ',') { continue }
            if ($xmlTag -match '^(Field Name|XML Tag Name|M/C/O|Size|Possible|\d|-)') { continue }
            if ($xmlTag.Length -lt 4 -or $xmlTag.Length -gt 50) { continue }
            if ($xmlTag -match '[.!?;*]$') { continue }
            if ($xmlTag -match '\b(and|or|the|of|is|for|may|by|to|in|at|as|an|not|be|no)\b') { continue }
            if ($xmlTag -match '^[A-Z],[A-Z]$') { continue }
            # Must start with a letter
            if ($xmlTag -notmatch '^[A-Za-z]') { continue }
            # All-lowercase = not a valid XML tag name
            if ($xmlTag -cmatch '^[a-z]+$') { continue }
            # All-uppercase 4 chars or less = likely a code value (TM, QWA, OUT, INV, etc.)
            if ($xmlTag -cmatch '^[A-Z0-9]+$' -and $xmlTag.Length -le 4) { continue }
            # Known noise words that pass the above filters
            if ($xmlTag -match '^(Blank|BLANK|Characters|Serial|Vehicle|YYYYMMDD|Manual|expired|records)$') { continue }

            # Register
            if (-not $script:fields.Contains($xmlTag)) {
                $script:fields[$xmlTag] = @{
                    Values     = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    Interfaces = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    Queries    = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                }
            }
            $script:fields[$xmlTag].Values.Add($pv)          | Out-Null
            $script:fields[$xmlTag].Interfaces.Add($ifaceId)  | Out-Null
            $script:fields[$xmlTag].Queries.Add($queryName)   | Out-Null
        }
    }

    $currentQuery = $null
    $inCombos     = $false
    $blockLines   = [System.Collections.Generic.List[string]]::new()

    foreach ($ln in $basicLines) {
        $qMatch = $null
        if ($ln -match '^\s*([A-Za-z]\w*Query)\b') { $qMatch = $Matches[1] }
        elseif ($ln -match '^\s*<([A-Za-z]\w*Query)>') { $qMatch = $Matches[1] }

        if ($qMatch) {
            if ($currentQuery -and $blockLines.Count -gt 0) {
                ProcessBlock -queryName $currentQuery -bLines $blockLines -iface $interfaceName -ifaceId $interfaceId
            }
            $currentQuery = $qMatch
            $inCombos     = $false
            $blockLines   = [System.Collections.Generic.List[string]]::new()
            continue
        }

        if (-not $currentQuery) { continue }
        if ($ln -match 'Possible Combinations') { $inCombos = $true; continue }
        if (-not $inCombos) { $blockLines.Add($ln) }
    }
    if ($currentQuery -and $blockLines.Count -gt 0) {
        ProcessBlock -queryName $currentQuery -bLines $blockLines -iface $interfaceName -ifaceId $interfaceId
    }

    $processed++
    Write-Host "[$processed] $interfaceId"
}

# ------------------------------------------------------------------
# Sort by field name and write output
# ------------------------------------------------------------------
$sortedKeys = $fields.Keys | Sort-Object

$out = [System.Collections.Generic.List[string]]::new()
$out.Add("LOOKUP FIELDS REFERENCE")
$out.Add("Generated  : $(Get-Date -Format 'yyyy-MM-dd')")
$out.Add("Source     : Basic Queries Supported section, all dev PDFs ($($pdfFiles.Count) files)")
$out.Add("Coverage   : $processed PDFs parsed  |  $($sortedKeys.Count) unique lookup fields found")
$out.Add("=" * 80)
$out.Add("")
$out.Add("A 'lookup field' is any field whose Possible Values column contains specific")
$out.Add("code values, code manual references, or enumerated lists (not free text).")
$out.Add("")
$out.Add(("  {0,-40} {1,-8} {2}" -f "XML Tag Name", "# Ifaces", "Possible Values / Code Reference"))
$out.Add("  " + "-" * 78)

foreach ($key in $sortedKeys) {
    $entry = $fields[$key]
    $ifaceCount = $entry.Interfaces.Count
    $pvList = @($entry.Values) -join "  /  "

    # Truncate if very long
    if ($pvList.Length -gt 60) { $pvList = $pvList.Substring(0, 57) + "..." }

    $out.Add(("  {0,-40} {1,-8} {2}" -f $key, $ifaceCount, $pvList))
}

$out.Add("")
$out.Add("=" * 80)
$out.Add("DETAIL: Interfaces and Queries per Field")
$out.Add("=" * 80)

foreach ($key in $sortedKeys) {
    $entry = $fields[$key]
    $out.Add("")
    $out.Add("FIELD: $key")
    $out.Add("  Possible Values : $($entry.Values -join '  /  ')")
    $out.Add("  Queries         : $($entry.Queries -join ', ')")
    $out.Add("  Interface count : $($entry.Interfaces.Count)")
    $out.Add("  Interfaces      : $($entry.Interfaces -join ', ')")
}

$outPath = "$DevFolder\LOOKUP_FIELDS.txt"
$out | Set-Content -Path $outPath -Encoding UTF8

Write-Host ""
Write-Host "Done. $processed PDFs  |  $($sortedKeys.Count) unique lookup fields"
Write-Host "Output: $outPath"
