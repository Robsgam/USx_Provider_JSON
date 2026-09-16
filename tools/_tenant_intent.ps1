# ===========================================================================
#  _tenant_intent.ps1 -- WHICH PROVIDER IS A TENANT SUPPOSED TO RUN?
#
#  ONE implementation of the authority order, because two would be worse than
#  either. `serve_plans.ps1`'s GET /target already answered this for the
#  browser deploy path; on 2026-09-16 `emit_import_job.ps1` needed the same
#  answer to build a job for a tenant with NOTHING installed. Writing it twice
#  means the job file can name one provider while /target names another -- and
#  `deploy_probe.js` refuses on exactly that disagreement, so the failure mode
#  is debugging two implementations at once with the real answer in neither.
#  ENGINEERING_STANDARD 4.4: never re-implement an existing parser.
#
#  AUTHORITY ORDER, and the answer always says which rung it used:
#    1. `intendedProvider` on the tenant's tenant_map.json row -> 'explicit-map'
#    2. the `usx-<slug>` subdomain, which encodes it by construction
#                                                              -> 'usx-subdomain'
#    3. nothing                                                 -> REFUSE
#
#  !! THE INSTALLED BUNDLE IS NOT AN AUTHORITY. `usx-fl-fcic` is the proof: it
#  was carrying a CA_eSUN bundle, so "what is installed" named exactly the
#  wrong provider on the first tenant we ever deployed to. Intent comes from
#  the record; the install is what is being corrected. This module therefore
#  never looks at a config file, which is also why it can answer for a tenant
#  that has no config at all.
#
#  !! WHY REFUSAL IS THE THIRD RUNG AND NOT A GUESS. Rob, 2026-09-11, on being
#  asked to type the provider into the deploy box:
#     "typing fcic in tath window is not right you should already know what the
#      tenatn is supposed to be based on my direct input intitally since you
#      ahve not deployed any on your own"
#  A typo there imports the WRONG PROVIDER and every downstream guard still
#  passes: a valid version-stamped build, the right deptId, a matching modal
#  field. Nothing compared the payload's provider to the tenant's intended one
#  because nothing knew the intended one.
#
#  !! CASING IS CANONICALISED OFF DISK, NOT DERIVED. 'usx-ca-esun' derives
#  'ca_esun'; the provider is 'CA_eSUN'. Windows' filesystem is
#  case-insensitive so Test-Path accepts either, and the mismatch stays
#  invisible until something string-compares the derived name against the
#  'CA_eSUN' written inside the bundle descriptions. Always return the
#  directory name as it exists on disk.
# ===========================================================================

function Resolve-TenantIntent {
    <#
      Returns a PSCustomObject:
        deptId / subdomain / provider / source / class / status / installedBundles / found / error
      `provider` is $null when it cannot be resolved; `error` then says why.
      NEVER throws on an unknown tenant -- a caller must be able to report the refusal.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DeptId,
        [string]$MapPath,
        [string]$ProvidersDir
    )

    $toolsDir = $PSScriptRoot
    $repoRoot = Split-Path -Parent $toolsDir
    if (-not $MapPath)      { $MapPath      = Join-Path $toolsDir 'config\tenant_map.json' }
    if (-not $ProvidersDir) { $ProvidersDir = Join-Path $repoRoot 'providers' }

    $out = [pscustomobject]@{
        deptId = $DeptId; subdomain = $null; provider = $null; source = $null
        class = $null; status = $null; installedBundles = @(); found = $false; error = $null
    }

    if (-not (Test-Path $MapPath)) { $out.error = "tenant_map.json not found at $MapPath"; return $out }

    # Re-read per call on purpose: a cached copy is how a server started yesterday served
    # pre-change data for a day (the /build endpoint, 2026-09-11).
    $map = Get-Content $MapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $row = @($map.tenants | Where-Object { "$($_.deptId)" -eq $DeptId })
    if ($row.Count -ne 1) {
        $out.error = ("deptId {0} is not in tenant_map.json ({1} rows matched) -- it cannot be a deploy target until it is recorded" -f $DeptId, $row.Count)
        return $out
    }

    $t = $row[0]
    $out.found            = $true
    $out.subdomain        = "$($t.subdomain)"
    $out.class            = "$($t.class)"
    $out.status           = "$($t.status)"
    $out.installedBundles = @($t.bundles | ForEach-Object { "$($_.name)" })

    if (($t.PSObject.Properties.Name -contains 'intendedProvider') -and $t.intendedProvider) {
        $out.provider = "$($t.intendedProvider)"; $out.source = 'explicit-map'
        return $out
    }

    if ($out.subdomain -like 'usx-*') {
        $derived = ($out.subdomain -replace '^usx-', '') -replace '-', '_'
        $dirs = @(Get-ChildItem $ProvidersDir -Directory -ErrorAction SilentlyContinue)
        $hit = @($dirs | Where-Object { $_.Name -eq $derived })
        # A slug can be a PREFIX of the real directory (usx-nm-nmlets -> NM_NMLETS_OFML). Require a
        # scripts\ dir so a doc-only or scratch sibling cannot win the match.
        if ($hit.Count -ne 1) {
            $hit = @($dirs | Where-Object { $_.Name -like "${derived}_*" -and (Test-Path (Join-Path $_.FullName 'scripts')) })
        }
        if ($hit.Count -eq 1) {
            $out.provider = $hit[0].Name    # AS ON DISK -- see the casing note in the header
            $out.source = 'usx-subdomain'
            return $out
        }
        if ($hit.Count -gt 1) {
            $out.error = ("subdomain {0} is ambiguous: {1}" -f $out.subdomain, (($hit | ForEach-Object { $_.Name }) -join ', '))
            return $out
        }
    }

    $out.error = ("no recorded intended provider for {0} ({1}) -- record intendedProvider on its tenant_map.json row; the deploy target is a decision, not something to type at the keyboard" -f $out.subdomain, $DeptId)
    return $out
}
