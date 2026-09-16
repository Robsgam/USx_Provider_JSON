<#
  probe_multi_qif_entities.ps1 -- WHICH PROVIDERS PUT MORE THAN ONE QUERYINPUTFORM ON ONE ENTITY,
  and how many controls each of those forms carries.

  WHY IT EXISTS. `emit_test_plan.ps1` kept its QIF lookup in a plain hashtable keyed by
  targetEntity (`$qifByEntity[$e] = $qif`), so on a multi-QIF entity the LAST form silently
  EVICTED every earlier one and only its controls were ever considered fillable. On SC_SLED v1.7
  that discarded all 20 controls on the Wanted Person tab and produced 24 lines of
  "any[X] -- no control on the Firearm form; treated as platform-DERIVED, not typed" for fields
  that are visible type-in boxes. This probe is the denominator for that fix: it names exactly
  which providers the change can affect, so "nothing else moved" is measured rather than asserted.

  LIMITATION #26 is why the UNION is correct: the field pool IS shared across all QIFs on one
  entity (which is also why #28 breaks codeTypeProvider reverse-lookup on a two-QIF entity).

  ⚠️ WRITTEN AFTER MY OWN HAND-ROLLED VERSION HUNG TWICE. It called
  `Get-ProviderRootJson -Provider $p` and omitted the MANDATORY `-ProvDir`, so PowerShell
  prompted on stdin, blocked forever with stdin not a console, and looked exactly like a slow
  sweep over 21 large JSONs. `Get-ProbeJsonPath` cannot be called wrong -- that is the whole
  point of the harness (usx-tooling 8).
#>
. "$PSScriptRoot\..\_probe.ps1"

$multi = 0
$provs = Get-ProbeProviders   # -NoEnumerate: assign FIRST, or foreach iterates ONCE over the whole array
foreach ($p in $provs) {
    $json = Get-Content (Get-ProbeJsonPath -Provider $p) -Raw | ConvertFrom-Json
    $qifs = @($json.bundles.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' })
    [void](Assert-ProbeNonZero $qifs.Count "QUERYINPUTFORMs in $p")
    $dups = @($qifs | Group-Object targetEntity | Where-Object { $_.Count -gt 1 })
    if ($dups.Count -gt 0) {
        $multi++
        $d = ($dups | ForEach-Object {
            $forms = ($_.Group | ForEach-Object {
                $n = @($_.layout.default.PSObject.Properties | Where-Object { $_.Value.props.fieldId }).Count
                "$($_.name):$n ctrl"
            }) -join ' + '
            "$($_.Name) = $forms"
        }) -join '  |  '
        Write-Host ("{0,-22} MULTI-QIF  {1}" -f $p, $d) -ForegroundColor Yellow
    } else {
        Write-Host ("{0,-22} one QIF per entity ({1} QIFs)" -f $p, $qifs.Count)
    }
}
Write-Host ''
Write-Host "$multi of $($provs.Count) provider(s) put >1 QUERYINPUTFORM on a single entity."
