# ===========================================================================
#  audit_extension_syntax.ps1 -- JS SYNTAX GATE for automation/extension/
#
#  WHY THIS EXISTS. On 2026-09-04 the usx_lib.js build tag -- a single-quoted
#  console.log string that had grown into a paragraph of prose -- acquired the
#  text  initialValue='C'  . That apostrophe closed the literal and the file
#  died at PARSE time:
#      usx_lib.js:473 Uncaught SyntaxError: missing ) after argument list
#  A parse error is TOTAL: window.__usxLib is assigned on the line ABOVE the
#  bad one and still never existed, so capture.js and driver.js both logged
#  "usx_lib not loaded" and ui.js fell back to its red "NOT a test tenant"
#  banner (isProviderTestTenant lives in the dead file). THE DRIVER AND
#  CAPTURE TOOLS WERE COMPLETELY DEAD FROM 2026-09-04 UNTIL 2026-09-09,
#  discovered only when the operator opened a tenant console.
#
#  Nothing in this repo parsed JavaScript. audit_ps51_parse.ps1 does exactly
#  this job for PowerShell and its own header says a tool must parse on the
#  engine that runs it -- the browser scripts had no equivalent.
#
#  WHY new Function() AND NOT A HEADLESS PAGE LOAD. Loading the file in a page
#  conflates a SYNTAX error with a RUNTIME throw, and several of these files
#  legitimately throw outside the extension context (no chrome.runtime). Worse,
#  a file:// page is an OPAQUE ORIGIN, so Chrome sanitizes the reason to the
#  useless "Script error." -- which is precisely how the real breakage above
#  got explained away as an environment artifact for an hour. new Function()
#  PARSES WITHOUT EXECUTING, so a clean verdict means "this is valid
#  JavaScript" and nothing else.
#
#  THE CONTROL RUNS EVERY TIME, NOT ONCE. A deliberately broken source is
#  parsed alongside the real files on every invocation. If the control does
#  not fail, this gate is inert and says so -- ENGINEERING_STANDARD LAW 2.
# ===========================================================================
[CmdletBinding()]
param([string]$Path, [string]$OutFile, [switch]$Quiet)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $Path) { $Path = Join-Path $repo 'automation\extension' }
$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$s) { $lines.Add($s) | Out-Null; if (-not $Quiet) { Write-Host $s } }

Emit "=== EXTENSION JS SYNTAX GATE ==="
Emit "Path: $Path"

if (-not (Test-Path $Path)) { Emit "[FAIL] extension dir not found: $Path"; exit 1 }

$browser = $null
foreach ($c in @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe")) {
  if ($c -and (Test-Path $c)) { $browser = $c; break }
}
# A tool that cannot run has NOT passed. Refuse loudly rather than exit 0.
if (-not $browser) { Emit "[FAIL] no Edge/Chrome found -- cannot parse JavaScript. This gate did NOT run; that is not a pass."; exit 1 }
Emit "Parser: $browser"

$files = @(Get-ChildItem -Path $Path -Filter '*.js' -File | Sort-Object Name)
if ($files.Count -eq 0) { Emit "[FAIL] 0 .js files found -- nothing was checked, which is not a pass."; exit 1 }

