# CA_eSUN v1.1 -- RND-71815 radio buttons, FIRST RESPONDER CONTEXT ONLY.
#
# Rob 2026-09-03: "we need to downshift and redo v1.1 and v2.2 so that the radio buttons only
# display for First responder context. do 1.1 no version bump and then i can evalutate".
#
# WHY THIS REBUILDS FROM v1.0 RATHER THAN EDITING v1.1: the previous v1.1 converted PurposeCode in
# ALL THREE layout variants (5 entities x 3 = 15 controls) and also widened those rows to 12 columns
# and added initialValue='C'. Un-picking that would leave the untouched variants "probably" back to
# where they started. Deriving from v1.0 again makes default and CAD_DISPATCH EXACTLY v1.0 by
# construction, and the assertion at the bottom proves it rather than assuming it.
#
# NO VERSION BUMP -- still v1.1, per the instruction. This is a correction of what v1.1 should have
# been, not a new version, and v1.1 has no live install to invalidate (SDSO runs v1.0).
#
# v1.0 STATE, READ NOT ASSUMED: all 15 PurposeCode controls are FormSelect with NO initialValue and
# no direction; the containing row is templateColumns [3] on Vehicle and [6] on the other four.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$src  = Join-Path $repo 'providers\CA_eSUN\docs\deliverables\CA_eSUN_v1.0_PRE_RADIOBUTTON_ORIGINAL_LIVE.json'
$dst  = Join-Path $repo 'providers\CA_eSUN\docs\deliverables\CA_eSUN_v1.1_RADIOBUTTON_FIRST_RESPONDER_ONLY.json'
if (-not (Test-Path $src)) { throw "ABORT: v1.0 baseline not found at $src" }

$TARGET_VARIANT = 'FIRST_RESPONDER'
$j = Get-Content $src -Raw | ConvertFrom-Json

# ---- census BEFORE ---------------------------------------------------------------------------
$before = 0
foreach ($b in $j.bundles) { foreach ($c in $b.configurations) {
  if ("$($c.type)" -ne 'QUERYINPUTFORM') { continue }
  foreach ($vp in $c.layout.PSObject.Properties) {
    foreach ($np in $vp.Value.PSObject.Properties) {
      if ($np.Value.props -and "$($np.Value.props.fieldId)" -eq 'PurposeCode') { $before++ }
    } } } }
Write-Output ("BEFORE: {0} PurposeCode control(s) across all variants (expect 15)" -f $before)
if ($before -eq 0) { throw "ABORT: no PurposeCode controls found -- the transform would be a silent no-op" }

# ---- convert ONLY the FIRST_RESPONDER variant --------------------------------------------------
$converted = 0; $widened = 0
foreach ($b in $j.bundles) {
  foreach ($c in $b.configurations) {
    if ("$($c.type)" -ne 'QUERYINPUTFORM') { continue }
    foreach ($vp in $c.layout.PSObject.Properties) {
      if ($vp.Name -ne $TARGET_VARIANT) { continue }          # <-- the whole point
      $variant = $vp.Value
      foreach ($np in $variant.PSObject.Properties) {
        $n = $np.Value
        if (-not $n.props -or "$($n.props.fieldId)" -ne 'PurposeCode') { continue }
        if ("$($n.type.resolvedName)" -ne 'FormSelect') { continue }
        $n.type.resolvedName = 'FormRadioGroup'
        if ($n.PSObject.Properties['displayName']) { $n.displayName = 'Radio Group' }
        # direction=row: the RND-71815 screenshots show the options laid out ACROSS, and the
        # ticket's snippet said 'column'. The images are what SDSO asked for.
        if ($null -eq $n.props.PSObject.Properties['direction']) {
          Add-Member -InputObject $n.props -MemberType NoteProperty -Name direction -Value 'row'
        } else { $n.props.direction = 'row' }
          # -- NO initialValue. REVERSED 2026-09-04 by Rob: "we need to remove the default for
          # purpose code". This previously set 'C' on his earlier call ("and we need a default of
          # c please"); that instruction is superseded and the control now ships UNSET, which also
          # matches v1.0 -- all 15 PurposeCode controls there carry no initialValue.
          #
          # IT WAS NEVER A ROUTING RISK EITHER WAY. PurposeCode sits in the set[] of ALL 25
          # combinations, so a prefill cancels out of every comparison and cannot shadow one combo
          # over another (the reasoning CLAUDE.md records for CA_CLETS's purposeCode='C'). This is
          # a decision about whether the officer STATES a purpose, not a correctness fix.
          #
          # IT ALSO UNBLOCKS THE DRIVER, WHICH IS THE OTHER HALF OF THE ASK. usx_lib's radio helper
          # SHORT-CIRCUITS when the wanted option is ALREADY SELECTED, and every plan test fills
          # PurposeCode='C' -- so with initialValue='C' the driver took that short-circuit on every
          # test and NEVER exercised the selection path. The radio interaction was untested BY
          # CONSTRUCTION, which is why it kept appearing to work and then failing. With no prefill
          # the driver must genuinely select, which is what the isChecked fix has to survive.
          if ($n.props.PSObject.Properties['initialValue']) {
            $n.props.PSObject.Properties.Remove('initialValue')
          }
        $converted++
        # Two long labels cannot lay out horizontally in a 3- or 6-column row -- they stack at the
        # left, which is exactly what Rob saw first time. Widen ONLY the row holding this control,
        # and ONLY if that row holds nothing else, so no sibling control is displaced.
        $parentId = "$($n.parent)"
        $prow = $variant.PSObject.Properties | Where-Object { $_.Name -eq $parentId }
        if ($prow) {
          $kids = @($variant.PSObject.Properties | Where-Object { "$($_.Value.parent)" -eq $parentId })
          if ($kids.Count -eq 1 -and $prow.Value.props) {
            $prow.Value.props.templateColumns = @('12')
            $widened++
          }
        }
      }
    }
  }
}
Write-Output ("converted to FormRadioGroup in {0} only: {1}" -f $TARGET_VARIANT, $converted)
Write-Output ("rows widened to 12 columns (single-child rows only): {0}" -f $widened)
if ($converted -ne 5) { throw "ABORT: expected 5 conversions (one per entity), got $converted" }

