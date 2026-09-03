# FULL v3.0 SPEC: for each devdoc-authorized transaction, every metadata variant with its
# mandatory set[] AND its per-variant <Any> optionals. Optionals are keyed on the FULL triple
# (transaction|keyRef|primaryField) because a keyRef is NOT a variant -- keying on keyRef alone
# makes every branch inherit its siblings' optionals, which is the exact bug that hid 8 real
# over-permits in audit_requirement_fidelity until 2026-09-02.
. "$PSScriptRoot\..\_probe.ps1"
$BASIC = @('ArticleSingleQuery','BoatQuery','DriverHistoryQuery','DriverLicenseQuery','GunQuery','VehicleRegistrationQuery')
$md  = Get-ProbeMetadata -Provider 'CA_eSUN'
$opt = Get-ProbeMetadataOptionals -Provider 'CA_eSUN'
$n = 0
foreach ($tx in $BASIC) {
    if (-not $md.ContainsKey($tx)) { Write-Output "!! $tx NOT IN METADATA"; continue }
    Write-Output "== $tx"
    foreach ($c in @($md[$tx]['combos'])) {
        $k = "$tx|$($c.keyReference)|$($c.primaryField)"
        $o = if ($opt.ContainsKey($k)) { @($opt[$k]) } else { @() }
        foreach ($s in @($c.requiredSets)) {
            $n++
            Write-Output ("   {0,-6} PF={1,-28} SET=[{2}]  ANY=[{3}]" -f $c.keyReference, $c.primaryField, (@($s) -join ','), ($o -join ','))
        }
    }
    Write-Output ("   fields declared: {0}" -f ((@($md[$tx]['fields']) | Sort-Object) -join ', '))
}
Write-Output ""
Write-Output ("TOTAL branches: {0}" -f $n)
Assert-ProbeNonZero -Count $n -What 'v3 spec branches'
