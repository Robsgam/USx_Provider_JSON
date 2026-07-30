<#
  audit_suppression_scope.ps1 -- how WIDE is each accepted divergence, versus how wide it was
  GRANTED? Read-only. Changes no verdict, cannot turn a provider red.

  WHY THIS EXISTS (measured 2026-07-30, not theorised)
    An ACCEPTED_DIVERGENCES row records one adjudicated decision about one field on one combo.
    But audit_metadata's Test-AllowListed keyed suppression on (query, keyRef, field) and DISCARDED
    the Rule column -- so a row saying "regionId may ride in RQ{VIN} any[]" also silenced the
    OPPOSITE defect, "regionId was wrongly PROMOTED INTO set[]". Nobody noticed for months because
    a suppression leaves no trace: the check simply stops speaking.
    It became visible only through mutation testing -- audit_gate_efficacy flipped
    `promote-any-to-set` from KILLED to SURVIVED the moment 4 legitimate promoted-to-any rows were
    added to TX_TLETS. A gate silently stopped being a gate because we recorded a decision.
    That is the accepted-divergence tax: every entry buys a blind spot, and its WIDTH is set by how
    precisely the suppression is keyed, not by what the entry actually claims.

  THE KEY OBSERVATION THAT MAKES THIS FIXABLE
    The rule vocabulary ALREADY encodes direction -- promoted-to-set vs promoted-to-any vs
    demoted-to-any vs not-built. Whoever wrote each row named it correctly. The enforcement just
    threw the name away. So this is a lookup table, not a redesign.

  WHAT THIS TOOL DOES
    For every registry row in every provider: classify its rule, then report which registry-reading
    checks it LEGITIMATELY licenses versus which it ALSO silences today. An "OVER-BROAD" line is a
    check that is currently mute for that (query,keyRef,field) even though the recorded decision
    says nothing about that check's defect class.

  WHAT THIS TOOL DOES NOT DO
    It does not prove a real defect is hiding in any blind spot -- only that the gate cannot see
    there. It does not narrow anything. Narrowing can turn a green provider red (a real finding
    stops being silenced), which is a release-timing decision and Rob's call, one provider at a time.

  HONESTY NOTE ON $checks: the call-site inventory below is HAND-MAINTAINED from grep evidence, not
  derived. That is a real limitation -- add a registry-reading check without adding it here and this
  tool will under-report, which is the same closed-loop disease it exists to measure. Re-derive with:
      Select-String tools\*.ps1 -Pattern 'ACCEPTED_DIVERGENCES|Test-AllowListed'

  Usage: .\audit_suppression_scope.ps1 [-Provider <NAME>] [-Detail] [-OutFile <path>]
#>

param([string]$Provider, [switch]$Detail, [string]$OutFile)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; Write-Host $s -ForegroundColor $c }

# ── rule -> direction class ───────────────────────────────────────────────────────────
# 'to-set'     the decision is about placing a field INTO set[]
# 'to-any'     the decision is about placing/leaving a field in any[]
# 'existence'  the decision is that a COMBINATION is not built / not reachable
# 'other'      adjudications that license no field-placement or existence check on their own
function Get-RuleClass([string]$rule) {
    $r = $rule.ToLower()
    if ($r -eq 'promoted-to-set')                                { return 'to-set' }
    if ($r -in @('promoted-to-any','demoted-to-any','added-to-any')) { return 'to-any' }
    if ($r -match 'not-built|unbuilt|shadow|dead-combo|dropped-combo|missing-primary-combo') { return 'existence' }
    return 'other'
}

# ── registry-reading checks, and the rule class each may LEGITIMATELY be licensed by ──
# RuleAware = does the call site already consult the Rule column? Only CHECK 4d does (2026-07-30),
# plus audit_requirement_fidelity, which was written rule-aware after this class was found.
$checks = @(
    @{ Id='audit_metadata CHECK 4d  (field promoted INTO set[])';        Accepts='to-set';     RuleAware=$true  }
    @{ Id='audit_metadata CHECK 4e  (field demoted to any[])';           Accepts='to-any';     RuleAware=$false }
    @{ Id='audit_metadata CHECK 4   (combination field coverage)';       Accepts='existence';  RuleAware=$false }
    @{ Id='audit_metadata CHECK 5   (primary-field combo present)';      Accepts='existence';  RuleAware=$false }
    @{ Id='audit_requirement_fidelity  OVER-PERMITTED';                  Accepts='to-any';     RuleAware=$true  }
    @{ Id='audit_requirement_fidelity  UNDER-REQUIRED / skip-unbuilt';   Accepts='existence';  RuleAware=$true  }
    @{ Id='audit_combo_reachability    (dead combo)';                    Accepts='existence';  RuleAware=$true  }
    @{ Id='audit_log_combo_attribution (log names a dead combo)';        Accepts='existence';  RuleAware=$true  }
    @{ Id='audit_devdoc_combinations   (devdoc path unbuilt)';           Accepts='existence';  RuleAware=$true  }
)

