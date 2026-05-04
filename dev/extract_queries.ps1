param(
    [string]$DevFolder = "C:\Users\RobSgambellone\.local\bin\dev"
)

$pdfFiles = Get-ChildItem "$DevFolder\*.pdf" | Sort-Object Name
$queriesLines = [System.Collections.Generic.List[string]]::new()
$fieldsLines  = [System.Collections.Generic.List[string]]::new()

$queriesLines.Add("INTERFACE QUERY / COMBINATION REFERENCE")
$queriesLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd')")
$queriesLines.Add("Source: Basic Queries Supported section only")
$queriesLines.Add("=" * 80)

$fieldsLines.Add("INTERFACE FIELD REFERENCE")
$fieldsLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd')")
$fieldsLines.Add("Source: Basic Queries Supported section only")
$fieldsLines.Add("=" * 80)

$processed = 0
$skipped   = 0

# Helper: safe substring extraction respecting line length
function SafeSub([string]$s, [int]$start, [int]$len) {
    if ($start -ge $s.Length) { return '' }
    $end = [Math]::Min($start + $len, $s.Length)
    return $s.Substring($start, $end - $start).Trim()
}

foreach ($pdf in $pdfFiles) {
    $interfaceId = $pdf.BaseName

    # Extract text with layout preservation
    $rawText = & pdftotext -layout $pdf.FullName - 2>$null
    if (-not $rawText) { $skipped++; continue }

    # Normalize line endings
    $lines = ($rawText -replace '\r', '') -split "`n"

    # -----------------------------------------------------------------
    # Interface name: take first non-empty line, strip trailing
    # "   Disclaimer..." that appears in the two-column PDF layout.
    # -----------------------------------------------------------------
    $interfaceName = $interfaceId
    foreach ($ln in $lines) {
        $t = $ln.Trim()
        if ($t -eq '') { continue }
        # Strip the "       Disclaimer Statement" tail (3+ spaces + Disclaimer/Statement)
        $cleaned = ($ln -replace '\s{3,}.*$', '').Trim()
        # Skip if what remains is a generic section header or noise
        if ($cleaned -ne '' -and $cleaned -notmatch '^(Disclaimer|Statement|Transport|Routing|Security|Logon|Certification|Data|©|\*|Page)') {
            $interfaceName = $cleaned
            break
        }
    }

    # -----------------------------------------------------------------
    # Locate the Basic Queries section.
    # Recognizes several header variants used across PDFs.
    # -----------------------------------------------------------------
    $basicStart = -1
    $basicEnd   = $lines.Count - 1
    $sectionPattern = 'Basic Quer(ies|y) (Supported|Transactions Supported|Transactions)\s*:'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sectionPattern) {
            # If the section says "None" on the same line, skip entirely
            if ($lines[$i] -match 'None\s*$') { break }
            $basicStart = $i + 1
            continue
        }
        if ($basicStart -ge 0 -and $i -gt $basicStart) {
            if ($lines[$i] -match '^\s*(Transactions|Expanded|Hardware|References|Logon|Notes)\s+(Supported|Requirements|:)') {
                $basicEnd = $i - 1
                break
            }
        }
    }

    if ($basicStart -lt 0) {
        $queriesLines.Add("")
        $queriesLines.Add("[$interfaceId]  $interfaceName")
        $queriesLines.Add("  (No Basic Queries section)")
        $skipped++
        continue
    }

    $basicLines = $lines[$basicStart..$basicEnd]

    # -----------------------------------------------------------------
    # Parse into query blocks.
    # Matches:  SomethingQuery
    #           <SomethingQuery>          (angle-bracket variant)
    # -----------------------------------------------------------------
    $blocks = [System.Collections.Generic.List[hashtable]]::new()
    $currentBlock = $null

    foreach ($ln in $basicLines) {
        $qMatch = $null
        if ($ln -match '^\s*([A-Za-z]\w*Query)\b') {
            $qMatch = $Matches[1]
        }
        elseif ($ln -match '^\s*<([A-Za-z]\w*Query)>') {
            $qMatch = $Matches[1]
        }

        if ($qMatch) {
            if ($currentBlock) { $blocks.Add($currentBlock) }
            $currentBlock = @{
                Name       = $qMatch
                FieldLines = [System.Collections.Generic.List[string]]::new()
                ComboLines = [System.Collections.Generic.List[string]]::new()
                InCombos   = $false
            }
            continue
        }

        if (-not $currentBlock) { continue }

        if ($ln -match 'Possible Combinations') {
            $currentBlock.InCombos = $true
            continue
        }

        $t = $ln.Trim()
        if ($t -eq '') { continue }
        if ($t -match 'CommSys|Confidential\.|NDA Required|Page \d+') { continue }

        if ($currentBlock.InCombos) {
            $currentBlock.ComboLines.Add($t)
        }
        else {
            # Skip pure column-header lines
            if ($t -match '^(Field Name\s*$|XML Tag Name\s*$|M/C/O\s+Size(\s+Possible Values)?\s*$)') { continue }
            $currentBlock.FieldLines.Add($ln)
        }
    }
    if ($currentBlock) { $blocks.Add($currentBlock) }

    if ($blocks.Count -eq 0) {
        $queriesLines.Add("")
        $queriesLines.Add("[$interfaceId]  $interfaceName")
        $queriesLines.Add("  (No query blocks parsed)")
        $skipped++
        continue
    }

    # -----------------------------------------------------------------
    # QUERIES output
    # -----------------------------------------------------------------
    $queriesLines.Add("")
    $queriesLines.Add("=" * 80)
    $queriesLines.Add("INTERFACE: $interfaceName  [$interfaceId]")
    $queriesLines.Add("=" * 80)

    foreach ($block in $blocks) {
        $queriesLines.Add("")
        $queriesLines.Add("  $($block.Name)")

        # Reassemble multi-line combinations into single lines
        $combos = [System.Collections.Generic.List[string]]::new()
        $current = ""
        foreach ($cl in $block.ComboLines) {
            if ($cl -match '^\d+\.') {
                if ($current -ne '') { $combos.Add($current.Trim()) }
                $current = $cl
            }
            else {
                $current += " " + $cl.Trim()
            }
        }
        if ($current -ne '') { $combos.Add($current.Trim()) }

        if ($combos.Count -gt 0) {
            foreach ($combo in $combos) {
                $queriesLines.Add("    $combo")
            }
        }
        else {
            $queriesLines.Add("    (no combinations listed)")
        }
    }

    # -----------------------------------------------------------------
    # FIELDS output
    # -----------------------------------------------------------------
    $fieldsLines.Add("")
    $fieldsLines.Add("=" * 80)
    $fieldsLines.Add("INTERFACE: $interfaceName  [$interfaceId]")
    $fieldsLines.Add("=" * 80)

    foreach ($block in $blocks) {
        $fieldsLines.Add("")
        $fieldsLines.Add("  $($block.Name)")
        $fieldsLines.Add("  " + "-" * 60)

        # Find a table header line containing "XML Tag Name" to determine column offsets
        $headerLine = $null
        $headerIdx  = -1
        for ($fi = 0; $fi -lt $block.FieldLines.Count; $fi++) {
            if ($block.FieldLines[$fi] -match 'XML Tag Name') {
                $headerLine = $block.FieldLines[$fi]
                $headerIdx  = $fi
                break
            }
        }

        if ($headerLine) {
            $xmlTagPos   = $headerLine.IndexOf("XML Tag Name")
            $mcoPos      = $headerLine.IndexOf("M/C/O")
            if ($mcoPos   -le $xmlTagPos) { $mcoPos = $xmlTagPos + 28 }
            $sizePos     = $headerLine.IndexOf("Size")
            if ($sizePos  -le $mcoPos)    { $sizePos = $mcoPos + 8 }
            $possiblePos = $headerLine.IndexOf("Possible Values")
            if ($possiblePos -le $sizePos) { $possiblePos = $sizePos + 8 }

            $fieldsLines.Add(("  {0,-38} {1,-7} {2,-6} {3}" -f "XML Tag Name", "M/C/O", "Size", "Possible Values"))
            $fieldsLines.Add("  " + "-" * 60)

            for ($fi = $headerIdx + 1; $fi -lt $block.FieldLines.Count; $fi++) {
                $fl  = $block.FieldLines[$fi]
                $ft  = $fl.Trim()
                if ($ft -eq '') { continue }
                # Skip leftover header text or page markers
                if ($ft -match '^(Field Name|XML Tag Name|M/C/O)' -or $ft -match '^Page \d') { continue }

                # Extract by column position
                $xmlTag = SafeSub $fl $xmlTagPos ($mcoPos - $xmlTagPos)
                $mco    = SafeSub $fl $mcoPos    ($sizePos - $mcoPos)
                $sz     = SafeSub $fl $sizePos   ($possiblePos - $sizePos)
                $poss   = SafeSub $fl $possiblePos 80

                # Skip rows where both extracted columns are empty (misaligned continuation)
                if ($xmlTag -eq '' -and $mco -eq '') { continue }

                # If the XML tag column is empty, this is likely a continuation of Possible Values
                # from the previous line. Skip it to keep output clean.
                if ($xmlTag -eq '') { continue }

                $fieldsLines.Add(("  {0,-38} {1,-7} {2,-6} {3}" -f $xmlTag, $mco, $sz, $poss))
            }
        }
        else {
            # No "XML Tag Name" header found -- best-effort: look for lines where
            # the first two tokens match (FieldName XMLTagName same value) or just
            # dump the trimmed field lines.
            $fieldsLines.Add("  [best-effort -- column header not found in this PDF layout]")
            $fieldsLines.Add(("  {0,-38} {1,-7} {2,-6} {3}" -f "Field/XML Tag", "M/C/O", "Size", "Possible Values"))
            $fieldsLines.Add("  " + "-" * 60)
            foreach ($fl in $block.FieldLines) {
                $t = $fl.Trim()
                if ($t -eq '') { continue }
                # Try to split on runs of 2+ spaces
                $parts = ($t -split '\s{2,}') | Where-Object { $_ -ne '' }
                if ($parts.Count -ge 2) {
                    $tag  = $parts[0]
                    $mco  = if ($parts.Count -ge 3) { $parts[2] } else { '' }
                    $sz   = if ($parts.Count -ge 4) { $parts[3] } else { '' }
                    $poss = if ($parts.Count -ge 5) { $parts[4..($parts.Count-1)] -join ' ' } else { '' }
                    $fieldsLines.Add(("  {0,-38} {1,-7} {2,-6} {3}" -f $tag, $mco, $sz, $poss))
                }
                else {
                    $fieldsLines.Add("  $t")
                }
            }
        }
    }

    $processed++
    Write-Host "[$processed] $interfaceId -- $($blocks.Count) queries"
}

# Write output files
$queriesOut = "$DevFolder\INTERFACE_QUERIES.txt"
$fieldsOut  = "$DevFolder\INTERFACE_FIELDS.txt"

$queriesLines | Set-Content -Path $queriesOut -Encoding UTF8
$fieldsLines  | Set-Content -Path $fieldsOut  -Encoding UTF8

Write-Host ""
Write-Host "Done. Processed: $processed  Skipped/no-content: $skipped"
Write-Host "Queries : $queriesOut"
Write-Host "Fields  : $fieldsOut"
