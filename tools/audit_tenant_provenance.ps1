<#
  audit_tenant_provenance.ps1 -- WHICH BUILD IS THIS BUNDLE, ACTUALLY? Identified by CONTENT
  against every version in git history. A label can go stale; a hash cannot.

  WHY THIS EXISTS. Rob, 2026-09-11: "we have all the curren tjsons in our repo so figuring out
  what the combination of versions shouldn't be hard", then "do that  that should be part of
  the ability to generate any version of the json like we worked on earlier."

  THE DEFECT IT REPLACES. Our version rides in the DESCRIPTION of up to three bundles
  (ENTITIES / <PROVIDER> / RMS), and imports are PER-BUNDLE -- so a tenant can hold a bundle
  whose description was baked in at an older import while its content is current, or the
  reverse. Reading a description and calling it "the version" was wrong in BOTH directions and
  silent in both (all three observed 2026-09-11):
     usx-az-azdps        RMS labelled "AZ_AZDPS v3.4" -- content byte-identical to v3.12's RMS.
                         Reported as a mixed install. NOTHING was wrong.
     usx-hi-hcjdc-ofml   ENTITIES v4.19 / PROVIDER v4.20, ENTITIES content identical across
                         both builds. Reported BEHIND. It is CURRENT.
     practice-bertanzini ENTITIES v4.9 / PROVIDER v4.8. Reported CLEAN, because the stale label
                         happened to MATCH the ledger -- and the provider bundle turned out to
                         match NO build in our history at all.
  A label-based audit cannot see any of that. A content hash can.

  HOW IT WORKS
    1. Enumerates every provider JSON that ever existed, via the SHARED
       _resolve_version_history.ps1 (the same walk get_provider_version.ps1 uses -- 671
       artifacts; see its warning about --diff-filter=A under-reporting a version SWAP).
    2. Reads each historical blob with `git cat-file` (never extracting ~540MB to disk),
       hashes EVERY bundle inside it with the DESCRIPTION EXCLUDED, and caches the result
       keyed by blob sha. The cache makes re-runs instant and only new blobs cost anything.
    3. Hashes every bundle of every tenant config and reports which build(s) it matches.

  !! WHY THE DESCRIPTION IS EXCLUDED FROM THE HASH. It is the only field guaranteed to differ
  between two builds whose content is otherwise identical, so including it would make every
  bundle look unique and the whole comparison vacuous. Excluding it is what turns "these
  labels disagree" into "these bundles are the same file".

  !! A BUNDLE MATCHING MANY VERSIONS IS THE NORMAL CASE, NOT AN ERROR. The RMS bundle is built
  from KB specs and is identical across every version of a provider (and across providers
  sharing the same flags), so it matches dozens of builds. That is information: it means a
  stale RMS label is HARMLESS. "Matches no build" is the finding to act on.

  !! 0 ARTIFACTS OR 0 TENANT CONFIGS FAILS -- "found nothing" and "never looked" are different
  verdicts (ENGINEERING_STANDARD 4.3), and this tool prints both denominators.

  Usage:
    .\tools\audit_tenant_provenance.ps1                      # tenants present on disk
    .\tools\audit_tenant_provenance.ps1 -Rebuild             # discard and rebuild the index
    .\tools\audit_tenant_provenance.ps1 -Providers AZ_AZDPS,TN_TIES
    .\tools\audit_tenant_provenance.ps1 -OutFile providers\TENANT_PROVENANCE.txt
#>

