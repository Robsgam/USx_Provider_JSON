<#
  audit_layout_flow.ps1 -- IS THE FORM A PROJECTION OF ITS COMBINATIONS?

  WHY THIS EXISTS
  ---------------
  Every other gate asks whether the REQUEST is correct. render_layout renders the form but
  has no opinion. verify_build CHECK 15 checks label TEXT. audit_wiring_closure checks that
  a control reaches the wire. NOTHING asked whether the form's SHAPE -- row order, field
  order, widths, grouping -- follows the query paths the officer is actually driving.

  It turns out that question is mechanical, not taste. FL_FCIC and NY_NYSPIN_EJUSTICE, the
  two most tenant-proven layouts in the portfolio, INDEPENDENTLY converged on the same
  skeleton, and that skeleton is a direct projection of the combination array:

      row 1  = combo[0]'s primaryFieldReference + combo[0]'s own any[] qualifiers
      row 2  = combo[1]'s primaryFieldReference + combo[1]'s own any[] qualifiers
      ...
      row N  = the fields COMMON to every combo (State, Image, Stolen Check)
      row N+1= hidden / auto-populated fields, [12], last

  FL Vehicle is literally that: [Plate|PlateType|PlateYear] then [VIN|Make|Year] then
  [Decal|State|Image] then [Requestor]. So a form that disagrees with its own combinations
  is not a matter of preference -- it is failing to teach the officer the paths that exist.

  THE DEFECT THAT MOTIVATED IT (AZ_AZDPS v3.9, found 2026-08-11): RegistrationStateDH is
  MANDATORY in both DriverHistory combos (set[]) and sat at the BOTTOM of the card, below
  every optional name part. An officer fills OLN, presses search, and fails -- with every
  existing gate green, because the REQUEST would have been correct if only they had known
  to scroll. FL and NY both put State in row 1 beside OLN.

  NOT WIRED INTO enforce / pipeline ON PURPOSE (Rob, 2026-08-11: "lets test before we put
  any of this in the the production pipeline"). Run it standalone. Wire it only once the
  portfolio baseline is understood and the findings have been adjudicated per provider --
  layout is the one area where providers legitimately differ, so a premature blocking gate
  would redden the portfolio for differences that were deliberate.

  ADVISORY BY NATURE. Every finding names the rule and the evidence so a human can accept
  it. It prints its DENOMINATORS (cards / rows / fields / combos mapped) because a layout
  gate that parsed nothing would otherwise report a clean form (ENGINEERING_STANDARD 4.3).

  Layout traversal MIRRORS tools/render_layout.ps1 (flat nodeId map; ROOT -> FormRoot ->
  RootPage -> cards; Row.props.templateColumns; field props fieldId/label/maxLength/hidden).
  Deliberately reads the DEFAULT variant only -- CAD_DISPATCH / FIRST_RESPONDER prepend a
  context card, which is correct there and would be a false finding here.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [string]$Provider,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here '_resolve_provider_json.ps1')

$lines = @()
function Emit($t, $c) {
    $script:lines += $t
    if (-not $Quiet) { if ($c) { Write-Host $t -ForegroundColor $c } else { Write-Host $t } }
}

# ---- L5: ONE-DIRECTIONAL. Flags WASTED width only, never "too narrow". ---------
# The first draft bucketed width against maxLength in both directions and was wrong:
# NY_NYSPIN_EJUSTICE deliberately gives a maxLen=35 middle name only [2], because width
# should track EXPECTED INPUT, not capacity -- nobody types 35 characters of middle name.
# So narrower-than-capacity is a legitimate choice and is no longer reported. What IS
# objectively wasteful is handing a whole 12-column row to a control that cannot use it.
function Test-WastedWidth($width, $maxLen, $isDropdown, $isDate) {
    if ($width -ne 12) { return $false }
    if ($isDropdown -or $isDate) { return $true }
    if ($null -ne $maxLen -and $maxLen -gt 0 -and $maxLen -le 15) { return $true }
    return $false
}

