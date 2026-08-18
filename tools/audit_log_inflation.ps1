<#
  audit_log_inflation.ps1 -- attacks aimed at COVERAGE INFLATION, not at correctness.

  TWO LESSONS THIS TOOL LEARNED ON ITSELF, both worth more than its findings:

  1. A CHECK THAT PARSES NOTHING PASSES EVERYTHING. Attack B first parsed
     get_entity_fingerprints with '^\s*(\w+)\s*[:=]\s*([0-9a-f]{16,})' -- but that tool emits JSON,
     so ZERO entities were captured, NOTHING was ever compared, and B printed "all logs match" on
     all 6 providers. It now parses JSON, ASSERTS the map is non-empty, and PRINTS THE COMPARED
     COUNT so a vacuous run is visible on its face. Never report a pass without the denominator.
  2. NEVER SUBSTRING-MATCH A TOOL'S OUTPUT FOR A VERDICT. A sibling harness scored every provider
     as "INVERSION" purely because audit_devdoc_order's HEADER explains what an inversion is. Anchor
     on the verdict line ('[FAIL] DEVDOC-ORDER INVERSION'), never a bare keyword. Same class as the
     test_phase2 '\bFAIL\b' bug fixed the same day. Also: tools that write via Write-Host produce
     NOTHING through an in-session pipeline -- capture them via `& powershell -File ... 2>&1`.

  Rob: "please be creative and shady and tricky when challenging all the results."

  Every existing gate asks "is what we sent correct?". None asks "are these N logs actually N
  DISTINCT tests?" -- and that is the cheapest way for a 109/109 to be a lie. Five attacks:

  A. CLONE ATTACK        two logs with byte-identical wire XML = ONE test wearing two names.
                         Coverage counts them twice. No gate checks this.
  B. FINGERPRINT DRIFT   a log records the Entity Fingerprint it was captured against. If the JSON
                         changed WITHOUT a version bump, the log is stale while its filename still
                         says current. Version equality cannot see an in-place rebuild.
  C. ORPHAN WIRE FIELD   a wire field that is no longer a targetField of the current QIDM for that
                         query = the log predates a field rename/removal.
  D. DEGENERATE GUARDRAIL a _guardrail_ test whose two competing identifiers were filled with the
                         SAME value proves nothing about priority -- either combo "matches" the value.
  E. SINGLETON VALUE     an identifier value used across EVERY combo of a query means no test would
                         notice if routing collapsed to one combo (all fills look alike).
#>
param([string[]]$Providers = @('TX_TLETS','NY_NYSPIN_EJUSTICE','NJ_NJCJIS','FL_FCIC','HI_HCJDC_OFML','CA_CLETS'))

$ErrorActionPreference = 'Continue'
$repo = 'C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON'
Set-Location $repo
. "$repo\tools\_resolve_provider_json.ps1"
. "$repo\tools\_json_canonical.ps1"

