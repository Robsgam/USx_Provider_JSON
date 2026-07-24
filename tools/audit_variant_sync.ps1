# ─────────────────────────────────────────────────────────────────────────────
#  audit_variant_sync.ps1 -- base<->variant lockstep drift check
#
#  A VARIANT provider (`<BASE>_<VARIANT>`, e.g. TX_TLETS_CCH) shares/derives its base-6
#  QIDMs from its BASE provider (see CLAUDE.md "Provider Variants (CCH / supported-stuff)").
#  A base change must propagate to the variant -- but the two are separate build scripts with
#  NO auto-propagation, so a variant can silently drift behind its base (TX_TLETS_CCH drifted
#  ~4 versions behind TX_TLETS before this check existed).
#
#  This check: for every provider whose name strips (on '_') to a sibling BASE provider dir,
#  read the variant's `# BASE-SYNC: <BASE> v<X.Y>` marker (the base version it was last synced
#  to) and compare it to the BASE provider's CURRENT version. Flags drift.
#
#  Marker convention (put near the top of the variant's build script):
#     # BASE-SYNC: TX_TLETS v4.7
#
#  Usage: tools/audit_variant_sync.ps1 [-Path providers] [-OutFile <path>]
#  Exit 0 = no drift; 1 = drift or missing marker (advisory -- compose into doctor.ps1).
# ─────────────────────────────────────────────────────────────────────────────
[CmdletBinding()]
param(
    [string]$Path,
    [string]$OutFile
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Path) { $Path = Join-Path $repoRoot "providers" }
. (Join-Path $PSScriptRoot "_resolve_provider_json.ps1")

$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$s){ $lines.Add($s) | Out-Null }

# current version of a provider: prefer its versioned root JSON filename, else bundle description
function Get-ProviderVersion($provDir, $name) {
    $j = Get-ProviderRootJson -ProvDir $provDir -Provider $name
    if ($j -and ([IO.Path]::GetFileName($j)) -match '_v([\d.]+)\.json$') { return $Matches[1] }
    if ($j -and (Test-Path $j)) {
        $raw = Get-Content $j -Raw
        if ($raw -match 'configuration for [^"]*?\bv([\d]+\.[\d]+)') { return $Matches[1] }
    }
    return $null
}

$provDirs = Get-ChildItem $Path -Directory | Sort-Object Name
$names = $provDirs.Name
$fail = 0; $variantCount = 0

Emit ("=" * 74)
Emit "  BASE<->VARIANT SYNC AUDIT"
Emit ("=" * 74)

# Detection is MARKER-DRIVEN (not name-heuristic): a provider is a variant IFF its build script
# declares `# BASE-SYNC: <BASE> vX.Y`. This avoids false positives -- CA_CLETS_OCATS strips to
# CA_CLETS by name but is an INDEPENDENT provider (own metadata), and CA_CONTRA_COSTA is a
# CA_CLETS copy that the name convention wouldn't catch. Declaring the marker is the opt-in;
# when you build a real variant (CCH etc.), add the marker (see CLAUDE.md "Provider Variants").
foreach ($pd in $provDirs) {
    $name = $pd.Name
    $script = Get-ChildItem (Join-Path $pd.FullName "scripts") -Filter "build_*.ps1" -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -notmatch '_(mc|base)\.ps1$' } | Select-Object -First 1
    if (-not $script) { continue }
    $txt = Get-Content $script.FullName -Raw
    if ($txt -notmatch "(?im)^\s*#\s*BASE-SYNC:\s*(\S+)\s*v([\d.]+)") { continue }   # not a declared variant
    $base   = $Matches[1]
    $synced = $Matches[2]
    $variantCount++

    $baseDir = ($provDirs | Where-Object { $_.Name -eq $base }).FullName
    if (-not $baseDir) {
        Emit ("  [FAIL] $name -- BASE-SYNC names base '$base' but no such provider directory exists")
        $fail++; continue
    }
    $baseVer = Get-ProviderVersion $baseDir $base
    if ($synced -ne $baseVer) {
        Emit ("  [FAIL] $name -- synced to $base v$synced but $base is now v$baseVer -- base-6 may be STALE; re-sync + bump the BASE-SYNC marker")
        $fail++
    } else {
        Emit ("  [PASS] $name -- base-6 in lockstep with $base v$baseVer")
    }
}

Emit ("-" * 74)
if ($variantCount -eq 0) { Emit "  No variant providers found (no <BASE>_<VARIANT> with a sibling base)." }
Emit ("  Variants: $variantCount   Drift/missing-marker: $fail")
Emit ("=" * 74)

$out = $lines -join "`n"
Write-Output $out
if ($OutFile) { $out | Out-File -FilePath $OutFile -Encoding utf8 }
if ($fail -gt 0) { exit 1 } else { exit 0 }
