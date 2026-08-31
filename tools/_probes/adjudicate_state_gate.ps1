# Adjudicate Shape-B: an in-state-only combo gated `<State> NOT_EXISTS` with no OOS sibling, so a
# State-bearing fill sends NOTHING. THE ONLY QUESTION (usx-build Step 3): does this transaction's
# metadata define an out-of-state variant our fill should have reached?
#   T1  a variant REQUIRES State (in <Set>) and our fill SATISFIES it -> REAL: missing combination
#   T2  OUR OWN variant -- same keyRef AND same primaryFieldReference -- permits State in <Any>
#       -> REAL: the gate refuses a fill the variant allows (TN_TIES KQ.N inverted)
#   T3b an OOS-capable variant exists but our fill lacks its OTHER mandatory fields
#       -> SPEC-CORRECT: nothing fires because the officer has not supplied the OOS path
#   T3a no variant requires or permits State at all -> SPEC-CORRECT, no OOS path exists
# Reuses tools/_metadata_parse.ps1 for Choice / nested-Set resolution. Only <Any> is read here.
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON'
. "$repo\tools\_sim_helpers.ps1"
. "$repo\tools\_metadata_parse.ps1"
. "$repo\tools\_resolve_provider_json.ps1"
. "$repo\tools\_resolve_provider_xml.ps1"

$items = @(
 'CA_CLETS_OCATS|DriverLicenseQuery|L1.N','CA_SAN_LUIS_OBISPO|DriverHistoryQuery|B2.N',
 'CA_VENTURA_COUNTY|DriverHistoryQuery|IN.B2','CA_eSUN|DriverHistoryQuery|L1.N.DH',
 'CA_eSUN|DriverLicenseQuery|L1.N','CA_eSUN|DriverLicenseQuery|QW.N',
 'CA_eSUN|VehicleRegistrationQuery|QV.P','FL_FCIC|BoatQuery|FBQDecalNumber',
 'FL_FCIC|BoatQuery|FBQTitleLienInformation','FL_FCIC|VehicleRegistrationQuery|FRQDecalNumber',
 'MD_METERS|VehicleRegistrationQuery|ZVEH.P','NM_NMLETS_OFML|VehicleRegistrationQuery|QV.V',
 'NY_NYSPIN_EJUSTICE|VehicleRegistrationQuery|RVEH','OH_LEADS|DriverLicenseQuery|DN',
 'OH_LEADS|DriverLicenseQuery|QWA','OH_LEADS|VehicleRegistrationQuery|RV',
 'TN_TIES|DriverHistoryQuery|DQ05','TN_TIES|DriverLicenseQuery|DQ06')

function Get-MetaOptionalsByKeyRef([string]$XmlPath) {
    [xml]$m = Get-Content $XmlPath -Raw
    $nsm = New-Object System.Xml.XmlNamespaceManager($m.NameTable)
    $ns = $m.DocumentElement.NamespaceURI
    if ($ns) { $nsm.AddNamespace('ns', $ns) }
    $pre = if ($ns) { 'ns:' } else { '' }
    $out = @{}
    foreach ($tx in $m.SelectNodes("//${pre}Transaction[@name]", $nsm)) {
        $tn = $tx.GetAttribute('name')
        foreach ($c in $tx.SelectNodes(".//${pre}Combination", $nsm)) {
            $k = $tn + '|' + $c.GetAttribute('keyReference') + '|' + $c.GetAttribute('primaryFieldReference')
            $opt = @()
            foreach ($f in $c.SelectNodes(".//${pre}Any//${pre}Field", $nsm)) {
                $r = $f.GetAttribute('reference')
                if (-not $r) { $r = $f.GetAttribute('name') }
                if ($r) { $opt += $r }
            }
            $out[$k] = @($opt | Select-Object -Unique)
        }
    }
    return $out
}
function Norm($f) {
    if ("$f" -match '(?i)^name(last|first|middle|suffix)(dh)?$') { return 'Name' }
    return ("$f" -replace 'DH$', '')
}
function HasState($arr) {
    return (@($arr) | Where-Object { "$_" -match '(?i)^state$' }).Count -gt 0
}

