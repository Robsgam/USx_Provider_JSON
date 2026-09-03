# v3.0 SCOPE -- the denominator a from-scratch build must satisfy.
# Step 3d: build every METADATA VARIANT of every DEVDOC-AUTHORIZED transaction. Never every
# combination in the XML: CA_eSUN.xml holds 63 transactions and most are ENTRY/MODIFY/CANCEL record
# operations, a different product surface. Measuring the in-scope denominator first is the point.
#
# SHAPE, learned by inspection rather than assumed (the harness threw on my first two guesses):
#   Get-ProbeMetadata -> hashtable  transactionName -> @{ combos; fields; version }
#   combos[i]        -> @{ keyReference; primaryField; requiredSets }
#   requiredSets     -> LIST OF SETS: each entry is one <Choice> BRANCH, so the true variant count
#                       is the sum of branches, not the combo count.
. "$PSScriptRoot\..\_probe.ps1"
$BASIC = @('ArticleSingleQuery','BoatQuery','DriverHistoryQuery','DriverLicenseQuery','GunQuery','VehicleRegistrationQuery')
$md = Get-ProbeMetadata -Provider 'CA_eSUN'
Write-Output ("metadata transactions parsed: {0}" -f $md.Keys.Count)
Write-Output ""
$combos = 0; $branches = 0
foreach ($nm in ($md.Keys | Sort-Object)) {
    if ($BASIC -notcontains $nm) { continue }
    $cs = @($md[$nm]['combos'])
    Write-Output ("{0}  --  {1} combination(s)" -f $nm, $cs.Count)
    foreach ($c in $cs) {
        $combos++
        $sets = @($c.requiredSets)
        foreach ($s in $sets) {
            $branches++
            Write-Output ("    keyRef={0,-8} PF={1,-28} set=[{2}]" -f $c.keyReference, $c.primaryField, (@($s) -join ','))
        }
    }
}
Write-Output ""
Write-Output ("IN-SCOPE metadata combinations : {0}" -f $combos)
Write-Output ("IN-SCOPE variant BRANCHES      : {0}   <-- what v3.0 must cover" -f $branches)
Assert-ProbeNonZero -Count $branches -What 'in-scope metadata variant branches'
