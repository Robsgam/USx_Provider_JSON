<#
  audit_deploy_guards.ps1 -- PROVE THE WRITE PATH REFUSES. LAW 2, applied to the one file in
  this project that can change someone's tenant.

  WHY THIS EXISTS. deploy_probe.js is the only write path in the extension. Its whole safety
  claim is "every guard can refuse" -- and a guard that cannot refuse is decoration. This gate
  EXECUTES `runGuards` against a real DOM with planted faults and asserts that each one is
  caught, so the claim is measured rather than asserted.

  HOW IT RUNS. A harness page builds a real #import-modal / #import-json / #do-import DOM,
  loads deploy_probe.js with <script src>, calls the EXPORTED runGuards for each case, and
  writes verdicts into the DOM. The page is then rendered by headless Edge with --dump-dom and
  the verdicts read back.

  ⚠️ Uses Start-Process -RedirectStandardOutput, NEVER pipeline capture. Edge DETACHES when
  spawned from powershell.exe and `& $browser` returns ZERO characters -- audit_extension_syntax
  learned that on a one-line page, so it is not size or timing.

  ⚠️ IT CARRIES ITS OWN CONTROL. One case is a DELIBERATELY VALID request that must be ALLOWED.
  A gate that refuses everything would score 100% on refusals while being useless -- and would
  also block every real deploy. If the control is refused, the gate reports itself broken.

  Usage: .\tools\audit_deploy_guards.ps1 [-OutFile <report>]
#>

param([string]$OutFile, [switch]$Quiet)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$extDir   = Join-Path $repoRoot 'automation\extension'
$deployJs = Join-Path $extDir 'deploy_probe.js'

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

Say ''
Say '===================================================================================='
Say '  DEPLOY GUARD EFFICACY -- can the only write path actually refuse?'
Say '===================================================================================='

