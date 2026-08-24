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

    # ---- CHECK 2: ADJUDICATION-REGISTRY DRIFT (added 2026-08-24) ----------------------------
    # WHY THIS EXISTS. CHECK 1 above compares the `# BASE-SYNC` VERSION MARKER and nothing else,
    # so it answers "was the base-6 re-synced?" and never "did the base's REASONING come with it?".
    # On 2026-08-24 TX_TLETS_CCH read [PASS] here -- marker current at v4.21 -- while carrying a
    # stale SUBSET of TX_TLETS's ACCEPTED_DIVERGENCES: EIGHT base rows absent, FOUR of them
    # producing live audit_requirement_fidelity OVER-PERMITTED findings that the base had closed
    # on 2026-07-30. Same metadata XML (byte-identical), same devdoc, same combinations, opposite
    # verdicts -- and the marker being CURRENT is exactly what made it invisible. Lockstep on the
    # build script, drift in the registry.
    #
    # SCOPED BY BUILT QUERY: only base rows whose QUERY the variant actually builds are in scope.
    # A base row for a query the variant does not build is not drift.
    #
    # NOT-INHERITING CAN BE THE RIGHT ANSWER, so a recorded decision reports [NOTE], not [FAIL].
    # Copying a base row is NOT always safe: an EXISTENCE-class rule (shadow / unbuilt / dead-combo)
    # makes audit_requirement_fidelity skip that keyRef's ENTIRE comparison, so inheriting one can
    # DROP branches from the denominator while the finding count still reads 0 -- indistinguishable
    # from a clean run. Three TX_TLETS rows are deliberately not inherited for exactly that reason
    # (two name BUILT keyRefs; RSDWW was measured at 36 -> 35 branches). Record the decision in a
    # COMMENT in the variant's own registry naming the keyRef and the field, and this reports it as
    # a considered choice instead of re-raising it every run.
    $baseReg = Join-Path $baseDir  ("docs\tracking\" + $base + "_ACCEPTED_DIVERGENCES.txt")
    $varReg  = Join-Path $pd.FullName ("docs\tracking\" + $name + "_ACCEPTED_DIVERGENCES.txt")
    if (-not ((Test-Path $baseReg) -and (Test-Path $varReg))) {
        Emit ("         [NOTE] CHECK 2 DID NOT RUN -- accepted-divergence registry missing for $name or $base.")
        Emit ("                A check that cannot tell 'no drift' from 'nothing compared' is not a check.")
    } else {
        $parseReg = {
            param($f)
            $h = @{}
            foreach ($ln in (Get-Content $f)) {
                if ($ln -match '^\s*($|#)') { continue }
                $p = $ln -split '\|'
                if ($p.Count -lt 4) { continue }
                $h[(($p[0].Trim()) + '|' + ($p[1].Trim()) + '|' + ($p[2].Trim()) + '|' + ($p[3].Trim()))] = $true
            }
            return $h
        }
        $bk = & $parseReg $baseReg
        $vk = & $parseReg $varReg
        $varComments = (((Get-Content $varReg) | Where-Object { $_ -match '^\s*#' }) -join "`n")

        # queries the VARIANT actually builds -- a base row for an unbuilt query is not drift
        $varQueries = @{}
        $varJson = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $name
        if ($varJson -and (Test-Path $varJson)) {
            $vj = Get-Content $varJson -Raw | ConvertFrom-Json
            foreach ($b in @($vj.bundles)) {
                foreach ($c in @($b.configurations)) {
                    if (("$($c.type)" -eq 'QUERYINPUTDATAMAPPING') -and $c.query) { $varQueries["$($c.query)"] = $true }
                }
            }
        }

        $inScope = 0; $inherited = 0; $recorded = 0; $missing = @()
        foreach ($k in $bk.Keys) {
            $p = $k -split '\|'
            if ($varQueries.Count -gt 0 -and -not $varQueries.ContainsKey($p[0])) { continue }
            $inScope++
            if ($vk.ContainsKey($k)) { $inherited++; continue }
            $kr = [regex]::Escape($p[1]); $fld = [regex]::Escape($p[2])
            if (($varComments -match $kr) -and ($varComments -match $fld)) { $recorded++ }
            else { $missing += $k }
        }

        if ($inScope -eq 0) {
            Emit ("         [NOTE] CHECK 2 compared ZERO base rows for $name -- no base row targets a query")
            Emit ("                this variant builds. Verify that is true before reading it as clean.")
        } else {
            Emit ("         CHECK 2 registry: $inScope base row(s) in scope / $inherited inherited / $recorded recorded-not-inherited / $($missing.Count) DRIFTED")
            foreach ($m in ($missing | Sort-Object)) {
                $p = $m -split '\|'
                Emit ("         [FAIL] $name -- base adjudication NOT inherited: $($p[0]) | $($p[1]) | $($p[2]) | $($p[3])")
                $fail++
            }
            if ($missing.Count -gt 0) {
                Emit ("                Copy the row VERBATIM (reason + original date) if it applies, or record a")
                Emit ("                comment in the variant registry naming the keyRef and field saying why not.")
                Emit ("                MEASURE branches-compared before and after: an existence-class rule can lower")
                Emit ("                the denominator while the finding count still reads 0.")
            }
        }
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
