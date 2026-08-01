<#
  audit_optional_scope.ps1 -- answer FIX-vs-REGISTER for a "silently not transmitted" finding
  MECHANICALLY, instead of re-deriving it by hand every time.

  THE PROBLEM THIS SOLVES
    audit_devdoc_optionals reports, in identical wording:
        "#N +[Field] -> fires KEYREF but optional(s) Field are in NO matching combo's set[]/any[]
         -- silently not transmitted"
    On 2026-08-01 that one sentence was a REAL DROPPED VALUE on AZ_AZDPS (boat RegistrationNumber),
    CA_eSUN (purposeCode), CA_SAN_LUIS_OBISPO (DL State) and OH_LEADS (DL BirthDate) -- and the
    CORRECT BEHAVIOUR on TX_TLETS_CCH (QWI BirthDate/RaceCode/SexCode), NM_NMLETS_OFML (QV VehicleYear)
    and OH_LEADS (Boat ImageIndicator). Same words, opposite answers, seven times in one day.

    WHY: the devdoc gives ONE FLAT OPTIONAL LIST PER QUERY, while the metadata spreads those optionals
    across SEPARATE TRANSACTIONS (an in-state NCIC keyRef vs an out-of-state Nlets keyRef) or across
    CHOICE BRANCHES (where a nested <Set> scopes fields to one alternative). The flat list cannot
    distinguish a GLOBAL optional from one scoped to a single alternative.

    So the question is never "is the field in the devdoc's bracket?" -- it always is, that is why the
    finding fired. The question is:
        DOES THE FIRING COMBO'S OWN METADATA VARIANT DEFINE THIS FIELD?
      YES -> FIX. The metadata permits it on this exact path and we are dropping the officer's value.
      NO  -> REGISTER. Adding it would OVER-PERMIT: transmit a field this transaction does not define.
    Adding an over-permitted field is not a neutral "safe" choice -- it is a new defect, and
    audit_requirement_fidelity will report it as OVER-PERMITTED.

  WHAT THIS DOES
    Parses audit_devdoc_optionals' dropped-optional findings for a provider, then for each
    (firing keyRef, dropped field) pair looks up THAT keyRef's metadata Requirements -- scoped by
    (query, keyRef), never a bare keyRef (BUILD_RULES 13) -- and reports where the field actually sits:
        [FIX]      field IS defined on the firing variant (says whether Set or Any)
        [REGISTER] field is NOT on the firing variant; names which OTHER variant(s) do define it,
                   which is the evidence line the accepted-divergence entry needs
        [CHECK]    keyRef could not be resolved in metadata (synthetic/invented keyRef -- decide by hand)

  It RECOMMENDS; it does not edit and is not wired into any gate. The reasoning still has to be
  written down in the registry or the build script, because the reason is the durable part.

  Usage: powershell -ExecutionPolicy Bypass -File tools\audit_optional_scope.ps1 -Provider <NAME>
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Provider, [string]$OutFile)

$repo    = Split-Path $PSScriptRoot -Parent
$provDir = Join-Path $repo "providers\$Provider"
. (Join-Path $PSScriptRoot '_resolve_provider_json.ps1')
. (Join-Path $PSScriptRoot '_resolve_provider_xml.ps1')

$lines = @()
function O([string]$t, [string]$c = 'Gray') { $script:lines += $t; Write-Host $t -ForegroundColor $c }
function Canon([string]$s) { return ($s -replace '[^A-Za-z0-9]', '').ToLower() }

$jp = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
$xp = Get-ProviderMetadataXml -Provider $Provider -ProvDir $provDir
if (-not $jp -or -not $xp) { O "  [FAIL] cannot resolve JSON and/or metadata XML for $Provider" 'Red'; exit 1 }

O ('=' * 108) 'Cyan'
O "  OPTIONAL-SCOPE ADJUDICATOR -- $Provider" 'Cyan'
O '  Does the FIRING combo''s own metadata variant define the dropped field? YES -> FIX. NO -> REGISTER.' 'Cyan'
O ('=' * 108) 'Cyan'

