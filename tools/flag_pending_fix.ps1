<#
  flag_pending_fix.ps1 -- reverse-propagate a JSON/shared-module bug fix as a
  doc-stub flag across providers that still need it.

  The mechanism (no new machinery -- reuses what already gates testing):
    * Each target provider gets a structured line appended to its
      docs/tracking/PENDING_UPDATES.txt (resolved via _resolve_docs_path.ps1, so
      migrated providers get docs/tracking/ and legacy ones get flat docs/).
    * enforce.ps1 PHASE 1 already FAILs any provider whose PENDING_UPDATES.txt has
      a non-'#' line -- so the flag BLOCKS that provider's testing until a rebuild.
    * The build script REMOVES PENDING_UPDATES.txt on a successful build, so an
      applied fix self-clears. There is no separate un-flag step.
    * A row is appended to the repo-root REVERSE_PROPAGATION_LOG.md ledger (the
      pending-rebuild source of truth) if the FixId isn't logged yet.

  Idempotent: re-running with the same -FixId is a no-op per provider (it will not
  duplicate the flag line) and will not duplicate the ledger row.

  Classification: this is a deterministic SCRIPT tool (not an agent) -- flagging is
  mechanical text I/O with no judgement, so a script fits the tool ecosystem and the
  enforce gate with zero nondeterminism.

  Usage:
    .\flag_pending_fix.ps1 -FixId RND-99999 -Description "..." -Providers TX_TLETS,NY_NYSPIN_EJUSTICE
    .\flag_pending_fix.ps1 -FixId RND-99999 -Description "..." -Providers all -Origin NJ_NJCJIS
    .\flag_pending_fix.ps1 -FixId ... -Description ... -Providers all -DryRun
#>
param(
    [Parameter(Mandatory)][string]$FixId,
    [Parameter(Mandatory)][string]$Description,
    # Comma/array list of provider folder names, or the keyword 'all'.
    [Parameter(Mandatory)][string[]]$Providers,
    # Origin provider (where the fix was made) -- skipped from targets + recorded in the ledger.
    [switch]$Retire,          # retire an existing flag instead of writing one (comments it out, keeps the record)
  [string]$Origin,
    # Flag date stamp (defaults to today). Overridable for reproducible runs/tests.
    [string]$Date,
    [switch]$DryRun,
    [string]$OutFile
)
$ErrorActionPreference = "Stop"
$tool = $PSScriptRoot
$repo = (Resolve-Path "$tool\..").Path
$providersDir = Join-Path $repo "providers"
. "$tool\_resolve_docs_path.ps1"

if (-not $Date) { $Date = (Get-Date -Format 'yyyy-MM-dd') }

# ── Output helpers (house style) ──
$script:outputLines = @()
function Out($msg)            { $script:outputLines += $msg; Write-Host $msg }
function OutColor($msg,$col)  { $script:outputLines += $msg; Write-Host $msg -ForegroundColor $col }
function Fail($msg) { OutColor "    [FAIL] $msg" Red }
function Pass($msg) { OutColor "    [PASS] $msg" Green }
function Info($msg) { OutColor "    [INFO] $msg" Gray }
function Skip($msg) { OutColor "    [SKIP] $msg" DarkYellow }

$skipProviders = @()   # (CA_CONTRA_COSTA was skipped while incomplete; removed 2026-07-24 -- completed build, a valid reverse-propagation target)

# ── Resolve target providers ──
$allProvNames = @(Get-ChildItem $providersDir -Directory | Select-Object -ExpandProperty Name)
if ($Providers.Count -eq 1 -and $Providers[0] -eq 'all') {
    $targets = $allProvNames
} else {
    $targets = $Providers
}
$targets = @($targets | Where-Object { $_ -and ($_ -ne $Origin) -and ($skipProviders -notcontains $_) } | Select-Object -Unique)

$unknown = @($targets | Where-Object { $allProvNames -notcontains $_ })
if ($unknown) { throw "flag_pending_fix: unknown provider(s): $($unknown -join ', ')" }