# ---- version stays v1.1 -------------------------------------------------------------------------
foreach ($b in $j.bundles) {
  if ("$($b.provider)" -eq 'CA_eSUN') {
    $b.description = "Provider configuration for CA_eSUN v1.1 -- HAND BUILT BY ENGINEERING (San Diego Sheriff live capture, v1.0 baseline) PLUS RND-71815: PurposeCode rendered as a radio group in the FIRST_RESPONDER layout variant ONLY; the default and CAD_DISPATCH variants keep the v1.0 dropdown unchanged. SDSO-ONLY change. Verbatim v1.0 baseline: source/CA_eSUN_v1.0_PRE_RADIOBUTTON_SDSO_BASELINE_2026-09-02.json; recovery tag CA_eSUN-v1.0-baseline"
  }
}

[IO.File]::WriteAllText($dst, ($j | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
Write-Output ("wrote: {0}" -f (Split-Path $dst -Leaf))

# ---- verify FROM DISK ---------------------------------------------------------------------------
$v = Get-Content $dst -Raw | ConvertFrom-Json
$byVariant = @{}
foreach ($b in $v.bundles) { foreach ($c in $b.configurations) {
  if ("$($c.type)" -ne 'QUERYINPUTFORM') { continue }
  foreach ($vp in $c.layout.PSObject.Properties) {
    foreach ($np in $vp.Value.PSObject.Properties) { $n = $np.Value
      if ($n.props -and "$($n.props.fieldId)" -eq 'PurposeCode') {
        $k = "$($vp.Name)|$($n.type.resolvedName)"
        if (-not $byVariant.ContainsKey($k)) { $byVariant[$k] = 0 }
        $byVariant[$k]++
      } } } } }
Write-Output ""
Write-Output "PurposeCode control types by variant (read back from disk):"
foreach ($k in ($byVariant.Keys | Sort-Object)) { "   {0,-34} {1}" -f $k, $byVariant[$k] }

# THE PROMISE: default and CAD_DISPATCH must be EXACTLY v1.0. Asserted, not assumed -- compare the
# serialized variant subtree, which catches a stray prop, a widened row or a changed label as
# readily as a changed control type.
function Get-VariantSig($o, $variantName) {
    $parts = @()
    foreach ($b in $o.bundles) { foreach ($c in $b.configurations) {
        if ("$($c.type)" -ne 'QUERYINPUTFORM') { continue }
        $vp = $c.layout.PSObject.Properties | Where-Object { $_.Name -eq $variantName }
        if ($vp) { $parts += "$($c.targetEntity)=" + ($vp.Value | ConvertTo-Json -Depth 60 -Compress) }
    } }
    return (($parts | Sort-Object) -join '')
}
$base = Get-Content $src -Raw | ConvertFrom-Json
foreach ($untouched in @('default', 'CAD_DISPATCH')) {
    $same = ((Get-VariantSig $base $untouched) -eq (Get-VariantSig $v $untouched))
    Write-Output ("{0,-16} identical to v1.0: {1}" -f $untouched, $same)
    if (-not $same) { throw "ABORT: $untouched variant changed -- only $TARGET_VARIANT may differ" }
}

# ---- hand it over where the operator actually looks ---------------------------------------------
try {
    $dl = Join-Path $env:USERPROFILE 'Downloads'
    if (Test-Path $dl) {
        $t = Join-Path $dl (Split-Path $dst -Leaf)
        Copy-Item $dst $t -Force
        Write-Output ("READY TO IMPORT -> {0}" -f $t)
    }
} catch { Write-Output ("   (could not copy to Downloads -- not fatal: " + $_.Exception.Message + ")") }
