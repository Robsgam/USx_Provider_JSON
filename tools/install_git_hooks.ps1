<#
  install_git_hooks.ps1 -- copy hooks\ into .git\hooks\ and make them executable.

  WHY: .git\hooks is NOT version-controlled, so a hook written there exists on exactly one machine
  and silently does not exist anywhere else. The hooks live in hooks\ (tracked) and this installs
  them.

  THE INCIDENT THIS CLOSES. On 2026-09-04 an apostrophe inside a single-quoted console.log in
  usx_lib.js closed the string early; the file never parsed and the driver + capture tools were DEAD
  FOR FIVE DAYS. audit_extension_syntax.ps1 was built to catch it. On 2026-09-11 the same mistake was
  made in deploy_probe.js, the gate DID report [FAIL] deploy_probe.js -- missing ) after argument
  list, and the commit went through anyway because it had been chained behind a `grep` that matched
  the output whether the verdict was PASS or FAIL.

  So the gate was never the weak point -- reading its verdict beside a commit instead of BRANCHING on
  it was. This makes the check unbypassable by habit rather than by discipline.

  Usage: pwsh -File tools\install_git_hooks.ps1  [-Verify]
#>
param([switch]$Verify)

$repo  = Split-Path $PSScriptRoot -Parent
$src   = Join-Path $repo 'hooks'
$dst   = Join-Path $repo '.git\hooks'

if (-not (Test-Path $src)) { Write-Host "[FAIL] no hooks\ directory at $src" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $dst)) { Write-Host "[FAIL] no .git\hooks at $dst -- is this a git repo?" -ForegroundColor Red; exit 1 }

$hooks = @(Get-ChildItem $src -File)
if ($hooks.Count -eq 0) { Write-Host '[FAIL] hooks\ is empty -- nothing to install (an empty install is not a success).' -ForegroundColor Red; exit 1 }

$stale = 0
foreach ($h in $hooks) {
    $target = Join-Path $dst $h.Name
    # NEVER verify a produced file with Test-Path -- a leftover satisfies it. Compare CONTENT.
    $same = (Test-Path $target) -and
            ((Get-FileHash $h.FullName -Algorithm SHA256).Hash -eq (Get-FileHash $target -Algorithm SHA256).Hash)
    if ($Verify) {
        if ($same) { Write-Host ("  [ok]      {0}" -f $h.Name) -ForegroundColor Green }
        else       { Write-Host ("  [STALE]   {0} -- installed copy differs from hooks\{0}" -f $h.Name) -ForegroundColor Yellow; $stale++ }
        continue
    }
    Copy-Item $h.FullName $target -Force
    $ok = ((Get-FileHash $h.FullName -Algorithm SHA256).Hash -eq (Get-FileHash $target -Algorithm SHA256).Hash)
    if (-not $ok) { Write-Host ("  [FAIL]    {0} did not copy" -f $h.Name) -ForegroundColor Red; exit 1 }
    Write-Host ("  installed {0}" -f $h.Name) -ForegroundColor Cyan
}

if ($Verify -and $stale -gt 0) {
    Write-Host ("[FAIL] {0} hook(s) stale -- run without -Verify to install." -f $stale) -ForegroundColor Red
    exit 1
}
Write-Host ("[PASS] {0} hook(s) {1}." -f $hooks.Count, $(if ($Verify) { 'match hooks\' } else { 'installed' })) -ForegroundColor Green