# ── metadata: (transaction, keyRef) -> list of variants, each with its field->location map ──────────
[xml]$x = Get-Content $xp -Raw
$meta = @()
foreach ($n in $x.SelectNodes("//*[local-name()='Combination']")) {
    $kr = $n.GetAttribute('keyReference'); if (-not $kr) { continue }
    $t = $n.ParentNode; $tx = $null
    while ($t -and $t.NodeType -eq 'Element') { if ($t.LocalName -eq 'Transaction') { $tx = $t.GetAttribute('name'); break }; $t = $t.ParentNode }
    $req = $n.SelectSingleNode("*[local-name()='Requirements']"); if (-not $req) { continue }
    # every field anywhere in this variant, with whether it sits under an <Any>
    $fields = @{}
    foreach ($f in $req.SelectNodes(".//*[local-name()='Field']")) {
        $ref = $f.GetAttribute('reference'); if (-not $ref) { continue }
        $underAny = $false; $p = $f.ParentNode
        while ($p -and $p.NodeType -eq 'Element' -and $p.LocalName -ne 'Requirements') {
            if ($p.LocalName -eq 'Any') { $underAny = $true; break }
            $p = $p.ParentNode
        }
        $fields[(Canon $ref)] = @{ Name = $ref; Where = $(if ($underAny) { 'Any' } else { 'Set' }) }
    }
    $meta += [pscustomobject]@{ Tx = $tx; KeyRef = $kr; PF = $n.GetAttribute('primaryFieldReference'); Fields = $fields }
}
O ("  metadata variants indexed: {0}" -f $meta.Count)

# ── built combos: (query|keyRef) -> primaryFieldReference. Needed to pick WHICH metadata variant the
#    firing combo actually implements; without it a sibling variant's field reads as permitted.
$script:builtPfMap = @{}
$bj = Get-Content $jp -Raw | ConvertFrom-Json
foreach ($b in $bj.bundles) { foreach ($c in $b.configurations) {
    if ($c.type -ne 'QUERYINPUTDATAMAPPING' -or "$($c.provider)" -eq 'RMS') { continue }
    foreach ($cm in @($c.combinations)) {
        $k = "$($c.query)|$($cm.keyReference)"
        if ("$($cm.primaryFieldReference)") { $script:builtPfMap[$k] = "$($cm.primaryFieldReference)" }
    }
} }
O ("  built combos with a primaryFieldReference: {0}" -f $script:builtPfMap.Count)

# ── run the optionals gate and harvest its dropped-optional findings ────────────────────────────────
$gate = Join-Path $PSScriptRoot 'audit_devdoc_optionals.ps1'
$raw  = & powershell -NoProfile -ExecutionPolicy Bypass -File $gate -Path $jp 2>&1 | Out-String
$findings = @()
foreach ($m in [regex]::Matches($raw, '\[FAIL\]\s+(\S+)\s+#(\d+)[^\r\n]*?->\s+fires\s+(\S+)\s+but\s+optional\(s\)\s+([^\r\n]+?)\s+are in NO matching')) {
    foreach ($f in ($m.Groups[4].Value -split ',')) {
        $f = $f.Trim(); if (-not $f) { continue }
        $findings += [pscustomobject]@{ Query = $m.Groups[1].Value; Item = $m.Groups[2].Value; Fired = $m.Groups[3].Value; Field = $f }
    }
}
$findings = @($findings | Sort-Object Query, Fired, Field -Unique)
O ("  dropped-optional finding(s) to adjudicate: {0}" -f $findings.Count)
if (-not $findings.Count) {
    O '' ; O '  Nothing to adjudicate -- no dropped-optional FAILs for this provider.' 'Green'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 0
}
O ''

