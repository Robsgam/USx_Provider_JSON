<#
  audit_devdoc_combinations.ps1 -- DEVDOC -> BUILT direction, at COMBINATION granularity.

  WHY THIS EXISTS (Rob 2026-07-30: "i asked if all combos were built and you said yes.
  why does this keep happening."):
    Every other tool in this repo starts from the JSON and is therefore CLOSED under
    "what we built":
      validate / verify_build / test_commsys / generate_test_matrix / emit_test_plan
      / audit_combo_reachability / audit_log_*      enumerate JSON combos
      audit_supported_queries                        BUILT -> devdoc (query NAMES only)
      audit_query_trace                              metadata, but scoped to transactions
                                                     that ALREADY have a QIDM
    A devdoc-listed path that was never built is outside that closure. It cannot fail a
    test either, because the TEST PLAN IS GENERATED FROM THE JSON -- no combo, no test,
    no failure. So every gate can be green while an officer-facing search path is absent.

    Concretely, on TX_TLETS v4.16 with 36 PASS / 0 FAIL / 0 WARN and 95/95 tenant tests,
    TWO devdoc-Basic combinations were unbuilt AND unrecorded:
      BoatQuery      #2  "(OutofState) Name, BirthDate, State"
      DriverLicense  #3  "Name, BirthDate, SexCode, RaceCode [ExpandedBirthDateSearchCode, RegionId]"
    Both turned out to be defensible (metadata defines no Name/BirthDate for BoatQuery;
    TX builds -SkipRace so RaceCode is wired nowhere) -- but "defensible" is a HUMAN
    judgement that must be RECORDED, not an absence that no tool can see.

    Devdoc authority had only ever been applied at QUERY-NAME granularity: "is BoatQuery in
    the Basic Queries Supported list?" -- yes. The per-query "Possible Combinations" line was
    never read item by item. Six names validated for months; ~24 combinations under them never.

  WHAT IT CHECKS
    For each devdoc "Basic Queries Supported" query, parse its "Possible Combinations" line
    into numbered items, split mandatory fields from the [optional] bracket, then:

      [FAIL] UNWIRED  -- a MANDATORY devdoc field for that path appears in NO built combo's
                         set[] or any[] for that query. The path is unreachable at any fill
                         because the field is not in the provider config at all. This is
                         mechanical, needs no judgement, and is what caught Boat #2 / DL #3.
      [NOTE] NO-EXACT -- every mandatory field IS wired, but no single built combo's set[]
                         equals that devdoc item's mandatory set. Usually legitimate (metadata
                         is field-authority and may require more than the devdoc, or we split
                         one devdoc item into several keyRefs) -- so INFO, for human eyes.

    Suppress a reviewed FAIL by recording it in docs/tracking/<P>_ACCEPTED_DIVERGENCES.txt
    with rule `devdoc-combo-unbuilt` and the devdoc field named in the reason -- same registry
    audit_metadata CHECK 4/4d already reads.

  PARSER HONESTY (the lesson that produced this file)
    Devdoc text is pdftotext output: noisy, wrapped, inconsistent. A parser that silently
    reads nothing reports "all covered" -- which is exactly the failure mode being fixed.
    So: this tool FAILS LOUDLY if it cannot find a Possible Combinations line for a query it
    was told is supported, and -Explain prints what it parsed so a human can confirm it
    against the PDF. Validated against TX_TLETS, where the answer was known independently
    before the tool was written (expected: Boat #2 + DL #3 flagged, nothing else).

  Usage:
    .\audit_devdoc_combinations.ps1 -Path providers\TX_TLETS\TX_TLETS_v4.16.json
    .\audit_devdoc_combinations.ps1 -All
    .\audit_devdoc_combinations.ps1 -Path <json> -Explain      # show parsed devdoc items
#>

param(
    [string]$Path,
    [switch]$All,
    [switch]$Explain,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir "_resolve_provider_json.ps1")

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s, $c) { $lines.Add($s); if ($c) { Write-Host $s -ForegroundColor $c } else { Write-Host $s } }

