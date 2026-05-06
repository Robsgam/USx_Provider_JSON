# Parse CA_CLETS metadata XML for standard query transactions
param([string]$XmlPath = "$PSScriptRoot\..\source\CA_CLETS.xml")

[xml]$xml = Get-Content $XmlPath
$txns = $xml.InterfaceSchema.States.State.Systems.System.Transactions.Transaction

$targets = @(
    'VehicleRegistrationQuery',
    'DriverLicenseQuery',
    'DriverHistoryQuery',
    'GunQuery',
    'ArticleSingleQuery',
    'BoatQuery',
    'WMPIWantedPersonQuery',
    'WMPIMissingPersonQuery'
)

foreach ($t in $targets) {
    $tx = $txns | Where-Object { $_.name -eq $t }
    if ($tx) {
        Write-Output "=== $($tx.name) v$($tx.version) ==="
        foreach ($f in $tx.Fields.Field) {
            $desc = if ($f.maxLength) { "max=$($f.maxLength)" } else { "" }
            $vl = if ($f.valueListName) { " valueList=$($f.valueListName)" } else { "" }
            $comp = if ($f.Components) { " components=[$($f.Components.Component.name -join ',')]" } else { "" }
            Write-Output "  Field: $($f.name) type=$($f.type) $desc$vl$comp"
        }
        foreach ($c in $tx.Combinations.Combination) {
            $sets = @()
            $anys = @()
            foreach ($req in $c.Requirements.Set.ChildNodes) {
                if ($req.LocalName -eq 'Field') { $sets += $req.reference }
                elseif ($req.LocalName -eq 'Any') {
                    foreach ($af in $req.ChildNodes) {
                        if ($af.LocalName -eq 'Field') { $anys += $af.reference }
                    }
                }
            }
            Write-Output "  Combo: keyRef=$($c.keyReference) primary=$($c.primaryFieldReference)"
            Write-Output "         set=[$($sets -join ', ')] any=[$($anys -join ', ')]"
        }
        Write-Output ""
    } else {
        Write-Output "=== $t === NOT FOUND"
        Write-Output ""
    }
}
