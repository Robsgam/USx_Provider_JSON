<#
  audit_defect_classes.ps1 -- scan EVERY provider for the defect classes we have PROVEN real.

  ############################################################################################
  ##  C1 IS VERIFIED. C2 / C3 / C4 ARE STILL EXPERIMENTAL -- DO NOT QUOTE THEIR OUTPUT.       ##
  ##  Nothing here is wired into a gate yet.                                                  ##
  ##                                                                                          ##
  ##  KNOWN-ANSWER TEST (C1): the CA family, whose true state was established BY HAND on       ##
  ##  2026-07-31. Correct answer = EXACTLY ONE row, CA_VENTURA_COUNTY GunQuery/IG.QGH, which   ##
  ##  carries no Age/BirthDate discriminator at all. Trajectory: 19 -> 9 -> 7 -> 6 -> 5 -> 1.  ##
  ##  It now returns 1, and it independently AGREES WITH 6d on the six tenant-verified         ##
  ##  providers (0 C1 there), which is the corroboration that makes C1 quotable.               ##
  ##                                                                                          ##
  ##  THE TWO BUGS THAT TOOK SIX PASSES, BOTH THE SAME CLASS: THE TOOL WAS READING THE WRONG   ##
  ##  AUTHORITY, AND NO AMOUNT OF REASONING ABOUT THE COMPARISON LOGIC COULD HAVE FOUND EITHER.##
  ##                                                                                          ##
  ##  BUG 1 -- WRONG FILE. Resolution was `Get-ChildItem source -Filter '*.xml' | Select -First ##
  ##  1`. On CA_CONTRA_COSTA (the only provider with two XMLs) that returned                   ##
  ##  CA_CONTRA_COSTA_JAWS_ONLY.xml: 6 <Combination> nodes instead of 466, and ONE IR.QVC       ##
  ##  variant instead of twelve. So every built IR.QVC.* combo was compared against the single  ##
  ##  surviving {Name} variant and five correct combos looked like collapsed-Choice defects.    ##
  ##  Five reasoning passes blamed the primaryFieldReference restriction. -Diag settled it in   ##
  ##  ONE run by printing `fam 1->1 ... PFsLeft=[Name]`: the restriction had nothing to         ##
  ##  restrict. Fixed by the new shared resolver `_resolve_provider_xml.ps1`, which prefers     ##
  ##  <PROVIDER>.xml and REFUSES to guess between candidates. Note the pick was not even        ##
  ##  STABLE: Get-ChildItem's native order put JAWS_ONLY first, `Sort-Object Name` puts it      ##
  ##  second. The same glob was in pipeline.ps1, feeding extract_metadata_reference.ps1 --      ##
  ##  i.e. it could have regenerated METADATA_REFERENCE.txt, the repo's authority doc, from a   ##
  ##  1.3% excerpt, silently and green. Latent only because CC had no full pipeline run since.  ##
  ##                                                                                          ##
  ##  BUG 2 -- FLATTENED THE AUTHORITY. A <Choice> BRANCH IS NOT ALWAYS A SINGLE <Field>; it    ##
  ##  can be a nested <Set> = a GROUP carried together. TX_TLETS QA is the shape:               ##
  ##      <Choice><Field NCICNumber/><Set><Field ArticleSerialNumber/><Field ArticleTypeCode/>  ##
  ##      </Set></Choice>      = "NCIC number, OR serial+type together"                        ##
  ##  Collecting only direct <Field> children saw the branch list as {NCICNumber} and declared  ##
  ##  the entirely-valid serial+type build to satisfy nothing. That put 4 FALSE C1 rows on      ##
  ##  TX_TLETS (TENANT-VERIFIED, 89 logs) and TX_TLETS_CCH. 6d audit_log_metadata validates the ##
  ##  real wire against the real metadata and had passed TX all along.                          ##
  ##  RULE: WHEN TWO GATES DISAGREE, SUSPECT THE ONE THAT FLATTENED ITS AUTHORITY. Satisfaction ##
  ##  is now per-BRANCH -- any ONE branch fully required = correct. Same family as              ##
  ##  METADATA_REFERENCE.txt flattening Choice branches (QIDM_REFERENCE Sec 1b).                ##
  ##                                                                                          ##
  ##  STILL OWED before C2/C3/C4 can be quoted: they report 359 / 313 / 28 candidates, which is ##
  ##  not credible and is very likely the SAME naivety -- C2's "ever mandatory" test flattens   ##
  ##  ChoiceBranches, so a field mandatory only WITHIN a group may read as never-mandatory.     ##
  ##  Give each class its own known-answer case before believing any count.                     ##
  ############################################################################################
  EVERY finding is a CANDIDATE with evidence attached, not a verdict. The FIX-vs-REGISTER call needs
  the devdoc check and is Rob's (see usx-build Step 3). A looser metadata variant legitimately
  permitting what we built is the REGISTER case, and this tool says so when it sees one.

  Usage: .\audit_defect_classes.ps1 [-Providers <list>] [-All] [-Class C1,C2] [-OutFile <path>]