# ── devdoc field token -> acceptable built fieldId tokens ─────────────────────────────
# Devdoc writes the human/CJIS field name; the form uses a fieldId. "Name" is composite
# (FormatStringRuleHandler over nameLast/nameFirst/...), so it maps to the components.
$fieldMap = @{
    'name'                        = @('namelast','namefirst','name')
    'state'                       = @('registrationstate','state')
    'gunserialnumber'             = @('serialnumber','gunserialnumber')
    'stickernumber'               = @('stickernumber')
    'financialresponsibilitytype' = @('financialresponsibilitytype')
    'regionid'                    = @('regionid')
    'vehicleyear'                 = @('vehicleyear')
    'racecode'                    = @('racecode')
    'operatorlicensenumber'       = @('operatorlicensenumber')
    'birthdate'                   = @('birthdate')
    'sexcode'                     = @('sexcode')
    # ---- aliases proven by inspection 2026-07-30; every one of these was a FALSE POSITIVE
    # in the first portfolio run (48 raw FAIL), so they are load-bearing, not cosmetic:
    'badgenumber'                 = @('dexstateuserid','badgenumber')          # AZ wires the badge as dexStateUserId (68 refs, all 4 queries)
    'articleserialnumber'         = @('articleserialnumber','serialnumber')    # OR/TN/OH use the generic serialNumber fieldId
    'articletypecode'             = @('articletypecode')                       # case handled by canonicalization
    'gunmake'                     = @('gunmake','firearmmake')                 # OH/TN use firearmMake
    'guncaliber'                  = @('guncaliber')
    'guntypecode'                 = @('guntypecode','guntype')
    'boathullidnumber'            = @('boathullidnumber','hullidnumber')
    'registrationnumber'          = @('registrationnumber','boatregistrationnumber')
    'licenseplatenumber'          = @('licenseplatenumber')
    'socialsecuritynumber'        = @('socialsecuritynumber','ownersocialsecuritynumber')
}
# One canonical token for a field name. Returns a STRING, never an array.
#
# WHY THIS IS SPLIT IN TWO (bug fixed 2026-07-30, before this tool ever shipped a verdict):
#   The first draft had a single Normalize-Token that returned `@($k)` and callers did
#   `(Normalize-Token $f)[0]`. PowerShell UNWRAPS a single-element array on return, so the
#   function handed back a bare string and `[0]` took its FIRST CHARACTER. Every wired-field
#   set became a set of letters ("wired=[a,i,n,r]"), so every devdoc field looked unwired and
#   the tool reported 20/20 UNBUILT on a provider that is 21/21 correct. Two lessons baked in:
#     1. Never index the result of a PS function that "returns an array" -- return a scalar,
#        or comma-guard the array (`,@(...)`) so it cannot unroll.
#     2. The built-side inventory printed under -Explain is what exposed this in one run.
#        A parser that cannot show its own intermediate state is indistinguishable from a
#        parser that is silently wrong -- which is the whole failure class this tool exists for.
function Get-CanonicalToken([string]$t) {
    $k = ($t -replace '[^A-Za-z0-9]','').ToLower()
    $k = $k -replace 'dh$',''       # DH-suffixed fieldIds are the same logical field
    $k = $k -replace 'cch$',''      # CCH-suffixed likewise
    return [string]$k
}
# Acceptable built tokens for a DEVDOC field name. Comma-guarded so it cannot unroll.
function Get-DevdocCandidates([string]$t) {
    $k = Get-CanonicalToken $t
    if ($fieldMap.ContainsKey($k)) { return ,@($fieldMap[$k]) }
    return ,@($k)
}
# ENTITY-PREFIXED fieldIds. A provider may scope a shared field name per entity/card so the two
# cards do not collide: CA_eSUN wires GunAge/GunNameLast/GunNameFirst on Firearm and
# VehBirthDate/VehNameLast/VehNameFirst on Vehicle. The devdoc calls those fields simply "Age",
# "Name", "BirthDate". Exact-token matching therefore declared them wired NOWHERE and reported four
# devdoc combinations as UNBUILT on a provider that builds all of them -- Rob spotted it as "a lot of
# those json look unbuilt", 2026-07-31. Same failure family as the dh$/cch$ suffix stripping already
# handled above, just on the front of the name.
# An explicit prefix list rather than a length-bounded wildcard: it is self-documenting, it cannot
# surprise on a future provider, and an unexpected prefix stays a visible FAIL instead of being
# silently swallowed.
$script:entityPrefixes = @('gun','veh','vehicle','boat','art','article','per','person','own','owner','subj','subject','dl','dr','oper')
function Test-TokenWired([string]$devTok, $wiredSet) {
    foreach ($cand in (Get-DevdocCandidates $devTok)) {
        foreach ($c1 in @($cand)) {
            $c = [string]$c1
            if ($wiredSet.Contains($c)) { return $true }
            foreach ($pfx in $script:entityPrefixes) { if ($wiredSet.Contains("$pfx$c")) { return $true } }
        }
    }
    return $false
}

