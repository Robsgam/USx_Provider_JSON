param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Entity,
    [ValidateSet('default','compact','detail','all')][string]$Variant = 'all',
    [switch]$QidmOnly,
    [switch]$Summary
)

$data = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
$entities = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$providerBundle = $data.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' }
$rmsBundle = $data.bundles | Where-Object { $_.name -eq 'RMS' }

if (-not $entities) { Write-Error "No ENTITIES bundle found"; exit 1 }

$qifs = $entities.configurations
if ($Entity) { $qifs = $qifs | Where-Object { $_.label -like "*$Entity*" -or $_.name -like "*$Entity*" } }

function Get-FieldProps($node) {
    $p = $node.props
    $parts = @()
    $type = $node.type.resolvedName
    $short = switch -Wildcard ($type) {
        'SelectInput'       { 'Dropdown' }
        'FormSelect'        { 'Dropdown' }
        'TextInput'         { 'Text' }
        'FormDateInput'     { 'Date' }
        'CheckboxInput'     { 'Check' }
        'HiddenInput'       { 'Hidden' }
        'SelectHistoryInput' { 'Dropdown+History' }
        'FormInput'         { 'Text' }
        default             { $type }
    }
    $parts += $short
    if ($p.maxLength)          { $parts += "maxLen=$($p.maxLength)" }
    if ($p.attributeTypeId)    { $parts += "attributeTypeId=$($p.attributeTypeId)" }
    if ($p.codeTypeCategory)   { $parts += "codeTypeCategory=$($p.codeTypeCategory)" }
    if ($p.codeTypeSource)     { $parts += "codeTypeSource=$($p.codeTypeSource)" }
    if ($p.codeTypeProvider)   { $parts += "codeTypeProvider=$($p.codeTypeProvider)" }
    if ($p.initialValue)       { $parts += "default=$($p.initialValue)" }
    if ($p.hidden -eq $true)   { $parts += "HIDDEN" }
    if ($p.autoSelect -eq $true) { $parts += "autoSelect" }
    return $parts -join ' | '
}

