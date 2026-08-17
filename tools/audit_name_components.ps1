<#
================================================================================
 audit_name_components.ps1 -- METADATA COMPONENT -> FORM CONTROL COVERAGE
================================================================================

 THE DIRECTION NOTHING ELSE CHECKS, AT COMPONENT GRANULARITY.

 audit_devdoc_combinations closes the "authority -> built" gap for COMBINATIONS.
 Nobody ever built the FIELD-COMPONENT twin, so this whole class was invisible:
 every other gate enumerates the JSON and is therefore closed under what we
 built. A metadata-defined name COMPONENT with no form control generates no
 control to audit, no attribute to orphan, and -- because the test plan is
 derived FROM the JSON -- no test that could fail. It cannot be found by looking
 harder at what exists.

 WHAT IT COST (2026-08-17): 15 of 20 providers ship NO middle-name and NO suffix
 control while their own metadata declares request Name with four components
 (First, Last, Middle, Suffix) on the queries we actually built. Every one of
 those providers was 0 FAIL / 0 WARN across the whole gate panel, and four of
 them (NJ_NJCJIS, FL_FCIC, IL_LEADS_OFML, CA_CLETS) were tenant-verified
 ALL-PASS. Worse: 6 of the missing controls on FL_FCIC and OR_LEDS were DELETED
 on 2026-08-02 after audit_wiring_closure correctly reported them as unwired --
 the gate answered "is it wired?" and the answer was read as "should it exist?".
 That is the exact inversion this tool exists to prevent: wiring_closure walks
 JSON -> JSON, so it can tell you a control is useless but never that one is
 MISSING. Only the metadata can say that.

 PROVEN CAPABILITY, NOT A THEORY. AZ_AZDPS v3.11, 2026-08-17, 10 captured wires:
 FormatStringRuleHandler emits all four components and degrades cleanly --
   <Name>DOE, JOHN A JR</Name>   (middle + suffix)
   <Name>DOE, JOHN JR</Name>     (suffix only -- no double space, no stray comma)
 So a missing control is lost officer capability, not a platform limit.

--------------------------------------------------------------------------------
 SCOPE IS DERIVED, NOT HARDCODED -- and this is the part to not "simplify".
--------------------------------------------------------------------------------

 First+Last+Middle+Suffix is a GENERIC TYPE SIGNATURE in the metadata, not a
 per-field statement of capability. Across the portfolio it is stamped on 100+
 fields that are plainly not person names -- ChemicalName, SchoolName,
 AddressStreetName, BoatName, PropertyBrandName, RegistrationJurisdictionName,
 even EnhancedNameSearchIndicator -- and one field carries a nonsense signature
 (SupervisorName :: Day+Month+Year). A gate demanding four controls per
 composite would demand a middle name for a chemical.

 Nor is component-count ever control-count in general: Day+Month+Year composites
 (BirthDate and 200+ siblings) map to exactly ONE FormDate control, parsed by
 CommsysParseDateRuleHandler.

 THE FILTER THAT MAKES IT CLEAN: only consider composite fields REFERENCED BY A
 BUILT TRANSACTION'S COMBINATIONS. Measured 2026-08-17 across 125 built
 transactions on all 20 providers, that leaves EXACTLY ONE field -- 'Name' -- and
 zero noise. So the scope emerges from the authorities; it is not a name
 whitelist, and it will pick up any future composite our combinations start
 using without a code change.

--------------------------------------------------------------------------------
 THE THREE CLASSES, and why only two of them block
--------------------------------------------------------------------------------

 C1 NO-CONTROL    the component has no form control anywhere on that entity.
                  The officer CANNOT enter it. Indisputable. BLOCKING.

 C2 NOT-COMPOSED  a control exists but is absent from the composite attribute's
                  sourceField list, so it can never enter <Name>. The officer
                  types into a black hole. Indisputable. BLOCKING.

 C3 NOT-IN-POOL   control exists AND is composed, but its fieldId appears in no
                  combination's set[]/any[]. *** REPORTED AS [NOTE], NOT A FAIL,
                  BECAUSE WHETHER THIS BREAKS ANYTHING IS UNPROVEN. ***
                  audit_wiring_closure's class A requires "no attribute sources
                  it AND no combo references it" -- so it deliberately treats
                  attribute-sourcing alone as reaching the wire, and reports
                  HI_HCJDC_OFML closed. I claimed the opposite. NEITHER position
                  has a committed log behind it, so per the hypothesis-quarantine
                  rule this stays a NOTE.
                  DISCRIMINATING TEST, and HI_HCJDC_OFML is the only provider
                  that isolates the variable (4 controls, composed, zero any[]):
                  fill middle + suffix on an HI Driver License query and read
                  <Name>.
                     DOE, JOHN A JR -> sourceField alone suffices. C3 is a
                        non-finding, HI is correct, and fixing a C1 provider
                        needs control + sourceField only.
                     DOE, JOHN      -> any[] membership is REQUIRED. C3 becomes
                        BLOCKING, HI is genuinely discarding input, and every C1
                        fix must add any[] entries too.
                  Do not promote C3 to blocking without that log.

 A run that compares ZERO components is a [FAIL], never a vacuous PASS
 (ENGINEERING_STANDARD 4.3) -- the denominator is printed every run.
