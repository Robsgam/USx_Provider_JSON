<#
  sweep_mined_keyref_shadow.ps1 -- WHICH BUILT COMBOS ARE ATTRIBUTED TO A DATA-MINED KEYREF WHEN
  THE STATE'S OWN NON-MINED SIBLING WOULD DO?

  WHY THIS EXISTS. Rob, 2026-09-03, reading the regenerated officer guides:
    "you are exposing qv queries which are supposed to be mined and not built"
    "looking at il again. i see qg and not zf. i think you missed the markl again with the shadow
     query. please reveiw system wide for shadow problems theis guide is exposing"

  The officer guide only started printing the METADATA keyRef an hour earlier. That change did not
  create this -- it REVEALED it. The sheets now advertise QV / QG / QB rows to officers, which name
  NCIC transactions the STATE RUNS FOR US off our single request (declared on 16 of 20 devdocs as
  "NCIC (QA, QB, QG, QV, QW) ... Tags returned from Data mining"), rather than the state's own
  registration/records transaction that we are actually asking for.

  WHAT IS AND IS NOT AT STAKE -- READ THIS BEFORE "FIXING" ANYTHING.
  A keyRef NEVER REACHES THE WIRE (verified against a live capture; the request carries
  <MessageType><QueryName></MessageType> plus fields and nothing else). So choosing QV over 4V
  changes NO BYTE that is transmitted. This is an ATTRIBUTION defect, not a wire defect, and that
  is exactly why every existing gate is silent on it:
    - audit_query_trace matches on REQUIREMENTS, so QV.V satisfying 4V's variant reads COMPLETE.
    - audit_data_mined DM1 reports mined-named combos as "EXPECTED, not a gap" -- correct, on its
      own question, which is whether the mined SIBLING needs building (it does not).
    - audit_requirement_fidelity compares the branch it pairs to, and either pairing is legal.
  It matters anyway, for three reasons: the officer guide now shows the name to a department; our
  SQVR/registry/log-attribution all reason by keyRef; and a reader who checks the state manual for
  "QG" finds a stolen-gun hit query where we meant a firearms-records query.

  CLASSES
    EXPOSED   the built combo resolves to a MINED keyRef, an identical-requirement NON-MINED
              sibling exists in the same transaction for the same primaryField, and NOTHING ELSE
              builds that sibling. This is the actionable one: re-attribute (rename the built
              keyRef), no wire change.
    COVERED   same shape, but the non-mined sibling IS separately built -- so the mined-named
              combo is a genuine additional path, not a substitution. Not actionable.
    ONLY      the mined keyRef is the only variant with those requirements. Legitimately named.

  Every count is printed. A run that compares zero combos says so instead of passing.
#>
param([string[]]$Providers, [switch]$Quiet)

. "$PSScriptRoot\..\_probe.ps1"

# The mined token list is not invented here -- it is the set the devdocs themselves name on the
# "Data-Mined Transactions" line, which audit_data_mined already parses and 16 providers declare.
$MINED = @('QV','QW','QA','QB','QG')

$scope = if ($Providers) { $Providers } else { Get-ProbeProviders }
Assert-ProbeNonZero $scope.Count 'providers in scope'

$rowsCompared = 0
$exposed = @(); $covered = @(); $only = @(); $orphan = @()

