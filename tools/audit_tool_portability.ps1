<#
  audit_tool_portability.ps1 -- does every shared gate actually RUN on every provider?

  WHY THIS EXISTS (Rob, 2026-08-01: "shared tools need to work everywhere")
    Every gate in this repo is provider-agnostic BY INTENTION, and several were provider-specific BY
    ACCIDENT -- each discovered only when someone happened to run it somewhere new:
      * _resolve_provider_xml did not exist, so four tools hand-rolled an alphabetical `*.xml` glob.
        On the ONE provider with two XMLs it silently read a 6-node excerpt as if it were the
        466-node metadata and reported green.
      * audit_requirement_fidelity compared SOURCEFIELDS to metadata references, so any provider that
        named a control unexpectedly (VehNameLast, OwnerLastName, firearmMake) produced false findings.
      * its $formOnly whitelist was written in sourceField spellings, so the moment comparison moved
        to targetField space it stopped matching -- on AZ only.
      * sync_session_state.ps1 was a hard PARSE FAILURE under PowerShell 5.1 while working under
        pwsh 7, so it silently broke a pipeline step.
    Every one of those was invisible until a tool met a provider it had never met.

  WHAT THIS MEASURES -- and what it deliberately does NOT
    NOT whether a gate PASSES. A FAIL is a real answer and is fine here.
    IT MEASURES whether the gate can RUN AND REACH A VERDICT at all:
      [OK]        emitted a recognisable verdict line
      [NO-VERDICT] exited without one -- a step that did not run is NOT a pass, and this is exactly
                   how a tool "passes" a provider it cannot actually handle
      [CRASH]     threw, or exited non-zero with no verdict
    A gate that cannot reach a verdict on a provider is UNPORTABLE THERE, regardless of what the
    green board says.

  Usage: powershell -ExecutionPolicy Bypass -File tools\audit_tool_portability.ps1 [-OutFile <path>]
#>
[CmdletBinding()]
param([string]$OutFile, [string[]]$Only)

$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot '_resolve_provider_json.ps1')

$lines = @()
function O([string]$t, [string]$c = 'Gray') { $script:lines += $t; Write-Host $t -ForegroundColor $c }

# Path-taking gates only. Provider-scoped or repo-wide tools have their own invocation contract and
# are covered by enforce; mixing them here would produce noise, not signal.
$gates = @(
    'validate.ps1', 'verify_build.ps1', 'audit_metadata.ps1', 'audit_cad.ps1',
    'audit_combo_reachability.ps1', 'audit_requirement_fidelity.ps1',
    'audit_devdoc_combinations.ps1', 'audit_devdoc_optionals.ps1', 'audit_devdoc_order.ps1',
    'audit_supported_queries.ps1', 'audit_sqvr_integrity.ps1', 'audit_log_combo_attribution.ps1',
    # Added 2026-08-02. audit_wiring_closure is BLOCKING in enforce PHASE 2t and was absent here, so
    # nothing had ever confirmed it reaches a verdict on all 20 providers -- the exact property this
    # sweep exists to measure. It was excluded only because it originally took -Provider and could not
    # be pointed at a path; a -Path mode was added the same day for the mutation harness, which makes
    # it auditable here too. Second time in one day a new gate turned out to be missing from a
    # harness that characterises the stack: check EVERY harness when adding a gate, not just enforce.
    'audit_wiring_closure.ps1'
)
# A verdict is any line a human would read as "this tool finished and reached a conclusion".
$verdictRx = '(?m)^\s*(?:RESULT|RESULTS|TOTALS|Total|VERDICT|SUMMARY)\s*:|VERIFICATION (?:PASSED|FAILED)|^\s*\[(?:PASS|FAIL|NOTE|INFO)\]'

$provs = @(Get-ChildItem (Join-Path $repo 'providers') -Directory | Sort-Object Name | ForEach-Object { $_.Name })
if ($Only) { $provs = @($provs | Where-Object { $Only -contains $_ }) }

O ('=' * 112) 'Cyan'
O '  TOOL PORTABILITY -- can every shared gate RUN and reach a verdict on every provider?' 'Cyan'
O '  Measures REACHABILITY OF A VERDICT, not pass/fail. A FAIL is a fine answer; silence is not.' 'Cyan'
O ('=' * 112) 'Cyan'
O ("  gates: {0}   providers: {1}   cells: {2}" -f $gates.Count, $provs.Count, ($gates.Count * $provs.Count))
O ''

$bad = @()
$cells = 0
foreach ($p in $provs) {
    $jp = Get-ProviderRootJson -ProvDir (Join-Path $repo "providers\$p") -Provider $p
    if (-not $jp) { O ("  [SKIP] $p -- no root JSON") 'DarkYellow'; continue }
    $probs = @()
    foreach ($g in $gates) {
        $cells++
        $gp = Join-Path $PSScriptRoot $g
        if (-not (Test-Path $gp)) { $probs += "$g=MISSING"; continue }
        $out = ''
        try   { $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $gp -Path $jp 2>&1 | Out-String) }
        catch { $probs += "$g=CRASH"; continue }
        if ($out -notmatch $verdictRx) { $probs += "$g=NO-VERDICT" }
        elseif ($out -match 'ParserError|is not recognized as|CommandNotFoundException|Cannot index into a null|You cannot call a method on a null') {
            $probs += "$g=RUNTIME-ERR"
        }
    }
    if ($probs.Count) {
        $bad += [pscustomobject]@{ P = $p; Probs = $probs }
        O ("  [UNPORTABLE] {0,-22} {1}" -f $p, ($probs -join '  ')) 'Red'
    } else {
        O ("  [OK]         {0,-22} all {1} gates reached a verdict" -f $p, $gates.Count) 'Green'
    }
}

O ''
O ("  RESULT: {0} cell(s) exercised / {1} provider(s) with an unportable gate" -f $cells, $bad.Count) `
    $(if ($bad.Count) { 'Red' } else { 'Green' })
if ($bad.Count) {
    O '  A gate that cannot reach a verdict on a provider is UNPORTABLE THERE. Fix the tool, not the' 'Yellow'
    O '  provider -- and re-run this sweep afterwards, because portability fixes routinely break a' 'Yellow'
    O '  DIFFERENT provider (the $formOnly namespace break did exactly that).' 'Yellow'
} else {
    O '  Every shared gate reaches a verdict on every provider.' 'Green'
}

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit $(if ($bad.Count) { 1 } else { 0 })
