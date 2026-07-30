<#
  audit_lifecycle.ps1 -- the END of the lifecycle: is this version's Jira entry filed, and is it
  recorded WHERE the JSON was imported?

  WHY THIS EXISTS (Rob 2026-07-30: "all gates need to operate from initial build/rebuild all the way
  to posting the jira entry and logging where jsons are imported"):
    Gate coverage stopped at "the JSON is correct and tested". Everything after that -- telling the
    customer-facing ticket, and recording which tenant received which version -- was carried by
    memory and habit. Two concrete exposures:
      1. A version can be built, tested, documented and pushed with NO Jira comment. Nothing
         noticed. The DEX ticket is what the rest of the org reads, so a silent version bump means
         the org's picture of the provider is a version (or four) behind.
      2. providers/IMPORT_LEDGER.md is the single source of truth for where each JSON is installed,
         and for Foundation tenants it is MANUALLY maintained (the capture tool cannot reach them).
         A manual ledger with no gate drifts by construction. "Where is version X installed" then
         gets answered from memory, which CLAUDE.md explicitly forbids.

  WHAT IT CHECKS, per provider
    STAGE 5 (Jira)   -- docs/tracking/DEX_TICKET.md names the CURRENT version.
    STAGE 6 (Import) -- providers/IMPORT_LEDGER.md accounts for the CURRENT version: either an
                        install record, or an explicit not-yet-imported line. Silence is the defect;
                        "built but not imported" is a perfectly good answer that must be WRITTEN.

  SEVERITY -- advisory by default (-Strict makes it blocking).
    Jira updates have been explicitly placed ON HOLD by Rob more than once, and Foundation-tenant
    imports are somebody else's action on somebody else's schedule. A gate that blocks the build
    because an external party has not acted yet would train everyone to bypass it. So this REPORTS
    relentlessly and blocks only when asked. What it removes is the ability to LOSE the fact.

  Usage: .\audit_lifecycle.ps1 [-Provider TX_TLETS] [-Strict] [-OutFile <path>]
#>

param(
    [string]$Provider,
    [switch]$Strict,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir "_resolve_provider_json.ps1")

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s,$c){ $lines.Add($s); if($c){Write-Host $s -ForegroundColor $c}else{Write-Host $s} }

Emit "" $null
Emit "================================================================" 'Cyan'
Emit "  LIFECYCLE TAIL AUDIT -- Jira entry + import record" 'Cyan'
Emit "================================================================" 'Cyan'

$ledgerPath = Join-Path $repoRoot 'providers\IMPORT_LEDGER.md'
$ledger = if (Test-Path $ledgerPath) { Get-Content $ledgerPath -Raw } else { $null }
if (-not $ledger) { Emit "  [FAIL] providers\IMPORT_LEDGER.md is missing -- there is no record of where anything is installed" 'Red' }

$targets = @()
if ($Provider) { $targets += Join-Path $repoRoot "providers\$Provider" }
else { $targets += (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | ForEach-Object { $_.FullName }) }

$fails = 0; $notes = 0; $passes = 0
foreach ($pd in ($targets | Sort-Object)) {
    $name = Split-Path $pd -Leaf
    $jp = Get-ProviderRootJson -ProvDir $pd -Provider $name
    if (-not $jp) { continue }
    # version from the filename: <PROVIDER>_v<X.Y>.json
    $ver = ''
    $m = [regex]::Match((Split-Path $jp -Leaf), '_v([0-9]+\.[0-9]+)\.json$')
    if ($m.Success) { $ver = $m.Groups[1].Value }
    if (-not $ver) { Emit "  [NOTE] $name -- version not in filename, cannot check lifecycle tail" 'Yellow'; $notes++; continue }

    # ── STAGE 5: Jira ──
    $dex = Get-ChildItem $pd -Recurse -Filter 'DEX_TICKET.md' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $dex) {
        Emit "  [NOTE] $name v$ver -- no DEX_TICKET.md; no ticket pointer exists for this provider" 'Yellow'; $notes++
    } elseif ((Get-Content $dex.FullName -Raw) -match [regex]::Escape("v$ver")) {
        Emit "  [PASS] $name v$ver -- Jira: DEX_TICKET.md names the current version" 'Green'; $passes++
    } else {
        Emit "  [GAP ] $name v$ver -- Jira: DEX_TICKET.md does NOT name v$ver. The ticket the org reads is behind the repo." 'Yellow'
        if ($Strict) { $fails++ } else { $notes++ }
    }

    # ── STAGE 6: import record ──
    if ($ledger) {
        $sect = ''
        # take the ledger lines mentioning this provider
        $hits = @($ledger -split "`n" | Where-Object { $_ -match [regex]::Escape($name) })
        if (-not $hits.Count) {
            Emit "  [GAP ] $name v$ver -- Import: provider absent from IMPORT_LEDGER.md entirely" 'Yellow'
            if ($Strict) { $fails++ } else { $notes++ }
        } elseif (($hits -join ' ') -match [regex]::Escape("v$ver")) {
            Emit "  [PASS] $name v$ver -- Import: ledger accounts for the current version" 'Green'; $passes++
        } else {
            Emit "  [GAP ] $name v$ver -- Import: ledger mentions the provider but NOT v$ver. Record the install, or record explicitly that v$ver is not imported yet -- silence is the defect." 'Yellow'
            if ($Strict) { $fails++ } else { $notes++ }
        }
    }
}

Emit "" $null
Emit "----------------------------------------------------------------" 'Cyan'
Emit "  RESULT: $passes PASS / $fails FAIL / $notes GAP-or-NOTE  (advisory unless -Strict)" $(if($fails){'Red'}elseif($notes){'Yellow'}else{'Green'})
Emit "  A GAP is not a build defect -- it is a fact about the lifecycle that would otherwise be lost." 'DarkGray'
Emit "----------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
exit $(if ($fails) { 1 } else { 0 })
