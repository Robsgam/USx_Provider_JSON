<#
  report_tenant_groups.ps1 -- EVERY TENANT WE FOUND, GROUPED FOR A HUMAN TO DECIDE ON.

  Rob, 2026-09-12: "i need the list of found tenants so i can group them. start by grouping the
  provider we created adn the ones we did not   then with the ones we did not, there should be a
  few that are obvious real tenants and the rest likley are just deleveopment and testing tenants
  make a pdf."

  WHAT THIS IS FOR. Scoping is the blocker: tenant_scope.json ships EMPTY, so every report and
  every import job still carries tenants Rob has already decided he does not care about. He cannot
  decide from a 64-row JSON. This is the same data as a document he can read and mark up.

  THE GROUPING HE ASKED FOR, and the honest status of each level:
    A. OURS            -- MEASURED, not guessed. The provider bundle carries our
                          "Provider configuration for <P> vX.Y" stamp, and where the content also
                          hashes equal to the current repo build that is stated as CURRENT.
    B. NOT OURS        -- MEASURED. A provider bundle with NO version stamp: confirmed by CONTENT
                          to match no build in our history. This is how Lafayette was identified as
                          hand-built by engineering. Absence of the stamp is EVIDENCE, not a gap.
    B1 / B2 real vs dev -- ⚠️ A HEURISTIC, AND THE ONLY GUESSED THING IN THIS DOCUMENT. It reads
                          the subdomain and the platform status. Every row prints the SIGNAL that
                          put it where it is, so Rob can correct it by looking rather than by
                          trusting me. Nothing acts on this split; it exists to be marked up.

  ⚠️ IT NEVER WRITES tenant_scope.json. Rob's own rule, in that file: "NOTHING IS EXCLUDED UNTIL
  ROB SAYS SO. The candidates are a PROPOSAL derived from measurement; they are NOT applied."

  ⚠️ THE PDF IS VERIFIED BY WRITE TIME, NEVER Test-Path. A PDF from a previous run satisfies
  Test-Path, which is exactly how a stale officer guide once shipped under a green success line
  ("i don't see an updated user guide for il"). A conversion failure OVER AN EXISTING FILE is
  reported louder than one over no file, because it ships a document that looks current.

  Usage:
    tools\report_tenant_groups.ps1
    tools\report_tenant_groups.ps1 -OutFile providers\TENANT_GROUPS.html -PdfFile providers\TENANT_GROUPS.pdf
#>
param(
    [string]$TenantDir,
    [string]$OutFile,
    [string]$PdfFile,
    [switch]$IncludeDeactivated,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_json_canonical.ps1"
. "$PSScriptRoot\_bundle_identity.ps1"

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }

Say '===================================================================================='
Say '  TENANT GROUPS -- every tenant we found, grouped for a decision'
Say '===================================================================================='

$tenantDir = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
if (-not (Test-Path $tenantDir)) { Say ('  [FAIL] no tenant exports at {0} -- pull them first (button 6b).' -f $tenantDir); exit 1 }

