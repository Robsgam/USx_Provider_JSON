# ===========================================================================
#  _temp_scratch.ps1 -- ONE OWNER FOR THROWAWAY SCRATCH DIRECTORIES
#
#  WHY THIS EXISTS. Three tools create a GUID-named scratch dir under %TEMP%
#  and delete it in a `finally`:
#      audit_extension_syntax.ps1   usx_jsyntax_<guid>
#      audit_deploy_guards.ps1      usxdeployguard_<guid>
#      _probes/probe_pull_verdict.ps1  usx_pullverdict_<guid>
#
#  !! A `finally` IS PRE-EMPTED BY A KILL, AND THAT IS NOT HYPOTHETICAL --
#  usx-tooling Step 5c already records it ("a timeout pre-empts finally") and
#  on 2026-09-16 a measurement found 17 abandoned usx_* directories holding
#  303 MB, four of them from audit_extension_syntax alone. That gate runs on
#  every doctor pass AND in the pre-commit hook, and each headless-browser
#  scratch dir is ~7 MB, so the growth is unbounded by construction: the
#  cleanup only runs on the happy path, and the sad path is the one that
#  leaves the litter.
#
#  So the fix is not a better `finally`. It is to SWEEP ON THE WAY IN: every
#  run removes its own predecessors' abandoned dirs before creating its own.
#  A run that is killed still leaves a dir -- it simply does not survive the
#  NEXT run. That is the property a `finally` cannot give you.
#
#  !! THE AGE CUTOFF IS LOAD-BEARING. Removing every matching sibling would
#  delete the scratch dir of a CONCURRENTLY RUNNING instance -- doctor.ps1
#  invokes these gates while the pre-commit hook can be running one too. Only
#  directories older than -MaxAgeHours (default 2) are touched, which is far
#  longer than any of these gates takes and far shorter than the days-old
#  litter that accumulated.
#
#  DISK, NOT RAM. This reclaims disk and keeps %TEMP% readable. It was found
#  while looking for a memory problem and is NOT one -- say so rather than
#  letting a 303 MB number imply it fixed a 15.5 GB machine at 87%.
# ===========================================================================

function New-UsxScratch {
    <#
      Creates a fresh GUID-named scratch directory and returns its full path,
      after sweeping abandoned siblings with the same prefix.

        $work = New-UsxScratch 'usx_jsyntax_'
        try   { ... }
        finally { Remove-UsxScratch $work }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prefix,
        [int]$MaxAgeHours = 2,
        [switch]$Quiet
    )
    $root = $env:TEMP
    $cut = (Get-Date).AddHours(-[math]::Abs($MaxAgeHours))
    $swept = 0
    # -ErrorAction SilentlyContinue throughout: a locked or vanished sibling is not this run's
    # problem, and a cleanup failure must NEVER fail the gate that called us.
    foreach ($d in @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -like ($Prefix + '*') -and $_.LastWriteTime -lt $cut })) {
        try { Remove-Item $d.FullName -Recurse -Force -ErrorAction Stop; $swept++ } catch { }
    }
    if ($swept -gt 0 -and -not $Quiet) {
        Write-Host ("  [scratch] swept {0} abandoned '{1}*' dir(s) from a previous killed run" -f $swept, $Prefix)
    }
    $p = Join-Path $root ($Prefix + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

function Remove-UsxScratch {
    [CmdletBinding()]
    param([string]$Path)
    if (-not $Path) { return }
    Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
}
