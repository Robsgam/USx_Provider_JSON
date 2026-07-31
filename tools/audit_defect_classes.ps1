<#
  audit_defect_classes.ps1 -- scan EVERY provider for the defect classes we have PROVEN real.

  ############################################################################################
  ##  EXPERIMENTAL -- DO NOT QUOTE ITS OUTPUT AS FINDINGS. NOT WIRED INTO ANY GATE.          ##
  ##                                                                                          ##
  ##  KNOWN-ANSWER TEST: run it against the CA family, whose true state was established BY HAND ##
  ##  on 2026-07-31. The correct answer is EXACTLY ONE row -- CA_VENTURA_COUNTY GunQuery/       ##
  ##  IG.QGH, which carries no discriminator at all. Four runs so far:                          ##
  ##    run 1 -> 19 candidates. No field aliasing (metadata 'Age' vs built 'GunAge', so it      ##
  ##             flagged the very combos just FIXED) and no variant matching by                 ##
  ##             primaryFieldReference (compared the built CII combo against the {Name} Choice).##
  ##    run 2 -> 9.  Both of the above addressed.                                               ##
  ##    run 3 -> 7.  Bidirectional anchored alias (CaRequestPurposeCode <-> purposeCode).       ##
  ##                 CA_CLETS fully cleared.                                                    ##
  ##    run 4 -> 6.  Removed a >=4 length floor I had added myself, which killed the 3-char     ##
  ##                 'Age' and re-broke run 1's case. CA_eSUN cleared.                          ##
  ##                                                                                            ##
  ##  REMAINING BUG -- symptom isolated, CAUSE NOT FOUND. The 5 CA_CONTRA_COSTA IR.QVC.* rows   ##
  ##  are ALL FALSE and they prove the primaryFieldReference restriction is not taking effect.  ##
  ##  Verified straight from CC metadata: IR.QVC{Name} has 5 variants of which 2 are LOOSER     ##
  ##  (Choice inside <Any>), so IR.QVC.N must be suppressed; and the {CriminalIdNumber},        ##
  ##  {OperatorLicenseNumber} and {SocialSecurityNumber} families contain ONLY looser variants  ##
  ##  with no Choice-in-Set at all, so IR.QVC.C/.O/.OS/.S should never have been compared       ##
  ##  against the {Name} variant. Their PFs ARE correctly declared in the JSON. Next step:      ##
  ##  instrument the $fam narrowing and the $looser predicate rather than guessing again.       ##
  ##                                                                                            ##
  ##  Do not wire this anywhere until the CA-family run yields exactly CA_VENTURA_COUNTY.       ##
  ##  A scanner that cries wolf on fixed providers is worse than no scanner -- it teaches the   ##
  ##  next session to ignore it.                                                                ##
  ############################################################################################

  Rob 2026-07-31: "i want this process to be fruitful."

  WHY THIS EXISTS. By the end of 2026-07-31 the session had found the same handful of defect classes
  over and over, one provider at a time, each time re-deriving it from scratch: read the metadata,
  notice a Choice inside <Set>, check the devdoc brackets, decide FIX vs REGISTER. That is fine for
  the first provider and wasteful by the fourth. The classes are now KNOWN, so they should be
  ENUMERATED across the portfolio in one pass and ranked -- turning 13 sequential investigations into
  one triage list.

  It reads each provider's OWN metadata and OWN devdoc. It never assumes one provider's answer
  applies to a sibling: CA_CLETS_OCATS and CA_SAN_LUIS_OBISPO looked like certain suspects for the
  gun-name class and were both CLEAN, because they build only the serial-number query.

  THE CLASSES, each with the shipped defect that proved it:

  C1  COLLAPSED CHOICE       metadata has a <Choice> as a DIRECT child of <Set> (= one of its fields
      (wire-invalid)         is MANDATORY) but the built combo carries them all in any[], or carries
                             none at all. The request satisfies NO metadata variant.
                             Proven: CA_CLETS IG.QGH shipped a committed PASS log doing exactly this;
                             CA_CONTRA_COSTA and CA_eSUN carried it identically; CA_VENTURA_COUNTY
                             carries the worse form (no discriminator at all).
                             Gate 6d catches it. 6c and 2i CANNOT -- content and attribution cannot
                             see a MISSING REQUIREMENT.

  C2  OVER-REQUIRED SET      a field is in the built set[] that NO metadata variant of that keyRef
      (silent field drop)    makes mandatory. Effect is not just strictness: the fill falls through to
                             a later, looser combo whose pool may not carry the extra field, so the
                             officer's value is accepted by the form and never transmitted.
                             Proven: CA_CLETS/CA_CONTRA_COSTA IR.QVC.O required criminalIdNumber, so
                             OLN+SSN fell to ID.L1 (no optionals) and the SSN vanished.

  C3  OPTIONAL CARRIED       a field some metadata variant of that keyRef permits as an optional is
      NOWHERE                in NO built combo's set[] or any[] for that query. The officer can type
                             it and it can never reach the wire.
                             Proven: CA_CLETS NLTS.DQ.N could not carry SexCode at all.

  C4  PREFILL ON A ROUTING   a form initialValue on a field that appears in some combo's set[].
      FIELD                  Makes it always-present, permanently hiding every combo needing its
                             absence. BUILD_RULES 24. Killed 35 combos across 6 providers.
                             NOT flagged when the field is in EVERY combo's set[] for that query --
                             then it cannot shadow one over another (CA's purposeCode='C' is
                             harmless, and a reverse-propagation flag wrongly blamed it TWICE).

  RANKING. C1 and C2 are WIRE defects -- a request that is invalid, or an officer value silently
  discarded. C3 is a capability gap. C4 is a reachability defect. Sorted accordingly.

  EVERY finding is a CANDIDATE with evidence attached, not a verdict. The FIX-vs-REGISTER call needs
  the devdoc check and is Rob's (see usx-build Step 3). A looser metadata variant legitimately
  permitting what we built is the REGISTER case, and this tool says so when it sees one.

  Usage: .\audit_defect_classes.ps1 [-Providers <list>] [-All] [-Class C1,C2] [-OutFile <path>]
