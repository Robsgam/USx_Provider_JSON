# Does CA_eSUN metadata define OriginatingAgencyORI on ANY transaction?
# Decides whether v2 may drop the attribute outright or must keep it where defined.
. "$PSScriptRoot\..\_probe.ps1"
$md = Get-ProbeMetadata -Provider 'CA_eSUN'
Assert-ProbeNonZero -Count @($md.Transactions).Count -What 'metadata transactions'
Write-Output ("transactions parsed: {0}" -f @($md.Transactions).Count)
$raw = Get-Content $md.Path -Raw
$names = [regex]::Matches($raw,'(?i)Name="([A-Za-z]*(?:OriginatingAgency|^ORI$)[A-Za-z]*)"') |
         ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Write-Output ("distinct ORI-ish field names anywhere in the XML: {0}" -f @($names).Count)
@($names) | ForEach-Object { "   $_" }
$exact = ([regex]::Matches($raw,'OriginatingAgencyORI')).Count
Write-Output ("literal 'OriginatingAgencyORI' occurrences in metadata: {0}" -f $exact)
