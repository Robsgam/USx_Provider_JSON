# =====================================================================
# get_entity_fingerprints.ps1
# Deterministic per-entity fingerprint of behavior-relevant structure.
#
# For each targetEntity, hashes (SHA256) a canonical, key-sorted
# serialization of:
#   - the entity's QIF layout (all 3 variants) + targetEntity
#   - every QIDM (PROVIDER + RMS bundles) with that targetEntity:
#       query, name, autoSelect, queriesToDeselect, combinations, attributes
# Volatile data (version strings, dates, top-level description) is excluded.
#
# Dot-source to get the Get-EntityFingerprints function, or run directly:
#   .\get_entity_fingerprints.ps1 -Path <json> [-OutFile <json>]
# Direct run prints a JSON object { "<entity>": "<hex>", ... } to stdout.
# =====================================================================
param(
    [string]$Path,
    [string]$OutFile
)

# Canonical serialization + hashing now live in the shared module so this tool
# and audit_reproducible.ps1 cannot drift (ConvertTo-Canonical, Get-Sha256Hex).
. (Join-Path $PSScriptRoot '_json_canonical.ps1')

function Get-EntityFingerprints {
    param([Parameter(Mandatory)][string]$Path)

    $json = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $bundles = $json.bundles

    # Collect per-entity canonical fragments.
    $byEntity = @{}
    foreach ($b in $bundles) {
        foreach ($cfg in $b.configurations) {
            $ent = $cfg.targetEntity
            if (-not $ent) { continue }
            $frag = $null
            switch ($cfg.type) {
                'QUERYINPUTFORM' {
                    # Layout drives RENDER behavior; exclude description.
                    $shape = [ordered]@{ kind = 'QIF'; targetEntity = $ent; layout = $cfg.layout }
                    $frag = 'QIF:' + (ConvertTo-Canonical ([pscustomobject]$shape))
                }
                'QUERYINPUTDATAMAPPING' {
                    $shape = [ordered]@{
                        kind              = 'QIDM'
                        query             = $cfg.query
                        name              = $cfg.name
                        autoSelect        = $cfg.autoSelect
                        queriesToDeselect = $cfg.queriesToDeselect
                        combinations      = $cfg.combinations
                        attributes        = $cfg.attributes
                    }
                    $frag = 'QIDM:' + (ConvertTo-Canonical ([pscustomobject]$shape))
                }
            }
            if ($frag) {
                if (-not $byEntity.ContainsKey($ent)) { $byEntity[$ent] = [System.Collections.Generic.List[string]]::new() }
                $byEntity[$ent].Add($frag)
            }
        }
    }

    $result = [ordered]@{}
    foreach ($ent in ($byEntity.Keys | Sort-Object)) {
        # Sort fragments so QIF/QIDM ordering across bundles is irrelevant.
        $canon = ($byEntity[$ent] | Sort-Object) -join '|'
        $result[$ent] = Get-Sha256Hex $canon
    }
    return $result
}

# Direct invocation
if ($Path) {
    $fp = Get-EntityFingerprints -Path $Path
    $jsonOut = ([pscustomobject]$fp | ConvertTo-Json)
    if ($OutFile) {
        [System.IO.File]::WriteAllText($OutFile, $jsonOut, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Wrote fingerprints -> $OutFile"
    } else {
        Write-Output $jsonOut
    }
}