$flagLine = "[FLAG:$FixId] $Description (flagged $Date)"
# THE HEADER USED TO CLAIM "Clear by running the build script (it removes this file on successful
# build)". THAT WAS FALSE and cost real time on 2026-08-13: IL_LEADS_OFML v2.4 and HI_HCJDC_OFML
# v4.17 both completed a full pipeline run and BOTH left their flag live, because nothing anywhere
# retires a flag -- this tool wrote them and no code path ever removed one. Sixteen providers still
# carry one. The header now tells the truth and names the retirement command.
$header = @(
    "# PENDING_UPDATES.txt -- <PROVIDER>",
    "# Lines without a leading '#' block enforce.ps1 and prevent testing.",
    "# A flag is NOT cleared by building. Retire it explicitly once the fix is in the JSON:",
    "#   tools\flag_pending_fix.ps1 -Retire -FixId <id> -Providers <P> -Description '<what was done>'",
    "#"
)

# ── NEWLINE-SAFE APPEND ────────────────────────────────────────────────────────────────────────
# Add-Content appends a trailing newline AFTER its value but does NOT guarantee the file already
# ENDED with one. Append to a file whose last line has no terminator and the flag is GLUED onto
# that line -- and since these files end in '#' comment prose, the flag becomes part of a COMMENT.
# enforce.ps1 L207 skips lines starting with '#', so the provider reports no unresolved items and
# PASSES PHASE 1 while believing itself flagged. That is exactly what happened to CA_CLETS with
# [FLAG:ncic-image-default-y-everywhere]: silently exempt, invisible, found only by a hand sweep.
# A flag that cannot block is worse than no flag -- it is a false record of pending work.
function Add-LineSafely {
    param([string]$Path, [string]$Line)
    $raw = if (Test-Path $Path) { [IO.File]::ReadAllText($Path) } else { '' }
    if ($raw.Length -gt 0 -and $raw[-1] -ne "`n") { $raw += "`r`n" }
    $raw += $Line + "`r`n"
    [IO.File]::WriteAllText($Path, $raw, (New-Object System.Text.UTF8Encoding($false)))
}

Out ""
Out "================================================================"
Out "  FLAG PENDING FIX: [$FixId]"
Out "  $Description"
Out "  Origin: $(if ($Origin) { $Origin } else { '(unspecified)' })   Targets: $($targets.Count)$(if ($DryRun) { '   [DRY RUN]' })"
Out "================================================================"