================================================================================
#>
[CmdletBinding()]
param(
    [string]$Provider,
    [string]$Path,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_resolve_provider_json.ps1"
. "$PSScriptRoot\_resolve_provider_xml.ps1"

$lines = New-Object System.Collections.ArrayList
function Emit([string]$s) { [void]$lines.Add($s); if (-not $Quiet) { Write-Host $s } }

function Canon([string]$s) {
    if (-not $s) { return '' }
    return ($s -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

# the component names we know how to map to a discrete officer control, and the
# token that identifies such a control / sourceField
$COMPONENT_TOKEN = [ordered]@{
    'Last'   = 'last'
    'First'  = 'first'
    'Middle' = 'middle'
    'Suffix' = 'suffix'
}
$NAME_SIGNATURE = 'First+Last+Middle+Suffix'

# ---------------------------------------------------------------- provider list
$provDirs = @()
if ($Path) {
    $pd = Split-Path -Parent (Resolve-Path $Path)
    $provDirs = @([pscustomobject]@{ Name = (Split-Path $pd -Leaf); Dir = $pd; Json = (Resolve-Path $Path).Path })
} elseif ($Provider) {
    $d = Join-Path $root "providers\$Provider"
    if (-not (Test-Path $d)) { throw "No such provider directory: $d" }
    $provDirs = @([pscustomobject]@{ Name = $Provider; Dir = $d; Json = $null })
} elseif ($All) {
    foreach ($d in (Get-ChildItem (Join-Path $root 'providers') -Directory | Sort-Object Name)) {
        $provDirs += [pscustomobject]@{ Name = $d.Name; Dir = $d.FullName; Json = $null }
    }
} else {
    throw 'Specify -Provider <NAME>, -Path <json>, or -All.'
}

Emit '============================================================================'
Emit '  METADATA COMPONENT -> FORM CONTROL COVERAGE (composite name fields)'
Emit '  Can the officer actually enter every component the metadata defines?'
Emit '============================================================================'

$totC1 = 0; $totC2 = 0; $totC3 = 0
$compared = 0; $provCompared = 0; $noXml = @(); $provWith = @()

foreach ($p in $provDirs) {
    $jsonPath = $p.Json
    if (-not $jsonPath) { $jsonPath = Get-ProviderRootJson -ProvDir $p.Dir -Provider $p.Name }
    if (-not $jsonPath -or -not (Test-Path $jsonPath)) { Emit ("  {0,-22} [SKIP] no active JSON" -f $p.Name); continue }

    $xmlPath = $null
    try { $xmlPath = Get-ProviderMetadataXml -Provider $p.Name -ProvDir $p.Dir } catch { $xmlPath = $null }
    if (-not $xmlPath) {
        Emit ("  {0,-22} [NOTE] no metadata XML resolved -- NOT COMPARED" -f $p.Name)
        $noXml += $p.Name
        continue
    }

    $j = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($xmlPath)

    # ---- form controls, per entity. 'hidden' is a NODE-level property, never props.hidden.
    $controls = @{}   # entity -> canon(fieldId) -> @{ Id; Visible }
    foreach ($b in @($j.bundles)) {
        foreach ($c in @($b.configurations)) {
            if ("$($c.type)" -ne 'QUERYINPUTFORM') { continue }
            $ent = "$($c.targetEntity)"
            if (-not $controls.ContainsKey($ent)) { $controls[$ent] = @{} }
            foreach ($lp in $c.layout.PSObject.Properties) {
                foreach ($np in $lp.Value.PSObject.Properties) {
                    $node = $np.Value
                    $fid = $null
                    try { $fid = "$($node.props.fieldId)" } catch { }
                    if (-not $fid) { continue }
                    $isHidden = $false
                    try { if ($node.hidden) { $isHidden = $true } } catch { }
                    $k = Canon $fid
                    if (-not $controls[$ent].ContainsKey($k)) {
                        $controls[$ent][$k] = [pscustomobject]@{ Id = $fid; Visible = (-not $isHidden) }
                    } elseif (-not $isHidden) {
                        $controls[$ent][$k].Visible = $true
                    }
                }
            }
        }
    }

    # ---- built (non-RMS) QIDMs, keyed by metadata transaction name
    $qidms = @()
    foreach ($b in @($j.bundles)) {
        foreach ($c in @($b.configurations)) {
            if ("$($c.type)" -ne 'QUERYINPUTDATAMAPPING') { continue }
            if ("$($c.provider)" -eq 'RMS') { continue }
            $qidms += $c
        }
    }
    if ($qidms.Count -eq 0) { Emit ("  {0,-22} [SKIP] no CommSys QIDM" -f $p.Name); continue }

    $provCompared++
    $found = New-Object System.Collections.ArrayList

    foreach ($q in $qidms) {
        $txnName = "$($q.query)"
        $ent = "$($q.targetEntity)"

        $txn = $doc.SelectNodes("//*[local-name()='Transaction']") |
               Where-Object { $_.GetAttribute('name') -eq $txnName } | Select-Object -First 1
        if (-not $txn) { continue }

        # composite name-signature fields DEFINED in this transaction
        $composite = @{}
        foreach ($f in $txn.SelectNodes("*[local-name()='Fields']/*[local-name()='Field']")) {
            $cs = @($f.SelectNodes("*[local-name()='Components']/*[local-name()='Component']") |
                    ForEach-Object { $_.GetAttribute('name') })
            if ((($cs | Sort-Object) -join '+') -eq $NAME_SIGNATURE) { $composite[$f.GetAttribute('name')] = $true }
        }
        if ($composite.Count -eq 0) { continue }

        # ...and REFERENCED by one of its combinations (this is the noise filter)
        $referenced = @{}
        foreach ($fr in $txn.SelectNodes("*[local-name()='Combinations']//*[local-name()='Field']")) {
            $rn = $fr.GetAttribute('reference')
            if ($composite.ContainsKey($rn)) { $referenced[$rn] = $true }
        }
        if ($referenced.Count -eq 0) { continue }

        # this QIDM's combination pool (every fieldId named in any set[]/any[])
        $pool = @{}
        foreach ($cb in @($q.combinations)) {
            foreach ($fx in (@($cb.requirements.set) + @($cb.requirements.any))) {
                if ("$fx") { $pool[(Canon $fx)] = $true }
            }
        }

        foreach ($mf in ($referenced.Keys | Sort-Object)) {
            # the QIDM attribute that targets this metadata field
            $attr = @($q.attributes | Where-Object { (Canon $_.targetField) -eq (Canon $mf) }) | Select-Object -First 1
            if (-not $attr) { continue }   # query builds no name search at all -- not this gate's business

            $srcCanon = @(@($attr.sourceField) | Where-Object { "$_" } | ForEach-Object { Canon $_ })

            foreach ($comp in $COMPONENT_TOKEN.Keys) {
                $tok = $COMPONENT_TOKEN[$comp]
                $compared++

                # THE SOURCEFIELD IS THE AUTHORITY FOR *WHICH* CONTROL, NOT A TOKEN SEARCH OF THE
                # FORM. Person carries TWO name pools (DL + the DH-suffixed one) on the SAME entity,
                # so an entity-wide token match reported HI_HCJDC_OFML's DriverLicenseQuery against
                # 'nameMiddleDH' -- the wrong card. The attribute's own sourceField already carries
                # the DH suffix, so resolve through it and only fall back to a token probe when the
                # component is absent from sourceField altogether.
                $sfMatch = @(@($attr.sourceField) | Where-Object { "$_" -and (Canon $_) -match $tok })
                $inSource = $sfMatch.Count -gt 0

                if ($inSource) {
                    $sfId = "$($sfMatch[0])"
                    $sfKey = Canon $sfId
                    $hasControl = ($controls.ContainsKey($ent) -and $controls[$ent].ContainsKey($sfKey))
                    $ctrlKeys = @()
                    if ($hasControl) { $ctrlKeys = @($sfKey) }
                } else {
                    # not composed at all -- does the officer even have somewhere to type it?
                    $ctrlKeys = @()
                    if ($controls.ContainsKey($ent)) {
                        $ctrlKeys = @($controls[$ent].Keys | Where-Object { $_ -match '^name' -and $_ -match $tok })
                    }
                    $hasControl = $ctrlKeys.Count -gt 0
                }

                # NOTE: the -f expression MUST be parenthesised inside .Add(). PowerShell parses a
                # method call's arguments as a comma-separated list, so .Add("fmt" -f $a,$b,$c) binds
                # only $a to -f and passes $b,$c as extra Add() args -> "Error formatting a string:
                # Index ... less than the size of the argument list". Caught by the LAW 2 run.
                if (-not $hasControl -and -not $inSource) {
                    [void]$found.Add(("    C1 NO-CONTROL     {0,-30} {1}.{2}: no form control on the {3} form -- the officer CANNOT enter it" -f $txnName, $mf, $comp, $ent))
                    $totC1++
                    continue
                }
                if ($hasControl -and -not $inSource) {
                    [void]$found.Add(("    C2 NOT-COMPOSED   {0,-30} {1}.{2}: control '{3}' exists but is NOT in attr '{4}' sourceField -- never reaches <{1}>" -f $txnName, $mf, $comp, $controls[$ent][$ctrlKeys[0]].Id, $attr.name))
                    $totC2++
                    continue
                }
                if (-not $hasControl -and $inSource) {
                    [void]$found.Add(("    C1 NO-CONTROL     {0,-30} {1}.{2}: attr '{3}' sources it but NO control emits it" -f $txnName, $mf, $comp, $attr.name))
                    $totC1++
                    continue
                }
                # composed and controlled -- is the fieldId in any combination pool?
                $inPool = @($ctrlKeys | Where-Object { $pool.ContainsKey($_) }).Count -gt 0
                if (-not $inPool) {
                    [void]$found.Add(("    C3 NOT-IN-POOL    {0,-30} {1}.{2}: control '{3}' composed but in NO combination set[]/any[] -- IMPACT UNPROVEN, see header" -f $txnName, $mf, $comp, $controls[$ent][$ctrlKeys[0]].Id))
                    $totC3++
                }
            }
        }
    }

    if ($found.Count -eq 0) {
        Emit ("  {0,-22} complete" -f $p.Name)
    } else {
        $provWith += $p.Name
        Emit ("  {0,-22} {1} finding(s)" -f $p.Name, $found.Count)
        foreach ($f in $found) { Emit $f }
    }
}

Emit '----------------------------------------------------------------------------'
Emit ("  {0} provider(s) compared / {1} component(s) examined" -f $provCompared, $compared)
Emit ("  C1 no-control {0} / C2 not-composed {1} / C3 not-in-pool {2} (NOTE only)" -f $totC1, $totC2, $totC3)
if ($noXml.Count) { Emit ("  NOT COMPARED (no metadata XML): {0}" -f ($noXml -join ', ')) }

$exit = 0
if ($compared -eq 0) {
    Emit '  [FAIL] ZERO components compared -- this is a vacuous run, not a pass (ENGINEERING_STANDARD 4.3)'
    $exit = 1
} elseif (($totC1 + $totC2) -gt 0) {
    Emit ("  [FAIL] {0} component(s) the metadata defines that the officer cannot deliver" -f ($totC1 + $totC2))
    Emit ("         providers with findings: {0}" -f ($provWith -join ', '))
    $exit = 1
} else {
    Emit ("  [PASS] every metadata-defined name component is controlled and composed ({0} examined)" -f $compared)
}
if ($totC3 -gt 0) {
    Emit ("  [NOTE] {0} C3 not-in-pool -- NOT counted as a failure; impact is UNPROVEN." -f $totC3)
    Emit '         Settle it with ONE HI_HCJDC_OFML Driver License query filling middle + suffix.'
}
Emit ("  RESULT: {0} blocking finding(s) / {1} component(s) examined" -f ($totC1 + $totC2), $compared)
Emit '----------------------------------------------------------------------------'

if ($OutFile) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($OutFile, (($lines -join "`r`n") + "`r`n"), $enc)
    if (-not $Quiet) { Write-Host "  -> $OutFile" }
}
exit $exit
