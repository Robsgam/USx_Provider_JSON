<#
  audit_data_mined.ps1 -- DATA-MINED TRANSACTIONS: what the state runs FOR us, and what that means
                          for "unbuilt" findings.

  WHY THIS EXISTS (2026-08-24, TN_TIES post-mortem -- Rob: "make sure we dont have this issue
  debated again"):
    TN_TIES carried a note in FOUR places -- SESSION_STATE, FINDINGS_REGISTER twice, and its own
    BUILD_NOTES -- reading:
        "metadata RQ01{LicensePlateNumber} ... is NOT BUILT -- the build serves the blank-State
         plate case with QV.P instead. Whether an in-state TN plate search should reach the
         TIES/DMV transaction rather than the NCIC one is a routing question for Rob."
    It sat there as an open functional risk. It was neither open nor a risk, for two reasons that
    are BOTH mechanical and BOTH invisible to every existing gate:

    (1) THE KEYREF NEVER REACHES THE WIRE. A request carries
        <MessageType><QueryName></MessageType> plus the FIELDS. Nothing else identifies the
        transaction. Rob, 2026-08-24: "we only send the VehicleRegistrationQuery and not the
        transaction name." So naming a combination `QV.P` vs `RQ01` emits BYTE-IDENTICAL bytes and
        cannot change where the query goes. "We built keyRef X instead of Y" is therefore NEVER a
        functional defect on its own -- only the QUERY NAME and the FIELD SET can be wrong.

    (2) `QV` IS A DATA-MINED TRANSACTION, and the devdoc SAYS SO on its own line:
        "Data-Mined Transactions: NCIC (QA, QB, QG, QV, QW) and DMV (Person and Vehicle) Tags
         returned from Data mining"
        A data-mined transaction is one the STATE runs off our single request, returning its tags in
        the response. We never send it as a separate query. So a metadata combination whose keyRef is
        a mined transaction is not a gap to fill, and building no separate stolen/wanted query for a
        mined file is CORRECT rather than an omission.

  WHY NO GATE CAUGHT IT: `audit_supported_queries` uses the string "Data-Mined Transactions" purely
  as a BOUNDARY MARKER to stop parsing the Basic list (lines 88 and 134) -- it reads past the content
  and throws it away. The devdoc tells us exactly which transactions are mined and, until this tool,
  NOTHING in the repo had ever read that sentence. Measured 2026-08-24: 17 of 20 devdocs declare the
  line, so this is portfolio-wide, not a TN quirk.

  PARSE NOTE -- the content is usually on the FOLLOWING line(s), not after the colon. pdftotext wraps
  it, and one provider carries a provider-specific extra (NJ_NJCJIS: "NCIC (QA, QB, QG, QV, QW),
  NJWP, and DMV (Person and Vehicle)"). Reading only the label line finds content on 4 of 20 and
  reports the other 13 as empty -- the same wrap trap that made audit_supported_queries under-read
  NJ as 1-of-6 supported queries. So: read the label, then continue across lines until a blank line,
  a page footer, or the next "<Something>:" heading.

  WHAT IT REPORTS
    DECLARED   -- the mined transaction tokens this provider's devdoc names.
    DM1 NOTE   -- built combinations whose keyRef matches a mined token, annotated so the next reader
                  sees "this is mined" beside the combo instead of re-deriving it. NOT a finding.
    DM2        -- mined transactions declared but the QRDM carries NO hit/related mapping to receive
                  their tags. THIS is the real risk, and it is the one thing in this area that can
                  actually cost an officer a hit. WARN.
    DM3 NOTE   -- config-present-but-unexercised: the QRDM has the mapping and the provider has no
                  logs proving a mined hit renders. Same class as HI's unverified NCIC hit block.

  ADVISORY, always exits 0. It exists to STOP a debate, not to start one: a mined transaction is a
  fact about the provider, not a defect, and the only actionable line it emits is DM2.

  Usage:
    audit_data_mined.ps1 -Provider TN_TIES
    audit_data_mined.ps1 -All [-Quiet] [-OutFile <path>]
#>
param(
    [string]$Provider,
    [string[]]$Providers,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
. "$PSScriptRoot\_resolve_provider_json.ps1"

$out = New-Object System.Collections.Generic.List[string]
function Emit($s) { $out.Add($s) | Out-Null; if (-not $Quiet) { Write-Host $s } }

# ---- devdoc parse ---------------------------------------------------------------------------
# Returns @{ Declared = <raw text>; Tokens = @(...); Found = $true/$false }
function Get-MinedDeclaration([string]$provDir, [string]$prov) {
    $cands = @(
        (Join-Path $provDir "source\${prov}_DEVDOC.txt")
    )
    # variant fallback: a <BASE>_<VARIANT> provider inherits its base's devdoc (CLAUDE.md)
    if ($prov -match '^(.+)_[A-Z0-9]+$') {
        $base = $Matches[1]
        $cands += (Join-Path $repoRoot "providers\$base\source\${base}_DEVDOC.txt")
        $cands += (Join-Path $provDir "source\${base}_DEVDOC.txt")
    }
    $f = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $f) { return @{ Found = $false; Declared = ''; Tokens = @(); Why = 'no devdoc text' } }

    $lines = Get-Content $f
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '(?i)^\s*Data-Mined Transactions\s*:') { $idx = $i; break }
    }
    if ($idx -lt 0) { return @{ Found = $false; Declared = ''; Tokens = @(); Why = 'devdoc declares no Data-Mined line' } }

    # Content may trail the colon AND/OR continue on following lines.
    # A LEADING BLANK LINE IS LEGAL AND MUST NOT END THE READ -- HI_HCJDC_OFML puts a blank line
    # between the label and its content, and the first version of this parser stopped there and
    # reported HI as declaring NOTHING. That false "none" is exactly the defect class this file was
    # written to prevent, and it was caught only by hand-checking a provider the tool called empty.
    # So: blanks BEFORE any content are skipped; a blank AFTER content has started ends the block.
    $buf = New-Object System.Collections.Generic.List[string]
    $tail = ($lines[$idx] -replace '(?i)^\s*Data-Mined Transactions\s*:', '').Trim()
    if ($tail) { $buf.Add($tail) | Out-Null }
    $blanksBefore = 0
    for ($i = $idx + 1; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if ($t -eq '') {
            if ($buf.Count -gt 0) { break }          # blank after content -> done
            $blanksBefore++
            if ($blanksBefore -gt 3) { break }       # a genuinely empty declaration
            continue
        }
        if ($t -match '(?i)^(Basic Quer|Transactions Supported|Expanded|Additional Transactions|Logon|Certification|Security|Routing)') { break }
        if ($t -match 'CommSys, Inc' -or $t -match '(?i)^page\s+\d+' -or $t -match 'NDA Required') { continue }
        if ($t -match '^\s*[A-Z][A-Za-z ]{2,30}:\s*$') { break }
        $buf.Add($t) | Out-Null
    }
    $decl = ($buf -join ' ').Trim()

    # tokens: bare NCIC-style codes (2-5 chars, upper+digits) plus the DMV phrase
    $tokens = @()
    foreach ($m in [regex]::Matches($decl, '\b([A-Z]{2}[A-Z0-9]{0,3})\b')) {
        $v = $m.Groups[1].Value
        if ($v -in @('NCIC','DMV','AND','NONE')) { continue }
        $tokens += $v
    }
    if ($decl -match '(?i)DMV') { $tokens += 'DMV' }
    $tokens = @($tokens | Sort-Object -Unique)
    return @{ Found = $true; Declared = $decl; Tokens = $tokens; Why = '' }
}

