<#
  audit_supported_queries.ps1 -- DEVDOC GROUND-TRUTH GATE (finding F).

  The rest of the pipeline validates the JSON against artifacts derived FROM the
  JSON (matrix, conductor, simulators). Nothing confirms a combo is even a
  provider-SUPPORTED query. This tool closes that gap by checking every CommSys
  combo against a human-reviewed, per-provider supported-query list extracted from
  the devdoc "Basic Queries Supported" section:

      docs/<PROVIDER>_SUPPORTED_QUERIES.txt

  File format:
      STATUS: PROVISIONAL | CONFIRMED      (first non-comment line)
      # comments allowed
      <QueryLabel> | <PrimaryFieldReference>   (one supported query+identifier per line)

  STATUS semantics (prevents false green -- the whole point of this exercise):
    - PROVISIONAL: extract seeded but NOT yet confirmed against the devdoc.
      Mismatches report as INFO; tool exits 0 (does not gate). This is the honest
      state until a human signs off against the actual devdoc.
    - CONFIRMED:  a human verified the list against the devdoc. Mismatches FAIL and
      the tool exits 1. THIS is when the gate has real anti-"propagate failures"
      teeth.

  If the extract is ABSENT, the tool auto-writes a PROVISIONAL template from the
  JSON's own combos (a starting point for sign-off) and reports INFO -- it never
  blocks a provider that has not been set up yet.

  Usage: .\audit_supported_queries.ps1 -Path <provider.json> [-OutFile <report>]
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$resolved = (Resolve-Path $Path).Path
$json = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$provider = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '_v[\d.]+$','' -replace '(?i)_(BASE|MC)$',''
$jsonDir  = Split-Path $resolved -Parent
$docsDir  = Join-Path $jsonDir "docs"
$extractFile = Join-Path $docsDir "${provider}_SUPPORTED_QUERIES.txt"

$lines = [System.Collections.Generic.List[string]]::new()
$fail = 0; $pass = 0; $warn = 0; $info = 0
function Emit($s) { $lines.Add($s); Write-Host $s }
function Rec($tag,$msg) {
    switch ($tag) {
        'PASS' { $script:pass++; Emit "[PASS] $msg" }
        'FAIL' { $script:fail++; Emit "[FAIL] $msg" }
        'WARN' { $script:warn++; Emit "[WARN] $msg" }
        'INFO' { $script:info++; Emit "[INFO] $msg" }
    }
}

Emit "================================================================"
Emit "  SUPPORTED-QUERY (DEVDOC) AUDIT -- $provider"
Emit "================================================================"
Emit ""

# ── Collect JSON CommSys combos: (queryLabel, primaryFieldReference) ──
$provBundle = $json.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' } | Select-Object -First 1
$qidms = @($provBundle.configurations | Where-Object {
    $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.handlerFunction -eq 'CommsysTransactionRequestHandler'
})
$jsonPairs = [System.Collections.Generic.List[object]]::new()
foreach ($q in $qidms) {
    $qlabel = if ($q.queryLabel) { $q.queryLabel } elseif ($q.query) { $q.query } else { ($q.name -replace "^$([regex]::Escape($provider))_",'') }
    foreach ($c in @($q.combinations)) {
        $pf = if ($c.primaryFieldReference) { $c.primaryFieldReference } else { '(none)' }
        $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
        $jsonPairs.Add([PSCustomObject]@{ query=$qlabel; ident=$pf; keyRef=$kr })
    }
}

# ── Auto-write a PROVISIONAL template if the extract is absent ──
if (-not (Test-Path $extractFile)) {
    $tmpl = [System.Collections.Generic.List[string]]::new()
    $tmpl.Add("STATUS: PROVISIONAL")
    $tmpl.Add("# ${provider} supported queries -- DERIVED FROM JSON COMBOS, NOT YET CONFIRMED.")
    $tmpl.Add("# ACTION: verify this list against the provider devdoc 'Basic Queries Supported'.")
    $tmpl.Add("#   - remove any line the devdoc does NOT authorize")
    $tmpl.Add("#   - add any devdoc-supported query intentionally not built (document as a skip)")
    $tmpl.Add("# Then change STATUS to CONFIRMED to turn this into a hard gate.")
    $tmpl.Add("# Format: <QueryLabel> | <PrimaryFieldReference>")
    $tmpl.Add("")
    foreach ($p in ($jsonPairs | Sort-Object query, ident -Unique)) {
        $tmpl.Add("$($p.query) | $($p.ident)")
    }
    if (-not (Test-Path $docsDir)) { New-Item -ItemType Directory -Path $docsDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($extractFile, ($tmpl -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
    Rec 'INFO' "no extract found -- wrote PROVISIONAL template ($($jsonPairs.Count) combos) to ${provider}_SUPPORTED_QUERIES.txt; confirm against devdoc"
    Emit ""
    Emit "RESULTS: $pass PASS / $fail FAIL / $warn WARN ($info INFO)"
    if ($OutFile) { [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false)) }
    exit 0
}

# ── Parse the extract ──
$raw = Get-Content $extractFile | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' }
$status = 'PROVISIONAL'
$supported = [System.Collections.Generic.List[object]]::new()
foreach ($l in $raw) {
    if ($l -match '^\s*STATUS:\s*(\w+)') { $status = $Matches[1].ToUpperInvariant(); continue }
    if ($l -match '^(.*?)\s*\|\s*(.*?)\s*$') {
        $supported.Add([PSCustomObject]@{ query=$Matches[1].Trim(); ident=$Matches[2].Trim() })
    }
}
$gated = ($status -eq 'CONFIRMED')
Emit "Extract STATUS: $status  ($(if ($gated) {'GATING -- mismatches FAIL'} else {'PROVISIONAL -- mismatches INFO until devdoc sign-off'}))"
Emit ""

function Key($q,$i) { "$($q.ToLower())|$($i.ToLower())" }
$supportedKeys = @{}
foreach ($s in $supported) { $supportedKeys[(Key $s.query $s.ident)] = $true }
$jsonKeys = @{}
foreach ($p in $jsonPairs) { $jsonKeys[(Key $p.query $p.ident)] = $true }

# 1. Every JSON combo must be a supported query.
foreach ($p in $jsonPairs) {
    if ($supportedKeys.ContainsKey((Key $p.query $p.ident))) {
        Rec 'PASS' "combo $($p.keyRef): '$($p.query) | $($p.ident)' is devdoc-supported"
    } else {
        $tag = if ($gated) { 'FAIL' } else { 'INFO' }
        Rec $tag "combo $($p.keyRef): '$($p.query) | $($p.ident)' NOT in supported-query list (unsupported query?)"
    }
}

# 2. Coverage: supported queries with no combo (intentional skip or a gap).
foreach ($s in $supported) {
    if (-not $jsonKeys.ContainsKey((Key $s.query $s.ident))) {
        Rec 'WARN' "supported '$($s.query) | $($s.ident)' has NO combo in JSON (intentional skip? document it)"
    }
}

Emit ""
Emit "RESULTS: $pass PASS / $fail FAIL / $warn WARN ($info INFO)"
if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
}
if ($gated -and $fail -gt 0) { exit 1 } else { exit 0 }