$grand = @()
foreach ($p in $Providers) {
    $d  = Join-Path $repo "providers\$p"
    $jp = Get-ProviderRootJson -ProvDir $d -Provider $p
    if (-not $jp) { continue }
    $ver = [regex]::Match([IO.Path]::GetFileNameWithoutExtension($jp), '_v([\d.]+)$').Groups[1].Value
    $json = Get-Content $jp -Raw | ConvertFrom-Json

    # targetField universe per query (for attack C)
    $tfByQuery = @{}
    foreach ($b in $json.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTDATAMAPPING' -or "$($c.provider)" -eq 'RMS') { continue }
        $q = "$($c.query)"; if (-not $q) { continue }
        if (-not $tfByQuery.ContainsKey($q)) { $tfByQuery[$q] = @{} }
        foreach ($a in @($c.attributes)) {
            $tf = if ($a.targetField) { $a.targetField } else { $a.name }
            if ($tf) { $tfByQuery[$q]["$tf".ToLower()] = $true }
        }
    } }

    # ENVELOPE FIELD UNIVERSE (for attack C) -- DERIVED, not a hand-list.
    # Envelope fields are emitted by the AUTHENTICATION / QUERYMESSAGEFORMAT config for EVERY
    # transaction and are deliberately absent from any QIDM's attributes, so class C must not
    # count them. This used to be a hardcoded literal list, and it went stale the moment a
    # provider gained a new envelope field: CA_CLETS v2.25 added <Authentication>/<DeviceId>
    # (Build-Auth -IncludeDeviceId, the Mariposa LIVE production-failure fix) and class C
    # reported 111 orphans on 111 logs -- a gate at 100% false positives teaches everyone to
    # ignore it. Deriving from the config self-extends to the next envelope field.
    # The literal floor is XML SCAFFOLDING plus the QUERYMESSAGEFORMAT-emitted fields: QMF declares
    # NO `attributes` (it carries handlerFunction/payloadParent instead), so <MessageType>/<MessageKey>
    # cannot be derived and must stay listed. Keeping the FULL original list as a floor and UNIONing
    # the derived set means this change can only ADD coverage, never remove it -- the first attempt
    # replaced the list outright and drove class C from 111 orphans on 1 provider to every log on all
    # 6, because `@($null).Count` is 1 and QMF's empty attributes read as populated.
    $envelope = @{}
    foreach ($e in @('transaction','request','header','lawenforcementtransaction','body','messagetype','messagekey',
                     'session','id','authentication','username','ori','mnemonic','dexstateuserid','password','agency')) { $envelope[$e] = $true }
    foreach ($b in $json.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -notin @('AUTHENTICATION','QUERYMESSAGEFORMAT')) { continue }
        foreach ($a in @($c.attributes)) {
            $tf = if ($a.targetField) { $a.targetField } else { $a.name }
            if ($tf) { $envelope["$tf".ToLower()] = $true }
        }
    } }

    $logs = @(Get-ChildItem (Join-Path $d 'logs') -Recurse -Filter "*.txt" -File -EA SilentlyContinue |
              Where-Object { $_.FullName -notmatch '[\\/]_archive_' })
    if (-not $logs.Count) { $grand += [pscustomobject]@{P=$p;V=$ver;N=0;Clone='n/a';Fp='n/a';Orphan='n/a';Degen='n/a';Single='n/a'}; continue }

    $byHash = @{}; $fpBad = @(); $orphan = @(); $degen = @(); $valsByQuery = @{}
    foreach ($l in $logs) {
        $c = Get-Content $l.FullName -Raw
        $q = [regex]::Match($c, 'TEST LOG:\s*\S+\s+\S+\s+(\S+)').Groups[1].Value
        $x = [regex]::Match($c, '(?s)COMMSYS XML\s*\n(.*?)(?:COMMSYS XML RESPONSE|RMS QUERY|FIELD ANALYSIS)').Groups[1].Value
        $lbl = $l.BaseName -replace "^$([regex]::Escape("${p}_v${ver}_"))", ''

        # A. clone attack -- normalise whitespace so pretty-print differences do not mask a clone,
        # AND strip the PER-SUBMISSION UNIQUE envelope fields.
        # *** THIS CHECK COULD NOT FAIL UNTIL 2026-08-18. *** Every submission carries a unique
        # <Id> (transaction id), so no two logs ever hashed the same and "[A CLONE] none -- every
        # log's wire XML is distinct" was a VACUOUS PASS on every provider, every run, forever.
        # Found by prediction: TX_TLETS v4.21 plan tests n97 and n98 are BYTE-IDENTICAL (same fills,
        # same expectedKeyRef=QBBoatHullIdNumber), so they must produce functionally identical
        # requests -- yet the gate reported 0 clones across 98 logs. Diffing the two wires showed
        # they differed in exactly ONE element: <Id>. Everything a clone check actually cares about
        # -- the query payload -- was identical.
        # A clone is "same REQUEST CONTENT twice", not "same bytes twice": two tests that send the
        # same payload prove one thing, not two, and that is coverage inflation whatever the ids say.
        if ($x.Trim()) {
            # TWO forms of per-submission id, and MISSING THE SECOND ONE KEPT THE GATE VACUOUS EVEN
            # AFTER THE FIRST FIX: the correlation id appears BOTH as an <Id> ELEMENT and as an
            # id="..." ATTRIBUTE on <api:Transaction>. Stripping only the element still left the two
            # byte-identical TX_TLETS n97/n98 tests hashing differently. Found by diffing the two
            # normalised strings character by character (they diverged at char 306, inside
            # <api:Transaction id="01M0APF...">), not by reasoning about the regex.
            $norm = $x -replace '(?is)<(Id|Session|TransactionId|Timestamp|DateTime)>[^<]*</\1>', ''
            $norm = $norm -replace '(?i)\sid="[^"]*"', ''
            $norm = ($norm -replace '\s+', '').ToLower()
            # A CLONE IS SAME INPUT *AND* SAME OUTPUT -- keying on the wire alone is wrong here.
            # A guardrail test deliberately fills a COMPETING identifier to prove it is ignored, so
            # a PASSING guardrail produces wire IDENTICAL to its plain base test. That is the
            # evidence, not duplication: "OLN alone fires DQOLN" and "OLN+Name still fires DQOLN"
            # are two different tests with two different inputs that must agree on the output.
            # Keying on wire-only flagged 50 such pairs across 6 providers (TX 4 / NY 14 / NJ 5 /
            # FL 13 / HI 5 / CA 9) -- all correct behaviour. Shipping that would have trained
            # everyone to ignore attack A, which is strictly worse than the vacuous pass it replaced.
            # So the fills are folded into the key: identical wire + identical fills = a genuine
            # clone (two tests proving one thing), identical wire + different fills = a guardrail
            # doing its job.
            $qs = [regex]::Match($c, '(?s)QUERY STRING.*?(\{.*?\})').Groups[1].Value
            $qsNorm = ($qs -replace '\s+', '').ToLower()
            $h = Get-Sha256Hex ($norm + '|FILLS|' + $qsNorm)
            if (-not $byHash.ContainsKey($h)) { $byHash[$h] = @() }
            $byHash[$h] += $lbl
        }
        # B. fingerprint recorded in the log
        $fp = [regex]::Match($c, 'Entity Fingerprint:\s*([0-9a-f]{16,})').Groups[1].Value
        if (-not $fp) { $fpBad += "$lbl (no fingerprint recorded)" }
        # C. orphan wire fields
        if ($q -and $tfByQuery.ContainsKey($q) -and $x) {
            foreach ($mm in [regex]::Matches($x, '<([A-Za-z][A-Za-z0-9]*)>')) {
                $e = $mm.Groups[1].Value.ToLower()
                # Envelope, not query payload. Excluding these is NOT weakening the attack: they are
                # emitted by the AUTH/QMF config for every transaction and are deliberately absent
                # from any QIDM's attributes, so counting them produced exactly 6 false hits per log
                # (534/89, 654/109 ...) and buried whatever real orphan might exist. Now DERIVED
                # from the provider's own AUTHENTICATION/QUERYMESSAGEFORMAT config -- see $envelope.
                if ($envelope.ContainsKey($e)) { continue }
                if (-not $tfByQuery[$q].ContainsKey($e)) { $orphan += "$lbl -> <$($mm.Groups[1].Value)> not a targetField of $q" }
            }
        }
        # D. degenerate guardrail -- competing identifiers filled with the SAME value
        if ($lbl -match '_guardrail_vs_') {
            $qs = [regex]::Match($c, '(?s)QUERY STRING.*?(\{.*?\})').Groups[1].Value
            if ($qs) {
                try {
                    $o = $qs | ConvertFrom-Json
                    $ids = @($o.PSObject.Properties | Where-Object { $_.Name -match '(?i)Number$|^operatorLicense|Hull|Serial|^nameLast' -and $_.Value })
                    $dupe = @($ids | Group-Object { "$($_.Value)" } | Where-Object { $_.Count -gt 1 })
                    foreach ($g in $dupe) { $degen += "$lbl -> $(($g.Group | ForEach-Object { $_.Name }) -join ' == ') all = '$($g.Name)'" }
                } catch {}
            }
        }
        # E. collect identifier values per query for the singleton test
        $qs2 = [regex]::Match($c, '(?s)QUERY STRING.*?(\{.*?\})').Groups[1].Value
        if ($q -and $qs2) {
            try { $o2 = $qs2 | ConvertFrom-Json
                if (-not $valsByQuery.ContainsKey($q)) { $valsByQuery[$q] = @{} }
                foreach ($pr in $o2.PSObject.Properties) { if ($pr.Value) { $valsByQuery[$q]["$($pr.Name)=$($pr.Value)"] = $true } }
            } catch {}
        }
    }
    $clones = @($byHash.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })

    # B (real check): recompute current fingerprints and compare against what logs recorded
    # get_entity_fingerprints emits JSON ({"Boat":"4b63...", ...}), NOT key:value text. The first
    # version of this parsed it with '^\s*(\w+)\s*[:=]\s*([0-9a-f]{16,})', captured ZERO entities,
    # and so compared NOTHING -- attack B printed "all logs match" on every provider while being
    # completely vacuous. Parse as JSON, then ASSERT the map is non-empty before trusting any verdict.
    $cur = @{}
    $fpOut = & powershell -ExecutionPolicy Bypass -File "$repo\tools\get_entity_fingerprints.ps1" -Path $jp 2>&1 | Out-String
    try {
        $fpJson = ($fpOut -replace '(?s)^[^{]*', '') | ConvertFrom-Json
        foreach ($pr in $fpJson.PSObject.Properties) { $cur[$pr.Name] = "$($pr.Value)" }
    } catch { }
    $fpVacuous = ($cur.Count -eq 0)
    $fpMismatch = @()
    $fpCompared = 0
    foreach ($l in $logs) {
        $c = Get-Content $l.FullName -Raw
        $fp = [regex]::Match($c, 'Entity Fingerprint:\s*([0-9a-f]{16,})').Groups[1].Value
        $ent = $l.Directory.Name
        if ($fp -and $cur.ContainsKey($ent)) {
            $fpCompared++
            if ($cur[$ent] -ne $fp) { $fpMismatch += "$($l.BaseName) ($ent): log=$($fp.Substring(0,12)) json=$($cur[$ent].Substring(0,12))" }
        }
    }

    Write-Host "`n########## $p v$ver -- $($logs.Count) logs ##########" -ForegroundColor Cyan
    if ($clones.Count)    { Write-Host "  [A CLONE] $($clones.Count) group(s) of byte-identical wire XML:" -ForegroundColor Red
                            $clones | Select-Object -First 6 | ForEach-Object { Write-Host "        $($_.Value -join '  ==  ')" -ForegroundColor Red } }
    else                  { Write-Host "  [A CLONE] none -- every log's wire XML is distinct" -ForegroundColor Green }
    if ($fpVacuous)       { Write-Host "  [B FINGERPRINT] VACUOUS -- could not parse current fingerprints; NOTHING was compared" -ForegroundColor Red }
    elseif ($fpMismatch.Count){ Write-Host "  [B FINGERPRINT] $($fpMismatch.Count) of $fpCompared compared log(s) recorded a fingerprint != current JSON:" -ForegroundColor Red
                            $fpMismatch | Select-Object -First 5 | ForEach-Object { Write-Host "        $_" -ForegroundColor Red } }
    else                  { Write-Host "  [B FINGERPRINT] $fpCompared log(s) COMPARED, all match current entity fingerprints" -ForegroundColor Green }
    if ($orphan.Count)    { Write-Host "  [C ORPHAN FIELD] $($orphan.Count):" -ForegroundColor Red
                            $orphan | Select-Object -Unique -First 6 | ForEach-Object { Write-Host "        $_" -ForegroundColor Red } }
    else                  { Write-Host "  [C ORPHAN FIELD] none -- every wire field is a current targetField" -ForegroundColor Green }
    if ($degen.Count)     { Write-Host "  [D DEGENERATE GUARDRAIL] $($degen.Count):" -ForegroundColor Red
                            $degen | ForEach-Object { Write-Host "        $_" -ForegroundColor Red } }
    else                  { Write-Host "  [D DEGENERATE GUARDRAIL] none -- competing identifiers use distinct values" -ForegroundColor Green }

    $grand += [pscustomobject]@{ P=$p; V=$ver; N=$logs.Count; Clone=$clones.Count; Fp=$fpMismatch.Count; Orphan=@($orphan|Select-Object -Unique).Count; Degen=$degen.Count }
}

Write-Host "`n"
Write-Host ('=' * 96) -ForegroundColor Cyan
Write-Host '  ADVERSARIAL PROBE -- coverage-inflation attacks (all counts must be 0)' -ForegroundColor Cyan
Write-Host ('=' * 96) -ForegroundColor Cyan
Write-Host ("  {0,-22} {1,-7} {2,-7} {3,-8} {4,-8} {5,-8} {6}" -f 'PROVIDER','VER','LOGS','A:CLONE','B:FPRINT','C:ORPHAN','D:DEGEN')
foreach ($g in $grand) {
    $bad = ("$($g.Clone)$($g.Fp)$($g.Orphan)$($g.Degen)" -match '[1-9]')
    Write-Host ("  {0,-22} {1,-7} {2,-7} {3,-8} {4,-8} {5,-8} {6}" -f $g.P,$g.V,$g.N,$g.Clone,$g.Fp,$g.Orphan,$g.Degen) -ForegroundColor $(if($bad){'Red'}else{'Green'})
}
Write-Host ''