$work = Join-Path $env:TEMP ("usx_jsyntax_" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<!doctype html><title>PENDING</title><body><pre id="out"></pre><script>')
  [void]$sb.AppendLine('var CASES=[];')
  # The self-test control: an unterminated single-quoted string, i.e. the ACTUAL defect class.
  $ctl = "console.log('broken " + [char]39 + "C" + [char]39 + " tail');"
  [void]$sb.AppendLine("CASES.push({name:'__CONTROL_MUST_FAIL__',src:" + ($ctl | ConvertTo-Json) + "});")
  foreach ($f in $files) {
    $src = [System.IO.File]::ReadAllText($f.FullName)
    [void]$sb.AppendLine("CASES.push({name:" + ($f.Name | ConvertTo-Json) + ",src:" + ($src | ConvertTo-Json) + "});")
  }
  [void]$sb.AppendLine(@'
var res=[];
for (var i=0;i<CASES.length;i++){
  var c=CASES[i];
  try { new Function(c.src); res.push('OK|'+c.name+'|'); }
  catch(e){ res.push('SYNTAX|'+c.name+'|'+(e&&e.message?e.message:String(e))); }
}
document.getElementById('out').textContent='RESULTS_BEGIN\n'+res.join('\n')+'\nRESULTS_END';
document.title='DONE';
'@)
  [void]$sb.AppendLine('</script></body>')
  $html = Join-Path $work 'check.html'
  [System.IO.File]::WriteAllText($html, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

  # MUST be Start-Process with a REDIRECTED FILE, not `& $browser ... ` with pipeline capture.
  # Edge detaches when spawned from powershell.exe, so `$dom = & $browser ...` returns ZERO
  # characters -- verified here on a trivial one-line page, so it is not a size or timing issue.
  # The same command run from bash captures fine, which is exactly the kind of shell-boundary
  # difference that makes a gate "pass" in one harness and produce nothing in another.
  $stdout = Join-Path $work 'dom.txt'
  $bargs = @('--headless=new', '--disable-gpu', '--no-sandbox', '--virtual-time-budget=8000',
             ('--user-data-dir=' + (Join-Path $work 'ud')), '--dump-dom',
             ('file:///' + $html.Replace([char]92, [char]47)))
  Start-Process -FilePath $browser -ArgumentList $bargs -Wait -NoNewWindow -RedirectStandardOutput $stdout | Out-Null
  if (-not (Test-Path $stdout)) { Emit "[FAIL] parser wrote no output file -- gate did not run."; exit 1 }
  $domText = [System.IO.File]::ReadAllText($stdout)
  if ($domText -notmatch 'RESULTS_BEGIN') { Emit "[FAIL] parser produced no results block -- gate did not run."; exit 1 }

  $body = ($domText -split 'RESULTS_BEGIN')[1]
  $body = ($body -split 'RESULTS_END')[0]
  $rows = @($body -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^(OK|SYNTAX)\|' })

  $ctlRow = $rows | Where-Object { $_ -match '\|__CONTROL_MUST_FAIL__\|' } | Select-Object -First 1
  $real   = @($rows | Where-Object { $_ -notmatch '\|__CONTROL_MUST_FAIL__\|' })

  if (-not $ctlRow -or -not $ctlRow.StartsWith('SYNTAX|')) {
    Emit "[FAIL] LAW 2: the control (a deliberately unterminated string) did NOT fail to parse."
    Emit "       This gate cannot detect the defect it exists for. Its PASS would be meaningless."
    exit 1
  }
  Emit "[PASS] control failed as required -- this gate can fail."

  $bad = @($real | Where-Object { $_.StartsWith('SYNTAX|') })
  foreach ($r in $real) {
    $p = $r -split '\|', 3
    if ($r.StartsWith('SYNTAX|')) { Emit ("  [FAIL] {0} -- {1}" -f $p[1], $p[2]) }
    elseif (-not $Quiet)          { Emit ("  [ok]   {0}" -f $p[1]) }
  }

  Emit ""
  Emit ("TOTALS: {0} file(s) parsed / {1} SYNTAX-FAIL" -f $real.Count, $bad.Count)
  if ($real.Count -ne $files.Count) {
    Emit ("[FAIL] denominator mismatch: {0} files on disk but {1} verdicts returned." -f $files.Count, $real.Count)
    exit 1
  }
  if ($bad.Count -gt 0) {
    Emit "[FAIL] a syntax error is TOTAL -- the whole file never executes, so every global it"
    Emit "       defines is missing and every dependent script logs 'not loaded'. Fix before use."
    if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines) }
    exit 1
  }
  Emit "[PASS] all extension scripts are valid JavaScript."
  if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines) }
  exit 0
}
finally { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