function Get-Cards($layout) {
    $members = ($layout | Get-Member -MemberType NoteProperty).Name
    $root = $members | Where-Object { $_ -eq 'ROOT' }
    if (-not $root) { $root = $members[0] }
    $rootNode = $layout.$root
    $formRoot = if ($rootNode.nodes) { $rootNode.nodes[0] } else { $null }
    if ($formRoot -and $layout.$formRoot -and $layout.$formRoot.nodes) {
        $rootPage = $layout.$formRoot.nodes[0]
        if ($rootPage -and $layout.$rootPage -and $layout.$rootPage.nodes) {
            # Filter to actual Cards. Without this, RootPage children that are containers or
            # stray nodes were counted as cards -- CA_CLETS_OCATS reported "16 cards / 14
            # rows", which is impossible, and MD_METERS 13 cards against a 6-query provider.
            # A denominator that is obviously wrong discredits every finding beside it.
            $out = @()
            foreach ($id in @($layout.$rootPage.nodes)) {
                $n = $layout.$id
                if ($n -and $n.type.resolvedName -eq 'Card') { $out += $id }
            }
            return $out
        }
    }
    return @()
}

function Get-RowsAndFields($layout, $cardId) {
    # NOTE: `hidden` is a NODE-level property ($n.hidden), NOT $n.props.hidden. Reading the
    # props path instead produced NINE false findings on the first AZ_AZDPS run (five
    # "mandatory dexStateUserId is below optionals", two RegistrationStateDH, two width) --
    # every one of them a hidden gate-feeder the officer never sees. verify_build CHECK 6
    # reads the node level and was right. A row can also be hidden as a whole, which hides
    # its children regardless of their own flag.
    $rows = @()
    $card = $layout.$cardId
    if (-not $card -or -not $card.nodes) { return $rows }
    foreach ($rowId in @($card.nodes)) {
        $rn = $layout.$rowId
        if (-not $rn) { continue }
        $rt = $rn.type.resolvedName
        if ($rt -notin @('Row', 'CadRow', 'FrRow')) { continue }
        $rowHidden = ($rn.hidden -eq $true)
        $flds = @()
        foreach ($fid in @($rn.nodes)) {
            $fn = $layout.$fid
            if (-not $fn) { continue }
            $t = $fn.type.resolvedName
            if ($t -in @('Row', 'CadRow', 'FrRow', 'Card', 'Container')) { continue }
            $flds += [pscustomobject]@{
                nodeId     = $fid
                fieldId    = if ($fn.props.fieldId) { [string]$fn.props.fieldId } else { [string]$fid }
                label      = if ($null -ne $fn.props.label) { [string]$fn.props.label } else { '' }
                maxLen     = if ($fn.props.maxLength) { [int]$fn.props.maxLength } else { $null }
                hidden     = ($rowHidden -or ($fn.hidden -eq $true))
                isDropdown = ($t -match 'Select')
                isDate     = ($t -match 'Date')
                # PREFILLED: a form initialValue means the officer can never leave it blank, so a
                # "mandatory field positioned late" cannot cause the failure L2 claims. Needed for
                # L2 guard (e). Counts ONLY a non-empty form initialValue -- combo defaults[] do NOT
                # participate (CAD applies those, the form does not), which is the same rule
                # audit_combo_reachability uses for always-present.
                prefilled  = ($null -ne $fn.props.initialValue -and "$($fn.props.initialValue)" -ne '')
            }
        }
        $cols = @()
        if ($rn.props.templateColumns) { $cols = @($rn.props.templateColumns) }
        $rows += [pscustomobject]@{ rowId = $rowId; cols = $cols; fields = $flds; hidden = $rowHidden }
    }
    return $rows
}