# ---- provider scope -------------------------------------------------------------------------
$names = @()
if ($All)            { $names = @(Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name | ForEach-Object { $_.Name }) }
elseif ($Providers)  { $names = @($Providers) }
elseif ($Provider)   { $names = @($Provider) }
else {
    Write-Host "[NOTE] audit_data_mined: pass -Provider <name>, -Providers <list> or -All."
    exit 0
}

Emit ''
Emit '===================================================================================================='
Emit '  DATA-MINED TRANSACTIONS -- what the state runs for us, and why that is not an unbuilt gap'
Emit '===================================================================================================='
Emit ''
Emit '  THE TWO MECHANICAL FACTS THIS TOOL EXISTS TO STOP RE-DEBATING:'
Emit '    1. The keyRef NEVER reaches the wire. A request carries <MessageType><QueryName></MessageType>'
Emit '       plus the FIELDS -- nothing else. So "we built keyRef X not Y" cannot change where a query'
Emit '       goes, and is never a functional defect on its own. Only the query name and field set can be.'
Emit '    2. A DATA-MINED transaction is run BY THE STATE off our single request; its tags come back in'
Emit '       the response. We never send it separately, so it is not a combination we owe.'
Emit ''

$examined = 0; $withDecl = 0; $skipped = @()
$dm2 = 0; $dm3 = 0; $dm1total = 0

