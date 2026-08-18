# audit_change_scope.ps1 -- IS THIS CHANGE INSIDE THE PROVIDER I WAS TOLD TO WORK ON?
#
# WHY THIS EXISTS (2026-08-18, Rob: "we need to put guardrails around your drift but respect the
# portfolio implications"). One-provider-at-a-time is a standing rule and it kept being broken by
# ACCRETION, never by decision: a shared-tool change moved MD_METERS 69->70 and OH_LEADS 77->78, and
# their reports/docs were regenerated "while I was there" -- a mass rebuild by the back door, on
# providers nobody had asked about (Rob: "why are you straying... stick to az only"). Same session,
# same shape, twice more: reaching for LA_LEMS + MD_METERS STATUS.txt mid-TX, and a portfolio-wide
# Name-separator "normalisation" that would have broken a CORRECT build.
#
# THE RULE THIS ENFORCES IS *WRITE* SCOPE, NOT READ SCOPE -- see ENGINEERING_STANDARD 4.5.
# Measuring across providers is ALWAYS allowed and is often mandatory (a shared-tool change cannot be
# validated any other way). What needs a guardrail is WRITING outside the provider in scope.
#
# VARIANT LOCKSTEP IS AUTO-ALLOWED, because it is REQUIRED: a provider declaring
# `# BASE-SYNC: <scope> vX.Y` must be rebuilt in the same pass as its base (CLAUDE.md "Provider
# Variants"). Flagging TX_TLETS_CCH while working TX_TLETS would train everyone to pass -Allow
# reflexively, which is how a guardrail becomes noise.
#
# SHARED PATHS ARE NOT VIOLATIONS but they ARE reported: tools/, knowledge-base/, and repo-root docs
# are portfolio-wide by nature. They get their own line so a change that quietly became a shared-tool
# change is visible as one -- that is the change class that moves other providers' scores.
#
# NOT VACUOUS: an empty working tree reports [NOTE] nothing staged, NOT "scope clean". A check that
# cannot tell "no violation" from "nothing to check" is the defect class this repo keeps finding
# (the PreToolUse hook that never ran, audit_log_inflation's attack A that could never fail,
# report_sweep_ledger's own COMPLETE-on-a-surplus). Exit 1 only on a real out-of-scope write.
#
# Usage:  audit_change_scope.ps1 -Provider TX_TLETS
#         audit_change_scope.ps1 -Provider TX_TLETS -Allow OH_LEADS   (declared, deliberate co-change)
#         audit_change_scope.ps1 -Provider TX_TLETS -Ref HEAD~3       (audit a range, not the worktree)

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Provider,
    [string[]]$Allow = @(),
    [string]$Ref,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Push-Location $repo
