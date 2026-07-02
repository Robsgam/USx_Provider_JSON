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

$skipProviders = @('CA_CONTRA_COSTA')   # incomplete -- never a propagation target

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
$header = @(
    "# PENDING_UPDATES.txt -- <PROVIDER>",
    "# Lines without a leading '#' block enforce.ps1 and prevent testing.",
    "# Clear by running the build script (it removes this file on successful build).",
    "#"
)

Out ""
Out "================================================================"
Out "  FLAG PENDING FIX: [$FixId]"
Out "  $Description"
Out "  Origin: $(if ($Origin) { $Origin } else { '(unspecified)' })   Targets: $($targets.Count)$(if ($DryRun) { '   [DRY RUN]' })"
Out "================================================================"

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
        Add-Content -Path $pendingPath -Value $flagLine -Encoding UTF8
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