# ── parse a devdoc text file into: query -> list of {Num, Mandatory[], Optional[], Raw} ──
function Get-DevdocCombinations([string]$txtPath) {
    $raw = [System.IO.File]::ReadAllLines($txtPath)

    # 1. the Basic Queries Supported list bounds which query sections are in scope
    $basic = @(); $inBasic = $false
    for ($i = 0; $i -lt $raw.Count; $i++) {
        if ($raw[$i] -match '^\s*Basic Quer(y|ies) Supported') { $inBasic = $true; continue }
        if ($inBasic) {
            if ($raw[$i] -match '^\s*([A-Z][A-Za-z0-9]*Query)\s*$') { $basic += $Matches[1] }
            # the list ends once a Field Name / Possible-Combinations block starts
            elseif ($raw[$i] -match '^\s*(Field Name|Possible Combinations)') { break }
        }
    }

    # 2. every "<Something>Query" heading line, in order, so we can attribute each
    #    Possible Combinations line to the section that owns it
    $heads = @()
    for ($i = 0; $i -lt $raw.Count; $i++) {
        # A query heading is the query name at the START of a line -- ALONE, or followed by the
        # field-table column headers on the SAME line. NJ_NJCJIS uses the second layout:
        #     'BoatQuery                      XML Tag Name         M/C/O    Size    Possible Values'
        # Requiring the name alone ($ anchor) meant NJ produced almost no headings, so every
        # "Possible Combinations" block had no OWNER and was skipped -- 2 of 11 blocks parsed, and
        # enforce PHASE 2p reported [PASS] over the other nine for months. The items themselves were
        # being glued correctly all along; the OWNER lookup was the failure.
        # Two-or-more spaces after the name is what distinguishes a column-header line from prose.
        if ($raw[$i] -match '^\s*([A-Z][A-Za-z0-9]*Query)\s*$' -or
            $raw[$i] -match '^\s*([A-Z][A-Za-z0-9]*Query)\s{2,}\S') {
            $heads += [pscustomobject]@{ Line = $i; Name = $Matches[1] }
        }
    }

    $out = @{}
    for ($i = 0; $i -lt $raw.Count; $i++) {
        if ($raw[$i] -notmatch 'Possible Combinations') { continue }
        $owner = $null
        foreach ($h in $heads) { if ($h.Line -lt $i) { $owner = $h.Name } else { break } }
        if (-not $owner) { continue }

        # the line often wraps; glue following lines until the next blank/heading
        $text = $raw[$i]
        $j = $i + 1
        while ($j -lt $raw.Count -and $raw[$j].Trim() -ne '' -and $raw[$j] -notmatch '^\s*[A-Z][A-Za-z0-9]*Query\s*$' -and $raw[$j] -notmatch 'Possible Combinations|^\s*Field Name') {
            $text += ' ' + $raw[$j]; $j++
        }
        $text = $text -replace '^.*?Possible Combinations\s*(\(fields within the square brackets are optional\))?\s*',''

        # split on "1." "2." ... numbered items
        $parts = [regex]::Split($text, '(?=(?<!\d)\d{1,2}\.\s)') | Where-Object { $_ -match '^\s*\d{1,2}\.\s' }
        $items = @()
        foreach ($p in $parts) {
            if ($p -notmatch '^\s*(\d{1,2})\.\s*(.*)$') { continue }
            $num = [int]$Matches[1]; $body = $Matches[2]
            $opt = @()
            # collect every [ ... ] bracket as optional, then strip them
            foreach ($m in [regex]::Matches($body, '\[([^\]]*)\]')) {
                $opt += ($m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
            $mandBody = ($body -replace '\[[^\]]*\]','')

            # UNCLOSED OPTIONAL BRACKET. The two regexes above require a CLOSING ']', and the
            # continuation-join a few lines up stops at a blank line or a page footer -- so when a
            # devdoc wraps its optional list mid-bracket, the ']' never makes it into $body and every
            # field inside the bracket was silently promoted to MANDATORY.
            # Real data (LA_LEMS, printed by this tool's own -Explain):
            #   "(In/Out) GunSerialNumber, Attention, [GunMake, GunModel, GunCaliber, ImageIndicator,"
            #   parsed as mand=[GunSerialNumber,Attention,GunModel,GunCaliber,ImageIndicator] opt=[]
            # which reported GunQuery #1 UNBUILT on a provider that builds it, and did the same to
            # DriverLicenseQuery #2 via "[ImageIndicator, State2, State3, State4,". FOUR false
            # UNBUILT FAILs on one provider. Rob flagged the symptom as "a lot of those json look
            # unbuilt", 2026-07-31.
            # Everything after an unmatched '[' is optional by construction -- a devdoc never REOPENS
            # a mandatory list after a bracket -- so take the tail as optionals and drop it from the
            # mandatory body. Truncation still loses the fields past the line break, which is honest:
            # they are absent, not misclassified.
            $openIdx = $mandBody.LastIndexOf('[')
            if ($openIdx -ge 0) {
                $tail = $mandBody.Substring($openIdx + 1)
                $opt += ($tail -split ',' | ForEach-Object { $_.Trim() } |
                         Where-Object { $_ -and $_ -match '^[A-Za-z][A-Za-z0-9 ]*$' })
                $mandBody = $mandBody.Substring(0, $openIdx)
            }
            $mandBody = $mandBody -replace '\((InState|OutofState|In/Out|In|Out)\)',''   # state qualifier, not a field
            $mand = @($mandBody -split ',' | ForEach-Object { $_.Trim() } |
                      Where-Object { $_ -and $_ -match '^[A-Za-z][A-Za-z0-9 ]*$' -and $_ -notmatch '^(and|or|at least one of|and/or)$' })
            # drop prose fragments ("and at least one of FBINumber", "Any optional fields")
            $mand = @($mand | Where-Object { $_ -notmatch '(?i)any optional|at least one of|legacy tag' })
            if ($mand.Count -or $opt.Count) {
                $items += [pscustomobject]@{ Num = $num; Mandatory = $mand; Optional = $opt; Raw = $body.Trim() }
            }
        }
        if ($items.Count) {
            if (-not $out.ContainsKey($owner)) { $out[$owner] = @() }
            $out[$owner] += ,$items
        }
    }

    # a query can have several Possible Combinations lines (field tables split across pages);
    # keep the FIRST block per query (the query's own table) -- later ones belong to sub-tables
    $flat = @{}
    foreach ($k in $out.Keys) { $flat[$k] = @($out[$k][0]) }
    return [pscustomobject]@{ Basic = $basic; Combos = $flat }
}

# ── per-provider audit ────────────────────────────────────────────────────────────────
function Invoke-One([string]$jsonPath, [string]$provName, [string]$provDir) {
    $fails = 0; $notes = 0

    $txt = Join-Path $provDir "source\${provName}_DEVDOC.txt"
    if (-not (Test-Path $txt)) {
        # variant fallback: a variant inherits its BASE devdoc (see CLAUDE.md Provider Variants)
        $baseGuess = ($provName -split '_')[0..1] -join '_'
        $alt = Join-Path $repoRoot "providers\$baseGuess\source\${baseGuess}_DEVDOC.txt"
        if (Test-Path $alt) { $txt = $alt }
        else {
            Emit "  [NOTE] $provName -- no devdoc text extract; cannot check (run pdftotext)" 'Yellow'
            return @{ Fail = 0; Note = 1 }
        }
    }

    $dd = Get-DevdocCombinations $txt
    if (-not $dd.Combos.Count) {
        Emit "  [FAIL] $provName -- devdoc found but NO 'Possible Combinations' line parsed; parser cannot see this devdoc's shape (do not read this as 'all covered')" 'Red'
        return @{ Fail = 1; Note = 0 }
    }

    $j = Get-Content $jsonPath -Raw | ConvertFrom-Json

    # built: query -> wired fields (set[] + any[]) and the list of set[] signatures
    $built = @{}
    foreach ($b in $j.bundles) {
        foreach ($c in $b.configurations) {
            if (-not $c.combinations) { continue }
            if ($c.name -match '^RMS' -or $c.name -match 'Results$') { continue }
            # QIDM name is "<PROVIDER>_<TransactionQuery>"; recover the query name
            $q = $c.name -replace "^$([regex]::Escape($provName))_",''
            if ($q -notmatch 'Query$') { continue }
            if (-not $built.ContainsKey($q)) {
                $built[$q] = [pscustomobject]@{ Wired = (New-Object 'System.Collections.Generic.HashSet[string]'); Sets = @() }
            }
            foreach ($cm in $c.combinations) {
                $s = @()
                foreach ($f in @($cm.requirements.set)) { if ($f) { $t2 = Get-CanonicalToken $f; $built[$q].Wired.Add($t2) | Out-Null; $s += $t2 } }
                foreach ($f in @($cm.requirements.any)) { if ($f) { $built[$q].Wired.Add((Get-CanonicalToken $f)) | Out-Null } }
                $built[$q].Sets += ,@($s | Sort-Object -Unique)
            }
        }
    }

    # PARSER HONESTY: never claim a field is "wired nowhere" without being able to show what
    # this tool believes is wired. An empty built-side inventory means the JSON walk is broken,
    # NOT that the provider is missing every path -- fail loudly on that instead of reporting
    # 20 false UNBUILTs (which is exactly what the first draft of this tool did).
    if (-not $built.Count) {
        Emit "  [FAIL] $provName -- built-side walk found NO query configurations; the JSON walk is broken, results would be meaningless" 'Red'
        return @{ Fail = 1; Note = 0 }
    }
    foreach ($q in ($built.Keys | Sort-Object)) {
        if ($built[$q].Wired.Count -eq 0) {
            Emit "  [FAIL] $provName -- built query '$q' parsed 0 wired fields; JSON walk is broken for it, not a coverage gap" 'Red'
            return @{ Fail = 1; Note = 0 }
        }
        if ($Explain) { Emit ("      built {0}: wired=[{1}]" -f $q, (($built[$q].Wired | Sort-Object) -join ',')) 'DarkGray' }
    }

    # accepted divergences: rule devdoc-combo-unbuilt
    $accepted = @()
    $accPath = Join-Path $provDir "docs\tracking\${provName}_ACCEPTED_DIVERGENCES.txt"
    if (Test-Path $accPath) {
        foreach ($l in (Get-Content $accPath)) {
            if ($l -match '^\s*#' -or -not $l.Trim()) { continue }
            $p = $l -split '\|'
            if ($p.Count -ge 4 -and $p[3].Trim() -eq 'devdoc-combo-unbuilt') {
                $accepted += [pscustomobject]@{ Query = $p[0].Trim(); Field = ($p[2].Trim().ToLower()) }
            }
        }
    }

    foreach ($q in ($dd.Combos.Keys | Sort-Object)) {
        # only queries we actually built are in scope; devdoc lists the whole TLETS catalogue
        if (-not $built.ContainsKey($q)) { continue }
        $wired = $built[$q].Wired
        foreach ($item in $dd.Combos[$q]) {
            if (-not $item.Mandatory.Count) { continue }
            $unwired = @($item.Mandatory | Where-Object { -not (Test-TokenWired $_ $wired) })
            if ($Explain) { Emit ("      devdoc {0} #{1}: mand=[{2}] opt=[{3}]" -f $q, $item.Num, ($item.Mandatory -join ','), ($item.Optional -join ',')) 'DarkGray' }

            if ($unwired.Count) {
                $ok = @($accepted | Where-Object { $_.Query -eq $q -and ($unwired | ForEach-Object { $_.ToLower() }) -contains $_.Field })
                if ($ok.Count) {
                    Emit ("  [NOTE] {0} -- {1} #{2} unbuilt, ACCEPTED divergence (unwired: {3})" -f $provName, $q, $item.Num, ($unwired -join ', ')) 'Yellow'
                    $notes++
                } else {
                    Emit ("  [FAIL] {0} -- {1} #{2} is devdoc-listed but UNBUILT: mandatory field(s) {3} wired nowhere in that query" -f $provName, $q, $item.Num, ($unwired -join ', ')) 'Red'
                    Emit ("           devdoc text: {0}" -f $item.Raw) 'DarkGray'
                    Emit ("           -> build it, or record it: accept_divergence.ps1 -Provider $provName (rule devdoc-combo-unbuilt, field $($unwired[0]))") 'DarkGray'
                    $fails++
                }
                continue
            }

            # every mandatory field is wired -- is there an exact set[] match?
            
            $exact = $false
            foreach ($s in $built[$q].Sets) {
                $covered = $true
                foreach ($m in $item.Mandatory) { if (-not (Test-TokenWired $m ([System.Collections.Generic.HashSet[string]]$s))) { $covered = $false; break } }
                if ($covered) { $exact = $true; break }
            }
            if (-not $exact) {
                Emit ("  [NOTE] {0} -- {1} #{2}: all fields wired but no single combo's set[] covers [{3}] (metadata may require more; human check)" -f $provName, $q, $item.Num, ($item.Mandatory -join ', ')) 'Yellow'
                $notes++
            }
        }
    }

    if (-not $fails -and -not $notes) { Emit "  [PASS] $provName -- every devdoc combination is built or accepted" 'Green' }
    elseif (-not $fails)              { Emit "  [PASS] $provName -- no unbuilt devdoc combination ($notes note(s))" 'Green' }
    return @{ Fail = $fails; Note = $notes }
}

# ── main ──────────────────────────────────────────────────────────────────────────────
Emit "" $null
Emit "================================================================" 'Cyan'
Emit "  DEVDOC COMBINATION COVERAGE (devdoc -> built)" 'Cyan'
Emit "================================================================" 'Cyan'

$targets = @()
if ($All -or -not $Path) {
    foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name)) {
        $jp = Get-ProviderRootJson -ProvDir $d.FullName -Provider $d.Name
        if ($jp) { $targets += [pscustomobject]@{ Json = $jp; Name = $d.Name; Dir = $d.FullName } }
    }
} else {
    $rp = (Resolve-Path $Path).Path
    $dir = Split-Path $rp -Parent
    $targets += [pscustomobject]@{ Json = $rp; Name = (Split-Path $dir -Leaf); Dir = $dir }
}

$tf = 0; $tn = 0
foreach ($t in $targets) {
    $r = Invoke-One $t.Json $t.Name $t.Dir
    $tf += $r.Fail; $tn += $r.Note
}

Emit "" $null
Emit "----------------------------------------------------------------" 'Cyan'
Emit "  RESULT: $tf FAIL / $tn NOTE" $(if ($tf) { 'Red' } else { 'Green' })
Emit "----------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
exit $(if ($tf) { 1 } else { 0 })
