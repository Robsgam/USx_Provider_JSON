<#
  preflight_rebuild.ps1 -- Per-provider rebuild action plan generator
  Aggregates all known issues (validator WARNs, build script lint, rebuild
  tracker flags) into a single actionable report per provider.

  Usage:
    .\preflight_rebuild.ps1 -Provider LA_LEMS
    .\preflight_rebuild.ps1 -Provider LA_LEMS -Quick
    .\preflight_rebuild.ps1 -All
    .\preflight_rebuild.ps1 -All -Quick -OutFile preflight.txt

  Parameters:
    -Provider <name>   Run preflight for a single provider
    -All               Run preflight for ALL providers that need rebuilds (any WARNs > 0)
    -OutFile <path>    Save report to file
    -Quick             Parse existing report files instead of running tools live
#>

param(
    [string]$Provider,
    [switch]$All,
    [string]$OutFile,
    [switch]$Quick
)

$ErrorActionPreference = "Stop"
$toolDir   = $PSScriptRoot
$repoRoot  = (Resolve-Path "$toolDir\..").Path
$providersDir = Join-Path $repoRoot "providers"
$trackerPath  = Join-Path $repoRoot "REBUILD_TRACKER.md"
$timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm"

# ══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ══════════════════════════════════════════════════════════════════════════════
if (-not $Provider -and -not $All) {
    Write-Host ""
    Write-Host "  [ERROR] Specify -Provider <name> or -All" -ForegroundColor Red
    Write-Host "  Usage:  .\preflight_rebuild.ps1 -Provider LA_LEMS" -ForegroundColor Gray
    Write-Host "          .\preflight_rebuild.ps1 -All -Quick" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

if (-not (Test-Path $providersDir)) {
    Write-Host "  [ERROR] Providers directory not found: $providersDir" -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUT HELPERS
# ══════════════════════════════════════════════════════════════════════════════
$script:reportLines = [System.Collections.Generic.List[string]]::new()

function Out-Line {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
    $script:reportLines.Add($Text)
}

function Out-Divider {
    Out-Line ("=" * 64) "Cyan"
}

# ══════════════════════════════════════════════════════════════════════════════
# PARSE VALIDATOR REPORT -- extract counts and individual WARN/FIX lines
# ══════════════════════════════════════════════════════════════════════════════
function Parse-ValidatorReport([string]$text) {
    $pass = 0; $fail = 0; $warn = 0; $limit = 0
    $warns = [System.Collections.Generic.List[object]]::new()

    if ($text -match 'RESULTS:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*WARN') {
        $pass = [int]$Matches[1]
        $fail = [int]$Matches[2]
        $warn = [int]$Matches[3]
        if ($text -match 'RESULTS:.*?/\s*(\d+)\s*LIMITATION') {
            $limit = [int]$Matches[1]
        }
    }

    # Extract each [WARN] line
    $lines = $text -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line -match '^\[WARN\]\s*(.+)$') {
            $warnMsg = $Matches[1]
            # Look ahead for a [FIX] line (not standard in validator, but some tools emit it)
            $fixMsg = $null
            if (($i + 1) -lt $lines.Count) {
                $nextLine = $lines[$i + 1].Trim()
                if ($nextLine -match '^\[FIX\]\s*(.+)$') {
                    $fixMsg = $Matches[1]
                }
            }
            $warns.Add(@{ Warn = $warnMsg; Fix = $fixMsg })
        }
    }

    return @{
        Pass   = $pass
        Fail   = $fail
        Warn   = $warn
        Limit  = $limit
        Warns  = $warns
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERATE FIX HINT for a given WARN message
# ══════════════════════════════════════════════════════════════════════════════
function Get-FixHint([string]$warnMsg) {
    # Attention in combo
    if ($warnMsg -match "Attention.*combo set.*any.*auto-fill handler") {
        return "Remove Attention from combo set[]/any[] -- handler auto-fills without combo reference"
    }
    if ($warnMsg -match "Attention.*not in QIF fieldIds" -or $warnMsg -match "unresolvable any\[\] fields: Attention") {
        return "Remove Attention from combo any[] -- field has no QIF FormInput, handler fills it implicitly"
    }
    # ImageIndicator
    if ($warnMsg -match "ImageIndicator.*initialValue=''.*expected 'Y'") {
        return "Set ImageIndicator initialValue='Y' on Person QIF FormSelect"
    }
    if ($warnMsg -match "ImageIndicator.*initialValue=''.*expected 'N'") {
        return "Set ImageIndicator initialValue='N' on Vehicle QIF FormSelect"
    }
    # State routing
    if ($warnMsg -match "State field.*initialValue.*changes combo routing.*LIMITATION #30") {
        return "Review: State initialValue may route OOS instead of in-state (LIMITATION #30) -- remove if separate In/Out combos"
    }
    if ($warnMsg -match "State.*codeTypeProvider") {
        return "Add codeTypeProvider='NCIC' to State QIDM attribute"
    }
    # ArticleType source field
    if ($warnMsg -match "source field.*not found in QIF") {
        return "Add missing field to QIF, or correct sourceField name in QIDM attribute"
    }
    # Combo ordering
    if ($warnMsg -match "combo order has fewer set\[\]") {
        return "Review combo order -- most-specific (most set[] fields) should come first"
    }
    # Generic unresolvable any[]
    if ($warnMsg -match "unresolvable any\[\] fields:") {
        return "Remove unresolvable fields from combo any[] or add matching QIF FormInput"
    }
    # DH-suffix
    if ($warnMsg -match "DH-suffix") {
        return "Add DH-suffix fieldIds (NameFirstDH, OperatorLicenseNumberDH, etc.) for DH QIDM"
    }
    # Default catch-all
    return $null
}

# ══════════════════════════════════════════════════════════════════════════════
# LINT BUILD SCRIPTS -- inline checks matching lint_build_scripts.ps1
# ══════════════════════════════════════════════════════════════════════════════
function Lint-BuildScripts([string]$providerDir) {
    $scriptDir = Join-Path $providerDir "scripts"
    $findings = [System.Collections.Generic.List[object]]::new()

    if (-not (Test-Path $scriptDir)) { return $findings }

    $buildScripts = Get-ChildItem $scriptDir -Filter "build_*.ps1" -File -ErrorAction SilentlyContinue
    if ($buildScripts.Count -eq 0) { return $findings }

    foreach ($scriptFile in $buildScripts) {
        $relName = $scriptFile.Name
        $lines   = [System.IO.File]::ReadAllLines($scriptFile.FullName)
        $raw     = [System.IO.File]::ReadAllText($scriptFile.FullName)

        $hasCurrentYearDef = $raw -match '\$currentYear\s*='

        # CHECK 1: Hardcoded PlateYear
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1
            if ($line -match '^\s*#') { continue }
            if ($line -match "initialValue\s*=\s*['""]?(20(?:2[4-9]|30))['""]?" -and $line -notmatch '\$currentYear') {
                $year = $Matches[1]
                $findings.Add(@{
                    Script = $relName; Line = $lineNum; Level = 'WARN'
                    Msg    = "Hardcoded PlateYear '$year'"
                    Fix    = "Add: `$currentYear = [string](Get-Date).Year  and replace '$year' with `$currentYear"
                })
            }
        }

        # CHECK 1b: $currentYear defined but hardcoded year still present
        if ($hasCurrentYearDef) {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                $lineNum = $i + 1
                if ($line -match '^\s*\$currentYear\s*=') { continue }
                if ($line -match '^\s*#') { continue }
                if ($line -match "initialValue\s*=\s*['""]?(20(?:2[4-9]|30))['""]?" -and $line -notmatch '\$currentYear') {
                    $year = $Matches[1]
                    $findings.Add(@{
                        Script = $relName; Line = $lineNum; Level = 'WARN'
                        Msg    = "`$currentYear is defined but initialValue='$year' is hardcoded here"
                        Fix    = "Replace '$year' with `$currentYear on this line"
                    })
                }
            }
        }

        # CHECK 2: LicensePlateNumberIn (banned)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1
            if ($line -match 'LicensePlateNumberIn') {
                $isPatch8 = $false
                if ($line -match '-replace\s.*LicensePlateNumberIn')           { $isPatch8 = $true }
                if ($line -match "'LicensePlateNumberIn'\s*=")                 { $isPatch8 = $true }
                if ($line -match """LicensePlateNumberIn""\s*=")               { $isPatch8 = $true }
                if ($line -match "-eq\s*'LicensePlateNumberIn'")               { $isPatch8 = $true }
                if ($line -match "-eq\s*""LicensePlateNumberIn""")             { $isPatch8 = $true }
                if ($line -match '^\s*#.*[Pp]atch\s*8')                        { $isPatch8 = $true }
                if ($line -match '^\s*#.*LicensePlateNumberIn\s*->\s*')        { $isPatch8 = $true }
                $contextStart = [Math]::Max(0, $i - 5)
                for ($j = $contextStart; $j -lt $i; $j++) {
                    if ($lines[$j] -match '[Pp]atch\s*8') { $isPatch8 = $true; break }
                }
                if (-not $isPatch8) {
                    $findings.Add(@{
                        Script = $relName; Line = $lineNum; Level = 'FAIL'
                        Msg    = "Banned pattern: LicensePlateNumberIn"
                        Fix    = "Use licensePlateNumber (BASE) or LicensePlateNumber (MC)"
                    })
                }
            }
        }

        # CHECK 3: Known field type mismatches
        $knownSelFields = @(
            @{ Pattern = "[Ss]ex[Cc]ode";           Label = "SexCode";           AttrHint = "attributeTypeId='SEX'" }
            @{ Pattern = "[Pp]late[Tt]ype";          Label = "PlateType";         AttrHint = "codeTypeCategory" }
            @{ Pattern = "[Rr]egistration[Ss]tate";  Label = "RegistrationState"; AttrHint = "attributeTypeId='STATE'" }
        )
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1
            if ($line -match '^\s*#') { continue }
            foreach ($field in $knownSelFields) {
                $fPat = $field.Pattern
                if ($line -match "(?:^|\s)Inp\s+['""]$fPat['""]") {
                    $findings.Add(@{
                        Script = $relName; Line = $lineNum; Level = 'WARN'
                        Msg    = "$($field.Label) uses Inp -- should be Sel with $($field.AttrHint)"
                        Fix    = "Change Inp to Sel with $($field.AttrHint)"
                    })
                }
            }
            # AP #24: NCIC_FIREARM_MAKE for vehicle make
            if ($line -match "(?:NCIC_FIREARM_MAKE)" -and $line -match "[Vv]ehicle[Mm]ake") {
                $findings.Add(@{
                    Script = $relName; Line = $lineNum; Level = 'WARN'
                    Msg    = "VehicleMakeCode uses NCIC_FIREARM_MAKE (AP #24)"
                    Fix    = "Use attributeTypeId='VEHICLE_MAKE' or Inp for text input"
                })
            }
        }

        # CHECK 4: RMS shared module usage
        $usesRmsModule = $raw -match "Build-RmsBundle|_build_rms_bundle"
        if (-not $usesRmsModule) {
            $findings.Add(@{
                Script = $relName; Line = '--'; Level = 'WARN'
                Msg    = "Does not use Build-RmsBundle -- RMS bundle must come from shared module"
                Fix    = "Dot-source _build_rms_bundle.ps1 and call Build-RmsBundle"
            })
        }

        # CHECK 5: Type safety -- AP #21, AP #22, AP #23
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1
            if ($line -match '^\s*#') { continue }

            # AP #21: templateColumns with integers
            if ($line -match 'templateColumns\s*=\s*@\(([^)]+)\)') {
                $arrayContent = $Matches[1]
                $elements = $arrayContent -split ','
                foreach ($elem in $elements) {
                    if ($elem.Trim() -match '^\d+$') {
                        $findings.Add(@{
                            Script = $relName; Line = $lineNum; Level = 'WARN'
                            Msg    = "templateColumns has integer value '$($elem.Trim())' (AP #21)"
                            Fix    = "Wrap in quotes: '$($elem.Trim())'"
                        })
                        break
                    }
                }
            }

            # AP #22: maxLength as bare integer
            if ($line -match "maxLength\s*=\s*(\d+)" -and $line -notmatch "maxLength\s*=\s*['""]") {
                $isFP = $false
                if ($line -match '^\s*function\s')    { $isFP = $true }
                if ($line -match "Inp\s+['""]")       { $isFP = $true }
                if ($line -match '^\s*if\s')          { $isFP = $true }
                if ($line -match '^\s*#')             { $isFP = $true }
                if ($line -match "description\s*=\s*['""]") { $isFP = $true }
                if ($line -match "['""].*maxLength")  { $isFP = $true }
                if (-not $isFP) {
                    $val = $Matches[1]
                    $findings.Add(@{
                        Script = $relName; Line = $lineNum; Level = 'WARN'
                        Msg    = "maxLength = $val (integer) -- must be string (AP #22)"
                        Fix    = "Change to maxLength = '$val'"
                    })
                }
            }

            # AP #23: autoSelect as string
            if ($line -match "autoSelect\s*=\s*['""](true|false)['""]") {
                $val = $Matches[1]
                $boolVal = if ($val -eq 'true') { '$true' } else { '$false' }
                $findings.Add(@{
                    Script = $relName; Line = $lineNum; Level = 'WARN'
                    Msg    = "autoSelect = '$val' (string) -- must be boolean (AP #23)"
                    Fix    = "Change to autoSelect = $boolVal"
                })
            }
        }
    }

    return $findings
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK KNOWN FLAGS -- PlateYear, PurposeCode DH, REBUILD_TRACKER
# ══════════════════════════════════════════════════════════════════════════════
function Get-KnownFlags([string]$providerDir, [string]$providerName) {
    $flags = [System.Collections.Generic.List[object]]::new()
    $scriptDir = Join-Path $providerDir "scripts"

    # ── PlateYear: check if any build script defines $currentYear ──
    $plateYearOk = $false
    if (Test-Path $scriptDir) {
        $buildScripts = Get-ChildItem $scriptDir -Filter "build_*.ps1" -File -ErrorAction SilentlyContinue
        foreach ($s in $buildScripts) {
            $raw = [System.IO.File]::ReadAllText($s.FullName)
            if ($raw -match '\$currentYear\s*=') {
                $plateYearOk = $true
                break
            }
        }
    }
    if ($plateYearOk) {
        $flags.Add(@{ Level = 'OK'; Label = 'PlateYear'; Msg = "Dynamic `$currentYear defined in build script" })
    } else {
        $flags.Add(@{ Level = 'FLAG'; Label = 'PlateYear'; Msg = "Needs dynamic `$currentYear (both BASE and MC scripts)" })
    }

    # ── PurposeCode DH: for CA_ providers, check JSON for PurposeCode near DriverHistory ──
    if ($providerName -match '^CA_') {
        $purposeCodeOk = $false
        # Check BASE JSON
        $baseJson = Get-ChildItem $providerDir -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($baseJson) {
            $jsonText = [System.IO.File]::ReadAllText($baseJson.FullName)
            # Check if DriverHistory QIDM has PurposeCode attribute
            if ($jsonText -match 'DriverHistory' -and $jsonText -match 'PurposeCode') {
                # More precise check: look for PurposeCode in a QIDM that contains DriverHistory
                # Simple heuristic: if both appear in the file, likely present
                $purposeCodeOk = $true
            }
        }
        if ($purposeCodeOk) {
            $flags.Add(@{ Level = 'OK'; Label = 'PurposeCode DH'; Msg = "PurposeCode attribute found in DriverHistory QIDM" })
        } else {
            if ($baseJson -and ([System.IO.File]::ReadAllText($baseJson.FullName) -match 'DriverHistory')) {
                $flags.Add(@{ Level = 'FLAG'; Label = 'PurposeCode DH'; Msg = "DriverHistoryQuery QIDM missing PurposeCode attribute" })
            } else {
                $flags.Add(@{ Level = 'OK'; Label = 'PurposeCode DH'; Msg = "N/A (no DriverHistoryQuery)" })
            }
        }
    } else {
        $flags.Add(@{ Level = 'OK'; Label = 'PurposeCode DH'; Msg = "N/A (not a CA provider)" })
    }

    # ── REBUILD_TRACKER.md: check for this provider's entry ──
    if (Test-Path $trackerPath) {
        $trackerText = [System.IO.File]::ReadAllText($trackerPath)
        $escapedName = [regex]::Escape($providerName)
        if ($trackerText -match "\|\s*\d+\s*\|\s*$escapedName\s*\|([^\|]+)\|([^\|]+)\|([^\|]+)\|") {
            $trackerWarns    = $Matches[1].Trim()
            $trackerPlateYr  = $Matches[2].Trim()
            $trackerPurpose  = $Matches[3].Trim()
            $flags.Add(@{
                Level = 'FLAG'; Label = 'REBUILD_TRACKER'
                Msg   = "Listed in REBUILD_TRACKER: WARNs=$trackerWarns, PlateYear=$trackerPlateYr, PurposeCode=$trackerPurpose"
            })
        }
    }

    return $flags
}