if (-not (Test-Path $deployJs)) {
    Say "  [FAIL] $deployJs not found -- nothing to test."
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

# locate a Chromium
$browser = $null
foreach ($c in @(
    "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe")) {
    if (Test-Path $c) { $browser = $c; break }
}
if (-not $browser) {
    Say '  [FAIL] no Edge/Chrome found -- a gate that cannot run has not PASSED.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
Say ("  parser: {0}" -f $browser)

$work = Join-Path $env:TEMP ('usxdeployguard_' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item $deployJs (Join-Path $work 'deploy_probe.js')
# usx_lib is referenced only inside dl(), which the guard tests never reach; a stub keeps the
# page from erroring on load without pretending the real thing is present.
Set-Content (Join-Path $work 'usx_lib_stub.js') -Value 'window.__usxLib={triggerDownload:function(){return true;}};' -Encoding ASCII

# A VALID payload: ENTITIES + exactly one version-stamped provider bundle, padded past the
# 10,000-byte plausibility floor the guards enforce.
$pad = 'x' * 12000
$validPayload = @"
{"bundles":[
 {"name":"ENTITIES","description":"Provider configuration for FL_FCIC v7.24 -- entity forms","pad":"$pad"},
 {"name":"FL_FCIC","description":"Provider configuration for FL_FCIC v7.24"},
 {"name":"RMS","description":"Provider configuration for RMS"}
]}
"@
$validJs = $validPayload -replace '\\', '\\\\' -replace '"', '\"' -replace "`r?`n", ''

$html = @"
<!doctype html><html><body>
<div id="import-modal">
  <!-- ⚠️ THIS DOM IS THE MEASURED ONE, and it was not before. The first version of this harness
       held a single anonymous <input type="text" value="69510828830">, which is exactly the shape
       the old findTargetField heuristic (scan every non-file input for /^\d{3,}$/, require EXACTLY
       one) was written against. It reported 20/20 while the guard REFUSED a legitimate dry run on
       the real page with "could not identify the modal target field unambiguously" -- because the
       real modal also carries #import-file-name, a second text input.
       A fixture I invented cannot test code I wrote to match it. Element order, ids and types below
       are copied from usx_admin_dialog_*.json, captured off the live dialog. -->
  <input type="text" id="import-dept-id-input" value="69510828830">
  <input type="text" id="import-file-name" placeholder="Choose a .json file">
  <button id="import-from-file-btn">Browse</button>
  <input type="file" id="import-file">
  <textarea id="import-json"></textarea>
  <button id="do-import">Import</button>
</div>
<pre id="results"></pre>
<script src="usx_lib_stub.js"></script>
<script src="deploy_probe.js"></script>
<script>
(function(){
  var R = document.getElementById('results');
  function line(s){ R.textContent += s + '\n'; }
  if (!window.__usxDeploy) { line('HARNESS-FAIL deploy_probe did not load'); return; }
  var D = window.__usxDeploy;
  var VALID = "$validJs";

  function ctx(){
    var m = document.querySelector('#import-modal');
    return { urlDeptId: '69510828830', modal: m,
             textarea: m ? m.querySelector('#import-json') : null,
             doBtn: document.querySelector('#do-import'),
             targetField: D.findTargetField(m) };
  }
  function base(){ return { deptId:'69510828830', payload: VALID, expectProvider:'FL_FCIC', expectVersion:'7.24' }; }
  var CASES = 0;
  function check(name, mutate, mustRefuse){
    CASES++;
    var o = base(); var c = ctx();
    var beforeJson = JSON.stringify({ d:o.deptId, p:(o.payload||'').length, ep:o.expectProvider,
                                      ev:o.expectVersion, ts:o.tenantStatus, lc:o.liveConfirmed,
                                      ab:window.__usxDeployAbort,
                                      cm:!!c.modal, ct:!!c.textarea, cb:!!c.doBtn,
                                      cf:(c.targetField?String(c.targetField.value):'null'),
                                      ro:(c.textarea?!!c.textarea.readOnly:null),
                                      ph:(o.payload||'').slice(0,200) });
    if (mutate) { mutate(o, c); }
    var afterJson = JSON.stringify({ d:o.deptId, p:(o.payload||'').length, ep:o.expectProvider,
                                     ev:o.expectVersion, ts:o.tenantStatus, lc:o.liveConfirmed,
                                     ab:window.__usxDeployAbort,
                                     cm:!!c.modal, ct:!!c.textarea, cb:!!c.doBtn,
                                     cf:(c.targetField?String(c.targetField.value):'null'),
                                     ro:(c.textarea?!!c.textarea.readOnly:null),
                                     ph:(o.payload||'').slice(0,200) });
    // ⚠️ A MUTATION THAT DID NOT MUTATE PROVES NOTHING, AND THAT IS NOT HYPOTHETICAL: the
    // 'payload unstamped' case targeted `v7.24",` while the JSON holds `v7.24"}`, so the
    // replace was a no-op, the payload stayed VALID, and the case reported the guard as broken
    // when the guard had never been exercised. A silently-inert test is worse than a missing
    // one -- it occupies the slot where coverage is assumed to be.
    if (mutate && beforeJson === afterJson) {
      line('BROKEN ' + name + ' :: TEST IS INERT -- the mutation changed nothing, so this guard was never exercised');
      return;
    }
    var bad = D.runGuards(o, c);
    var refused = bad.length > 0;
    var ok = (refused === mustRefuse);
    line((ok ? 'OK   ' : 'BROKEN ') + name + ' :: ' + (refused ? ('REFUSED -- ' + bad[0]) : 'ALLOWED'));
  }

  // THE CONTROL: a valid request MUST be allowed, or the gate proves nothing.
  check('CONTROL valid request is ALLOWED', null, false);

  check('no deptId',              function(o){ delete o.deptId; }, true);
  check('deptId mismatches URL',  function(o){ o.deptId = '11111111'; }, true);
  check('modal absent',           function(o,c){ c.modal = null; c.textarea = null; c.targetField = null; }, true);
  check('textarea absent',        function(o,c){ c.textarea = null; }, true);
  check('textarea readOnly',      function(o,c){ c.textarea = {readOnly:true}; }, true);
  check('execute button absent',  function(o,c){ c.doBtn = null; }, true);
  check('modal target disagrees', function(o,c){ c.targetField = {value:'99999999'}; }, true);
  check('target field ambiguous', function(o,c){ c.targetField = null; }, true);
  check('no payload',             function(o){ delete o.payload; }, true);
  check('payload too small',      function(o){ o.payload = '{"bundles":[]}'; }, true);
  check('payload not JSON',       function(o){ o.payload = 'x'.repeat(20000); }, true);
  check('payload no bundles',     function(o){ o.payload = '{"bundles":[],"pad":"' + 'y'.repeat(20000) + '"}'; }, true);
  check('payload no ENTITIES',    function(o){ o.payload = VALID.replace('ENTITIES','SOMETHINGELSE'); }, true);
  check('payload unstamped',      function(o){ o.payload = VALID.split('Provider configuration for FL_FCIC v7.24').join('hand built by engineering'); }, true);
  check('payload wrong provider', function(o){ o.expectProvider = 'NJ_NJCJIS'; }, true);
  check('payload wrong version',  function(o){ o.expectVersion = '9.99'; }, true);
  check('LIVE without consent',   function(o){ o.tenantStatus = 'LiveLIVE'; }, true);
  check('LIVE with consent',      function(o){ o.tenantStatus = 'LiveLIVE'; o.liveConfirmed = true; }, false);

  // ── THE RESOLVER AND THE RACE, against the MEASURED DOM ────────────────────────────────
  // Every case above hands runGuards a hand-made {value:...} stub, so NONE of them touch
  // findTargetField -- which is exactly how the broken version passed 20/20 while refusing the
  // real page. These use the DOM and assert the resolver's OWN return value.
  //
  // ⚠️ The first attempt at these cases ALSO failed to discriminate: it drove them through
  // runGuards, and since a null targetField and a mismatched one both produce a refusal, the old
  // and new resolvers scored identically. A test that cannot tell the fixed code from the broken
  // code is not a test. These assert the resolver directly.
  function assert(name, got, want){
    CASES++;
    var ok = (got === want);
    line((ok ? 'OK   ' : 'BROKEN ') + name + ' :: got ' + JSON.stringify(got) + ' want ' + JSON.stringify(want));
  }
  var M = document.querySelector('#import-modal');
  var DF = document.querySelector('#import-dept-id-input');

  // THE ACTUAL DEFECT: the page populates dept-id a moment after the modal renders, so at the
  // instant we looked the field was EMPTY. The resolver must still FIND it (so the caller can
  // wait for it and say what is really wrong), and targetReady must say NOT YET.
  DF.value = '';
  assert('empty dept-id: resolver still FINDS the field', D.findTargetField(M) === DF, true);
  assert('empty dept-id: targetReady is false (wait, do not read)', D.targetReady(M), false);

  // Populated: found, and ready.
  DF.value = '69510828830';
  assert('populated: resolver finds #import-dept-id-input', D.findTargetField(M) === DF, true);
  assert('populated: targetReady is true', D.targetReady(M), true);

  // The sibling filename box must never be mistaken for the target, even holding digits.
  document.querySelector('#import-file-name').value = '20260911';
  assert('numeric filename box is not mistaken for the target', D.findTargetField(M) === DF, true);
  document.querySelector('#import-file-name').value = '';

  // A UI change that renames the id must REFUSE, not fall back onto some other numeric field.
  var keep = DF.id; DF.id = 'renamed-by-a-ui-change';
  assert('id renamed: fallback finds the one numeric field', D.findTargetField(M) === DF, true);
  var decoy = document.createElement('input');
  decoy.type = 'text'; decoy.value = '12345678901'; M.appendChild(decoy);
  assert('id renamed AND a second numeric field: REFUSE, never guess', D.findTargetField(M), null);
  M.removeChild(decoy); DF.id = keep;

  check('operator abort',         function(){ window.__usxDeployAbort = true; }, true);
  window.__usxDeployAbort = false;
  line('CASES ' + CASES);
  line('DONE');
})();
</script></body></html>
"@
$page = Join-Path $work 'guards.html'
Set-Content -Path $page -Value $html -Encoding UTF8

$outTxt = Join-Path $work 'dump.txt'
$errTxt = Join-Path $work 'err.txt'
$args = @('--headless=new', '--disable-gpu', '--no-sandbox', '--dump-dom',
          ('--user-data-dir=' + (Join-Path $work 'ud')), ('file:///' + ($page -replace '\\','/')))
Start-Process -FilePath $browser -ArgumentList $args -Wait -NoNewWindow `
    -RedirectStandardOutput $outTxt -RedirectStandardError $errTxt | Out-Null
$dump = if (Test-Path $outTxt) { Get-Content $outTxt -Raw } else { '' }

if (-not $dump -or $dump.Length -lt 50) {
    Say '  [FAIL] the browser produced no DOM -- the gate could not run, which is not a PASS.'
    if (Test-Path $errTxt) { Get-Content $errTxt | Select-Object -First 5 | ForEach-Object { Say ('         ' + $_) } }
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

# ⚠️ STRIP TAGS BEFORE MATCHING. --dump-dom emits the first line of <pre> GLUED to the tag
# ("<pre id=\"results\">OK   CONTROL ..."), so an anchored ^(OK|BROKEN) match silently DROPPED
# the control case -- which had actually passed. The report then showed 19 lines for 20 cases
# and the missing one was the single case whose absence mattered most. Hence also the CASES
# assertion below: a dropped verdict must FAIL, not quietly shrink the denominator.
$verdicts = @()
foreach ($l in ($dump -split "`n")) {
    $t = ($l -replace '<[^>]*>', '').Trim()
    if ($t -match '^(OK|BROKEN|HARNESS-FAIL|DONE|CASES)') { $verdicts += $t }
}
$declared = 0
foreach ($v in $verdicts) { if ($v -match '^CASES\s+(\d+)$') { $declared = [int]$Matches[1] } }
$seen = @($verdicts | Where-Object { $_ -match '^(OK|BROKEN)' }).Count
if ($declared -gt 0 -and $seen -ne $declared) {
    Say ("  [FAIL] the harness ran {0} case(s) but only {1} verdict(s) were parsed -- {2} lost." -f $declared, $seen, ($declared - $seen))
    Say '         A dropped verdict shrinks the denominator silently, so this is a FAIL, not a note.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
if ($verdicts.Count -eq 0) {
    Say '  [FAIL] no verdict lines in the rendered DOM -- the harness did not execute.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
if (-not ($verdicts -contains 'DONE')) {
    Say '  [FAIL] the harness did not reach DONE -- it threw partway, so absent failures mean nothing.'
    foreach ($v in $verdicts) { Say ('    ' + $v) }
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

Say ''
foreach ($v in $verdicts) { if ($v -ne 'DONE' -and $v -notmatch '^CASES') { Say ('  ' + $v) } }

$broken = @($verdicts | Where-Object { $_ -match '^(BROKEN|HARNESS-FAIL)' })
$okCount = @($verdicts | Where-Object { $_ -match '^OK' }).Count
Say ''
Say ("  cases: {0} declared / {1} parsed / {2} correct / {3} broken" -f $declared, $seen, $okCount, $broken.Count)
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

if ($broken.Count -gt 0) {
    Say '  [FAIL] a guard did not behave as specified. The write path is NOT safe to use.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
Say '  [PASS] every planted fault was refused AND the valid control was allowed.'
Say '         The refusals are measured, not asserted -- and the control proves the gate is'
Say '         not simply refusing everything, which would score perfectly and block every deploy.'
Say '===================================================================================='
Say ''
if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
exit 0
