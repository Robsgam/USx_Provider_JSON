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
# docs/ reorg pilot (2026-07-01, NJ_NJCJIS first) -- SUPPORTED_QUERIES is "reference" category.
. (Join-Path $PSScriptRoot '_resolve_docs_path.ps1')
$extractFile = Find-DocsPath $jsonDir 'reference' "${provider}_SUPPORTED_QUERIES.txt"

$lines = [System.Collections.Generic.List[string]]::new()
$fail = 0; $pass = 0; $warn = 0; $info = 0
# CHECK 0 (devdoc transaction-name scope) failures. Tracked apart from $fail because $fail is gated
# behind the extract's STATUS, and the devdoc's authority does not depend on a human's sign-off flag.
$scopeFail = 0
function Emit($s) { $lines.Add($s); Write-Host $s }
function Rec($tag,$msg) {
    switch ($tag) {
        'PASS' { $script:pass++; Emit "[PASS] $msg" }
        'FAIL' { $script:fail++; Emit "[FAIL] $msg" }
        'WARN' { $script:warn++; Emit "[WARN] $msg" }
        'INFO' { $script:info++; Emit "[INFO] $msg" }
    }
}

# Best-effort extraction of the devdoc "Basic Queries Supported" (or "Basic Query Transactions")
# section: the transaction names it authorizes + the line range. This is the DEVDOC GROUND TRUTH.
# Rationale (2026-07-27): the SUPPORTED_QUERIES.txt extract is seeded FROM the JSON's own combos,
# so a shadow query present at seed time survives a human "CONFIRMED" rubber stamp forever (NY's
# NyNyspinDriverLicenseNameQuery / DGRP did exactly this -- an Expanded-section transaction that
# was falsely confirmed as Basic). Surfacing the devdoc's own list here gives the reconciler the
# ground truth to diff against. Advisory only -- does NOT gate (PDF-only devdocs can't be parsed).
function Get-DevdocBasic($srcDir) {
    $res = [PSCustomObject]@{ found=$false; file=$null; startLine=0; boundaryLine=0; queries=@(); note='' }
    if (-not $srcDir -or -not (Test-Path $srcDir)) { $res.note = 'no source/ dir'; return $res }
    $txt = @(Get-ChildItem -Path $srcDir -Filter '*_DEVDOC.txt' -File -ErrorAction SilentlyContinue)
    if (-not $txt) { $txt = @(Get-ChildItem -Path $srcDir -Filter '*.txt' -File -ErrorAction SilentlyContinue) }
    if (-not $txt) {
        $pdf = @(Get-ChildItem -Path $srcDir -Filter '*.pdf' -File -ErrorAction SilentlyContinue)
        $res.note = if ($pdf) { "devdoc is PDF-only ($($pdf[0].Name)); run pdftotext to enable Basic-list extraction" } else { 'no devdoc text found' }
        return $res
    }
    $file = $txt[0].FullName
    $res.file = $file
    $lines = @(Get-Content $file)
    $start = -1
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '(?i)^\s*Basic Quer(y|ies) (Supported|Transactions)\s*:') { $start = $i; break }
    }
    if ($start -lt 0) { $res.note = 'no "Basic Queries Supported:" header found'; return $res }
    $boundary = $lines.Count
    for ($i=$start+1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '(?i)^\s*(Transactions Supported|Expanded Transactions Supported|Expanded Quer(y|ies) Supported|Data-Mined Transactions|Additional Transactions)\s*:') { $boundary = $i; break }
    }
    $names = [System.Collections.Generic.List[string]]::new()
    for ($i=$start+1; $i -lt $boundary; $i++) {
        $t = $lines[$i].Trim()
        # Match the query name as the FIRST TOKEN, not the whole line. pdftotext routinely merges the
        # query heading onto the following field-table header, e.g. HI's
        #   "BoatQuery            XML Tag Name         M/C/O Size Possible Values"
        # A '$'-anchored pattern silently under-reads the ground truth in exactly that case, and an
        # under-read Basic list makes this gate weaker while looking identical to a clean run:
        # it read HI as 5 of 6 (no BoatQuery) and NJ_NJCJIS as 1 of 6, then PASSed the queries it had
        # never heard of. Relaxing the anchor was measured across all 20 providers before landing --
        # it adds exactly 6 names (HI BoatQuery; NJ ArticleSingleQuery/BoatQuery/DriverLicenseQuery/
        # GunQuery/VehicleStolenQuery) and admits no non-query text. Fixed 2026-08-04.
        if ($t -match '^([A-Za-z][A-Za-z0-9]*(?:Query|Inquiry))\b') { [void]$names.Add($Matches[1]) }
    }
    $res.found = $true
    $res.startLine = $start + 1      # 1-based, for human cross-reference
    $res.boundaryLine = $boundary + 1
    $res.queries = @($names | Sort-Object -Unique)
    return $res
}

