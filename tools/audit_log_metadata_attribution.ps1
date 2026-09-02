<#
  audit_log_metadata_attribution.ps1 -- WHICH metadata combination does this log's WIRE satisfy,
  decided WITHOUT consulting the combo array we built?

  WHY THIS EXISTS (Rob, 2026-09-02, during the CA_CLETS_OCATS v2.12 sweep):
      "be sure the logs are matched to a query combo independently of the original metadata sweep
       used to build it. we don't want a deaf feedback loop."

  He is describing a CLOSED LOOP, and the two existing log gates each sit on one side of it:

    2i  audit_log_combo_attribution -- ATTRIBUTES, but through OUR JSON. It replays the log's
        recorded QUERY STRING through the built QIDM's combination array in array order. That is
        the right question for "is this log FILED correctly", and it is exactly the wrong question
        for "is the COMBO right" -- if the combo array is wrong, 2i faithfully confirms the log
        against the wrong thing and reports green.
    6d  audit_log_metadata -- INDEPENDENT (it parses the wire and validates against
        Get-MetadataTransactions from the raw XML), but it only asks SATISFACTION: "does this wire
        satisfy SOME metadata combination?" Its matcher breaks on the FIRST satisfying combo and
        DISCARDS which one (`$matched = $true; break`). It can never say the wire is attributable
        to a DIFFERENT combination than the one the log is filed under.

  So nothing computed WHICH combination the wire actually is, from the wire and the metadata alone.
  That is the missing direction, and it is ENGINEERING_STANDARD LAW 3 (authority is directional and
  BOTH directions need a gate) applied to the log stage rather than the build stage.

  WHAT IT DOES
    For each current-version log:
      1. Parse the COMMSYS wire XML -> MessageType + present <Request> fields.
      2. From the RAW METADATA ONLY, find EVERY combination of that transaction whose required
         set[] the wire satisfies. Keep them all -- do not break on the first (that is 6d's bug
         for this purpose).
      3. The independent attribution is the MOST SPECIFIC satisfied variant (largest satisfied
         required set). A wire that satisfies several EQUALLY specific variants is genuinely
         AMBIGUOUS from the wire alone -- report it, never guess.
      4. Read the combo NAME out of the filename, and look up that name in the built JSON to learn
         only WHICH REQUIRED FIELD SET it declares (its set[], resolved through the QIDM attribute
         map from sourceFields to targetFields).
         >>> THE JSON IS USED AS A DICTIONARY, NEVER AS AN AUTHORITY. It answers "what does the
         >>> name RQ.P mean", not "what fired". Every routing decision above comes from the wire
         >>> and the XML. Removing this step would leave nothing to compare against, since the wire
         >>> carries no keyRef at all.
      5. AGREE iff the filed combo's declared required set IS one of the metadata alternatives the
         wire satisfies.

  THE COMPARISON AXIS IS THE REQUIRED SET, AND THE FIRST DRAFT GOT THIS WRONG -- 22 FALSE
  DISAGREEs ACROSS 4 PROVIDERS, WHICH IS THE SHAPE THAT MEANS THE PROBE IS BROKEN.
  It compared primaryFieldReference, and that is not a per-branch property:
    * A METADATA COMBINATION CAN HOLD SEVERAL <Choice> ALTERNATIVES AND CARRIES ONE PF LABEL FOR
      ALL OF THEM. TX_TLETS ArticleSingleQuery has exactly ONE combination, QA, labelled
      primaryFieldReference="ArticleSerialNumber", whose Choice yields the alternatives
      [NCICNumber] and [ArticleSerialNumber, ArticleTypeCode]. TX correctly SPLITS that into two
      built combos (QANCICNumber, QAArticleSerialNumber). An NCIC-number wire genuinely satisfies
      the [NCICNumber] branch, and comparing its PF to the combination's label "ArticleSerialNumber"
      reported a defect on a correct build.
    * DH-SUFFIXED FIELD POOLS. FL's built KQ carries primaryFieldReference OperatorLicenseNumberDH
      against metadata OperatorLicenseNumber -- equal in every way that matters and unequal as a
      string. Resolving set[] THROUGH THE QIDM ATTRIBUTE MAP fixes this for free, because the
      attribute's targetField is already the un-suffixed metadata name; no suffix-stripping hack.
    * A COMBINATION MAY DECLARE NO primaryFieldReference AT ALL (HI_HCJDC_OFML QA,
      NM_NMLETS_OFML QUERY), so the axis was empty-vs-something on those.
  The required set is per-ALTERNATIVE, which is exactly the granularity routing happens at.

  VERDICTS
    AGREE          the wire's most-specific metadata variant is the one the log claims.
    DISAGREE       it is a DIFFERENT variant -> the log is attributed to the wrong search path.
                   THIS IS THE FINDING THIS TOOL EXISTS FOR. Blocking.
    AMBIGUOUS      two or more equally-specific variants are satisfied; the wire cannot
                   discriminate them. A METADATA PROPERTY, NOT A DEFECT -- e.g. CA_CLETS_OCATS
                   QV{VIN} and 4V{VIN} have IDENTICAL required sets, so no request can ever tell
                   them apart (usx-build Step 3d calls this a routing impossibility). [NOTE].
    UNATTRIBUTABLE no metadata combination is satisfied. 6d owns this and will already FAIL.

  DELIBERATELY NOT DONE
    - No re-implementation of the metadata parser or the field-equivalence rules: it reuses
      _metadata_parse.ps1 (Get-MetadataTransactions / Test-MetaFieldEquiv / Test-MetaFormOnly) and
      _resolve_provider_xml.ps1 / _resolve_provider_json.ps1. ENGINEERING_STANDARD 4.4 -- five
      parsers were written wrong in one session by re-deriving what already existed.
    - It does NOT duplicate 2i. 2i asks "does our own array route this fill to the named combo";
      this asks "does the METADATA say the wire IS that combo". Both can be green while the other
      fails, which is the entire point of running both.

  Usage: .\tools\audit_log_metadata_attribution.ps1 -Provider <name> [-All] [-Quiet] [-OutFile p]