param(
    [string[]]$Providers,
    [string]$TenantDir,
    [switch]$Rebuild,
    [switch]$IncludeLegacy,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_resolve_version_history.ps1"
. "$PSScriptRoot\_json_canonical.ps1"

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

$tenantDir = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
$cachePath = Join-Path $repoRoot '_versions\bundle_hash_index.json'

# ⚠️ THE BUNDLE-IDENTITY PRIMITIVE MOVED OUT ON 2026-09-11 -- it is now shared, not private.
# audit_tenant.ps1 (the on-demand single-tenant dossier) needs the IDENTICAL hash, and two
# copies of a hash primitive that drift give two different answers to "is this the same
# bundle" with neither obviously wrong. ENGINEERING_STANDARD 4.4.
# The module carries the reasoning for both normalizations that make it correct: the
# description is EXCLUDED (it is the one field guaranteed to differ between otherwise
# identical builds) and PLATFORM-ADDED NULLS are stripped ("conditions":null,"defaults":null
# where our build omits the property -- +324 bytes on one AZ bundle, and the reason both
# current provider bundles on ALL-PASS tenants first read "matches no known build").
. "$PSScriptRoot\_bundle_identity.ps1"

Say ''
Say '===================================================================================='
Say '  TENANT BUNDLE PROVENANCE -- which BUILD is each bundle, by content'
Say '===================================================================================='

# ---------------------------------------------------------------- the index
$cache = @{}
if ((Test-Path $cachePath) -and -not $Rebuild) {
    $raw = Get-Content $cachePath -Raw | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $cache[$p.Name] = $p.Value }
    Say ("  cache: {0} blob(s) already hashed" -f $cache.Count)
} else {
    Say '  cache: building from scratch'
}