#>
param(
    [string[]]$Providers,
    [switch]$All,
    [string[]]$Class = @('C1','C2','C3','C4'),
    [string]$OutFile
)

$ErrorActionPreference = 'Continue'
$repo    = Split-Path $PSScriptRoot -Parent
$toolDir = $PSScriptRoot
. (Join-Path $toolDir '_resolve_provider_json.ps1')

$lines = @()
function E([string]$s, $c = 'Gray') { $script:lines += $s; if ($c) { Write-Host $s -ForegroundColor $c } else { Write-Host $s } }
function Canon([string]$s) { return ($s -replace '[^A-Za-z0-9]', '').ToLower() }

# Metadata names a field 'Age'/'BirthDate'; a build may prefix it per entity or per DH card
# (CA_eSUN uses GunAge/GunBirthDate, DH cards use BirthDateDH, CA Vehicle uses VehBirthDate). A bare
# Canon comparison therefore MISSED the very combos just fixed and flagged them as defects -- caught
# by the known-answer test on 2026-07-31, which is exactly why that test exists. Match on containment
# in EITHER direction, anchored so 'age' cannot match 'imageindicator' or 'salvage'.
function Test-FieldSame([string]$metaField, [string]$builtField) {
    $m = Canon $metaField; $b = Canon $builtField
    if (-not $m -or -not $b) { return $false }
    if ($m -eq $b) { return $true }
    # Anchored containment in BOTH directions. The build may PREFIX per entity/card (GunAge,
    # VehBirthDate, BirthDateDH) or the metadata name may be LONGER than the built one
    # (metadata CaRequestPurposeCode <-> built purposeCode; metadata State <-> built
    # RegistrationState). Only a shared prefix or suffix counts, never a mid-word hit, so 'Age'
    # cannot match 'imageindicator' and 'Name' cannot match 'NCICNumber'.
    # A >=4 length floor was WRONG: it killed 'Age' (3 chars) so CA_eSUN's GunAge stopped matching
    # and the combos just fixed were flagged again. Short metadata names are real ('Age', 'Sex').
    # For them, only accept the ENTITY-PREFIX shape (built ENDS WITH meta, e.g. GunAge/VehAge) --
    # that is the pattern builds actually use, and it avoids the loose hits a bare contains would give.
    if ($m.Length -lt 4) { return $b.EndsWith($m) }
    if ($b.Length -lt 4) { return $m.EndsWith($b) }
    if ($b.StartsWith($m) -or $b.EndsWith($m)) { return $true }
    if ($m.StartsWith($b) -or $m.EndsWith($b)) { return $true }
    return $false
}
function Test-InList([string]$metaField, [string[]]$builtList) {
    foreach ($bf in $builtList) { if (Test-FieldSame $metaField $bf) { return $true } }
    return $false
}

