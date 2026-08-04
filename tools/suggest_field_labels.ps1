# suggest_field_labels.ps1 -- derive required/optional label hints from QIDM combos
# =====================================================================
# Consistency tool: instead of hand-deriving each field's "(required)/(optional)"
# label hint, compute it from the authoritative combo structure (QIDM set[]/any[]).
# This makes the required/optional dimension of labels CONSISTENT across providers.
#
# Rule (the convention):
#   - a fieldId in the set[] of EVERY combo of its query  -> (required)
#   - a fieldId in the set[] of SOME combos               -> (required for <keyRefs>)   [conditional]
#   - a fieldId in any[] only (never in a set[])          -> (optional)
#   - a fieldId not referenced by any combo               -> (display / not in a combo)
#
# LIMIT: this derives the STRUCTURAL hint only. It cannot infer SEMANTIC wording --
# value meanings (e.g. RandomRequest N=full/Y=random), out-of-state guidance, or
# cross-field "or use X" hints. Those fields are flagged [NEEDS HUMAN HINT].
#
# Usage:
#   pwsh -NoProfile -File tools/suggest_field_labels.ps1 -Path <provider.json> [-OutFile <txt>]
# =====================================================================
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile
)

if (-not (Test-Path $Path)) { Write-Error "JSON not found: $Path"; exit 1 }
$json = Get-Content $Path -Raw | ConvertFrom-Json

# --- 1. Collect combo membership per fieldId (across all QIDMs) ---
$role = @{}   # fieldId -> ordered@{ setKeys=[]; anyKeys=[]; queries=[] }
$comboTotal = @{}   # query -> total combo count
function Ensure($fid) {
    if (-not $role.ContainsKey($fid)) {
        $role[$fid] = [ordered]@{ setKeys = New-Object System.Collections.Generic.List[string];
                                  anyKeys = New-Object System.Collections.Generic.List[string];
                                  queries = New-Object System.Collections.Generic.List[string] }
    }
}
foreach ($b in $json.bundles) {
    if ($b.provider -eq 'RMS' -or $b.provider -eq 'MARK43') { continue }   # officer-facing CommSys QIDMs only
    foreach ($cfg in $b.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        $q = [string]$cfg.query
        $combos = @($cfg.combinations)
        $comboTotal[$q] = $combos.Count
        foreach ($combo in $combos) {
            $kr  = [string]$combo.keyReference
            $req = $combo.requirements
            foreach ($f in @($req.set))  { if ($f) { Ensure $f; $role[$f].setKeys.Add($kr); if (-not $role[$f].queries.Contains($q)) { $role[$f].queries.Add($q) } } }
            foreach ($f in @($req.any))  { if ($f) { Ensure $f; $role[$f].anyKeys.Add($kr); if (-not $role[$f].queries.Contains($q)) { $role[$f].queries.Add($q) } } }
        }
    }
}

# --- 2. Collect current label + entity/card per fieldId from the QIF layouts (default variant) ---
$labelOf = @{}; $cardOf = @{}; $entityOf = @{}
foreach ($b in $json.bundles) {
    foreach ($cfg in $b.configurations) {
        if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
        $entity = [string]$cfg.targetEntity
        $layout = $cfg.layout.default
        if (-not $layout) { continue }
        # node map: nodeId -> node. First pass: fieldId nodes + their parent; collect card titles.
        $cardTitle = @{}
        foreach ($p in $layout.PSObject.Properties) {
            $n = $p.Value
            if ($n.type.resolvedName -eq 'Card' -and $n.props.title) { $cardTitle[$p.Name] = [string]$n.props.title }
        }
        # map row -> card (row parent is the card)
        $rowCard = @{}
        foreach ($p in $layout.PSObject.Properties) {
            $n = $p.Value
            if ($n.type.resolvedName -eq 'Row' -and $n.parent) { $rowCard[$p.Name] = [string]$n.parent }
        }
        foreach ($p in $layout.PSObject.Properties) {
            $n = $p.Value
            $fid = $n.props.fieldId
            if (-not $fid) { continue }
            $fid = [string]$fid
            if ($labelOf.ContainsKey($fid)) { continue }   # first (default variant) wins
            $labelOf[$fid]  = [string]$n.props.label
            $entityOf[$fid] = $entity
            $card = $rowCard[[string]$n.parent]
            if ($card -and $cardTitle.ContainsKey($card)) { $cardOf[$fid] = $cardTitle[$card] } else { $cardOf[$fid] = '' }
        }
    }
}

# --- 3. Derive role + suggested hint; flag semantic-hint candidates ---
# Heuristic flags for fields whose hint needs human semantic wording:
$semanticFlag = @('randomRequest','RandomRequest','registrationState','RegistrationState','State')
$out = New-Object System.Collections.Generic.List[string]
$out.Add("FIELD LABEL SUGGESTIONS -- $([System.IO.Path]::GetFileName($Path))")
$out.Add("Derived from QIDM combo set[]/any[]. Structural hint only; [HUMAN] = needs semantic wording.")
$out.Add(("{0,-30} {1,-34} {2}" -f 'fieldId (entity)','current label','suggested role -> hint"'))
$out.Add(('-' * 110))

$allFids = @($labelOf.Keys + $role.Keys | Sort-Object -Unique)
foreach ($fid in $allFids) {
    $ent = if ($entityOf.ContainsKey($fid)) { $entityOf[$fid] } else { '?' }
    $lbl = if ($labelOf.ContainsKey($fid)) { $labelOf[$fid] } else { '(not in layout)' }
    $suggest = ''
    if ($role.ContainsKey($fid)) {
        $r = $role[$fid]
        $setK = @($r.setKeys); $anyK = @($r.anyKeys)
        if ($setK.Count -eq 0) {
            $suggest = '(optional)'
        } else {
            # required in all combos of every query it sets in?
            $allReq = $true
            foreach ($q in $r.queries) {
                $setInQ = @($setK | Sort-Object -Unique).Count   # approx; keyRefs unique
                if ($comboTotal[$q] -and ($setInQ -lt $comboTotal[$q])) { $allReq = $false }
            }
            if ($allReq) { $suggest = '(required)' }
            else { $suggest = "(required for $((@($setK | Sort-Object -Unique)) -join '/'))" }
        }
    } else {
        $suggest = '(display / not in a combo)'
    }
    $flag = ''
    if ($semanticFlag -contains $fid) { $flag = '   [HUMAN: value meaning / OOS]' }
    $out.Add(("{0,-30} {1,-34} {2}{3}" -f "$fid ($ent)", $lbl, $suggest, $flag))
}

$text = ($out -join "`r`n")
Write-Host $text
# PS 5.1: -Encoding utf8NoBOM is PowerShell 7 only (see render_officer_guide.ps1 for the full note);
# under 5.1 it is a hard parameter-binding failure, and -Encoding utf8 would write a BOM instead.
if ($OutFile) {
    [System.IO.File]::WriteAllText($OutFile, ($text -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "`n-> $OutFile"
}