function Audit-One($jsonPath, $provName) {
    $j = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $bundles = @($j.bundles)

    # CommSys QIDMs (provider bundle) and RMS QIDMs, keyed by targetEntity
    $commsysByEntity = @{}
    $rmsFields = @{}
    foreach ($b in $bundles) {
        foreach ($cfg in @($b.configurations)) {
            if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            $isRms = ($b.provider -eq 'RMS')
            if ($isRms) {
                foreach ($a in @($cfg.attributes)) {
                    foreach ($sf in @($a.sourceField)) { if ($sf) { $rmsFields[[string]$sf] = $true } }
                }
                continue
            }
            if ($cfg.name -match 'Results') { continue }
            $ent = [string]$cfg.targetEntity
            if (-not $ent) { continue }
            if (-not $commsysByEntity.ContainsKey($ent)) { $commsysByEntity[$ent] = @() }
            $commsysByEntity[$ent] += $cfg
        }
    }

    $qifs = @()
    foreach ($b in $bundles) {
        foreach ($cfg in @($b.configurations)) {
            if ($cfg.type -eq 'QUERYINPUTFORM') { $qifs += $cfg }
        }
    }

    $nCards = 0; $nRows = 0; $nFields = 0; $nCombos = 0; $nFindings = 0
    $findings = @()

    foreach ($qif in $qifs) {
        $ent = [string]$qif.targetEntity
        $layout = $qif.layout.default
        if (-not $layout) { continue }

        $combos = @()
        foreach ($cfg in @($commsysByEntity[$ent])) {
            foreach ($cb in @($cfg.combinations)) {
                $combos += [pscustomobject]@{
                    keyRef = [string]$cb.keyReference
                    pf     = [string]$cb.primaryFieldReference
                    set    = @($cb.requirements.set    | ForEach-Object { [string]$_ })
                    any    = @($cb.requirements.any    | ForEach-Object { [string]$_ })
                }
            }
        }
        $nCombos += $combos.Count

        # union of set[] and any[] across this entity's combos
        $allSet = @{}; $allAny = @{}
        $anyShareCount = @{}   # how many combos list this field as optional -> shared context
        foreach ($c in $combos) {
            foreach ($f in $c.set) { $allSet[$f] = $true }
            foreach ($f in $c.any) {
                $allAny[$f] = $true
                if (-not $anyShareCount.ContainsKey($f)) { $anyShareCount[$f] = 0 }
                $anyShareCount[$f]++
            }
        }

        # ---- L4 CARD COUNT PER ENTITY -- the un-collapsed-layout detector ------------
        # The portfolio's single biggest cosmetic split, and it is one number. Providers that
        # have had the card-collapse pass run ONE card per entity (Person is legitimately TWO
        # -- DL + DH -- because the DH-suffix fieldIds are a separate field pool, which is the
        # isolation mechanism). Providers that have not still carry the old
        # SEARCH-OPTIONS / PLATE / VIN split: MD_METERS has 3 Vehicle cards, CA_VENTURA_COUNTY
        # 20 cards overall, CA_CLETS_OCATS 16.
        # This also explains why those providers score LOW on the other rules: small cards
        # hold few rows, so there are fewer chances to trip L2/L5/L6. Their low counts are
        # partly vacuous, which is why this rule reports the card count rather than staying
        # silent about it.
        $entCards = @(Get-Cards $layout)
        $cardCap = if ($ent -eq 'Person') { 2 } else { 1 }
        if ($entCards.Count -gt $cardCap) {
            $findings += "[L4 CARDS-NOT-COLLAPSED] $ent -- $($entCards.Count) cards where the collapsed standard is $cardCap. The card-collapse pass has not reached this entity, so its query paths are split across cards instead of enumerated in one card title. NOTE: fewer rows per card also means the other rules examined less of this entity."
        }

        foreach ($cardId in $entCards) {
            $nCards++
            $rows = Get-RowsAndFields $layout $cardId
            $nRows += $rows.Count

            # ---- L3 HIDDEN-LAST: a hidden-only row must not precede a visible row -----
            $lastVisibleIdx = -1
            for ($i = 0; $i -lt $rows.Count; $i++) {
                $vis = @($rows[$i].fields | Where-Object { -not $_.hidden })
                if ($vis.Count -gt 0) { $lastVisibleIdx = $i }
            }
            for ($i = 0; $i -lt $rows.Count; $i++) {
                $r = $rows[$i]
                if ($r.fields.Count -eq 0) { continue }
                $vis = @($r.fields | Where-Object { -not $_.hidden })
                if ($vis.Count -eq 0 -and $i -lt $lastVisibleIdx) {
                    $findings += "[L3 HIDDEN-MID-CARD] $ent / $cardId / $($r.rowId) -- hidden-only row sits ABOVE visible content (row $($i+1) of $($rows.Count)); it splits a field group. Move auto/hidden rows to the bottom. fields: $((@($r.fields).fieldId) -join ', ')"
                }
            }

            foreach ($r in $rows) {
                $nFields += $r.fields.Count

                # ---- L6 ROW-SUM-12 (visible MULTI-FIELD rows only) -------------------
                # Only rows with 2+ fields are judged. A SINGLE-field row is a deliberate
                # left-aligned control, and demanding it sum to 12 is unsatisfiable next to L5:
                # a lone dropdown at [12] is wasted width (L5) and at [4] is a short row (L6),
                # so there is no legal width. Found by applying the rules to AZ_AZDPS v3.10 --
                # fixing four L5 findings created four new L6 ones, which is a rule conflict, not
                # progress. A multi-field row that does not tile to 12 IS a mistake.
                if ($r.cols.Count -gt 1 -and $r.fields.Count -gt 1 -and -not $r.hidden) {
                    $sum = 0
                    foreach ($c in $r.cols) { $sum += [int]$c }
                    if ($sum -ne 12) {
                        $findings += "[L6 ROW-NOT-12] $ent / $($r.rowId) -- templateColumns [$($r.cols -join ' ')] sums to $sum, not 12 ($(12-$sum) column(s) of dead space)"
                    }
                    if ($r.cols.Count -ne $r.fields.Count -and $r.fields.Count -gt 0) {
                        $findings += "[L6 COL-FIELD-MISMATCH] $ent / $($r.rowId) -- $($r.cols.Count) column(s) declared for $($r.fields.Count) field(s)"
                    }
                }

                # ---- L5 WASTED WIDTH -------------------------------------------------
                for ($k = 0; $k -lt $r.fields.Count; $k++) {
                    $f = $r.fields[$k]
                    if ($f.hidden) { continue }
                    if ($k -ge $r.cols.Count) { continue }
                    $w = [int]$r.cols[$k]
                    if ((Test-WastedWidth $w $f.maxLen $f.isDropdown $f.isDate) -and $r.fields.Count -eq 1) {
                        $cap = if ($f.isDropdown) { 'a dropdown' } elseif ($f.isDate) { 'a date picker' } else { "maxLen=$($f.maxLen)" }
                        $findings += "[L5 WASTED-WIDTH] $ent / $($r.rowId) / $($f.fieldId) -- alone on a full 12-column row, but it is $cap and cannot use the space. Pair it with a related control (FL/NY put State and Image together at [3]+[3])."
                    }

                    # ---- L7 LABEL-vs-CAPACITY (initial-abbreviation on a long field) --
                    if ($f.label -match '^(MI|M\.I\.)$' -and $f.maxLen -and $f.maxLen -gt 1) {
                        $findings += "[L7 LABEL-CAPACITY] $ent / $($f.fieldId) -- label '$($f.label)' means middle INITIAL but maxLength=$($f.maxLen) accepts a full middle name. Use 'Middle Name' (FL keeps 'MI' only because its field is maxLen=1)"
                    }
                }
            }

            # ---- L2 SET-BEFORE-ANY, per combo, in reading order ----------------------
            $order = @()
            foreach ($r in $rows) { foreach ($f in $r.fields) { if (-not $f.hidden) { $order += $f.fieldId } } }
            $pos = @{}
            for ($i = 0; $i -lt $order.Count; $i++) { if (-not $pos.ContainsKey($order[$i])) { $pos[$order[$i]] = $i } }
            # fieldId -> field object, for the L2 guards (d) fallback-satisfiable and (e) prefilled.
            # Built from ALL rows including hidden ones: a hidden prefilled control is still always
            # present on the wire, so it can satisfy a fallback combo's set[] even though the officer
            # never sees it (AZ's dexStateUserId is exactly that).
            $fieldById = @{}
            foreach ($r in $rows) { foreach ($f in $r.fields) { if (-not $fieldById.ContainsKey($f.fieldId)) { $fieldById[$f.fieldId] = $f } } }

            foreach ($c in $combos) {
                $setPos = @()
                foreach ($f in $c.set) { if ($pos.ContainsKey($f)) { $setPos += [pscustomobject]@{ f = $f; p = $pos[$f] } } }
                $anyPos = @()
                foreach ($f in $c.any) {
                    # (a) An any[] field that is ANOTHER combo's set[] is an ALTERNATIVE
                    #     IDENTIFIER, not a qualifier -- Boat BQH has BoatHullIdNumber in
                    #     set[] and RegistrationNumber in any[], while BQ has Registration-
                    #     Number in set[]. Two identifiers side by side is correct design.
                    if ($allSet.ContainsKey($f)) { continue }
                    # (b) A field appearing in MORE THAN ONE combo's any[] is SHARED CONTEXT
                    #     (ImageIndicator, RegistrationState, purposeCode). Rule 3 says those
                    #     belong in one group with the primary identifier, which puts them
                    #     ABOVE the combo-specific mandatory fields lower down -- by design.
                    #     Without this exclusion L2 punished the very convention it should
                    #     reward: it raised 8 findings against FL_FCIC, whose layout is one of
                    #     the two this ruleset was derived FROM, all of the form "SexCode is
                    #     after ImageIndicator". L2 was 71 of 165 portfolio findings before
                    #     this guard.
                    if ($anyShareCount.ContainsKey($f) -and $anyShareCount[$f] -gt 1) { continue }
                    # (c) NAME COMPONENTS are one concept and are grouped as a unit (rule L8: all
                    #     four parts on one row). Middle name and suffix are optional while Last,
                    #     DOB and Sex may be mandatory, so grouping the name necessarily puts two
                    #     optionals ahead of them -- L8 and L2 conflict, and L8 wins because a name
                    #     is a single thing to an officer. Found by applying the rules to AZ v3.10:
                    #     the KQH finding survived a correct fix, which means the rule was wrong.
                    if ($f -match '^[Nn]ame(Middle|Suffix)') { continue }
                    if ($pos.ContainsKey($f)) { $anyPos += [pscustomobject]@{ f = $f; p = $pos[$f] } }
                }
                if ($setPos.Count -eq 0 -or $anyPos.Count -eq 0) { continue }
                $maxSet = ($setPos | Sort-Object p -Descending)[0]
                $minAny = ($anyPos | Sort-Object p)[0]
                if ($maxSet.p -gt $minAny.p) {
                    # (d) FALLBACK EXISTS -- the whole finding asserts "an officer can fill everything
                    #     visible above it and STILL FAIL". That is FALSE when another combo in the
                    #     same query fires on what is already filled above. NY_NYSPIN_EJUSTICE is the
                    #     case that exposed it: RVIN is set[VIN, RegistrationState] with State on the
                    #     shared-context row BELOW the identifiers, so L2 flagged it -- but RCAR is
                    #     set[VehicleIdentificationNumber] gated State NOT_EXISTS, so a VIN with State
                    #     left blank fires RCAR. That is the standard in-state/out-of-state fork, and
                    #     State sitting below IS correct: it is the field that chooses the network.
                    #     FL_FCIC is identical (FRQVehicleIdentificationNumber backs
                    #     RQVehicleIdentificationNumber). Without this guard L2 was about to buy a
                    #     75-test and a 118-test re-sweep for defects that do not exist.
                    #     THE FALLBACK MUST BELONG TO THE SAME SEARCH PATH, and getting this wrong
                    #     turns the guard into a blanket suppressor. My first version accepted any
                    #     combo satisfiable from fields POSITIONED ABOVE the flagged one -- and a
                    #     LAW 2 probe (delete RCAR from a replica; the finding must return) showed it
                    #     did NOT return: it had latched onto RVEH (set[LicensePlateNumber]) merely
                    #     because a plate control sits on row 1. But the officer filled a VIN, not a
                    #     plate, so RVEH is no fallback at all. Since almost every card has some
                    #     identifier above, that version would have suppressed nearly every real L2.
                    #     Correct test: the alternative's set[] must be satisfiable from THIS combo's
                    #     OWN pool minus the flagged field (plus anything prefilled, which is always
                    #     present). NY: RVIN pool minus State = {VIN}; RCAR set{VIN} fits -> suppress.
                    #     RVEH set{LicensePlateNumber} does not fit -> correctly rejected.
                    $ownPool = @{}
                    foreach ($sf in $c.set) { if ($sf -ne $maxSet.f) { $ownPool[$sf] = 1 } }
                    foreach ($af in $c.any) { if ($af -ne $maxSet.f) { $ownPool[$af] = 1 } }
                    $fallback = $null
                    foreach ($alt in $combos) {
                        if ($alt.keyRef -eq $c.keyRef) { continue }
                        if ($alt.set -contains $maxSet.f) { continue }        # still needs the field
                        if (@($alt.set).Count -eq 0) { continue }
                        $satisfiable = $true
                        foreach ($sf in $alt.set) {
                            if ($ownPool.ContainsKey($sf)) { continue }       # same search path
                            $fld = $fieldById[$sf]
                            if ($fld -and $fld.prefilled) { continue }        # always present anyway
                            $satisfiable = $false; break
                        }
                        if ($satisfiable) { $fallback = $alt.keyRef; break }
                    }
                    if ($fallback) { continue }

                    # (e) PREFILLED -- a mandatory field carrying a form initialValue can never be
                    #     left blank, so its POSITION cannot cause a failure. CA_CLETS/CA_CONTRA_COSTA
                    #     flag 'purposeCode', which is prefilled 'C' on every entity.
                    $flaggedFld = $fieldById[$maxSet.f]
                    if ($flaggedFld -and $flaggedFld.prefilled) { continue }

                    $nAfter = @($anyPos | Where-Object { $_.p -lt $maxSet.p }).Count
                    $findings += "[L2 SET-BELOW-ANY] $ent / combo $($c.keyRef) -- MANDATORY '$($maxSet.f)' is positioned AFTER $nAfter optional field(s) of the same combo (first is '$($minAny.f)'), it is NOT prefilled, and NO other combo in this query fires on what is filled above it. An officer can fill everything visible above and still get no query. Mandatory fields lead."
                }
            }

            # ---- L1 ROW ORDER -- WITHDRAWN, the premise was wrong ---------------------
            # This check compared each combo's identifier position on the form against the
            # combo's index in the QIDM array. It fired 4 times on AZ_AZDPS and every one was
            # WRONG, because the two orderings encode different things:
            #   * combo array order = SPECIFICITY, for first-match FIRING (most set[] first).
            #     AZ's DQPN has 5 set[] fields so it sorts ahead of DQP, which has OLN.
            #   * form order = IDENTIFIER PRIORITY, what the officer reaches for first, which
            #     is expressed by the NOT_EXISTS guardrails (OLN > Name, Plate > VIN, Hull >
            #     Reg) -- NOT by the array index.
            # So "OLN appears before Name while DQ sorts after DQN" is CORRECT behaviour and
            # exactly what the OLN>Name guardrail asks for. A real version of this check must
            # read the guardrail conditions and compare against those. Left unimplemented
            # rather than shipped wrong: a check that fires on correct builds trains the
            # reader to ignore the report.

            # ---- L9 RMS-ONLY FIELD SHARING A ROW WITH A CommSys IDENTIFIER -----------
            foreach ($r in $rows) {
                $rmsOnly = @($r.fields | Where-Object { -not $_.hidden -and $rmsFields.ContainsKey($_.fieldId) -and -not $allSet.ContainsKey($_.fieldId) -and -not $allAny.ContainsKey($_.fieldId) })
                if ($rmsOnly.Count -eq 0) { continue }
                $csIdent = @($r.fields | Where-Object { -not $_.hidden -and $allSet.ContainsKey($_.fieldId) })
                if ($csIdent.Count -gt 0) {
                    $findings += "[L9 RMS-ONLY-BESIDE-IDENTIFIER] $ent / $($r.rowId) -- '$((@($rmsOnly).fieldId) -join ', ')' feed the RMS query ONLY (in no CommSys combination), but share a row with the mandatory state identifier '$((@($csIdent).fieldId) -join ', ')'. Reads as though it queries the state; it does not."
                }
            }
        }
    }

    Emit ''
    Emit "########## $provName ##########"
    Emit "  compared: $nCards card(s) / $nRows row(s) / $nFields field(s) / $nCombos combination(s)"
    if ($nRows -eq 0) {
        Emit '  [FAIL] 0 rows parsed -- the layout was not read. A gate that parsed nothing has NOT passed.' 'Red'
        return 1
    }
    if ($nCombos -eq 0) {
        Emit '  [NOTE] 0 combinations found -- L1/L2/L9 could not run for this provider.' 'Yellow'
    }
    if ($findings.Count -eq 0) {
        Emit '  [PASS] layout is consistent with the combination array' 'Green'
        return 0
    }
    foreach ($f in ($findings | Sort-Object)) { Emit "  $f" 'Yellow' }
    Emit "  $($findings.Count) finding(s) -- ADVISORY. Each names its rule; adjudicate per provider." 'Yellow'
    return $findings.Count
}