if ($All -or -not $Providers) {
    $Providers = @(Get-ChildItem (Join-Path $repo 'providers') -Directory | Sort-Object Name | ForEach-Object { $_.Name })
}

$findings = @()

foreach ($p in $Providers) {
    $d  = Join-Path $repo "providers\$p"
    $jp = Get-ProviderRootJson -ProvDir $d -Provider $p
    if (-not $jp) { continue }
    $ver = [regex]::Match([IO.Path]::GetFileNameWithoutExtension($jp), '_v([\d.]+)$').Groups[1].Value
    $xf  = @(Get-ChildItem (Join-Path $d 'source') -Filter '*.xml' -File -ErrorAction SilentlyContinue) | Select-Object -First 1
    if (-not $xf) { continue }

    try { [xml]$x = Get-Content $xf.FullName -Raw } catch { E "  [SKIP] $p -- metadata XML unparseable" 'DarkYellow'; continue }
    try { $j = Get-Content $jp -Raw | ConvertFrom-Json } catch { E "  [SKIP] $p -- JSON unparseable" 'DarkYellow'; continue }

    # ── built combos, per query ────────────────────────────────────────────────────────────────
    $built = @{}   # query -> list of @{KeyRef; Set; Any}
    $forms = @{}   # fieldId -> initialValue (non-empty only)
    foreach ($b in $j.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and "$($c.provider)" -ne 'RMS' -and "$($c.name)" -notmatch '^RMS ') {
            $q = "$($c.query)"; if (-not $q) { continue }
            if (-not $built.ContainsKey($q)) { $built[$q] = @() }
            foreach ($cm in @($c.combinations)) {
                $built[$q] += [pscustomobject]@{
                    KeyRef = "$($cm.keyReference)"
                    Set    = @($cm.requirements.set | Where-Object { $_ })
                    Any    = @($cm.requirements.any | Where-Object { $_ })
                    PF     = "$($cm.primaryFieldReference)"
                }
            }
        }
        if ($c.type -eq 'QUERYINPUTFORM') {
            $lay = $c.layout.'default'
            if ($lay) { foreach ($nid in $lay.PSObject.Properties.Name) {
                $fid = "$($lay.$nid.props.fieldId)"; $iv = "$($lay.$nid.props.initialValue)"
                if ($fid -and $iv) { $forms[$fid] = $iv }
            } }
        }
    } }
    if (-not $built.Count) { continue }

    # ── metadata combinations: keyRef -> list of @{PF; MandDirect; ChoiceInSet; AnyFields} ─────
    $meta = @()
    foreach ($n in $x.SelectNodes("//*[local-name()='Combination']")) {
        $kr = $n.GetAttribute('keyReference'); if (-not $kr) { continue }
        $req = $n.SelectSingleNode("*[local-name()='Requirements']"); if (-not $req) { continue }
        $setNode = $req.SelectSingleNode("*[local-name()='Set']");    if (-not $setNode) { continue }

        # direct-child <Choice> inside <Set> => exactly one of its fields is MANDATORY
        $choiceInSet = @()
        foreach ($ch in $setNode.ChildNodes) {
            if ($ch.LocalName -ne 'Choice') { continue }
            foreach ($f in $ch.ChildNodes) { if ($f.LocalName -eq 'Field') { $choiceInSet += $f.GetAttribute('reference') } }
        }
        # mandatory scalar fields: direct <Field> children of <Set>, plus nested <Set> groups
        $mand = @()
        foreach ($ch in $setNode.ChildNodes) {
            if ($ch.LocalName -eq 'Field') { $mand += $ch.GetAttribute('reference') }
            elseif ($ch.LocalName -eq 'Set') { foreach ($f in $ch.ChildNodes) { if ($f.LocalName -eq 'Field') { $mand += $f.GetAttribute('reference') } } }
        }
        # optionals: anything under an <Any>, including a Choice nested inside Any
        $opt = @()
        foreach ($anyNode in $setNode.SelectNodes(".//*[local-name()='Any']")) {
            foreach ($f in $anyNode.SelectNodes(".//*[local-name()='Field']")) { $opt += $f.GetAttribute('reference') }
        }
        $meta += [pscustomobject]@{
            KeyRef = $kr; PF = $n.GetAttribute('primaryFieldReference')
            Mand = @($mand | Where-Object { $_ }); ChoiceInSet = @($choiceInSet | Where-Object { $_ }); Opt = @($opt | Where-Object { $_ })
        }
    }
    if (-not $meta.Count) { continue }

    # map a built keyRef to its metadata family: exact, or the longest metadata keyRef that prefixes it
    function Get-MetaFamily($builtKr) {
        $exact = @($script:metaLocal | Where-Object { $_.KeyRef -eq $builtKr })
        if ($exact.Count) { return $exact }
        $cands = @($script:metaLocal | Where-Object { $builtKr.StartsWith($_.KeyRef) } | Sort-Object { -($_.KeyRef.Length) })
        if (-not $cands.Count) { return @() }
        $best = $cands[0].KeyRef
        return @($script:metaLocal | Where-Object { $_.KeyRef -eq $best })
    }
    $script:metaLocal = $meta

    foreach ($q in $built.Keys) {
        $qCombos = $built[$q]
        # every ref this query can transmit anywhere (for C3)
        $qPool = @{}
        foreach ($cm in $qCombos) { foreach ($f in (@($cm.Set) + @($cm.Any))) { $qPool[(Canon $f)] = $true } }

        foreach ($cm in $qCombos) {
            $fam = Get-MetaFamily $cm.KeyRef
            if (-not $fam.Count) { continue }
            # RESTRICT to variants for the SAME primary field. A metadata keyRef family covers several
            # distinct searches (IR.QVC has Name, OperatorLicenseNumber, CriminalIdNumber and
            # SocialSecurityNumber variants); comparing the built CII combo against the Name variant's
            # Choice group is meaningless and produced 11 false candidates on CA_CLETS alone in the
            # first known-answer run. If the built combo declares no primaryFieldReference, fall back
            # to the whole family rather than guessing.
            if ($cm.PF) {
                $samePf = @($fam | Where-Object { (Canon $_.PF) -eq (Canon $cm.PF) })
                if ($samePf.Count) { $fam = $samePf }
            }
            $setC = @($cm.Set | ForEach-Object { Canon $_ })
            $anyC = @($cm.Any | ForEach-Object { Canon $_ })

            # ── C1: a variant demands one of a Choice group; we make them all optional/absent ──
            if ($Class -contains 'C1') {
                foreach ($v in @($fam | Where-Object { $_.ChoiceInSet.Count })) {
                    $grp = @($v.ChoiceInSet)
                    $inSet = @($grp | Where-Object { Test-InList $_ $cm.Set })
                    if ($inSet.Count) { continue }   # we require one -- correct
                    # is there a SIBLING variant that legitimately makes them optional AND whose own
                    # mandatory fields we satisfy? then this is the REGISTER case, not a defect.
                    $looser = @($fam | Where-Object {
                        $_.ChoiceInSet.Count -eq 0 -and
                        -not @(@($_.Mand) | Where-Object { -not (Test-InList $_ $cm.Set) }).Count
                    })
                    if ($looser.Count) { continue }
                    $where = @($grp | Where-Object { Test-InList $_ $cm.Any })
                    $findings += [pscustomobject]@{
                        Sev=1; Class='C1'; P=$p; V=$ver; Q=$q; K=$cm.KeyRef
                        What = ("metadata {0}{{{1}}} puts Choice[{2}] INSIDE <Set> (one is MANDATORY) but built carries {3}" -f `
                                $v.KeyRef, $v.PF, ($v.ChoiceInSet -join '|'), $(if ($where.Count) { "them in any[] -- can send NEITHER" } else { "NONE of them at all" }))
                    }
                }
            }

            # ── C2: a set[] field no metadata variant of this family makes mandatory ──────────
            if ($Class -contains 'C2') {
                $everMand = @{}
                foreach ($v in $fam) { foreach ($f in $v.Mand) { $everMand[(Canon $f)] = $true }
                                       foreach ($f in $v.ChoiceInSet) { $everMand[(Canon $f)] = $true } }
                foreach ($f in $cm.Set) {
                    $fc = Canon $f
                    if ($everMand.ContainsKey($fc)) { continue }
                    # form-only / provider-injected fields are not metadata-mandatory by design
                    if ($fc -match 'imageindicator|purposecode|attention|requestor|relatedhit|randomrequest') { continue }
                    $optSomewhere = @($fam | Where-Object { @($_.Opt | ForEach-Object { Canon $_ }) -contains $fc }).Count
                    $findings += [pscustomobject]@{
                        Sev=2; Class='C2'; P=$p; V=$ver; Q=$q; K=$cm.KeyRef
                        What = ("built set[] requires '{0}' but NO metadata {1} variant makes it mandatory{2} -- a fill lacking it falls through to a looser combo that may not carry it, so the value can be silently dropped" -f `
                                $f, $fam[0].KeyRef, $(if ($optSomewhere) { " (it is an OPTIONAL there)" } else { "" }))
                    }
                }
            }

            # ── C3: an optional this family permits that the QUERY can carry nowhere ─────────
            if ($Class -contains 'C3') {
                foreach ($v in $fam) {
                    foreach ($f in $v.Opt) {
                        $fc = Canon $f
                        if ($qPool.ContainsKey($fc)) { continue }
                        if ($fc -match 'requestor|state[2-5]|expanded') { continue }
                        $findings += [pscustomobject]@{
                            Sev=3; Class='C3'; P=$p; V=$ver; Q=$q; K=$cm.KeyRef
                            What = ("metadata {0}{{{1}}} permits optional '{2}' but NO combo of {3} carries it in set[] or any[] -- an officer can type it and it can never reach the wire" -f $v.KeyRef, $v.PF, $f, $q)
                        }
                    }
                }
            }
        }

        # ── C4: prefill on a routing field, unless it is in EVERY combo's set[] ──────────────
        if ($Class -contains 'C4') {
            $inSomeSet = @{}; $inAllSet = @{}
            foreach ($cm in $qCombos) { foreach ($f in $cm.Set) { $inSomeSet[(Canon $f)] = $true } }
            foreach ($k in $inSomeSet.Keys) {
                $everyOne = -not @($qCombos | Where-Object { @($_.Set | ForEach-Object { Canon $_ }) -notcontains $k }).Count
                if ($everyOne) { $inAllSet[$k] = $true }
            }
            foreach ($fid in $forms.Keys) {
                $fc = Canon $fid
                if (-not $inSomeSet.ContainsKey($fc)) { continue }
                if ($inAllSet.ContainsKey($fc)) { continue }   # cannot shadow -- CA purposeCode case
                $findings += [pscustomobject]@{
                    Sev=4; Class='C4'; P=$p; V=$ver; Q=$q; K='(form)'
                    What = ("form prefills '{0}'='{1}' and it is a set[] discriminator on SOME but not all {2} combos -- BUILD_RULES 24, it is always-present so combos needing its absence can never fire" -f $fid, $forms[$fid], $q)
                }
            }
        }
    }
}