$fix = 0; $reg = 0; $chk = 0
foreach ($fd in $findings) {
    # scope by (query, keyRef): the SAME keyRef can exist under two transactions (BUILD_RULES 13)
    $cands = @($meta | Where-Object { $_.KeyRef -eq $fd.Fired })
    if (-not $cands.Count) {
        # built keyRefs are often synthetic (RQ.P from metadata RQ) -- try the longest metadata prefix
        $pre = @($meta | Where-Object { $fd.Fired.StartsWith($_.KeyRef) } | Sort-Object { -($_.KeyRef.Length) })
        if ($pre.Count) { $cands = @($meta | Where-Object { $_.KeyRef -eq $pre[0].KeyRef }) }
    }
    # narrow to the transaction whose name matches the reported query where possible
    $inQ = @($cands | Where-Object { $_.Tx -and ((Canon $_.Tx) -eq (Canon $fd.Query)) })
    if ($inQ.Count) { $cands = $inQ }

    # NARROW BY primaryFieldReference -- MANDATORY, and the tool was WRONG without it.
    # A metadata keyRef routinely carries several variants for different searches: OR_LEDS BQ has both
    # BQ{BoatHullIdNumber} and BQ{RegistrationNumber}. The firing combo BQ.H is the HULL search, but
    # RegistrationNumber is the Set KEY of the sibling REG variant -- so an unnarrowed lookup found it
    # on the sibling and reported [FIX] "metadata DOES define it", advising a change that would
    # OVER-PERMIT. Caught by its own evidence line naming BQ{RegistrationNumber} while the firing combo
    # was BQ.H. Same primaryFieldReference-restriction defect that put 5 false rows on
    # audit_defect_classes earlier the same day: A KEYREF IS NOT A VARIANT.
    $builtPf = $script:builtPfMap["$($fd.Query)|$($fd.Fired)"]
    if ($builtPf) {
        $samePf = @($cands | Where-Object { (Canon $_.PF) -eq (Canon $builtPf) })
        if ($samePf.Count) { $cands = $samePf }
        else {
            O ("  [CHECK]    {0} #{1}  fires {2}  field {3}" -f $fd.Query, $fd.Item, $fd.Fired, $fd.Field) 'Yellow'
            O ("             built combo declares PF='{0}' but no metadata variant of keyRef '{1}' has that PF" -f $builtPf, $fd.Fired) 'DarkGray'
            O '             -- cannot say which variant this implements; adjudicate by hand.' 'DarkGray'
            $chk++; continue
        }
    }

    $fc = Canon $fd.Field
    if (-not $cands.Count) {
        O ("  [CHECK]    {0} #{1}  fires {2}  field {3}" -f $fd.Query, $fd.Item, $fd.Fired, $fd.Field) 'Yellow'
        O ("             keyRef '{0}' not resolvable in metadata -- synthetic/invented, adjudicate by hand" -f $fd.Fired) 'DarkGray'
        $chk++; continue
    }
    $hit = @($cands | Where-Object { $_.Fields.ContainsKey($fc) })
    if ($hit.Count) {
        $w = @($hit | ForEach-Object { "$($_.KeyRef){$($_.PF)}:$($_.Fields[$fc].Where)" }) -join ', '
        O ("  [FIX]      {0} #{1}  fires {2}  field {3}" -f $fd.Query, $fd.Item, $fd.Fired, $fd.Field) 'Red'
        O ("             metadata DOES define it on the firing variant ({0}) -- the officer's value is being DROPPED." -f $w) 'DarkGray'
        O ("             Add '{0}' to that combination's any[] in the build script." -f $fd.Field) 'DarkGray'
        $fix++
    } else {
        $other = @($meta | Where-Object { $_.Fields.ContainsKey($fc) } | ForEach-Object { "$($_.Tx)/$($_.KeyRef){$($_.PF)}:$($_.Fields[$fc].Where)" } | Select-Object -Unique)
        O ("  [REGISTER] {0} #{1}  fires {2}  field {3}" -f $fd.Query, $fd.Item, $fd.Fired, $fd.Field) 'Green'
        O ("             NOT defined on the firing variant ({0}) -- adding it would OVER-PERMIT." -f (@($cands | ForEach-Object { "$($_.KeyRef){$($_.PF)}" }) -join ', ')) 'DarkGray'
        if ($other.Count) {
            O ("             It IS defined on: {0}" -f (($other | Select-Object -First 4) -join ' | ')) 'DarkGray'
            O '             ^ that is the evidence line for the accepted-divergence reason.' 'DarkGray'
        } else {
            O '             It is not defined on ANY variant of this metadata -- devdoc-only field.' 'DarkGray'
        }
        $reg++
    }
}

O ''
O ("  RESULT: {0} FIX / {1} REGISTER / {2} CHECK-BY-HAND   [{3} finding(s)]" -f $fix, $reg, $chk, $findings.Count) `
    $(if ($fix) { 'Red' } else { 'Green' })
O '  FIX = metadata permits the field on the firing path and we drop it. REGISTER = adding it would' 'DarkGray'
O '  transmit a field that transaction does not define. Recommendation only -- write the reason down.' 'DarkGray'

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
