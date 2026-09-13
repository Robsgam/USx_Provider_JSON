<#
  watch_imports.ps1 -- WAIT FOR THE AFTER-EXPORT AND PROVE THE IMPORT, WITHOUT BEING ASKED.

  Rob's goal, stated twice and still not fully mechanised until now:
      "the idea is for the tool to eventually execute the imports, then run an export, then
       compare the 2 to confirm the json update takes place"
  and, on being handed a button that still needed two follow-up commands: "this is still too
  clunky".

  WHAT IT CLOSES. The import is one click. The PROOF was three manual steps -- press 6b, run
  ingest_tenant_configs, run verify_tenant_import -- and the middle of those is the step that gets
  skipped. That matters more than convenience: `verify_tenant_import` reports UNPROVEN without a
  fresh AFTER and deliberately refuses to fall back on "AFTER matches REPO, therefore it worked",
  because a tenant ALREADY at the target version satisfies that with no import having happened.
  A proof you have to remember to run is a proof that will be skipped on the day it matters.

  The panel now auto-exports after a CLICKED verdict; this picks that file up and finishes the job:
      ingest_tenant_configs.ps1  ->  verify_tenant_import.ps1  ->  PASS / DID-NOT-LAND / FAIL.

  ⚠️ -Once IS THE SUPPORTED MODE, and it is not a stylistic choice. A persistent watcher never
  notifies its supervisor and gets killed by the environment (the lesson `watch_captures.ps1`
  already carries). Run it as a background task before the operator clicks; it exits when the
  export lands, which is what surfaces the verdict.

  ⚠️ IT ONLY CONSIDERS FILES NEWER THAN ITS OWN START. A tenant config sitting in Downloads from
  an earlier pull is NOT evidence about an import that has not happened yet -- treating it as such
  is how a stale artifact becomes a green verdict. Startup catch-up is deliberately NOT done here,
  which is the opposite of watch_captures' rule, and the reason is the opposite too: a capture is
  evidence whenever it was made, an AFTER-export is only evidence relative to a specific import.

  ⚠️ IT NEVER REPORTS A PASS IT DID NOT MEASURE. If verify exits non-zero the verdict is printed
  verbatim and this exits non-zero as well, so it can be chained.

  Usage:
    tools\watch_imports.ps1 -Once                       # wait for the next AFTER-export, prove it
    tools\watch_imports.ps1 -Once -DeptId 69510828830   # only that tenant's export counts
    tools\watch_imports.ps1 -Once -TimeoutSec 600
#>
param(
    [switch]$Once,
    [string[]]$DeptId,
    [int]$TimeoutSec = 900,
    [int]$PollSec = 5,
    [switch]$VersionCheck,
    [switch]$Quiet
)

# ⚠️ -VersionCheck EXISTS BECAUSE THE RIGHT VERDICT ON THE WRONG QUESTION IS STILL MISLEADING.
# The default mode proves an IMPORT: it compares BEFORE / AFTER / REPO and, when nothing changed,
# correctly reports "THE IMPORT DID NOT LAND". But an operator who pulls a tenant merely to ASK WHAT
# VERSION IS ON IT has performed no import, so that verdict is both true and completely misleading --
# it reads as a failure when the answer was simply "unchanged". Rob, 2026-09-12, pulling Newark to
# check a version before deciding whether to import at all, is exactly that case.
# In -VersionCheck the chain ends at audit_tenant (the dossier: label AND content, side by side)
# instead of verify_tenant_import, and nothing is reported as a failure for being unchanged.

$ErrorActionPreference = 'Stop'
$repoRoot  = Split-Path -Parent $PSScriptRoot
$downloads = [System.IO.Path]::Combine($env:USERPROFILE, 'Downloads')

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }

Say '===================================================================================='
Say '  WATCH IMPORTS -- wait for the AFTER-export, then PROVE the import landed'
Say '===================================================================================='

if (-not (Test-Path $downloads)) { Say ('  [FAIL] no Downloads folder at {0}' -f $downloads); exit 1 }

$wanted = @()
if ($DeptId) { $wanted = @($DeptId | ForEach-Object { ('{0}' -f $_).Trim() } | Where-Object { $_ }) }