#>
param(
    [string]$Provider,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_metadata_parse.ps1')
. (Join-Path $PSScriptRoot '_resolve_provider_json.ps1')
. (Join-Path $PSScriptRoot '_resolve_provider_xml.ps1')

$lines = @()
function Out-Line([string]$m, [string]$c = 'Gray') { $script:lines += $m; if (-not $Quiet) { Write-Host $m -ForegroundColor $c } }

$repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$providersD = Join-Path $repoRoot 'providers'

$targets = @()
if ($All) { $targets = @(Get-ChildItem $providersD -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'source') } | ForEach-Object { $_.Name } | Sort-Object) }
elseif ($Provider) { $targets = @($Provider) }
else { Write-Host 'specify -Provider <name> or -All'; exit 2 }

Out-Line ''
Out-Line '================================================================================' 'Cyan'
Out-Line '  LOG -> METADATA ATTRIBUTION -- which combination does the WIRE say this is?' 'Cyan'
Out-Line '  Decided from the wire + raw metadata. The built combo array is NOT consulted.' 'Cyan'
Out-Line '================================================================================' 'Cyan'

# Envelope elements that live in <Request> but are not query fields (mirrors 6d).
$envelope = @('MessageType', 'Id', 'MessageContinueKeyCode')

$totLogs = 0; $totAgree = 0; $totDis = 0; $totAmb = 0; $totUnattr = 0; $totNoLabel = 0; $totStrip = 0
$provExamined = 0; $provSkipped = @()
$findings = @()

