<#
  audit_prefill_shadow.ps1 -- WHICH PREFILL KILLED THE COMBO. (BUILD_RULES 24, at the CAUSE.)

  BUILD_RULES 24 has said since the 35-combos-across-6-providers incident: "NEVER prefill a routing
  field. A form initialValue on any set[] field makes it always-present and permanently hides every
  combo needing its absence." Nothing enforced it.

  audit_combo_reachability owns the CONSEQUENCE -- it reports "DEAD COMBO" once a combo is already
  unreachable. It does not say WHY, and a dead-combo verdict reads like a design trade-off you can
  accept. On AZ_AZDPS v3.7 that is exactly how it was read: prefilling ImageIndicator, Requestor and
  dexStateUserId (three set[] fields, in one version) collapsed
      DQPN  variable set -> [NameLast, NameFirst]        == DQN's
      DQP   variable set -> [OperatorLicenseNumber]      == DQ's
      ACQB  variable set -> [RegistrationNumber]         == BQ's
      ACQBH variable set -> [BoatHullIdNumber]           == BQH's
  four EXACT collisions that no ordering can separate, killing DQN/DQ/BQ/BQH -- and the proposed
  responses were to delete or register the losers. Rob: "we do not leave out queries because it is
  hard ... use ordering and recognize the shadows." The fix was to UN-prefill the discriminators
  (ImageIndicator for the DL pairs, RegistrationState for the Boat pairs), which metadata already
  distinguished. This gate names that cause at BUILD time, before a tenant test is ever spent.

  THE RULE, and why it is not "no prefill on a set[] field":
    A prefill is a defect only when it CREATES a shadow. For an ordered pair (A before B) in the same
    QIDM, A shadows B when A's VARIABLE set (set[] minus always-present fields) is a subset of B's --
    A matches whenever B does, so first-match hands A everything. That is a PREFILL-CAUSED shadow only
    if the subset relation does NOT already hold on the raw set[]s. If it holds either way, the shadow
    is structural and belongs to audit_combo_reachability, not here.
    This is what spares the legitimate cases: CA_CLETS prefills purposeCode, which sits in EVERY combo's
    set[], so it cancels out of both sides and creates no new relation. AZ's dexStateUserId prefill is
    likewise required -- without it the badge combos cannot match at all -- and it is fine because
    ImageIndicator/RegistrationState remain un-prefilled to discriminate.

  Conditions are honoured: a pair gated on mutually exclusive existence (one EXISTS, the other
  NOT_EXISTS on the same field) can never co-fire, so it is not a shadow.

  Usage: .\audit_prefill_shadow.ps1 -Path <provider.json> [-OutFile <report>]
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path $Path).Path
$json = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$provider = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '_v[\d.]+$','' -replace '(?i)_(BASE|MC)$',''

$lines = [System.Collections.Generic.List[string]]::new()
$fail = 0; $pass = 0; $compared = 0
function Emit($s) { $lines.Add($s); Write-Host $s }

Emit "================================================================"
Emit "  PREFILL-SHADOW AUDIT -- $provider"
Emit "  Which form initialValue makes a combo unreachable (BUILD_RULES 24)"
Emit "================================================================"
Emit ''

# ---- always-present fields = every form control carrying a non-empty initialValue -----------------
$prefilled = @{}
foreach ($b in $json.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTFORM') { continue }
        foreach ($lv in $c.layout.PSObject.Properties) {
            foreach ($n in $lv.Value.PSObject.Properties) {
                $p = $n.Value.props
                if ($p -and $p.fieldId -and $null -ne $p.initialValue -and "$($p.initialValue)" -ne '') {
                    $prefilled["$($p.fieldId)"] = "$($p.initialValue)"
                }
            }
        }
    }
}
Emit ("  prefilled control(s): {0}" -f $(if ($prefilled.Count) { (($prefilled.Keys | Sort-Object | ForEach-Object { "$_=$($prefilled[$_])" }) -join '  ') } else { '(none)' }))
Emit ''

function Get-Variable-Set($combo) {
    return @(@($combo.requirements.set) | Where-Object { $_ -and -not $prefilled.ContainsKey("$_") })
}
function Test-IsSubset($a, $b) {   # is every element of $a in $b?
    foreach ($x in @($a)) { if (@($b) -notcontains $x) { return $false } }
    return $true
}
# mutually exclusive existence gates on the same field => the pair can never co-fire
function Test-MutuallyExclusive($ca, $cb) {
    foreach ($x in @($ca.requirements.conditions)) {
        foreach ($y in @($cb.requirements.conditions)) {
            foreach ($fx in @($x.field)) {
                foreach ($fy in @($y.field)) {
                    if ("$fx" -ieq "$fy" -and "$($x.operator)" -ne "$($y.operator)" -and
                        "$($x.operator)" -match 'EXISTS' -and "$($y.operator)" -match 'EXISTS') { return $true }
                }
            }
        }
    }
    return $false
}

foreach ($b in $json.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        if ("$($c.provider)" -eq 'RMS') { continue }
        $combos = @($c.combinations)
        for ($i = 0; $i -lt $combos.Count; $i++) {
            for ($k = $i + 1; $k -lt $combos.Count; $k++) {
                $A = $combos[$i]; $B = $combos[$k]      # A is ordered BEFORE B
                $compared++
                if (Test-MutuallyExclusive $A $B) { continue }

                $rawA = @($A.requirements.set); $rawB = @($B.requirements.set)
                $varA = Get-Variable-Set $A;     $varB = Get-Variable-Set $B

                # A shadows B only if A matches whenever B does -> A's requirement is a subset of B's
                $shadowsNow    = (Test-IsSubset $varA $varB)
                $shadowedRaw   = (Test-IsSubset $rawA $rawB)
                if (-not $shadowsNow -or $shadowedRaw) { continue }   # no shadow, or structural (not ours)

                $culprits = @($rawA | Where-Object { $prefilled.ContainsKey("$_") -and (@($rawB) -notcontains $_) })
                if (-not $culprits.Count) { $culprits = @($rawA | Where-Object { $prefilled.ContainsKey("$_") }) }
                $fail++
                Emit ("  [FAIL] {0}: '{1}' SHADOWS '{2}' only because of prefill(s): {3}" -f `
                      $c.query, $A.keyReference, $B.keyReference, ($culprits -join ', '))
                Emit ("         {0} needs [{1}] of which [{2}] is always present -> variable [{3}]" -f `
                      $A.keyReference, ($rawA -join ','), (($culprits) -join ','), ($varA -join ','))
                Emit ("         {0} needs [{1}] -> variable [{2}]  ==> '{2}' can never win first-match" -f `
                      $B.keyReference, ($rawB -join ','), ($varB -join ','))
                Emit  '         FIX: un-prefill the discriminator (metadata usually supplies one), or reorder.'
                Emit  '              Do NOT delete or register the shadowed combo -- BUILD_RULES 24.'
            }
        }
    }
}

Emit ''
if ($compared -eq 0) {
    Emit "  [FAIL] compared ZERO combination pairs -- this gate did not run, which is NOT a pass"
    $fail++
} elseif ($fail -eq 0) {
    Emit ("  [PASS] no prefill-caused shadow ({0} ordered pair(s) compared)" -f $compared)
    $pass++
}
Emit ("  RESULTS: {0} PASS / {1} FAIL   ({2} pair(s) compared)" -f $pass, $fail, $compared)

if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
}
if ($fail -gt 0) { exit 1 } else { exit 0 }