#>
param(
    [string[]]$Providers,
    [switch]$All,
    # C1 ONLY by default. C2/C3/C4 are RETIRED -- each duplicated a gate that already answers its
    # question CORRECTLY, and each was the WEAKER copy. Proven on HI_HCJDC_OFML, not argued:
    #   C2 (over-required set[])  -> audit_requirement_fidelity.ps1 reports "14 branches compared,
    #      0 UNDER-REQUIRED / 0 OVER-PERMITTED, 6 registered divergences" where C2 claimed NINE
    #      wire-severity defects. C2's premise is simply wrong: it assumes set[] must mirror the
    #      metadata mandatory list, but a SYNTHETIC keyRef SPLIT (LIMITATION #21, used across the
    #      whole portfolio) deliberately makes set[] TIGHTER in order to route. So C2 flags every
    #      synthetic split forever. audit_requirement_fidelity maps a built combo to the metadata
    #      ALTERNATIVE it implements and honours the accepted-divergence registry -- the right shape.
    #   C3 (optional carried nowhere) -> audit_devdoc_optionals.ps1 owns this, against the DEVDOC
    #      (the query authority), not against metadata alone.
    #   C4 (routing prefill)      -> audit_query_trace.ps1 PREFILL-DEAD owns BUILD_RULES 24 and
    #      reported "13 built / 0 PREFILL-DEAD" with registered NOTEs on the same provider.
    # They remain runnable via -Class for forensic comparison, but they are NOT findings and their
    # counts (359/313/28 portfolio-wide vs C1's 1) are noise. Keeping a second, weaker copy of an
    # existing authority is the anti-pattern this same file has now demonstrated three times.
    [string[]]$Class = @('C1'),
    [switch]$Diag,
    [string]$OutFile
)

