<#
  identify_notours_provider.ps1 -- WHICH USx PROVIDER DOES EACH NOT-OUR-BUILD CONFIG ACTUALLY ALIGN
  WITH, MEASURED FROM ITS CONTENT -- and which tenants are identical, so one fix covers them all.

  Rob, 2026-09-12: "i want you to beter idetify the usx provider it mostly aligns with adn say which
  ones are identical in the saem family ergo same usx provder support and any one off with
  associated state."

  ⚠️ THE BUNDLE NAME IS A CLAIM, NOT EVIDENCE. `gordo` carries a bundle called `HI_HCJDC` and there
  is no such provider directory -- ours is `HI_HCJDC_OFML`. `1836` calls itself `FL_FCIC` while
  holding no ENTITIES and no RMS at all. A name tells you what somebody typed; it does not tell you
  which of our twenty providers would have to support the thing.

  SO IDENTITY COMES FROM THE ROUTING KEY. Every bundle carries a `provider` FIELD, and that is what
  the platform DISPATCHES ON to reach a state system. `provider=LA_LEMS` means this configuration
  talks to Louisiana, whoever authored it and whatever the bundle is called. That is a FACT about
  the config, not a resemblance score. It is resolved to the provider WE would have to support --
  exact directory, then unique prefix (`HI_HCJDC` -> our `HI_HCJDC_OFML`, the same Hawaii system
  under our fuller name), then nothing.

  ⚠️ THE FIRST VERSION OF THIS TOOL SCORED SIMILARITY AND WAS NONSENSE. It compared keyReferences
  and query types by Jaccard and confidently reported 23 tenants -- all carrying bundles named
  LA_LEMS -- as aligning with NJ_NJCJIS. Louisiana matched to New Jersey while our own LA_LEMS build
  sat right there. Cause: these configs use DESCRIPTIVE keyReferences
  (`BirthDateNamePurposeCodeSexCodeRegistrationStateAttention`) where ours are short codes (`DQ`,
  `IA.QV`), so overlap was ZERO against all twenty builds and the score was carried entirely by
  generic query names every provider shares -- after which Jaccard simply crowned whichever build
  had the SMALLEST signature. **A similarity measure over a dimension where nothing can match does
  not return "no match"; it returns noise shaped like an answer.** Query coverage is still reported
  here, but only as coverage against our build for the SAME system -- never as the thing that
  decides which provider it is.

  ⚠️ NO ROUTING KEY WE RECOGNISE = NO MATCH, NOT THE NEAREST ONE. `RecordsArchive` is the case that
  matters: not a CJIS provider at all, and assigning it to the closest one would invent a support
  obligation that does not exist.

  WHAT THE OUTPUT IS FOR. Grouped BY USx PROVIDER, because that is the unit of support: everything
  under one heading is answered by one person who knows that provider. Within a heading, tenants
  whose provider bundle is byte-identical (canonically) are marked as one FAMILY -- one config, N
  tenants, so a defect is N defects and a fix is one fix. One-offs are listed with the STATE the
  matched provider serves, since that is who would have to be involved.

  Usage:
    tools\identify_notours_provider.ps1
    tools\identify_notours_provider.ps1 -OutFile providers\NOTOURS_IDENTITY.txt