$targets = @()
if ($Path) {
    $targets += [pscustomobject]@{ name = (Split-Path (Split-Path $Path -Parent) -Leaf); path = $Path }
} elseif ($Provider) {
    $pd = Join-Path (Join-Path (Split-Path $here -Parent) 'providers') $Provider
    $p = Get-ProviderRootJson -ProvDir $pd -Provider $Provider
    if (-not $p) { Write-Host "[FAIL] no active JSON for $Provider" -ForegroundColor Red; exit 1 }
    $targets += [pscustomobject]@{ name = $Provider; path = $p }
} elseif ($All) {
    $root = Join-Path (Split-Path $here -Parent) 'providers'
    foreach ($d in (Get-ChildItem $root -Directory | Sort-Object Name)) {
        $p = Get-ProviderRootJson -ProvDir $d.FullName -Provider $d.Name
        if ($p) { $targets += [pscustomobject]@{ name = $d.Name; path = $p } }
    }
} else {
    Write-Host 'usage: audit_layout_flow.ps1 -Provider <NAME> | -Path <json> | -All' -ForegroundColor Yellow
    exit 2
}

Emit '================================================================'
Emit '  LAYOUT FLOW AUDIT -- is the form a projection of its combinations?'
Emit '  ADVISORY. Not wired into enforce/pipeline (Rob, 2026-08-11).'
Emit '================================================================'

$total = 0; $provWith = 0
foreach ($t in $targets) {
    $n = Audit-One $t.path $t.name
    if ($n -gt 0) { $total += $n; $provWith++ }
}

Emit ''
Emit '----------------------------------------------------------------'
Emit "  $($targets.Count) provider(s) compared -- $provWith with finding(s), $total finding(s) total"
Emit '----------------------------------------------------------------'

if ($OutFile) {
    $d = Split-Path $OutFile -Parent
    if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}
exit 0
