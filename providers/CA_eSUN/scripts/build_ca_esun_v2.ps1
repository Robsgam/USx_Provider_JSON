# CA_eSUN v2.0 -- FIRST BUILD OF THE ENGINEERED LINE.
#
# Rob 2026-09-02: "anything after 1.1 will be its own line ... at some point we will need to build
# out the json like the others", and for this version: "fixes as much as possible in the
# combinations without makign any changes to the cad interoperability and no form changes except
# maybe some field labels", then "drop the ori and build v2".
#
# So v2.0 DERIVES from v1.1 and touches QIDMs ONLY. It is deliberately NOT yet a from-scratch build
# like the other 19 providers -- that is the "at some point" step. Deriving is what lets the script
# ASSERT the layout is byte-identical; a ground-up rebuild could not promise that.
#
# THREE CHANGES, ALL INSIDE QUERYINPUTDATAMAPPING:
#   A. drop the OriginatingAgencyORI attribute from every QIDM
#   B. order combinations most-specific-first (a strict superset must precede its subset)
#   C. RQLicensePlateTypeYearOut: LicensePlateTypeCode + LicensePlateYear any[] -> set[]
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$repo = Split-Path $repo -Parent
$src  = Join-Path $repo 'providers\CA_eSUN\docs\deliverables\CA_eSUN_v1.1_RADIOBUTTON.json'
$dst  = Join-Path $repo 'providers\CA_eSUN\CA_eSUN_v2.0.json'
if (-not (Test-Path $src)) { throw "ABORT: v1.1 source not found at $src" }

$j = Get-Content $src -Raw | ConvertFrom-Json

function Get-Qidms($o) {
  $r = @()
  foreach ($b in $o.bundles) {
    foreach ($c in $b.configurations) {
      if ("$($c.type)" -eq 'QUERYINPUTDATAMAPPING' -and "$($c.provider)" -ne 'RMS') { $r += $c }
    }
  }
  return ,$r
}

# ---- census BEFORE ----------------------------------------------------------------------
$q0 = Get-Qidms $j
$combo0 = (@($q0) | ForEach-Object { @($_.combinations).Count } | Measure-Object -Sum).Sum
$ori0 = (@($q0) | Where-Object { @($_.attributes) | Where-Object { "$($_.targetField)" -eq 'OriginatingAgencyORI' } }).Count
Write-Output ("BEFORE: {0} QIDMs / {1} combinations / {2} carry OriginatingAgencyORI" -f @($q0).Count, $combo0, $ori0)
if (@($q0).Count -eq 0) { throw "ABORT: no CommSys QIDMs found -- the transform would be a silent no-op" }

# ---- A. drop the ORI attribute -----------------------------------------------------------
# Devdoc line 8 scopes <OriginatingAgencyORI> to running a transaction ON BEHALF OF ANOTHER AGENCY,
# or to an ENTRY/EDIT transaction (suffix Entry|Modify|Clear|Locate|Cancel). We build neither --
# all 8 query mappings are Query transactions. It is also PROVEN INERT here: across 25 committed
# v1.1 logs it carries the SAME value as <Authentication>/<ORI> ('MK1234567' x21), so the devdoc's
# "ConnectCIC may replace the Authentication/ORI value with the provided OriginatingAgencyORI" is a
# no-op today. Removing it stops the send that fails gate 6d without changing a transmitted value.
$dropped = 0
foreach ($c in $q0) {
  $keep = @(@($c.attributes) | Where-Object { "$($_.targetField)" -ne 'OriginatingAgencyORI' })
  $dropped += (@($c.attributes).Count - $keep.Count)
  $c.attributes = $keep
}
Write-Output ("A1. OriginatingAgencyORI attributes removed: {0}" -f $dropped)
if ($dropped -eq 0) { throw "ABORT: expected to remove ORI attributes, removed none" }

