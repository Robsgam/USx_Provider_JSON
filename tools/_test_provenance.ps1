# ─────────────────────────────────────────────────────────────────────────────
#  _test_provenance.ps1 -- shared test-log provenance + tier helpers
#
#  Single source of truth for: which JSON version + entity fingerprint a test log
#  was run against, the provider's active test tier, and whether a log validly
#  backs a [CONFIRMED] combo. post_test.ps1 stamps logs; audit_test_coverage.ps1,
#  block_entity.ps1 and backfill_log_stamps.ps1 read them through these functions
#  so the provenance rules cannot drift between writer and readers.
#
#  PROVENANCE RULE (the fix for silent test-package drift): a log validly backs a
#  combo only when its stamped "JSON Version" == the current build version AND its
#  stamped "Entity Fingerprint" == the entity's current fingerprint AND (for non
#  render/negative tests) it carries real XML. A log with no stamp, or a stamp from
#  a prior build, does NOT count -- so a [CONFIRMED] marker can never rest on a
#  stale or hand-edited log again.
#
#  Dot-source this file; it defines functions only (no side effects).
# ─────────────────────────────────────────────────────────────────────────────

# Stamp markers written into every test log header by post_test.ps1.
$script:TP_VersionLabel = "JSON Version"
$script:TP_FingerprintLabel = "Entity Fingerprint"
$script:TP_TierLabel = "Tier"

# Read the build-script version ($Version = "X.Y"). Mirrors the (now-removed) local
# copy in audit_test_coverage.ps1 and reset_test_package.ps1: prefer the canonical
# mainline build_<provider>.ps1, then any non-_mc/_old build_* script.
function Get-BuildVersionForProvider {
    param([Parameter(Mandatory)][string]$ProvDir)
    $provName = Split-Path $ProvDir -Leaf
    $scriptsDir = Join-Path $ProvDir "scripts"
    if (Test-Path $scriptsDir) {
        $canonical = Join-Path $scriptsDir ("build_" + $provName.ToLower() + ".ps1")
        $script = $null
        if (Test-Path $canonical) {
            $script = Get-Item $canonical
        } else {
            $script = Get-ChildItem $scriptsDir -Filter "build_*" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch '_mc' -and $_.Name -notmatch '_old' } | Select-Object -First 1
            if (-not $script) {
                $script = Get-ChildItem $scriptsDir -Filter "build_*_mc*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
            }
        }
        if ($script) {
            $text = [System.IO.File]::ReadAllText($script.FullName)
            if ($text -match '\$Version\s*=\s*["'']([0-9]+\.[0-9]+(?:-[A-Za-z]+)?)["'']') { return $Matches[1] }
        }
    }

    # FALLBACK: THE ACTIVE JSON FILENAME. Added 2026-09-02.
    # A provider whose JSON is a CAPTURED ARTIFACT rather than a generated one has NO build script,
    # so every path above returns $null and post_test.ps1 stamps the literal string "unknown" into
    # the log header AND the filename -- producing CA_eSUN_vunknown_<combo>.txt. That is not a
    # cosmetic blemish: every log gate and report_sweep_ledger globs "<PROVIDER>_v<version>_*", so
    # 25 real captures with real wire XML counted for exactly NOTHING and the tool still printed
    # "Imported: 25 PASS". A success message with no usable artifact.
    # Found on CA_eSUN v1.0 (the hand-built San Diego Sheriff baseline) 2026-09-02.
    # The filename is the repo's PRIMARY version carrier by policy -- CLAUDE.md Versioning Policy:
    # "the version lives (a) in the filename and (b) inside the bundle description" -- so reading it
    # here is the documented source, not a guess. reset_test_package.ps1 already falls back to the
    # bundle description for the same reason; this makes the shared resolver agree with it.
    # STRICTLY A FALLBACK: it is reached ONLY when the build-script path yields nothing, which is
    # true for exactly one provider today, so no generated provider's stamp can change.
    try {
        $resolver = Join-Path $PSScriptRoot '_resolve_provider_json.ps1'
        if (Test-Path $resolver) {
            . $resolver
            $activeJson = Get-ProviderRootJson -ProvDir $ProvDir -Provider $provName
            if ($activeJson) {
                $leaf = [System.IO.Path]::GetFileNameWithoutExtension($activeJson)
                if ($leaf -match '_v([0-9]+\.[0-9]+(?:-[A-Za-z]+)?)$') { return $Matches[1] }
                # Second fallback: the bundle description, the policy's other carrier.
                $jt = [System.IO.File]::ReadAllText($activeJson)
                if ($jt -match [regex]::Escape($provName) + ' v([0-9]+\.[0-9]+(?:-[A-Za-z]+)?)') { return $Matches[1] }
            }
        }
    } catch { }
    return $null
}

