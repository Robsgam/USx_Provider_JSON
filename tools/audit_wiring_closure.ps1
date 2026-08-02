<#
  audit_wiring_closure.ps1 -- FORM <-> QIDM WIRING CLOSURE. The direction nothing else checks.

  WHY THIS EXISTS (2026-08-02):
    Every other gate in this repo validates the REQUEST against an AUTHORITY -- devdoc, metadata,
    reachability, log evidence. All of them start from "what should we send?" and work inward. None
    of them asks the plumbing question:

        does every officer-visible control actually reach the wire, and does every wired field
        actually have somewhere for the officer to type it?

    That gap is not theoretical. CA_SAN_LUIS_OBISPO shipped a VISIBLE "Purpose Code (DH)" control,
    prefilled 'C', with a matching PurposeCode attribute -- and the field was in no combination's
    any[], so the officer's value was silently discarded on every DriverHistory query. Validator,
    verify_build, audit_metadata, audit_cad, reachability, requirement_fidelity and the spec plan
    were ALL green on that provider. It was found by hand, chasing something else. A control the
    officer can see and set, whose value goes nowhere, is worse than no control at all: it actively
    lies about what the query will do.

  THE NINE CLOSURE BREAKS (each is silent by construction -- no gate, no error, no wire evidence):
    A DEAD CONTROL        form field exists; no QIDM attribute sources it AND no combo references it
                          -> the officer types into a black hole
    B ORPHAN ATTRIBUTE    QIDM attribute's sourceField has no control on that entity's form
                          -> nothing can ever populate it (unless a rule handler supplies the value)
    C UNFILLABLE REQ      a combo set[]/any[] names a fieldId with no control on that form
                          -> the combination can never be satisfied by a human
    D INERT CONDITION     conditions[].field names a fieldId with no control
                          -> the routing gate silently never changes anything
    E INERT DEFAULT       defaults[].field names something absent from that combo's set[]/any[]
                          -> the CAD default is never applied
    F VARIANT GAP         a control on `default` is MISSING from CAD_DISPATCH / FIRST_RESPONDER
                          -> the CAD officer simply does not get that field, and A cannot see it
                             because A unions the variants by design
    G DUP FIELDID         the same fieldId bound twice in one layout variant
                          -> undefined which control the officer's value comes from
    H DUP TARGETFIELD     two attributes in one QIDM writing the same targetField
                          -> undefined which value lands on the wire (verify_build checks this for
                             Results bundles only, never for request QIDMs)
    I DESELECT ORPHAN     queriesToDeselect naming a query that does not exist
                          -> the mutual exclusion never fires and both queries co-fire, silently

  F-I were probed across the portfolio on 2026-08-02 and found at ZERO, then folded in HERE rather
  than given their own script: same concern (is the form/QIDM pair internally coherent?), and a
  fifth standalone tool would just have become another orphan. Added at zero = regression guards.

  SCOPING / KNOWN-GOOD EXCLUSIONS (kept deliberately small -- a wide whitelist would hide the class):
    - CAD / First-Responder context controls (CadUnit, CadEvent, LinkToEvent) have no QIDM by design.
    - AUTH-fed identity (dexStateUserId) is supplied by the platform, not the form.
    - Handler-fed attributes (attr.rule present) are exempt from B: the handler is the source.
    - RMS bundle is skipped entirely; it has its own field contract.
    - Composite Name attributes legitimately source several controls.

  Usage: .\audit_wiring_closure.ps1 [-Provider <name>] [-All] [-Quiet]
#>

