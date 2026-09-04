<#
  audit_order_risk.ps1 -- the TRUE residual ordering risk, not the scary-but-wrong headline.

  WHY IT EXISTS: audit_devdoc_order honestly reports "mapped N of M -- UNMAPPED COMBOS ARE NOT
  CHECKED", which reads as "26-44% of combos are unverified" (TX 14/19, NY 9/16, NJ 5/8, FL 22/30,
  HI 9/12, CA 14/25 as of 2026-07-31). That framing is WRONG and it panics the reader toward
  reordering combos that are already deterministic. This tool computes the number that actually
  matters. First run: TX 5, NY 0, NJ 0, FL 19, HI 0, CA 2 -- i.e. NY/NJ/HI ordering is FULLY pinned
  by specificity plus conditions, and the devdoc-order coverage gap cannot hurt them at all.

  "31-44% of combos get no devdoc-order check" overstates it. Ordering has TWO lines:
    LINE 1 SPECIFICITY -- audit_combo_reachability checks this for EVERY combo pair, fill-independent
                          (an ungated subset ahead of a superset steals its fills). Clean on all 6.
    LINE 2 DEVDOC ORDER -- audit_devdoc_order, and it only covers combos it can MAP to a devdoc item.

  A pair is only at RISK if line 1 cannot resolve it AND line 2 does not cover it:
      * neither set[] is a subset of the other  (so specificity is silent -- they are peers), AND
      * both are UNGATED (a condition on either one deterministically defers), AND
      * they are CO-SATISFIABLE (some single fill satisfies both set[]s at once)
  Only then does nothing but the devdoc's listing order decide the winner. That is the number that
  belongs next to a confidence %, and it is much smaller than the mapped/unmapped delta.
#>
param([string[]]$Providers = @('TX_TLETS','NY_NYSPIN_EJUSTICE','NJ_NJCJIS','FL_FCIC','HI_HCJDC_OFML','CA_CLETS'))

$repo = 'C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON'
Set-Location $repo
. "$repo\tools\_resolve_provider_json.ps1"
. "$repo\tools\_sim_helpers.ps1"

$sum = @()
foreach ($p in $Providers) {
    $d = Join-Path $repo "providers\$p"
    $jp = Get-ProviderRootJson -ProvDir $d -Provider $p
    if (-not $jp) { continue }
    $ver = [regex]::Match([IO.Path]::GetFileNameWithoutExtension($jp), '_v([\d.]+)$').Groups[1].Value
    $json = Get-Content $jp -Raw | ConvertFrom-Json

    $risk = @(); $pairs = 0
    foreach ($b in $json.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTDATAMAPPING' -or "$($c.provider)" -eq 'RMS') { continue }
        $cms = @($c.combinations)
        for ($i = 0; $i -lt $cms.Count; $i++) {
            for ($j = $i + 1; $j -lt $cms.Count; $j++) {
                $pairs++
                $a = $cms[$i]; $z = $cms[$j]
                $sa = @($a.requirements.set | Where-Object { $_ }); $sz = @($z.requirements.set | Where-Object { $_ })
                if (-not $sa.Count -or -not $sz.Count) { continue }   # empty-set[] combos are a different class
                $ca = @(Get-ComboConditions $a).Count; $cz = @(Get-ComboConditions $z).Count
                if ($ca -gt 0 -or $cz -gt 0) { continue }             # a condition defers deterministically
                $aSubZ = -not @($sa | Where-Object { $sz -notcontains $_ }).Count
                $zSubA = -not @($sz | Where-Object { $sa -notcontains $_ }).Count
                if ($aSubZ -or $zSubA) { continue }                   # LINE 1 owns this pair
                # peers, both ungated: co-satisfiable by definition (fill the union of both set[]s)
                $risk += "$($c.query): $($a.keyReference) [$(($sa) -join '+')]  vs  $($z.keyReference) [$(($sz) -join '+')]"
            }
        }
    } }

    Write-Host "`n########## $p v$ver ##########" -ForegroundColor Cyan
    Write-Host ("  combo pairs examined            : {0}" -f $pairs)
    Write-Host ("  pairs where ONLY devdoc order decides : {0}" -f $risk.Count) -ForegroundColor $(if($risk.Count){'Yellow'}else{'Green'})
    $risk | ForEach-Object { Write-Host "        $_" -ForegroundColor Yellow }
    $sum += [pscustomobject]@{ P=$p; V=$ver; Pairs=$pairs; Risk=$risk.Count }
}

Write-Host "`n"
Write-Host ('=' * 92) -ForegroundColor Cyan
Write-Host '  RESIDUAL ORDERING RISK -- pairs neither specificity nor a condition can resolve' -ForegroundColor Cyan
Write-Host ('=' * 92) -ForegroundColor Cyan
Write-Host ("  {0,-22} {1,-6} {2,-16} {3}" -f 'PROVIDER','VER','PAIRS EXAMINED','ONLY-DEVDOC-DECIDES')
foreach ($s in $sum) { Write-Host ("  {0,-22} {1,-6} {2,-16} {3}" -f $s.P,$s.V,$s.Pairs,$s.Risk) -ForegroundColor $(if($s.Risk){'Yellow'}else{'Green'}) }
Write-Host ''

# ── EXIT CODE, added 2026-09-04 ────────────────────────────────────────────────────────────────
# This tool had NO exit statement at all, so it always returned 0 -- and it was about to be wired
# into an orchestrator that keys on exit codes, which would have added a gate that cannot fail.
# Fix the exit BEFORE wiring, never after: a "wired" gate that always returns 0 is indistinguishable
# on the board from a working one, and the meta-gate that checks wiring would have read green.
#
# ADVISORY BY DESIGN, so residual risk is reported and does NOT block: this tool exists to give the
# HONEST number behind audit_devdoc_order's "mapped N of M" line -- pairs where neither specificity
# nor a condition decides, and only devdoc listing order does. That is a real risk to KNOW, not a
# defect to fix; forcing it to zero would mean inventing conditions the metadata does not support.
# Exit 1 is therefore reserved for "this run proved nothing".
if (-not $sum -or $sum.Count -eq 0) {
    Write-Host "  [NO-VERDICT] examined ZERO providers -- this run compared nothing. That is not a pass." -ForegroundColor Red
    exit 1
}
$totalPairs = ($sum | Measure-Object -Property Pairs -Sum).Sum
$totalRisk  = ($sum | Measure-Object -Property Risk  -Sum).Sum
Write-Host ("  TOTALS: {0} provider(s) / {1} ordered pair(s) examined / {2} where ONLY devdoc order decides" -f $sum.Count, $totalPairs, $totalRisk) -ForegroundColor Cyan
if ($totalPairs -eq 0) {
    Write-Host "  [NO-VERDICT] zero ordered pairs examined across all providers -- nothing was compared." -ForegroundColor Red
    exit 1
}
exit 0
