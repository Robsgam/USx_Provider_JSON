# _resolve_provider_xml.ps1 -- SHARED metadata-XML resolver. Dot-source; do not run directly.
#
# WHY THIS EXISTS
#   JSON resolution has had a single shared resolver for a long time (`_resolve_provider_json.ps1`
#   / Get-ProviderRootJson) precisely so no tool hardcodes or guesses. Metadata XML had NO such
#   resolver, so SIX tools each hand-rolled it, and four of them used the same shortcut:
#       Get-ChildItem source -Filter '*.xml' | Select-Object -First 1
#   That is alphabetical, not authoritative. On the ONE provider that carries two XMLs
#   (CA_CONTRA_COSTA: `CA_CONTRA_COSTA_JAWS_ONLY.xml` + `CA_CONTRA_COSTA.xml`) it silently picked
#   the JAWS-only excerpt -- 6 <Combination> nodes instead of 466, and 1 IR.QVC variant instead of
#   12. Nothing failed. The tool ran green against 1.3% of the metadata.
#
#   That produced a false defect report that survived FIVE reasoning passes: every built IR.QVC.*
#   combo was compared against the single surviving {Name} variant, so five correct combos looked
#   like collapsed-Choice defects. The bug was never in the comparison logic being debugged -- it
#   was in which file had been opened. See the banner in audit_defect_classes.ps1.
#
#   The class generalizes and is worth naming: A GATE THAT READS THE WRONG AUTHORITY CANNOT FAIL
#   HONESTLY. It will report PASS or FAIL with equal confidence and no denominator to betray it.
#   Same family as the vacuous fingerprint check and the registry over-suppression.
#
# RESOLUTION ORDER (first hit wins)
#   1. <PROVIDER>.xml exactly                  -- authoritative; all 20 providers have this today
#   2. <BASE>.xml for a variant                -- <BASE>_<SUFFIX> falls back to its base provider's
#                                                 XML, mirroring the devdoc base/variant rule in
#                                                 CLAUDE.md ("Provider Variants -- Source Sharing")
#   3. the only *.xml present                  -- unambiguous, so safe
#   4. nothing                                 -- returns $null AND warns; NEVER guesses between
#                                                 multiple candidates
#
# The point of 4: an ambiguous pick is worse than no pick, because a caller can handle $null but
# cannot detect a plausible-looking wrong answer.

function Get-ProviderMetadataXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Provider,
        [string]$ProvDir,
        [string]$Repo,
        # Emit a warning when the pick is anything other than the exact <PROVIDER>.xml. Callers that
        # print their own resolution line can pass -Quiet.
        [switch]$Quiet
    )

    if (-not $ProvDir) {
        if (-not $Repo) { $Repo = Split-Path (Split-Path $PSCommandPath -Parent) -Parent }
        $ProvDir = Join-Path $Repo "providers\$Provider"
    }
    $srcDir = Join-Path $ProvDir 'source'
    if (-not (Test-Path $srcDir)) { return $null }

    # 1 -- exact
    $exact = Join-Path $srcDir "$Provider.xml"
    if (Test-Path $exact) { return $exact }

    # 2 -- variant falls back to its base provider's XML (TX_TLETS_CCH -> TX_TLETS)
    if ($Provider -match '_') {
        $parts = $Provider -split '_'
        for ($i = $parts.Count - 1; $i -ge 2; $i--) {
            $base = ($parts[0..($i - 1)] -join '_')
            $baseDir = Join-Path (Split-Path $ProvDir -Parent) $base
            $cand = Join-Path $baseDir "source\$base.xml"
            if ((Test-Path $baseDir -PathType Container) -and (Test-Path $cand)) {
                if (-not $Quiet) { Write-Warning "$Provider has no own metadata XML; using base $base's ($cand)." }
                return $cand
            }
        }
    }

    # 3 -- exactly one candidate is unambiguous
    $all = @(Get-ChildItem $srcDir -Filter '*.xml' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($all.Count -eq 1) {
        if (-not $Quiet) { Write-Warning "$Provider has no $Provider.xml; using the only XML present ($($all[0].Name))." }
        return $all[0].FullName
    }

    # 4 -- refuse to guess
    if ($all.Count -gt 1 -and -not $Quiet) {
        Write-Warning ("$Provider has $($all.Count) metadata XMLs and none named $Provider.xml -- " +
                       "REFUSING to pick one (an alphabetical guess is how the CA_CONTRA_COSTA " +
                       "JAWS-only misread happened). Candidates: " + (($all | ForEach-Object { $_.Name }) -join ', '))
    }
    return $null
}
