# -----------------------------------------------------------------------------
#  get_provider_version.ps1 -- RETRIEVE ANY PRIOR PROVIDER JSON, ON DEMAND
#
#  WHY THIS EXISTS (Rob, 2026-09-10): he asked for HI_HCJDC_OFML v4.15 in the
#  provider folder and got back only the tenant export he had supplied himself.
#  The repo-authored v4.15 was sitting in git the whole time (commit 99ade338,
#  927,754 bytes) and nothing made that one command, so it read as unavailable.
#  His question was the right one: "i thought you were able to create any
#  previous version json on demand ... if that is not the case we need to make
#  it so if only to have archived version of the json readily available."
#
#  THE CRITICAL DISTINCTION -- RETRIEVAL, NOT REBUILD.
#  Re-running an old build script does NOT reproduce an old version. The shared
#  modules (_build_rms_bundle / _build_layout_helpers / _build_provider_helpers)
#  and each provider's own build script keep changing, so today's run of
#  yesterday's script emits today's RMS bundle. Measured for the HI v4.15 case:
#  3 shared-module commits and 6 HI build-script commits landed after it. So the
#  git blob is not a convenient shortcut -- it is the ONLY byte-exact source, and
#  a "regenerated" old version is a reconstruction that may silently differ.
#
#  WHY THE FOLDER CANNOT JUST KEEP THEM: the ONE-JSON-IN-ROOT rule. On every
#  bump Write-ProviderJson deletes the stale root sibling, precisely so that
#  Get-ProviderRootJson and the ~40 gates resolving through it can never pick
#  the wrong JSON. Archiving into the provider root would break that invariant,
#  so this tool extracts OUTSIDE it and REFUSES an -OutPath inside providers/.
#
#  WHY NOT COMMIT THE ARCHIVES: 257 versions x ~0.9MB is ~240MB of duplicate
#  JSON that git already stores losslessly, plus a new exclusion needed in every
#  active-JSON resolver. That is ENGINEERING_STANDARD 7's drift engine bought
#  for nothing. Extract on demand instead (Rob's call, 2026-09-10).
#
#  THE VERIFICATION IS THE POINT, AND IT CAN FAIL (LAW 2). The extracted file is
#  checked with `git hash-object` against the blob sha git itself recorded. That
#  compares CONTENT, not existence -- unlike Test-Path, which a leftover or a
#  half-written file satisfies. A mismatch deletes the bad file and FAILs.
#  Proven both directions before this was trusted: a clean extract matches, and
#  a single flipped byte reports HASH MISMATCH.
#
#  THE PRE-VERSIONED ERA IS COVERED TOO (-IncludeLegacy). The versioned filename
#  <PROVIDER>_v<X.Y>.json is the CURRENT standard; before it, builds were
#  committed as <PROVIDER>.json / _MC.json / _BASE.json, and 341 commits touch
#  those names. Indexing only the versioned filenames would have silently
#  reported HI as reaching back to v4.3 when v4.2 and earlier are equally
#  retrievable -- a coverage claim that reads complete while missing an era. For
#  those the version is not in the filename, so it is read from the bundle
#  description ("Provider configuration for <PROVIDER> v<X.Y>") in the blob
#  itself, via `git grep` against the commit+path (no full blob capture).
#  MC and BASE were two JSONs of the SAME version, so both are listed and the
#  variant rides in the extracted filename.
#
#  USAGE
#    -Provider <NAME> -List              every recoverable version + commit/date/why
#    -Provider <NAME> -Version <X.Y>     extract that version (+ provenance sidecar)
#    -All                                census: versions recoverable per provider
#    -IncludeLegacy                      also index the pre-versioned-filename era
#    -Commit <sha>                       disambiguate when one version has 2+ blobs
#    -Variant <legacy|MC|BASE>           disambiguate BASE vs MC at the same commit
#    -OutPath <dir>                      default <repo>\_versions (gitignored)
#    -Force                              overwrite an existing extract
#
#  Retrieval works for every version whose JSON was ever committed -- including
#  providers no longer on disk (NY_NYSPIN_EJUSTICE_SKILLTEST), which are noted
#  rather than refused.
# -----------------------------------------------------------------------------

param(
    [string]$Provider,
    [string]$Version,
    [switch]$List,
    [switch]$All,
    [switch]$IncludeLegacy,
    [string]$Commit,
    [ValidateSet('legacy', 'MC', 'BASE')][string]$Variant,
    [string]$OutPath,
    [switch]$Force,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

function Say([string]$m) { if (-not $Quiet) { Write-Output $m } }

function Fail([string]$m) {
    Write-Output ("  [FAIL] " + $m)
    exit 1
}

# --- environment: refuse loudly rather than pass vacuously ------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git is not on PATH -- this tool retrieves from git history and cannot run without it."
}
& git -C $repo rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail ("not a git repository: " + $repo)
}

