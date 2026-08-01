<#
  audit_ps51_parse.ps1 -- can every tool script actually be PARSED by the engine that runs it?

  WHY THIS EXISTS
    pipeline.ps1 / enforce.ps1 invoke tools as `powershell -File ...` = Windows PowerShell 5.1.
    Interactive work in this repo often happens under pwsh 7. The two engines do NOT accept the
    same source, so a tool can be developed, run, and "verified" under 7 while being a HARD PARSE
    FAILURE under 5.1 -- and a parse failure is not a FAIL line in a report, it is a wall of
    ParserError text that whatever called it may swallow. On 2026-08-01 sync_session_state.ps1 was
    exactly this: it silently broke pipeline step 8, and audit_defect_classes.ps1 had the same
    defect while being used all day (it is not wired into a gate, so nothing caught it).

  THE TWO 5.1-ONLY FAILURE MODES FOUND SO FAR
    1. NON-ASCII INSIDE A DOUBLE-QUOTED / INTERPOLATED STRING, in a file with no UTF-8 BOM.
       5.1 decodes a BOM-less file as cp1252. An em-dash (U+2014 = E2 80 94) and a box-drawing
       char (U+2500 = E2 94 80) BOTH contain byte 0x94, which cp1252 maps to a RIGHT DOUBLE
       QUOTATION MARK -- and 5.1 treats that as a string delimiter, so the string terminates
       mid-line and the rest of the file misparses.
       This repo has 66 BOM-less scripts full of box-drawing characters that are FINE, because
       theirs sit in SINGLE-quoted strings where 5.1 never scans for interpolation.
       RULE: non-ASCII is fine in '...', NEVER in "...$x...". Use ASCII '--' and '---' there.
    2. NESTED SAME-TYPE QUOTES INSIDE $( ) INSIDE A STRING, e.g.
           "$($a)$(if($b){" -- $($b) owed"})"
       PowerShell 7 parses it; 5.1 does not.

  WHY IT PRINTS THE ENGINE VERSION
    The first version of this check was run by pwsh 7, so it used the PS7 grammar and reported
    "99 scanned / 0 failures" while TWO files were broken under 5.1. That is the same defect class
    as the JAWS-only XML misread: A CHECK THAT CONSULTS THE WRONG AUTHORITY CANNOT FAIL HONESTLY.
    So this script REFUSES to report a clean verdict unless it is running on 5.1, and it always
    prints the engine and the denominator.

  Usage: powershell -ExecutionPolicy Bypass -File tools\audit_ps51_parse.ps1 [-OutFile <path>]
         (deliberately NOT `pwsh` -- that would defeat the point)
#>
[CmdletBinding()]
param([string]$OutFile)

$repo    = Split-Path $PSScriptRoot -Parent
$toolDir = $PSScriptRoot
$lines   = @()
function O([string]$t, [string]$c = 'Gray') { $script:lines += $t; Write-Host $t -ForegroundColor $c }

O ('=' * 100) 'Cyan'
O '  PS 5.1 PARSE GATE -- every tool script must parse on the engine that actually runs it' 'Cyan'
O ('=' * 100) 'Cyan'

$engine   = $PSVersionTable.PSVersion
$is51     = ($engine.Major -eq 5)
O ("  engine: PowerShell $engine   edition: $($PSVersionTable.PSEdition)")
if (-not $is51) {
    O ''
    O '  [FAIL] WRONG ENGINE -- this check is meaningless here.' 'Red'
    O '         You are on PowerShell 7+, whose grammar ACCEPTS constructs 5.1 rejects, so a clean' 'Red'
    O '         result would be a false negative. That exact mistake was made on 2026-08-01: a pwsh-7' 'Red'
    O '         run reported 99/0 while two files were hard parse failures under 5.1.' 'Red'
    O '         Re-run as:  powershell -ExecutionPolicy Bypass -File tools\audit_ps51_parse.ps1' 'Yellow'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

$scripts = @(Get-ChildItem $toolDir -Filter '*.ps1' -File | Sort-Object Name)
$bad = 0
foreach ($s in $scripts) {
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($s.FullName, [ref]$null, [ref]$errs)
    if (@($errs).Count) {
        $bad++
        $e0 = @($errs)[0]
        O ("  [FAIL] {0,-40} {1} parse error(s); first at line {2}: {3}" -f `
            $s.Name, @($errs).Count, $e0.Extent.StartLineNumber, $e0.Message) 'Red'
        # the most likely cause, named, so the fix is obvious rather than a hunt
        $txt = [IO.File]::ReadAllText($s.FullName)
        $b   = [IO.File]::ReadAllBytes($s.FullName)
        $hasBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
        $ln  = $e0.Extent.StartLineNumber
        $src = @([IO.File]::ReadAllLines($s.FullName))
        if ($ln -ge 1 -and $ln -le $src.Count) {
            $line = $src[$ln - 1]
            $na = @($line.ToCharArray() | Where-Object { [int]$_ -gt 127 })
            if ($na.Count -and -not $hasBom -and $line -match '"') {
                O ("         LIKELY CAUSE: non-ASCII ({0}) inside a double-quoted string in a BOM-less file." -f `
                    (($na | ForEach-Object { 'U+{0:X4}' -f [int]$_ }) -join ' ')) 'Yellow'
                O '         Replace with ASCII (-- / ---), or move it into a SINGLE-quoted string.' 'Yellow'
            } elseif ($line -match '\$\(.*"') {
                O '         LIKELY CAUSE: nested double quotes inside $() -- PS7 allows it, 5.1 does not.' 'Yellow'
                O '         Compute the fragment into a variable on its own line first.' 'Yellow'
            }
        }
    }
}

O ''
O ("  RESULT: {0} scanned / {1} PARSE-FAIL   [engine {2}]" -f $scripts.Count, $bad, $engine) `
    $(if ($bad) { 'Red' } else { 'Green' })
if (-not $bad) { O '  Every tool script parses on the engine pipeline/enforce use to run them.' 'Green' }

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit $(if ($bad) { 1 } else { 0 })
