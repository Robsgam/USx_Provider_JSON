<#
  audit_requirement_fidelity.ps1 -- does each BUILT combination require EXACTLY what its metadata
  branch requires? Mandatory-vs-optional fidelity, per combination, both directions.

  WHY THIS EXISTS (found 2026-07-30 on NY_NYSPIN_EJUSTICE, round 4 of an attack sweep)
    Every existing gate answers a DIFFERENT question, and none of them answers this one:
      audit_metadata            -- is the FIELD metadata-defined for this query?      (membership)
      audit_query_trace         -- does a built combo EXIST for each metadata combo?  (existence)
      audit_combo_reachability  -- can the form actually REACH each built combo?      (reachability)
      audit_log_metadata (6d)   -- does a captured wire request satisfy SOME combo?   (satisfaction)
    A combination can pass all four while being built LOOSER than the spec. NY's RVEHOUT is the
    proof case: metadata's out-of-state plate branch requires
        LicensePlateNumber + LicensePlateTypeCode + LicensePlateYear + State   (all mandatory)
    and we built
        set[LicensePlateNumber, RegistrationState]  any[ImageIndicator, PlateTypeCode, PlateYear]
    Two metadata-MANDATORY fields demoted to optional. The combo exists, is reachable, every field
    is metadata-defined, and a Plate+State-only wire request satisfies our own set[] -- so all four
    gates go green while the officer sends NY a request the spec says is incomplete.

    6d cannot catch it BY CONSTRUCTION: it validates the log against the combination as WE built it.
    A gate that reads its expectation from the artifact under test cannot detect that the artifact is
    wrong -- the same closed-loop failure that let the test plan be generated FROM the JSON.
    This tool reads the expectation from the XML only.

  THE OTHER HALF OF WHY: nested <Choice><Set> was invisible to four gates written on 2026-07-30
    (audit_devdoc_combinations, audit_devdoc_optionals, emit_test_plan_spec, audit_log_metadata all
    have ZERO Choice handling), while audit_metadata CHECK 4b and extract_metadata_reference had
    handled it correctly for months. 13 of 18 providers use the nested shape -- TX_TLETS has 60 of
    them, so TX's ALL-PASS was signed off by Choice-blind gates too. Read the existing parsers
    before writing a new one (ENGINEERING_STANDARD LAW 4).

  VERDICTS
    UNDER-REQUIRED  metadata says MANDATORY, we built it optional or absent  -> can send an
                    incomplete request. This is the defect class that motivated the tool.
    OVER-PERMITTED  we allow a field the metadata branch does not define at all -> can send a field
                    the branch rejects (LIMITATION #1 family, per-branch scope).
    Both are [WARN], never [FAIL]: a build may legitimately tighten or split a branch, and only Rob
    rules on combination semantics. A WARN that names the exact field is what he needs to rule.

  MATCHING is keyRef-first, signature-second. Synthetic keyRefs are legal and common (NY implements
  the RVEH out-of-state branch as RVEHOUT; BUILD_RULES 13 + LIMITATION #21), so an unmatched
  metadata alternative falls back to the built combo with the highest field overlap WITHIN THE SAME
  QUERY. Never across queries: RVEH/RVIN/RNAM each appear in MULTIPLE NY transactions with
  completely different requirement sets, and RNAM appears TWICE inside one transaction.

  Usage: .\audit_requirement_fidelity.ps1 [-Provider <NAME>] [-OutFile <path>]
#>

param([string]$Provider, [string]$OutFile)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')

$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; Write-Host $s -ForegroundColor $c }

# ── field-name canonicalisation ───────────────────────────────────────────────────────
# Built fieldIds diverge from metadata field references in three systematic ways:
#   case/punctuation (vehicleYear vs VehicleYear), DH/CCH isolation suffixes
#   (purposeCodeDH vs PurposeCode), and deliberate renames (RegistrationState vs State).
# Anything NOT in one of those three classes is a real difference and must survive canonicalisation.
$alias = @{
    'state'                  = 'registrationstate'
    'licenseplatenumberout'  = 'licenseplatenumber'
    'articleserialnumber'    = 'serialnumber'
    'gunserialnumber'        = 'serialnumber'   # every provider builds the metadata GunSerialNumber as serialNumber
    'carequestpurposecode'   = 'purposecode'
}
function Canon([string]$t) {
    $k = ($t -replace '[^A-Za-z0-9]', '').ToLower()
    # suffix-strip only -- a bare 'birthdate' must not lose characters, only 'birthdatedh' may.
    if ($k.Length -gt 2 -and $k.EndsWith('dh'))  { $k = $k.Substring(0, $k.Length - 2) }
    if ($k.Length -gt 3 -and $k.EndsWith('cch')) { $k = $k.Substring(0, $k.Length - 3) }
    if ($alias.ContainsKey($k)) { $k = $alias[$k] }
    return $k
}
# 'Name' is a metadata COMPOSITE that the form decomposes into Last/First/Middle/Suffix via
# FormatStringRuleHandler. Treat it as satisfied by any component, else every name-based combination
# on every provider reports a false UNDER-REQUIRED.
# BIDIRECTIONAL, and the first draft was not: it expanded only want=='name', so metadata 'Name' vs
# built 'nameMiddle' failed and every name-based combination on every provider reported a false
# OVER-PERMITTED (12 of the first run's 39 findings).
$nameParts = @('namelast', 'namefirst', 'namemiddle', 'namesuffix', 'name')
function Test-Has([string[]]$pool, [string]$want) {
    if ($pool -contains $want) { return $true }
    if ($nameParts -contains $want) { foreach ($p in $nameParts) { if ($pool -contains $p) { return $true } } }
    return $false
}
# FORM-ONLY fields: platform/form-supplied, not part of any provider combination's field list, so
# their presence in a built any[] is EXPECTED and never an over-permit. audit_metadata.ps1 has
# carried this same whitelist for months -- reused rather than reinvented (LAW 4). Applied to
# OVER-PERMITTED only; a form-only field can still be legitimately metadata-mandatory somewhere.
$formOnly = @('imageindicator', 'registrationstate', 'attention', 'purposecode', 'requestor',
              'emailaddress', 'reasoncode', 'relatedhitsearchindicator', 'randomrequest',
              'dexstateuserid', 'messagekey', 'messagecontinuekeycode')

# ── metadata: expand each Combination into one entry per Choice alternative ────────────
function Get-MetaAlternatives([string]$xmlPath) {
    $x = [xml](Get-Content $xmlPath -Raw)
    $out = @()
    foreach ($t in $x.SelectNodes('//*[local-name()="Transaction"]')) {
        $tn = "$($t.GetAttribute('name'))"
        if (-not $tn) { continue }
        foreach ($cb in $t.SelectNodes('.//*[local-name()="Combination"]')) {
            $kr = "$($cb.GetAttribute('keyReference'))"
            $sn = $cb.SelectSingleNode('./*[local-name()="Requirements"]/*[local-name()="Set"]')
            if (-not $sn) { continue }
            # fields declared at the OUTER level apply to every alternative
            $baseSet = @(); $baseAny = @()
            foreach ($f in $sn.SelectNodes('./*[local-name()="Field"]'))                       { $baseSet += "$($f.GetAttribute('reference'))" }
            foreach ($f in $sn.SelectNodes('./*[local-name()="Any"]/*[local-name()="Field"]')) { $baseAny += "$($f.GetAttribute('reference'))" }
            # flat <Choice><Field> -- a mandatory one-of, so NOT individually mandatory. Optional
            # for fidelity purposes; audit_metadata CHECK 4b owns one-of coverage.
            # FOURTH shape, TX_TLETS GunQuery/QG: a nested <Set> and a bare <Field> as SIBLINGS in
            # one <Choice> -- 'either serial(+caliber/make) OR NCICNumber'. Folding the bare Field
            # into baseAny understates it (it is an alternative, not an optional extra), but it
            # cannot produce a false UNDER-REQUIRED, and TX correctly splits it into two combos.
            foreach ($f in $sn.SelectNodes('./*[local-name()="Choice"]/*[local-name()="Field"]')) { $baseAny += "$($f.GetAttribute('reference'))" }
            $alts = @($sn.SelectNodes('./*[local-name()="Choice"]/*[local-name()="Set"]'))
            if ($alts.Count -eq 0) {
                $out += [pscustomobject]@{ Query = $tn; KeyRef = $kr; Alt = 0; AltTotal = 0
                                           Set = @($baseSet | Where-Object { $_ }); Any = @($baseAny | Where-Object { $_ }) }
            } else {
                $i = 0
                foreach ($a in $alts) {
                    $i++
                    $s = @($baseSet); $n = @($baseAny)
                    foreach ($f in $a.SelectNodes('./*[local-name()="Field"]'))                       { $s += "$($f.GetAttribute('reference'))" }
                    foreach ($f in $a.SelectNodes('./*[local-name()="Any"]/*[local-name()="Field"]')) { $n += "$($f.GetAttribute('reference'))" }
                    $out += [pscustomobject]@{ Query = $tn; KeyRef = $kr; Alt = $i; AltTotal = $alts.Count
                                               Set = @($s | Where-Object { $_ }); Any = @($n | Where-Object { $_ }) }
                }
            }
        }
    }
    # UNIQUE INDEX per alternative. Keying the assignment map on query|keyRef|alt collided
    # whenever a transaction declares the SAME keyRef twice (NY RNAM, TX QB/RQ, FL FRQ x7): all
    # duplicates carry alt=0, so several metadata entries read back the SAME built combo and each
    # reported the other's fields as UNDER-REQUIRED. Index, never a natural key.
    for ($i = 0; $i -lt $out.Count; $i++) { $out[$i] | Add-Member -NotePropertyName Idx -NotePropertyValue $i -Force }
    return $out
}

# ── main ──────────────────────────────────────────────────────────────────────────────
Out-Line ''
Out-Line ('=' * 80)
Out-Line '  REQUIREMENT FIDELITY -- built mandatory/optional vs metadata, per Choice branch'
Out-Line ("  " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Out-Line ('=' * 80)

$dirs = Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name
if ($Provider) { $dirs = @($dirs | Where-Object { $_.Name -eq $Provider }) }
if (-not $dirs) { Out-Line "  [FAIL] provider '$Provider' not found" 'Red'; exit 1 }

$totUnder = 0; $totOver = 0; $totMatched = 0; $totUnmatched = 0

foreach ($d in $dirs) {
    $jp = Get-ProviderRootJson -ProvDir $d.FullName -Provider $d.Name
    if (-not $jp) { continue }
    $xml = @(Get-ChildItem "$($d.FullName)\source" -Filter '*.xml' -File -ErrorAction SilentlyContinue |
             Where-Object { $_.BaseName -eq $d.Name }) | Select-Object -First 1
    if (-not $xml) { $xml = @(Get-ChildItem "$($d.FullName)\source" -Filter '*.xml' -File -ErrorAction SilentlyContinue) | Select-Object -First 1 }
    if (-not $xml) { Out-Line "`n=== $($d.Name) ===" 'Cyan'; Out-Line '  [FAIL] no metadata XML in source/ -- cannot verify fidelity' 'Red'; $totUnmatched++; continue }

    $meta = Get-MetaAlternatives $xml.FullName
    $raw  = Get-Content $jp -Raw | ConvertFrom-Json

    # built combos, grouped by the query the QIDM targets
    $built = @{}
    foreach ($b in $raw.bundles) {
        foreach ($c in $b.configurations) {
            if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            if ("$($c.provider)" -eq 'RMS' -or "$($c.name)" -match '^RMS ') { continue }
            $q = "$($c.name)" -replace "^$([regex]::Escape($d.Name))_", ''
            if (-not $built.ContainsKey($q)) { $built[$q] = @() }
            foreach ($cm in $c.combinations) {
                $built[$q] += [pscustomobject]@{ KeyRef = "$($cm.keyReference)"
                                                 Set = @($cm.requirements.set    | Where-Object { $_ })
                                                 Any = @($cm.requirements.any    | Where-Object { $_ }) }
            }
        }
    }

    Out-Line "`n=== $($d.Name)  ($(Split-Path $jp -Leaf)) ===" 'Cyan'
    $pUnder = 0; $pOver = 0; $pMatched = 0

    # ── ONE-TO-ONE ASSIGNMENT, per query ──────────────────────────────────────────────
    # The first draft matched each metadata alternative INDEPENDENTLY, so several alternatives
    # collapsed onto the SAME built combo and every unmatched alternative reported its whole set[]
    # as UNDER-REQUIRED/ABSENT. That produced NY's bogus "DLIC UNDER-REQUIRED BirthDate, Name,
    # SexCode" and both providers' bogus "GunSerialNumber ABSENT": those transactions declare the
    # SAME keyRef twice with different sets (NY's RNAM appears twice in one transaction), so the
    # name-based alternative was scored against the OLN-based built combo.
    # Greedy, most-specific-first: each built combo can win at most one alternative. An alternative
    # left unassigned is a genuine coverage question -- and it belongs to audit_query_trace (2p),
    # not here, so it is skipped rather than reported as a fidelity defect.
    $assign = @{}
    foreach ($q in @($meta | ForEach-Object { $_.Query } | Sort-Object -Unique)) {
        if (-not $built.ContainsKey($q)) { continue }
        $used  = @{}
        $alts  = @($meta | Where-Object { $_.Query -eq $q } | Sort-Object { -(@($_.Set).Count) })
        foreach ($m in $alts) {
            $mS = @($m.Set | ForEach-Object { Canon $_ }); $mA = @($m.Any | ForEach-Object { Canon $_ })
            $best = $null; $bestScore = -999; $bestKey = $null
            $ci = -1
            foreach ($cd in @($built[$q])) {
                $ci++
                if ($used.ContainsKey($ci)) { continue }
                $cS = @($cd.Set | ForEach-Object { Canon $_ })
                $score = 0
                foreach ($w in $mS) { if (Test-Has $cS $w) { $score += 3 } else { $score -= 1 } }
                foreach ($w in $cS) { if (-not (Test-Has $mS $w) -and -not (Test-Has $mA $w)) { $score -= 2 } }
                if ($cd.KeyRef -eq $m.KeyRef) { $score += 2 }
                if ($score -gt $bestScore) { $bestScore = $score; $best = $cd; $bestKey = $ci }
            }
            if ($best -ne $null) { $used[$bestKey] = $true; $assign["$($m.Idx)"] = $best }
        }
    }

    foreach ($m in $meta) {
        if (-not $built.ContainsKey($m.Query)) { continue }   # query not built: 2p/2e own that
        $b0 = $assign["$($m.Idx)"]
        if (-not $b0) { continue }
        $mSetC = @($m.Set | ForEach-Object { Canon $_ })
        $mAnyC = @($m.Any | ForEach-Object { Canon $_ })
        $pMatched++

        $bSetC = @($b0.Set | ForEach-Object { Canon $_ })
        $bAnyC = @($b0.Any | ForEach-Object { Canon $_ })
        $tag = if ($m.AltTotal -gt 1) { "$($m.KeyRef)[alt$($m.Alt)/$($m.AltTotal)]" } else { $m.KeyRef }

        # UNDER-REQUIRED: metadata-mandatory, built optional or absent
        $under = @()
        for ($i = 0; $i -lt $mSetC.Count; $i++) {
            $w = $mSetC[$i]
            if (Test-Has $bSetC $w) { continue }
            $where = if (Test-Has $bAnyC $w) { 'built any[]' } else { 'ABSENT' }
            $under += "$($m.Set[$i]) ($where)"
        }
        # OVER-PERMITTED: built any[] member the branch does not define at all
        $over = @()
        for ($i = 0; $i -lt $bAnyC.Count; $i++) {
            $w = $bAnyC[$i]
            if ((Test-Has $mSetC $w) -or (Test-Has $mAnyC $w)) { continue }
            if ($formOnly -contains $w) { continue }
            $over += "$($b0.Any[$i])"
        }

        if ($under.Count) {
            Out-Line "  [WARN] $($m.Query) / $tag -> built '$($b0.KeyRef)' UNDER-REQUIRED: $($under -join '; ')" 'Yellow'
            $pUnder += $under.Count
        }
        if ($over.Count) {
            Out-Line "  [WARN] $($m.Query) / $tag -> built '$($b0.KeyRef)' OVER-PERMITTED: $($over -join '; ')" 'Yellow'
            $pOver += $over.Count
        }
    }

    if (-not $pUnder -and -not $pOver) { Out-Line "  [PASS] $pMatched matched branch(es), 0 UNDER-REQUIRED / 0 OVER-PERMITTED" 'Green' }
    else { Out-Line "  ---- $pMatched matched branch(es): $pUnder UNDER-REQUIRED, $pOver OVER-PERMITTED" 'Yellow' }
    $totUnder += $pUnder; $totOver += $pOver; $totMatched += $pMatched
}

Out-Line ''
Out-Line ('-' * 80)
Out-Line "  TOTALS: $totMatched branch(es) compared / $totUnder UNDER-REQUIRED / $totOver OVER-PERMITTED"
Out-Line '  UNDER-REQUIRED = we can send an INCOMPLETE request the metadata calls invalid.'
Out-Line '  OVER-PERMITTED = we can send a field this branch does not define.'
Out-Line '  Advisory: only Rob rules on combination semantics. Never auto-tighten a set[] --'
Out-Line '  a mandatory field that the form PREFILLS becomes an always-true discriminator and'
Out-Line '  silently kills every sibling combination ordered after it (BUILD_RULES 24).'
Out-Line ('-' * 80)

if ($OutFile) {
    $lines | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "  -> $OutFile" -ForegroundColor DarkGray
}
exit 0