foreach ($p in $scope) {
    $tx = Get-ProbeMetadata -Provider $p
    $built = Get-ProbeCombos -Provider $p
    foreach ($r in $built) {
        if (-not $tx.ContainsKey($r.Query)) { continue }
        $rowsCompared++
        $stem = ($r.KeyRef -replace '\.[A-Za-z0-9]+$','')
        if ($MINED -notcontains $stem) { continue }

        $variants = @($tx[$r.Query].combos)
        # A metadata <Combination> MAY DECLARE NO primaryFieldReference at all -- HI_HCJDC_OFML's
        # ArticleSingleQuery is literally `<Combination keyReference="QA">`. Requiring PF equality
        # made that variant invisible and reported HI's perfectly-correct `QA` as an ORPHAN. A
        # PF-less metadata variant matches ANY primaryField; treating absence as a mismatch is the
        # probe being wrong, not the build.
        $mine = @($variants | Where-Object {
            "$($_['keyReference'])" -eq $stem -and
            ((-not "$($_['primaryField'])") -or "$($_['primaryField'])" -eq $r.PrimaryField) })
        if ($mine.Count -eq 0) {
            # HOLE CLOSED 2026-09-03, found by Rob asking about IL's QG-vs-ZF and my sweep having
            # nothing to say. The first cut did `continue` here, which SILENTLY DROPPED the worst
            # case of all: a built combo named after a mined transaction that the metadata does not
            # even define for that query -- i.e. a name with no authority behind it at all. Skipping
            # it made the sweep quiet on exactly the shape it was written to find.
            $orphan += [pscustomobject]@{ Provider=$p; Entity=$r.Entity; Built=$r.KeyRef; Shown=$stem
                                          Sibling='(no such metadata variant)'; PrimaryField=$r.PrimaryField }
            continue
        }
        $sig = ((@($mine[0]['requiredSets']) | ForEach-Object { ($_ | Sort-Object) -join '+' }) | Sort-Object) -join ' | '

        $sibs = @($variants | Where-Object {
            $sk = "$($_['keyReference'])"
            $sk -ne $stem -and ($MINED -notcontains $sk) -and
            "$($_['primaryField'])" -eq $r.PrimaryField -and
            (((@($_['requiredSets']) | ForEach-Object { ($_ | Sort-Object) -join '+' }) | Sort-Object) -join ' | ') -eq $sig
        })
        if ($sibs.Count -eq 0) {
            $only += [pscustomobject]@{ Provider=$p; Entity=$r.Entity; Built=$r.KeyRef; Shown=$stem; Sibling='--' }
            continue
        }
        foreach ($s in $sibs) {
            $sk = "$($s['keyReference'])"
            # Is that sibling ALREADY implemented by some other built combo in this same query?
            $sibBuilt = @($built | Where-Object {
                $_.Query -eq $r.Query -and (($_.KeyRef -replace '\.[A-Za-z0-9]+$','') -eq $sk) }).Count
            $rec = [pscustomobject]@{ Provider=$p; Entity=$r.Entity; Built=$r.KeyRef; Shown=$stem
                                      Sibling=$sk; PrimaryField=$r.PrimaryField; SiblingBuilt=$sibBuilt }
            if ($sibBuilt -gt 0) { $covered += $rec } else { $exposed += $rec }
        }
    }
}

Assert-ProbeNonZero $rowsCompared 'built combinations compared'

if (-not $Quiet) {
    Write-Output ''
    Write-Output '=================================================================================='
    Write-Output '  MINED-KEYREF ATTRIBUTION SWEEP -- what the officer guides are exposing'
    Write-Output '=================================================================================='
    Write-Output ("  scope: {0} provider(s) / {1} built combination(s) compared / mined tokens: {2}" -f `
        $scope.Count, $rowsCompared, ($MINED -join ' '))
    Write-Output ''
    Write-Output '  [EXPOSED] mined keyRef shown, identical non-mined sibling exists and is NOT built:'
    if ($exposed.Count -eq 0) { Write-Output '     none' }
    else {
        foreach ($e in ($exposed | Sort-Object Provider, Entity, Built)) {
            Write-Output ("     {0,-22} {1,-9} built '{2}' shows '{3}'  ->  should be '{4}'  [{5}]" -f `
                $e.Provider, $e.Entity, $e.Built, $e.Shown, $e.Sibling, $e.PrimaryField)
        }
    }
    Write-Output ''
    Write-Output ("  [COVERED] non-mined sibling separately built -- NOT actionable: {0}" -f $covered.Count)
    foreach ($c in ($covered | Sort-Object Provider, Built)) {
        Write-Output ("     {0,-22} {1,-9} '{2}' alongside built '{3}'" -f $c.Provider, $c.Entity, $c.Built, $c.Sibling)
    }
    Write-Output ''
    Write-Output ("  [ORPHAN] named after a mined token with NO such metadata variant in that query: {0}" -f $orphan.Count)
    foreach ($o in ($orphan | Sort-Object Provider, Built)) {
        Write-Output ("     {0,-22} {1,-9} built '{2}' -- the query defines no '{3}' variant at all" -f `
            $o.Provider, $o.Entity, $o.Built, $o.Shown)
    }
    Write-Output ''
    Write-Output ("  [ONLY] mined keyRef is the only variant with those requirements -- correctly named: {0}" -f $only.Count)
    Write-Output ''
    Write-Output ("  TOTALS: EXPOSED {0} / ORPHAN {1} / COVERED {2} / ONLY {3}" -f `
        $exposed.Count, $orphan.Count, $covered.Count, $only.Count)
    Write-Output '  A keyRef never reaches the wire -- EXPOSED items are an ATTRIBUTION fix (rename the'
    Write-Output '  built keyRef), never a change to what is transmitted.'
    Write-Output '=================================================================================='
}
Write-Output @($exposed) -NoEnumerate
