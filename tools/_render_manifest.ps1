# ─────────────────────────────────────────────────────────────────────────────
#  _render_manifest.ps1 -- canonical RENDER manifest: labels + field ORDER
#                          (dot-sourced shared module)
#
#  ONE definition of "what this entity's form should look like", consumed by:
#    tools\emit_test_plan.ps1        -- emits the EXPECTED manifest into each render test
#    tools\audit_render_fidelity.ps1 -- compares a CAPTURED manifest against expected
#
#  WHY THIS EXISTS (2026-07-29, Rob's directive "render should be classified with the
#  labels and field ordering"):
#    Render was the one gate with no machine check. `audit_form_review.ps1` records only
#    THAT a human looked at a build, not WHAT they saw, and every label/title/ordering
#    defect in 2026-07 was caught by eye. Worse, JSON-side checks cannot catch a
#    JSON->DOM fidelity break: the retired Convert-UsxCasing recase collapsed Craft.js
#    `nodes` lists and forms silently rendered as tab names only while every validator
#    passed. So the expected side is derived here from the JSON, and the actual side is
#    snapshotted from the live tenant DOM -- a mismatch in label text, field order, or
#    presence is a FAIL, not a matter of whether anyone happened to notice.
#
#  ORDER COMES FROM A TREE WALK, NOT THE FLAT NODE MAP. The Craft.js layout is a flat
#  id->node dictionary; its key order is file-write order and has NO relationship to what
#  the officer sees. Visual order is ROOT -> FORM_ROOT -> ROOT_PAGE -> nodes[] (cards) ->
#  nodes[] (rows) -> nodes[] (fields), following each node's OWN `nodes` array. Existing
#  helpers (Get-QifFieldIds et al.) enumerate the flat map because they only need a set,
#  not a sequence -- do not copy them for ordering.
#
#  Exports:
#    Get-QifRenderManifest -Qif <qif> [-Variant default]
#    Compare-RenderManifest -Expected <obj> -Actual <obj>
# ─────────────────────────────────────────────────────────────────────────────

# Node types that carry an officer-visible input. FormCheckbox included: it renders a
# label the officer reads, so a wrong one is exactly the defect class this gate exists for.
$script:RM_FieldTypes = @('FormInput','FormSelect','FormDate','FormCheckbox')

function Get-QifRenderManifest {
    <#
      Returns the ordered, comparable render manifest for one entity + layout variant:

        @{ entity=<name>; variant='default'
           cards = @( @{ id; title; rows = @( @{ id; templateColumns;
                          fields = @( @{ fieldId; label; type; hidden; initialValue } ) } ) } ) }

      Hidden fields are INCLUDED and flagged. They must not be compared as visible
      (a hidden gate-feeder legitimately has no rendered label) but omitting them
      entirely would let a field flip hidden<->visible with nothing noticing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Qif,
        [string]$Variant = 'default'
    )

    $layout = $null
    if ($Qif -and $Qif.layout) {
        $lp = $Qif.layout.PSObject.Properties[$Variant]
        if ($lp) { $layout = $lp.Value }
    }
    if (-not $layout) { return $null }

    function Get-Node($id) {
        $p = $layout.PSObject.Properties[$id]
        if ($p) { return $p.Value }
        return $null
    }
    function Get-ChildIds($node) {
        if (-not $node) { return @() }
        # A single-child `nodes` list can deserialize as a bare string; force an array or
        # the walk silently iterates characters (this is the Craft.js nodes-collapse shape
        # that broke rendering once already -- see header).
        return @($node.nodes | Where-Object { $_ })
    }

    # Walk to the page: ROOT -> FORM_ROOT -> ROOT_PAGE. Tolerate depth differences by
    # descending until we hit nodes that are Cards.
    $cards = New-Object System.Collections.Generic.List[object]

    function Walk-ForCards($nodeId, [int]$depth) {
        if ($depth -gt 6) { return }
        $node = Get-Node $nodeId
        if (-not $node) { return }
        $rn = "$($node.type.resolvedName)"
        if ($rn -eq 'Card') {
            $rows = New-Object System.Collections.Generic.List[object]
            foreach ($rowId in (Get-ChildIds $node)) {
                $rowNode = Get-Node $rowId
                if (-not $rowNode) { continue }
                $fields = New-Object System.Collections.Generic.List[object]
                foreach ($fid in (Get-ChildIds $rowNode)) {
                    $fNode = Get-Node $fid
                    if (-not $fNode) { continue }
                    $frn = "$($fNode.type.resolvedName)"
                    if ($script:RM_FieldTypes -notcontains $frn) { continue }
                    $fields.Add([ordered]@{
                        fieldId      = "$($fNode.props.fieldId)"
                        label        = "$($fNode.props.label)"
                        type         = $frn
                        hidden       = [bool]$fNode.hidden
                        initialValue = if ($null -ne $fNode.props.initialValue) { "$($fNode.props.initialValue)" } else { $null }
                    })
                }
                $rows.Add([ordered]@{
                    id             = "$rowId"
                    templateColumns = @($rowNode.props.templateColumns)
                    hidden         = [bool]$rowNode.hidden
                    fields         = $fields.ToArray()
                })
            }
            $cards.Add([ordered]@{
                id    = "$nodeId"
                title = if ($null -ne $node.props.title) { "$($node.props.title)" } else { $null }
                rows  = $rows.ToArray()
            })
            return
        }
        foreach ($childId in (Get-ChildIds $node)) { Walk-ForCards $childId ($depth + 1) }
    }

    Walk-ForCards 'ROOT' 0

    return [ordered]@{
        entity  = "$($Qif.targetEntity)"
        variant = $Variant
        cards   = $cards.ToArray()
    }
}

