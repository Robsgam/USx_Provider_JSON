<#
  audit_devdoc_order.ps1 -- is the built combination order consistent with the DEVDOC listing order?

  Rob 2026-07-31: "ordering has two lines. Specificity first, then the devdoc order for over-filled
  fields -- if both queries could execute given the filled fields, we refer to the order in the
  devdoc for firing."

    LINE 1  SPECIFICITY      -- an ungated combo whose set[] is a strict SUBSET of a later one steals
                                every fill from it. Owned by audit_combo_reachability + build_phase1 [3].
    LINE 2  DEVDOC ORDER     -- THIS TOOL. The tiebreaker when two DIFFERENT queries could both
                                execute. NJ Boat forced it: hull and registration-number are separate,
                                equally-specific single-identifier searches, so specificity cannot
                                resolve them and the devdoc's order is the product answer.

  Nothing verified line 2 until now. Rob caught that, the tooling did not -- and it is the dimension
  behind the QV/QW mess that was hand-ruled three times and regressed twice.

  WHAT IS FLAGGED: an INVERSION -- a devdoc-LATER item positioned AHEAD of a devdoc-EARLIER one --
  but ONLY when the earlier-positioned combo is UNGATED. A condition on it legitimately hands the
  over-fill back to the devdoc-earlier path, which is exactly how NJ_NJCJIS ends up CORRECT despite
  QB (devdoc #2) sitting first in the array: QB carries 'BoatHullIdNumber NOT_EXISTS', so a hull
  fill defers to QBN (devdoc #1). Flagging that would be a false positive.

  KNOWN LIMIT, stated because a gate that hides its blind spot is worse than no gate: only combos
  that MAP to a devdoc item are checked. Synthetic combos with no devdoc counterpart (3/8 on NJ,
  5/19 on TX, 8/30 on FL) get NO order verification, and neither does the order BETWEEN two
  synthetics. The mapped/unmapped counts are printed every run so the coverage is never implied.

  Usage: .\audit_devdoc_order.ps1 -Path <json> [-OutFile <path>]
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$toolDir = $PSScriptRoot
$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; Write-Host $s -ForegroundColor $c }

if (-not (Test-Path $Path)) { Write-Host "  [FAIL] -Path not found: $Path" -ForegroundColor Red; exit 1 }
$prov = [System.IO.Path]::GetFileNameWithoutExtension($Path) -replace '_v[0-9]+\.[0-9]+$', ''

Out-Line ''
Out-Line ('=' * 80)
Out-Line '  DEVDOC ORDER -- built combination order vs the devdoc listing order'
Out-Line ("  " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + "   $prov")
Out-Line ('=' * 80)

# ── devdoc items, reusing the already-validated parser (LAW 4) ────────────────────────
$ddItems = @{}
$ddRaw = & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir 'audit_devdoc_combinations.ps1') -Path $Path -Explain 2>&1 | Out-String
foreach ($ln in ($ddRaw -split "`n")) {
    $mm = [regex]::Match($ln, 'devdoc\s+(\S+)\s+#(\d+):\s*mand=\[([^\]]*)\]')
    if (-not $mm.Success) { continue }
    $q = $mm.Groups[1].Value
    $mand = @($mm.Groups[3].Value -split ',' | ForEach-Object { ($_ -replace '[^A-Za-z0-9]','').ToLower() } | Where-Object { $_ })
    if (-not $ddItems.ContainsKey($q)) { $ddItems[$q] = @() }
    $ddItems[$q] += [pscustomobject]@{ Num = [int]$mm.Groups[2].Value; Mand = $mand }
}
if (-not $ddItems.Count) {
    Out-Line '  [FAIL] parsed 0 devdoc items -- do NOT read this as "order is fine"; the parser saw nothing' 'Red'
    if ($OutFile) { $lines | Out-File $OutFile -Encoding utf8 }
    exit 0
}

$json = Get-Content $Path -Raw | ConvertFrom-Json
$inv = @(); $tot = 0; $map = 0

foreach ($b in $json.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        if ("$($c.provider)" -eq 'RMS' -or "$($c.name)" -match '^RMS ') { continue }
        $qn = ($c.name -replace "^$([regex]::Escape($prov))_", '')
        $cms = @($c.combinations)
        $tot += $cms.Count
        if (-not $ddItems.ContainsKey($qn)) { continue }

        $mapped = @()
        for ($i = 0; $i -lt $cms.Count; $i++) {
            $cs = @($cms[$i].requirements.set | ForEach-Object { ($_ -replace '[^A-Za-z0-9]','').ToLower() })
            $best = $null; $bestScore = -999
            foreach ($it in $ddItems[$qn]) {
                $sc = 0
                foreach ($w in $it.Mand) { if ($cs -contains $w) { $sc += 3 } else { $sc -= 2 } }
                foreach ($w in $cs)      { if ($it.Mand -notcontains $w) { $sc -= 1 } }
                if ($sc -gt $bestScore) { $bestScore = $sc; $best = $it }
            }
            if ($best -and $bestScore -gt 0) {
                $map++
                $mapped += [pscustomobject]@{ Pos = $i; Kr = "$($cms[$i].keyReference)"; Dd = $best.Num
                                             Cond = @($cms[$i].requirements.conditions).Count }
            }
        }
        for ($a = 0; $a -lt $mapped.Count; $a++) {
            for ($z = $a + 1; $z -lt $mapped.Count; $z++) {
                if ($mapped[$a].Dd -le $mapped[$z].Dd) { continue }   # agrees with devdoc
                if ($mapped[$a].Cond -gt 0) { continue }              # gated -> defers correctly
                $inv += "$qn/$($mapped[$a].Kr) implements devdoc #$($mapped[$a].Dd) at position $($mapped[$a].Pos+1), AHEAD of $($mapped[$z].Kr) which implements devdoc #$($mapped[$z].Dd) at position $($mapped[$z].Pos+1) -- UNGATED, so on a fill satisfying both, the devdoc-LATER path fires"
            }
        }
    }
}

Out-Line ''
foreach ($l in $inv) { Out-Line "  [FAIL] DEVDOC-ORDER INVERSION: $l" 'Red' }
Out-Line ''
Out-Line ('-' * 80)
Out-Line ("  mapped {0} of {1} built combination(s) to a devdoc item -- UNMAPPED COMBOS ARE NOT CHECKED" -f $map, $tot)
if ($inv.Count) { Out-Line "  [FAIL] $($inv.Count) inversion(s). Fix by ORDER (devdoc-earlier first) or by giving the earlier combo a discriminating condition. NEVER by deleting the later one." 'Red' }
else            { Out-Line "  [PASS] no inversion among mapped combinations (order agrees with the devdoc, or is gated)" 'Green' }
Out-Line ('-' * 80)

if ($OutFile) { $lines | Out-File $OutFile -Encoding utf8 }
exit 0