# Only files written AFTER this instant count. See the header: an AFTER-export is evidence only
# relative to a specific import, so a pre-existing file must never satisfy this.
$startedAt = Get-Date
Say ('  watching {0}' -f $downloads)
Say ('  pattern : usx_tenant_config_*.json written after {0:HH:mm:ss}' -f $startedAt)
if ($wanted.Count -gt 0) { Say ('  scoped  : deptId {0}' -f ($wanted -join ', ')) }
Say ('  timeout : {0}s' -f $TimeoutSec)
Say ''

$deadline = $startedAt.AddSeconds($TimeoutSec)
$seen = @()

while ((Get-Date) -lt $deadline) {
    $fresh = @(Get-ChildItem $downloads -Filter 'usx_tenant_config_*.json' -File -ErrorAction SilentlyContinue |
               Where-Object { $_.LastWriteTime -gt $startedAt -and $seen -notcontains $_.FullName })

    if ($wanted.Count -gt 0 -and $fresh.Count -gt 0) {
        $fresh = @($fresh | Where-Object { $n = $_.Name; ($wanted | Where-Object { $n -like ('*_{0}_*' -f $_) }).Count -gt 0 })
    }

    if ($fresh.Count -gt 0) {
        # Let the browser finish writing before reading -- a partially-written 300KB file parses as
        # garbage and would be reported as a corrupt tenant config rather than as a race.
        Start-Sleep -Seconds 2
        foreach ($f in $fresh) { $seen += $f.FullName }

        Say ('  [{0:HH:mm:ss}] {1} new export(s):' -f (Get-Date), $fresh.Count)
        foreach ($f in $fresh) { Say ('     {0}  ({1:N0} bytes)' -f $f.Name, $f.Length) }
        Say ''

        # ---- INGEST ---------------------------------------------------------------------------
        Say '  --- ingest_tenant_configs.ps1 -------------------------------------------------'
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ingest_tenant_configs.ps1') |
            Where-Object { $_ -match 'superseded|processing|inventory written|FAIL|OURS ' } |
            ForEach-Object { Say ('  {0}' -f $_) }

        # ---- VERIFY, per tenant that just landed ----------------------------------------------
        $tenants = @()
        foreach ($f in $fresh) {
            # usx_tenant_config_<tag>_<deptId>_<stamp>.json -- the deptId is the stable key.
            if ($f.Name -match '^usx_tenant_config_(.+)_(\d+)_[0-9T\-]+Z?\.json$') { $tenants += $Matches[2] }
        }
        $tenants = @($tenants | Select-Object -Unique)
        if ($tenants.Count -eq 0) {
            Say '  [FAIL] could not read a deptId out of any new filename -- refusing to guess which tenant to verify.'
            exit 1
        }

        $bad = 0
        foreach ($t in $tenants) {
            Say ''
            if ($VersionCheck) {
                Say ('  --- audit_tenant.ps1 -Tenant {0}  (VERSION CHECK, no import claimed) -----' -f $t)
                $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'audit_tenant.ps1') -Tenant $t 2>&1
                foreach ($l in $out) { Say ('  {0}' -f $l) }
                # Deliberately NOT counted as a failure: "unchanged" is a legitimate answer to
                # "what version is on this tenant", and the exit code of a dossier is not a verdict
                # about an import nobody performed.
            } else {
                Say ('  --- verify_tenant_import.ps1 -Tenant {0} ---------------------------------' -f $t)
                $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify_tenant_import.ps1') -Tenant $t 2>&1
                $rc = $LASTEXITCODE
                foreach ($l in $out) { Say ('  {0}' -f $l) }
                if ($rc -ne 0) { $bad++ }
            }
        }

        Say ''
        if ($bad -gt 0) {
            Say ('  [FAIL] {0} of {1} tenant(s) did not verify. The import is NOT proven.' -f $bad, $tenants.Count)
            Say '         A CLICKED verdict and an "import complete" dialog are not evidence; this is.'
            exit 1
        }
        if ($VersionCheck) { Say ("  [DONE] version check complete for {0} tenant(s) -- read the dossier above." -f $tenants.Count) }
        else { Say ("  [PASS] {0} tenant(s) verified by CONTENT against the repo build." -f $tenants.Count) }
        if ($Once) { exit 0 }
        $startedAt = Get-Date
        $deadline = $startedAt.AddSeconds($TimeoutSec)
        continue
    }

    Start-Sleep -Seconds $PollSec
}

Say ('  [TIMEOUT] no new tenant export in {0}s.' -f $TimeoutSec)
Say '            Nothing was proven -- and that is reported as a timeout, not as a pass.'
exit 2