function Walk-Node($layout, $nodeId, $depth) {
    $node = $layout.$nodeId
    if (-not $node) { return }
    $indent = '  ' * $depth
    $type = $node.type.resolvedName

    switch ($type) {
        'Card' {
            $label = if ($node.props.label) { $node.props.label } else { $nodeId }
            Write-Output "${indent}CARD `"$label`""
        }
        { $_ -in 'Row','CadRow','FrRow' } {
            $cols = if ($node.props.templateColumns) { " [$($node.props.templateColumns -join ' ')]" } else { '' }
            Write-Output "${indent}ROW ${nodeId}${cols}"
        }
        { $_ -in 'RootPage','FormRoot','Container' } { }
        default {
            $fieldId = if ($node.props.fieldId) { $node.props.fieldId } else { $nodeId }
            $info = Get-FieldProps $node
            Write-Output "${indent}${fieldId} ($info)"
        }
    }

    $children = $node.nodes
    if ($children) {
        foreach ($child in $children) {
            Walk-Node $layout $child ($depth + 1)
        }
    }
}

function Render-Layout($layout, $variantName) {
    Write-Output "  [$variantName]"
    $members = ($layout | Get-Member -MemberType NoteProperty).Name
    $root = $members | Where-Object { $_ -eq 'ROOT' }
    if (-not $root) { $root = $members[0] }

    $rootNode = $layout.$root
    $formRoot = if ($rootNode.nodes) { $rootNode.nodes[0] } else { $null }
    if ($formRoot -and $layout.$formRoot) {
        $pageNode = $layout.$formRoot
        if ($pageNode.nodes) {
            $rootPage = $pageNode.nodes[0]
            if ($rootPage -and $layout.$rootPage -and $layout.$rootPage.nodes) {
                foreach ($cardId in $layout.$rootPage.nodes) {
                    Walk-Node $layout $cardId 2
                }
                return
            }
        }
    }
    # fallback: walk from ROOT
    Walk-Node $layout $root 2
}

function Render-Qidm($provBundle, $qidmName) {
    if (-not $provBundle) { return }
    $qidm = $provBundle.configurations | Where-Object { $_.name -eq $qidmName }
    if (-not $qidm) { return }
    Write-Output "  QIDM: $qidmName"
    $attrs = $qidm.attributes
    if ($attrs) {
        foreach ($a in $attrs) {
            $parts = @("src=$($a.sourceField)", "tgt=$($a.targetField)")
            if ($a.useAttributeId -eq $true) { $parts += "useAttrId" }
            if ($a.codeTypeProvider) { $parts += "codeProv=$($a.codeTypeProvider)" }
            if ($a.rule -and $a.rule.function) {
                $rhDetail = $a.rule.function
                if ($a.rule.arguments) { $rhDetail += "($($a.rule.arguments -join ', '))" }
                $parts += "rule=$rhDetail"
            }
            if ($a.fallbackRule -and $a.fallbackRule.function) {
                $fbDetail = $a.fallbackRule.function
                if ($a.fallbackRule.arguments) { $fbDetail += "($($a.fallbackRule.arguments -join ', '))" }
                $parts += "fallback=$fbDetail"
            }
            Write-Output "    $($a.sourceField) -> $($a.targetField) ($($parts[2..99] -join ' | '))"
        }
    }
    $combos = $qidm.combinations
    if ($combos) {
        Write-Output "  COMBINATIONS:"
        foreach ($c in $combos) {
            $kr = if ($c.keyReference) { " [$($c.keyReference)]" } else { '' }
            $setStr = if ($c.requirements.set) { "set=[$($c.requirements.set -join ',')]" } else { '' }
            $anyStr = if ($c.requirements.any) { "any=[$($c.requirements.any -join ',')]" } else { '' }
            Write-Output "    ${kr} ${setStr} ${anyStr}"
        }
    }
}

# Summary mode
if ($Summary) {
    Write-Output "=== $(Split-Path $Path -Leaf) ==="
    Write-Output "QIFs: $($qifs.Count)"
    foreach ($qif in $qifs) {
        $entity = $qif.targetEntity
        $qidm = $qif.queryInputDataMapping
        $cards = 0
        $fields = 0
        $layout = $qif.layout.default
        if ($layout) {
            $members = ($layout | Get-Member -MemberType NoteProperty).Name
            foreach ($m in $members) {
                $n = $layout.$m
                if ($n.type.resolvedName -eq 'Card') { $cards++ }
                if ($n.type.resolvedName -match 'Input$') { $fields++ }
            }
        }
        Write-Output "  $($qif.label) | entity=$entity | qidm=$qidm | cards=$cards fields=$fields"
    }
    if ($providerBundle) {
        $qidms = $providerBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' }
        Write-Output "QIDMs: $($qidms.Count)"
        foreach ($q in $qidms) {
            $ac = if ($q.attributes) { $q.attributes.Count } else { 0 }
            $cc = if ($q.combinations) { $q.combinations.Count } else { 0 }
            Write-Output "  $($q.name) | attrs=$ac combos=$cc autoSelect=$($q.autoSelect)"
        }
    }
    exit 0
}

foreach ($qif in $qifs) {
    Write-Output ""
    Write-Output "=== $($qif.label) ==="
    Write-Output "  name=$($qif.name) | entity=$($qif.targetEntity) | qidm=$($qif.queryInputDataMapping)"

    if (-not $QidmOnly) {
        $variants = if ($Variant -eq 'all') { @('default','compact','detail') } else { @($Variant) }
        foreach ($v in $variants) {
            $lay = $qif.layout.$v
            if ($lay) { Render-Layout $lay $v }
        }
    }

    if ($qif.queryInputDataMapping -and $providerBundle) {
        Render-Qidm $providerBundle $qif.queryInputDataMapping
    }
}

if ($rmsBundle -and -not $QidmOnly) {
    $rmsQidms = $rmsBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' }
    if ($rmsQidms) {
        Write-Output ""
        Write-Output "=== RMS QIDMs ==="
        foreach ($rq in $rmsQidms) {
            Write-Output "  $($rq.name)"
            if ($rq.attributes) {
                foreach ($a in $rq.attributes) {
                    $parts = @()
                    if ($a.useAttributeId -eq $true) { $parts += "useAttrId" }
                    if ($a.rule -and $a.rule.function) {
                        $rhDetail = $a.rule.function
                        if ($a.rule.arguments) { $rhDetail += "($($a.rule.arguments -join ', '))" }
                        $parts += "rule=$rhDetail"
                    }
                    if ($a.fallbackRule -and $a.fallbackRule.function) {
                        $fbDetail = $a.fallbackRule.function
                        if ($a.fallbackRule.arguments) { $fbDetail += "($($a.fallbackRule.arguments -join ', '))" }
                        $parts += "fallback=$fbDetail"
                    }
                    $extra = if ($parts) { " ($($parts -join ' | '))" } else { '' }
                    Write-Output "    $($a.sourceField) -> $($a.targetField)${extra}"
                }
            }
        }
    }
}
