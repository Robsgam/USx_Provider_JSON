<#
  audit_provider_linkage.ps1 -- NO PROVIDER IS A REFERENCE FOR ANOTHER. Enforce it mechanically.

  THE RULE (Rob, three times now -- 2026-05-07, 2026-05-08, 2026-08-01):
    "never link provider unless directed to like with costa contra and tx cch"
    Every provider JSON is STANDALONE. Its build is justified by ITS OWN devdoc (query authority) and
    ITS OWN metadata XML (field authority). CLAUDE.md + knowledge-base are the only shared authority.

  THE ONLY TWO DIRECTED LINKS:
    1. CA_CONTRA_COSTA -> CA_CLETS   (explicit ruling: build = full CA_CLETS copy + CC's JAWS)
    2. <BASE>_<VARIANT> -> <BASE>    (CCH and future variants; declared by `# BASE-SYNC: <BASE> vX.Y`
                                      and gated for drift by audit_variant_sync.ps1)

  WHY A GATE AND NOT ANOTHER NOTE
    This was already written down and I broke it anyway, on CA_VENTURA_COUNTY v2.1/v2.2, by citing
    CA_CLETS as precedent in build-script comments. A repeat correction means the note is not the
    control -- the mechanism is.

  WHY IT MATTERS BEYOND TIDINESS -- the near-miss that proves it:
    CA_CLETS and CA_VENTURA_COUNTY both have an IR.QVC{Name} DL combination, and they require
    OPPOSITE things. CA_CLETS's has FOUR metadata variants, one of which puts Choice[Age|BirthDate]
    inside <Any> -- so the discriminator is legally OPTIONAL there, and CA_CLETS correctly registered
    a demoted-to-any divergence. Ventura's has exactly ONE variant with the Choice inside <Set> -- so
    the discriminator is MANDATORY and must be split into one combination per branch. Copying the
    "verified sibling" would have shipped a request Ventura's own metadata calls invalid.
    A sibling provider is not evidence. Where it looks like evidence, it is actively misleading.

  WHAT THIS FLAGS
    A build script naming a DIFFERENT provider (in code or comment) without being a directed link.
    Comments count: a comment is where the JUSTIFICATION lives, and a justification that points at
    another provider is exactly the defect. Rewrite it to cite this provider's own devdoc/metadata --
    which is stronger anyway, because it says WHY rather than WHO ELSE.

  Usage: powershell -ExecutionPolicy Bypass -File tools\audit_provider_linkage.ps1 [-Provider <name>] [-OutFile <path>]
#>
[CmdletBinding()]
param([string]$Provider, [string]$OutFile)

$repo  = Split-Path $PSScriptRoot -Parent
$provs = @(Get-ChildItem (Join-Path $repo 'providers') -Directory | Sort-Object Name | ForEach-Object { $_.Name })
$lines = @()
function O([string]$t, [string]$c = 'Gray') { $script:lines += $t; Write-Host $t -ForegroundColor $c }

O ('=' * 110) 'Cyan'
O '  PROVIDER LINKAGE GATE -- every provider is standalone; only DIRECTED links are allowed' 'Cyan'
O ('=' * 110) 'Cyan'

$targets = if ($Provider) { @($Provider) } else { $provs }
$totFlag = 0; $totScanned = 0; $totAllowed = 0

foreach ($p in $targets) {
    $dir = Join-Path $repo "providers\$p\scripts"
    if (-not (Test-Path $dir)) { continue }
    $scripts = @(Get-ChildItem $dir -Filter '*.ps1' -File)
    if (-not $scripts.Count) { continue }

    # ── allowed link targets for THIS provider ────────────────────────────────────────────────
    $allowed = @()
    # (1) explicit directed ruling
    if ($p -eq 'CA_CONTRA_COSTA') { $allowed += 'CA_CLETS' }
    # (2) variant -> its declared base, via the BASE-SYNC marker (same source audit_variant_sync uses)
    foreach ($s in $scripts) {
        $m = [regex]::Match((Get-Content $s.FullName -Raw), '(?m)^\s*#\s*BASE-SYNC:\s*([A-Z0-9_]+)\s')
        if ($m.Success) { $allowed += $m.Groups[1].Value }
    }
    $allowed = @($allowed | Select-Object -Unique)

    $hits = @()
    foreach ($s in $scripts) {
        $srcLines = @([IO.File]::ReadAllLines($s.FullName))
        for ($i = 0; $i -lt $srcLines.Count; $i++) {
            $line = $srcLines[$i]
            # NOT a provider link: a PLATFORM CODE-TYPE SOURCE that happens to be named after a
            # provider. `codeTypeSource = 'CA_CLETS'` is the registry value the platform requires for
            # NCIC_ARTICLE_TYPE (CLAUDE.md code-type pairings -- NCIC gives an empty dropdown), and
            # codeTypeProvider works the same way. Flagging these would make the gate cry wolf, and a
            # gate with false positives gets ignored, which is worse than no gate.
            if ($line -match "codeType(Source|Provider|Category)\s*=") { continue }
            foreach ($other in $provs) {
                if ($other -eq $p) { continue }
                # a provider name is only a "link" when it appears as a whole token
                if ($line -notmatch "(?<![A-Za-z0-9_])$([regex]::Escape($other))(?![A-Za-z0-9_])") { continue }
                # a LONGER provider name containing this one is not a hit (CA_CLETS inside CA_CLETS_OCATS)
                $longer = @($provs | Where-Object { $_ -ne $other -and $_ -like "*$other*" -and
                            $line -match "(?<![A-Za-z0-9_])$([regex]::Escape($_))(?![A-Za-z0-9_])" })
                if ($longer.Count) { continue }
                if ($allowed -contains $other) { $script:totAllowed++; continue }
                $hits += [pscustomobject]@{ File = $s.Name; Line = $i + 1; Other = $other; Text = $line.Trim() }
            }
        }
        $totScanned++
    }

    if ($hits.Count) {
        $totFlag += $hits.Count
        O ''
        O ("  [FAIL] $p -- $($hits.Count) cross-provider reference(s); allowed targets: " +
           $(if ($allowed.Count) { $allowed -join ', ' } else { '(none -- standalone)' })) 'Red'
        foreach ($h in ($hits | Select-Object -First 12)) {
            $t = $h.Text; if ($t.Length -gt 118) { $t = $t.Substring(0, 118) + '...' }
            O ("         $($h.File):$($h.Line) -> $($h.Other)") 'Yellow'
            O ("            $t") 'DarkGray'
        }
        if ($hits.Count -gt 12) { O ("         ... and $($hits.Count - 12) more") 'DarkGray' }
        O '         FIX: justify from THIS provider''s own devdoc + metadata XML instead. Naming another' 'Yellow'
        O '         provider is not evidence -- CA_CLETS and CA_VENTURA_COUNTY require OPPOSITE things' 'Yellow'
        O '         on the same IR.QVC{Name} combo (see header).' 'Yellow'
    }
}

O ''
O ("  RESULT: $totFlag cross-provider reference(s) across $($targets.Count) provider(s) " +
   "[$totScanned build script(s) scanned, $totAllowed directed reference(s) allowed]") `
   $(if ($totFlag) { 'Red' } else { 'Green' })
if (-not $totFlag) { O '  Every build script justifies itself from its own sources.' 'Green' }

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit $(if ($totFlag) { 1 } else { 0 })