# ⚠️ `powershell -File` STRINGIFIES ARRAY ARGUMENTS, so `-Providers AZ_AZDPS,TN_TIES` arrives
# as the SINGLE literal string "AZ_AZDPS,TN_TIES". That is how pipeline.ps1 and enforce.ps1
# invoke every tool, so a comma list must be split here or the filter silently matches nothing.
# It bit on this tool's first run: 0 artifacts, and only the empty-index refusal below stopped
# it reporting all 64 tenants as "content matches no known build" -- a false finding of the
# worst possible shape, since that is the one row this tool says to act on.
$provList = @()
if ($Providers) {
    foreach ($p in @($Providers)) { $provList += @(([string]$p).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
} else {
    # ⚠️ DO NOT WRITE @(Get-ProvidersInHistory). The module returns `,@(...)` -- a deliberate
    # comma-guard so a SINGLE result does not unwrap to a scalar -- and wrapping that in @()
    # again produces a NESTED array. The loop then ran ONCE with $prov bound to the whole list,
    # stringified it into one bogus provider name, and reported "artifacts in history: 0".
    # `$provList.Count` was 1, so the zero-guard below did not fire: the run looked like an
    # empty repo rather than a broken call. A bare assignment unrolls the guard correctly.
    $fromHistory = Get-ProvidersInHistory
    $provList = @($fromHistory)
}
if ($provList.Count -eq 0) {
    Say '  [FAIL] 0 providers found in history -- the enumeration is broken, not the repo.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
# Print the denominator, and refuse a value that is obviously not a provider name. The nested
# array above was invisible precisely because nothing asserted the SHAPE of what it iterated.
$bogus = @($provList | Where-Object { $_ -isnot [string] -or $_ -match '[ ,]' })
if ($bogus.Count -gt 0) {
    Say ("  [FAIL] provider list is malformed ({0} bad entr(y/ies)) -- first: '{1}'" -f $bogus.Count, ([string]$bogus[0]).Substring(0, [Math]::Min(80, ([string]$bogus[0]).Length)))
    Say '         This is an array-shape bug in the caller, not an empty repo.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
Say ("  providers to index: {0}" -f $provList.Count)

$artifacts = 0; $hashedNow = 0
foreach ($prov in $provList) {
    foreach ($e in (Get-Index $prov ([bool]$IncludeLegacy))) {
        if (-not $e.Blob) { continue }
        $artifacts++
        if ($cache.ContainsKey($e.Blob)) { continue }
        $text = $null
        try { $text = Get-BlobText $e.Blob } catch { }
        if (-not $text) { continue }
        $parsed = $null
        try { $parsed = $text | ConvertFrom-Json } catch { continue }
        $entry = [ordered]@{ provider = $prov; version = $e.Version; variant = "$($e.Variant)"
                             date = "$($e.Date)"; bundles = @() }
        foreach ($b in (Get-BundleList $parsed)) {
            $entry.bundles += [ordered]@{ name = "$($b.name)"; hash = (Get-BundleContentHash $b)
                                          description = "$($b.description)" }
        }
        $cache[$e.Blob] = [pscustomobject]$entry
        $hashedNow++
        if ($hashedNow % 25 -eq 0) { Say ("    ... hashed {0} new artifact(s)" -f $hashedNow) }
    }
}
Say ("  artifacts in history: {0}   newly hashed this run: {1}   cache total: {2}" -f $artifacts, $hashedNow, $cache.Count)

if ($cache.Count -eq 0) {
    Say '  [FAIL] index is EMPTY -- nothing to match against. Refusing to report tenants as unmatched.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
($cache | ConvertTo-Json -Depth 8) | Set-Content -Path $cachePath -Encoding UTF8

# invert: bundle hash -> list of "PROVIDER vX.Y"
$byHash = @{}
foreach ($k in $cache.Keys) {
    $a = $cache[$k]
    foreach ($b in @($a.bundles)) {
        $tag = "$($a.provider) v$($a.version)"
        if (-not $byHash.ContainsKey($b.hash)) { $byHash[$b.hash] = New-Object 'System.Collections.Generic.HashSet[string]' }
        [void]$byHash[$b.hash].Add($tag)
    }
}
Say ("  distinct bundle contents across all builds: {0}" -f $byHash.Count)

# ---------------------------------------------------------------- the tenants
$tfiles = @(Get-ChildItem $tenantDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch 'provenance' })
Say ("  tenant configs: {0}" -f $tfiles.Count)
if ($tfiles.Count -eq 0) {
    Say '  [FAIL] no tenant configs. Run ingest_tenant_configs.ps1 first.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

Say ''
Say '  ---- PER TENANT, PER BUNDLE: what the LABEL says vs what the CONTENT is -----------'
$unmatched = @(); $labelWrong = @(); $notIndexedRows = @(); $script:skipped = 0
foreach ($f in ($tfiles | Sort-Object Name)) {
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    $bl = Get-BundleList $o
    if ($bl.Count -eq 0) { continue }

    # ⚠️ OUT OF SCOPE IS NOT UNACCOUNTED FOR. When -Providers narrows the index, a tenant
    # running some OTHER provider has nothing to match against -- and the first run printed
    # those as "CONTENT MATCHES NO KNOWN BUILD", which is the single row this tool tells you to
    # act on. Reporting an unexamined tenant as a finding is the same conflation the census
    # tools refuse (unresolved is not empty). Skip them, and COUNT what was skipped.
    if ($Providers) {
        $tprov = @($bl | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' } |
                  ForEach-Object { "$($_.name)" })
        $inScope = $false
        foreach ($tp in $tprov) { if ($provList -contains $tp) { $inScope = $true } }
        if (-not $inScope) { $script:skipped++; continue }
    }

    Say ''
    Say ("  {0}" -f ($f.BaseName))
    foreach ($b in $bl) {
        $h = Get-BundleContentHash $b
        # ⚠️ NOT `$matches`. That is a PowerShell AUTOMATIC VARIABLE holding regex captures, and
        # the `-match` two lines below silently overwrote my match list with the capture
        # hashtable -- so every row printed "content = System.Collections.Hashtable" and every
        # label read as NOT-AMONG-THE-MATCHES. Same collision class as `$A` destroying `$a`
        # (PowerShell is case-insensitive), and both were caught only by output that looked
        # obviously wrong rather than subtly wrong. Reserved-name collisions fail loudly here;
        # they will not always.
        $hits = @()
        if ($byHash.ContainsKey($h)) { $hits = @($byHash[$h]) }
        $lbl = ''
        if ("$($b.description)" -match 'Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)') {
            $lbl = $Matches[1] + ' v' + $Matches[2]
        }
        $lblTxt = if ($lbl) { $lbl } else { '(not stamped)' }

        if ($hits.Count -eq 0) {
            # ⚠️ "matches no build" and "we never indexed that provider" are DIFFERENT verdicts
            # and printed identically at first. usx-la-lems reported LA_LETTS_OFML v2.0 as
            # unmatched -- but that provider only ever existed in the PRE-VERSIONED era, so
            # Get-ProvidersInHistory (which globs providers/*/*_v*.json) never included it and
            # the index had nothing to match against. It resolved perfectly under
            # -Providers LA_LETTS_OFML -IncludeLegacy. Reporting an un-indexed provider as
            # "deployed and unaccounted for" is the same conflation the census tools refuse.
            $bn = "$($b.name)"
            $notIndexed = ($bn -ne 'ENTITIES' -and $bn -ne 'RMS' -and $provList -notcontains $bn)
            if ($notIndexed) {
                Say ("     {0,-20} label {1,-26} PROVIDER NOT INDEXED -- try -Providers {2} -IncludeLegacy" -f $bn, $lblTxt, $bn)
                $notIndexedRows += [pscustomobject]@{ Tenant = $f.BaseName; Bundle = $bn; Label = $lblTxt }
            } else {
                Say ("     {0,-20} label {1,-26} CONTENT MATCHES NO KNOWN BUILD" -f $bn, $lblTxt)
                $unmatched += [pscustomobject]@{ Tenant = $f.BaseName; Bundle = $bn; Label = $lblTxt }
            }
        } else {
            $sorted = @($hits | Sort-Object)
            $show = if ($sorted.Count -le 3) { $sorted -join ', ' } else { ($sorted[0..2] -join ', ') + (' (+{0} more)' -f ($sorted.Count - 3)) }
            $flag = ''
            if ($lbl -and ($sorted -notcontains $lbl)) {
                $flag = '   <== LABEL NOT AMONG THE MATCHES'
                $labelWrong += [pscustomobject]@{ Tenant = $f.BaseName; Bundle = "$($b.name)"; Label = $lbl; Content = $show }
            }
            Say ("     {0,-20} label {1,-26} content = {2}{3}" -f $b.name, $lblTxt, $show, $flag)
        }
    }
}

Say ''
Say '  ---- WHAT TO ACT ON ---------------------------------------------------------------'
if ($Providers) { Say ("  tenants SKIPPED as out of the -Providers scope (NOT examined, not clean): {0}" -f $script:skipped) }
Say ("  bundles whose PROVIDER WAS NEVER INDEXED (unexamined, NOT a finding): {0}" -f $notIndexedRows.Count)
foreach ($ni in $notIndexedRows) { Say ("     {0,-30} {1,-18} label {2}" -f $ni.Tenant, $ni.Bundle, $ni.Label) }
Say ("  bundles whose CONTENT matches no build in history: {0}" -f $unmatched.Count)
foreach ($u in $unmatched) { Say ("     {0,-30} {1,-18} label {2}" -f $u.Tenant, $u.Bundle, $u.Label) }
Say ("  bundles whose LABEL names a build its content is NOT: {0}" -f $labelWrong.Count)
foreach ($w in $labelWrong) { Say ("     {0,-30} {1,-18} label {2} -> really {3}" -f $w.Tenant, $w.Bundle, $w.Label, $w.Content) }
Say ''
Say '  A bundle matching MANY builds is normal and is itself the answer: the RMS bundle is'
Say '  built from KB specs and is identical across versions, so a stale RMS label is HARMLESS.'
Say '  "Matches no known build" is the row that means something is deployed we cannot account for.'
Say '===================================================================================='
Say ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
