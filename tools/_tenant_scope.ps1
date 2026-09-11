<#
  _tenant_scope.ps1 -- SHARED: is this tenant in scope, and if not, WHY NOT.

  WHY THIS EXISTS. Rob, 2026-09-11: "amyblair and onscene as well as a bunch of the others will
  be excluded at some point so we likely won't need to account for them or only account for them
  seperatlye". Without a scope mechanism every report re-surfaces tenants we have already decided
  not to care about, and the real queue drowns in them.

  !! EXCLUSION IS NOT DELETION, AND THAT IS THE WHOLE DESIGN. An excluded tenant is reported in
  its OWN section, with its reason, and every count prints IN-SCOPE and EXCLUDED side by side.
  A filtered report that does not say what it filtered is how a finding disappears without
  anyone deciding it should -- the same failure shape as an ACCEPTED_DIVERGENCES row that
  silences a gate while reading like a completed adjudication, and the same reason the census
  tools refuse to conflate "unresolved" with "empty".

  !! NOTHING IS EXCLUDED UNTIL IT IS IN `excluded`. tenant_scope.json ships with an EMPTY
  exclusion list and a `_candidates` block that is explicitly a PROPOSAL. A tenant is excluded
  because Rob decided it, never because a tool inferred it.

  EXPORTS
    Get-TenantScope                     the parsed scope document (or an empty-but-valid one)
    Test-TenantExcluded <deptId>        $true only for an explicit `excluded` entry
    Get-TenantExclusion <deptId>        the entry (reason/category/date/revisit) or $null
    Split-TenantsByScope <rows> <k>     -> @{ InScope=@(); Excluded=@() }, partitioning any
                                           row collection on a deptId property name
    Write-ScopeFooter <inScope> <excl>  the one-line denominator every consumer must print
#>

$script:TS_Repo = Split-Path -Parent $PSScriptRoot
# ⚠️ $env:USX_TENANT_SCOPE OVERRIDES THE PATH, and it exists so this mechanism can be TESTED
# against a replica instead of by editing the real config. Mutating a committed config file to
# prove a filter works leaves footprints (mtime, and a window where a crash leaves the mutation
# in place) -- usx-tooling Step 5c, learned the hard way five separate times on provider JSONs.
$script:TS_Path = if ($env:USX_TENANT_SCOPE) { $env:USX_TENANT_SCOPE } else { Join-Path $PSScriptRoot 'config\tenant_scope.json' }
$script:TS_Doc  = $null

function Get-TenantScope {
    if ($null -ne $script:TS_Doc) { return $script:TS_Doc }
    if (-not (Test-Path $script:TS_Path)) {
        # A MISSING scope file means NOTHING is excluded -- it must never mean "exclude
        # everything" or "silently proceed with an unknown scope". Fail open, and say so.
        $script:TS_Doc = [pscustomobject]@{ excluded = @(); _missing = $true }
        return $script:TS_Doc
    }
    $script:TS_Doc = Get-Content $script:TS_Path -Raw -Encoding UTF8 | ConvertFrom-Json
    return $script:TS_Doc
}

function Get-TenantExclusion([string]$deptId) {
    $d = Get-TenantScope
    foreach ($e in @($d.excluded)) {
        if ("$($e.deptId)" -eq "$deptId") { return $e }
    }
    return $null
}

function Test-TenantExcluded([string]$deptId) {
    return ($null -ne (Get-TenantExclusion $deptId))
}

# Partition any collection of rows carrying a deptId property. Returns BOTH halves -- a
# function that returned only the in-scope half would make the denominator unavailable to the
# caller, which is precisely the thing this module exists to prevent.
function Split-TenantsByScope($rows, [string]$DeptIdProperty = 'deptId') {
    $inScope = @(); $excluded = @()
    foreach ($r in @($rows)) {
        $id = "$($r.$DeptIdProperty)"
        $ex = Get-TenantExclusion $id
        if ($null -eq $ex) { $inScope += $r }
        else { $excluded += [pscustomobject]@{ Row = $r; Exclusion = $ex } }
    }
    return @{ InScope = $inScope; Excluded = $excluded }
}

# The footer every consumer prints. Centralised so no report can quietly omit it.
function Get-ScopeFooterLines($inScopeCount, $excludedRows) {
    $d = Get-TenantScope
    $out = @()
    $out += ("  IN SCOPE {0} | EXCLUDED {1}" -f $inScopeCount, @($excludedRows).Count)
    if ($d._missing) {
        $out += '  [WARN] tools/config/tenant_scope.json is MISSING -- nothing was excluded.'
        $out += '         That is fail-OPEN by design: an absent scope file must not silently'
        $out += '         shrink a report. Create it to start excluding.'
        return $out
    }
    if (@($excludedRows).Count -eq 0) {
        $out += '  Nothing is excluded. tenant_scope.json `excluded` is empty -- its `_candidates`'
        $out += '  block is a PROPOSAL and deliberately has no effect until Rob moves entries in.'
        return $out
    }
    $out += '  ---- EXCLUDED, and WHY (listed, never silently dropped) --------------------------'
    foreach ($x in @($excludedRows)) {
        $e = $x.Exclusion
        $rv = if ($e.revisit) { 'REVISIT' } else { 'settled' }
        $out += ("     {0,-28} {1,-8} {2}" -f "$($e.subdomain)", $rv, "$($e.reason)")
    }
    return $out
}