Out-Line ''
Out-Line ('=' * 84)
Out-Line '  SUPPRESSION SCOPE -- is each accepted divergence as narrow as it was granted?'
Out-Line ("  " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '   READ-ONLY: changes no verdict')
Out-Line ('=' * 84)

$provDirs = Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name
if ($Provider) { $provDirs = @($provDirs | Where-Object { $_.Name -eq $Provider }) }

$totRows = 0; $totOver = 0; $byRule = @{}; $perProv = @()
foreach ($d in $provDirs) {
    $f = @(Get-ChildItem (Join-Path $d.FullName 'docs') -Recurse -Filter '*ACCEPTED_DIVERGENCES*' -File -ErrorAction SilentlyContinue) | Select-Object -First 1
    if (-not $f) { continue }
    $rows = @()
    foreach ($ln in (Get-Content $f.FullName)) {
        $s = $ln.Trim(); if (-not $s -or $s.StartsWith('#')) { continue }
        $p = $s -split '\|'; if ($p.Count -lt 4) { continue }
        $rows += [pscustomobject]@{ Query=$p[0].Trim(); KeyRef=$p[1].Trim(); Field=$p[2].Trim(); Rule=$p[3].Trim() }
    }
    if (-not $rows.Count) { continue }

    $pOver = 0; $rowDetail = @()
    foreach ($r in $rows) {
        $cls = Get-RuleClass $r.Rule
        if (-not $byRule.ContainsKey($r.Rule)) { $byRule[$r.Rule] = 0 }
        $byRule[$r.Rule]++
        $over = @()
        foreach ($c in $checks) {
            if ($c.RuleAware) { continue }        # already consults the Rule column -> correctly scoped
            if ($c.Accepts -eq $cls) { continue } # this row genuinely licenses that check
            $over += $c.Id
        }
        if ($over.Count) {
            $pOver += $over.Count
            $rowDetail += [pscustomobject]@{ Row="$($r.Query)/$($r.KeyRef)/$($r.Field)"; Rule=$r.Rule; Class=$cls; Over=$over }
        }
    }
    $totRows += $rows.Count; $totOver += $pOver
    $perProv += [pscustomobject]@{ Name=$d.Name; Rows=$rows.Count; Over=$pOver; Detail=$rowDetail }
}

Out-Line ''
Out-Line ('  {0,-26} {1,5} {2,10}' -f 'PROVIDER','ROWS','OVER-BROAD')
Out-Line ('  ' + ('-' * 46))
foreach ($p in ($perProv | Sort-Object -Property @{e={$_.Over};Descending=$true}, Name)) {
    $col = if ($p.Over -gt 0) { 'Yellow' } else { 'Green' }
    Out-Line ('  {0,-26} {1,5} {2,10}' -f $p.Name, $p.Rows, $p.Over) $col
}

Out-Line ''
Out-Line '  RULE CLASSES PRESENT (the vocabulary already encodes direction -- enforcement did not):'
foreach ($k in ($byRule.Keys | Sort-Object { -$byRule[$_] })) {
    Out-Line ('    {0,-38} {1,4}   class={2}' -f $k, $byRule[$k], (Get-RuleClass $k))
}

Out-Line ''
Out-Line '  DIRECTION-BLIND CALL SITES (each silences EVERY rule class for a matched triple):'
foreach ($c in $checks) { if (-not $c.RuleAware) { Out-Line ("    [BLIND]  " + $c.Id) 'Yellow' } }
foreach ($c in $checks) { if ($c.RuleAware)      { Out-Line ("    [scoped] " + $c.Id) 'Green'  } }

if ($Detail) {
    foreach ($p in ($perProv | Where-Object { $_.Over -gt 0 } | Sort-Object Name)) {
        Out-Line ''
        Out-Line "  === $($p.Name) ===" 'Cyan'
        foreach ($x in $p.Detail) {
            Out-Line ("    $($x.Row)")
            Out-Line ("      rule=$($x.Rule) (class=$($x.Class)) also silences:") 'Yellow'
            foreach ($o in $x.Over) { Out-Line "        - $o" 'DarkGray' }
        }
    }
}

Out-Line ''
Out-Line ('-' * 84)
Out-Line "  TOTAL: $totRows registry row(s) / $totOver over-broad suppression(s) across $($perProv.Count) provider(s)"
Out-Line '  OVER-BROAD = that check is currently mute for that (query,keyRef,field) even though the'
Out-Line '  recorded decision says nothing about its defect class. It does NOT mean a defect is'
Out-Line '  hiding there -- only that the gate cannot see there if one appears.'
Out-Line '  FIX = pass -IgnoreRule at each [BLIND] call site (audit_metadata CHECK 4d is the pattern).'
Out-Line '  Narrowing can turn a green provider red, because a real finding stops being silenced.'
Out-Line '  That is a release-timing call: one provider at a time, never a portfolio sweep.'
Out-Line ('-' * 84)

if ($OutFile) { $lines | Out-File -FilePath $OutFile -Encoding utf8; Write-Host "  -> $OutFile" -ForegroundColor DarkGray }
exit 0