$ErrorActionPreference = 'Continue'
$repo    = Split-Path $PSScriptRoot -Parent
$toolDir = $PSScriptRoot
. (Join-Path $toolDir '_resolve_provider_json.ps1')
. (Join-Path $toolDir '_resolve_provider_xml.ps1')

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
    # Shared resolver, NOT an alphabetical glob. `Select-Object -First 1` over *.xml is what made
    # this tool read CA_CONTRA_COSTA's JAWS-only excerpt (6 Combination nodes, 1 IR.QVC) instead of
    # the real 466-node metadata, manufacturing 5 false collapsed-Choice findings. See the banner.
    $xfPath = Get-ProviderMetadataXml -Provider $p -ProvDir $d
    if (-not $xfPath) { E "  [SKIP] $p -- no unambiguous metadata XML" 'DarkYellow'; continue }

    try { [xml]$x = Get-Content $xfPath -Raw } catch { E "  [SKIP] $p -- metadata XML unparseable" 'DarkYellow'; continue }
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

        # direct-child <Choice> inside <Set> => exactly one BRANCH of it is MANDATORY.
        #
        # A BRANCH IS NOT ALWAYS A SINGLE FIELD. It can be a nested <Set> = a GROUP that must be
        # carried together. TX_TLETS QA is the canonical shape:
        #     <Set><Choice>
        #        <Field reference="NCICNumber"/>
        #        <Set><Field reference="ArticleSerialNumber"/><Field reference="ArticleTypeCode"/></Set>
        #     </Choice>...
        # i.e. "NCIC number, OR serial+type together". Collecting only the direct <Field> children
        # yields {NCICNumber} and makes the entirely-valid serial+type build look like it satisfies
        # no branch -- which is precisely the false positive this produced on TX_TLETS (TENANT-VERIFIED,
        # 89 logs) and TX_TLETS_CCH. 6d audit_log_metadata validates the real wire against the real
        # metadata and passed TX all along; when two gates disagree, the one that flattened its
        # authority is the one that is wrong.
        $choiceBranches = @()          # array of string[]; satisfied if ANY branch is FULLY carried
        foreach ($ch in $setNode.ChildNodes) {
            if ($ch.LocalName -ne 'Choice') { continue }
            foreach ($br in $ch.ChildNodes) {
                if ($br.LocalName -eq 'Field') {
                    $r = $br.GetAttribute('reference'); if ($r) { $choiceBranches += ,@($r) }
                } elseif ($br.LocalName -eq 'Set') {
                    $g = @()
                    foreach ($f in $br.ChildNodes) { if ($f.LocalName -eq 'Field') { $g += $f.GetAttribute('reference') } }
                    $g = @($g | Where-Object { $_ })
                    if ($g.Count) { $choiceBranches += ,@($g) }
                }
            }
        }
        # flattened view, kept for C2's "is this field ever mandatory" test and for messaging
        $choiceInSet = @($choiceBranches | ForEach-Object { $_ } | Where-Object { $_ })
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
            Mand = @($mand | Where-Object { $_ }); ChoiceInSet = @($choiceInSet | Where-Object { $_ })
            ChoiceBranches = $choiceBranches; Opt = @($opt | Where-Object { $_ })
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
            $famBefore = $fam.Count
            $samePfN = 0
            if ($cm.PF) {
                $samePf = @($fam | Where-Object { (Canon $_.PF) -eq (Canon $cm.PF) })
                $samePfN = $samePf.Count
                if ($samePf.Count) { $fam = $samePf }
            }
            # -Diag prints the ACTUAL narrowing state. Five reasoning passes about why the restriction
            # "was not taking effect" were each wrong, and a standalone replication of this exact logic
            # gives the CORRECT answer (samePf>0, zero Choice-in-Set variants left, no finding) -- so the
            # divergence is somewhere reasoning has not reached. Print it instead of theorising:
            #   .\audit_defect_classes.ps1 -Providers CA_CONTRA_COSTA -Class C1 -Diag
            # Expected for IR.QVC.C/.O/.OS/.S: PF non-empty, samePf>0, choiceLeft=0 -> NO finding.
            # If the tool still emits findings for those while showing choiceLeft=0, the bug is BELOW
            # this point (in the C1 emit block), not in the narrowing.
            if ($Diag) {
                $choiceLeft = @($fam | Where-Object { $_.ChoiceInSet.Count }).Count
                E ("    [DIAG] {0,-14} PF='{1}'  fam {2}->{3}  samePf={4}  choiceLeft={5}  PFsLeft=[{6}]" -f `
                    $cm.KeyRef, $cm.PF, $famBefore, $fam.Count, $samePfN, $choiceLeft,
                    (($fam | ForEach-Object { $_.PF } | Select-Object -Unique) -join ',')) 'DarkCyan'
            }
            $setC = @($cm.Set | ForEach-Object { Canon $_ })
            $anyC = @($cm.Any | ForEach-Object { Canon $_ })

            # ── C1: a variant demands one of a Choice group; we make them all optional/absent ──
            if ($Class -contains 'C1') {
                foreach ($v in @($fam | Where-Object { $_.ChoiceInSet.Count })) {
                    $grp = @($v.ChoiceInSet)
                    # A branch is satisfied only when EVERY field in it is required by us; the Choice
                    # is satisfied when ANY ONE branch is. A branch may be a group (TX QA:
                    # serial+type), so testing individual fields is not enough -- see the parse note.
                    $branchOk = $false
                    foreach ($br in @($v.ChoiceBranches)) {
                        $missing = @(@($br) | Where-Object { -not (Test-InList $_ $cm.Set) })
                        if (-not $missing.Count) { $branchOk = $true; break }
                    }
                    if ($branchOk) { continue }   # we require a full branch -- correct
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
                        What = ("metadata {0}{{{1}}} puts Choice[{2}] INSIDE <Set> (one BRANCH is MANDATORY) but built satisfies no branch -- carries {3}" -f `
                                $v.KeyRef, $v.PF,
                                (@($v.ChoiceBranches | ForEach-Object { if (@($_).Count -gt 1) { '(' + (@($_) -join '+') + ')' } else { "$_" } }) -join ' | '),
                                $(if ($where.Count) { "some only in any[] -- can send NEITHER" } else { "NONE of them at all" }))
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
E '                         VERIFIED: known-answer test returns exactly 1, and agrees with 6d on the six'
E '                         tenant-verified providers (0 there). Choice satisfaction is per-BRANCH, and a'
E '                         branch may be a nested <Set> GROUP (TX QA: NCICNumber OR serial+type).'
E ''
E '  C2/C3/C4 RETIRED -- each duplicated a gate that already answers its question, and was the WEAKER' 'DarkGray'
E '  copy. On HI_HCJDC_OFML: audit_requirement_fidelity = 0 UNDER/0 OVER over 14 branches where C2' 'DarkGray'
E '  claimed 9; audit_query_trace = 0 PREFILL-DEAD where C4 duplicates it; audit_devdoc_optionals owns' 'DarkGray'
E '  C3 against the DEVDOC. C2 also assumed set[] must mirror metadata-mandatory, which is wrong for' 'DarkGray'
E '  every SYNTHETIC keyRef SPLIT (LIMITATION #21). Runnable via -Class for comparison; NOT findings.' 'DarkGray'
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
