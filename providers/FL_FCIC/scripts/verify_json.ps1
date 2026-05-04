$ErrorActionPreference = "Stop"
$path = Join-Path $PSScriptRoot "FL_FCIC_v2.2_test.json"
try {
    $raw = [System.IO.File]::ReadAllText((Resolve-Path $path), [System.Text.UTF8Encoding]::new($false))
    $j = $raw | ConvertFrom-Json
    Write-Host "JSON parse OK" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$personQif = $null
foreach ($b in $j.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -eq "QUERYINPUTFORM" -and $c.targetEntity -eq "Person") {
            $personQif = $c
        }
    }
}

$lk = @($personQif.layout | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
Write-Host "Person layouts: $($lk -join ', ')"

foreach ($l in $lk) {
    $nk = @($personQif.layout.$l | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
    $cards = 0
    $fields = 0
    foreach ($n in $nk) {
        $node = $personQif.layout.$l.$n
        if ($node.type -and $node.type.resolvedName -eq "Card") { $cards++ }
        if ($node.type -and $node.type.resolvedName -match "^Form") { $fields++ }
    }
    Write-Host "  $l : $($nk.Count) nodes, $cards cards, $fields fields"
}