# A VARIANT provider (<BASE>_CCH today, other "supported-stuff" variants later) is chartered to build
# BEYOND the Basic list -- that is the entire point of the variant -- so for a variant the authorized
# set is devdoc Basic UNION devdoc "Transactions Supported". Detection is MARKER-DRIVEN (`# BASE-SYNC:`
# in the build script), the same mechanism audit_variant_sync uses, so an independent provider that
# merely shares a name prefix (CA_CLETS_OCATS) is never mistaken for a variant. Do NOT widen this to
# base providers: on a base, "it's somewhere in the devdoc" is precisely the reasoning that put an
# out-of-Basic transaction into AZ_AZDPS.
# Found by the 20-provider sweep of CHECK 0 -- TX_TLETS_CCH's 8 CCH transactions are all in the
# devdoc's "Transactions Supported" section, so flagging them was MY scope model being wrong, not a
# build defect. Added 2026-08-04.
function Get-DevdocVariantSection($srcDir) {
    $out = @()
    if (-not $srcDir -or -not (Test-Path $srcDir)) { return $out }
    $txt = @(Get-ChildItem -Path $srcDir -Filter '*_DEVDOC.txt' -File -ErrorAction SilentlyContinue)
    if (-not $txt) { return $out }
    $L = @(Get-Content $txt[0].FullName)
    $s = -1
    for ($i=0; $i -lt $L.Count; $i++) {
        if ($L[$i] -match '(?i)^\s*Transactions Supported\s*:') { $s = $i; break }
    }
    if ($s -lt 0) { return $out }
    $e = $L.Count
    for ($i=$s+1; $i -lt $L.Count; $i++) {
        if ($L[$i] -match '(?i)^\s*(Expanded Transactions Supported|Expanded Quer(y|ies) Supported|Data-Mined Transactions|Additional Transactions)\s*:') { $e = $i; break }
    }
    for ($i=$s+1; $i -lt $e; $i++) {
        $t = $L[$i].Trim()
        if ($t -match '^([A-Za-z][A-Za-z0-9]*(?:Query|Inquiry))\b') { $out += $Matches[1] }
    }
    return @($out | Sort-Object -Unique)
}