try {
    # ---- collect changed paths -------------------------------------------------------------
    # git writes benign notices to STDERR ("warning: in the working copy of 'X', LF will be replaced
    # by CRLF"), and under $ErrorActionPreference='Stop' PowerShell promotes native stderr to a
    # terminating NativeCommandError -- so the -Ref path died on a line-ending warning, not on a real
    # failure. Drop to Continue around the git calls only.
    $eapSaved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($Ref) {
        $raw = @(& git diff --name-only "$Ref" 2>$null)
        $src = "git diff --name-only $Ref"
    } else {
        # Worktree + index. --porcelain gives 'XY path'; strip the status columns, and handle renames
        # ('R  old -> new') by taking the destination.
        $raw = @(& git status --porcelain 2>$null | ForEach-Object {
            $p = $_.Substring(3).Trim().Trim('"')
            if ($p -match '\s->\s(.+)$') { $Matches[1].Trim().Trim('"') } else { $p }
        })
        $src = 'git status --porcelain (worktree + index)'
    }
    $ErrorActionPreference = $eapSaved
    $raw = @($raw | Where-Object { $_ })

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "  CHANGE SCOPE -- in-scope provider: $Provider" -ForegroundColor Cyan
        Write-Host "  source: $src" -ForegroundColor DarkGray
        Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
    }

    if (-not $raw.Count) {
        if (-not $Quiet) {
            Write-Host "  [NOTE] nothing staged or modified -- there is no scope to check." -ForegroundColor DarkYellow
            Write-Host "         This is NOT 'scope clean'. Nothing was compared." -ForegroundColor DarkYellow
        }
        exit 0
    }

    # ---- resolve which providers are legitimately in scope ---------------------------------
    # Any provider declaring `# BASE-SYNC: <Provider>` is a mandatory lockstep co-change.
    $variants = @()
    foreach ($d in @(Get-ChildItem (Join-Path $repo 'providers') -Directory -ErrorAction SilentlyContinue)) {
        $bs = @(Get-ChildItem (Join-Path $d.FullName 'scripts') -Filter 'build_*.ps1' -File -ErrorAction SilentlyContinue |
                ForEach-Object { Select-String -Path $_.FullName -Pattern '^#\s*BASE-SYNC:\s*(\S+)' -ErrorAction SilentlyContinue })
        foreach ($m in $bs) { if ($m.Matches[0].Groups[1].Value -eq $Provider) { $variants += $d.Name } }
    }
    $inScope = @($Provider) + @($variants) + @($Allow) | Sort-Object -Unique

    # ---- bucket ---------------------------------------------------------------------------
    $byProv = @{}
    $shared = @()
    foreach ($p in $raw) {
        $norm = $p -replace '\\', '/'
        if ($norm -match '^providers/([^/]+)/') {
            $pv = $Matches[1]
            if (-not $byProv.ContainsKey($pv)) { $byProv[$pv] = 0 }
            $byProv[$pv]++
        } else { $shared += $norm }
    }

    $violations = @()
    foreach ($pv in ($byProv.Keys | Sort-Object)) {
        $n = $byProv[$pv]
        if ($inScope -contains $pv) {
            $why = if ($pv -eq $Provider) { 'in scope' }
                   elseif ($variants -contains $pv) { 'BASE-SYNC variant of ' + $Provider + ' -- lockstep is MANDATORY' }
                   else { 'declared via -Allow' }
            if (-not $Quiet) { Write-Host ("  [ OK ] providers/{0,-22} {1,3} file(s)  ({2})" -f $pv, $n, $why) -ForegroundColor Green }
        } else {
            $violations += "providers/$pv ($n file(s))"
            if (-not $Quiet) { Write-Host ("  [FAIL] providers/{0,-22} {1,3} file(s)  OUT OF SCOPE" -f $pv, $n) -ForegroundColor Red }
        }
    }

    if ($shared.Count) {
        $tools = @($shared | Where-Object { $_ -like 'tools/*' })
        $kb    = @($shared | Where-Object { $_ -like 'knowledge-base/*' })
        $root  = @($shared | Where-Object { $_ -notlike 'tools/*' -and $_ -notlike 'knowledge-base/*' })
        if (-not $Quiet) {
            if ($tools.Count) { Write-Host ("  [NOTE] tools/{0,-26} {1,3} file(s)  SHARED -- this is a PORTFOLIO-WIDE change; measure the other providers before committing (ENGINEERING_STANDARD 4.5)" -f '', $tools.Count) -ForegroundColor Yellow }
            if ($kb.Count)    { Write-Host ("  [NOTE] knowledge-base/{0,-17} {1,3} file(s)  SHARED -- a rule every provider reads" -f '', $kb.Count) -ForegroundColor Yellow }
            if ($root.Count)  { Write-Host ("  [NOTE] repo root{0,-23} {1,3} file(s)  SHARED" -f '', $root.Count) -ForegroundColor DarkGray }
        }
    }

    if (-not $Quiet) {
        Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("  COMPARED: {0} changed path(s) across {1} provider dir(s) + {2} shared path(s)" -f $raw.Count, $byProv.Keys.Count, $shared.Count) -ForegroundColor DarkGray
    }

    if ($violations.Count) {
        if (-not $Quiet) {
            Write-Host ""
            Write-Host "  *** OUT-OF-SCOPE WRITES: $($violations -join ' , ')" -ForegroundColor Red
            Write-Host "  A shared-tool change that moves another provider's score gets a FLAG, never a fix:" -ForegroundColor Red
            Write-Host "      tools\flag_pending_fix.ps1 -FixId <id> -Description <..> -Providers <that provider>" -ForegroundColor Red
            Write-Host "  If the co-change really is intended, say so explicitly with -Allow <PROVIDER>." -ForegroundColor Red
        }
        exit 1
    }

    if (-not $Quiet) { Write-Host "  [PASS] every write is inside $Provider (plus shared paths, reported above)." -ForegroundColor Green }
    exit 0
}
finally { Pop-Location }