# A2. ...and the OTHER half of the drop, which the first pass missed: bare 'ORI' rides in 20
# combinations' any[]. Devdoc line 8 puts the device/site ORI in <Authentication>/<ORI> -- the
# ConnectCIC HEADER -- and it is already an AUTHENTICATION attribute here (ORI, Mnemonic, DeviceId,
# UserName). Carrying it in a combination's any[] additionally offers it as a QUERY-BODY field,
# which no transaction's metadata defines; that is the residual OVER-PERMITTED finding. Removing it
# from any[] does NOT touch the envelope, so the authenticated ORI still transmits exactly as today.
$oriAny = 0
foreach ($c in $q0) {
  foreach ($cb in @($c.combinations)) {
    $any = @($cb.requirements.any)
    $trimmed = @($any | Where-Object { $_ -ne 'ORI' })
    if ($trimmed.Count -ne $any.Count) { $oriAny++ }
    $cb.requirements.any = $trimmed
  }
}
Write-Output ("A2. bare 'ORI' removed from combination any[]: {0}" -f $oriAny)

# ---- C. RQ under-required (BEFORE ordering, so ordering sees the final sets) --------------
$rqFixed = 0
foreach ($c in $q0) {
  foreach ($cb in @($c.combinations)) {
    if ("$($cb.keyReference)" -ne 'RQLicensePlateTypeYearOut') { continue }
    $set = @($cb.requirements.set)
    $any = @($cb.requirements.any)
    foreach ($f in @('LicensePlateTypeCode', 'LicensePlateYear')) {
      if ($set -notcontains $f) { $set += $f; $rqFixed++ }
      $any = @($any | Where-Object { $_ -ne $f })
    }
    $cb.requirements.set = $set
    $cb.requirements.any = $any
  }
}
Write-Output ("C. RQLicensePlateTypeYearOut promoted any[] -> set[]: {0}" -f $rqFixed)

# ---- B. ordering: SUBSET is the hard constraint, IDENTIFIER PRIORITY is the tiebreak ---------
# NOT a size sort. The rule is the SUBSET relation: if A's set[] is a strict subset of B's, then A
# matches whenever B does, so A ahead of B makes B unreachable.
#
# THE TIEBREAK IS LOAD-BEARING AND MY FIRST DRAFT GOT IT WRONG. A pure subset sort put
# L1OperatorLicenseNumberIn (the OLN search) LAST on DriverLicenseQuery, behind all four Name
# combos -- so an officer filling OLN *and* a full name would have fired the Name query. That is
# forced by the subset relation, not a quirk: L1NameIn sat first in the live config with three
# supersets behind it, so all three must move ahead of it, and OLN falls off the end.
# The portfolio convention (11 providers carry "identifier-priority guardrails") is Plate > VIN >
# SSN > Name, OLN > Name, Hull > Reg. So among combos with NO subset relationship, the one whose
# set[] carries the stronger identifier goes first. Rank 0 = strongest.
$identRank = @(
  @('LicensePlateNumber'), @('VehicleIdentificationNumber'), @('BoatHullIdNumber'),
  @('OperatorLicenseNumber'), @('RegistrationNumber'), @('FirearmSerialNumber'),
  @('ArticleSerialNumber'), @('SocialSecurityNumber'), @('LojackId', 'LojackID')
)
function Get-IdentRank($setFields) {
  for ($r = 0; $r -lt $identRank.Count; $r++) {
    foreach ($tok in $identRank[$r]) { if ($setFields -contains $tok) { return $r } }
  }
  return 99   # no recognised identifier (name-only paths) -- weakest, sorts last
}
$reordered = 0
foreach ($c in $q0) {
  $orig = @($c.combinations)
  if ($orig.Count -lt 2) { continue }
  $out = New-Object System.Collections.ArrayList
  foreach ($cb in $orig) {
    $mySet = @($cb.requirements.set)
    $myRank = Get-IdentRank $mySet
    $idx = $out.Count
    for ($i = 0; $i -lt $out.Count; $i++) {
      $other = @($out[$i].requirements.set)
      $foreign = @($other | Where-Object { $mySet -notcontains $_ }).Count
      $isStrictSubset = ($other.Count -lt $mySet.Count) -and ($foreign -eq 0)
      # hard constraint: I am a strict superset of what is placed here, so I must precede it
      if ($isStrictSubset) { $idx = $i; break }
      # tiebreak: neither contains the other, and I carry the stronger identifier
      $otherRank = Get-IdentRank $other
      $mineForeign = @($mySet | Where-Object { $other -notcontains $_ }).Count
      $unrelated = ($foreign -gt 0) -and ($mineForeign -gt 0)
      if ($unrelated -and ($myRank -lt $otherRank)) { $idx = $i; break }
    }
    [void]$out.Insert($idx, $cb)
  }
  $before = (($orig | ForEach-Object { "$($_.keyReference)" }) -join ' > ')
  $after = (($out | ForEach-Object { "$($_.keyReference)" }) -join ' > ')
  if ($before -ne $after) {
    $reordered++
    Write-Output ("   reordered {0}" -f $c.name)
    Write-Output ("      was: {0}" -f $before)
    Write-Output ("      now: {0}" -f $after)
  }
  $c.combinations = @($out)
}
Write-Output ("B. QIDMs reordered: {0}" -f $reordered)

