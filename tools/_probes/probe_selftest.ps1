# Re-runs, THROUGH THE HARNESS, the exact measurements that failed on 2026-08-31.
# Each block names the slip it is proving is now impossible.
. 'C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON\tools\_probe.ps1'

'== 1. provider enumeration (was: hand-glob -> 0 providers) =='
$provs = Get-ProbeProviders
"   providers: $($provs.Count)"

'== 2. QIDM lookup (was: type string QUERYINPUTDATAMAP -> combos 0) =='
$q = Get-ProbeQidms -Provider MD_METERS -Entity Person -Query DriverLicenseQuery
"   MD DL QIDMs: $($q.Count)  combos: $(@($q[0].combinations).Count)"

'== 3. routing (was: named -Qidm/-Filled -> all 8 fills NOTHING FIRES) =='
$fills = @(
  @{ n='Name+Sex+DOB';             f=@{NameLast='DOE';NameFirst='JOHN';SexCode='M';BirthDate='01011980'} },
  @{ n='Name+Sex+DOB+Race';        f=@{NameLast='DOE';NameFirst='JOHN';SexCode='M';BirthDate='01011980';raceCode='W'} },
  @{ n='Name+Sex+DOB+Race+State';  f=@{NameLast='DOE';NameFirst='JOHN';SexCode='M';BirthDate='01011980';raceCode='W';RegistrationState='VA'} },
  @{ n='OLN+Race';                 f=@{OperatorLicenseNumber='D1';raceCode='W'} }
)
foreach ($t in $fills) {
  $r = Get-ProbeFiring -Provider MD_METERS -Entity Person -Fills $t.f
  '   {0,-24} -> {1}' -f $t.n, $(if ($r) { $r } else { '*** NOTHING ***' })
}

'== 4. plan read (was: /c/ path -> EMPTY plan -> "28 combos lose coverage") =='
$plan = Get-ProbePlan -Provider FL_FCIC
"   FL plan tests: $($plan.Count)   logs: $((Get-ProbeLogs -Provider FL_FCIC).Count)"

'== 5. metadata (was: unprefixed XPath vs default namespace -> "OH defines no DL variants") =='
$tx = Get-ProbeMetadata -Provider OH_LEADS
$dl = $tx['DriverLicenseQuery']
"   OH DriverLicenseQuery metadata combinations: $(@($dl.combos).Count)"
$opts = Get-ProbeMetadataOptionals -Provider MD_METERS
"   MD metadata variants with <Any> recorded: $($opts.Keys.Count)"
"   ZWAR{Name} Any = [$(($opts['DriverLicenseQuery|ZWAR|Name']) -join ',')]  (must NOT contain State)"
"   ZLDR{Name} Any = [$(($opts['DriverLicenseQuery|ZLDR|Name']) -join ',')]  (must contain State)"

'== 6. form defaults (was: props.hidden / .nodes level assumed) =='
$fd = Get-ProbeFormDefaults -Provider HI_HCJDC_OFML -Entity Vehicle
"   HI Vehicle defaults: $(($fd.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"

'== 7. registry scope (was: grepped the literal field, not the scope) =='
$dv = Get-ProbeDivergences -Provider FL_FCIC
$ex = @($dv | Where-Object { $_.Class -eq 'existence' })
"   FL registry rows: $($dv.Count)   existence-class: $($ex.Count)"

'== 8. THE ASSERTION ITSELF must throw (LAW 2 for the harness) =='
try { [void](Assert-ProbeNonZero 0 'a deliberately empty measurement'); '   *** FAILED: did not throw' }
catch { "   threw as designed: $($_.Exception.Message.Substring(0,60))..." }
try { [void](Get-ProbeJsonPath -Provider NOT_A_PROVIDER); '   *** FAILED: bogus provider did not throw' }
catch { '   bogus provider name threw as designed' }
''
'SELF-TEST COMPLETE'
