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
    # Derive provider name: strip _BASE, _MC suffixes
    $providerName = $jsonFile -replace '(?i)_(BASE|MC)$', ''

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
        Out-Line "  [SKIP] No XML metadata found for $providerName"
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
                    $qifFields[$fid.ToLower()] = @{
                        fieldId   = $fid
                        maxLength = $ml
                    }
                }
            }
        }
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

        Out-Line "  ${qName}:"

        foreach ($xmlCombo in $xmlCombos) {
            $kr = $xmlCombo.keyReference
            if (-not $kr) {
                try { $kr = $xmlCombo.GetAttribute('keyReference') } catch { $kr = '(unknown)' }
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

            if ($matchingJsonCombos.Count -eq 0) {
                # Find invented keyRef variants for this query (JSON combos whose keyRef is not in XML)
                $inventedCombos = @()
                foreach ($qidm in $jsonQidms) {
                    if (-not $qidm.combinations) { continue }
                    foreach ($jc in @($qidm.combinations)) {
                        if ($jc.keyReference -and -not $allXmlKeyRefs.ContainsKey($jc.keyReference)) {
                            $inventedCombos += $jc
                        }
                    }
                }

                if ($inventedCombos.Count -eq 0) {
                    Out-Info "  keyRef ${kr}: no exact match in JSON (no invented variants found)"
                    continue
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

                # Collect all set[] and any[] fields across all invented variants
                $allInventedSet = @()
                $allInventedAny = @()
                foreach ($ic in $inventedCombos) {
                    if ($ic.requirements) {
                        if ($ic.requirements.set) { $allInventedSet += @($ic.requirements.set) }
                        if ($ic.requirements.any) { $allInventedAny += @($ic.requirements.any) }
                    }
                }
                $allInventedFields = @($allInventedSet) + @($allInventedAny) | Select-Object -Unique

                $inventedNames = ($inventedCombos | ForEach-Object { $_.keyReference }) -join ','

                # Validate XML set[] fields against invented variants
                foreach ($xsf in $xmlSetFields) {
                    $found = $false
                    foreach ($isf in $allInventedFields) {
                        if ($isf -ieq $xsf) { $found = $true; break }
                        if ($src2tgt.ContainsKey($isf.ToLower())) {
                            if (Test-FieldEquiv $src2tgt[$isf.ToLower()] $xsf) { $found = $true; break }
                        }
                    }
                    if ($found) {
                        Out-Pass "  keyRef ${kr}: set field '$xsf' covered by invented variants ($inventedNames)"
                    } else {
                        $inInvAny = $false
                        foreach ($isf in $allInventedAny) {
                            if ($isf -ieq $xsf) { $inInvAny = $true; break }
                            if ($src2tgt.ContainsKey($isf.ToLower())) {
                                if (Test-FieldEquiv $src2tgt[$isf.ToLower()] $xsf) { $inInvAny = $true; break }
                            }
                        }
                        if ($inInvAny) {
                            Out-Info "  keyRef ${kr}: XML set field '$xsf' demoted to any[] in invented variants"
                        } else {
                            # INFO not WARN: invented variants exist but don't cover this field path.
                            # This means the build chose a different search path for this query.
                            # CHECK 5 (Primary Field Coverage) already catches missing primary paths as FAIL/WARN.
                            Out-Info "  keyRef ${kr}: XML set field '$xsf' not covered by invented variants ($inventedNames) -- intentional exclusion, see CHECK 5"
                        }
                    }
                }

                # Validate XML any[] fields against invented variants
                foreach ($xaf in $xmlAnyFields) {
                    $found = $false
                    foreach ($isf in $allInventedFields) {
                        if ($isf -ieq $xaf) { $found = $true; break }
                        if ($src2tgt.ContainsKey($isf.ToLower())) {
                            if (Test-FieldEquiv $src2tgt[$isf.ToLower()] $xaf) { $found = $true; break }
                        }
                    }
                    if ($found) {
                        Out-Pass "  keyRef ${kr}: any field '$xaf' covered by invented variants ($inventedNames)"
                    } else {
                        $isFormOnly = $false
                        foreach ($fo in $formOnlyFields) {
                            if ($fo -ieq $xaf) { $isFormOnly = $true; break }
                        }
                        if ($isFormOnly) {
                            Out-Info "  keyRef ${kr}: XML any field '$xaf' not in invented variants (form-only)"
                        } else {
                            Out-Info "  keyRef ${kr}: XML any field '$xaf' not in invented variants"
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
                            Out-Info "  keyRef ${kr}: XML set field '$xsf' is in JSON any[] (demoted)"
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
                        Out-Note "$qName keyRef $kr (primary ${pfr4b}): OOS Choice requires State but no combo with this primary has State in set[] -- OOS path not a distinct firing combo; add an OOS combo with State in set[] (LIMITATION #36) or verify any[] routing on live test"
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
                    Out-Fail "  $pfr`: QIDM has attribute but NO combo uses it as primaryFieldReference (missing combo for $kr path)"
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
                $key = $sfId.ToLower()
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