# Tiers were removed 2026-07-01 -- testing is a single all-or-nothing "Full" pass
# (the former "Final": render + every combo + per-field any[] + all-any + guardrails +
# deselect + negative). There is no longer a "Preliminary" subset. This function is kept
# for callers but always returns 'Full'; the tier stamp is informational only (log
# validity = version + fingerprint + XML, never the tier label).
function Get-ActiveTier {
    param([Parameter(Mandatory)][string]$ProvDir)
    return 'Full'
}

# Parse the stamp block from a log file. Returns @{ Version=...; Fingerprint=...; Tier=... }
# with $null fields when the log predates stamping (unstamped legacy log).
function Get-LogStamp {
    param([Parameter(Mandatory)][string]$LogFullPath)
    $text = [System.IO.File]::ReadAllText($LogFullPath)
    $ver = $null; $fp = $null; $tier = $null
    if ($text -match "(?im)^\s*$([regex]::Escape($script:TP_VersionLabel))\s*:\s*v?([0-9]+\.[0-9]+(?:-[A-Za-z]+)?)\s*$") { $ver = $Matches[1] }
    if ($text -match "(?im)^\s*$([regex]::Escape($script:TP_FingerprintLabel))\s*:\s*([0-9a-fA-F]{8,})\s*$") { $fp = $Matches[1].ToLower() }
    if ($text -match "(?im)^\s*$([regex]::Escape($script:TP_TierLabel))\s*:\s*(\w+)\s*$") { $tier = $Matches[1] }
    return @{ Version = $ver; Fingerprint = $fp; Tier = $tier }
}

# A negative/empty-form or render test log carries no XML by design.
function Test-IsNonXmlLog {
    param([Parameter(Mandatory)][string]$LogName)
    return ($LogName -match '(?i)(negative|render)')
}

# A log "has XML" when it contains a real angle-bracket element and is not still a stub.
function Test-LogHasXmlContent {
    param([Parameter(Mandatory)][string]$LogFullPath)
    $text = [System.IO.File]::ReadAllText($LogFullPath)
    if ($text -match '\[PASTE RAW XML HERE\]') { return $false }
    if ($text -match '<\?xml' -or $text -match '<[A-Za-z][\w:.-]*>') { return $true }
    return $false
}

# The core provenance test. A log validly backs work for $EntityFp at $BuildVer when:
#   - its stamped version == $BuildVer, AND
#   - its stamped fingerprint == $EntityFp, AND
#   - it carries XML (skipped for render/negative logs, which have none by design).
# Returns a result object so callers can report the precise failure reason.
function Test-LogProvenance {
    param(
        [Parameter(Mandatory)][string]$LogFullPath,
        [Parameter(Mandatory)][AllowNull()][string]$BuildVer,
        [Parameter(Mandatory)][AllowNull()][string]$EntityFp
    )
    $name  = Split-Path $LogFullPath -Leaf
    $stamp = Get-LogStamp $LogFullPath
    $reasons = @()

    if (-not $stamp.Version) { $reasons += "unstamped (no '$($script:TP_VersionLabel)') -- predates provenance stamping" }
    elseif ($BuildVer -and ($stamp.Version -ne $BuildVer)) { $reasons += "stale version (log v$($stamp.Version) != build v$BuildVer)" }

    if (-not $stamp.Fingerprint) { $reasons += "unstamped (no '$($script:TP_FingerprintLabel)')" }
    elseif ($EntityFp -and ($stamp.Fingerprint -ne $EntityFp.ToLower())) { $reasons += "fingerprint mismatch (entity structure changed since the log)" }

    $hasXml = $true
    if (-not (Test-IsNonXmlLog $name)) {
        $hasXml = Test-LogHasXmlContent $LogFullPath
        if (-not $hasXml) { $reasons += "no XML evidence" }
    }

    return [PSCustomObject]@{
        Name        = $name
        Version     = $stamp.Version
        Fingerprint = $stamp.Fingerprint
        Tier        = $stamp.Tier
        HasXml      = $hasXml
        Valid       = ($reasons.Count -eq 0)
        Reasons     = $reasons
    }
}