# ── RETIRE MODE ────────────────────────────────────────────────────────────────────────────────
# The missing half of the lifecycle. Flags were WRITTEN by this tool and retired by nobody, so
# every provider that took a fix had to be edited by hand -- twice on 2026-08-13 alone, and 16
# providers still owe it. Retiring COMMENTS THE LINE OUT rather than deleting it: the record of
# what was owed and why it closed is the point, and a bare deletion loses it (same reasoning as
# the accepted-divergence registry). Requires -Description so the reason is recorded, not implied.
if ($Retire) {
    # $changed counts providers where a LIVE flag was actually commented out THIS RUN. $retired
    # counts providers now in a retired state, which includes ones that already were -- so only
    # $changed may drive a ledger write. Separating them 2026-08-14: an already-inert flag was
    # incrementing $retired, so a second -Retire run reported "RETIRED: 1" having changed nothing
    # and appended a DUPLICATE ledger row, contradicting this tool's own idempotency claim.
    $retired = 0; $notFound = 0; $inertFixed = 0; $changed = 0
    foreach ($prov in ($targets | Sort-Object)) {
        $provDir = Join-Path $providersDir $prov
        $pendingPath = Find-DocsPath $provDir 'tracking' 'PENDING_UPDATES.txt'
        if (-not (Test-Path $pendingPath)) { Skip "$prov -- no PENDING_UPDATES.txt"; $notFound++; continue }

        $lines = @(Get-Content $pendingPath)
        $pat   = "\[FLAG:$([regex]::Escape($FixId))\]"
        # A flag can be LIVE (own line) or INERT (glued into a '#' comment by the pre-fix appender).
        # Retire handles BOTH -- an inert one still has to be recorded as closed, or the next sweep
        # re-discovers it and cannot tell whether the work was done.
        $hitLive  = @($lines | Where-Object { $_ -match $pat -and -not $_.TrimStart().StartsWith('#') })
        $hitInert = @($lines | Where-Object { $_ -match $pat -and $_.TrimStart().StartsWith('#') })
        if (-not $hitLive -and -not $hitInert) { Skip "$prov -- does not carry [FLAG:$FixId]"; $notFound++; continue }
        if (-not $hitLive -and $hitInert) { Info "$prov -- flag was INERT (already commented); recording retirement anyway"; $inertFixed++ }

        if ($DryRun) { Info "$prov -- would retire [FLAG:$FixId] ($($hitLive.Count) live, $($hitInert.Count) inert)"; $retired++; continue }

        $out = foreach ($ln in $lines) {
            if ($ln -match $pat -and -not $ln.TrimStart().StartsWith('#')) { "# RETIRED $Date -- $Description" ; "# $ln" }
            else { $ln }
        }
        [IO.File]::WriteAllText($pendingPath, (($out -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))

        # PROVE IT: re-read and confirm enforce can no longer see the flag. A retirement that did
        # not actually silence the gate is the same false record in the other direction.
        $stillLive = @(Get-Content $pendingPath | Where-Object { $_ -match $pat -and -not $_.TrimStart().StartsWith('#') })
        if ($stillLive) { Fail "$prov -- retirement FAILED, flag still live"; }
        else {
            if ($hitLive.Count -gt 0) {
                Pass "$prov -- [FLAG:$FixId] retired (comment retained for the record)"
                $changed++
            } else {
                Info "$prov -- [FLAG:$FixId] was ALREADY retired; no change made"
            }
            $retired++
        }
    }
    # ── LEDGER: record the CLOSURE, not just the raise ──────────────────────────────────────────
    # Added 2026-08-14 after retiring 9 providers off [FLAG:ncic-image-default-y-everywhere] and
    # noticing REVERSE_PROPAGATION_LOG.md did not change at all. The raise path appends a row; this
    # path wrote nothing, so the ledger recorded that a fix was OWED and never that it was CLOSED --
    # and once the last provider drops off, audit_reverse_propagation reports
    # "PROPAGATED -- no provider still carries the flag", which would read as "all 20 took the
    # change" when 9 of them were retired as NOT-APPLICABLE or ALREADY-CONFORMANT instead. Those are
    # different facts and the difference is the whole reason this ledger exists.
    if (-not $DryRun -and $changed -gt 0) {
        $ledgerPath = Join-Path $repo "REVERSE_PROPAGATION_LOG.md"
        if (Test-Path $ledgerPath) {
            $provList = ($targets | Sort-Object) -join ', '
            $row = "| [FLAG:$FixId] | RETIRED on $changed provider(s) -- $Description | (retirement) | $provList | RETIRED $Date -- not a rebuild; recorded as closed |"
            $raw = [IO.File]::ReadAllText($ledgerPath)
            # Idempotent: an identical retirement row already present means this ran before.
            # MUST be a literal .Contains(), NOT -like: the row opens with "[FLAG:<id>]" and '[' ']'
            # are wildcard CHARACTER-CLASS metacharacters, so -like threw "the specified wildcard
            # character pattern is not valid" and the append was skipped entirely -- the guard
            # silently suppressed the very write it was meant to protect. Caught by a LAW 2 probe
            # that checked the ledger actually GREW (it grew by 0 bytes), not just that no error
            # surfaced. Same family as escaping a FixId for -match, which this file already does.
            if ($raw.Contains($row)) {
                Info "ledger already carries this retirement row -- not duplicated"
            } else {
                if ($raw.Length -gt 0 -and $raw[-1] -ne "`n") { $raw += "`r`n" }
                [IO.File]::WriteAllText($ledgerPath, $raw + $row + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
                Pass "ledger row appended -- retirement recorded as a CLOSURE, distinct from a rebuild"
            }
        } else {
            Fail "REVERSE_PROPAGATION_LOG.md absent -- retirement NOT recorded in the ledger"
        }
    }

    Out ""
    Out "  RETIRED: $retired    not carrying it: $notFound    were already inert: $inertFixed"
    Out "================================================================"
    if ($OutFile) { $script:outputLines -join "`r`n" | Set-Content -Path $OutFile -Encoding UTF8 }
    exit 0
}

$flagged = 0; $already = 0
foreach ($prov in ($targets | Sort-Object)) {
    $provDir = Join-Path $providersDir $prov
    $pendingPath = Find-DocsPath $provDir 'tracking' 'PENDING_UPDATES.txt'

    $existing = @()
    if (Test-Path $pendingPath) { $existing = @(Get-Content $pendingPath) }

    if ($existing | Where-Object { $_ -match "\[FLAG:$([regex]::Escape($FixId))\]" }) {
        Skip "$prov -- already carries [FLAG:$FixId]"
        $already++
        continue
    }

    if ($DryRun) {
        Info "$prov -- would append: $flagLine"
        $flagged++
        continue
    }

    if (-not $existing) {
        # Create with the standard header (resolve write path via category dir).
        $writePath = Get-DocsPath $provDir 'tracking' 'PENDING_UPDATES.txt'
        $content = ($header -replace '<PROVIDER>', $prov) + $flagLine
        Set-Content -Path $writePath -Value $content -Encoding UTF8
        $pendingPath = $writePath
    } else {
        Add-LineSafely -Path $pendingPath -Line $flagLine
    }
    Pass "$prov -- flagged ($((Split-Path $pendingPath -Parent) -replace [regex]::Escape($repo),'.'))"
    $flagged++
}

# ── Ledger: append a row if this FixId isn't logged ──
$ledgerPath = Join-Path $repo "REVERSE_PROPAGATION_LOG.md"
$ledgerNote = ""
if (-not $DryRun) {
    if (-not (Test-Path $ledgerPath)) {
        $scaffold = @(
            "# Reverse-Propagation Log",
            "",
            "Pending-rebuild ledger for shared-module / JSON bug fixes that must propagate to",
            "providers on their next rebuild. Hand-curate the Status column as providers rebuild;",
            "``tools/flag_pending_fix.ps1`` appends a row here when it flags, and",
            "``tools/audit_reverse_propagation.ps1`` reads this + every PENDING_UPDATES.txt.",
            "",
            "| Fix ID | Description | Origin | Affected | Status |",
            "|---|---|---|---|---|"
        )
        Set-Content -Path $ledgerPath -Value $scaffold -Encoding UTF8
    }
    $ledger = @(Get-Content $ledgerPath)
    if ($ledger | Where-Object { $_ -match "^\|\s*(\[FLAG:)?$([regex]::Escape($FixId))" }) {
        $ledgerNote = "ledger row for $FixId already present (left as-is)"
    } else {
        $originCell = if ($Origin) { $Origin } else { '—' }
        $affectedCell = ($targets | Sort-Object) -join ', '
        $row = "| $FixId | $Description | $originCell | $affectedCell | pending: $affectedCell (flagged $Date) |"
        Add-Content -Path $ledgerPath -Value $row -Encoding UTF8
        $ledgerNote = "appended ledger row for $FixId"
    }
}

Out ""
Out "  Flagged: $flagged   Already-present: $already   $(if ($ledgerNote) { "Ledger: $ledgerNote" })"
Out "  Reminder: each flagged provider now FAILs enforce.ps1 PHASE 1 until it is rebuilt."
Out "================================================================"

if ($OutFile) {
    $script:outputLines -join "`r`n" | Set-Content -Path $OutFile -Encoding UTF8
    Write-Host "`n  Saved: $OutFile" -ForegroundColor Green
}
