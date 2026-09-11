<#
  _bundle_identity.ps1 -- SHARED: what IS this bundle, independent of what it calls itself.

  WHY THIS IS A MODULE. These three functions were private to audit_tenant_provenance.ps1 and
  on 2026-09-11 a second consumer appeared (audit_tenant.ps1, the on-demand single-tenant
  dossier). ENGINEERING_STANDARD 4.4 -- NEVER RE-IMPLEMENT AN EXISTING PARSER. Copying a hash
  primitive is worse than copying most code: two copies that drift produce two different
  answers to "is this the same bundle", and neither is obviously wrong.

  THE TWO NORMALIZATIONS ARE NOT OPTIONAL, AND BOTH WERE PAID FOR:

  1. THE DESCRIPTION IS EXCLUDED. It is the one field guaranteed to differ between two builds
     whose content is otherwise identical (it carries "... vX.Y"), so including it makes every
     bundle unique and the whole comparison vacuous. Excluding it is exactly what turns
     "these labels disagree" into "these bundles are the same file" -- the finding that proved
     usx-az-azdps's RMS bundle, labelled v3.4, is byte-identical to v3.12's and therefore
     harmless, and that usx-tn-ties carries AZ's LABEL with TN's own correct CONTENT (which I
     nearly filed as cross-provider contamination).

  2. PLATFORM-ADDED NULLS ARE STRIPPED. The platform's serializer emits properties our build
     omits entirely:
         REPO    "requirements":{"any":["dexStateUserId"],"set":["ORI","Mnemonic"]}
         TENANT  "requirements":{"any":[...],"conditions":null,"defaults":null,"set":[...]}
     Same meaning, +324 bytes on a single AZ bundle. Before this, BOTH current provider bundles
     on ALL-PASS tenants reported "matches no known build" -- implausible on its face, which is
     what forced the investigation. ENTITIES and RMS matched, so the difference is not uniform
     and could not have been guessed from one comparison.
     `null` and `absent` mean the same thing here: validate.ps1 requires `conditions` to be an
     ARRAY when present, so a null IS the platform's spelling of absent.

  ⚠️ THIS IS ALSO THE REASON AN IMPORT CANNOT BE VERIFIED BY A BYTE COMPARE. Rob's goal is
  "import, then export, then compare the 2 to confirm the json update takes place"; the compare
  has to run through these normalizations or it will report a difference on every successful
  import. Any future import-verify step MUST use this module rather than its own comparison.

  EXPORTS
    Remove-NullProperties   <obj>              recursive null strip, properties sorted
    Get-BundleList          <parsed>           bundles[] from EITHER a tenant export
                                               (.departmentBundle.bundles) or a repo JSON (.bundles)
    Get-BundleContentHash   <bundle>           canonical SHA-256, description excluded,
                                               platform nulls normalized
  Requires _json_canonical.ps1 to be dot-sourced by the caller (ConvertTo-Canonical / Get-Sha256Hex).
#>

function Remove-NullProperties($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [string] -or $o -is [bool] -or $o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) { return $o }
    if ($o -is [System.Collections.IEnumerable]) {
        $out = @()
        foreach ($i in $o) { $out += ,(Remove-NullProperties $i) }
        return ,$out
    }
    if ($o.PSObject.Properties.Count -gt 0) {
        $h = [ordered]@{}
        foreach ($p in ($o.PSObject.Properties | Sort-Object Name)) {
            if ($null -eq $p.Value) { continue }          # platform-added null == our omission
            $h[$p.Name] = Remove-NullProperties $p.Value
        }
        return [pscustomobject]$h
    }
    return $o
}

function Get-BundleList($parsed) {
    if ($parsed.departmentBundle) { return @($parsed.departmentBundle.bundles) }   # tenant export
    return @($parsed.bundles)                                                       # repo JSON
}

function Get-BundleContentHash($bundle) {
    $c = $bundle | ConvertTo-Json -Depth 60 | ConvertFrom-Json
    $c.PSObject.Properties.Remove('description')
    return (Get-Sha256Hex (ConvertTo-Canonical (Remove-NullProperties $c)))
}

# Read our version out of a bundle description, or $null when it is not stamped.
# ⚠️ ABSENCE IS EVIDENCE, NOT A GAP. Every build we produce carries
# "Provider configuration for <P> vX.Y"; a bundle with no such string is a config we did not
# build. That is how Lafayette was confirmed as the hand-built engineering JSON, and it is why
# this returns $null rather than guessing.
function Get-BundleLabelVersion($bundle) {
    if ("$($bundle.description)" -match 'Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)') {
        return [pscustomobject]@{ Provider = $Matches[1]; Version = $Matches[2]; Tag = ($Matches[1] + ' v' + $Matches[2]) }
    }
    return $null
}
