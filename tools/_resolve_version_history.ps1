<#
  _resolve_version_history.ps1 -- SHARED: enumerate every provider JSON that has ever existed
  in git history, with the blob that still holds it.

  WHY THIS IS A MODULE. It was the private enumeration inside get_provider_version.ps1, and on
  2026-09-11 a second consumer appeared: audit_tenant_provenance.ps1, which identifies a
  TENANT's bundles by CONTENT against every historical build. Rob's steer: "that should be part
  of the ability to generate any version of the json like we worked on earlier."

  ENGINEERING_STANDARD 4.4 -- NEVER RE-IMPLEMENT AN EXISTING PARSER. Five parsers were written
  wrong in one session by re-deriving something that already existed, and this enumeration in
  particular encodes a mistake that is very easy to repeat (see the diff-filter note below).
  So it moved here VERBATIM rather than being written a second time.

  ⚠️ `--diff-filter=A` UNDER-REPORTS BADLY and must never be used here. A version swap
  (delete v4.15 + write v4.16 in ONE commit) is recorded by git as a RENAME, so filtering on
  additions found 40 versions portfolio-wide when the true figure is 257 -- and reported
  HI_HCJDC_OFML as having 2 when it has 18. Enumerate every path that ever appeared instead.

  ⚠️ THE NEWEST COMMIT TOUCHING A PATH IS OFTEN ITS DELETION, where the blob no longer
  resolves. Resolve-Blob walks newest-first and takes the first commit whose tree still
  CONTAINS the path.

  EXPORTS
    Get-VersionPaths     <provider>            -> versioned-era paths + version
    Resolve-Blob         <path>                -> newest commit whose tree holds it, + blob sha
    Get-LegacyEntries    <provider>            -> pre-versioned era (<P>.json / _MC / _BASE),
                                                  version read from the bundle description,
                                                  DEDUPED BY BLOB not by version
    Get-Index            <provider> <bool>     -> unified index, optionally including legacy
    Get-ProvidersInHistory                     -> every provider that ever had a versioned JSON

  Repo root is derived from THIS file's location (tools/ -> parent), so a consumer does not
  have to thread it through and cannot pass a wrong one.
#>

$script:VH_Repo = Split-Path -Parent $PSScriptRoot

function Get-VersionPaths([string]$prov) {
    $rx = '^providers/' + [regex]::Escape($prov) + '/' + [regex]::Escape($prov) + '_v(\d+\.\d+)\.json$'
    $spec = 'providers/' + $prov + '/' + $prov + '_v*.json'
    $raw = @(& git -C $script:VH_Repo log --all --pretty=format: --name-only -- $spec 2>$null)
    $seen = @{}
    foreach ($line in $raw) {
        $p = $line.Trim()
        if ($p -match $rx) { $seen[$p] = $Matches[1] }
    }
    $out = @()
    foreach ($k in $seen.Keys) {
        $out += [pscustomobject]@{ Path = $k; Version = $seen[$k] }
    }
    # comma-guard: a single-element array unwraps to a scalar otherwise
    return ,@($out | Sort-Object { [version]$_.Version })
}

function Resolve-Blob([string]$path) {
    $commits = @(& git -C $script:VH_Repo log --all --format=%H -- $path 2>$null)
    foreach ($c in $commits) {
        $sha = & git -C $script:VH_Repo rev-parse --quiet --verify ($c + ':' + $path) 2>$null
        if ($LASTEXITCODE -eq 0 -and $sha) {
            $meta = (& git -C $script:VH_Repo show -s --format='%ad|%s' --date=short $c) -join ''
            $parts = $meta.Split('|', 2)
            return [pscustomobject]@{
                Commit  = $c
                Blob    = $sha.Trim()
                Date    = $parts[0]
                Subject = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            }
        }
    }
    return $null
}