function Test-IsVariantProvider($provDir) {
    $scripts = @(Get-ChildItem -Path (Join-Path $provDir 'scripts') -Filter 'build_*.ps1' -File -ErrorAction SilentlyContinue)
    foreach ($s in $scripts) {
        if ((Get-Content $s.FullName -Raw) -match '(?m)^\s*#\s*BASE-SYNC\s*:') { return $true }
    }
    return $false
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

# ── Devdoc ground truth: the "Basic Queries Supported" list the extract must be reconciled
#    AGAINST (not the JSON it was seeded from). Advisory/reference only. ──
$srcDir = Join-Path $jsonDir 'source'
$devdoc = Get-DevdocBasic $srcDir

# -- CHECK 0 -- TRANSACTION-NAME SCOPE (added 2026-08-04) -------------------------------------
#   The check this file's own template text has DESCRIBED since 2026-07-27 -- "a built query whose
#   transaction name is NOT in the list above is a SHADOW / scope violation" -- and never performed.
#   Everything below CHECK 0 compares each built combo's queryLabel against the HAND-MAINTAINED
#   extract. A LABEL IS NOT A TRANSACTION. AZ_AZDPS builds the out-of-Basic
#   `AzAzdpsDriverLicenseQuery` under the approved label 'Driver License', and every combo scored
#   [PASS] -- including "[PASS] combo DQSS: 'Driver License | SocialSecurityNumber' is
#   devdoc-supported", which is flatly false: AZ's Basic DriverLicenseQuery entry defines no SSN
#   field at all. The metadata defines DUPLICATE TRANSACTION PAIRS -- a plain devdoc name and an
#   <Provider>-prefixed sibling with DIFFERENT <Requirements> -- so the prefixed one is a different
#   query wearing the same label. On AZ that cost the two ImageIndicator="Y" photo paths (devdoc #2
#   and #5, metadata DQP) and the name-only search (devdoc #3), while adding an unauthorized SSN path.
#
#   GATES ON THE DEVDOC, NOT ON THE EXTRACT'S STATUS. AZ's extract is PROVISIONAL, and that was the
#   third layer hiding this: even a detected mismatch would have printed INFO. The devdoc is the
#   QUERY authority -- a human's sign-off state on a derived file cannot make an out-of-scope
#   transaction in-scope, so this check deliberately ignores $gated.
#
#   REFUSES TO GATE ON AN UNREADABLE LIST. If the Basic section yields zero names (CA_CONTRA_COSTA,
#   PDF-only devdocs) the check reports INFO and says plainly that nothing was verified -- gating on
#   an EMPTY ground truth would invert into failing every built query, which is the same vacuity
#   defect in the opposite direction.
$builtTx = @($qidms | ForEach-Object {
    if ($_.query) { $_.query } elseif ($_.name) { $_.name -replace "^$([regex]::Escape($provider))_", '' }
} | Where-Object { $_ } | Sort-Object -Unique)

$isVariant   = Test-IsVariantProvider $jsonDir
$variantTx   = if ($isVariant) { Get-DevdocVariantSection $srcDir } else { @() }
$authorized  = @(@($devdoc.queries) + @($variantTx) | Where-Object { $_ } | Sort-Object -Unique)
$basisLabel  = if ($isVariant) { "$($devdoc.queries.Count) Basic + $($variantTx.Count) variant-section name(s) (VARIANT: declares # BASE-SYNC)" } else { "$($devdoc.queries.Count) Basic name(s)" }

if (-not $devdoc.found -or $devdoc.queries.Count -eq 0) {
    $why = if ($devdoc.note) { $devdoc.note } else { 'Basic section parsed to 0 query names' }
    Rec 'INFO' "CHECK 0 transaction-name scope NOT VERIFIED -- $why. $($builtTx.Count) built transaction(s) unchecked; this is NOT a pass."
} elseif ($builtTx.Count -eq 0) {
    Rec 'FAIL' "CHECK 0 examined ZERO built transactions -- this check is not evidence"
} else {
    $offScope = @($builtTx | Where-Object { $authorized -notcontains $_ })
    foreach ($t in $offScope) {
        $near = @($devdoc.queries | Where-Object { $t -like "*$_" -or $_ -like "*$t" })
        $hint = ''
        if ($near.Count) {
            $nearList = $near -join ', '
            $hint = " -- the devdoc authorizes $nearList, not this prefixed sibling (different <Requirements>)"
        }
        # Counted SEPARATELY from $fail on purpose: the final exit gates $fail behind $gated (the
        # extract's CONFIRMED/PROVISIONAL flag), and CHECK 0 must not be silenceable that way. First
        # run of this check on AZ printed the [FAIL] line and still exited 0 for exactly that reason.
        $script:scopeFail++
        Rec 'FAIL' "CHECK 0 SCOPE VIOLATION: built transaction '$t' is NOT in the devdoc 'Basic Queries Supported' list$hint"
    }
    if ($offScope.Count -eq 0) {
        Rec 'PASS' "CHECK 0 transaction-name scope: all $($builtTx.Count) built transaction(s) are devdoc-authorized (compared against $basisLabel)"
    }
    # Other direction, INFO ONLY. Every current instance is an adjudicated skip (FL ImageQuery;
    # TX VehicleRegistrationQuery, merged into VehicleInsuranceRegistrationQuery; NJ VehicleStolenQuery,
    # user-approved), so raising WARNs here would manufacture noise on settled decisions. But a Basic
    # query silently DROPPED is a real class that nothing else watches, so it must still be visible.
    $notBuilt = @($devdoc.queries | Where-Object { $builtTx -notcontains $_ })
    if ($notBuilt.Count) {
        $nbList = $notBuilt -join ', '
        Rec 'INFO' "CHECK 0 devdoc-Basic but NOT BUILT: $nbList -- each must be a documented skip (ACCEPTED_DIVERGENCES / BUILD_NOTES)"
    }
}
Emit ""

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
    $tmpl.Add("#")
    if ($devdoc.found) {
        $tmpl.Add("# ---- DEVDOC GROUND TRUTH (auto-extracted -- reconcile the lines below AGAINST THIS) ----")
        $tmpl.Add("# $([System.IO.Path]::GetFileName($devdoc.file)) 'Basic Queries Supported' section, lines $($devdoc.startLine)-$($devdoc.boundaryLine):")
        if ($devdoc.queries.Count) {
            foreach ($q in $devdoc.queries) { $tmpl.Add("#     $q") }
        } else {
            $tmpl.Add("#     (NONE listed -- devdoc authorizes no Basic queries)")
        }
        $tmpl.Add("# A built query whose transaction name is NOT in the list above is a SHADOW / scope")
        $tmpl.Add("# violation (e.g. NY's NyNyspinDriverLicenseNameQuery was an Expanded-section transaction).")
        $tmpl.Add("# ---------------------------------------------------------------------------------------")
    } else {
        $tmpl.Add("# [devdoc Basic list NOT auto-extracted: $($devdoc.note) -- verify manually against the devdoc]")
    }
    $tmpl.Add("")
    foreach ($p in ($jsonPairs | Sort-Object query, ident -Unique)) {
        $tmpl.Add("$($p.query) | $($p.ident)")
    }
    $extractDir = Split-Path $extractFile -Parent
    if (-not (Test-Path $extractDir)) { New-Item -ItemType Directory -Path $extractDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($extractFile, ($tmpl -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
    Rec 'INFO' "no extract found -- wrote PROVISIONAL template ($($jsonPairs.Count) combos) to ${provider}_SUPPORTED_QUERIES.txt; confirm against devdoc"
    Emit ""
    Emit "RESULTS: $pass PASS / $fail FAIL / $warn WARN ($info INFO)"
    if ($OutFile) { [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false)) }
    # A bare `exit 0` here would swallow a CHECK 0 scope violation on any provider that has no
    # extract yet -- CHECK 0 runs BEFORE this early return and does not depend on the extract.
    if ($fail -gt 0) { exit 1 } else { exit 0 }
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
if ($devdoc.found) {
    Emit "Devdoc 'Basic Queries Supported' ($([System.IO.Path]::GetFileName($devdoc.file)), lines $($devdoc.startLine)-$($devdoc.boundaryLine)): $(if ($devdoc.queries.Count) { ($devdoc.queries -join ', ') } else { '(none)' })"
} else {
    Emit "Devdoc Basic list: not auto-extracted ($($devdoc.note))"
}
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
if ($scopeFail -gt 0) {
    Emit "BLOCKING: $scopeFail devdoc transaction-name scope violation(s) -- gates regardless of extract STATUS."
}
if (($gated -and $fail -gt 0) -or $scopeFail -gt 0) { exit 1 } else { exit 0 }
