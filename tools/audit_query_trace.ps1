<#
  audit_query_trace.ps1 -- QUERY TRACE: every metadata combination -> built? reachable? why not?

  Answers the question no existing gate answers: "are we missing a COMBINATION, and is one of
  our own form defaults the reason?"

  WHY THIS EXISTS (2026-07-29, TX_TLETS v4.13 post-mortem):
    TX shipped with 3 of 7 metadata combinations built (43%) and every gate green.
      - audit_supported_queries (enforce 2e) checks BUILT -> devdoc (nothing built that the
        devdoc does not list). It cannot see a devdoc combo that was never built.
      - audit_metadata CHECK 5 checks PRIMARY FIELD coverage ("LicensePlateNumber: at least one
        combo built"), which an in-state combo satisfies -- so a missing OUT-OF-STATE variant on
        the same primary field is invisible.
      - audit_combo_reachability only walks combos that ARE built.
    Net effect: TX's two devdoc "(OutofState)" vehicle paths were deleted as "dead combos" when
    they were only unreachable because the FORM PREFILLED their discriminators
    (LicensePlateTypeCode=PC, LicensePlateYear=2026, FinancialResponsibilityType=E). Officers
    lost out-of-state plate and VIN queries, and 141 PASS / 0 FAIL said everything was fine.

  WHAT IT REPORTS, per query:
    BUILT        -- metadata combo present in the JSON
    MISSING      -- metadata combo not built, and NOT explained by a prefill (a plain gap)
    PREFILL-DEAD -- metadata combo not built (or unreachable) specifically because a sibling
                    combo's extra set[] field is form-prefilled, so the sibling always matches
                    first. Names the prefill to remove. THIS IS THE RECOVERABLE CLASS.
    SHADOW       -- two combos with IDENTICAL required set[]; only one can ever fire under
                    first-match. Needs a discriminating condition, not a prefill change.

  Prefill sources counted as always-present (same model as audit_combo_reachability):
    form initialValue on the field, and any combo defaults[] entry for it.

  Scope note: metadata is FIELD authority but the devdoc is QUERY authority, so a MISSING combo
  is not automatically work to do -- it may be out-of-Basic-scope (CA builds only devdoc-Basic
  combos out of 19 in metadata) or unbuildable because the metadata transaction lacks the field.
  This tool reports; a human adjudicates against the devdoc. It never fails a build.

  Usage:
    .\audit_query_trace.ps1 -Provider TX_TLETS
    .\audit_query_trace.ps1 -Providers NJ_NJCJIS,HI_HCJDC_OFML,NY_NYSPIN_EJUSTICE
    .\audit_query_trace.ps1 -All [-OutFile <path>]
#>

param(
    [string]$Provider,
    [string[]]$Providers,
    [switch]$All,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_resolve_provider_json.ps1"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s, $color) {
    $lines.Add($s)
    if ($color) { Write-Host $s -ForegroundColor $color } else { Write-Host $s }
}

# ── which providers ──
$targets = @()
if ($All)            { $targets = @(Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Select-Object -ExpandProperty Name) }
elseif ($Providers)  { $targets = @($Providers) }
elseif ($Provider)   { $targets = @($Provider) }
else { Write-Host "  Pass -Provider, -Providers, or -All" -ForegroundColor Red; exit 1 }

# Normalize a set[] list into a comparable signature (case-insensitive, order-independent).
function Sig($fields) {
    return (@($fields | Where-Object { $_ } | ForEach-Object { "$_".ToLower() } | Sort-Object) -join '+')
}

# Metadata field name -> form fieldId, via the QIDM attribute sourceField (mirrors
# emit_test_plan's Resolve-FieldId). Needed because prefills live on form fieldIds while
# metadata combos name attributes.
# ALL form fieldIds a metadata field name can legitimately appear as. A composite maps to many
# (Name -> NameLast, NameFirst, nameMiddle, nameSuffix); a DH-isolated query maps to the suffixed
# copies. Falls back to the name itself when the QIDM has no matching attribute.
function Expand-Sf([string]$name, $qidm, $formIds) {
    $out = @()
    $direct = $formIds | Where-Object { $_ -ieq $name } | Select-Object -First 1
    if ($direct) { $out += "$direct" }
    foreach ($a in @($qidm.attributes)) {
        if ("$($a.name)" -ieq $name) {
            foreach ($s in @($a.sourceField)) {
                $m = $formIds | Where-Object { $_ -ieq $s } | Select-Object -First 1
                if ($m) { $out += "$m" } else { $out += "$s" }
            }
        }
    }
    if (-not $out.Count) { $out = @($name) }
    return @($out | Select-Object -Unique)
}

function Resolve-Fid([string]$name, $qidm, $formIds) {
    $direct = $formIds | Where-Object { $_ -ieq $name } | Select-Object -First 1
    if ($direct) { return $direct }
    foreach ($a in @($qidm.attributes)) {
        if ("$($a.name)" -ieq $name) {
            foreach ($s in @($a.sourceField)) {
                $m = $formIds | Where-Object { $_ -ieq $s } | Select-Object -First 1
                if ($m) { return $m }
            }
            $sf = @($a.sourceField); if ($sf.Count) { return "$($sf[0])" }
        }
    }
    return $name
}

$grand = [ordered]@{ Built=0; Missing=0; PrefillDead=0; Shadow=0 }

Emit "" $null
Emit "================================================================================" 'Cyan'
Emit "  QUERY TRACE -- metadata combinations vs built, and what our own defaults hide" 'Cyan'
Emit "  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 'Cyan'
Emit "================================================================================" 'Cyan'

foreach ($pn in ($targets | Sort-Object)) {
    $provDir = Join-Path $repoRoot "providers\$pn"
    if (-not (Test-Path $provDir)) { Emit "  [SKIP] $pn -- no such provider folder" 'Yellow'; continue }
    $jsonPath = Get-ProviderRootJson -ProvDir $provDir -Provider $pn
    $xmlPath  = Join-Path $provDir "source\$pn.xml"
    if (-not $jsonPath) { Emit "  [SKIP] $pn -- no root JSON" 'Yellow'; continue }
    if (-not (Test-Path $xmlPath)) {
        # Variant providers reuse the base's metadata (see CLAUDE.md Provider Variants).
        $baseName = ($pn -split '_')[0..1] -join '_'
        $alt = Join-Path $repoRoot "providers\$baseName\source\$baseName.xml"
        if (Test-Path $alt) { $xmlPath = $alt } else { Emit "  [SKIP] $pn -- no metadata XML" 'Yellow'; continue }
    }

    $json = [System.IO.File]::ReadAllText($jsonPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    [xml]$xml = Get-Content $xmlPath -Raw

    # ── form prefills (initialValue) across all QIFs, by fieldId ──
    $prefill = @{}
    $formIds = @()
    foreach ($b in $json.bundles) { foreach ($c in $b.configurations) {
        if ($c.layout -and $c.layout.default) {
            foreach ($p in $c.layout.default.PSObject.Properties) {
                $fid = $p.Value.props.fieldId
                if (-not $fid) { continue }
                $formIds += "$fid"
                $iv = "$($p.Value.props.initialValue)"
                if ($iv -ne '') { $prefill["$fid".ToLower()] = $iv }
            }
        } } }
    $formIds = @($formIds | Select-Object -Unique)

    # ── built combos per query ──
    $builtByQuery = @{}
    $qidmByQuery  = @{}
    foreach ($b in $json.bundles) { foreach ($c in $b.configurations) {
        if (-not $c.combinations -or -not $c.query) { continue }
        if ($c.provider -eq 'RMS' -or "$($c.name)" -match 'RMS') { continue }
        $q = "$($c.query)"
        if (-not $builtByQuery[$q]) { $builtByQuery[$q] = @(); $qidmByQuery[$q] = $c }
        foreach ($cm in $c.combinations) {
            $kr = if ($cm.keyReference) { "$($cm.keyReference)" } else { "$($cm.keyRef)" }
            # combo defaults[] also make a field always-present
            foreach ($df in @($cm.requirements.defaults)) {
                if ($df.field) { $prefill["$($df.field)".ToLower()] = "$($df.value)" }
            }
            $builtByQuery[$q] += [pscustomobject]@{
                KeyRef=$kr; Set=@($cm.requirements.set | Where-Object { $_ }); Sig=(Sig $cm.requirements.set)
            }
        } } }

    # ── metadata combos per query ──
    $metaByQuery = @{}
    foreach ($t in $xml.SelectNodes('//*[local-name()="transaction" or local-name()="Transaction"]')) {
        $qn = "$($t.name)"; if (-not $qn) { $qn = "$($t.Name)" }
        if (-not $qn) { continue }
        $combos = @()
        # REAL METADATA SHAPE (verified against TX_TLETS.xml 2026-07-29 -- do not guess this):
        #   <Combination keyReference="RQ" primaryFieldReference="...">
        #     <Requirements>
        #       <Set>
        #         <Field reference="LicensePlateNumber"/>     <- REQUIRED
        #         <Field reference="LicensePlateYear"/>
        #         <Any>   <Field reference="State"/>   </Any>  <- OPTIONAL, NESTED INSIDE <Set>
        #         <Choice><Field .../><Field .../></Choice>    <- one-of, also nested
        #       </Set>
        #     </Requirements>
        #   </Combination>
        # Two traps: fields carry @reference (NOT InnerText), and <Any>/<Choice> are CHILDREN of
        # <Set>, so a descendant query on Set picks up the optionals as if they were required.
        # My first pass fell into both and reported every set[] as empty -- which made all 17
        # combos look like identical-signature SHADOWs. Caught only because TX's ground truth was
        # already known; that is why this parser is validated against a provider with a known answer.
        # ── A <Choice> MAY CONTAIN NESTED <Set> ELEMENTS, NOT JUST <Field> ──────────────────
        # THIRD shape, found on NY_NYSPIN_EJUSTICE 2026-07-30 and missed by both earlier readings:
        #   <Set><Choice><Set><Field .../></Set><Set><Field .../><Field .../></Set></Choice>
        #        <Any><Field .../></Any></Set>
        # Each nested <Set> is an ALTERNATIVE complete requirement set -- "either these fields, or
        # those". TX only ever had <Choice><Field/></Choice>, so a Choice/Field-only XPath read TX
        # correctly and returned EMPTY on NY. The outer <Set> then looked requirement-free, which is
        # how three real NY requirement structures (DriverHistoryQuery DALL x2, VehicleRegistration
        # RVEH) were reported as empty-set and MISSING, and how I wrongly concluded and RECORDED that
        # NY's empty-Set combos "carry ANY content with NO CHOICE". Decoded, they are exactly the
        # in-state / out-of-state pairs NY builds as DALL/DALLOUT, DALH/DALHOUT, RVEH/RVEHOUT.
        # A Combination carrying a Choice-of-Sets is therefore EXPANDED into one logical combination
        # per alternative, so each can be matched against the keyRef that implements it. Anything
        # less makes the gate under-read the spec, which is the one thing it exists to prevent.
        # LIMITATION #36 names NY as the Choice-set provider -- the KB said so and the XPath still
        # did not descend. Validate any change here against BOTH TX (Choice/Field) and NY (Choice/Set).
        $expanded = @()
        foreach ($cb0 in $t.SelectNodes('.//*[local-name()="Combination"]')) {
            $sn0 = $cb0.SelectSingleNode('./*[local-name()="Requirements"]/*[local-name()="Set"]')
            $altSets = @()
            if ($sn0) { $altSets = @($sn0.SelectNodes('./*[local-name()="Choice"]/*[local-name()="Set"]')) }
            if ($altSets.Count -gt 0) {
                $ai = 0
                foreach ($alt in $altSets) {
                    $ai++
                    $expanded += [pscustomobject]@{ Node = $cb0; Alt = $alt; AltIdx = $ai; AltTotal = $altSets.Count }
                }
            } else {
                $expanded += [pscustomobject]@{ Node = $cb0; Alt = $null; AltIdx = 0; AltTotal = 0 }
            }
        }
        foreach ($ex in $expanded) {
            $cb = $ex.Node
            $kr = "$($cb.keyReference)"; if (-not $kr) { $kr = "$($cb.keyRef)" }
            if ($ex.AltTotal -gt 1) { $kr = "$kr[alt$($ex.AltIdx)/$($ex.AltTotal)]" }
            $set = @(); $any = @(); $choice = @()
            $setNode = $cb.SelectSingleNode('./*[local-name()="Requirements"]/*[local-name()="Set"]')
            if ($setNode) {
                foreach ($f in $setNode.SelectNodes('./*[local-name()="Field"]'))              { $set    += "$($f.reference)" }
                foreach ($f in $setNode.SelectNodes('./*[local-name()="Any"]/*[local-name()="Field"]'))    { $any    += "$($f.reference)" }
                foreach ($f in $setNode.SelectNodes('./*[local-name()="Choice"]/*[local-name()="Field"]')) { $choice += "$($f.reference)" }
            }
            # this alternative's own fields become the REQUIRED set for this logical combination
            if ($ex.Alt) {
                foreach ($f in $ex.Alt.SelectNodes('./*[local-name()="Field"]'))                        { $set += "$($f.reference)" }
                foreach ($f in $ex.Alt.SelectNodes('./*[local-name()="Any"]/*[local-name()="Field"]'))  { $any += "$($f.reference)" }
            }
            $set    = @($set    | Where-Object { $_ })
            $any    = @($any    | Where-Object { $_ })
            $choice = @($choice | Where-Object { $_ })
            # A Choice is a mandatory one-of: it constrains firing, so it belongs to the required
            # signature, but no single member is individually required. Fold it in as one token so
            # two combos differing only in Choice membership do not collapse to the same signature.
            $sigParts = @($set)
            if ($choice.Count) { $sigParts += "choice(" + (Sig $choice) + ")" }
            $combos += [pscustomobject]@{
                KeyRef=$kr; Set=$set; Any=$any; Choice=$choice; Sig=(Sig $sigParts)
            }
        }
        if ($combos.Count) { $metaByQuery[$qn] = $combos }
    }

    Emit "" $null
    Emit "=== $pn  ($(Split-Path $jsonPath -Leaf)) ===" 'White'
    if ($metaByQuery.Count -eq 0) {
        Emit "  [INFO] no combinations parsed from $(Split-Path $xmlPath -Leaf) -- metadata shape not recognized; trace skipped" 'Yellow'
        continue
    }

    foreach ($q in ($builtByQuery.Keys | Sort-Object)) {
        $meta = $metaByQuery[$q]
        if (-not $meta) { continue }
        $built = @($builtByQuery[$q])
        $qidm  = $qidmByQuery[$q]
        $builtSigs = @($built | ForEach-Object { $_.Sig })

        $rows = New-Object System.Collections.Generic.List[string]
        $findings = 0   # count FINDINGS, not output lines -- a PREFILL-DEAD emits 2 lines and the
                        # header read "-1/7 built" when it subtracted line count from combo count.
        foreach ($mc in $meta) {
            # MATCHING IS CONTAINMENT, NOT EQUALITY. The build legitimately reshapes a metadata
            # combo: a mandatory <Choice> is split into one built combo per member with that member
            # promoted into set[] (BUILD_RULES / LIMITATION #21), and an any[] field may be promoted
            # to set[] to force routing (recorded in the accepted-divergence registry). Exact
            # signature equality would call all of those MISSING. So a metadata combo counts as
            # BUILT when some built combo (a) requires everything metadata requires, and (b) requires
            # nothing metadata does not even mention.
            # NAME SPACES DIFFER ON THE TWO SIDES -- normalize before comparing, or every DH and
            # every composite Name combo reads as a false MISSING (observed 2026-07-29: DH 0/2 and
            # DL 2/5 while all of them were in fact built):
            #   metadata says   Name / BirthDate / OperatorLicenseNumber      (attribute names)
            #   built set[] says NameLast,NameFirst / BirthDateDH / OperatorLicenseNumberDH
            #                                                        (form fieldIds = sourceFields)
            # One metadata field can map to SEVERAL form fields (Name -> NameLast+NameFirst+...),
            # so "covered" means at least one of its sourceFields is required by the built combo.
            $mcReqSf = @()   # each entry: array of acceptable form fieldIds for one required field
            foreach ($f in @($mc.Set))    { $mcReqSf += ,(@(Expand-Sf $f $qidm $formIds)) }
            $mcAllSf = @()
            foreach ($f in @(@($mc.Set) + @($mc.Any) + @($mc.Choice))) { $mcAllSf += @(Expand-Sf $f $qidm $formIds) }
            $mcAllSf = @($mcAllSf | ForEach-Object { "$_".ToLower() } | Select-Object -Unique)

            $isBuilt = $false
            foreach ($bc in $built) {
                $bSet = @($bc.Set | ForEach-Object { "$_".ToLower() })
                $coversRequired = $true
                foreach ($opts in $mcReqSf) {
                    $lc = @($opts | ForEach-Object { "$_".ToLower() })
                    if (-not (@($lc | Where-Object { $bSet -contains $_ }).Count)) { $coversRequired = $false; break }
                }
                $noStrangers = -not (@($bSet | Where-Object { $mcAllSf -notcontains $_ }).Count)
                if ($coversRequired -and $noStrangers) { $isBuilt = $true; break }
            }
            if ($isBuilt) { $grand.Built++; continue }

            # SHADOW: another metadata combo has an identical set signature
            $twins = @($meta | Where-Object { $_.Sig -eq $mc.Sig -and $_.KeyRef -ne $mc.KeyRef })

            # PREFILL-DEAD: a BUILT combo's set[] differs from this one only by fields that are
            # prefilled -- i.e. the built sibling matches whenever this one would, for free.
            $culprits = @()
            foreach ($bc in $built) {
                $extra = @($bc.Set | Where-Object { (Sig $_) -notin (@($mc.Set) | ForEach-Object { Sig $_ }) })
                if ($extra.Count -eq 0) { continue }
                $allPrefilled = $true; $these = @()
                foreach ($e in $extra) {
                    $fid = Resolve-Fid $e $qidm $formIds
                    if ($prefill.ContainsKey("$fid".ToLower())) { $these += "$fid=$($prefill["$fid".ToLower()])" }
                    else { $allPrefilled = $false; break }
                }
                if ($allPrefilled -and $these.Count) { $culprits += "$($bc.KeyRef) wins via $($these -join ',')" }
            }

            if ($culprits.Count) {
                $grand.PrefillDead++; $findings++
                $rows.Add("    [PREFILL-DEAD] $($mc.KeyRef) set[$($mc.Set -join ',')]")
                $rows.Add("                   -> $($culprits[0]) ; remove that prefill to recover this combo")
            } elseif ($twins.Count) {
                $grand.Shadow++; $findings++
                $rows.Add("    [SHADOW]       $($mc.KeyRef) set[$($mc.Set -join ',')] == $($twins[0].KeyRef) -- needs a discriminating condition")
            } else {
                $grand.Missing++; $findings++
                $rows.Add("    [MISSING]      $($mc.KeyRef) set[$($mc.Set -join ',')] -- adjudicate vs devdoc Basic scope")
            }
        }

        $tag = if ($findings -eq 0) { 'COMPLETE' } else { "$($meta.Count - $findings)/$($meta.Count) built" }
        $col = if ($rows.Count -eq 0) { 'Green' } else { 'Yellow' }
        Emit ("  {0,-44} {1}" -f $q, $tag) $col
        foreach ($r in $rows) { Emit $r 'Yellow' }
    }
}

Emit "" $null
Emit "--------------------------------------------------------------------------------" 'Cyan'
Emit ("  TOTALS: {0} built / {1} PREFILL-DEAD (recoverable) / {2} SHADOW / {3} MISSING" -f `
      $grand.Built, $grand.PrefillDead, $grand.Shadow, $grand.Missing) 'Cyan'
Emit "  PREFILL-DEAD = our own form default is hiding a real metadata combination." 'Cyan'
Emit "  Advisory only -- adjudicate MISSING against each devdoc's Basic Queries Supported." 'Cyan'
Emit "--------------------------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) {
    [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Report: $OutFile" -ForegroundColor DarkGray
}
exit 0
