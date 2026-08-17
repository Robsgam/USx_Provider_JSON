<#
================================================================================
 report_import_owed.ps1 -- WHICH BUILDS ARE WAITING TO BE IMPORTED
================================================================================

 WHY THIS EXISTS. Rob, 2026-08-17: "you need to alert when a new version is built
 to prompt for import   iver lost track of all the things you are fixing."

 That day TEN provider versions were bumped in one session (CA_CLETS v2.25,
 CA_CLETS_OCATS v2.4, CA_CONTRA_COSTA v2.3, CA_eSUN v2.3, CA_SAN_LUIS_OBISPO v2.4,
 CA_VENTURA_COUNTY v2.4, FL_FCIC v7.24, HI_HCJDC_OFML v4.19, IL_LEADS_OFML v2.8,
 OR_LEDS v2.3) and NOT ONCE did anything say "these now need importing". Every
 individual step was gated and green; the LIST of what the day had left waiting was
 nowhere, in any tool. A repo can be entirely correct and still be useless to the
 person who has to go install it.

 THE GAP IS STRUCTURAL, not forgetfulness. Every existing gate is scoped to ONE
 provider and answers "is this build correct?". `audit_lifecycle` stage 6 comes
 closest -- it asks whether the ledger ACCOUNTS for the current version -- but it is
 advisory, per-provider, and satisfied by an explicit "not imported yet" line, so it
 is silent exactly when a queue is building up. Nothing looked ACROSS providers and
 asked "what is built but not installed anywhere?".

 THE THREE TENANT CLASSES ARE NOT INTERCHANGEABLE (IMPORT_LEDGER.md defines them),
 and the whole value of this report is keeping them apart:
   * USx Provider Tenant -- SELF-VERIFYING. The capture tool is locked to these, so
     the newest non-archived log version IS what is installed. Derived, never asked.
   * Foundation Tenant   -- customer staging. The capture tool CANNOT reach it, so
     its version is only ever known because someone reported an import.
   * LIVE / Production    -- real officers. Same manual tracking, but a bump here is
     a COORDINATED re-import, never a repo action. A LIVE row may also be
     DELIBERATELY HELD BEHIND (HDLE is), so "behind" is not automatically drift --
     this report prints the ledger's own note rather than guessing.

 WHAT IT WILL NOT DO: claim a tenant has a version. Foundation and LIVE numbers come
 from the ledger, which is hand-maintained from import reports. If the ledger is
 wrong this report repeats the error -- it is a prompt to ask, not a source of truth.
 Silence about a tenant means "the ledger says nothing", which is itself the finding.

 EXIT CODE IS ALWAYS 0. This is a REPORT, not a gate. Owing an import is a normal
 state, not a defect, and making it blocking would train everyone to skip it.
