<#
  audit_branch_currency.ps1 -- is the shipping branch drifting, and is main going stale?

  WHY THIS EXISTS (Rob 2026-07-30: "you need to keep these things in line -- figure out how to
  wire it in so nothing gets stale and nothing gets left behind"):
    Work happens on a long-lived branch while `main` sits untouched. Nothing watched the gap, so
    it grew to 216 commits / 8 days without anyone deciding to let it. Two concrete harms:
      1. STALE main -- a fresh clone, a colleague, or a recovery pulls a portfolio that is missing
         real fixes. On 2026-07-30 main's TX could not run out-of-state plate or VIN queries at all
         (the v4.13 dead-combo deletion), because the v4.14/v4.15/v4.16 fixes live only on the branch.
      2. MISLEADING branch name -- `rebuild/az_azdps_v3.0` was cut for one AZ rebuild and now carries
         the entire portfolio's history. Anyone reading the repo cold is told the wrong thing about
         what the branch is, including a future session picking up from SESSION_STATE.
    Rob imports JSON from the provider ROOT FOLDER (working tree), so branch state does not affect
    what he installs -- that is why this is a WARN, not a FAIL. It exists so the drift is a decision
    rather than an accident.

  Thresholds (WARN, never blocks -- merging is a human call about what ships to a customer):
    - main older than $MaxMainAgeDays
    - branch more than $MaxAhead commits ahead of main
    - branch name references a single provider while carrying commits that touch others

  Usage: .\audit_branch_currency.ps1 [-MaxAhead 50] [-MaxMainAgeDays 7] [-OutFile <path>]
#>

param(
    [int]$MaxAhead = 50,
    [int]$MaxMainAgeDays = 7,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
Push-Location $repoRoot

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s, $c) { $lines.Add($s); if ($c) { Write-Host $s -ForegroundColor $c } else { Write-Host $s } }

Emit "" $null
Emit "================================================================" 'Cyan'
Emit "  BRANCH CURRENCY AUDIT" 'Cyan'
Emit "================================================================" 'Cyan'

$warn = 0
$branch = (git branch --show-current 2>$null)
if (-not $branch) { Emit "  [INFO] not on a branch (detached HEAD?) -- check skipped" 'Yellow'; Pop-Location; exit 0 }

$mainRef = if ((git rev-parse --verify main 2>$null)) { 'main' } elseif ((git rev-parse --verify master 2>$null)) { 'master' } else { $null }
if (-not $mainRef) { Emit "  [INFO] no main/master branch found -- check skipped" 'Yellow'; Pop-Location; exit 0 }

Emit "  branch: $branch" $null

if ($branch -eq $mainRef) {
    Emit "  [PASS] working directly on $mainRef -- no divergence possible" 'Green'
} else {
    $ahead  = [int](git rev-list --count "$mainRef..HEAD" 2>$null)
    $behind = [int](git rev-list --count "HEAD..$mainRef" 2>$null)
    $mainDateRaw = (git log -1 --format='%aI' $mainRef 2>$null)
    $mainAge = if ($mainDateRaw) { [int]((Get-Date) - [datetime]::Parse($mainDateRaw)).TotalDays } else { -1 }

    Emit "  ahead of ${mainRef}: $ahead   behind: $behind   ${mainRef} last commit: $(if($mainAge -ge 0){"$mainAge day(s) ago"}else{'unknown'})" $null

    if ($ahead -gt $MaxAhead) {
        Emit "  [WARN] $ahead commits ahead of $mainRef (threshold $MaxAhead) -- decide whether to merge or accept the gap; do not let it grow by default" 'Yellow'
        $warn++
    } elseif ($ahead -gt 0) {
        Emit "  [PASS] $ahead commit(s) ahead of $mainRef -- within threshold ($MaxAhead)" 'Green'
    }

    if ($mainAge -gt $MaxMainAgeDays) {
        Emit "  [WARN] $mainRef is $mainAge day(s) old (threshold $MaxMainAgeDays) -- a fresh clone or recovery gets a portfolio missing every fix on this branch" 'Yellow'
        $warn++
    } elseif ($mainAge -ge 0) {
        Emit "  [PASS] $mainRef is $mainAge day(s) old -- within threshold ($MaxMainAgeDays)" 'Green'
    }

    # Branch name naming a single provider while carrying cross-provider work.
    $named = @()
    foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory -ErrorAction SilentlyContinue)) {
        if ($branch -match [regex]::Escape($d.Name)) { $named += $d.Name }
    }
    if ($named.Count -eq 1) {
        $touched = @(git diff --name-only "$mainRef..HEAD" -- providers 2>$null |
                    ForEach-Object { ($_ -split '/')[1] } | Where-Object { $_ } | Select-Object -Unique)
        $others = @($touched | Where-Object { $_ -ne $named[0] })
        if ($others.Count -gt 0) {
            Emit "  [WARN] branch is named for $($named[0]) but carries commits touching $($others.Count) other provider(s) ($(($others | Select-Object -First 6) -join ', ')$(if($others.Count -gt 6){', ...'})) -- the name misleads anyone reading the repo cold" 'Yellow'
            $warn++
        }
    }
}

Emit "" $null
Emit "----------------------------------------------------------------" 'Cyan'
Emit "  RESULT: $warn warning(s). Advisory only -- what ships to a customer is a human call." 'Cyan'
Emit "----------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
Pop-Location
exit 0