#>
param(
    [string]$TenantDir,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_json_canonical.ps1"
. "$PSScriptRoot\_bundle_identity.ps1"

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

# The state each provider serves. Derived from the provider directory prefix; spelled out because
# "who do we have to involve" is the actual question behind a one-off.
$states = @{
    'AZ' = 'Arizona'; 'CA' = 'California'; 'FL' = 'Florida'; 'HI' = 'Hawaii'; 'IL' = 'Illinois'
    'LA' = 'Louisiana'; 'MD' = 'Maryland'; 'NJ' = 'New Jersey'; 'NM' = 'New Mexico'; 'NY' = 'New York'
    'OH' = 'Ohio'; 'OR' = 'Oregon'; 'TN' = 'Tennessee'; 'TX' = 'Texas'
}
function Get-StateOf([string]$provider) {
    $pfx = ($provider -split '_')[0]
    if ($states.ContainsKey($pfx)) { return $states[$pfx] }
    return $null
}

# ⚠️ THE INSTRUMENT CHANGED AFTER THE FIRST RUN PRODUCED A NONSENSE ANSWER, AND THE NONSENSE IS
# WORTH RECORDING. The first cut scored keyReference + query-type overlap by Jaccard and confidently
# reported 23 tenants -- every one of them carrying a bundle named LA_LEMS -- as aligning with
# NJ_NJCJIS, i.e. Louisiana configs matched to New Jersey while our own LA_LEMS build sat right
# there. 23 findings of identical implausible shape is the tell that the probe is the defect.
#
# CAUSE, measured rather than guessed: these configs use DESCRIPTIVE keyReferences --
# `BirthDateNamePurposeCodeSexCodeRegistrationStateAttention` -- while ours are short codes (`DQ`,
# `IA.QV`, `ZWAR.N`). Overlap was therefore ZERO against all twenty builds, so the score was carried
# entirely by generic query names that every provider shares, and Jaccard then simply crowned the
# provider with the SMALLEST signature. A similarity measure over a dimension where nothing can
# match does not return "no match" -- it returns noise shaped like an answer.
#
# THE RIGHT INSTRUMENT WAS SITTING IN THE DATA: each bundle carries a `provider` FIELD, and that is
# the platform's ROUTING KEY -- what it dispatches on to reach a state system. `provider=LA_LEMS`
# means this config talks to Louisiana, whoever wrote it. That is a fact about the config, not a
# resemblance score. Query coverage is still reported, but as COVERAGE against our build for the
# same system, never as the thing that decides which provider it is.
function Get-QueryTypes($bundle) {
    $q = New-Object System.Collections.Generic.HashSet[string]
    foreach ($c in @($bundle.configurations)) {
        $n = '{0}' -f $c.name
        if ($n -match '([A-Za-z]+Query)$') { [void]$q.Add($Matches[1]) }
    }
    return $q
}

# Resolve the routing key to the provider WE would have to support: exact directory, then unique
# prefix (HI_HCJDC -> HI_HCJDC_OFML, the same Hawaii system under our fuller name), then nothing.
# Refuses to guess between multiple candidates, the Get-ProviderMetadataXml rule.
function Resolve-OurProvider([string]$routingKey, $dirNames) {
    if (-not $routingKey) { return $null }
    $exact = @($dirNames | Where-Object { $_ -eq $routingKey })
    if ($exact.Count -eq 1) { return $exact[0] }
    $pfx = @($dirNames | Where-Object { $_ -like ($routingKey + '_*') })
    if ($pfx.Count -eq 1) { return $pfx[0] }
    return $null
}

Say '===================================================================================='
Say '  NOT-OUR-BUILD CONFIGS -- which USx provider each one aligns with, BY CONTENT'
Say '===================================================================================='

$tenantDir = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
if (-not (Test-Path $tenantDir)) { Say ('  [FAIL] no tenant exports at {0}' -f $tenantDir); exit 1 }

# ---- our builds: query coverage per provider ------------------------------------------------------
$repoQ = @{}; $repoVer = @{}
foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory)) {
    $cands = @(Get-ChildItem $d.FullName -Filter ('{0}_v*.json' -f $d.Name) -File -ErrorAction SilentlyContinue)
    if ($cands.Count -ne 1) { continue }
    $o = $null
    try { $o = Get-Content $cands[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ($cands[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer[$d.Name] = $Matches[1] }
    $pb = @(Get-BundleList $o | Where-Object { ('{0}' -f $_.name) -ne 'ENTITIES' -and ('{0}' -f $_.name) -ne 'RMS' })[0]
    if ($pb) { $repoQ[$d.Name] = Get-QueryTypes $pb }
}
if ($repoQ.Count -eq 0) { Say '  [FAIL] no repo builds indexed -- refusing to compare against nothing.'; exit 1 }
$dirNames = @($repoQ.Keys)
Say ('  reference: {0} repo provider build(s). Identity comes from the bundle ROUTING KEY;' -f $repoQ.Count)
Say '             query coverage is reported against our build for the same system.'

# ---- theirs --------------------------------------------------------------------------------------
$files = @(Get-ChildItem $tenantDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch 'provenance' })
$rows = @(); $skipped = 0
foreach ($f in $files) {
    $dept = ($f.BaseName -replace '^.*_(\d+)$', '$1')
    if ($dept -notmatch '^\d+$') { $skipped++; continue }
    $sub = ($f.BaseName -replace '_\d+$', '')
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $skipped++; continue }
    $bl = Get-BundleList $o
    $pb = @($bl | Where-Object { ('{0}' -f $_.name) -ne 'ENTITIES' -and ('{0}' -f $_.name) -ne 'RMS' })[0]
    if (-not $pb) { $skipped++; continue }
    if (Get-BundleLabelVersion $pb) { continue }       # stamped = ours

    # ⚠️ ROUTING IDENTITY COMES FROM THE CONFIGURATIONS, NOT THE BUNDLE HEADER -- and `fullwooddemo`
    # is why. Its BUNDLE is named CA_eSUN with `provider = NJ_NJCJIS`, while ALL NINE configurations
    # inside declare `provider = CA_eSUN`. Reading the bundle header alone filed a California config
    # under New Jersey. Each configuration carries its own provider and that is what the QIDM
    # declares, so the majority across configurations is the identity; a bundle header that
    # disagrees with its own contents is reported as the inconsistency it is rather than silently
    # resolved either way.
    $cfgProv = @(@($pb.configurations) | ForEach-Object { '{0}' -f $_.provider } | Where-Object { $_ })
    $routing = if ($cfgProv.Count -gt 0) {
        ($cfgProv | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
    } else { '{0}' -f $pb.provider }
    $hdrProv = '{0}' -f $pb.provider
    $hdrDisagrees = ($hdrProv -and $hdrProv -ne $routing)
    $ours    = Resolve-OurProvider $routing $dirNames
    $theirQ  = Get-QueryTypes $pb
    $covShared = 0; $covMissing = @(); $covExtra = @()
    if ($ours -and $repoQ.ContainsKey($ours)) {
        foreach ($q in $theirQ) { if ($repoQ[$ours].Contains($q)) { $covShared++ } else { $covExtra += $q } }
        foreach ($q in $repoQ[$ours]) { if (-not $theirQ.Contains($q)) { $covMissing += $q } }
    }
    $rows += [pscustomobject]@{
        Sub = $sub; Dept = $dept; Claimed = ('{0}' -f $pb.name); Routing = $routing
        HdrProv = $hdrProv; HdrDisagrees = $hdrDisagrees
        Match = $ours
        TheirQ = $theirQ.Count; CovShared = $covShared
        CovMissing = ($covMissing -join ', '); CovExtra = ($covExtra -join ', ')
        ProvHash = (Get-BundleContentHash $pb)
        Bundles = (@($bl | ForEach-Object { '{0}' -f $_.name }) -join '+')
    }
}

if ($rows.Count -eq 0) { Say '  [FAIL] no not-our-build configs found -- refusing to report an empty analysis.'; exit 1 }
Say ('  subjects : {0} not-our-build tenant(s){1}' -f $rows.Count, $(if ($skipped) { "  ($skipped skipped)" } else { '' }))
Say ''

# ---- grouped BY USx PROVIDER, because that is the unit of support ---------------------------------
$byProvider = @($rows | Where-Object { $_.Match } | Group-Object Match | Sort-Object { $_.Group.Count } -Descending)
$noMatch    = @($rows | Where-Object { -not $_.Match })

foreach ($g in $byProvider) {
    $prov = $g.Name
    $state = Get-StateOf $prov
    Say '===================================================================================='
    Say ('  ALIGNS WITH: {0}{1}   -- {2} tenant(s)' -f $prov, $(if ($state) { "   [$state]" } else { '' }), $g.Count)
    Say ('  our current build: v{0}' -f $repoVer[$prov])
    Say '===================================================================================='

    # Within the provider, identical provider bundles are ONE config on N tenants.
    $fams = @($g.Group | Group-Object ProvHash | Sort-Object Count -Descending)
    $famNo = 0
    foreach ($fam in $fams) {
        $famNo++
        $r0 = $fam.Group[0]
        if ($fam.Count -gt 1) {
            Say ('  FAMILY {0} -- ONE configuration on {1} tenants (provider bundle byte-identical)' -f $famNo, $fam.Count)
            Say ('    content {0}   routing key "{1}"   {2} queries built, {3} shared with our build' -f
                 $fam.Name.Substring(0,12), $r0.Routing, $r0.TheirQ, $r0.CovShared)
            Say '    ONE FIX COVERS ALL OF THESE; one defect is present on all of them:'
            foreach ($m in ($fam.Group | Sort-Object Sub)) { Say ('       {0,-34} dept {1}' -f $m.Sub, $m.Dept) }
        } else {
            $st = Get-StateOf $prov
            Say ('  ONE-OFF -- {0} (dept {1})' -f $r0.Sub, $r0.Dept)
            Say ('    exists on NO other tenant we have looked at. State: {0}' -f $(if ($st) { $st } else { 'n/a' }))
            Say ('    content {0}   routing key "{1}"   {2} queries built, {3} shared with our build' -f
                 $fam.Name.Substring(0,12), $r0.Routing, $r0.TheirQ, $r0.CovShared)
            if ($r0.Claimed -ne $prov) {
                Say ('    !! the bundle is NAMED "{0}" while its configurations route to {1}. A name is a claim.' -f $r0.Claimed, $r0.Routing)
            }
            if ($r0.HdrDisagrees) {
                Say ('    !! INTERNALLY INCONSISTENT: the bundle HEADER says provider="{0}" while every' -f $r0.HdrProv)
                Say ('       configuration inside declares "{0}". Reported, not silently resolved.' -f $r0.Routing)
            }
            if ($r0.Bundles -notmatch 'ENTITIES') {
                Say '    !! NO ENTITIES BUNDLE -- the forms cannot render. This is a fragment, not a working config.'
            }
        }
        Say ''
    }
}

if ($noMatch.Count -gt 0) {
    Say '===================================================================================='
    Say ('  NO RECOGNISED ROUTING KEY -- {0} tenant(s)' -f $noMatch.Count)
    Say '===================================================================================='
    Say '  Reported as unmatched rather than assigned to the least-bad provider. Naming one would'
    Say '  invent a support obligation that does not exist.'
    Say ''
    foreach ($r in ($noMatch | Sort-Object Sub)) {
        Say ('  {0,-34} routing key "{1}"  bundle "{2}"  [{3}]' -f $r.Sub, $r.Routing, $r.Claimed, $r.Bundles)
    }
    Say ''
}

Say '===================================================================================='
Say '  HOW THE MATCH IS MADE, AND WHAT IT IS NOT'
Say '===================================================================================='
Say '  Identity is the bundle ROUTING KEY -- the `provider` field the platform dispatches on to'
Say '  reach a state system -- resolved to the provider we would have to support (exact name, then'
Say '  unique prefix). It is a fact about the configuration, not a similarity score.'
Say ''
Say '  "IDENTICAL" means the provider bundle is byte-identical after canonicalisation (description'
Say '  excluded, platform nulls normalised), so one fix covers the whole family and one defect is'
Say '  present on every member.'
Say ''
Say '  IT DOES NOT SAY the config is ours (none carry our version stamp), who wrote it, or that it'
Say '  works. Query coverage is shown to indicate how complete each one is RELATIVE to our build'
Say '  for the same system -- it is not evidence of authorship or of correctness.'
Say '===================================================================================='

if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII; Write-Host ('  written: {0}' -f $OutFile) -ForegroundColor Cyan }
exit 0