function Get-LegacyEntries([string]$prov) {
    $variants = @(
        @{ File = ($prov + '.json');       Variant = 'legacy' },
        @{ File = ($prov + '_MC.json');    Variant = 'MC' },
        @{ File = ($prov + '_BASE.json');  Variant = 'BASE' }
    )
    $out = @()
    $seenBlob = @{}
    foreach ($v in $variants) {
        $path = 'providers/' + $prov + '/' + $v.File
        $commits = @(& git -C $script:VH_Repo log --all --format=%H -- $path 2>$null)
        foreach ($c in $commits) {
            $sha = & git -C $script:VH_Repo rev-parse --quiet --verify ($c + ':' + $path) 2>$null
            if ($LASTEXITCODE -ne 0 -or -not $sha) { continue }
            $sha = $sha.Trim()
            if ($seenBlob.ContainsKey($sha)) { continue }
            $seenBlob[$sha] = $true
            $hit = @(& git -C $script:VH_Repo grep -h -m1 -e 'Provider configuration for' $c -- $path 2>$null)
            $ver = ''
            foreach ($line in $hit) {
                if ($line -match ('Provider configuration for\s+' + [regex]::Escape($prov) + '\s+v([\d]+\.[\d]+)')) {
                    $ver = $Matches[1]; break
                }
            }
            if (-not $ver) { continue }   # cannot name it -> do not list it as a version
            $meta = (& git -C $script:VH_Repo show -s --format='%ad|%s' --date=short $c) -join ''
            $parts = $meta.Split('|', 2)
            $subj = ''
            if ($parts.Count -gt 1) { $subj = $parts[1] }
            $out += [pscustomobject]@{
                Version = $ver
                Path    = $path
                Variant = $v.Variant
                Commit  = $c
                Blob    = $sha
                Date    = $parts[0]
                Subject = $subj
                Era     = 'legacy'
            }
        }
    }
    return ,@($out | Sort-Object { [version]$_.Version }, Variant)
}

function Get-Index([string]$prov, [bool]$withLegacy) {
    $entries = @()
    foreach ($v in (Get-VersionPaths $prov)) {
        $b = Resolve-Blob $v.Path
        if ($null -eq $b) {
            $entries += [pscustomobject]@{
                Version = $v.Version; Path = $v.Path; Variant = ''; Commit = ''
                Blob = ''; Date = ''; Subject = '[UNRESOLVED -- path in history but no reachable blob]'
                Era = 'versioned'
            }
        } else {
            $entries += [pscustomobject]@{
                Version = $v.Version; Path = $v.Path; Variant = ''; Commit = $b.Commit
                Blob = $b.Blob; Date = $b.Date; Subject = $b.Subject; Era = 'versioned'
            }
        }
    }
    if ($withLegacy) { $entries += (Get-LegacyEntries $prov) }
    return ,@($entries | Sort-Object { [version]$_.Version }, Variant)
}

function Get-ProvidersInHistory {
    $raw = @(& git -C $script:VH_Repo log --all --pretty=format: --name-only -- 'providers/*/*_v*.json' 2>$null)
    $seen = @{}
    foreach ($line in $raw) {
        $p = $line.Trim()
        if ($p -match '^providers/([^/]+)/\1_v\d+\.\d+\.json$') { $seen[$Matches[1]] = $true }
    }
    return ,@($seen.Keys | Sort-Object)
}

# Read a historical blob's TEXT without writing it to disk. 671 artifacts at ~800KB each is
# ~540MB; extracting them all to build an index would be absurd, and `git cat-file` avoids it.
# ⚠️ Must go through Start-Process/-RedirectStandardOutput or a raw call operator -- piping a
# ~1MB blob through PowerShell's object pipeline mangles encoding and is slow.
function Get-BlobText([string]$blobSha) {
    $prev = $OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        return (& git -C $script:VH_Repo cat-file blob $blobSha | Out-String)
    } finally { $OutputEncoding = $prev }
}
