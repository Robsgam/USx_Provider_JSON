<#
  probe_qidm_helpers.ps1 -- LAW 2 FOR THE QIDM BUILD HELPERS: can Build-Qidm actually refuse?

  Added 2026-09-14 while authoring SC_SLED, the first ground-up provider since the toolchain changed.

  WHY. Build-QidmAttribute and Build-QidmCombo had been in _build_provider_helpers.ps1 for months and
  NO PROVIDER BUILD SCRIPT USED EITHER OF THEM -- all 20 hand-write the PSCustomObject literals. The
  missing piece was the outer envelope (Build-Qidm), so there was nothing to hang them off. That means
  the helpers which make an entire defect class unrepresentable were dead code.

  THE DEFECT CLASS: CA_eSUN v3.0/v3.1 shipped `"conditions": {...}` as an OBJECT and the platform
  rejected the WHOLE FILE (`Cannot deserialize ArrayList<Combination$Condition> from Object value`)
  with ~40 gates green. validate.ps1 now type-checks that subtree, but a gate catches it AFTER the
  fact; the helpers make it unrepresentable. Prefer impossible over detected.

  ⚠️ TWO OF THE CASES BELOW ARE REFUSED BY POWERSHELL'S PARAMETER BINDER, not by the explicit throws
  in Build-Qidm -- the probe prints the binder's message, which is how that was discovered. The
  explicit throws are labelled unreachable in the module rather than deleted, so nobody mistakes them
  for the active mechanism.

  Run: powershell -File tools\_probes\probe_qidm_helpers.ps1     (exit 1 if any case is BROKEN)
  Companion proof, run once and worth re-running after any helper change: the helpers reproduce the
  SHIPPED OR_LEDS_VehicleRegistrationQuery QIDM with an IDENTICAL canonical hash (fc24b544833e9ab3),
  which is why they are trusted to author a new provider.
#>
. 'C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON\tools\_build_provider_helpers.ps1'
$ok = 0; $bad = 0
function T([string]$name, [scriptblock]$sb, [bool]$mustThrow) {
    $threw = $false; $msg = ''
    try { & $sb | Out-Null } catch { $threw = $true; $msg = $_.Exception.Message }
    if ($threw -eq $mustThrow) { "  OK     $name :: $(if($threw){'REFUSED -- ' + ($msg -replace '^Build-Qidm: ','')}else{'allowed'})"; $script:ok++ }
    else { "  BROKEN $name :: expected $(if($mustThrow){'a refusal'}else{'to be allowed'})"; $script:bad++ }
}
$goodAttr  = @(Build-QidmAttribute -Name 'X' -Size 5 -SourceField @('X'))
$goodCombo = @(Build-QidmCombo -KeyReference 'K' -PrimaryFieldReference 'X' -Set @('X'))

T 'CONTROL: a valid QIDM is ALLOWED' { Build-Qidm -ProviderName 'P' -Query 'Q' -TargetEntity 'Person' -QueryLabel 'L' -Attributes $goodAttr -Combinations $goodCombo -Description 'd' } $false
T 'no attributes -> refuse' { Build-Qidm -ProviderName 'P' -Query 'Q' -TargetEntity 'Person' -QueryLabel 'L' -Attributes @() -Combinations $goodCombo -Description 'd' } $true
T 'no combinations -> refuse' { Build-Qidm -ProviderName 'P' -Query 'Q' -TargetEntity 'Person' -QueryLabel 'L' -Attributes $goodAttr -Combinations @() -Description 'd' } $true
T 'keyRef instead of keyReference -> refuse' {
    $c = @([PSCustomObject]@{ requirements=[PSCustomObject]@{set=@('X');any=@()}; primaryFieldReference='X'; keyRef='K'; state='In/Out' })
    Build-Qidm -ProviderName 'P' -Query 'Q' -TargetEntity 'Person' -QueryLabel 'L' -Attributes $goodAttr -Combinations $c -Description 'd' } $true
T 'conditions as an OBJECT (the CA_eSUN import reject) -> refuse' {
    $c = @([PSCustomObject]@{ requirements=[PSCustomObject]@{set=@('X');any=@();conditions=[PSCustomObject]@{field=@('X');operator='EXISTS'}}; primaryFieldReference='X'; keyReference='K'; state='In/Out' })
    Build-Qidm -ProviderName 'P' -Query 'Q' -TargetEntity 'Person' -QueryLabel 'L' -Attributes $goodAttr -Combinations $c -Description 'd' } $true
T 'conditions as an ARRAY -> allowed' {
    $c = @(Build-QidmCombo -KeyReference 'K' -PrimaryFieldReference 'X' -Set @('X') -Conditions @([PSCustomObject]@{field=@('X');operator='EXISTS'}))
    Build-Qidm -ProviderName 'P' -Query 'Q' -TargetEntity 'Person' -QueryLabel 'L' -Attributes $goodAttr -Combinations $c -Description 'd' } $false
''
"  cases: $($ok+$bad) run / $ok correct / $bad broken"
if ($bad) { exit 1 }