foreach ($n in $names) {
    $pd = Join-Path $repoRoot "providers\$n"
    if (-not (Test-Path $pd)) { $skipped += "$n (no such provider)"; continue }
    $jp = Get-ProviderRootJson -ProvDir $pd -Provider $n
    if (-not $jp) { $skipped += "$n (no active JSON)"; continue }

    $decl = Get-MinedDeclaration $pd $n
    $examined++

    if (-not $decl.Found) {
        Emit ("  {0,-22} [NOTE] {1} -- nothing to reconcile" -f $n, $decl.Why)
        continue
    }
    if ($decl.Declared -eq '' -or $decl.Declared -match '(?i)^none') {
        Emit ("  {0,-22} DECLARED: none ('{1}')" -f $n, $decl.Declared)
        continue
    }
    $withDecl++
    Emit ("  {0,-22} DECLARED: {1}" -f $n, $decl.Declared)
    Emit ("  {0,-22}   tokens: {1}" -f '', ($decl.Tokens -join ', '))

    # ---- DM1: built combos whose keyRef matches a mined token -------------------------------
    $j = Get-Content $jp -Raw | ConvertFrom-Json
    $minedCombos = @(); $qrdmHit = $false
    foreach ($b in @($j.bundles)) {
        $isRms = ("$($b.provider)" -eq 'RMS')
        foreach ($c in @($b.configurations)) {
            if ($c.type -eq 'QUERYRESULTDATAMAPPING' -and -not $isRms) {
                $txt = $c | ConvertTo-Json -Depth 40
                if ($txt -match '(?i)"(name|targetField)":\s*"[^"]*(hit|related)[^"]*"') { $qrdmHit = $true }
            }
            if ($c.type -ne 'QUERYINPUTDATAMAPPING' -or $isRms) { continue }
            foreach ($k in @($c.combinations)) {
                $kr = "$($k.keyReference)"
                foreach ($tok in $decl.Tokens) {
                    if ($tok -eq 'DMV') { continue }
                    # keyRef may be the bare token or a synthetic split of it (QV -> QV.P / QV.V)
                    if ($kr -eq $tok -or $kr -match ("^" + [regex]::Escape($tok) + "[\.\-_]")) {
                        $minedCombos += "$($c.targetEntity)/$kr (mined: $tok)"
                    }
                }
            }
        }
    }
    $minedCombos = @($minedCombos | Sort-Object -Unique)
    $dm1total += $minedCombos.Count
    if ($minedCombos.Count) {
        Emit ("  {0,-22}   [DM1 NOTE] {1} built combination(s) named after a MINED transaction -- EXPECTED, not a gap:" -f '', $minedCombos.Count)
        foreach ($mc in $minedCombos) { Emit ("  {0,-22}      {1}" -f '', $mc) }
        Emit ("  {0,-22}      A gate reporting the mined sibling 'unbuilt' is reporting a NON-ISSUE. Do not 'fix' it." -f '')
    }

    # ---- DM2 / DM3: can we RECEIVE the mined tags? ------------------------------------------
    if (-not $qrdmHit) {
        Emit ("  {0,-22}   [DM2 WARN] mined transactions declared but the QRDM carries NO hit/related mapping --" -f '')
        Emit ("  {0,-22}              the state returns tags we cannot surface. THIS is the actionable one." -f '')
        $dm2++
    } else {
        $logDir = Join-Path $pd 'logs'
        $logCount = 0
        if (Test-Path $logDir) {
            $logCount = @(Get-ChildItem $logDir -Recurse -Filter '*.txt' -ErrorAction SilentlyContinue |
                          Where-Object { $_.FullName -notmatch '[\\/]_archive' }).Count
        }
        if ($logCount -eq 0) {
            Emit ("  {0,-22}   [DM3 NOTE] QRDM mapping present but CONFIG-PRESENT-NOT-VERIFIED: no logs at all." -f '')
            Emit ("  {0,-22}              Make 'does a mined hit render?' a stated objective of the first sweep." -f '')
            $dm3++
        } else {
            Emit ("  {0,-22}   QRDM hit/related mapping PRESENT; {1} log(s) on disk. Rendering of a MINED hit is" -f '', $logCount)
            Emit ("  {0,-22}   still only proven by a query that actually returns one -- config presence is not proof." -f '')
        }
    }
}

Emit ''
if ($examined -eq 0) {
    Emit '  [NO-VERDICT] 0 provider(s) examined -- nothing was compared, this is NOT a clean result.'
    if ($skipped.Count) { Emit ("               SKIPPED: {0}" -f ($skipped -join ', ')) }
} else {
    Emit ("  EXAMINED: {0} provider(s) / {1} declare mined transactions / {2} mined-named combination(s) annotated" -f $examined, $withDecl, $dm1total)
    Emit ("  DM2 (no QRDM mapping, ACTIONABLE): {0}   DM3 (present but unexercised): {1}" -f $dm2, $dm3)
    if ($skipped.Count) { Emit ("  SKIPPED: {0}" -f ($skipped -join ', ')) }
    if ($dm2 -eq 0) { Emit '  [PASS] every provider declaring mined transactions can receive their tags.' }
}
Emit '  ADVISORY -- always exits 0. DM1 exists to CLOSE a debate; only DM2 is work.'
Emit '===================================================================================================='

if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllLines((Resolve-Path -LiteralPath (New-Item -ItemType File -Force -Path $OutFile).FullName), $out, (New-Object System.Text.UTF8Encoding($false)))
}
exit 0
