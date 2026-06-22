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

# Canonical, deterministic serialization: object keys are sorted, arrays
# keep order. Produces a stable string so the hash only changes when
# meaningful structure changes.
function ConvertTo-Canonical {
    param($o)
    if ($null -eq $o) { return 'null' }
    if ($o -is [bool]) { return $o.ToString().ToLowerInvariant() }
    if ($o -is [string]) { return '"' + ($o -replace '\\','\\\\' -replace '"','\"') + '"' }
    if ($o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) { return [string]$o }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) {
        $items = @($o | ForEach-Object { ConvertTo-Canonical $_ })
        return '[' + ($items -join ',') + ']'
    }
    if ($o -is [System.Management.Automation.PSCustomObject] -or $o.PSObject.Properties.Count -gt 0) {
        $props = @($o.PSObject.Properties | Sort-Object Name)
        $parts = foreach ($p in $props) { '"' + $p.Name + '":' + (ConvertTo-Canonical $p.Value) }
        return '{' + ($parts -join ',') + '}'
    }
    return '"' + [string]$o + '"'
}

function Get-Sha256Hex {
    param([string]$s)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
        return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    } finally { $sha.Dispose() }
}

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