$verdicts = @()
foreach ($it in $items) {
  $parts = $it.Split('|'); $p = $parts[0]; $qname = $parts[1]; $bkr = $parts[2]
  $pd  = "$repo\providers\$p"
  $js  = Get-ProviderRootJson -ProvDir $pd -Provider $p
  $xml = Get-ProviderMetadataXml -ProvDir $pd -Provider $p
  if (-not $xml) {
    $verdicts += [pscustomobject]@{P=$p;Q=$qname;K=$bkr;V='NO-VERDICT';E='no metadata XML resolved'}; continue }
  $j = Get-Content $js -Raw | ConvertFrom-Json
  $txs = Get-MetadataTransactions -XmlPath $xml
  $opts = Get-MetaOptionalsByKeyRef $xml
  if (-not $txs.ContainsKey($qname)) {
    $verdicts += [pscustomobject]@{P=$p;Q=$qname;K=$bkr;V='NO-VERDICT';E="transaction '$qname' absent from metadata"}; continue }

  $qidm = $null; $combo = $null
  foreach ($b in $j.bundles) { foreach ($c in $b.configurations) {
    if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and $c.query -eq $qname -and $b.provider -ne 'RMS') {
      foreach ($k in $c.combinations) {
        $kr = if ($k.keyReference) { $k.keyReference } else { $k.keyRef }
        if ("$kr" -eq $bkr) { $qidm = $c; $combo = $k }
      } } } }
  if (-not $combo) {
    $verdicts += [pscustomobject]@{P=$p;Q=$qname;K=$bkr;V='NO-VERDICT';E='built combo not found'}; continue }

  $mapped = @()
  foreach ($sf in @($combo.requirements.set | Where-Object { $_ })) {
    $hit = $null
    foreach ($a in $qidm.attributes) { if (@($a.sourceField) -contains $sf) { $hit = $a; break } }
    $tf = if ($hit) { if ($hit.targetField) { $hit.targetField } else { $hit.name } } else { $sf }
    $mapped += (Norm $tf)
  }
  $mapped = @($mapped | Select-Object -Unique)
  $fill = @($mapped + 'State' | Select-Object -Unique)
  $ourPf = Norm "$($combo.primaryFieldReference)"

  $best = ''
  foreach ($mc in $txs[$qname].combos) {
    $k = "$($mc.keyReference)"
    if ($k -and ($bkr -eq $k -or $bkr -like "$k.*" -or $bkr -like "$k*") -and $k.Length -gt $best.Length) { $best = $k }
  }

  $t1 = @(); $t2 = @(); $t3b = @()
  foreach ($mc in $txs[$qname].combos) {
    $mk = $qname + '|' + $mc.keyReference + '|' + $mc.primaryField
    $permits = HasState $opts[$mk]
    foreach ($alt in @($mc.requiredSets)) {
      $a = @($alt | ForEach-Object { Norm $_ } | Select-Object -Unique)
      if ($a.Count -eq 0) { continue }
      $requires = HasState $a
      if (-not ($permits -or $requires)) { continue }
      $missing = @()
      foreach ($f in $a) {
        if ("$f" -match '(?i)^state$') { continue }
        if (-not ($fill | Where-Object { Test-MetaFieldEquiv $_ $f })) { $missing += $f }
      }
      if ($requires -and $missing.Count -eq 0) {
        $t1 += "$($mc.keyReference){$($mc.primaryField)} Set[$($alt -join ',')]"
      } elseif ($missing.Count) {
        $t3b += "$($mc.keyReference){$($mc.primaryField)} needs also: $($missing -join ',')"
      }
    }
    # T2: SAME VARIANT ONLY -- keyRef AND primaryFieldReference. A keyRef is not a variant.
    if ("$($mc.keyReference)" -eq $best -and (Test-MetaFieldEquiv (Norm "$($mc.primaryField)") $ourPf) -and $permits) {
      $t2 += "$($mc.keyReference){$($mc.primaryField)}"
    }
  }
  $t1 = @($t1 | Select-Object -Unique); $t2 = @($t2 | Select-Object -Unique); $t3b = @($t3b | Select-Object -Unique)

  $v = if ($t1.Count) { 'REAL-T1 missing OOS combination' }
       elseif ($t2.Count) { 'REAL-T2 gate refuses a State its own variant permits' }
       elseif ($t3b.Count) { 'SPEC-CORRECT -- OOS path exists but needs more fields' }
       else { 'SPEC-CORRECT -- no OOS path in metadata at all' }
  $ev = if ($t1.Count) { "metadata REQUIRES State and our fill SATISFIES it: $($t1 -join ' ; ')" }
        elseif ($t2.Count) { "our own variant permits State in <Any>: $($t2 -join ' ; ')" }
        elseif ($t3b.Count) { "OOS-capable variant(s) exist, fill does not satisfy them -- $($t3b -join ' ; ')" }
        else { "no variant of $qname requires OR permits State (our variant: $best{$ourPf})" }
  $verdicts += [pscustomobject]@{P=$p;Q=$qname;K=$bkr;V=$v;E=$ev}
}
''
"  SHAPE-B ADJUDICATION -- $($verdicts.Count) item(s) compared"
'  ============================================================'
foreach ($g in ($verdicts | Group-Object V | Sort-Object Name)) {
  ''
  "  ## $($g.Name)   ($($g.Group.Count))"
  foreach ($r in $g.Group) { "     $($r.P)  $($r.Q)/$($r.K)"; "        $($r.E)" }
}
