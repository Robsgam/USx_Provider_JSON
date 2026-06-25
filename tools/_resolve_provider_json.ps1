# ─────────────────────────────────────────────────────────────────────────────
#  _resolve_provider_json.ps1 -- shared active-JSON resolver
#
#  Single source of truth for locating a provider's active root JSON. The root
#  JSON name carries the version (<PROVIDER>_v<X.Y>.json). Tools must resolve via
#  this helper instead of hardcoding "<PROVIDER>.json", so a versioned filename is
#  found everywhere. enforce.ps1, block_entity.ps1 and build_report.ps1 carry
#  their own equivalent fallbacks (kept as-is); every other discovery site should
#  dot-source this file and call Get-ProviderRootJson.
#
#  Resolution order (first hit wins):
#    1. <PROVIDER>.json            (legacy bare name, still valid)
#    2. <PROVIDER>_v<X.Y>.json     (versioned -- current standard)
#    3. *_MC.json                  (legacy multi-card)
#    4. *_BASE.json                (legacy base)
#
#  Returns the full path as a string, or $null when no JSON is present.
# ─────────────────────────────────────────────────────────────────────────────

function Get-ProviderRootJson {
    param(
        [Parameter(Mandatory)][string]$ProvDir,
        [Parameter(Mandatory)][string]$Provider
    )

    if (-not (Test-Path $ProvDir)) { return $null }

    # 1. bare name
    $bare = Join-Path $ProvDir "$Provider.json"
    if (Test-Path $bare) { return $bare }

    # 2. versioned <PROVIDER>_v<X.Y>.json -- prefer the highest version if (against
    #    the one-JSON-in-root rule) more than one is present.
    $ver = @(Get-ChildItem $ProvDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^$([regex]::Escape($Provider))_v[\d.]+\.json$" })
    if ($ver.Count -ge 1) {
        $best = $ver | Sort-Object {
            if ($_.Name -match '_v([\d.]+)\.json$') { [version]($Matches[1]) } else { [version]'0.0' }
        } | Select-Object -Last 1
        return $best.FullName
    }

    # 3. legacy _MC
    $mc = Get-ChildItem $ProvDir -Filter "*_MC.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mc) { return $mc.FullName }

    # 4. legacy _BASE
    $base = Get-ChildItem $ProvDir -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($base) { return $base.FullName }

    return $null
}