================================================================================
#>
[CmdletBinding()]
param(
    [string]$Provider,
    [switch]$Quiet,
    [string]$OutFile,
    # Only list providers whose version changed at/after this git revision or date
    # (e.g. -Since 'HEAD~10' or -Since '2026-08-17'). Omit for the full standing queue.
    [string]$Since
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_resolve_provider_json.ps1"

$lines = New-Object System.Collections.ArrayList
function Emit([string]$s) { [void]$lines.Add($s); if (-not $Quiet) { Write-Host $s } }

# ---------------------------------------------------------------- ledger parse
# Section B rows look like:  | <Tenant> | <PROVIDER> | v<X.Y> | <date> | <note> |
# LIVE rows carry **LIVE** in the tenant cell. Versions may be bolded (**v2.25**).
$ledgerPath = Join-Path $root 'providers\IMPORT_LEDGER.md'
$tenantRows = @{}
if (Test-Path $ledgerPath) {
    foreach ($ln in (Get-Content $ledgerPath)) {
        if ($ln -notmatch '^\s*\|') { continue }
        $cells = @($ln -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 5) { continue }
        $tenant = ($cells[1] -replace '\*','').Trim()
        $prov   = ($cells[2] -replace '\*','').Trim()
        $ver    = $cells[3]
        if ($prov -notmatch '^[A-Z][A-Z0-9_]+$') { continue }
        # A row must name BOTH a tenant and a version. Without this the header/separator rows and
        # the section-C catalog table (whose columns are in a different order) produced phantom
        # entries reading "Foundation '': v vs repo v2.4" -- an alert with no tenant and no version
        # in it, which is noise that trains the reader to skim.
        if (-not $tenant) { continue }
        $m = [regex]::Match($ver, 'v?([0-9]+\.[0-9]+)')
        if (-not $m.Success) { continue }
        if (-not $tenantRows.ContainsKey($prov)) { $tenantRows[$prov] = @() }
        $tenantRows[$prov] += [pscustomobject]@{
            Tenant = ($tenant -replace '\*','').Trim()
            Ver    = $m.Groups[1].Value
            IsLive = ($tenant -match '(?i)LIVE')
            Note   = if ($cells.Count -ge 6) { $cells[5] } else { '' }
        }
    }
}

# ---------------------------------------------------------------- recent bumps
$recent = @{}
if ($Since) {
    # TWO GIT-INVOCATION TRAPS, both of which made this report announce "no provider version
    # changed" while ten of them had -- a false NEGATIVE, the worst outcome for a prompt like this:
    #  1. --format='' passes an EMPTY argument, which git rejects; with stderr suppressed that
    #     yields zero lines. Use %H and let the hash lines fall through the regex harmlessly.
    #  2. A BARE --since=YYYY-MM-DD yields ZERO lines here, while --since='YYYY-MM-DD 00:00'
    #     yields 310. Measured, not guessed. So always append a time to a date-only value.
    $arg = if ($Since -match '^\d{4}-\d{2}-\d{2}$') { "--since=$Since 00:00" }
           elseif ($Since -match '^\d{4}-\d{2}-\d{2}')  { "--since=$Since" }
           else { "$Since..HEAD" }
    $raw = & git -C $root log $arg --diff-filter=R --name-status --format=%H 2>$null
    foreach ($r in @($raw)) {
        $m = [regex]::Match("$r", 'providers/([A-Z][A-Z0-9_]+)/\1_v[0-9.]+\.json\s+providers/\1/\1_v([0-9.]+)\.json')
        if ($m.Success) { $recent[$m.Groups[1].Value] = $m.Groups[2].Value }
    }
}

Emit '============================================================================'
Emit '  IMPORT QUEUE -- built versions waiting to be installed'
Emit '  USx Provider Tenant = log-derived (self-verifying). Foundation / LIVE = the'
Emit '  ledger, which is only ever as current as the last reported import.'
Emit '============================================================================'
if ($Since) {
    Emit "  [WARN] -Since $Since IS A CONVENIENCE FILTER AND CAN UNDER-REPORT."
    Emit '         It finds version changes via git RENAME detection (old JSON -> new JSON). When a'
    Emit '         version swap is recorded as a separate add+delete instead, that provider is'
    Emit '         invisible here -- measured on 2026-08-17, when it found 8 of 10 real bumps and'
    Emit '         silently omitted CA_CONTRA_COSTA and CA_eSUN. RUN WITHOUT -Since for the'
    Emit '         authoritative queue; that view compares versions directly and cannot miss one.'
}

$provDirs = if ($Provider) { @(Get-Item (Join-Path $root "providers\$Provider")) }
            else { Get-ChildItem (Join-Path $root 'providers') -Directory | Sort-Object Name }

$owedUsx = @(); $owedFdn = @(); $owedLive = @(); $held = @(); $compared = 0

foreach ($d in $provDirs) {
    $jp = Get-ProviderRootJson -ProvDir $d.FullName -Provider $d.Name
    if (-not $jp) { continue }
    if ($Since -and -not $recent.ContainsKey($d.Name)) { continue }
    $compared++
    $repo = [regex]::Match((Split-Path $jp -Leaf), '_v([0-9.]+)\.json$').Groups[1].Value

    # log-derived provider-tenant version
    $logs = @(Get-ChildItem "$($d.FullName)\logs" -Recurse -Filter '*.txt' -File -ErrorAction SilentlyContinue |
              Where-Object { $_.FullName -notmatch '_archive' })
    $tenantVer = $null
    if ($logs.Count) {
        $vs = @($logs | ForEach-Object { [regex]::Match($_.Name, '_v([0-9.]+)_').Groups[1].Value } |
                Where-Object { $_ } | Sort-Object -Unique)
        $tenantVer = ($vs -join ',')
    }

    $flags = New-Object System.Collections.ArrayList
    if ($tenantVer -ne $repo) {
        if (-not $tenantVer) { [void]$flags.Add("USx provider tenant: NO logs at any version -- import v$repo then sweep") }
        else                 { [void]$flags.Add("USx provider tenant: logs at v$tenantVer, repo is v$repo -- import + re-sweep") }
        $owedUsx += $d.Name
    }
    # @($null).Count IS 1 IN POWERSHELL. Wrapping a missing hashtable key in @() yields a
    # one-element array holding $null, so every provider with NO ledger row emitted a phantom
    # "Foundation '': v vs repo vX.Y" line -- 12 of them, which is most of this report's output.
    # It looked like a ledger-parsing bug and was not: probing the ledger for empty-tenant rows
    # returned nothing. Guard on ContainsKey; never rely on @() to normalise a missing key.
    $ledgerRows = if ($tenantRows.ContainsKey($d.Name)) { @($tenantRows[$d.Name]) } else { @() }
    foreach ($r in $ledgerRows) {
        if ($r.Ver -eq $repo) { continue }
        $isHeld = $r.Note -match '(?i)\bheld\b|deliberately BEHIND'
        $tag = if ($r.IsLive) { 'LIVE' } else { 'Foundation' }
        if ($isHeld) {
            [void]$flags.Add("$tag '$($r.Tenant)': v$($r.Ver) vs repo v$repo -- DELIBERATELY HELD, do not import without saying so")
            $held += "$($d.Name)/$($r.Tenant)"
        } else {
            [void]$flags.Add("$tag '$($r.Tenant)': v$($r.Ver) vs repo v$repo -- ASK whether this needs v$repo" +
                             $(if ($r.IsLive) { ' (LIVE = coordinated re-import, never a repo action)' } else { '' }))
            if ($r.IsLive) { $owedLive += "$($d.Name)/$($r.Tenant)" } else { $owedFdn += "$($d.Name)/$($r.Tenant)" }
        }
    }

    if ($flags.Count -eq 0) {
        Emit ("  {0,-22} v{1,-8} up to date everywhere the ledger knows about" -f $d.Name, $repo)
    } else {
        Emit ("  {0,-22} v{1,-8} {2} item(s):" -f $d.Name, $repo, $flags.Count)
        foreach ($x in $flags) { Emit "      - $x" }
    }
}

Emit '----------------------------------------------------------------------------'
Emit ("  {0} provider(s) examined{1}" -f $compared, $(if ($Since) { " (filtered to versions bumped since $Since)" } else { '' }))
Emit ("  USx provider tenant imports owed : {0}" -f $owedUsx.Count)
Emit ("  Foundation rows behind the repo  : {0}" -f $owedFdn.Count)
Emit ("  LIVE rows behind the repo        : {0}" -f $owedLive.Count)
Emit ("  Deliberately held (NOT owed)     : {0}{1}" -f $held.Count, $(if ($held.Count) { " -- $($held -join ', ')" } else { '' }))
if ($owedUsx.Count) { Emit ("  IMPORT + SWEEP: {0}" -f ($owedUsx -join ', ')) }
if ($owedLive.Count) {
    Emit ''
    Emit '  *** LIVE TENANT(S) BEHIND THE REPO -- these reach real officers. ***'
    foreach ($x in $owedLive) { Emit "      $x" }
    Emit '  A LIVE bump is a coordinated re-import. Confirm with Rob; never assume.'
}
if ($compared -eq 0) { Emit '  [NOTE] nothing matched -- no provider version changed in that range.' }
Emit '----------------------------------------------------------------------------'

if ($OutFile) {
    [IO.File]::WriteAllText($OutFile, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    if (-not $Quiet) { Write-Host "  -> $OutFile" }
}
exit 0
