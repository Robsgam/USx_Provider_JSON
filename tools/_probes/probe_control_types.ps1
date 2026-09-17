<#
  probe_control_types.ps1 -- WHICH FORM CONTROL TYPES DOES THE PORTFOLIO ACTUALLY BUILD?

  WHY IT EXISTS. Rob 2026-09-17, on the Administrative Message tab: "can we make the text line
  multirow like a box for text". A 501-character free-text message in a single-line FormInput is a
  bad control and he is right to ask. But whether the platform HAS a multi-line control is a
  CAPABILITY question, and inventing a resolvedName that the Craft.js renderer does not know would
  silently render nothing -- the same failure class as the retired whole-tree recase, which
  collapsed `nodes` and left only tab names showing. So: census what is built and proven, first.
#>
. "$PSScriptRoot\..\_probe.ps1"

$provs = Get-ProbeProviders
$types = @{}
$props = @{}
foreach ($p in $provs) {
    $j = Get-Content (Get-ProbeJsonPath -Provider $p) -Raw | ConvertFrom-Json
    foreach ($b in $j.bundles) {
        foreach ($c in @($b.configurations)) {
            if ($c.type -ne 'QUERYINPUTFORM') { continue }
            foreach ($lv in $c.layout.PSObject.Properties) {
                foreach ($n in $lv.Value.PSObject.Properties) {
                    $r = "$($n.Value.type.resolvedName)"
                    if (-not $r) { continue }
                    if ($types.ContainsKey($r)) { $types[$r]++ } else { $types[$r] = 1 }
                    foreach ($pp in $n.Value.props.PSObject.Properties) {
                        $k = "$r.$($pp.Name)"
                        if ($props.ContainsKey($k)) { $props[$k]++ } else { $props[$k] = 1 }
                    }
                }
            }
        }
    }
}
[void](Assert-ProbeNonZero $types.Count 'control types found')
Write-Host "CONTROL TYPES BUILT ACROSS $($provs.Count) PROVIDERS (all 3 layout variants):"
$types.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object {
    Write-Host ("  {0,-20} {1} node(s)" -f $_.Key, $_.Value)
}
Write-Host ''
Write-Host 'EVERY PROP NAME EVER SET ON A CONTROL (this is the whole vocabulary we have proven):'
$props.GetEnumerator() | Sort-Object -Property Name | ForEach-Object {
    Write-Host ("  {0,-46} {1}" -f $_.Key, $_.Value)
}

# ---------------------------------------------------------------------------------------------
# THE SECOND, INDEPENDENT AUTHORITY: configs we did NOT build.
# Our own 21 JSONs can only show what WE have used -- absence there is not evidence the platform
# lacks a control. `_versions\tenant_exports\` holds every tenant config pulled off the platform,
# including NOT-OUR-BUILD ones authored by other engineers. If a component type appears there and
# nowhere in ours, the platform renders it and we simply never used it.
# ---------------------------------------------------------------------------------------------
$tdir = Join-Path $script:ProbeRepo '_versions\tenant_exports'
if (-not (Test-Path $tdir)) { Write-Host ''; Write-Host 'NO tenant_exports on disk -- second authority UNAVAILABLE, not empty.'; return }
$files = @(Get-ChildItem $tdir -Filter '*.json' -File | Where-Object { $_.Name -notmatch 'provenance' })
[void](Assert-ProbeNonZero $files.Count 'tenant export configs on disk')
$ttypes = @{}
foreach ($f in $files) {
    $o = $null
    try { $o = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
    foreach ($b in @($o.bundles)) {
        foreach ($c in @($b.configurations)) {
            if ($c.type -ne 'QUERYINPUTFORM') { continue }
            foreach ($lv in $c.layout.PSObject.Properties) {
                foreach ($n in $lv.Value.PSObject.Properties) {
                    $r = "$($n.Value.type.resolvedName)"
                    if ($r) { if ($ttypes.ContainsKey($r)) { $ttypes[$r]++ } else { $ttypes[$r] = 1 } }
                }
            }
        }
    }
}
Write-Host ''
Write-Host "CONTROL TYPES IN $($files.Count) TENANT CONFIG(S) ON THE PLATFORM (ours AND not-ours):"
$ttypes.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object {
    $flag = if ($types.ContainsKey($_.Key)) { '' } else { '   <== NOT IN ANY OF OUR BUILDS' }
    Write-Host ("  {0,-20} {1} node(s){2}" -f $_.Key, $_.Value, $flag)
}
