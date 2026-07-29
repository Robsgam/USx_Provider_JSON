<#
  audit_combo_reachability.ps1 -- FILL-INDEPENDENT dead-combo detector

  Finds QIDM combinations that can NEVER fire, no matter what the officer types.

  WHY THIS EXISTS
  ---------------
  The platform fires the FIRST matching combination in a QIDM's array (test_commsys
  prints ">> PLATFORM FIRES: X (first matching combo)"). A combo A is therefore dead
  if some combo B ordered BEFORE it matches every time A does.

  That happens silently when B's extra set[] fields are all form-DEFAULTED: the officer
  never sees them blank, so B's set is always satisfied and B always wins. The combo
  still validates, still appears in coverage counts, and can even carry a PASS test log
  -- because the wire XML contains no keyRef, so a log named for A is indistinguishable
  from one where B fired.

  Found 2026-07-29 in TX_TLETS v4.12: BOTH RQLicensePlateNumber (shadowed by
  REGLicensePlateNumber via FinancialResponsibilityType=E) and RQVehicleIdentificationNumber
  (shadowed by VINVehicleIdentificationNumber, same field) were unreachable, each with a
  PASS log that had actually exercised its shadower. The RQLicensePlateNumber log's wire
  proves it -- it carries FinancialResponsibilityType (REG's set field) AND
  LicensePlateTypeCode (RQ's), i.e. the LIMITATION #1 union pool.

  A dead combo is not merely inert: its any[] still unions into the serialized pool, so
  it can push fields onto the wire that the firing transaction does not define.

  WHAT COUNTS AS "ALWAYS PRESENT"
  -------------------------------
  Form initialValue ONLY. A field with an initialValue is pre-filled in the rendered form,
  so it is present unless the officer deliberately clears it -- that is the condition that
  makes a shadow permanent. Combo defaults[] are deliberately NOT counted: whether the
  platform applies them before or after combo matching is unverified, and a combo's own
  defaults cannot help satisfy its own set[] (it must match first to be selected).

  RMS QIDMs are skipped -- their combos are an intentional specificity cascade with
  identical any[], so shadowing there is by design and harmless.

  Usage: .\audit_combo_reachability.ps1 -Path <provider.json> [-OutFile <path>]
  Exit:  0 = no dead combos, 1 = at least one dead combo
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

$json = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json

$lines = @()
function Emit($text, $color = "Gray") {
    Write-Host $text -ForegroundColor $color
    $script:lines += $text
}

Emit "================================================================"
Emit "  COMBO REACHABILITY AUDIT -- $(Split-Path $Path -Leaf)"
Emit "================================================================"

# -- 0. Accepted divergences: a dead combo that has been reasoned about and registered
#       reports as [NOTE] instead of [FAIL], so a documented shadow does not block the
#       pipeline while a decision is pending (same contract audit_metadata uses).
#       Register with: accept_divergence.ps1 -Rule dead-combo-REVISIT
$accepted = @{}
$provDir = Split-Path (Resolve-Path $Path) -Parent
$regFile = Get-ChildItem $provDir -Recurse -Filter '*ACCEPTED_DIVERGENCES*' -ErrorAction SilentlyContinue |
           Select-Object -First 1
if ($regFile) {
    foreach ($line in (Get-Content $regFile.FullName)) {
        if ($line -match '^\s*#' -or -not $line.Trim()) { continue }
        $p = $line -split '\|'
        if ($p.Count -ge 4 -and $p[3].Trim() -match 'dead-combo') {
            $accepted["$($p[1].Trim())"] = $p[4].Trim()
        }
    }
}

# -- 1. Fields the rendered form pre-fills (per entity) --
$prefilled = @{}
foreach ($bundle in $json.bundles) {
    if ($bundle.provider -ne 'MARK43') { continue }
    foreach ($cfg in $bundle.configurations) {
        $ent = $cfg.targetEntity
        if (-not $ent) { continue }
        if (-not $prefilled.ContainsKey($ent)) { $prefilled[$ent] = @{} }
        foreach ($prop in $cfg.layout.default.PSObject.Properties) {
            $fid = $prop.Value.props.fieldId
            $iv  = $prop.Value.props.initialValue
            if ($fid -and -not [string]::IsNullOrEmpty([string]$iv)) { $prefilled[$ent][$fid] = $iv }
        }
    }
}

# -- 2. Walk CommSys QIDMs in array order --
$dead = 0; $checked = 0; $noted = 0
foreach ($bundle in $json.bundles) {
    if ($bundle.provider -in @('MARK43','RMS')) { continue }
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        if ($cfg.handlerFunction -eq 'RmsRestPayloadHandler') { continue }
        $combos = @($cfg.combinations)
        if ($combos.Count -lt 2) { continue }

        $ent = $cfg.targetEntity
        $pre = if ($ent -and $prefilled.ContainsKey($ent)) { $prefilled[$ent] } else { @{} }
        $qname = $cfg.name

        for ($i = 0; $i -lt $combos.Count; $i++) {
            $A = $combos[$i]
            $checked++
            $aSet  = @($A.requirements.set)
            $aCond = @($A.requirements.conditions | ForEach-Object { "$($_.field)|$($_.operator)" })

            for ($k = 0; $k -lt $i; $k++) {
                $B = $combos[$k]
                $bSet  = @($B.requirements.set)
                $bCond = @($B.requirements.conditions | ForEach-Object { "$($_.field)|$($_.operator)" })

                # B's set must be satisfied whenever A's is: every field B needs that A
                # does not is pre-filled by the form.
                $unmet = @()
                foreach ($f in $bSet) {
                    if ($aSet -notcontains $f -and -not $pre.ContainsKey($f)) { $unmet += $f }
                }
                if ($unmet.Count -gt 0) { continue }

                # B's conditions must also hold whenever A's do. A condition on a
                # form-prefilled field is not a real extra requirement: EXISTS is always
                # true (so ignore it), NOT_EXISTS is always false (so B can never match and
                # is not a shadower at all). Without this, TX_TLETS's VIN combo -- gated
                # 'FinancialResponsibilityType EXISTS' on a field prefilled 'E' -- looked
                # like it imposed a requirement its dead sibling RQ{VIN} did not.
                $extraCond = @()
                foreach ($c in $bCond) {
                    if ($aCond -contains $c) { continue }
                    $cf, $co = $c -split '\|'
                    if ($co -match 'NOT_EXISTS') {
                        # prefilled => unsatisfiable => B is not a shadower
                        if ($pre.ContainsKey($cf)) { $extraCond += $c; continue }
                        $extraCond += $c
                    } elseif ($co -match 'EXISTS') {
                        if ($pre.ContainsKey($cf)) { continue }   # always true
                        $extraCond += $c
                    } else {
                        $extraCond += $c
                    }
                }
                if ($extraCond.Count -gt 0) { continue }

                $via = @($bSet | Where-Object { $aSet -notcontains $_ } |
                         ForEach-Object { "$_=$($pre[$_])" })
                $isAccepted = $accepted.ContainsKey($A.keyReference)
                $tag = if ($isAccepted) { "[NOTE]" } else { "[FAIL]" }
                $col = if ($isAccepted) { "DarkYellow" } else { "Red" }
                Emit ""
                Emit "  $tag DEAD COMBO: $($qname -replace '.*_','')/$($A.keyReference)" $col
                Emit "         never fires -- '$($B.keyReference)' is ordered before it (index $k < $i) and matches whenever it does"
                Emit "         A.set=[$($aSet -join ', ')]"
                Emit "         B.set=[$($bSet -join ', ')]"
                if ($via.Count -gt 0) {
                    Emit "         B's extra set field(s) are form-prefilled, so B's set is always satisfied: $($via -join ', ')" "Yellow"
                } else {
                    Emit "         B.set is a subset of A.set -- B is strictly broader" "Yellow"
                }
                if ($isAccepted) {
                    Emit "         ACCEPTED (dead-combo): $($accepted[$A.keyReference])" "DarkYellow"
                    $noted++
                } else {
                    Emit "         FIX: gate them apart (existence-only), drop A as a shadow, or register an accepted divergence." "Yellow"
                    $dead++
                }
                break
            }
        }
    }
}

Emit ""
Emit "================================================================"
$noteSfx = if ($noted -gt 0) { " ($noted accepted dead-combo divergence(s))" } else { "" }
if ($dead -eq 0) {
    Emit "  [PASS] $checked combination(s) checked -- all reachable$noteSfx" "Green"
} else {
    Emit "  [FAIL] $dead dead combination(s) of $checked checked$noteSfx" "Red"
}
Emit "================================================================"

if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Saved: $OutFile" -ForegroundColor Gray
}

if ($dead -gt 0) { exit 1 } else { exit 0 }
