<#
  lint_build_scripts.ps1 -- Static analysis for provider build scripts
  Detects known anti-patterns before build time:
    1. Hardcoded PlateYear (should use $currentYear)
    2. Banned LicensePlateNumberIn (except Patch 8 rename map)
    3. Known field type mismatches (Inp where Sel required)
    4. Missing mandatory RMS patches (1, 3, 6)
    5. Type safety violations (AP #21-23)
    6. $currentYear defined but hardcoded year still present

  Usage: .\lint_build_scripts.ps1
         .\lint_build_scripts.ps1 -Path providers\CA_CLETS\scripts
         .\lint_build_scripts.ps1 -OutFile docs\lint_report.txt
         .\lint_build_scripts.ps1 -Fix AP21  (stubbed -- future auto-fix)
#>

param(
    [string]$Path,
    [string]$OutFile,
    [string]$Fix
)

$ErrorActionPreference = "Stop"

# ── resolve scan directory ──
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
if ($Path) {
    $scanDir = Resolve-Path $Path
} else {
    $scanDir = Join-Path $repoRoot "providers"
}

# ── collect build scripts (skip archive/) ──
$scripts = Get-ChildItem -Path $scanDir -Recurse -Filter "build_*.ps1" |
    Where-Object { $_.FullName -notmatch '\\archive\\' }

if ($scripts.Count -eq 0) {
    Write-Host "  No build scripts found under $scanDir" -ForegroundColor Yellow
    exit 0
}

# ── fix stub ──
if ($Fix) {
    Write-Host ""
    Write-Host "  [STUB] Auto-fix for pattern '$Fix' is not yet implemented." -ForegroundColor Yellow
    Write-Host "  Supported patterns (future): AP21, AP22, AP23, PlateYear, LicensePlateNumberIn" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ── counters ──
$totalScripts  = $scripts.Count
$cleanScripts  = 0
$dirtyScripts  = 0
$totalWarns    = 0
$totalFails    = 0
$totalFixes    = 0

$DATE = Get-Date -Format 'yyyy-MM-dd'

# ── output capture for -OutFile ──
$reportLines = [System.Collections.Generic.List[string]]::new()

function Out-Line {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
    $script:reportLines.Add($Text)
}

function Out-Finding {
    param([string]$Level, [string]$Line, [string]$Msg)
    switch ($Level) {
        'FAIL' { Out-Line "    [FAIL] Line ${Line}: $Msg" 'Red';    $script:totalFails++ }
        'WARN' { Out-Line "    [WARN] Line ${Line}: $Msg" 'Yellow'; $script:totalWarns++ }
        'FIX'  { Out-Line "    [FIX]  $Msg" 'Cyan';                 $script:totalFixes++ }
    }
}

# ══════════════════════════════════════════════════════════════════════
# HEADER
# ══════════════════════════════════════════════════════════════════════
Out-Line ""
Out-Line "================================================================"
Out-Line "  Build Script Lint -- $DATE"
Out-Line "================================================================"
Out-Line ""

# ══════════════════════════════════════════════════════════════════════
# LINT EACH SCRIPT
# ══════════════════════════════════════════════════════════════════════
foreach ($scriptFile in ($scripts | Sort-Object FullName)) {
    $relPath = $scriptFile.FullName.Substring($repoRoot.Length + 1)
    $lines   = [System.IO.File]::ReadAllLines($scriptFile.FullName)
    $raw     = [System.IO.File]::ReadAllText($scriptFile.FullName)
    $issueCount = 0

    Out-Line "  $relPath"

    # ------------------------------------------------------------------
    # CHECK 1: Hardcoded PlateYear
    # Look for initialValue with a 4-digit year 2024-2030
    # Exclude lines that use $currentYear variable
    # ------------------------------------------------------------------
    $hasCurrentYearDef = $raw -match '\$currentYear\s*='
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1
        # Skip comments
        if ($line -match '^\s*#') { continue }
        # Match initialValue = '2024' through '2030' (single or double quotes)
        if ($line -match "initialValue\s*=\s*['""]?(20(?:2[4-9]|30))['""]?" -and $line -notmatch '\$currentYear') {
            $year = $Matches[1]
            Out-Finding 'WARN' $lineNum "Hardcoded PlateYear '$year' -- use `$currentYear"
            Out-Finding 'FIX' '' "Add: `$currentYear = [string](Get-Date).Year  and replace '$year' with `$currentYear"
            $issueCount++
        }
    }

    # CHECK 1b: $currentYear defined but hardcoded years still present elsewhere
    if ($hasCurrentYearDef) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1
            # Skip the definition line itself and comments
            if ($line -match '^\s*\$currentYear\s*=') { continue }
            if ($line -match '^\s*#') { continue }
            # Check for hardcoded year in initialValue that is NOT using the variable
            if ($line -match "initialValue\s*=\s*['""]?(20(?:2[4-9]|30))['""]?" -and $line -notmatch '\$currentYear') {
                $year = $Matches[1]
                Out-Finding 'WARN' $lineNum "`$currentYear is defined but initialValue='$year' is hardcoded here"
                Out-Finding 'FIX' '' "Replace '$year' with `$currentYear on this line"
                $issueCount++
            }
        }
    }

    # ------------------------------------------------------------------
    # CHECK 2: LicensePlateNumberIn (banned, except in Patch 8 rename maps)
    # Valid in Patch 8 context: string replacement maps, -replace operations,
    # rename comments, and conditional renames
    # ------------------------------------------------------------------
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1
        if ($line -match 'LicensePlateNumberIn') {
            # Allow in Patch 8 rename contexts
            $isPatch8 = $false
            # Check if line is a -replace operation (Patch 8 rename)
            if ($line -match '-replace\s.*LicensePlateNumberIn') { $isPatch8 = $true }
            # Check if line is a rename map key/value
            if ($line -match "'LicensePlateNumberIn'\s*=" -or $line -match """LicensePlateNumberIn""\s*=") { $isPatch8 = $true }
            # Check if line is a string comparison for rename
            if ($line -match "-eq\s*'LicensePlateNumberIn'" -or $line -match "-eq\s*""LicensePlateNumberIn""") { $isPatch8 = $true }
            # Check if it's a comment about Patch 8
            if ($line -match '^\s*#.*[Pp]atch\s*8') { $isPatch8 = $true }
            if ($line -match '^\s*#.*LicensePlateNumberIn\s*->\s*') { $isPatch8 = $true }
            # Check context: look at surrounding lines for Patch 8 comments
            $contextStart = [Math]::Max(0, $i - 5)
            for ($j = $contextStart; $j -lt $i; $j++) {
                if ($lines[$j] -match '[Pp]atch\s*8') { $isPatch8 = $true; break }
            }

            if (-not $isPatch8) {
                Out-Finding 'FAIL' $lineNum "Banned pattern: LicensePlateNumberIn -- use LicensePlateNumber (or licensePlateNumber for BASE)"
                $issueCount++
            }
        }
    }

    # ------------------------------------------------------------------
    # CHECK 3: Known field type mismatches
    # These fields MUST use Sel/SelH, not Inp/InpH
    # ------------------------------------------------------------------
    $knownSelFields = @(
        @{ Pattern = "[Ss]ex[Cc]ode";           Label = "SexCode";           AttrHint = "attributeTypeId='SEX'" }
        @{ Pattern = "[Pp]late[Tt]ype";          Label = "PlateType";         AttrHint = "codeTypeCategory" }
        @{ Pattern = "[Rr]egistration[Ss]tate";  Label = "RegistrationState"; AttrHint = "attributeTypeId='STATE'" }
    )

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1
        # Skip comments
        if ($line -match '^\s*#') { continue }

        foreach ($field in $knownSelFields) {
            $fPat = $field.Pattern
            # Match Inp or InpH calls with these fieldIds (visible form fields, not hidden)
            # Inp 'SexCode' ... or Inp 'sexCode' ...
            if ($line -match "(?:^|\s)Inp\s+['""]$fPat['""]") {
                Out-Finding 'WARN' $lineNum "$($field.Label) uses Inp -- should be Sel with $($field.AttrHint)"
                Out-Finding 'FIX' '' "Change: Inp '$($field.Label)' ... -> Sel '$($field.Label)' '<label>' @{$($field.AttrHint)}"
                $issueCount++
            }
        }

        # VehicleMakeCode: special case -- CLAUDE.md says should use Sel with attributeTypeId='VEHICLE_MAKE'
        # But per AP #24 and FIELD_REFERENCE, VehicleMakeCode is text input for CommSys (NCIC has no vehicle make dropdown).
        # DO NOT flag VehicleMakeCode as Inp -- it is correctly Inp for CommSys providers.
        # Only flag if using Sel with NCIC_FIREARM_MAKE (AP #24).
        if ($line -match "(?:NCIC_FIREARM_MAKE)" -and $line -match "[Vv]ehicle[Mm]ake") {
            Out-Finding 'WARN' $lineNum "VehicleMakeCode uses NCIC_FIREARM_MAKE -- wrong code type (AP #24)"
            Out-Finding 'FIX' '' "Use attributeTypeId='VEHICLE_MAKE' for dropdown, or Inp for text input"
            $issueCount++
        }
    }

    # ------------------------------------------------------------------
    # CHECK 4: Missing mandatory RMS patches
    # Scan for Patch 1, Patch 3, Patch 6 markers in comments or code
    # ------------------------------------------------------------------
    $hasPatch1 = $raw -match '(?i)Patch\s*1\b'
    $hasPatch3 = $raw -match '(?i)Patch\s*3\b'
    $hasPatch6 = $raw -match '(?i)Patch\s*6\b'
    # Also detect functional equivalents without comment markers
    if (-not $hasPatch1) {
        $hasPatch1 = $raw -match "(?i)licensePlateIn.*any.*[Rr]egistrationState|[Rr]egistrationState.*licensePlateIn"
    }
    if (-not $hasPatch3) {
        $hasPatch3 = $raw -match "(?i)registrationState.*Person.*QIDM|RMS\s+Person.*registrationState"
    }
    if (-not $hasPatch6) {
        $hasPatch6 = $raw -match "(?i)RMS\s+(CLEANUP|cleanup)|Remove.*unused.*HIDLE|LicensePlateNumberOut.*remove|remove.*LicensePlateNumberOut"
    }

    if (-not $hasPatch1) {
        Out-Finding 'WARN' '--' "Missing Patch 1: RegistrationState in RMS Vehicle licensePlateIn any[]"
        $issueCount++
    }
    if (-not $hasPatch3) {
        Out-Finding 'WARN' '--' "Missing Patch 3: registrationState attr in RMS Person QIDM"
        $issueCount++
    }
    if (-not $hasPatch6) {
        Out-Finding 'WARN' '--' "Missing Patch 6: RMS cleanup (remove unused HIDLE fields)"
        $issueCount++
    }

    # ------------------------------------------------------------------
    # CHECK 5: Type safety -- AP #21, AP #22, AP #23
    # ------------------------------------------------------------------

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1
        # Skip comments
        if ($line -match '^\s*#') { continue }

        # AP #21: templateColumns with integer values instead of strings
        # Pattern: templateColumns = @(6, 6) or @(12) or @(4,4,4) -- integers not quoted
        if ($line -match 'templateColumns\s*=\s*@\(') {
            # Extract the array contents
            if ($line -match 'templateColumns\s*=\s*@\(([^)]+)\)') {
                $arrayContent = $Matches[1]
                # Check if any element is an unquoted integer (not wrapped in quotes)
                $elements = $arrayContent -split ','
                foreach ($elem in $elements) {
                    $trimmed = $elem.Trim()
                    # Bare integer (no quotes around it, not a variable)
                    if ($trimmed -match '^\d+$') {
                        Out-Finding 'WARN' $lineNum "templateColumns has integer value '$trimmed' -- must be string (AP #21)"
                        Out-Finding 'FIX' '' "Change: @($arrayContent) -> @($($elements | ForEach-Object { "'$($_.Trim())'" } | Join-String -Separator ','))"
                        $issueCount++
                        break  # One finding per line is enough
                    }
                }
            }
        }

        # AP #22: maxLength as bare integer (not in quotes)
        # Pattern: maxLength = 20 (no quotes) vs maxLength = '20' (correct)
        # In the Inp helper call, maxLength is passed as 3rd positional arg -- always a string there.
        # But in direct hashtable assignment: @{ maxLength = 20 } is wrong.
        # Exclude: description strings (maxLength=N inside a quoted string), function defs, comments.
        if ($line -match "maxLength\s*=\s*(\d+)" -and $line -notmatch "maxLength\s*=\s*['""]") {
            # Exclude lines that are: function defs, Inp calls, conditionals, comments, or description strings
            $isFalsePositive = $false
            if ($line -match '^\s*function\s')    { $isFalsePositive = $true }
            if ($line -match "Inp\s+['""]")       { $isFalsePositive = $true }
            if ($line -match '^\s*if\s')          { $isFalsePositive = $true }
            if ($line -match '^\s*#')             { $isFalsePositive = $true }
            # Description strings: maxLength appears inside a quoted string value
            if ($line -match "description\s*=\s*['""]") { $isFalsePositive = $true }
            if ($line -match "['""].*maxLength")  { $isFalsePositive = $true }
            if (-not $isFalsePositive) {
                $val = $Matches[1]
                Out-Finding 'WARN' $lineNum "maxLength = $val (integer) -- must be string '$val' (AP #22)"
                Out-Finding 'FIX' '' "Change: maxLength = $val -> maxLength = '$val'"
                $issueCount++
            }
        }

        # AP #23: autoSelect as string instead of boolean
        # Pattern: autoSelect = 'true' or autoSelect = "true" or autoSelect = 'false'
        if ($line -match "autoSelect\s*=\s*['""](true|false)['""]") {
            $val = $Matches[1]
            $boolVal = if ($val -eq 'true') { '$true' } else { '$false' }
            Out-Finding 'WARN' $lineNum "autoSelect = '$val' (string) -- must be boolean $boolVal (AP #23)"
            Out-Finding 'FIX' '' "Change: autoSelect = '$val' -> autoSelect = $boolVal"
            $issueCount++
        }
    }

    # ------------------------------------------------------------------
    # RESULT FOR THIS SCRIPT
    # ------------------------------------------------------------------
    if ($issueCount -eq 0) {
        Out-Line "    [PASS] No issues found" 'Green'
        $cleanScripts++
    } else {
        $dirtyScripts++
    }
    Out-Line ""
}

# ══════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════
Out-Line "================================================================"
Out-Line "  TOTAL: $totalScripts scripts | $cleanScripts clean | $dirtyScripts with issues | $totalWarns warnings | $totalFails failures"
Out-Line "================================================================"
Out-Line ""

# ── save to file if requested ──
if ($OutFile) {
    $outDir = Split-Path $OutFile -Parent
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    # Write UTF-8 without BOM (compatible with PS 5.1 and PS 7+)
    [System.IO.File]::WriteAllLines($OutFile, [string[]]$reportLines, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "  Report saved to: $OutFile" -ForegroundColor Gray
}

# ── exit code ──
if ($totalFails -gt 0) { exit 1 }
exit 0