function Get-RmFlatFields($Manifest) {
    <#
      Flattens a manifest to an ordered list of visible fields, each stamped with its
      card/row context and its 1-based visual position. Position is what makes an
      ORDER change detectable -- comparing sets alone cannot see a reorder.
    #>
    $out = New-Object System.Collections.Generic.List[object]
    $pos = 0
    foreach ($card in @($Manifest.cards)) {
        foreach ($row in @($card.rows)) {
            foreach ($f in @($row.fields)) {
                if ($f.hidden) { continue }
                $pos++
                $out.Add([pscustomobject]@{
                    Position = $pos
                    FieldId  = "$($f.fieldId)"
                    Label    = "$($f.label)"
                    Type     = "$($f.type)"
                    CardId   = "$($card.id)"
                    RowId    = "$($row.id)"
                })
            }
        }
    }
    return $out
}

function Compare-RenderManifest {
    <#
      Compares an EXPECTED manifest (JSON-derived) against an ACTUAL one (DOM-captured).
      Returns a list of findings; empty list = the rendered form matches the JSON.

      Finding kinds:
        MISSING_FIELD  -- expected visible field absent from the render (the nodes-collapse
                          class of bug, and the reason this gate exists at all)
        EXTRA_FIELD    -- rendered field the JSON does not define
        LABEL_MISMATCH -- same field, different visible label
        ORDER_MISMATCH -- same field set, different visual sequence
        CARD_MISMATCH  -- field rendered under a different card than the JSON places it
        TITLE_MISMATCH -- card title text differs

      Label comparison is whitespace-normalized and case-SENSITIVE: the OLN and
      "NCIC Image" conventions are exact-case rules (CLAUDE.md / BUILD_RULES Sec 11), so
      folding case here would blind the gate to the very drift it is meant to catch.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Actual
    )

    $findings = New-Object System.Collections.Generic.List[object]
    function Add-F($kind, $fieldId, $msg) {
        $findings.Add([pscustomobject]@{ Kind = $kind; FieldId = $fieldId; Message = $msg })
    }
    function Norm($s) { return (("$s" -replace '\s+', ' ').Trim()) }

    $exp = Get-RmFlatFields $Expected
    $act = Get-RmFlatFields $Actual

    $expById = @{}; foreach ($e in $exp) { $expById[$e.FieldId.ToLower()] = $e }
    $actById = @{}; foreach ($a in $act) { $actById[$a.FieldId.ToLower()] = $a }

    foreach ($e in $exp) {
        $k = $e.FieldId.ToLower()
        if (-not $actById.ContainsKey($k)) {
            Add-F 'MISSING_FIELD' $e.FieldId "expected at position $($e.Position) (label '$($e.Label)') but not rendered"
            continue
        }
        $a = $actById[$k]
        if ((Norm $e.Label) -cne (Norm $a.Label)) {
            Add-F 'LABEL_MISMATCH' $e.FieldId "JSON label '$(Norm $e.Label)' vs rendered '$(Norm $a.Label)'"
        }
        # Card identity: Craft.js card IDs (CARD_VEH, ...) are BUILD-TIME ids and do not exist
        # in the rendered DOM, so a DOM-captured manifest legitimately carries no CardId. Only
        # compare when the actual side actually supplies one (e.g. JSON-vs-JSON self-checks);
        # comparing unconditionally would flag every live capture (card grouping is still
        # covered by the card-INDEX pairing and the title check below).
        if ($e.CardId -and $a.CardId -and $e.CardId -ne $a.CardId) {
            Add-F 'CARD_MISMATCH' $e.FieldId "JSON places it on card '$($e.CardId)', rendered under '$($a.CardId)'"
        }
    }
    foreach ($a in $act) {
        if (-not $expById.ContainsKey($a.FieldId.ToLower())) {
            Add-F 'EXTRA_FIELD' $a.FieldId "rendered at position $($a.Position) (label '$($a.Label)') but not defined in the JSON layout"
        }
    }

    # Order: compare the sequences restricted to fields present in BOTH, so a missing or
    # extra field is reported once as itself and does not cascade into phantom reorderings.
    $common = @($exp | Where-Object { $actById.ContainsKey($_.FieldId.ToLower()) } | ForEach-Object { $_.FieldId })
    $actCommon = @($act | Where-Object { $expById.ContainsKey($_.FieldId.ToLower()) } | ForEach-Object { $_.FieldId })
    for ($i = 0; $i -lt [Math]::Min($common.Count, $actCommon.Count); $i++) {
        if ($common[$i] -ne $actCommon[$i]) {
            Add-F 'ORDER_MISMATCH' $common[$i] "expected at visual slot $($i + 1) but '$($actCommon[$i])' is rendered there"
            break   # one report: the first divergence explains the shift, N more would be noise
        }
    }

    # Card titles, in order.
    $expCards = @($Expected.cards); $actCards = @($Actual.cards)
    for ($i = 0; $i -lt [Math]::Min($expCards.Count, $actCards.Count); $i++) {
        if ($null -ne $expCards[$i].title -and (Norm $expCards[$i].title) -cne (Norm $actCards[$i].title)) {
            Add-F 'TITLE_MISMATCH' "$($expCards[$i].id)" "JSON title '$(Norm $expCards[$i].title)' vs rendered '$(Norm $actCards[$i].title)'"
        }
    }

    return $findings
}