# --- the version index, straight from history -------------------------------
# ⚠️ THE ENUMERATION MOVED OUT ON 2026-09-11 -- it is now shared, not private.
# audit_tenant_provenance.ps1 needs the identical walk to identify a TENANT's bundles by
# CONTENT against every historical build, and ENGINEERING_STANDARD 4.4 forbids re-deriving a
# parser that already exists (five were written wrong in one session that way). The functions
# moved VERBATIM into tools/_resolve_version_history.ps1, including the two warnings that make
# them correct: --diff-filter=A under-reports a version SWAP (recorded by git as a RENAME, so
# additions-only found 40 of 257 and reported HI as 2 of 18), and the newest commit touching a
# path is usually its DELETION, where the blob no longer resolves.
# Verified by diffing -List output for AZ/HI/NJ/OR and -All -IncludeLegacy before and after.
. "$PSScriptRoot\_resolve_version_history.ps1"

# --- -All: the census -------------------------------------------------------
if ($All) {
    $provs = Get-ProvidersInHistory
    if ($provs.Count -eq 0) {
        Fail "0 providers found in history -- the enumeration is broken (a zero denominator is not a pass)."
    }
    Say ''
    Say '===================================================================='
    Say '  RECOVERABLE PROVIDER JSON VERSIONS (git history, byte-exact)'
    Say '===================================================================='
    if ($IncludeLegacy) {
        Say ('  {0,-28} {1,5} {2,7}  {3}' -f 'Provider', 'Vers', 'Legacy', 'Range')
    } else {
        Say ('  {0,-28} {1,5}  {2}' -f 'Provider', 'Vers', 'Range')
    }
    Say '  --------------------------------------------------------------'
    $total = 0
    $legacyTotal = 0
    foreach ($p in $provs) {
        $vp = Get-VersionPaths $p
        $total += $vp.Count
        $onDisk = Test-Path (Join-Path $repo ('providers\' + $p))
        $note = ''
        if (-not $onDisk) { $note = '   [not on disk -- historical only]' }
        $range = ''
        if ($vp.Count -gt 0) { $range = 'v' + $vp[0].Version + ' .. v' + $vp[-1].Version }
        if ($IncludeLegacy) {
            $leg = Get-LegacyEntries $p
            $legacyTotal += $leg.Count
            if ($leg.Count -gt 0) { $range = 'v' + $leg[0].Version + ' .. v' + $vp[-1].Version }
            Say ('  {0,-28} {1,5} {2,7}  {3}{4}' -f $p, $vp.Count, $leg.Count, $range, $note)
        } else {
            Say ('  {0,-28} {1,5}  {2}{3}' -f $p, $vp.Count, $range, $note)
        }
    }
    Say '  --------------------------------------------------------------'
    if ($IncludeLegacy) {
        # Say what the numbers ARE. The legacy column counts DISTINCT BLOBS, not
        # distinct version numbers: in the BASE/MC era one version had two JSONs,
        # and a same-version rebuild leaves a second blob. Calling both columns
        # "versions" would overstate the second one.
        Say ('  {0} providers, {1} versioned-filename version(s) + {2} pre-versioned blob(s) = {3} retrievable artifact(s)' -f $provs.Count, $total, $legacyTotal, ($total + $legacyTotal))
        Say '    (pre-versioned counts DISTINCT BLOBS -- BASE and MC were two JSONs of one version)'
    } else {
        Say ('  {0} providers, {1} recoverable versions (versioned filenames only --' -f $provs.Count, $total)
        Say '    add -IncludeLegacy for the pre-versioned <PROVIDER>.json / _MC / _BASE era)'
    }
    Say '===================================================================='
    Say ''
    Say ('  Extract one:  tools\get_provider_version.ps1 -Provider <NAME> -Version <X.Y>')
    Say ''
    exit 0
}

if (-not $Provider) {
    Fail "specify -Provider <NAME> (with -List or -Version <X.Y>), or -All for the census."
}

$idx = Get-Index $Provider ([bool]$IncludeLegacy)
if ($idx.Count -eq 0) {
    $known = Get-ProvidersInHistory
    Write-Output ("  [FAIL] no versioned JSON for '" + $Provider + "' in git history.")
    Write-Output ('         providers present in history (' + $known.Count + '):')
    foreach ($k in $known) { Write-Output ('           ' + $k) }
    exit 1
}

if (-not (Test-Path (Join-Path $repo ('providers\' + $Provider)))) {
    Say ('  [NOTE] ' + $Provider + ' has no directory on disk -- recoverable from history only.')
}

# --- -List ------------------------------------------------------------------
if ($List -or -not $Version) {
    $activeName = ''
    $active = Get-ChildItem (Join-Path $repo ('providers\' + $Provider)) -Filter '*.json' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match ('^' + [regex]::Escape($Provider) + '_v[\d.]+\.json$') }
    if ($active) { $activeName = $active[0].Name }

    Say ''
    Say ('  ' + $Provider + ' -- ' + $idx.Count + ' recoverable version(s)')
    Say '  --------------------------------------------------------------------------'
    foreach ($e in $idx) {
        $mark = '   '
        if ($activeName -and ($e.Path -like ('*/' + $activeName))) { $mark = ' * ' }
        $tag = ''
        if ($e.Era -eq 'legacy') { $tag = '[' + $e.Variant + '] ' }
        if (-not $e.Blob) {
            Say ('  ' + $mark + 'v' + $e.Version + '  ' + $e.Subject)
        } else {
            $subj = $tag + $e.Subject
            if ($subj.Length -gt 84) { $subj = $subj.Substring(0, 84) + '...' }
            Say ('  ' + $mark + 'v' + ('{0,-6}' -f $e.Version) + ' ' + $e.Date + '  ' + $e.Commit.Substring(0, 8) + '  ' + $subj)
        }
    }
    Say '  --------------------------------------------------------------------------'
    if ($activeName) { Say ('  * = the version currently in the provider root (' + $activeName + ')') }
    if (-not $IncludeLegacy) {
        Say '  (versioned filenames only -- add -IncludeLegacy for the pre-versioned era)'
    }
    Say ('  Extract:  tools\get_provider_version.ps1 -Provider ' + $Provider + ' -Version <X.Y>')
    Say ''
    exit 0
}

# --- extract ----------------------------------------------------------------
$want = $Version -replace '^v', ''
$hit = @($idx | Where-Object { $_.Version -eq $want })
if ($Commit) { $hit = @($hit | Where-Object { $_.Commit -like ($Commit + '*') }) }
# -Variant is needed as well as -Commit, not instead of it: in the BASE/MC era a
# SINGLE commit holds both variants at one version, so a commit sha alone cannot
# name one artifact. Found by exercising the ambiguity refusal on HI v1.0.
if ($Variant) { $hit = @($hit | Where-Object { $_.Variant -eq $Variant }) }
if ($hit.Count -eq 0) {
    Write-Output ("  [FAIL] " + $Provider + " v" + $want + " is not in git history.")
    Write-Output ('         ' + $idx.Count + ' version(s) available: ' + (($idx | ForEach-Object { 'v' + $_.Version }) -join ', '))
    if (-not $IncludeLegacy) { Write-Output '         (add -IncludeLegacy to also search the pre-versioned era)' }
    exit 1
}
# AMBIGUITY IS REFUSED, NOT GUESSED. In the legacy era MC and BASE were two
# JSONs of one version, and a same-version rebuild can leave two distinct blobs.
# Picking one silently would hand back an artifact the caller cannot identify.
if ($hit.Count -gt 1) {
    Write-Output ('  [FAIL] ' + $Provider + ' v' + $want + ' is ambiguous -- ' + $hit.Count + ' distinct blob(s) claim it:')
    foreach ($h in $hit) {
        Write-Output ('         ' + $h.Commit.Substring(0, 8) + '  ' + $h.Date + '  ' + $h.Variant + '  ' + $h.Path)
    }
    Write-Output '         Re-run with -Commit <sha> and/or -Variant <legacy|MC|BASE> to name one.'
    exit 1
}
$target = $hit[0]
if (-not $target.Blob) {
    Fail ($Provider + ' v' + $want + ' appears in history but no reachable blob resolves -- history may be shallow or the object pruned.')
}
$blobInfo = $target

if (-not $OutPath) { $OutPath = Join-Path $repo '_versions' }

# Absolutize WITHOUT creating anything: Resolve-Path demands existence, and the
# guard below must run before any mkdir. (Found by exercising the guard: the
# first cut created the directory and only then refused, so a refusal could
# leave a footprint inside providers\ -- a tool that says no must leave no trace.)
if (-not [System.IO.Path]::IsPathRooted($OutPath)) { $OutPath = Join-Path $repo $OutPath }
$OutPath = [System.IO.Path]::GetFullPath($OutPath)

# THE GUARD THAT PROTECTS THE ONE-JSON-IN-ROOT RULE. A retrieved archive landing
# in a provider directory would give Get-ProviderRootJson two candidates and
# make every gate resolve against a superseded build. Refuse, do not warn.
$provRoot = [System.IO.Path]::GetFullPath((Join-Path $repo 'providers'))
if ($OutPath.ToLower().StartsWith($provRoot.ToLower())) {
    Fail ("-OutPath is inside providers\ (" + $OutPath + "). That would break the ONE-JSON-IN-ROOT rule and make the active-JSON resolver ambiguous. Extract elsewhere (default: " + (Join-Path $repo '_versions') + ").")
}

if (-not (Test-Path $OutPath)) { New-Item -ItemType Directory -Path $OutPath -Force | Out-Null }

# MC and BASE were two JSONs of the SAME version, so the variant must ride in
# the filename or the second extract would silently overwrite the first.
$suffix = ''
if ($target.Variant -eq 'MC' -or $target.Variant -eq 'BASE') { $suffix = '_' + $target.Variant }
$outFile = Join-Path $OutPath ($Provider + '_v' + $want + $suffix + '.json')
if ((Test-Path $outFile) -and -not $Force) {
    Fail ('already extracted: ' + $outFile + '  (use -Force to overwrite)')
}
if (Test-Path $outFile) { Remove-Item $outFile -Force }

# Raw process stdout straight to the file. A PowerShell pipeline capture would
# re-encode and re-terminate lines; Start-Process does not touch the bytes.
Start-Process -FilePath 'git' `
    -ArgumentList @('-C', $repo, 'cat-file', 'blob', $blobInfo.Blob) `
    -NoNewWindow -Wait -RedirectStandardOutput $outFile

if (-not (Test-Path $outFile)) {
    Fail ('extraction produced no file: ' + $outFile)
}

# CONTENT verification, not existence. This is the line that makes a clean
# verdict mean something.
$actual = (& git -C $repo hash-object $outFile).Trim()
$bytes = (Get-Item $outFile).Length
if ($actual -ne $blobInfo.Blob) {
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    Write-Output ('  [FAIL] HASH MISMATCH -- extracted bytes are NOT the committed blob. File deleted.')
    Write-Output ('         expected ' + $blobInfo.Blob)
    Write-Output ('         actual   ' + $actual)
    exit 1
}

# Provenance sidecar. An extracted JSON with no provenance is an artifact shaped
# like evidence -- you cannot tell it from a hand-edited copy a week later.
$prov = Join-Path $OutPath ($Provider + '_v' + $want + $suffix + '.provenance.txt')
$lines = @(
    'PROVIDER JSON -- RETRIEVED FROM GIT HISTORY (byte-exact, not rebuilt)',
    '=====================================================================',
    ('Provider     : ' + $Provider),
    ('Version      : v' + $want),
    ('Era          : ' + $target.Era + $(if ($target.Variant) { '  (variant: ' + $target.Variant + ')' } else { '' })),
    ('History path : ' + $target.Path),
    ('Commit       : ' + $blobInfo.Commit),
    ('Commit date  : ' + $blobInfo.Date),
    ('Commit subj  : ' + $blobInfo.Subject),
    ('Blob sha1    : ' + $blobInfo.Blob),
    ('Bytes        : ' + $bytes),
    ('Verified     : git hash-object matches the committed blob'),
    ('Extracted    : ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' by tools\get_provider_version.ps1'),
    '',
    'This is the JSON as COMMITTED at that version. It is NOT a rebuild: re-running',
    'the build script of that era against today shared modules would emit different',
    'bytes. Do NOT copy this into the provider root -- the ONE-JSON-IN-ROOT rule',
    'means the active-JSON resolver must find exactly one candidate there.'
)
Set-Content -Path $prov -Value $lines -Encoding ASCII

Say ''
Say ('  [OK] ' + $Provider + ' v' + $want + ' extracted and VERIFIED')
Say ('       file    : ' + $outFile)
Say ('       bytes   : ' + $bytes)
Say ('       blob    : ' + $blobInfo.Blob + '  (git hash-object matches)')
Say ('       commit  : ' + $blobInfo.Commit.Substring(0, 8) + '  ' + $blobInfo.Date + '  ' + $blobInfo.Subject)
Say ('       why     : ' + $prov)
Say ''
exit 0
