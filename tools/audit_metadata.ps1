# audit_metadata.ps1
# Validates provider JSON QIDM configurations against authoritative XML metadata.
# The XML metadata is gospel -- if the XML says a query exists with certain fields
# and combinations, the JSON must implement it correctly.
#
# Usage:
#   .\audit_metadata.ps1                                     # Scan all providers
#   .\audit_metadata.ps1 -Path providers\IL_LEADS_OFML\IL_LEADS_OFML_BASE.json
#   .\audit_metadata.ps1 -Path providers\IL_LEADS_OFML\IL_LEADS_OFML_BASE.json -OutFile report.txt

param(
    [string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_metadata_keyref_match.ps1')
. (Join-Path $PSScriptRoot '_divergence_rules.ps1')

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
# If tools/ is directly under repo root, adjust
if (Test-Path (Join-Path $PSScriptRoot '..\providers')) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
} elseif (Test-Path (Join-Path $PSScriptRoot '..\..\providers')) {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

# Known form-only fields: present in QIDM but not in XML (expected, not a gap)
$formOnlyFields = @(
    'ImageIndicator', 'State', 'RegistrationState', 'Attention',
    'PurposeCode', 'CaRequestPurposeCode', 'RelatedHitSearchIndicator',
    'RandomRequest', 'ExpandedBirthDateSearchCode', 'ReasonCode',
    'ExpandedNameSearchCode', 'ExpandedBirthDateSearchIndicator',
    'dexStateUserId', 'InquiryLevel', 'FormORI', 'Requestor'
)

# Known field aliases — XML combo may reference one name, QIDM targetField uses the other
$fieldAliases = @{
    'CaRequestPurposeCode' = 'PurposeCode'
    'PurposeCode'          = 'CaRequestPurposeCode'
}

# Non-query transaction names to skip (admin, enter, clear, modify, etc.)
$nonQueryTypes = @('Administrative','Clear','Enter','Locate','Modify','Cancel')

# ── Output helpers ────────────────────────────────────────────────────────────
$lines = [System.Collections.Generic.List[string]]::new()
$script:passCount  = 0
$script:failCount  = 0
$script:warnCount  = 0
$script:totalProviders = 0

function Out-Line([string]$text) { $lines.Add($text) }
function Out-Pass([string]$msg)  { $lines.Add("  [PASS] $msg"); $script:passCount++ }
function Out-Fail([string]$msg)  { $lines.Add("  [FAIL] $msg"); $script:failCount++ }
function Out-Warn([string]$msg)  { $lines.Add("  [WARN] $msg"); $script:warnCount++ }
function Out-Info([string]$msg)  { }
# Out-Note: visible advisory that does NOT count as PASS/FAIL/WARN (won't break enforce 0-WARN gate)
function Out-Note([string]$msg)  { $lines.Add("  [NOTE] $msg") }

# ── Discover providers to audit ───────────────────────────────────────────────
$targets = @()

if ($Path) {
    # Single provider mode
    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Error "File not found: $Path"
        return
    }
    $targets += [PSCustomObject]@{ JsonPath = $resolved.Path }
} else {
    # Scan all providers
    $provDir = Join-Path $repoRoot 'providers'
    if (-not (Test-Path $provDir)) {
        Write-Error "Providers directory not found at $provDir"
        return
    }
    $folders = Get-ChildItem $provDir -Directory
    foreach ($folder in $folders) {
        $baseName = $folder.Name
        # Find _BASE.json (case-insensitive)
        $jsonCandidates = Get-ChildItem $folder.FullName -Filter '*_BASE.json' -File
        if ($jsonCandidates) {
            $targets += [PSCustomObject]@{ JsonPath = $jsonCandidates[0].FullName }
        }
    }
}

if ($targets.Count -eq 0) {
    Write-Host "No provider JSON files found to audit." -ForegroundColor Yellow
    return
}

# ── Helper: Parse XML requirements structure ──────────────────────────────────
function Get-XmlComboRequirements {
    param([System.Xml.XmlElement]$combo)

    $setFields = @()
    $anyFields = @()

    if ($combo.Requirements -and $combo.Requirements.Set) {
        $setNode = $combo.Requirements.Set
        foreach ($child in $setNode.ChildNodes) {
            if ($child.LocalName -eq 'Field') {
                $ref = $child.GetAttribute('reference')
                if (-not $ref) { $ref = $child.GetAttribute('name') }
                if ($ref) { $setFields += $ref }
            } elseif ($child.LocalName -eq 'Any') {
                foreach ($af in $child.ChildNodes) {
                    if ($af.LocalName -eq 'Field') {
                        $ref = $af.GetAttribute('reference')
                        if (-not $ref) { $ref = $af.GetAttribute('name') }
                        if ($ref) { $anyFields += $ref }
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        Set = $setFields
        Any = $anyFields
    }
}

# ── Helper: Check if two fields are equivalent (case-insensitive + aliases) ───
function Test-FieldEquiv {
    param([string]$a, [string]$b)
    if ($a -ieq $b) { return $true }
    if ($fieldAliases.ContainsKey($a) -and $fieldAliases[$a] -ieq $b) { return $true }
    return $false
}

# ── Helper: Case-insensitive field match ──────────────────────────────────────
function Test-FieldMatch {
    param(
        [string]$xmlField,
        [string[]]$jsonFields
    )
    foreach ($jf in $jsonFields) {
        if ($jf -ieq $xmlField) { return $true }
    }
    return $false
}

# ── Helper: Find matching JSON field for XML field (case-insensitive) ─────────
function Find-MatchingJsonField {
    param(
        [string]$xmlField,
        [string[]]$jsonFields
    )
    foreach ($jf in $jsonFields) {
        if ($jf -ieq $xmlField) { return $jf }
    }
    return $null
}

# ── Per-provider audit ────────────────────────────────────────────────────────
function Audit-Provider {
    param([string]$JsonPath)

    $jsonFile = [System.IO.Path]::GetFileNameWithoutExtension($JsonPath)
    # Derive provider name: strip versioned (_v<X.Y>) and legacy _BASE/_MC suffixes
    $providerName = $jsonFile -replace '_v[\d.]+$', '' -replace '(?i)_(BASE|MC)$', ''

    Out-Line ""
    Out-Line ("=" * 60)
    Out-Line " METADATA AUDIT: $providerName"
    Out-Line ("=" * 60)

    # ── Find XML metadata ─────────────────────────────────────────────────────
    $jsonDir = Split-Path $JsonPath -Parent
    $xmlPath = $null

    # Look for source/<PROVIDER>.xml — prefer exact provider name match
    $sourceDir = Join-Path $jsonDir 'source'
    if (Test-Path $sourceDir) {
        $xmlCandidates = Get-ChildItem $sourceDir -Filter '*.xml' -File |
            Where-Object { $_.Name -notmatch '(?i)\bold\b' }
        if ($xmlCandidates.Count -gt 0) {
            $exactMatch = $xmlCandidates | Where-Object { $_.BaseName -ieq $providerName }
            if ($exactMatch) {
                $xmlPath = @($exactMatch)[0].FullName
            } else {
                $xmlPath = $xmlCandidates[0].FullName
            }
        }
    }

    if (-not $xmlPath) {
        # Fallback: look in provider folder itself
        $xmlCandidates = Get-ChildItem $jsonDir -Filter '*.xml' -File |
            Where-Object { $_.Name -notmatch '(?i)\bold\b' }
        if ($xmlCandidates.Count -gt 0) {
            $exactMatch = $xmlCandidates | Where-Object { $_.BaseName -ieq $providerName }
            if ($exactMatch) {
                $xmlPath = @($exactMatch)[0].FullName
            } else {
                $xmlPath = $xmlCandidates[0].FullName
            }
        }
    }

    if (-not $xmlPath) {
        # VACUOUS PASS, CLOSED 2026-07-30. This used to Out-Line a [SKIP] and return, so the tool exited 0
        # with "Providers checked: 0 / 0 PASS / 0 FAIL" -- indistinguishable from a clean audit to
        # enforce PHASE 2b, which reads the report. A gate asked to audit a provider and unable to
        # find that provider's authority document has NOT passed; it has failed to run.
        Out-Fail "  No XML metadata found for $providerName -- this audit CANNOT run, and a tool that cannot run has not PASSED. Expected source\$providerName.xml (variants inherit their base's; see CLAUDE.md Provider Variants)"
        Out-Line ""
        return
    }

    Out-Line "  XML: $(Split-Path $xmlPath -Leaf)"
    Out-Line "  JSON: $(Split-Path $JsonPath -Leaf)"

    # ── Parse XML ─────────────────────────────────────────────────────────────
    try {
        [xml]$xml = Get-Content $xmlPath -Raw -Encoding UTF8
    } catch {
        Out-Fail "XML parse error: $_"
        return
    }

    # Navigate XML structure: InterfaceSchema > States > State > Systems > System > Transactions
    $system = $null
    try {
        $system = $xml.InterfaceSchema.States.State.Systems.System
    } catch { }

    if (-not $system) {
        Out-Fail "Could not find System element in XML"
        return
    }

    $xmlTransactions = @()
    if ($system.Transactions -and $system.Transactions.Transaction) {
        $xmlTransactions = @($system.Transactions.Transaction)
    }

    # Filter to query transactions (name ends with Query)
    $xmlQueryTxns = @()
    foreach ($txn in $xmlTransactions) {
        # Include transactions ending in Query or Inquiry (e.g. AZ WMPIMissingPersonInquiry)
        if ($txn.name -match '(Query|Inquiry)$') {
            $xmlQueryTxns += $txn
        }
    }

    # Also check MessageKeys for transactionType/type = Inquiry to identify basic queries
    $inquiryMsgKeys = @{}
    $msgKeys = $null
    try {
        $msgKeys = $system.MessageKeys.MessageKey
    } catch { }
    if ($msgKeys) {
        foreach ($mk in @($msgKeys)) {
            $mkType = $mk.type
            if (-not $mkType) {
                try { $mkType = $mk.GetAttribute('type') } catch { }
            }
            if ($mkType -ieq 'Inquiry') {
                $mkName = $mk.name
                if (-not $mkName) {
                    try { $mkName = $mk.GetAttribute('name') } catch { }
                }
                if ($mkName) { $inquiryMsgKeys[$mkName] = $true }
            }
        }
    }

    # ── Parse JSON ────────────────────────────────────────────────────────────
    try {
        $raw = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8)
        $json = $raw | ConvertFrom-Json
    } catch {
        Out-Fail "JSON parse error: $_"
        return
    }

    # Extract CommSys QIDMs (skip RMS)
    $qidms = @()
    foreach ($bundle in $json.bundles) {
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -eq 'QUERYINPUTDATAMAPPING' -and
                $cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
                $qidms += $cfg
            }
        }
    }

    # Extract QIF form fields (for CHECK 5 maxLength)
    $qifFields = @{}  # key = fieldId (lowercase), value = @{ maxLength; fieldId }
    foreach ($bundle in $json.bundles) {
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
            $cfgText = $cfg | ConvertTo-Json -Depth 100 -Compress
            # Extract fieldId and maxLength pairs
            $fieldMatches = [regex]::Matches($cfgText, '"fieldId"\s*:\s*"([^"]+)"')
            $maxLenMatches = @{}
            # Parse node-by-node for accurate fieldId -> maxLength mapping
            $layoutVariant = $null
            try { $layoutVariant = $cfg.layout.default } catch { }
            if (-not $layoutVariant) { continue }

            foreach ($prop in $layoutVariant.PSObject.Properties) {
                $node = $prop.Value
                if (-not $node -or -not $node.props) { continue }
                $fid = $null
                $ml = $null
                try { $fid = $node.props.fieldId } catch { }
                try { $ml = $node.props.maxLength } catch { }
                if ($fid -and $ml) {
                    # ENTITY-SCOPED KEY as well as the bare one. A fieldId is only unique WITHIN a
                    # QIF: CA_eSUN and OR_LEDS both name the control 'serialNumber' on Firearm AND on
                    # Article, with legitimately different sizes (Firearm 14/11 = GunSerialNumber,
                    # Article 20 = ArticleSerialNumber). A bare-fieldId index kept whichever came
                    # last, so checking GunQuery compared the ARTICLE control against GunQuery's XML
                    # and reported "QIF maxLength 20 > XML maxLength 14 -- server may reject" on two
                    # providers whose controls are both exactly right. Verified against the artifacts
                    # before changing the tool (usx-tooling Step 5b) -- the mirror case on
                    # CA_SAN_LUIS_OBISPO looked identical and there the BUILD was wrong.
                    # Bare key retained so any lookup that cannot supply an entity still resolves.
                    $qifFields[$fid.ToLower()] = @{ fieldId = $fid; maxLength = $ml }
                    $ent = "$($cfg.targetEntity)"
                    if ($ent) { $qifFields["$($ent.ToLower())|$($fid.ToLower())"] = @{ fieldId = $fid; maxLength = $ml } }
                }
            }
        }
    }

    # ── Metadata-divergence gate: source map, defaulted tokens, registry ────────
    # Used by CHECK 4 demote classification and CHECK 4d defaulted-in-set gate.
    $sourceToTargetG = @{}
    foreach ($q in $qidms) {
        if (-not $q.attributes) { continue }
        foreach ($attr in @($q.attributes)) {
            if ($attr.sourceField -and $attr.targetField) {
                foreach ($sf in @($attr.sourceField)) { $sourceToTargetG[([string]$sf).ToLower()] = [string]$attr.targetField }
            }
        }
    }

    # Defaulted fields: QIF initialValue OR combo defaults[]. Platform rule
    # (initialValue-not-counted-for-set) => a defaulted field MUST live in any[].
    # Store lowercased; add both the raw token and its mapped targetField so that
    # set-field (sourceField) and XML (targetField) names both resolve.
    $defaultedTokens = @{}
    function Add-Defaulted([string]$tok) {
        if (-not $tok) { return }
        $t = $tok.ToLower()
        $defaultedTokens[$t] = $true
        if ($sourceToTargetG.ContainsKey($t)) { $defaultedTokens[$sourceToTargetG[$t].ToLower()] = $true }
        if ($fieldAliases.ContainsKey($tok)) { $defaultedTokens[([string]$fieldAliases[$tok]).ToLower()] = $true }
    }
    foreach ($bundle in $json.bundles) {
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
            $lv = $null; try { $lv = $cfg.layout.default } catch { }
            if (-not $lv) { continue }
            foreach ($prop in $lv.PSObject.Properties) {
                $node = $prop.Value
                if (-not $node -or -not $node.props) { continue }
                $fid = $null; $iv = $null
                try { $fid = $node.props.fieldId } catch { }
                try { $iv = $node.props.initialValue } catch { }
                if ($fid -and $null -ne $iv -and "$iv".Trim() -ne '') { Add-Defaulted ([string]$fid) }
            }
        }
    }
    foreach ($q in $qidms) {
        if (-not $q.combinations) { continue }
        foreach ($c in @($q.combinations)) {
            if (-not $c.defaults) { continue }
            foreach ($d in @($c.defaults)) {
                $df = $null; try { $df = $d.field } catch { }
                if ($df) { Add-Defaulted ([string]$df) }
            }
        }
    }
    function Test-IsDefaulted([string]$tok) {
        if (-not $tok) { return $false }
        $t = $tok.ToLower()
        if ($defaultedTokens.ContainsKey($t)) { return $true }
        if ($sourceToTargetG.ContainsKey($t) -and $defaultedTokens.ContainsKey($sourceToTargetG[$t].ToLower())) { return $true }
        return $false
    }

    # Per-provider ACCEPTED-DIVERGENCE registry (learning mechanism). Lines:
    #   query | keyRef | field | rule | reason | source | date    (# = comment)
    $acceptedDiv = @{}
    # docs/ reorg (2026-07-01): ACCEPTED_DIVERGENCES is a "tracking" category doc for migrated
    # providers (docs/tracking/), flat docs/ for the rest. Check tracking/ first, then fall back.
    $acceptedDivFile = Join-Path $jsonDir ("docs\tracking\{0}_ACCEPTED_DIVERGENCES.txt" -f $providerName)
    if (-not (Test-Path $acceptedDivFile)) {
        $acceptedDivFile = Join-Path $jsonDir ("docs\{0}_ACCEPTED_DIVERGENCES.txt" -f $providerName)
    }
    if (Test-Path $acceptedDivFile) {
        foreach ($ln in (Get-Content $acceptedDivFile)) {
            $s = $ln.Trim()
            if (-not $s -or $s.StartsWith('#')) { continue }
            $parts = $s -split '\|'
            if ($parts.Count -ge 3) {
                $k = ('{0}|{1}|{2}' -f $parts[0].Trim(), $parts[1].Trim(), $parts[2].Trim()).ToLower()
                # KEEP THE RULE. It used to be discarded, which made every suppression
                # DIRECTION-BLIND: registering "regionId may ride in RQ{VIN} any[]" (rule
                # promoted-to-any) also silenced CHECK 4d, whose defect is the OPPOSITE -- a field
                # wrongly PROMOTED INTO set[]. Measured 2026-07-30: audit_gate_efficacy flipped
                # promote-any-to-set from KILLED to SURVIVED the moment 4 legitimate
                # promoted-to-any rows were added. Every accepted divergence was silently buying a
                # wider blind spot than it was granted.
                if (-not $acceptedDiv.ContainsKey($k)) { $acceptedDiv[$k] = @() }
                $acceptedDiv[$k] += $(if ($parts.Count -ge 4) { $parts[3].Trim().ToLower() } else { '' })
            }
        }
    }
    # DIRECTION-AWARE SUPPRESSION (2026-07-30). -AcceptClass names the rule class(es) that can
    # legitimately license the CALLING check's defect class; a row of any other class no longer
    # silences it. Classes come from _divergence_rules.ps1 so this enforcer and
    # audit_suppression_scope.ps1 (the measurer) can never disagree about what a rule name means.
    #
    # GATED PER PROVIDER by the '# SUPPRESSION-SCOPE: direction-aware' marker in that provider's
    # registry. Narrowing is stricter than legacy behaviour, so it can turn a GREEN provider RED
    # when a real finding stops being silenced -- a release decision, one provider at a time.
    # Without the marker, behaviour is exactly as before: location match alone suppresses.
    $dirAware = Test-DirectionAwareOptIn $acceptedDivFile
    function Test-AllowListed([string]$q, [string]$kr, [string]$field, [string[]]$AcceptClass) {
        $k = ('{0}|{1}|{2}' -f $q, $kr, $field).ToLower()
        if (-not $acceptedDiv.ContainsKey($k)) { return $false }
        if (-not $script:dirAware -or -not $AcceptClass) { return $true }
        foreach ($r in @($acceptedDiv[$k])) {
            if ($AcceptClass -contains (Get-DivergenceRuleClass $r)) { return $true }
        }
        return $false
    }
    $script:dirAware = $dirAware

    # Same ACCEPTED_DIVERGENCES file, different rule namespace ('built-as'/'not-built' vs.
    # the field-level rules above) -- shared with extract_metadata_reference.ps1's BUILD
    # COVERAGE via _metadata_keyref_match.ps1. See that module's header for why.
    $keyRefDeclarations = Get-KeyRefDeclarations -JsonDir $jsonDir -ProviderName $providerName

    # Per-query metadata SET-union / ANY-union (XML field tokens, lowercased) for the
    # promote gate (CHECK 4d). A field metadata has in ANY but the build puts in SET[]
    # is an over-promotion (the DQN v4.0 bug class). A field metadata ALSO has in SET[]
    # (PlateType/Year, VehicleTypeCode) is correct and must NOT be flagged.
    $metaSetUnion = @{}   # query(lower) -> @{ token = $true } present in any metadata SET
    $metaAnyUnion = @{}   # query(lower) -> @{ token = $true } present in any metadata ANY
    # PER-COMBINATION index, keyed by the METADATA keyReference. The unions above are query-wide,
    # which is correct for CHECK 4d (over-promotion) but WRONG for 4e (demotion): a field that is
    # set[]-mandatory in ONE combination is not thereby mandatory in its SIBLINGS. Without this,
    # adding a devdoc-optional field to combo B's any[] is misreported as demoting combo A's
    # requirement -- it produced exactly 2 false FAILs on TX_TLETS v4.18 (FinancialResponsibilityType
    # added to DPSI any[] read as demoting REG's set[]; BirthDate added to CPL any[] read as demoting
    # DQ's). Same keyRef-scoping bug BUILD_RULES 13 documents, in a new place.
    $metaSetByKeyRef = @{}   # query(lower) -> metaKeyRef(lower) -> @{ token = $true }
    foreach ($txn in $xmlQueryTxns) {
        $qkey = ([string]$txn.name).ToLower()
        if (-not $metaSetUnion.ContainsKey($qkey)) { $metaSetUnion[$qkey] = @{}; $metaAnyUnion[$qkey] = @{} }
        if (-not $metaSetByKeyRef.ContainsKey($qkey)) { $metaSetByKeyRef[$qkey] = @{} }
        $xc = $null; try { $xc = @($txn.Combinations.Combination) } catch { }
        foreach ($cmb in $xc) {
            if (-not $cmb) { continue }
            $r = Get-XmlComboRequirements $cmb
            foreach ($f in @($r.Set)) { if ($f) { $metaSetUnion[$qkey][([string]$f).ToLower()] = $true } }
            foreach ($f in @($r.Any)) { if ($f) { $metaAnyUnion[$qkey][([string]$f).ToLower()] = $true } }
            $mkr = ''
            try { $mkr = ([string]$cmb.keyReference).ToLower() } catch { }
            if ($mkr) {
                if (-not $metaSetByKeyRef[$qkey].ContainsKey($mkr)) { $metaSetByKeyRef[$qkey][$mkr] = @{} }
                foreach ($f in @($r.Set)) { if ($f) { $metaSetByKeyRef[$qkey][$mkr][([string]$f).ToLower()] = $true } }
            }
        }
    }
    function Resolve-MetaToken([string]$jsf) {
        $t = $jsf.ToLower()
        if ($sourceToTargetG.ContainsKey($t)) { return $sourceToTargetG[$t].ToLower() }
        return $t
    }
    function Test-InMetaSet([string]$query, [string]$jsf) {
        $qk = $query.ToLower(); if (-not $metaSetUnion.ContainsKey($qk)) { return $false }
        return ($metaSetUnion[$qk].ContainsKey((Resolve-MetaToken $jsf)) -or $metaSetUnion[$qk].ContainsKey($jsf.ToLower()))
    }
    function Test-InMetaAny([string]$query, [string]$jsf) {
        $qk = $query.ToLower(); if (-not $metaAnyUnion.ContainsKey($qk)) { return $false }
        return ($metaAnyUnion[$qk].ContainsKey((Resolve-MetaToken $jsf)) -or $metaAnyUnion[$qk].ContainsKey($jsf.ToLower()))
    }

    # Build lookup: query name -> QIDM config(s)
    $qidmByQuery = @{}
    foreach ($q in $qidms) {
        $qName = $q.query
        if (-not $qidmByQuery.ContainsKey($qName)) {
            $qidmByQuery[$qName] = @()
        }
        $qidmByQuery[$qName] += $q
    }

    # Build unique XML query names
    $xmlQueryNames = @{}
    foreach ($txn in $xmlQueryTxns) {
        $xmlQueryNames[$txn.name] = $txn
    }

    $jsonQueryNames = @{}
    foreach ($q in $qidms) {
        $jsonQueryNames[$q.query] = $true
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 1: Query Coverage
    #
    # INVESTIGATED 2026-07-06: this check's XML-vs-JSON query coverage overlaps
    # conceptually with <PROVIDER>_METADATA_REFERENCE.txt's "BUILD COVERAGE" section
    # (per-keyRef BUILT/UNBUILT + summary table) -- a prior cleanup pass flagged it as
    # possible duplication to trim. Left unchanged on inspection: every line below is an
    # Out-Pass/Out-Fail call, and the print IS the count -- $script:passCount++ /
    # $script:failCount++ happen in the same statement as the Write-Host text (see the
    # Out-Pass/Out-Fail function defs above). The Out-Fail path here ("in JSON but NOT in
    # XML") is exactly the [FAIL] count enforce.ps1 Phase 2b greps out of this report
    # (`$mdFails = ([regex]::Matches($mdText, '\[FAIL\]')).Count`). Trimming any printed
    # line would change that FAIL count (or the PASS count), i.e. it is not "purely
    # printed diagnostic text" -- it's the gate itself. Do not trim without re-deriving
    # the FAIL/PASS computation independently of the print first.
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 1: Query Coverage ---"

    # Queries in XML
    $xmlNames = @($xmlQueryNames.Keys) | Sort-Object
    $jsonNames = @($jsonQueryNames.Keys) | Sort-Object

    foreach ($name in $xmlNames) {
        if ($jsonQueryNames.ContainsKey($name)) {
            Out-Pass "$name`: in XML and JSON"
        } else {
            Out-Info "$name`: in XML but not in JSON (devdoc determines which queries to build)"
        }
    }

    foreach ($name in $jsonNames) {
        if (-not $xmlQueryNames.ContainsKey($name)) {
            Out-Fail "$name`: in JSON but NOT in XML (invalid query)"
        }
    }

    if ($xmlNames.Count -eq 0 -and $jsonNames.Count -eq 0) {
        Out-Info "No query transactions found in XML or JSON"
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 2: KeyReference Validation
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 2: KeyReference Validation ---"

    # Build set of all XML keyRefs per query
    $xmlKeyRefsByQuery = @{}  # queryName -> set of keyRefs
    $allXmlKeyRefs = @{}      # keyRef -> queryName
    foreach ($txn in $xmlQueryTxns) {
        $qName = $txn.name
        $keyRefs = [System.Collections.Generic.HashSet[string]]::new()
        if ($txn.Combinations -and $txn.Combinations.Combination) {
            foreach ($combo in @($txn.Combinations.Combination)) {
                $kr = $combo.keyReference
                if (-not $kr) {
                    try { $kr = $combo.GetAttribute('keyReference') } catch { }
                }
                if ($kr) {
                    [void]$keyRefs.Add($kr)
                    $allXmlKeyRefs[$kr] = $qName
                }
            }
        }
        $xmlKeyRefsByQuery[$qName] = $keyRefs
    }

    # Check each JSON combo's keyRef against XML
    $jsonKeyRefsSeen = @{}  # keyRef -> queryName
    foreach ($q in $qidms) {
        $qName = $q.query
        if (-not $q.combinations) { continue }
        foreach ($combo in @($q.combinations)) {
            $kr = $combo.keyReference
            if (-not $kr) { continue }
            $jsonKeyRefsSeen[$kr] = $qName

            # Check if this keyRef exists in XML for this query
            $foundInQuery = $false
            $foundAnywhere = $false

            if ($xmlKeyRefsByQuery.ContainsKey($qName)) {
                if ($xmlKeyRefsByQuery[$qName].Contains($kr)) {
                    $foundInQuery = $true
                }
            }
            if ($allXmlKeyRefs.ContainsKey($kr)) {
                $foundAnywhere = $true
            }

            if ($foundInQuery) {
                Out-Pass "${kr}: exists in XML $qName"
            } elseif ($foundAnywhere) {
                Out-Warn "${kr}: exists in XML $($allXmlKeyRefs[$kr]) but JSON maps it to $qName"
            } else {
                Out-Info "${kr}: invented keyRef (not in XML) -- acceptable"
            }
        }
    }

    # XML keyRefs not in any JSON combo — check for invented variants
    foreach ($kr in $allXmlKeyRefs.Keys | Sort-Object) {
        if (-not $jsonKeyRefsSeen.ContainsKey($kr)) {
            $qName = $allXmlKeyRefs[$kr]
            # Find all JSON keyRefs for the same query that are NOT in XML (= invented)
            $variants = @()
            foreach ($jkr in $jsonKeyRefsSeen.Keys) {
                if ($jsonKeyRefsSeen[$jkr] -ieq $qName -and -not $allXmlKeyRefs.ContainsKey($jkr)) {
                    $variants += $jkr
                }
            }
            if ($variants.Count -gt 0) {
                $varList = ($variants | Sort-Object) -join ','
                Out-Info "${kr}: XML keyRef ($qName) replaced by invented variants ($varList)"
            } else {
                Out-Info "${kr}: XML keyRef ($qName) not used in any JSON combo"
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 3: Field Coverage
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 3: Field Coverage ---"

    foreach ($txn in $xmlQueryTxns) {
        $qName = $txn.name

        # Collect XML field names
        $xmlFields = @()
        if ($txn.Fields -and $txn.Fields.Field) {
            foreach ($f in @($txn.Fields.Field)) {
                $fname = $f.name
                if (-not $fname) {
                    try { $fname = $f.GetAttribute('name') } catch { }
                }
                if ($fname) { $xmlFields += $fname }
            }
        }

        if ($xmlFields.Count -eq 0) { continue }

        # Collect JSON QIDM sourceFields and targetFields for this query
        $jsonSourceFields = @()
        $jsonTargetFields = @()
        if ($qidmByQuery.ContainsKey($qName)) {
            foreach ($qidm in $qidmByQuery[$qName]) {
                if ($qidm.attributes) {
                    foreach ($attr in @($qidm.attributes)) {
                        if ($attr.sourceField) {
                            foreach ($sf in @($attr.sourceField)) {
                                $jsonSourceFields += $sf
                            }
                        }
                        if ($attr.targetField) {
                            $jsonTargetFields += $attr.targetField
                        }
                    }
                }
            }
        } else {
            Out-Line "  $qName`: (not built in JSON -- see CHECK 1)"
            continue
        }

        # Deduplicate
        $jsonSourceFieldsUniq = $jsonSourceFields | Select-Object -Unique
        $jsonTargetFieldsUniq = $jsonTargetFields | Select-Object -Unique
        $allJsonFields = @($jsonSourceFieldsUniq) + @($jsonTargetFieldsUniq) | Select-Object -Unique

        Out-Line "  ${qName}:"

        # XML fields vs JSON
        foreach ($xf in ($xmlFields | Sort-Object)) {
            $inSource = Test-FieldMatch -xmlField $xf -jsonFields $jsonSourceFieldsUniq
            $inTarget = Test-FieldMatch -xmlField $xf -jsonFields $jsonTargetFieldsUniq

            if ($inSource -or $inTarget) {
                Out-Pass "  $xf`: in XML and QIDM"
            } else {
                # Check if it's a known form-only that appears with different casing
                $isFormOnly = $false
                foreach ($fo in $formOnlyFields) {
                    if ($fo -ieq $xf) { $isFormOnly = $true; break }
                }
                if ($isFormOnly) {
                    Out-Info "  $xf`: in XML only (form-only pattern -- expected)"
                } else {
                    # Field in XML but not in QIDM — only a problem if required by a combo (caught by CHECK 4/5)
                    Out-Info "  $xf`: in XML but not in QIDM (CHECK 4/5 validates if required)"
                }
            }
        }

        # JSON sourceFields not in XML (form-only fields)
        foreach ($jf in ($jsonSourceFieldsUniq | Sort-Object)) {
            $inXml = Test-FieldMatch -xmlField $jf -jsonFields $xmlFields
            if (-not $inXml) {
                $isFormOnly = $false
                foreach ($fo in $formOnlyFields) {
                    if ($fo -ieq $jf) { $isFormOnly = $true; break }
                }
                if ($isFormOnly) {
                    Out-Info "  $jf`: in QIDM only (form-only field)"
                } else {
                    # Check if this sourceField is part of a composite mapping (e.g. nameFirst → Name via FormatStringRuleHandler)
                    $compositeTarget = $null
                    foreach ($qidm in $qidmByQuery[$qName]) {
                        if (-not $qidm.attributes) { continue }
                        foreach ($attr in @($qidm.attributes)) {
                            if ($attr.sourceField -and $attr.targetField -and $attr.rule -and $attr.rule -imatch 'FormatString') {
                                $sfList = @($attr.sourceField)
                                foreach ($sf in $sfList) {
                                    if ($sf -ieq $jf) {
                                        $tgtInXml = Test-FieldMatch -xmlField $attr.targetField -jsonFields $xmlFields
                                        if ($tgtInXml) { $compositeTarget = $attr.targetField }
                                        break
                                    }
                                }
                            }
                            if ($compositeTarget) { break }
                        }
                        if ($compositeTarget) { break }
                    }
                    if ($compositeTarget) {
                        Out-Info "  $jf`: composite sourceField for $compositeTarget (FormatStringRuleHandler)"
                    } else {
                        Out-Info "  $jf`: in QIDM sourceField but not in XML"
                    }
                }
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 4: Combination Field Requirements
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 4: Combination Field Requirements ---"

    foreach ($txn in $xmlQueryTxns) {
        $qName = $txn.name
        if (-not $qidmByQuery.ContainsKey($qName)) { continue }
        if (-not $txn.Combinations -or -not $txn.Combinations.Combination) { continue }

        $xmlCombos = @($txn.Combinations.Combination)
        $jsonQidms = $qidmByQuery[$qName]

        # Full list of this query's built JSON keyRefs -- needed by the shared matcher
        # (Resolve-XmlKeyRefBuild) below, both for its mechanical fallback and to confirm a
        # declared "built-as" target still actually exists.
        $jsonKeyRefsForQuery = @()
        foreach ($qidm in $jsonQidms) {
            if (-not $qidm.combinations) { continue }
            foreach ($jc in @($qidm.combinations)) {
                if ($jc.keyReference) { $jsonKeyRefsForQuery += $jc.keyReference }
            }
        }

        Out-Line "  ${qName}:"

        foreach ($xmlCombo in $xmlCombos) {
            $kr = $xmlCombo.keyReference
            if (-not $kr) {
                try { $kr = $xmlCombo.GetAttribute('keyReference') } catch { $kr = '(unknown)' }
            }
            $pfr = $xmlCombo.primaryFieldReference
            if (-not $pfr) {
                try { $pfr = $xmlCombo.GetAttribute('primaryFieldReference') } catch { $pfr = '' }
            }

            $reqs = Get-XmlComboRequirements -combo $xmlCombo
            $xmlSetFields = $reqs.Set
            $xmlAnyFields = $reqs.Any

            # Find matching JSON combo(s) by keyRef
            $matchingJsonCombos = @()
            foreach ($qidm in $jsonQidms) {
                if (-not $qidm.combinations) { continue }
                foreach ($jc in @($qidm.combinations)) {
                    if ($jc.keyReference -ieq $kr) {
                        $matchingJsonCombos += $jc
                    }
                }
            }

            # NARROW BY primaryFieldReference -- A KEYREF IS NOT A VARIANT.
            # Matching on keyRef alone compares an XML variant against a JSON combo that implements a
            # DIFFERENT variant of the same keyRef, and then reports the other variant's mandatory
            # fields as "missing from JSON set[]". Every one of LA_LEMS's 6 WARNs was this: metadata
            # has BQ{Hull} + BQ{Reg}, QB{Hull} + QB{Reg}, DQ{Name} + DQ{OLN}, QWDN{Name} + QWDN{OLN},
            # the build implements one variant of each exactly, and the union comparison declared the
            # sibling's key field missing. audit_requirement_fidelity -- which IS per-combination --
            # reported 0 UNDER / 0 OVER on the same provider, which is what proved the build right.
            # Prefer same-PF combos; if none matches AND this keyRef has several XML variants, this
            # variant simply is not built, so fall through to the not-built resolver below. That path
            # carries a HARD INVARIANT never to emit Out-Fail/Out-Warn and already takes $pfr into
            # account, so this cannot manufacture a new failure -- it can only stop a false one.
            if ($pfr -and $matchingJsonCombos.Count -gt 0) {
                $canonPf = (("$pfr" -replace '[^A-Za-z0-9]','').ToLower() -replace 'dh$','') -replace 'cch$',''
                $samePf = @($matchingJsonCombos | Where-Object {
                    $p = "$($_.primaryFieldReference)"
                    $p -and ((("$p" -replace '[^A-Za-z0-9]','').ToLower() -replace 'dh$','') -replace 'cch$','') -eq $canonPf
                })
                if ($samePf.Count) {
                    $matchingJsonCombos = @($samePf)
                } else {
                    $xmlVariantsForKr = @($xmlCombos | Where-Object {
                        $k2 = $_.keyReference; if (-not $k2) { try { $k2 = $_.GetAttribute('keyReference') } catch { $k2 = '' } }
                        $k2 -ieq $kr
                    })
                    if ($xmlVariantsForKr.Count -gt 1) { $matchingJsonCombos = @() }
                }
            }

            if ($matchingJsonCombos.Count -eq 0) {
                # Matching delegated to _metadata_keyref_match.ps1 (shared with
                # extract_metadata_reference.ps1's BUILD COVERAGE) -- declaration-first
                # (ACCEPTED_DIVERGENCES built-as/not-built), mechanical keyRef/dotted-base/
                # synthetic-suffix rule as the fallback. Replaces the old per-query POOLED
                # field-overlap heuristic (2026-07-06), which produced false [PASS] "covered by
                # invented variants" verdicts for keyRefs that are genuinely not built but happen
                # to share field names with an unrelated sibling combo (FL_FCIC QV/QW were the
                # confirmed case, root-caused by reconciling against <PROVIDER>_METADATA_
                # REFERENCE.txt, which correctly showed them as UNBUILT).
                #
                # HARD INVARIANT: this block must never call Out-Fail/Out-Warn. An unmatched or
                # not-built XML keyRef is reported via Out-Pass/Out-Info/Out-Note only -- exactly
                # like the code it replaces -- so enforce.ps1's Phase 2b [FAIL]-count gate cannot
                # regress from this change (verified: this block contained zero Out-Fail/Out-Warn
                # before this refactor too).
                $resolved = Resolve-XmlKeyRefBuild -XmlKeyRef $kr -XmlPrimaryField $pfr `
                    -Query $qName -BuiltKeyRefs $jsonKeyRefsForQuery -Declarations $keyRefDeclarations

                if ($resolved.Status -eq 'not-built') {
                    if ($resolved.Source -eq 'declaration') {
                        Out-Note "  keyRef ${kr}: not built -- ACCEPTED per registry (see docs ACCEPTED_DIVERGENCES)"
                    } else {
                        Out-Info "  keyRef ${kr}: no matching built combo (no exact keyRef, dotted-variant, or keyRef+primaryField match)"
                    }
                    continue
                }

                # Built (via declaration or the mechanical rule): validate the XML combo's
                # fields against ONLY the specific matched JSON combo(s) -- not the whole query's
                # pool -- so a field that coincidentally appears on an unrelated sibling combo can
                # no longer produce a false [PASS].
                $matchedCombos = @()
                foreach ($qidm in $jsonQidms) {
                    if (-not $qidm.combinations) { continue }
                    foreach ($jc in @($qidm.combinations)) {
                        if ($jc.keyReference -and ($resolved.Matches -icontains $jc.keyReference)) {
                            $matchedCombos += $jc
                        }
                    }
                }

                # Build sourceField→targetField map for field resolution
                $src2tgt = @{}
                foreach ($qidm in $jsonQidms) {
                    if (-not $qidm.attributes) { continue }
                    foreach ($attr in @($qidm.attributes)) {
                        if ($attr.sourceField -and $attr.targetField) {
                            foreach ($sf in @($attr.sourceField)) {
                                $src2tgt[$sf.ToLower()] = $attr.targetField
                            }
                        }
                    }
                }

                # Collect set[] and any[] fields across the matched combo(s) only
                $matchedSet = @()
                $matchedAny = @()
                foreach ($mc in $matchedCombos) {
                    if ($mc.requirements) {
                        if ($mc.requirements.set) { $matchedSet += @($mc.requirements.set) }
                        if ($mc.requirements.any) { $matchedAny += @($mc.requirements.any) }
                    }
                }
                $matchedFields = @($matchedSet) + @($matchedAny) | Select-Object -Unique
                $matchedNames = ($resolved.Matches) -join ','

                # Validate XML set[] fields against the matched combo(s)
                foreach ($xsf in $xmlSetFields) {
                    $found = $false
                    foreach ($isf in $matchedFields) {
                        if ($isf -ieq $xsf) { $found = $true; break }
                        if ($src2tgt.ContainsKey($isf.ToLower())) {
                            if (Test-FieldEquiv $src2tgt[$isf.ToLower()] $xsf) { $found = $true; break }
                        }
                    }
                    if ($found) {
                        Out-Pass "  keyRef ${kr}: set field '$xsf' covered by ${matchedNames}"
                    } else {
                        $inMatchedAny = $false
                        foreach ($isf in $matchedAny) {
                            if ($isf -ieq $xsf) { $inMatchedAny = $true; break }
                            if ($src2tgt.ContainsKey($isf.ToLower())) {
                                if (Test-FieldEquiv $src2tgt[$isf.ToLower()] $xsf) { $inMatchedAny = $true; break }
                            }
                        }
                        if ($inMatchedAny) {
                            Out-Info "  keyRef ${kr}: XML set field '$xsf' demoted to any[] in ${matchedNames}"
                        } else {
                            # INFO not WARN: matched combo(s) exist but don't cover this field path.
                            # CHECK 5 (Primary Field Coverage) already catches missing primary paths as FAIL/WARN.
                            Out-Info "  keyRef ${kr}: XML set field '$xsf' not covered by ${matchedNames} -- intentional exclusion, see CHECK 5"
                        }
                    }
                }

                # Validate XML any[] fields against the matched combo(s)
                foreach ($xaf in $xmlAnyFields) {
                    $found = $false
                    foreach ($isf in $matchedFields) {
                        if ($isf -ieq $xaf) { $found = $true; break }
                        if ($src2tgt.ContainsKey($isf.ToLower())) {
                            if (Test-FieldEquiv $src2tgt[$isf.ToLower()] $xaf) { $found = $true; break }
                        }
                    }
                    if ($found) {
                        Out-Pass "  keyRef ${kr}: any field '$xaf' covered by ${matchedNames}"
                    } else {
                        $isFormOnly = $false
                        foreach ($fo in $formOnlyFields) {
                            if ($fo -ieq $xaf) { $isFormOnly = $true; break }
                        }
                        if ($isFormOnly) {
                            Out-Info "  keyRef ${kr}: XML any field '$xaf' not in ${matchedNames} (form-only)"
                        } else {
                            Out-Info "  keyRef ${kr}: XML any field '$xaf' not in ${matchedNames}"
                        }
                    }
                }

                continue
            }

            foreach ($jc in $matchingJsonCombos) {
                $jSet = @()
                $jAny = @()
                if ($jc.requirements) {
                    if ($jc.requirements.set) { $jSet = @($jc.requirements.set) }
                    if ($jc.requirements.any) { $jAny = @($jc.requirements.any) }
                }
                $jAll = $jSet + $jAny

                # Also need to map JSON fieldIds (camelCase sourceField) back to XML PascalCase
                # Build a reverse map from the QIDM attributes: sourceField -> targetField
                $sourceToTarget = @{}
                foreach ($qidm in $jsonQidms) {
                    if (-not $qidm.attributes) { continue }
                    foreach ($attr in @($qidm.attributes)) {
                        if ($attr.sourceField -and $attr.targetField) {
                            foreach ($sf in @($attr.sourceField)) {
                                $sourceToTarget[$sf.ToLower()] = $attr.targetField
                            }
                        }
                    }
                }

                # CHECK: XML Set fields present in JSON set[]
                foreach ($xsf in $xmlSetFields) {
                    $found = $false
                    # Direct match (case-insensitive)
                    foreach ($jsf in $jSet) {
                        if ($jsf -ieq $xsf) { $found = $true; break }
                        # Also check if JSON sourceField maps to this XML field via targetField
                        if ($sourceToTarget.ContainsKey($jsf.ToLower())) {
                            if (Test-FieldEquiv $sourceToTarget[$jsf.ToLower()] $xsf) { $found = $true; break }
                        }
                    }
                    if (-not $found) {
                        # Also check if it's in any[] (demoted from set to any)
                        $inAny = $false
                        foreach ($jaf in $jAny) {
                            if ($jaf -ieq $xsf) { $inAny = $true; break }
                            if ($sourceToTarget.ContainsKey($jaf.ToLower())) {
                                if (Test-FieldEquiv $sourceToTarget[$jaf.ToLower()] $xsf) { $inAny = $true; break }
                            }
                        }
                        if ($inAny) {
                            # Demote classification (metadata says set[], build has any[])
                            if (Test-IsDefaulted $xsf) {
                                Out-Note "  keyRef ${kr}: XML set '$xsf' in any[] -- PRINCIPLED (defaulted field -> any[] per initialValue-not-counted-for-set)"
                            } elseif (Test-AllowListed $qName $kr $xsf @('existence','to-any')) {
                                Out-Note "  keyRef ${kr}: XML set '$xsf' in any[] -- ACCEPTED per registry"
                            } else {
                                Out-Fail "  keyRef ${kr}: XML set '$xsf' demoted to any[] with NO default and NO registry entry -- fix build or record in docs\${providerName}_ACCEPTED_DIVERGENCES.txt"
                            }
                        } else {
                            # Check invented keyRef variants (JSON combos for same query not in XML)
                            $inInvented = $false
                            foreach ($qidm in $jsonQidms) {
                                if (-not $qidm.combinations) { continue }
                                foreach ($ic in @($qidm.combinations)) {
                                    if ($ic.keyReference -and -not $allXmlKeyRefs.ContainsKey($ic.keyReference) -and $ic.keyReference -ine $kr) {
                                        $icSet = @()
                                        if ($ic.requirements -and $ic.requirements.set) { $icSet = @($ic.requirements.set) }
                                        $icAny = @()
                                        if ($ic.requirements -and $ic.requirements.any) { $icAny = @($ic.requirements.any) }
                                        $icAll = $icSet + $icAny
                                        foreach ($isf in $icAll) {
                                            if ($isf -ieq $xsf) { $inInvented = $true; break }
                                            if ($sourceToTarget.ContainsKey($isf.ToLower())) {
                                                if (Test-FieldEquiv $sourceToTarget[$isf.ToLower()] $xsf) { $inInvented = $true; break }
                                            }
                                        }
                                        if ($inInvented) { break }
                                    }
                                }
                                if ($inInvented) { break }
                            }
                            if ($inInvented) {
                                Out-Info "  keyRef ${kr}: XML set field '$xsf' covered by invented keyRef variant"
                            } else {
                                Out-Warn "  keyRef ${kr}: XML set field '$xsf' missing from JSON set[]"
                            }
                        }
                    } else {
                        Out-Pass "  keyRef ${kr}: set field '$xsf' present"
                    }
                }

                # CHECK: XML Any fields present in JSON any[] or set[]
                foreach ($xaf in $xmlAnyFields) {
                    $found = $false
                    foreach ($jsf in $jAll) {
                        if ($jsf -ieq $xaf) { $found = $true; break }
                        if ($sourceToTarget.ContainsKey($jsf.ToLower())) {
                            if (Test-FieldEquiv $sourceToTarget[$jsf.ToLower()] $xaf) { $found = $true; break }
                        }
                    }
                    if ($found) {
                        Out-Pass "  keyRef ${kr}: any field '$xaf' present"
                    } else {
                        # Check if it's a known form-only field
                        $isFormOnly = $false
                        foreach ($fo in $formOnlyFields) {
                            if ($fo -ieq $xaf) { $isFormOnly = $true; break }
                        }
                        if ($isFormOnly) {
                            Out-Info "  keyRef ${kr}: XML any field '$xaf' not in JSON (form-only)"
                        } else {
                            Out-Info "  keyRef ${kr}: XML any field '$xaf' not in JSON any[] or set[]"
                        }
                    }
                }
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 4d: Defaulted-field-in-set[] gate (DEFAULT-IN-SET)
    # Platform ignores initialValue for set[] evaluation -> a defaulted field in a
    # combo set[] mis-evaluates (the combo won't fire on the default value alone).
    # This is the bug class that made NJ DQN require State (defaulted NJ) pre-v4.1.
    # Runs across ALL JSON combos (incl. invented keyRefs), independent of XML.
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 4d: Field promoted to set[] vs metadata any[] ---"
    $promoteHit = $false
    foreach ($q in $qidms) {
        $qn = $q.query
        if (-not $q.combinations) { continue }
        foreach ($c in @($q.combinations)) {
            $kr2 = [string]$c.keyReference
            if (-not ($c.requirements -and $c.requirements.set)) { continue }
            foreach ($sf in @($c.requirements.set)) {
                $sfS = [string]$sf
                if (Test-InMetaSet $qn $sfS) { continue }          # metadata agrees set[] -> correct (PlateType/Year, VehicleType)
                if (-not (Test-InMetaAny $qn $sfS)) { continue }    # not in metadata any either -> form-only/extra, not a promote
                if (Test-AllowListed $qn $kr2 $sfS @('to-set')) {
                    Out-Note "  keyRef ${kr2}: '$sfS' in set[] but metadata any[] -- ACCEPTED per registry"
                } else {
                    $defNote = if (Test-IsDefaulted $sfS) { ' (defaulted -- initialValue not counted for set[])' } else { '' }
                    Out-Fail "  keyRef ${kr2} ($qn): '$sfS' PROMOTED to set[] but metadata has it in any[]$defNote -- move to any[] or record in ${providerName}_ACCEPTED_DIVERGENCES.txt"
                    $promoteHit = $true
                }
            }
        }
    }
    if (-not $promoteHit) { Out-Pass "  No fields over-promoted from metadata any[] to set[]" }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 4e: Field DEMOTED from metadata set[] to any[]  (the mirror of 4d)
    #
    # WHY THIS EXISTS (2026-07-30): 4d has always caught PROMOTION (metadata any[] -> built
    # set[]) but nothing caught the opposite. A field metadata marks REQUIRED that we build as
    # OPTIONAL lets the query fire WITHOUT it -- the provider can reject the request or answer a
    # different question than the officer asked. That asymmetry is why NJ_NJCJIS shipped
    # VehicleRegistrationQuery with RandomRequest / State / LicensePlateTypeCode all demoted to
    # any[], unregistered, while sitting ALL-PASS on 35 tenant logs: the tests passed because
    # they only ever exercised what the build allowed, and no gate compared against the
    # metadata's own required list. Same family as the PREFILL-DEAD blind spot found the same
    # week -- every check validated what EXISTS, none checked what the spec DEMANDS.
    #
    # A demotion can be legitimate (a handler supplies the value, or the provider tolerates the
    # omission) -- so it is FAIL-with-an-escape-hatch: record it in
    # <PROVIDER>_ACCEPTED_DIVERGENCES.txt with a reason and it downgrades to [NOTE], exactly
    # like 4d. What must never happen again is it being invisible.
    Out-Line ""
    Out-Line "--- CHECK 4e: Field demoted to any[] vs metadata set[] ---"
    $demoteHit = $false
    foreach ($q in $qidms) {
        $qn = [string]$q.query
        if (-not $q.combinations) { continue }
        foreach ($c in @($q.combinations)) {
            $kr3 = if ($c.keyReference) { [string]$c.keyReference } else { [string]$c.keyRef }
            if (-not ($c.requirements -and $c.requirements.any)) { continue }
            foreach ($af in @($c.requirements.any)) {
                $afS = [string]$af
                if (-not $afS) { continue }
                # Only a problem when metadata has it REQUIRED and NOT also optional. A field
                # metadata lists in BOTH set[] and any[] (different combos of the same query) is
                # legitimately optional here -- do not flag it.
                if (-not (Test-InMetaSet $qn $afS)) { continue }
                if (Test-InMetaAny $qn $afS) { continue }
                # A defaulted field MUST live in any[] per the platform rule 4d enforces
                # (initialValue is not counted toward set[]). Flagging it here would demand the
                # exact opposite of 4d and make the two checks unsatisfiable together.
                if (Test-IsDefaulted $afS) { continue }
                # COMPOSITE GUARD: one metadata field can expand to several form fields. Metadata
                # requires a single 'Name'; the build splits it into NameLast+NameFirst (set[]) plus
                # nameMiddle/nameSuffix (any[]). Every one of those maps back to 'Name', so without
                # this guard each optional component reads as a demotion of a satisfied requirement
                # -- it produced 6 false FAILs on TX_TLETS, 14 on TX_TLETS_CCH and 2 on NY the first
                # time this check ran. The requirement is met if ANY OTHER field already in THIS
                # combo's set[] resolves to the same metadata token.
                $metaTok = Resolve-MetaToken $afS
                $satisfied = $false
                foreach ($sfChk in @($c.requirements.set)) {
                    if (-not $sfChk) { continue }
                    if ((Resolve-MetaToken ([string]$sfChk)) -eq $metaTok) { $satisfied = $true; break }
                }
                if ($satisfied) { continue }
                # KEYREF SCOPING (BUILD_RULES 13). The unions above are query-wide, so a field that
                # is set[]-mandatory in a SIBLING combination looks mandatory here too. A demotion is
                # only real if the METADATA COMBINATION THIS combo derives from requires the field.
                # Our keyRefs are synthetic: metadata keyRef + a field suffix (DPSI -> DPSIStickerNumber,
                # CPL -> CPLName), so match by prefix and require the field in EVERY metadata
                # combination that could be the source. If none corresponds, fall back to the union
                # (better to over-report than to go silent).
                $qkLow = $qn.ToLower(); $krLow = $kr3.ToLower()
                if ($metaSetByKeyRef.ContainsKey($qkLow)) {
                    $cands = @($metaSetByKeyRef[$qkLow].Keys | Where-Object { $krLow.StartsWith($_) })
                    if ($cands.Count) {
                        $reqInAll = $true
                        foreach ($cd in $cands) {
                            $sets = $metaSetByKeyRef[$qkLow][$cd]
                            if (-not ($sets.ContainsKey($metaTok) -or $sets.ContainsKey($afS.ToLower()))) { $reqInAll = $false; break }
                        }
                        if (-not $reqInAll) { continue }   # not required by THIS combination -- legitimate any[]
                    }
                }
                if (Test-AllowListed $qn $kr3 $afS @('to-any')) {
                    Out-Note "  keyRef ${kr3}: '$afS' in any[] but metadata set[] -- ACCEPTED per registry"
                } else {
                    Out-Fail "  keyRef ${kr3} ($qn): '$afS' DEMOTED to any[] but metadata REQUIRES it in set[] -- the query can fire without it; promote to set[] or record in ${providerName}_ACCEPTED_DIVERGENCES.txt"
                    $demoteHit = $true
                }
            }
        }
    }
    if (-not $demoteHit) { Out-Pass "  No metadata-required fields demoted to any[]" }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 4b: Choice-Set Option Coverage
    # Metadata combinations can have a Choice structure: two Set options, where
    # Option A is the minimal in-state path and Option B adds PurposeCode,
    # Requestor, State for OOS queries. Both options must have a corresponding
    # build combo. Missing the OOS option leaves OOS queries broken.
    # XML structure: Requirements/Set/Choice containing two Set children.
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 4b: Choice-Set Option Coverage ---"

    foreach ($txn in $xmlQueryTxns) {
        $qName = $txn.name
        if (-not $qidmByQuery.ContainsKey($qName)) { continue }
        if (-not $txn.Combinations -or -not $txn.Combinations.Combination) { continue }

        $jsonQidms = $qidmByQuery[$qName]

        # Build sourceField->targetField map for this query
        $src2tgt4b = @{}
        foreach ($qidm in $jsonQidms) {
            if (-not $qidm.attributes) { continue }
            foreach ($attr in @($qidm.attributes)) {
                if ($attr.sourceField -and $attr.targetField) {
                    foreach ($sf in @($attr.sourceField)) {
                        $src2tgt4b[$sf.ToLower()] = $attr.targetField
                    }
                }
            }
        }

        # Collect all set[] fields across all JSON combos for this query
        $allJsonSetFields = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $allJsonAnyFields = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($qidm in $jsonQidms) {
            if (-not $qidm.combinations) { continue }
            foreach ($jc in @($qidm.combinations)) {
                if ($jc.requirements) {
                    if ($jc.requirements.set) {
                        foreach ($f in @($jc.requirements.set)) { [void]$allJsonSetFields.Add($f) }
                    }
                    if ($jc.requirements.any) {
                        foreach ($f in @($jc.requirements.any)) { [void]$allJsonAnyFields.Add($f) }
                    }
                }
            }
        }

        foreach ($xmlCombo in @($txn.Combinations.Combination)) {
            $kr = $xmlCombo.keyReference
            if (-not $kr) { try { $kr = $xmlCombo.GetAttribute('keyReference') } catch { $kr = '?' } }
            $pfr4b = $xmlCombo.primaryFieldReference
            if (-not $pfr4b) { try { $pfr4b = $xmlCombo.GetAttribute('primaryFieldReference') } catch { } }

            # Look for Choice element inside Requirements/Set
            $choiceNode = $null
            try {
                if ($xmlCombo.Requirements -and $xmlCombo.Requirements.Set) {
                    foreach ($child in $xmlCombo.Requirements.Set.ChildNodes) {
                        if ($child.LocalName -eq 'Choice') { $choiceNode = $child; break }
                    }
                }
            } catch { }

            if (-not $choiceNode) { continue }

            # Extract each Set option within the Choice
            $choiceOptions = @()
            foreach ($optNode in $choiceNode.ChildNodes) {
                if ($optNode.LocalName -eq 'Set') {
                    $optFields = @()
                    foreach ($fNode in $optNode.ChildNodes) {
                        if ($fNode.LocalName -eq 'Field') {
                            $ref = $fNode.GetAttribute('reference')
                            if (-not $ref) { $ref = $fNode.GetAttribute('name') }
                            if ($ref) { $optFields += $ref }
                        }
                    }
                    if ($optFields.Count -gt 0) { $choiceOptions += ,@($optFields) }
                }
            }

            if ($choiceOptions.Count -lt 2) { continue }

            # The option with MORE fields is the extended (OOS) path
            $minimalOption = $choiceOptions | Sort-Object Count | Select-Object -First 1
            $extendedOptions = $choiceOptions | Where-Object { $_.Count -gt $minimalOption.Count }

            foreach ($extOpt in $extendedOptions) {
                # Find fields in the extended option that are NOT in the minimal option
                $oosOnlyFields = @($extOpt | Where-Object { $_ -notin $minimalOption })

                # Check each OOS-only field is covered by some JSON combo set[] or any[]
                $missingFields = @()
                foreach ($xf in $oosOnlyFields) {
                    $isFormOnly = $formOnlyFields -contains $xf
                    if ($isFormOnly) { continue }  # form-only fields (ImageIndicator, State) are expected

                    $covered = $false
                    # Check direct match in set[] or any[]
                    if ($allJsonSetFields.Contains($xf) -or $allJsonAnyFields.Contains($xf)) { $covered = $true }

                    if (-not $covered) {
                        # Check via sourceField->targetField reverse mapping
                        foreach ($sf in $src2tgt4b.Keys) {
                            if (Test-FieldEquiv $src2tgt4b[$sf] $xf) {
                                if ($allJsonSetFields.Contains($sf) -or $allJsonAnyFields.Contains($sf)) { $covered = $true; break }
                            }
                        }
                    }

                    if (-not $covered) { $missingFields += $xf }
                }

                if ($missingFields.Count -eq 0) {
                    Out-Pass "$qName keyRef $kr`: OOS Choice option covered (fields: $($oosOnlyFields -join ', '))"
                } else {
                    Out-Fail "$qName keyRef $kr`: OOS Choice option missing fields: $($missingFields -join ', ') -- add OOS combo with these in set[]"
                }

                # Discriminator check: if the OOS option requires State, a JSON combo sharing
                # this primaryFieldReference must enforce State in set[] -- otherwise the OOS path
                # is only reachable via any[] on an in-state combo (not a distinct firing combo).
                # This catches the NY RVEH-plate pattern that field-coverage alone passes silently.
                $oosHasState = @($extOpt | Where-Object { $_ -ieq 'State' -or $_ -ieq 'RegistrationState' }).Count -gt 0
                if ($oosHasState -and $pfr4b) {
                    $stateInSetForPrimary = $false
                    foreach ($qidm in $jsonQidms) {
                        if (-not $qidm.combinations) { continue }
                        foreach ($jc in @($qidm.combinations)) {
                            if ($jc.primaryFieldReference -ine $pfr4b) { continue }
                            if (-not ($jc.requirements -and $jc.requirements.set)) { continue }
                            foreach ($f in @($jc.requirements.set)) {
                                if ($f -ieq 'State' -or $f -ieq 'RegistrationState') { $stateInSetForPrimary = $true; break }
                                if ($src2tgt4b.ContainsKey($f.ToLower())) {
                                    $t4b = $src2tgt4b[$f.ToLower()]
                                    if ($t4b -ieq 'State' -or $t4b -ieq 'RegistrationState') { $stateInSetForPrimary = $true; break }
                                }
                            }
                            if ($stateInSetForPrimary) { break }
                        }
                        if ($stateInSetForPrimary) { break }
                    }
                    if (-not $stateInSetForPrimary) {
                        Out-Note "$qName keyRef $kr (primary ${pfr4b}): OOS Choice requires State but no combo with this primary has State in set[] -- OOS path not a distinct firing combo; add an OOS combo with State in set[] (LIMITATION #36) or verify any[] routing during USx Tenant Testing"
                    }
                }
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 5: Primary Field Coverage (HARD GATE)
    # For each built query, every unique primaryFieldReference in the metadata
    # must have at least one matching combo in the JSON. If a metadata search
    # path exists and we build the query but skip that path, that's a FAIL.
    # This catches cross-entity gaps (Name on Vehicle/Firearm/Boat) and any
    # other missing search paths within queries we claim to support.
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 5: Primary Field Coverage (HARD GATE) ---"

    foreach ($txn in $xmlQueryTxns) {
        $qName = $txn.name
        if (-not $qidmByQuery.ContainsKey($qName)) { continue }
        if (-not $txn.Combinations -or -not $txn.Combinations.Combination) { continue }

        $xmlCombos = @($txn.Combinations.Combination)
        $jsonQidms = $qidmByQuery[$qName]

        # Collect unique primaryFieldReferences from metadata
        $xmlPrimaries = @{}
        foreach ($xmlCombo in $xmlCombos) {
            $pfr = $null
            try { $pfr = $xmlCombo.primaryFieldReference } catch { }
            if (-not $pfr) {
                try { $pfr = $xmlCombo.GetAttribute('primaryFieldReference') } catch { }
            }
            if ($pfr -and -not $xmlPrimaries.ContainsKey($pfr)) {
                $kr = $xmlCombo.keyReference
                if (-not $kr) { try { $kr = $xmlCombo.GetAttribute('keyReference') } catch { $kr = '?' } }
                $xmlPrimaries[$pfr] = $kr
            }
        }

        # Collect unique primaryFieldReferences from JSON combos. A combo's
        # primaryFieldReference names a QIDM attribute; resolve it to that
        # attribute's targetField so suffixed primaries (DH-suffix etc.) match
        # the metadata field name -- e.g. 'OperatorLicenseNumberDH' -> 'OperatorLicenseNumber'.
        $jsonPrimaries = @{}
        foreach ($qidm in $jsonQidms) {
            if (-not $qidm.combinations) { continue }
            foreach ($jc in @($qidm.combinations)) {
                $pfr = $jc.primaryFieldReference
                if (-not $pfr) { continue }
                $jsonPrimaries[$pfr] = $true
                foreach ($attr in @($qidm.attributes)) {
                    if ($attr.name -ieq $pfr -and $attr.targetField) { $jsonPrimaries[$attr.targetField] = $true; break }
                }
            }
        }

        # Also collect JSON QIDM attribute targetFields (for Name fields that use FormatStringRuleHandler)
        $jsonTargetFields = @{}
        foreach ($qidm in $jsonQidms) {
            if (-not $qidm.attributes) { continue }
            foreach ($attr in @($qidm.attributes)) {
                if ($attr.targetField) { $jsonTargetFields[$attr.targetField] = $true }
            }
        }

        Out-Line "  ${qName}: $($xmlPrimaries.Count) metadata search paths"
        foreach ($pfr in ($xmlPrimaries.Keys | Sort-Object)) {
            $kr = $xmlPrimaries[$pfr]
            $hasComboPfr = $false
            foreach ($jp in $jsonPrimaries.Keys) {
                if ($jp -ieq $pfr) { $hasComboPfr = $true; break }
            }

            if ($hasComboPfr) {
                Out-Pass "  $pfr`: at least one combo built (e.g. $kr)"
            } else {
                $hasAttr = $false
                foreach ($tf in $jsonTargetFields.Keys) {
                    if ($tf -ieq $pfr) { $hasAttr = $true; break }
                }
                if ($hasAttr) {
                    if (Test-AllowListed $qName $kr $pfr @('existence')) {
                        Out-Note "  $pfr`: QIDM has attribute but no combo as primaryFieldReference (keyRef $kr) -- ACCEPTED per registry"
                    } else {
                        Out-Fail "  $pfr`: QIDM has attribute but NO combo uses it as primaryFieldReference (missing combo for $kr path)"
                    }
                } else {
                    # INFO not WARN: query IS built but this secondary search path (e.g. boat-by-name)
                    # was intentionally not implemented. Devdoc authority determines which paths to build.
                    # FAIL is reserved for when the QIDM has the attribute but no combo -- a clear gap.
                    Out-Info "  $pfr`: metadata search path not built -- no attribute, no combo (keyRef $kr) -- check devdoc authority"
                }
            }
        }
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CHECK 6: Field maxLength Alignment
    # ══════════════════════════════════════════════════════════════════════════
    Out-Line ""
    Out-Line "--- CHECK 5: Field maxLength Alignment ---"

    $maxLenChecked = 0
    foreach ($txn in $xmlQueryTxns) {
        $qName = $txn.name
        if (-not $qidmByQuery.ContainsKey($qName)) { continue }
        if (-not $txn.Fields -or -not $txn.Fields.Field) { continue }

        foreach ($xf in @($txn.Fields.Field)) {
            $xmlFieldName = $xf.name
            if (-not $xmlFieldName) {
                try { $xmlFieldName = $xf.GetAttribute('name') } catch { continue }
            }
            $xmlMaxLen = $xf.maxLength
            if (-not $xmlMaxLen) {
                try { $xmlMaxLen = $xf.GetAttribute('maxLength') } catch { continue }
            }
            if (-not $xmlMaxLen) { continue }

            # Find matching QIF field by looking at QIDM attributes: targetField -> sourceField -> QIF fieldId
            $sourceFieldIds = @()
            foreach ($qidm in $qidmByQuery[$qName]) {
                if (-not $qidm.attributes) { continue }
                foreach ($attr in @($qidm.attributes)) {
                    if ($attr.targetField -and $attr.targetField -ieq $xmlFieldName) {
                        if ($attr.sourceField) {
                            foreach ($sf in @($attr.sourceField)) {
                                $sourceFieldIds += $sf
                            }
                        }
                    }
                }
            }

            foreach ($sfId in $sourceFieldIds) {
                # Prefer the control on THIS query's own entity; fall back to the bare fieldId only
                # when that QIF has no such control. See the indexing note above -- without this, a
                # fieldId reused across entities is compared against the wrong card's control.
                $key = $sfId.ToLower()
                $entKey = $null
                foreach ($q in @($qidmByQuery[$qName])) {
                    $te = "$($q.targetEntity)"
                    if ($te -and $qifFields.ContainsKey("$($te.ToLower())|$key")) { $entKey = "$($te.ToLower())|$key"; break }
                }
                if ($entKey) { $key = $entKey }
                if ($qifFields.ContainsKey($key)) {
                    $qifMaxLen = $qifFields[$key].maxLength
                    $maxLenChecked++
                    if ($qifMaxLen -and $xmlMaxLen) {
                        $qifInt = 0; $xmlInt = 0
                        $qifParsed = [int]::TryParse($qifMaxLen, [ref]$qifInt)
                        $xmlParsed = [int]::TryParse($xmlMaxLen, [ref]$xmlInt)
                        if ($qifParsed -and $xmlParsed) {
                            if ($qifInt -eq $xmlInt) {
                                Out-Pass "$sfId`: maxLength $qifInt matches XML ($xmlFieldName)"
                            } elseif ($qifInt -gt $xmlInt) {
                                Out-Warn "$sfId`: QIF maxLength $qifInt > XML maxLength $xmlInt ($xmlFieldName) -- server may reject"
                            } else {
                                Out-Info "$sfId`: QIF maxLength $qifInt < XML maxLength $xmlInt ($xmlFieldName) -- conservative, OK"
                            }
                        }
                    }
                }
            }
        }
    }

    if ($maxLenChecked -eq 0) {
        Out-Info "No maxLength comparisons possible (no matching QIF fields found)"
    }

    Out-Line ""
    $script:totalProviders++
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ══════════════════════════════════════════════════════════════════════════════

Out-Line ("=" * 60)
Out-Line " CONNECTCIC METADATA AUDIT"
Out-Line " Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Out-Line ("=" * 60)

foreach ($target in $targets) {
    try {
        Audit-Provider -JsonPath $target.JsonPath
    } catch {
        Out-Line ""
        Out-Line "  [ERROR] Exception auditing $($target.JsonPath): $_"
        Out-Line ""
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
Out-Line ("=" * 60)
Out-Line " METADATA AUDIT SUMMARY"
Out-Line ("=" * 60)
Out-Line "Providers checked: $($script:totalProviders)"
Out-Line "Total: $($script:passCount) PASS / $($script:failCount) FAIL / $($script:warnCount) WARN"
Out-Line ("=" * 60)

# ── Output ────────────────────────────────────────────────────────────────────
$output = $lines -join "`r`n"

if ($OutFile) {
    $output | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "Report written to: $OutFile" -ForegroundColor Green
} else {
    # Write to console with color coding
    foreach ($line in $lines) {
        if ($line -match '^\s*\[PASS\]')       { Write-Host $line -ForegroundColor Green }
        elseif ($line -match '^\s*\[FAIL\]')    { Write-Host $line -ForegroundColor Red }
        elseif ($line -match '^\s*\[WARN\]')    { Write-Host $line -ForegroundColor Yellow }
        elseif ($line -match '^\s*\[INFO\]')    { Write-Host $line -ForegroundColor Gray }
        elseif ($line -match '^\s*\[SKIP\]')    { Write-Host $line -ForegroundColor DarkYellow }
        elseif ($line -match '^\s*\[ERROR\]')   { Write-Host $line -ForegroundColor Red }
        elseif ($line -match '^={3,}')           { Write-Host $line -ForegroundColor Cyan }
        elseif ($line -match '^-{3,}\s*CHECK')   { Write-Host $line -ForegroundColor Yellow }
        else                                     { Write-Host $line }
    }
}