# ---- version ------------------------------------------------------------------------------
foreach ($b in $j.bundles) {
  if ("$($b.provider)" -eq 'CA_eSUN') {
    $b.description = "Provider configuration for CA_eSUN v2.0 -- ENGINEERED LINE, separate from the San Diego Sheriff live v1.0/v1.1 line. Derived from v1.1: layout byte-identical, radio-group PurposeCode retained. QIDM-only fixes: OriginatingAgencyORI attribute removed (devdoc scopes it to entry/edit and on-behalf-of; proven identical to Authentication/ORI across 25 logs), combinations ordered most-specific-first, RQLicensePlateTypeYearOut requirements aligned to metadata."
  }
}

[IO.File]::WriteAllText($dst, ($j | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
Write-Output ""
Write-Output ("wrote: {0}" -f (Split-Path $dst -Leaf))

# ---- verify from disk ----------------------------------------------------------------------
$v = Get-Content $dst -Raw | ConvertFrom-Json
$q1 = Get-Qidms $v
$combo1 = (@($q1) | ForEach-Object { @($_.combinations).Count } | Measure-Object -Sum).Sum
$ori1 = (@($q1) | Where-Object { @($_.attributes) | Where-Object { "$($_.targetField)" -eq 'OriginatingAgencyORI' } }).Count
Write-Output ("AFTER : {0} QIDMs / {1} combinations / {2} carry OriginatingAgencyORI" -f @($q1).Count, $combo1, $ori1)
if ($combo1 -ne $combo0) { throw "ABORT: combination count moved $combo0 -> $combo1; v2 must not add or drop a combination" }
if ($ori1 -ne 0) { throw "ABORT: OriginatingAgencyORI still present on $ori1 QIDM(s)" }

# LAYOUT MUST BE BYTE-IDENTICAL -- the promise to Rob, so it is ASSERTED, not assumed.
function Get-LayoutSig($o) {
  $parts = @()
  foreach ($b in $o.bundles) {
    foreach ($c in $b.configurations) {
      if ("$($c.type)" -eq 'QUERYINPUTFORM') { $parts += "$($c.targetEntity)=" + ($c.layout | ConvertTo-Json -Depth 60 -Compress) }
    }
  }
  return (($parts | Sort-Object) -join '')
}
$h0 = Get-LayoutSig (Get-Content $src -Raw | ConvertFrom-Json)
$h1 = Get-LayoutSig $v
Write-Output ("LAYOUT identical to v1.1: {0}" -f ($h0 -eq $h1))
if ($h0 -ne $h1) { throw "ABORT: layout changed -- v2 must not touch cards, controls or widths" }
