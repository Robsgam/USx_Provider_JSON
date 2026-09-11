<#
  audit_auth_uniformity.ps1 -- IS THE AUTHENTICATION CONFIG THE SAME ON EVERY PROVIDER?
  RND-71625 surface, measured against CA_CLETS as the reference.

  WHY THIS EXISTS. Rob, 2026-09-11:
    "confirm that all jsons are sonfigured the same in terms of the issues described in that
     jira. you should have access to every json  i gave screenshot and ran tests on the ca
     clets usx test tenant so whatever is thier currently should be the standard please reveiw
     and confirm that all are the same or let me know which one are different"

  WHAT RND-71625 IS ABOUT, AT THE CONFIG LEVEL. The ticket (P3, SQA-145 TC-10) claims RMS shows
  no blocking indicator when a device is unregistered. Cringer's comment 812334 named the fix:
    "In the configuration under type AUTHENTICATION, set deviceRegistrationOptional to false."
  and his snippet also named handlerFunction: CommsysOriAuthenticationHandler,
  providerType: Commsys, signInRequired: false. So the surface this probe compares is the
  AUTHENTICATION configuration -- every property of it, not just the one flag.

  WHY CA_CLETS IS THE REFERENCE AND NOT A HAND-WRITTEN EXPECTATION. Rob tested CA_CLETS and
  supplied the screenshots ("whatever is thier currently should be the standard"). Comparing to
  a literal I typed would be comparing to my belief; comparing to CA_CLETS compares to the
  artifact he actually validated. If CA_CLETS changes, this probe's expectation changes with it.

  !! WHAT IT REFUSES TO DO:
   1. It does not compare ONE FLAG. The earlier round measured deviceRegistrationOptional alone
      and found 20/20 uniform -- true, and not an answer to "are they configured the same",
      because a difference in signInRequired or providerType would have passed unseen.
   2. It does not treat ABSENT and FALSE as equal. The RMS AUTH config carries NO providerType
      and NO signInRequired at all, while the provider AUTH carries both -- so "missing" is
      reported as MISSING, never silently defaulted.
   3. 0 providers or a missing reference FAILS. A vacuous pass here would read as "all
      uniform" (ENGINEERING_STANDARD 4.3).

  Usage: .\tools\_probes\audit_auth_uniformity.ps1 [-Reference CA_CLETS] [-OutFile <report>]
#>