# ══════════════════════════════════════════════════════════════════════════════
# GENERATE ACTION CHECKLIST from aggregated findings
# ══════════════════════════════════════════════════════════════════════════════
function Build-ActionChecklist {
    param(
        [object[]]$ValidatorWarnsBase,
        [object[]]$ValidatorWarnsMC,
        [object[]]$LintFindings,
        [object[]]$KnownFlags,
        [string]$ProviderName
    )

    $scriptActions  = [System.Collections.Generic.List[string]]::new()
    $rebuildActions = [System.Collections.Generic.List[string]]::new()

    # ── Deduplicate validator WARN fix hints ──
    $seenFixes = @{}

    # Combine BASE + MC warns (deduplicate identical messages)
    $allWarns = @()
    if ($ValidatorWarnsBase) { $allWarns += $ValidatorWarnsBase }
    if ($ValidatorWarnsMC)   { $allWarns += $ValidatorWarnsMC }

    foreach ($w in $allWarns) {
        $fix = $w.Fix
        if (-not $fix) { $fix = Get-FixHint $w.Warn }
        if ($fix -and -not $seenFixes.ContainsKey($fix)) {
            $seenFixes[$fix] = $true
            $scriptActions.Add($fix)
        }
    }

    # ── Lint findings (deduplicate by Msg) ──
    $seenLint = @{}
    foreach ($f in $LintFindings) {
        $key = "$($f.Script):$($f.Msg)"
        if (-not $seenLint.ContainsKey($key)) {
            $seenLint[$key] = $true
            $action = "$($f.Script) line $($f.Line): $($f.Fix)"
            $scriptActions.Add($action)
        }
    }

    # ── Known flags ──
    foreach ($fl in $KnownFlags) {
        if ($fl.Level -eq 'FLAG') {
            $scriptActions.Add("$($fl.Label): $($fl.Msg)")
        }
    }

    # ── Standard rebuild steps ──
    $hasBase = Test-Path (Join-Path (Join-Path $providersDir "*") "scripts\build_$($ProviderName.ToLower())*.ps1") -ErrorAction SilentlyContinue
    $providerLower = $ProviderName.ToLower()
    $rebuildActions.Add("Run build script (BASE): build_$providerLower.ps1")
    $rebuildActions.Add("Run build script (MC): build_${providerLower}_mc.ps1 (if exists)")
    $rebuildActions.Add("Run build_report.ps1 for both variants")
    $rebuildActions.Add("Verify 0 WARN in both BASE and MC validator output")

    return @{
        ScriptActions  = $scriptActions
        RebuildActions = $rebuildActions
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT ONE PROVIDER -- main workhorse
# ══════════════════════════════════════════════════════════════════════════════
function Run-PreflightSingle([string]$provName) {
    # Resolve folder
    $provDir = Join-Path $providersDir $provName
    if (-not (Test-Path $provDir)) {
        Out-Line "  [ERROR] Provider not found: $provName" 'Red'
        return $null
    }

    $cleanProvName = $provName

    # ── Get validator results ────────────────────────────────────────────────
    $baseReport = $null
    $mcReport   = $null

    if ($Quick) {
        # Parse existing report files
        $baseReportFile = Get-ChildItem (Join-Path $provDir "docs\base") -Filter "VALIDATOR_REPORT_*_BASE.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($baseReportFile) {
            $baseText  = [System.IO.File]::ReadAllText($baseReportFile.FullName)
            $baseReport = Parse-ValidatorReport $baseText
        }
        $mcReportFile = Get-ChildItem (Join-Path $provDir "docs\mc") -Filter "VALIDATOR_REPORT_*_MC.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($mcReportFile) {
            $mcText  = [System.IO.File]::ReadAllText($mcReportFile.FullName)
            $mcReport = Parse-ValidatorReport $mcText
        }
    } else {
        # Run validator live
        $baseJson = Get-ChildItem $provDir -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        $mcJson = Get-ChildItem $provDir -Filter "*_MC.json" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '_MC_BASE' } | Select-Object -First 1

        $validatorPath = Join-Path $toolDir "validate.ps1"
        if ($baseJson -and (Test-Path $validatorPath)) {
            Write-Host "  Running validator: $($baseJson.Name)..." -ForegroundColor DarkGray -NoNewline
            $validatorOut = & powershell -ExecutionPolicy Bypass -File $validatorPath -Path $baseJson.FullName -Force 2>&1 | Out-String
            $baseReport = Parse-ValidatorReport $validatorOut
            Write-Host " done" -ForegroundColor DarkGray
        }
        if ($mcJson -and (Test-Path $validatorPath)) {
            Write-Host "  Running validator: $($mcJson.Name)..." -ForegroundColor DarkGray -NoNewline
            $validatorOut = & powershell -ExecutionPolicy Bypass -File $validatorPath -Path $mcJson.FullName -Force 2>&1 | Out-String
            $mcReport = Parse-ValidatorReport $validatorOut
            Write-Host " done" -ForegroundColor DarkGray
        }
    }

    # ── Format score strings ─────────────────────────────────────────────────
    $baseScoreStr = if ($baseReport) { "$($baseReport.Pass)P/$($baseReport.Fail)F/$($baseReport.Warn)W/$($baseReport.Limit)LIM" } else { "--" }
    $mcScoreStr   = if ($mcReport)   { "$($mcReport.Pass)P/$($mcReport.Fail)F/$($mcReport.Warn)W/$($mcReport.Limit)LIM" } else { "--" }

    # ── Lint build scripts ───────────────────────────────────────────────────
    $lintFindings = Lint-BuildScripts $provDir

    # ── Known flags ──────────────────────────────────────────────────────────
    $knownFlags = Get-KnownFlags $provDir $cleanProvName

    # ── Build action checklist ───────────────────────────────────────────────
    $baseWarns = if ($baseReport) { $baseReport.Warns } else { @() }
    $mcWarns   = if ($mcReport)   { $mcReport.Warns }   else { @() }
    $checklist = Build-ActionChecklist -ValidatorWarnsBase $baseWarns -ValidatorWarnsMC $mcWarns `
        -LintFindings $lintFindings -KnownFlags $knownFlags -ProviderName $cleanProvName

    # ══════════════════════════════════════════════════════════════════════
    # RENDER REPORT
    # ══════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Divider
    Out-Line "  Preflight Rebuild: $cleanProvName" "Cyan"
    Out-Line "  Current: $baseScoreStr (BASE) | $mcScoreStr (MC)" "White"
    Out-Divider
    Out-Line ""

    # ── SECTION 1: Validator WARNs (BASE) ────────────────────────────────
    $baseWarnCount = if ($baseReport) { $baseReport.Warn } else { 0 }
    Out-Line "  SECTION 1: Validator WARNs (BASE -- $baseWarnCount WARNs)" "Yellow"
    if ($baseReport -and $baseReport.Warns.Count -gt 0) {
        foreach ($w in $baseReport.Warns) {
            Out-Line "    [WARN] $($w.Warn)" "Yellow"
            $fix = $w.Fix
            if (-not $fix) { $fix = Get-FixHint $w.Warn }
            if ($fix) {
                Out-Line "    [FIX]  $fix" "Cyan"
            }
        }
    } elseif ($baseWarnCount -eq 0) {
        Out-Line "    (none)" "Green"
    } else {
        Out-Line "    (no report available -- run without -Quick)" "DarkGray"
    }
    Out-Line ""

    # ── SECTION 1b: Validator WARNs (MC) ─────────────────────────────────
    $mcWarnCount = if ($mcReport) { $mcReport.Warn } else { 0 }
    Out-Line "  SECTION 1b: Validator WARNs (MC -- $mcWarnCount WARNs)" "Yellow"
    if ($mcReport -and $mcReport.Warns.Count -gt 0) {
        foreach ($w in $mcReport.Warns) {
            Out-Line "    [WARN] $($w.Warn)" "Yellow"
            $fix = $w.Fix
            if (-not $fix) { $fix = Get-FixHint $w.Warn }
            if ($fix) {
                Out-Line "    [FIX]  $fix" "Cyan"
            }
        }
    } elseif ($mcWarnCount -eq 0) {
        Out-Line "    (none)" "Green"
    } else {
        Out-Line "    (no MC report available)" "DarkGray"
    }
    Out-Line ""

    # ── SECTION 2: Build Script Issues ───────────────────────────────────
    Out-Line "  SECTION 2: Build Script Issues" "Yellow"
    if ($lintFindings.Count -gt 0) {
        # Group by script name
        $grouped = @{}
        foreach ($f in $lintFindings) {
            if (-not $grouped.ContainsKey($f.Script)) {
                $grouped[$f.Script] = [System.Collections.Generic.List[object]]::new()
            }
            $grouped[$f.Script].Add($f)
        }
        foreach ($scriptName in ($grouped.Keys | Sort-Object)) {
            Out-Line "    $scriptName`:" "White"
            foreach ($f in $grouped[$scriptName]) {
                $levelColor = switch ($f.Level) { 'FAIL' { 'Red' } 'WARN' { 'Yellow' } default { 'White' } }
                Out-Line "      [$($f.Level)] Line $($f.Line): $($f.Msg)" $levelColor
                Out-Line "      [FIX]  $($f.Fix)" "Cyan"
            }
        }
    } else {
        Out-Line "    (none)" "Green"
    }
    Out-Line ""

    # ── SECTION 3: Known Flags ───────────────────────────────────────────
    Out-Line "  SECTION 3: Known Flags" "Yellow"
    foreach ($fl in $knownFlags) {
        $color = if ($fl.Level -eq 'OK') { 'Green' } else { 'Magenta' }
        $tag   = if ($fl.Level -eq 'OK') { '[OK]  ' } else { '[FLAG]' }
        Out-Line "    $tag $($fl.Label): $($fl.Msg)" $color
    }
    Out-Line ""

    # ── SECTION 4: Action Checklist ──────────────────────────────────────
    Out-Line "  SECTION 4: Action Checklist" "White"
    $actionNum = 0
    if ($checklist.ScriptActions.Count -gt 0) {
        Out-Line "    BUILD SCRIPT CHANGES:" "White"
        foreach ($action in $checklist.ScriptActions) {
            $actionNum++
            Out-Line "      $actionNum. $action" "White"
        }
    }
    Out-Line "    REBUILD REQUIRED:" "White"
    foreach ($action in $checklist.RebuildActions) {
        $actionNum++
        Out-Line "      $actionNum. $action" "White"
    }
    Out-Line ""

    # ── Footer totals ────────────────────────────────────────────────────
    $lintWarnCount = ($lintFindings | Where-Object { $_.Level -eq 'WARN' }).Count
    $lintFailCount = ($lintFindings | Where-Object { $_.Level -eq 'FAIL' }).Count
    $flagCount = ($knownFlags | Where-Object { $_.Level -eq 'FLAG' }).Count
    $totalIssues = $baseWarnCount + $mcWarnCount + $lintWarnCount + $lintFailCount + $flagCount
    Out-Divider
    Out-Line "  Total: $baseWarnCount BASE WARNs + $mcWarnCount MC WARNs + $($lintWarnCount + $lintFailCount) script issues + $flagCount flags = $totalIssues total" "White"
    Out-Divider
    Out-Line ""

    # Return summary for -All mode
    return @{
        Provider      = $cleanProvName
        BaseWarns     = $baseWarnCount
        McWarns       = $mcWarnCount
        ScriptIssues  = $lintWarnCount + $lintFailCount
        Flags         = $flagCount
        TotalActions  = $actionNum
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

Out-Line ""
Out-Line "================================================================" "Cyan"
Out-Line "  Preflight Rebuild Report -- $timestamp" "Cyan"
if ($Quick) { Out-Line "  Mode: QUICK (parsing existing reports)" "DarkYellow" }
else        { Out-Line "  Mode: LIVE (running validator + lint)" "DarkYellow" }
Out-Line "================================================================" "Cyan"

$summaryRows = [System.Collections.Generic.List[object]]::new()

if ($Provider) {
    # ── Single provider mode ──
    $result = Run-PreflightSingle $Provider
    if ($result) { $summaryRows.Add($result) }

} elseif ($All) {
    # ── All providers mode ──
    # Discover all providers, run preflight for those with WARNs > 0
    $providerDirs = Get-ChildItem $providersDir -Directory | Sort-Object Name
    $skipped = 0

    foreach ($dir in $providerDirs) {
        $folderName = $dir.Name
        $cleanName  = $folderName

        # Quick check: does this provider have WARNs?
        $needsRebuild = $false

        if ($Quick) {
            # Parse existing report to check WARN count
            $baseReportFile = Get-ChildItem (Join-Path $dir.FullName "docs\base") -Filter "VALIDATOR_REPORT_*_BASE.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($baseReportFile) {
                $text = [System.IO.File]::ReadAllText($baseReportFile.FullName)
                $parsed = Parse-ValidatorReport $text
                if ($parsed.Warn -gt 0) { $needsRebuild = $true }
            }
            $mcReportFile = Get-ChildItem (Join-Path $dir.FullName "docs\mc") -Filter "VALIDATOR_REPORT_*_MC.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($mcReportFile) {
                $text = [System.IO.File]::ReadAllText($mcReportFile.FullName)
                $parsed = Parse-ValidatorReport $text
                if ($parsed.Warn -gt 0) { $needsRebuild = $true }
            }
            # Also check build script for PlateYear (even 0-WARN providers may need script fixes)
            $scriptDir = Join-Path $dir.FullName "scripts"
            if (Test-Path $scriptDir) {
                $buildScripts = Get-ChildItem $scriptDir -Filter "build_*.ps1" -File -ErrorAction SilentlyContinue
                foreach ($s in $buildScripts) {
                    $raw = [System.IO.File]::ReadAllText($s.FullName)
                    if ($raw -notmatch '\$currentYear\s*=') { $needsRebuild = $true; break }
                }
            }
        } else {
            # In live mode, just run everything -- we filter at the end
            $needsRebuild = $true
        }

        if (-not $needsRebuild) {
            $skipped++
            continue
        }

        $result = Run-PreflightSingle $cleanName
        if ($result) { $summaryRows.Add($result) }
    }

    # ── Summary table ────────────────────────────────────────────────────
    if ($summaryRows.Count -gt 0) {
        Out-Line ""
        Out-Divider
        Out-Line "  REBUILD SUMMARY" "Cyan"
        Out-Divider
        Out-Line ""

        $colProv   = 26
        $colWarns  = 10
        $colScript = 18
        $colFlags  = 10
        $colTotal  = 16

        $header = "  {0,-$colProv} {1,-$colWarns} {2,-$colScript} {3,-$colFlags} {4}" -f "Provider", "WARNs", "Script Issues", "Flags", "Total Actions"
        Out-Line $header "White"
        $divLine = "  {0,-$colProv} {1,-$colWarns} {2,-$colScript} {3,-$colFlags} {4}" -f ("-" * ($colProv - 1)), ("-" * ($colWarns - 1)), ("-" * ($colScript - 1)), ("-" * ($colFlags - 1)), ("-" * ($colTotal - 1))
        Out-Line $divLine "DarkGray"

        # Sort by total WARNs descending
        $sorted = $summaryRows | Sort-Object { $_.BaseWarns + $_.McWarns } -Descending

        $grandWarns   = 0
        $grandScript  = 0
        $grandFlags   = 0
        $grandActions = 0

        foreach ($row in $sorted) {
            $totalWarns = $row.BaseWarns + $row.McWarns
            $warnStr    = "$totalWarns"

            $line = "  {0,-$colProv} {1,-$colWarns} {2,-$colScript} {3,-$colFlags} {4}" -f `
                "$($row.Provider)", $warnStr, $row.ScriptIssues, $row.Flags, $row.TotalActions

            $color = if ($totalWarns -gt 10) { 'Red' } elseif ($totalWarns -gt 0) { 'Yellow' } else { 'White' }
            Out-Line $line $color

            $grandWarns   += $totalWarns
            $grandScript  += $row.ScriptIssues
            $grandFlags   += $row.Flags
            $grandActions += $row.TotalActions
        }

        Out-Line ""
        Out-Divider
        Out-Line "  GRAND TOTAL: $($summaryRows.Count) providers | $grandWarns WARNs | $grandScript script issues | $grandFlags flags | $grandActions total actions" "Cyan"
        if ($skipped -gt 0) {
            Out-Line "  SKIPPED: $skipped providers (0 WARNs, no script issues)" "Green"
        }
        Out-Divider
        Out-Line ""
    } else {
        Out-Line ""
        Out-Line "  All providers are clean -- no rebuilds needed." "Green"
        Out-Line ""
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# SAVE TO FILE
# ══════════════════════════════════════════════════════════════════════════════
if ($OutFile) {
    $outDir = Split-Path $OutFile -Parent
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllLines(
        $OutFile,
        [string[]]$script:reportLines,
        (New-Object System.Text.UTF8Encoding $false)
    )
    Write-Host "  Report saved to: $OutFile" -ForegroundColor Green
}