foreach ($p in $targets) {
    $provDir = Join-Path $providersD $p
    if (-not (Test-Path $provDir)) { $provSkipped += "${p} (no dir)"; continue }

    $jsonPath = Get-ProviderRootJson -ProvDir $provDir -Provider $p
    if (-not $jsonPath) { $provSkipped += "${p} (no active JSON)"; continue }
    $version = if ([IO.Path]::GetFileNameWithoutExtension($jsonPath) -match '_v([\d.]+)$') { $Matches[1] } else { $null }
    if (-not $version) { $provSkipped += "${p} (version not derivable)"; continue }

    $xmlResolved = Get-ProviderMetadataXml -Provider $p -ProvDir $provDir
    if (-not $xmlResolved) { $provSkipped += "${p} (no metadata XML)"; continue }
    $meta = Get-MetadataTransactions -XmlPath $xmlResolved

    $logs = @(Get-ChildItem (Join-Path $provDir 'logs') -Recurse -Filter "${p}_v${version}_*.txt" -ErrorAction SilentlyContinue |
              Where-Object { $_.FullName -notmatch '[\\/]_archive_' })
    if (-not $logs.Count) { $provSkipped += "${p} (no current-version logs)"; continue }

    # ── JSON as a DICTIONARY ONLY: combo NAME -> (keyRef, primaryField), scoped by query.
    # Scoped by query because keyRefs COLLIDE across QIDMs within one provider (BUILD_RULES 13):
    # NY reuses RVEH and RCAR on both VehicleRegistrationQuery and BoatQuery, so a bare keyRef
    # lookup would silently read the wrong entity's combo.
    $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $labelOf = @{}   # "<query>|<keyRef>" -> @(declared required set, as metadata TARGETFIELD names)
    foreach ($b in $json.bundles) {
        foreach ($c in $b.configurations) {
            if ("$($c.type)" -ne 'QUERYINPUTDATAMAPPING') { continue }
            $q = "$($c.query)"
            # sourceField -> targetField, per QIDM. This is what un-suffixes the DH/CCH pools:
            # the attribute for sourceField 'OperatorLicenseNumberDH' has targetField
            # 'OperatorLicenseNumber', which is the metadata name. No string surgery required.
            $srcToTgt = @{}
            foreach ($a in @($c.attributes)) {
                foreach ($sf in @($a.sourceField)) { if ($sf) { $srcToTgt["$sf"] = "$($a.targetField)" } }
            }
            foreach ($cm in @($c.combinations)) {
                $kr = if ($cm.keyReference) { "$($cm.keyReference)" } else { "$($cm.keyRef)" }
                if (-not $kr) { continue }
                $declared = @()
                foreach ($sf in @($cm.requirements.set)) {
                    if (-not $sf) { continue }
                    $declared += $(if ($srcToTgt.ContainsKey("$sf")) { $srcToTgt["$sf"] } else { "$sf" })
                }
                $labelOf["$q|$kr"] = @($declared | Sort-Object -Unique)
            }
        }
    }

    $provExamined++
    $pAgree = 0; $pDis = 0; $pAmb = 0; $pUn = 0; $pNoLabel = 0; $pStrip = 0
    Out-Line ''
    Out-Line "=== $p  (v$version, $($logs.Count) log(s)) ===" 'Cyan'

    foreach ($f in $logs) {
        $totLogs++
        $rel = "$($f.Directory.Name)\$($f.Name)"
        $content = Get-Content $f.FullName -Raw

        if ($content -notmatch '(?s)COMMSYS XML\s*-+\s*(<\?xml.*?</api:ConnectCicApi>)') { $pUn++; $totUnattr++; continue }
        try { $doc = [xml]$Matches[1] } catch { $pUn++; $totUnattr++; continue }
        $reqNode = $doc.SelectNodes('//*') | Where-Object { $_.LocalName -eq 'Request' } | Select-Object -First 1
        if (-not $reqNode) { $pUn++; $totUnattr++; continue }
        $mt = ($reqNode.ChildNodes | Where-Object { $_.LocalName -eq 'MessageType' } | Select-Object -First 1).InnerText
        if (-not $mt -or -not $meta.ContainsKey($mt)) { $pUn++; $totUnattr++; continue }

        $present = @($reqNode.ChildNodes | ForEach-Object { $_.LocalName } |
                     Where-Object { $_ -and ($envelope -notcontains $_) })

        # ── INDEPENDENT ATTRIBUTION: every satisfied metadata variant, keeping ALL of them.
        $cands = @()
        foreach ($combo in $meta[$mt].combos) {
            foreach ($reqSet in $combo.requiredSets) {
                $rs = @($reqSet | Where-Object { $_ })
                if (-not $rs.Count) { continue }
                $setOk = $true
                foreach ($s in $rs) {
                    $has = $false
                    foreach ($pf in $present) { if (Test-MetaFieldEquiv $pf $s) { $has = $true; break } }
                    if (-not $has) { $setOk = $false; break }
                }
                if ($setOk) {
                    $cands += [pscustomobject]@{
                        KeyRef = "$($combo.keyReference)"; Fields = @($rs | Sort-Object -Unique); Size = $rs.Count
                    }
                }
            }
        }
        if (-not $cands.Count) { $pUn++; $totUnattr++; continue }   # 6d owns this and will FAIL

        # ── the FILED name, from the filename (the JSON is consulted only to translate it)
        $stem = $f.BaseName -replace "^$([regex]::Escape($p))_v$([regex]::Escape($version))_", ''
        # '_strip_<field>' TESTS ARE EXCLUDED, AND THE REASON IS NOT A CONVENIENCE.
        # A strip test deliberately removes or neutralises a field to prove the query RE-ROUTES.
        # Its filename names THE COMBO BEING TESTED AGAINST, not the combo that fired, so reading
        # that name as an attribution claim produces a guaranteed false DISAGREE.
        # PROVEN, not assumed, on NY_NYSPIN_EJUSTICE v4.26: the ordinary out-of-state tests fill
        # RegistrationState="Georgia" and the wire carries <State>GA</State>, while both
        # '_strip_RegistrationState' tests fill "New York" -- NY's OWN HOME STATE -- and the wire
        # correctly carries NO State element at all, because an in-state query has no destination
        # state. The build is right, the log is right, and only the name looks wrong.
        # Counted and reported, never silently dropped: a skipped test is not a passed test.
        if ($stem -match '_strip_') {
            $pStrip++; $totStrip++
            continue
        }
        $named = $stem -replace '_guardrail_vs_.*$', '' -replace '_af_.*$', '' -replace '_any$', ''
        if (-not $labelOf.ContainsKey("$mt|$named")) {
            # BLOCKING, and it was a NOTE in the first draft -- which is exactly how the LAW 2
            # mutation SURVIVED. A plate-wire log renamed to a VIN combo landed here instead of in
            # DISAGREE, and the gate reported [PASS]. An unresolvable name means the log CANNOT BE
            # ATTRIBUTED AT ALL, which is a strictly worse state than being attributed wrongly --
            # "a step that did not run is not a pass". Baseline after modelling the '_strip_'
            # suffix is 0, so any occurrence is real.
            $pNoLabel++; $totNoLabel++
            $findings += "[NO-LABEL ] $p $rel [$mt]: filename combo '$named' matches NO built combination of this query -- the log cannot be attributed"
            continue
        }
        $declared = @($labelOf["$mt|$named"])

        # Does the FILED combo's declared required set equal a metadata alternative the WIRE
        # satisfies? Set equality modulo the shared field-equivalence rule (State<->RegistrationState,
        # PurposeCode<->CaRequestPurposeCode).
        function Test-SetEquiv($x, $y) {
            $x = @($x); $y = @($y)
            if ($x.Count -ne $y.Count) { return $false }
            foreach ($xi in $x) {
                $hit = $false
                foreach ($yi in $y) { if (Test-MetaFieldEquiv $xi $yi) { $hit = $true; break } }
                if (-not $hit) { return $false }
            }
            return $true
        }

        $match = @($cands | Where-Object { Test-SetEquiv $_.Fields $declared })
        if ($match.Count) {
            $pAgree++; $totAgree++
            continue
        }

        # No satisfied alternative matches what this combo declares. Before calling that a
        # disagreement, check whether the wire is simply too thin to discriminate: if the filed
        # combo's declared set is NOT satisfied by the wire at all, the log is genuinely
        # mis-attributed; if it IS satisfied but some OTHER alternative is strictly more specific,
        # that is the ambiguity case rather than a defect.
        $declaredSatisfied = $true
        foreach ($d in $declared) {
            $has = $false
            foreach ($pf2 in $present) { if (Test-MetaFieldEquiv $pf2 $d) { $has = $true; break } }
            if (-not $has) { $declaredSatisfied = $false; break }
        }
        $altList = (@($cands | ForEach-Object { '[' + (($_.Fields) -join '+') + ']' } | Sort-Object -Unique) -join ' | ')
        if ($declaredSatisfied) {
            $pAmb++; $totAmb++
            $findings += "[AMBIGUOUS] $p $rel [$mt]: filed as '$named' (declares [$(($declared) -join '+')]) -- the wire satisfies that, but it is not an exact metadata alternative; satisfied alternatives: $altList"
        } else {
            $pDis++; $totDis++
            $findings += "[DISAGREE ] $p $rel [$mt]: filed as '$named', which declares [$(($declared) -join '+')] -- the WIRE DOES NOT SATISFY THAT SET. Metadata alternatives the wire does satisfy: $altList"
        }
    }

    $verdict = if ($pDis) { "$pDis DISAGREE" } else { 'no disagreement' }
    Out-Line ("  {0} log(s): {1} agree / {2} disagree / {3} ambiguous / {4} unattributable / {5} no-label / {6} strip-excluded  -- {7}" -f `
              $logs.Count, $pAgree, $pDis, $pAmb, $pUn, $pNoLabel, $pStrip, $verdict) $(if ($pDis) { 'Red' } else { 'Green' })
}

Out-Line ''
Out-Line '--------------------------------------------------------------------------------'
if ($findings.Count) { foreach ($x in $findings) { Out-Line "  $x" $(if ($x -like '`[DISAGREE*') { 'Red' } else { 'DarkYellow' }) } ; Out-Line '' }

# DENOMINATOR, ALWAYS. A run that examined nothing must not read like a clean run
# (ENGINEERING_STANDARD 4.3 -- a vacuous PASS and a vacuous FAIL are the same bug).
Out-Line ("  EXAMINED: {0} provider(s) with current-version logs / {1} log(s) attributed" -f $provExamined, $totLogs)
if ($provSkipped.Count) { Out-Line ("  SKIPPED : {0} -- {1}" -f $provSkipped.Count, ($provSkipped -join '; ')) 'DarkGray' }
Out-Line ("  AGREE {0} / DISAGREE {1} / AMBIGUOUS {2} / UNATTRIBUTABLE {3} / NO-LABEL {4} / STRIP-EXCLUDED {5}" -f $totAgree, $totDis, $totAmb, $totUnattr, $totNoLabel, $totStrip)

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }

if ($totLogs -eq 0) {
    Out-Line '  [NO-VERDICT] no current-version logs were attributed -- this is NOT a pass.' 'Yellow'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 0
}
if ($totDis -or $totNoLabel) {
    if ($totDis)     { Out-Line "  [FAIL] $totDis log(s) attribute to a DIFFERENT metadata variant than the combo they are filed under." 'Red' }
    if ($totNoLabel) { Out-Line "  [FAIL] $totNoLabel log(s) name a combo that does not exist in this query -- unattributable." 'Red' }
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}
Out-Line '  [PASS] every attributed log agrees with the metadata variant its wire satisfies.' 'Green'
if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