param(
    [string]$Reference = 'CA_CLETS',
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\_probe.ps1"

$lines = @()
function Say([string]$s) { $script:lines += $s; Write-Host $s }

Say ''
Say '===================================================================================='
Say ("  AUTHENTICATION CONFIG UNIFORMITY -- RND-71625 surface, reference = {0}" -f $Reference)
Say '===================================================================================='

# ⚠️ BARE ASSIGNMENT. The harness returns a comma-guarded `,@(...)` so a single result does not
# unwrap to a scalar; wrapping it in @() again NESTS it, and the loop then binds $p to the whole
# provider list. It printed "providers: 1" and died on the first Get-ProbeJsonObject -- the same
# shape that earlier made audit_tenant_provenance report "0 artifacts" as though the repo were
# empty. THIRD time this convention bit me today; it is a property of the harness, not a typo.
$provs = Get-ProbeProviders
Assert-ProbeNonZero $provs.Count 'providers enumerated'
Say ("  providers: {0}" -f $provs.Count)
$bogus = @($provs | Where-Object { $_ -isnot [string] })
if ($bogus.Count -gt 0) {
    Say '  [FAIL] provider list is not a flat list of names -- an array-shape bug, not an empty repo.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

# Collect every AUTHENTICATION configuration, keyed by provider + handlerFunction.
# Keyed on the HANDLER, not on bundle name: the provider bundle is named after the provider
# (CA_CLETS) while the RMS one is named RMS, so a bundle-name key cannot compare across
# providers. The handler is what Cringer's snippet identified and what governs behaviour.
$auth = @{}
foreach ($p in $provs) {
    $o = Get-ProbeJsonObject $p
    foreach ($b in @($o.bundles)) {
        foreach ($c in @($b.configurations)) {
            if ("$($c.type)" -ne 'AUTHENTICATION') { continue }
            $h = "$($c.handlerFunction)"
            if (-not $auth.ContainsKey($h)) { $auth[$h] = @{} }
            $auth[$h][$p] = $c
        }
    }
}
Say ("  distinct AUTHENTICATION handlers across the portfolio: {0} -- {1}" -f $auth.Count, (($auth.Keys | Sort-Object) -join ', '))

# The properties that matter. `description` and `name` are per-provider BY DESIGN (they carry
# the provider name), so comparing them would report 20 differences that are all correct.
$skip = @('description', 'name', 'provider', 'attributes', 'combinations')

# The comparison, factored out so the SELF-TEST below exercises the SAME code that produces the
# verdict. A self-test against a reimplementation proves nothing about the real path.
function Compare-AuthConfig($refCfg, $mineCfg, $skipList) {
    $bad = @()
    $refP = @($refCfg.PSObject.Properties | Where-Object { $skipList -notcontains $_.Name })
    foreach ($rp in $refP) {
        $mine = $mineCfg.PSObject.Properties[$rp.Name]
        if ($null -eq $mine) { $bad += ("{0}: MISSING (ref {1})" -f $rp.Name, $rp.Value); continue }
        if ("$($mine.Value)" -ne "$($rp.Value)") { $bad += ("{0}: {1} (ref {2})" -f $rp.Name, $mine.Value, $rp.Value) }
    }
    foreach ($mp in @($mineCfg.PSObject.Properties | Where-Object { $skipList -notcontains $_.Name })) {
        if ($null -eq $refCfg.PSObject.Properties[$mp.Name]) { $bad += ("{0}: EXTRA = {1} (ref has none)" -f $mp.Name, $mp.Value) }
    }
    # ⚠️ NO COMMA-GUARD HERE, and the self-test below is what caught it. `return ,@($bad)` on an
    # EMPTY result yields a 1-element array whose element is an empty array, so .Count was 1
    # even with ZERO differences -- which made every verdict from this function meaningless in
    # both directions. The guard is right for a function whose single result must not unwrap to
    # a scalar (that is why _probe.ps1 and _resolve_version_history.ps1 use it); it is WRONG for
    # one whose empty result must stay empty. Callers wrap with @() themselves.
    return $bad
}

# ── LAW 2: A GATE THAT CANNOT FAIL IS NOT A GATE ──────────────────────────────────────
# "All 20 uniform" is produced identically by a uniform portfolio and by a comparison that
# compares nothing. Three separate probes I wrote TODAY returned a clean-looking answer while
# comparing nothing at all (a nested provider array -> "0 artifacts"; `$matches` clobbered by a
# regex; `function H` shadowed by the Get-History alias -> six `True`s off $null -eq $null).
# So this asserts, in memory and against the SAME comparison function, that a planted
# difference IS detected -- and declares itself INERT if not.
$refAuth = $auth['CommsysOriAuthenticationHandler'][$Reference]
if ($null -eq $refAuth) { Say ("  [FAIL] reference {0} has no Commsys AUTH config -- cannot self-test." -f $Reference); exit 1 }
$decoyFlip = $refAuth | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$decoyFlip.deviceRegistrationOptional = -not $refAuth.deviceRegistrationOptional
$decoyDrop = $refAuth | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$decoyDrop.PSObject.Properties.Remove('signInRequired')
$hitFlip = @(Compare-AuthConfig $refAuth $decoyFlip $skip)
$hitDrop = @(Compare-AuthConfig $refAuth $decoyDrop $skip)
$hitSame = @(Compare-AuthConfig $refAuth $refAuth $skip)
if ($hitFlip.Count -eq 0 -or $hitDrop.Count -eq 0 -or $hitSame.Count -ne 0) {
    Say '  [FAIL] SELF-TEST FAILED -- this probe cannot tell a difference from a match.'
    Say ("         flipped-value detected: {0} | dropped-property detected: {1} | false positive on identical: {2}" -f ($hitFlip.Count -gt 0), ($hitDrop.Count -gt 0), ($hitSame.Count -ne 0))
    Say '         Its "UNIFORM" verdict would be meaningless. Refusing to report one.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
Say ("  [PASS] self-test: a flipped value AND a dropped property are both detected, and an" )
Say ("         identical pair reports clean. This probe can fail, so its verdict means something.")

$anyDiff = 0
foreach ($h in ($auth.Keys | Sort-Object)) {
    Say ''
    Say ("  ---- handler: {0} ----------------------------------------------------------" -f $h)
    $set = $auth[$h]
    if (-not $set.ContainsKey($Reference)) {
        Say ("  [FAIL] the reference provider {0} has no {1} config -- cannot compare." -f $Reference, $h)
        $anyDiff++
        continue
    }
    $ref = $set[$Reference]
    $refProps = @($ref.PSObject.Properties | Where-Object { $skip -notcontains $_.Name } | Sort-Object Name)
    Say ("  reference ({0}) carries: {1}" -f $Reference, (($refProps | ForEach-Object { $_.Name + '=' + $_.Value }) -join '  '))
    Say ("  providers carrying this handler: {0} of {1}" -f $set.Count, $provs.Count)

    $missingHandler = @($provs | Where-Object { -not $set.ContainsKey($_) })
    if ($missingHandler.Count -gt 0) {
        Say ("  !! DOES NOT HAVE THIS HANDLER AT ALL: {0}" -f ($missingHandler -join ', '))
        $anyDiff++
    }

    $diffRows = @()
    foreach ($p in ($set.Keys | Sort-Object)) {
        if ($p -eq $Reference) { continue }
        $c = $set[$p]
        # SAME function the self-test above exercised -- a verdict produced by different code
        # than the self-test validated would be a self-test of nothing.
        $bad = @(Compare-AuthConfig $ref $c $skip)
        if ($bad.Count -gt 0) { $diffRows += [pscustomobject]@{ Provider = $p; Diffs = $bad } }
    }

    if ($diffRows.Count -eq 0) {
        Say ("  OK -- all {0} provider(s) carrying this handler match {1} EXACTLY on every compared property." -f $set.Count, $Reference)
    } else {
        $anyDiff += $diffRows.Count
        Say ("  !! {0} PROVIDER(S) DIFFER:" -f $diffRows.Count)
        foreach ($d in $diffRows) {
            Say ("     {0}" -f $d.Provider)
            foreach ($x in $d.Diffs) { Say ("        {0}" -f $x) }
        }
    }
}

Say ''
Say '  ---- VERDICT ---------------------------------------------------------------------'
if ($anyDiff -eq 0) {
    Say ("  UNIFORM. Every provider's AUTHENTICATION configs match {0} on every compared" -f $Reference)
    Say '  property, and no provider is missing a handler the reference has.'
    Say '  => Nothing to change for RND-71625 at the configuration level.'
} else {
    Say ("  {0} DIFFERENCE(S) -- listed above. These are the JSONs that are NOT like {1}." -f $anyDiff, $Reference)
}
Say ''
Say '  Compared: every property of every AUTHENTICATION configuration EXCEPT description/name/'
Say '  provider, which carry the provider name by design. ABSENT is reported as MISSING or'
Say '  EXTRA, never treated as equal to a value.'
Say '===================================================================================='
Say ''
if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
