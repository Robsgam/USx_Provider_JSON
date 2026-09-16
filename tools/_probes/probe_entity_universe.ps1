# ===========================================================================
#  probe_entity_universe.ps1 -- IS A SIXTH ENTITY POSSIBLE? ASK THE PLATFORM'S
#  OWN DEPLOYED CONFIGURATIONS, NOT OUR OWN BUILDS.
#
#  WHY. On 2026-09-16 SC_SLED's `AdministrativeMessage` QUERYINPUTFORM did not
#  render, and I recorded LIMITATION #46 off ONE observation plus the fact that
#  all 21 of OUR providers use exactly Person/Vehicle/Firearm/Article/Boat.
#  Rob pushed back: "there has to be a way to have more than 5 ... i want it
#  compeltely seperated".
#
#  He is right that our own builds are the WEAKEST possible evidence: they are
#  21 copies of ONE convention that one person established. Surveying them and
#  concluding "five is the limit" is the shape ENGINEERING_STANDARD 4.5 warns
#  about -- "18 of 20 providers do X" describes practice, never spec.
#
#  THE BETTER AUTHORITY IS ALREADY ON DISK: _versions\tenant_exports holds ~66
#  configurations pulled from live tenants, and some were NOT BUILT BY US --
#  Lafayette's LA_LEMS is hand-built by Mark43 engineering, plus sdso, gordo and
#  ~24 demo copies. A foreign config carrying a sixth entity would prove the
#  mechanism exists AND show its exact shape. A survey finding none across every
#  deployed config is much stronger than our own 21.
#
#  IT ALSO ANSWERS THE OTHER HALF: if a sixth entity does exist somewhere, what
#  ELSE does that config carry for it -- a QRDM? a results layout? an entry in a
#  different order array? That is the "what am I missing" question, and it cannot
#  be answered by reading our own builds because ours never had one that worked.
#
#  READ-ONLY. Reports; changes nothing.
# ===========================================================================
[CmdletBinding()]
param([string]$TenantDir, [switch]$Quiet)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $TenantDir) { $TenantDir = Join-Path $repo '_versions\tenant_exports' }

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }

Say ''
Say '===================================================================================='
Say '  ENTITY UNIVERSE -- every QUERYINPUTFORM targetEntity in every DEPLOYED config'
Say '===================================================================================='

if (-not (Test-Path $TenantDir)) { Say "  [FAIL] no tenant exports at $TenantDir"; exit 1 }
$files = @(Get-ChildItem $TenantDir -Filter '*.json' -File -EA SilentlyContinue |
           Where-Object { $_.Name -notmatch 'provenance' })
if ($files.Count -eq 0) { Say '  [FAIL] 0 tenant configs on disk -- that is not an answer, it is an empty probe.'; exit 1 }
Say ("  configs examined: {0}" -f $files.Count)

$KNOWN5 = @('Person','Vehicle','Firearm','Article','Boat')
$ents = @{}          # entity -> list of "tenant/provider"
$extraDetail = @()

foreach ($f in $files) {
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    $bundles = @()
    if ($o.bundles) { $bundles = @($o.bundles) }
    elseif ($o.departmentBundle.bundles) { $bundles = @($o.departmentBundle.bundles) }
    foreach ($b in $bundles) {
        foreach ($c in @($b.configurations)) {
            if ("$($c.type)" -ne 'QUERYINPUTFORM') { continue }
            $te = "$($c.targetEntity)"
            if (-not $te) { $te = '(blank)' }
            if (-not $ents.ContainsKey($te)) { $ents[$te] = @() }
            $ents[$te] += ('{0}|{1}' -f $f.BaseName, "$($b.name)")
            if ($KNOWN5 -notcontains $te) {
                # THE INTERESTING CASE. Capture everything that config carries FOR that entity,
                # because the question is not only "does it exist" but "what makes it work".
                $siblingTypes = @(@($b.configurations) | Where-Object { "$($_.targetEntity)" -eq $te } |
                                  ForEach-Object { "$($_.type)" } | Select-Object -Unique)
                $orderNames = @()
                foreach ($c2 in @($b.configurations)) {
                    if ($c2.order) { foreach ($pr in $c2.order.PSObject.Properties) { $orderNames += @($pr.Value) } }
                }
                if ($b.order) { foreach ($pr in $b.order.PSObject.Properties) { $orderNames += @($pr.Value) } }
                $extraDetail += [pscustomobject]@{
                    Tenant = $f.BaseName; Bundle = "$($b.name)"; Entity = $te
                    FormName = "$($c.name)"; Label = "$($c.label)"
                    TypesForEntity = ($siblingTypes -join ',')
                    InOrderArray = ($orderNames -contains $te)
                }
            }
        }
    }
}

Say ''
Say ('  {0,-28} {1,7}  {2}' -f 'targetEntity', 'forms', 'status')
foreach ($k in ($ents.Keys | Sort-Object { -(@($ents[$_]).Count) })) {
    $mark = if ($KNOWN5 -contains $k) { 'one of the known five' } else { '<<< NOT one of the five' }
    Say ('  {0,-28} {1,7}  {2}' -f $k, @($ents[$k]).Count, $mark)
}

Say ''
Say '  ---- VERDICT ----'
$extras = @($ents.Keys | Where-Object { $KNOWN5 -notcontains $_ })
if ($extras.Count -eq 0) {
    Say ('  NO config among {0} deployed tenants carries a QUERYINPUTFORM outside the five.' -f $files.Count)
    Say '  That is the strongest evidence available on disk -- it includes configurations we did'
    Say '  NOT build (Lafayette hand-built by engineering, sdso, gordo, demo copies). It still is'
    Say '  NOT a platform spec: absence across deployed configs cannot prove the platform refuses'
    Say '  one. It proves nobody has shipped one, which is a different claim.'
} else {
    Say ('  *** {0} entity value(s) OUTSIDE the five FOUND. The mechanism exists -- here is its shape:' -f $extras.Count)
    foreach ($d in $extraDetail) {
        Say ('    {0}' -f $d.Tenant)
        Say ('      entity={0}  form={1}  label={2}' -f $d.Entity, $d.FormName, $d.Label)
        Say ('      config types carrying that entity: [{0}]' -f $d.TypesForEntity)
        Say ('      present in an order array: {0}' -f $d.InOrderArray)
    }
    Say '  COMPARE those config types against what SC_SLED shipped -- a QUERYINPUTFORM alone may'
    Say '  not be enough if a working example also carries a QRDM or a results layout for it.'
}
exit 0