# ---- repo builds -------------------------------------------------------------------------------
$repoVer = @{}; $repoHash = @{}
foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory)) {
    $cands = @(Get-ChildItem $d.FullName -Filter ('{0}_v*.json' -f $d.Name) -File -ErrorAction SilentlyContinue)
    if ($cands.Count -ne 1) { continue }
    $o = $null
    try { $o = Get-Content $cands[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ($cands[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer[$d.Name] = $Matches[1] }
    foreach ($b in (Get-BundleList $o)) { $repoHash[('{0}|{1}' -f $d.Name, $b.name)] = (Get-BundleContentHash $b) }
}
if ($repoVer.Count -eq 0) { Say '  [FAIL] no repo builds indexed.'; exit 1 }

# ---- roster (status + subdomain, keyed on deptId) ----------------------------------------------
$status = @{}
$rosterPath = Join-Path $repoRoot 'tools\config\tenant_roster.json'
if (Test-Path $rosterPath) {
    $r = Get-Content $rosterPath -Raw | ConvertFrom-Json
    foreach ($t in $r.tenants) { $status[('{0}' -f $t.deptId)] = ('{0}' -f $t.status) }
}

# ---- THE DEV/TEST HEURISTIC --------------------------------------------------------------------
# Named patterns, so the report can print WHICH one fired rather than an unexplained verdict.
$devPatterns = [ordered]@{
    # ⚠️ WIDENED after READING the first output rather than its counts: the original pattern
    # required a separator around "demo", so "erich-demo1" and "fullwooddemo" were filed as REAL
    # TENANTS. A heuristic whose misses all land in the "treat it as a real deployment" direction
    # is the safe failure mode -- but it is still wrong, and a count would never have shown it.
    'demo'      = 'demo\d*'
    'test'      = '(^|[-_])test([-_]|$)|[-_]test\d*$'
    'qa'        = '^qa([-_]|$)'
    'practice'  = '^practice([-_]|$)'
    'sandbox'   = 'sandbox'
    'training'  = 'training'
    'migration' = 'migration'
    'personal'  = '^(dark|justin|kyle|kris|abbey|amyblair|amyb)([-_]|$)'
}
# A LIVE tenant is a real deployment whatever its name looks like -- status outranks the name.
function Get-DevSignal([string]$sub, [string]$st) {
    if ($st -match 'LIVE') { return $null }
    foreach ($k in $devPatterns.Keys) { if ($sub -match $devPatterns[$k]) { return $k } }
    return $null
}

$files = @(Get-ChildItem $tenantDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch 'provenance' })
if ($files.Count -eq 0) { Say '  [FAIL] no tenant configs on disk.'; exit 1 }

$rows = @(); $skipped = @()
foreach ($f in $files) {
    $dept = ($f.BaseName -replace '^.*_(\d+)$', '$1')
    if ($dept -notmatch '^\d+$') { $skipped += $f.Name; continue }   # a -replace that did not match returns its input
    $sub = ($f.BaseName -replace '_\d+$', '')
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $skipped += $f.Name; continue }
    $bl = Get-BundleList $o
    if ($bl.Count -eq 0) { $skipped += $f.Name; continue }

    $pb = @($bl | Where-Object { ('{0}' -f $_.name) -ne 'ENTITIES' -and ('{0}' -f $_.name) -ne 'RMS' })[0]
    $pn  = if ($pb) { '{0}' -f $pb.name } else { '(none)' }
    $lbl = if ($pb) { Get-BundleLabelVersion $pb } else { $null }
    $st  = if ($status.ContainsKey($dept)) { $status[$dept] } else { 'UNKNOWN' }

    $isCurrent = $false
    if ($lbl -and $repoVer.ContainsKey($pn)) {
        $allMatch = $true; $compared = 0
        foreach ($b in $bl) {
            $k = '{0}|{1}' -f $pn, $b.name
            if (-not $repoHash.ContainsKey($k)) { $allMatch = $false; break }
            $compared++
            if ((Get-BundleContentHash $b) -ne $repoHash[$k]) { $allMatch = $false; break }
        }
        $isCurrent = ($allMatch -and $compared -gt 0)
    }

    $ours = [bool]$lbl
    $sig  = if ($ours) { $null } else { Get-DevSignal $sub $st }

    $rows += [pscustomobject]@{
        Sub = $sub; Dept = $dept; Status = ($st -replace '^(Live|Test|Training|Deactivated)', ''); Provider = $pn
        Ours = $ours; Version = $(if ($lbl) { $lbl.Version } else { $null })
        RepoVer = $(if ($repoVer.ContainsKey($pn)) { $repoVer[$pn] } else { $null })
        Current = $isCurrent; DevSignal = $sig
        Bundles = (@($bl | ForEach-Object { '{0}' -f $_.name }) -join ', ')
        Bytes = (Get-Item $f.FullName).Length
    }
}

$deact = @($rows | Where-Object { $_.Status -match 'DEACTIVATED' })
if (-not $IncludeDeactivated -and $deact.Count -gt 0) { $rows = @($rows | Where-Object { $_.Status -notmatch 'DEACTIVATED' }) }

$groupA  = @($rows | Where-Object { $_.Ours } | Sort-Object Provider, Sub)
$notOurs = @($rows | Where-Object { -not $_.Ours })
$groupB1 = @($notOurs | Where-Object { -not $_.DevSignal } | Sort-Object Sub)
$groupB2 = @($notOurs | Where-Object { $_.DevSignal } | Sort-Object DevSignal, Sub)

Say ('  {0} tenant(s) | OURS {1} | NOT OURS {2} (real-looking {3} / dev-test {4}) | deactivated {5}{6}' -f
     $rows.Count, $groupA.Count, $notOurs.Count, $groupB1.Count, $groupB2.Count, $deact.Count,
     $(if ($IncludeDeactivated) { ' (included)' } else { ' (excluded)' }))
if ($skipped.Count -gt 0) { Say ('  {0} file(s) skipped -- unreadable or no deptId in the name' -f $skipped.Count) }

# ---- HTML --------------------------------------------------------------------------------------
# ⚠️ NOT named `H`: the built-in alias `h` for Get-History SHADOWS a one-letter function, and this
# repo has already lost a probe to exactly that (six bogus `True` results comparing $null -eq $null).
# It failed here as `Get-History : Cannot convert value "TEST" to type "System.Int64"`.
function HtmlEsc([string]$s) { if ($null -eq $s) { return "" }; [System.Net.WebUtility]::HtmlEncode($s) }

$sb = New-Object System.Text.StringBuilder
function Add($s) { [void]$sb.AppendLine($s) }

Add '<!doctype html><html><head><meta charset="utf-8"><title>USx Tenant Groups</title><style>'
Add 'body{font:13px/1.45 "Segoe UI",system-ui,sans-serif;color:#111;margin:28px;max-width:1100px}'
Add 'h1{font-size:22px;margin:0 0 4px} h2{font-size:16px;margin:26px 0 6px;border-bottom:2px solid #333;padding-bottom:3px}'
Add 'h3{font-size:13px;margin:16px 0 4px;color:#444}'
Add '.sub{color:#666;font-size:12px;margin:0 0 14px}'
Add 'table{border-collapse:collapse;width:100%;margin:6px 0 14px;font-size:12px}'
Add 'th,td{border:1px solid #ccc;padding:4px 6px;text-align:left;vertical-align:top}'
Add 'th{background:#eee;font-weight:600}'
Add 'tr:nth-child(even) td{background:#fafafa}'
Add '.mono{font-family:Consolas,ui-monospace,monospace;font-size:11px}'
Add '.ok{color:#0a6e2e;font-weight:600}.behind{color:#a15c00;font-weight:600}.live{color:#b00;font-weight:700}'
Add '.note{background:#fff8e1;border-left:4px solid #e0a800;padding:8px 10px;margin:10px 0;font-size:12px}'
Add '.warn{background:#fdecea;border-left:4px solid #c00;padding:8px 10px;margin:10px 0;font-size:12px}'
Add '.decide{background:#e8f4ff;border-left:4px solid #2b7;padding:8px 10px;margin:10px 0;font-size:12px}'
Add '@media print{h2{page-break-after:avoid}table{page-break-inside:auto}tr{page-break-inside:avoid}}'
Add '</style></head><body>'

Add ('<h1>USx Tenant Groups</h1>')
Add ('<p class="sub">Generated {0} by <span class="mono">tools\report_tenant_groups.ps1</span> from {1} pulled tenant configurations. Repo builds indexed: {2} providers.</p>' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $rows.Count, $repoVer.Count)

Add '<div class="decide"><b>What this document is for.</b> Scoping is the blocker: <span class="mono">tenant_scope.json</span> ships empty, so every report and every import job still carries tenants already decided against. Mark this up and the exclusions get applied with your reason and the date.</div>'

Add '<div class="note"><b>What is measured and what is guessed.</b> <b>Ours / not ours is MEASURED</b> &mdash; a configuration of ours carries a <span class="mono">Provider configuration for &lt;P&gt; vX.Y</span> stamp in its bundle description, and where the content also hashes equal to the current repo build it is marked CURRENT. Absence of that stamp is <i>evidence</i>, not a gap: it is how Lafayette was confirmed hand-built by engineering. <b>The real-vs-development split in section B is a HEURISTIC</b> &mdash; the only guessed thing here. Each row prints the signal that placed it, so you can correct it by looking rather than by trusting the tool.</div>'

Add ('<h2>Summary</h2><table><tr><th>Group</th><th>Count</th><th>Basis</th></tr>')
Add ('<tr><td><b>A &mdash; our build</b></td><td>{0}</td><td>MEASURED: carries our version stamp</td></tr>' -f $groupA.Count)
Add ('<tr><td><b>B1 &mdash; not ours, looks like a real tenant</b></td><td>{0}</td><td>measured not-ours; no dev/test signal in the name</td></tr>' -f $groupB1.Count)
Add ('<tr><td><b>B2 &mdash; not ours, looks like development / testing</b></td><td>{0}</td><td>measured not-ours; HEURISTIC on name + status</td></tr>' -f $groupB2.Count)
Add ('<tr><td>deactivated (not listed)</td><td>{0}</td><td>platform status; cannot serve queries</td></tr>' -f $deact.Count)
Add '</table>'

# ---- A ----
Add '<h2>A. Runs a configuration WE created</h2>'
Add '<p class="sub">Measured from the bundle description, corroborated by content hash against the current repo build.</p>'
Add '<table><tr><th>Tenant</th><th>Dept id</th><th>Status</th><th>Provider</th><th>Version</th><th>vs repo</th></tr>'
foreach ($r in $groupA) {
    $cls = if ($r.Current) { '<span class="ok">CURRENT</span>' } else { ('<span class="behind">behind (repo v{0})</span>' -f $r.RepoVer) }
    $stc = if ($r.Status -match 'LIVE') { '<span class="live">LIVE</span>' } else { HtmlEsc $r.Status }
    Add ('<tr><td class="mono">{0}</td><td class="mono">{1}</td><td>{2}</td><td class="mono">{3}</td><td class="mono">v{4}</td><td>{5}</td></tr>' -f
         (HtmlEsc $r.Sub), (HtmlEsc $r.Dept), $stc, (HtmlEsc $r.Provider), (HtmlEsc $r.Version), $cls)
}
Add '</table>'

# ---- B ----
Add '<h2>B. Runs a configuration we did NOT create</h2>'
Add '<p class="sub">A provider bundle is present but carries no version stamp of ours &mdash; confirmed by content to match no build in our history. Overwriting one of these is a different decision and needs a human.</p>'

Add ('<h3>B1. Looks like a real tenant &mdash; {0}</h3>' -f $groupB1.Count)
Add '<table><tr><th>Tenant</th><th>Dept id</th><th>Status</th><th>Provider bundle</th><th>Bundles present</th></tr>'
foreach ($r in $groupB1) {
    $stc = if ($r.Status -match 'LIVE') { '<span class="live">LIVE</span>' } else { HtmlEsc $r.Status }
    Add ('<tr><td class="mono">{0}</td><td class="mono">{1}</td><td>{2}</td><td class="mono">{3}</td><td class="mono">{4}</td></tr>' -f
         (HtmlEsc $r.Sub), (HtmlEsc $r.Dept), $stc, (HtmlEsc $r.Provider), (HtmlEsc $r.Bundles))
}
Add '</table>'

Add ('<h3>B2. Looks like development / testing &mdash; {0} <span style="font-weight:400;color:#a15c00">(heuristic &mdash; signal shown per row)</span></h3>' -f $groupB2.Count)
Add '<table><tr><th>Tenant</th><th>Dept id</th><th>Status</th><th>Provider bundle</th><th>Signal that placed it here</th></tr>'
foreach ($r in $groupB2) {
    Add ('<tr><td class="mono">{0}</td><td class="mono">{1}</td><td>{2}</td><td class="mono">{3}</td><td>name matches <b>{4}</b></td></tr>' -f
         (HtmlEsc $r.Sub), (HtmlEsc $r.Dept), (HtmlEsc $r.Status), (HtmlEsc $r.Provider), (HtmlEsc $r.DevSignal))
}
Add '</table>'

Add '<div class="warn"><b>A LIVE tenant is never placed in B2 on its name.</b> Status outranks the name, because a real deployment with an informal subdomain is exactly the row that must not be quietly filed as a test system.</div>'
Add '<div class="warn"><b>A customer&rsquo;s TRAINING tenant is not a development sandbox.</b> <span class="mono">lafayettela-sherifftraining</span> is placed in B2 by the word &ldquo;training&rdquo;, but it belongs to Lafayette Parish &mdash; a real agency whose LA_LEMS configuration the ledger already records as hand-built by engineering. Excluding it would hide a supported environment. Judge it with its sibling <span class="mono">lafayettesheriff-la</span> in B1, not with the demo tenants.</div>'

Add '<h2>How to use this</h2><ol>'
Add '<li>Mark the rows that should be <b>excluded</b> from import planning and reporting.</li>'
Add '<li>They move into <span class="mono">tools\config\tenant_scope.json</span> under <span class="mono">excluded</span>, each with a reason and a date &mdash; never silently dropped: every count prints in-scope and excluded side by side.</li>'
Add '<li>A tenant on a deliberate HOLD is reported separately rather than excluded, so the hold stays visible instead of quietly becoming a forgotten gap.</li>'
Add '</ol>'
Add ('<p class="sub">Nothing here is applied. No tool writes <span class="mono">tenant_scope.json</span> or <span class="mono">IMPORT_LEDGER.md</span>.</p>')
Add '</body></html>'

$outHtml = if ($OutFile) { $OutFile } else { Join-Path $repoRoot 'providers\TENANT_GROUPS.html' }
[System.IO.File]::WriteAllText($outHtml, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Say ('  HTML: {0}' -f $outHtml)

# ---- PDF (write-time verified, never Test-Path) -------------------------------------------------
if ($PdfFile) {
    $edge = $null
    foreach ($cand in @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    )) { if ($cand -and (Test-Path $cand)) { $edge = $cand; break } }
    if (-not $edge) {
        Say '  [WARN] Edge/Chrome not found -- PDF skipped. The HTML is complete; print it to PDF.'
    } else {
        $pdfFull = [System.IO.Path]::GetFullPath($PdfFile)
        $before = if (Test-Path $pdfFull) { (Get-Item $pdfFull).LastWriteTimeUtc } else { [datetime]::MinValue }
        $uri = 'file:///' + ((Resolve-Path $outHtml).Path -replace '\\','/')
        & $edge --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=4000 "--print-to-pdf=$pdfFull" $uri 2>$null
        # POLL rather than sample once: the conversion is asynchronous and a single sleep reported
        # every file stale on the first attempt.
        $ok = $false
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Milliseconds 400
            if ((Test-Path $pdfFull) -and ((Get-Item $pdfFull).LastWriteTimeUtc -gt $before)) { $ok = $true; break }
        }
        if ($ok) { Say ('  PDF : {0}  ({1:N0} bytes)' -f $pdfFull, (Get-Item $pdfFull).Length) }
        else {
            Say '  [FAIL] the PDF was NOT rewritten. A leftover file from a previous run satisfies Test-Path,'
            Say '         so this is reported as a failure rather than a success over a stale document.'
            exit 1
        }
    }
}
Say '===================================================================================='
exit 0