# ── report ────────────────────────────────────────────────────────────────────────────────────
$uniq = @($findings | Sort-Object Sev, P, Q, K, What -Unique)

E ''
E ('=' * 132) 'Cyan'
E '  PROVEN DEFECT-CLASS SCAN -- every provider, every class we have actually shipped and fixed' 'Cyan'
E ('=' * 132) 'Cyan'
E ("  providers scanned: {0}   classes: {1}" -f $Providers.Count, ($Class -join ','))
E ''
E '  C1 COLLAPSED CHOICE  = request satisfies NO metadata variant (WIRE-INVALID; 6d catches it, 6c/2i cannot)'
E '  C2 OVER-REQUIRED SET = set[] demands what no variant requires -> fill falls to a looser combo, value silently dropped'
E '  C3 OPTIONAL NOWHERE  = a permitted optional no combo of that query can carry'
E '  C4 ROUTING PREFILL   = BUILD_RULES 24 (skipped when the field is in EVERY combo set[], which cannot shadow)'
E ''
foreach ($cl in @('C1','C2','C3','C4')) {
    $rows = @($uniq | Where-Object { $_.Class -eq $cl })
    if (-not $rows.Count) { continue }
    $col = switch ($cl) { 'C1' { 'Red' } 'C2' { 'Red' } 'C3' { 'Yellow' } default { 'Yellow' } }
    E ''
    E ("  ─── $cl -- $($rows.Count) candidate(s) ───") $col
    foreach ($r in $rows) {
        E ("    {0,-22} v{1,-6} {2,-32} {3}" -f $r.P, $r.V, "$($r.Q)/$($r.K)", $r.What) $col
    }
}
E ''
E ('-' * 132)
$byP = @($uniq | Group-Object P | Sort-Object { -($_.Group | Where-Object { $_.Sev -le 2 }).Count }, Name)
E '  BY PROVIDER (wire-severity first -- C1+C2 are the ones that corrupt a request):'
foreach ($g in $byP) {
    $w = @($g.Group | Where-Object { $_.Sev -le 2 }).Count
    E ("    {0,-22} {1} candidate(s)   WIRE-SEVERITY: {2}" -f $g.Name, $g.Count, $w) $(if ($w) { 'Red' } else { 'Gray' })
}
E ''
E ("  TOTAL: {0} candidate(s) across {1} provider(s); {2} are WIRE-severity (C1/C2)" -f `
   $uniq.Count, $byP.Count, @($uniq | Where-Object { $_.Sev -le 2 }).Count) 'Cyan'
E '  Each is a CANDIDATE with its evidence. FIX-vs-REGISTER needs the provider devdoc and is Rob''s'
E '  call (usx-build Step 3). A looser metadata variant that legitimately permits what we built is'
E '  the REGISTER case -- C1 already suppresses those, C2/C3 flag them for the check.'
E ('-' * 132)

if ($OutFile) { $lines | Out-File $OutFile -Encoding utf8 }
exit 0