param(
    [string]$Provider,
    [switch]$All,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')

function Canon([string]$t) { ("$t" -replace '[^A-Za-z0-9]','').ToLower() }

# LINK_CURRENT_ASSIGNED_EVENT is the First-Responder "link this query to the active event" checkbox.
# It canonicalises to 'linkcurrentassignedevent', NOT 'linktoevent' as the layout helper's parameter
# name suggested -- the first run of this tool reported it as a dead control on all 5 entities of all
# 20 providers (100 of 110 findings), which is exactly how a real signal gets buried under a
# known-good one. It is platform context like CadUnit/CadEvent: consumed by the host, never by a QIDM.
$ctxRx  = '(?i)^(cadunit|cadevent|linktoevent|linkcurrentassignedevent|dexstateuserid)'
$totals = @{ A = 0; B = 0; C = 0; D = 0; E = 0; F = 0; G = 0; H = 0; I = 0; Providers = 0 }

$targets = @()
if ($All -or -not $Provider) {
    $targets = Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name
} else {
    $targets = @(Get-Item (Join-Path $repoRoot "providers\$Provider"))
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  FORM <-> QIDM WIRING CLOSURE" -ForegroundColor Cyan
Write-Host "  Does every control reach the wire, and every wired field have a control?" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan

foreach ($dir in $targets) {
    $prov = $dir.Name
    $jsonPath = Get-ProviderRootJson -Provider $prov -ProvDir $dir.FullName
    if (-not $jsonPath) { continue }
    $totals.Providers++

    $j = Get-Content $jsonPath -Raw | ConvertFrom-Json

    # ---- index form controls per entity, and QIDMs per entity -------------------------------
    $controls = @{}   # entity -> @{canon -> fieldId}
    $qidms    = @()
    $rmsQidms = @()
    foreach ($b in $j.bundles) {
        $isRms = ("$($b.provider)" -eq 'RMS')
        foreach ($c in @($b.configurations)) {
            if ($c.type -eq 'QUERYINPUTFORM' -and $c.layout) {
                $e = "$($c.targetEntity)"
                if (-not $controls.ContainsKey($e)) { $controls[$e] = @{} }
                # union across ALL layout variants: a control present only on CAD is still a control
                foreach ($vp in $c.layout.PSObject.Properties) {
                    foreach ($np in $vp.Value.PSObject.Properties) {
                        $p = $np.Value.props
                        if ($p -and $p.fieldId) { $controls[$e][(Canon $p.fieldId)] = "$($p.fieldId)" }
                    }
                }
            }
            if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and $c.combinations) {
                # RMS QIDMs are form-fed too (Build-RmsBundle -PascalCaseUsxFields), so a control
                # consumed ONLY by the Mark43 RMS search is NOT dead -- it just does not reach
                # CommSys. Skipping the RMS bundle entirely made this tool report 'raceCode' as a
                # dead control on four providers when every one of them feeds it to the RMS Person
                # QIDM. They are tracked for REFERENCE purposes but never audited for orphan
                # attributes / unfillable requirements, which are CommSys-contract questions.
                if ($isRms) { $rmsQidms += $c } else { $qidms += $c }
            }
        }
    }

    $findings = New-Object System.Collections.Generic.List[string]
    $allQueryNames  = @(); $allConfigNames = @()
    foreach ($bx in $j.bundles) { foreach ($cx in @($bx.configurations)) {
        if ("$($cx.type)" -eq 'QUERYINPUTDATAMAPPING') { $allQueryNames += "$($cx.query)"; $allConfigNames += "$($cx.name)" } } }

    # ---- B / C / D / E : wired things with no control ---------------------------------------
    $referenced = @{}   # entity -> set(canon) of every fieldId the QIDMs reference
    foreach ($q in $qidms) {
        $e = "$($q.targetEntity)"
        if (-not $referenced.ContainsKey($e)) { $referenced[$e] = @{} }
        $have = if ($controls.ContainsKey($e)) { $controls[$e] } else { @{} }

        foreach ($attr in @($q.attributes)) {
            $hasRule = [bool]$attr.rule
            foreach ($sf in @($attr.sourceField)) {
                if (-not "$sf") { continue }
                $k = Canon $sf
                $referenced[$e][$k] = $true
                if ($k -match $ctxRx) { continue }
                if (-not $have.ContainsKey($k) -and -not $hasRule) {
                    $findings.Add(("B ORPHAN ATTRIBUTE  {0,-26} attr '{1}' sourceField '{2}' has NO control on the {3} form" -f $q.query, $attr.name, $sf, $e)) | Out-Null
                    $totals.B++
                }
            }
        }

        foreach ($cm in @($q.combinations)) {
            $kr = "$($cm.keyReference)"
            $setF = @($cm.requirements.set  | Where-Object { $_ })
            $anyF = @($cm.requirements.any  | Where-Object { $_ })
            foreach ($f in ($setF + $anyF)) {
                $k = Canon $f
                $referenced[$e][$k] = $true
                if ($k -match $ctxRx) { continue }
                if (-not $have.ContainsKey($k)) {
                    $findings.Add(("C UNFILLABLE REQ    {0,-26} {1,-24} references '{2}' -- no control on the {3} form" -f $q.query, $kr, $f, $e)) | Out-Null
                    $totals.C++
                }
            }
            foreach ($cond in @($cm.requirements.conditions)) {
                foreach ($f in @($cond.field)) {
                    if (-not "$f") { continue }
                    $k = Canon $f
                    $referenced[$e][$k] = $true
                    if ($k -match $ctxRx) { continue }
                    if (-not $have.ContainsKey($k)) {
                        $findings.Add(("D INERT CONDITION   {0,-26} {1,-24} {2} '{3}' -- no control, so the gate never changes anything" -f $q.query, $kr, $cond.operator, $f)) | Out-Null
                        $totals.D++
                    }
                }
            }
            # defaults are keyed by ATTRIBUTE NAME; they only apply if that attribute's sourceField
            # is in this combo's set[]/any[]
            $poolCanon = @{}
            foreach ($f in ($setF + $anyF)) { $poolCanon[(Canon $f)] = $true }
            foreach ($d in @($cm.requirements.defaults)) {
                $dn = "$($d.field)"
                if (-not $dn) { continue }
                $attr = @($q.attributes | Where-Object { "$($_.name)" -eq $dn })
                $reach = $false
                if ($attr.Count) {
                    foreach ($sf in @($attr[0].sourceField)) { if ($poolCanon.ContainsKey((Canon $sf))) { $reach = $true } }
                } elseif ($poolCanon.ContainsKey((Canon $dn))) { $reach = $true }
                if (-not $reach) {
                    $findings.Add(("E INERT DEFAULT     {0,-26} {1,-24} default '{2}' is not in this combo's set[]/any[] -- never applied" -f $q.query, $kr, $dn)) | Out-Null
                    $totals.E++
                }
            }
        }
    }

    # RMS references count as REACHED for the dead-control test (see the note at collection).
    foreach ($rq in $rmsQidms) {
        $e = "$($rq.targetEntity)"
        if (-not $referenced.ContainsKey($e)) { $referenced[$e] = @{} }
        foreach ($attr in @($rq.attributes)) { foreach ($sf in @($attr.sourceField)) { if ("$sf") { $referenced[$e][(Canon $sf)] = $true } } }
        foreach ($cm in @($rq.combinations)) {
            foreach ($fx in (@($cm.requirements.set) + @($cm.requirements.any))) { if ("$fx") { $referenced[$e][(Canon $fx)] = $true } }
        }
    }

    # ---- F / G / H / I : structural integrity of the form+QIDM pair --------------------------
    # Four more silent classes, probed across the portfolio 2026-08-02 and found at ZERO. Folded in
    # HERE rather than given their own tool: they are the same concern this gate already owns
    # (is the form/QIDM pair internally coherent?), and a fifth standalone script would just become
    # another orphan. Added at zero so they are regression guards, not a backlog.
    foreach ($b in $j.bundles) {
        foreach ($c in @($b.configurations)) {
            if ($c.type -eq 'QUERYINPUTFORM' -and $c.layout) {
                $e = "$($c.targetEntity)"
                $vsets = @{}
                foreach ($vp in $c.layout.PSObject.Properties) {
                    $vids = @()
                    foreach ($np in $vp.Value.PSObject.Properties) {
                        $p = $np.Value.props
                        if ($p -and $p.fieldId) { $vids += "$($p.fieldId)" }
                    }
                    $vsets[$vp.Name] = @($vids | Select-Object -Unique)
                    # G: the SAME fieldId twice in one layout variant -- two controls bound to one
                    # field, so which one the officer's value comes from is undefined.
                    foreach ($g in @($vids | Group-Object | Where-Object { $_.Count -gt 1 })) {
                        $findings.Add(("G DUP FIELDID       {0,-26} {1} variant '{2}' binds '{3}' {4}x -- undefined which control wins" -f '(form)', $e, $vp.Name, $g.Name, $g.Count)) | Out-Null
                        $totals.G++
                    }
                }
                # F: a control present on `default` but MISSING from CAD_DISPATCH / FIRST_RESPONDER.
                # This gate's dead-control test unions all variants, so it cannot see this by design:
                # a field the CAD officer simply does not get would look perfectly wired.
                if ($vsets.ContainsKey('default')) {
                    foreach ($k in $vsets.Keys) {
                        if ($k -eq 'default') { continue }
                        $miss = @($vsets['default'] | Where-Object { $vsets[$k] -notcontains $_ })
                        if ($miss.Count) {
                            $findings.Add(("F VARIANT GAP       {0,-26} {1} variant '{2}' lacks {3} control(s) present on default: {4}" -f '(form)', $e, $k, $miss.Count, (($miss | Select-Object -First 5) -join ', '))) | Out-Null
                            $totals.F++
                        }
                    }
                }
            }
            if ($c.type -eq 'QUERYINPUTDATAMAPPING') {
                # H: two attributes writing the SAME targetField in one QIDM -- which value lands is
                # undefined (verify_build checks this for Results bundles only, not request QIDMs).
                $tfs = @($c.attributes | ForEach-Object { "$($_.targetField)" } | Where-Object { $_ })
                foreach ($g in @($tfs | Group-Object | Where-Object { $_.Count -gt 1 })) {
                    $findings.Add(("H DUP TARGETFIELD   {0,-26} two attributes both write '{1}' -- undefined which value lands on the wire" -f $c.query, $g.Name)) | Out-Null
                    $totals.H++
                }
                # I: queriesToDeselect naming a query that does not exist -- the mutual-exclusion
                # never fires, so both queries co-fire and nobody sees a config error.
                foreach ($qd in @($c.queriesToDeselect)) {
                    if (-not "$qd") { continue }
                    if (($allQueryNames -notcontains "$qd") -and ($allConfigNames -notcontains "$qd")) {
                        $findings.Add(("I DESELECT ORPHAN   {0,-26} queriesToDeselect names '{1}', which is not a configuration here -- the exclusion never fires" -f $c.query, $qd)) | Out-Null
                        $totals.I++
                    }
                }
            }
        }
    }

    # ---- A : controls that reach nothing -----------------------------------------------------
    foreach ($e in $controls.Keys) {
        $ref = if ($referenced.ContainsKey($e)) { $referenced[$e] } else { @{} }
        foreach ($k in $controls[$e].Keys) {
            if ($k -match $ctxRx) { continue }
            if (-not $ref.ContainsKey($k)) {
                $findings.Add(("A DEAD CONTROL      {0,-26} control '{1}' on the {2} form reaches NO attribute and NO combination -- officer input discarded" -f '(form)', $controls[$e][$k], $e)) | Out-Null
                $totals.A++
            }
        }
    }

    if ($findings.Count) {
        Write-Host ""
        Write-Host ("-- {0}  ({1} closure break(s))" -f $prov, $findings.Count) -ForegroundColor Yellow
        foreach ($f in ($findings | Sort-Object)) { Write-Host ("   {0}" -f $f) }
    } elseif (-not $Quiet) {
        Write-Host ("   {0,-22} closed" -f $prov) -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "----------------------------------------------------------------------------"
Write-Host ("  {0} provider(s) checked" -f $totals.Providers)
Write-Host ("  A dead control {0} / B orphan attribute {1} / C unfillable req {2} / D inert condition {3} / E inert default {4}" -f $totals.A, $totals.B, $totals.C, $totals.D, $totals.E)
Write-Host ("  F variant gap {0} / G dup fieldId {1} / H dup targetField {2} / I deselect orphan {3}" -f $totals.F, $totals.G, $totals.H, $totals.I)
Write-Host "  A and C are officer-facing: a control that discards input, or a path no human can fill."
Write-Host "----------------------------------------------------------------------------"
