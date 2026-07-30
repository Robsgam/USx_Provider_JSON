<#
  _metadata_parse.ps1 -- shared CommSys metadata-XML parser + field-equivalence rules.

  Dot-sourced by audit_log_metadata.ps1 (log <-> metadata gate). Provides ONE definition of
  "what the metadata says" so the log-metadata gate and the JSON-metadata gate (audit_metadata.ps1)
  cannot drift on field aliases / form-only fields.

  Exports:
    Get-MetadataTransactions -XmlPath <xml>
        -> hashtable { <query> = @{ version; fields=@(names); combos=@(@{keyReference;primaryField;
           set=@();any=@();choiceFields=@()}) } }
        Parser adapted from extract_metadata_reference.ps1 (Parse-Requirements + $transactions,
        XmlNamespaceManager-based -- the robust variant, not audit_metadata's dotted navigation).
    Test-MetaFieldEquiv $a $b   -- case-insensitive + alias-aware field-name equality.
    $MetaFormOnlyFields         -- fields legitimately on the wire but not metadata-combo fields.
    $MetaFieldAliases           -- XML-reference-name <-> QIDM-targetField aliases.

  NOTE: $MetaFormOnlyFields / $MetaFieldAliases / the equivalence rule are mirrored verbatim from
  audit_metadata.ps1 (lines 29-41, 128-133) so the two gates agree. Origin of truth is still
  audit_metadata.ps1; unifying it onto this module is a deliberate follow-up (left untouched here
  to keep the working PHASE 2b gate stable).
#>

# Mirror of audit_metadata.ps1:29-35 -- present on the wire/QIDM but not a metadata combo field.
$script:MetaFormOnlyFields = @(
    'ImageIndicator', 'State', 'RegistrationState', 'Attention',
    'PurposeCode', 'CaRequestPurposeCode', 'RelatedHitSearchIndicator',
    'RandomRequest', 'ExpandedBirthDateSearchCode', 'ReasonCode',
    'ExpandedNameSearchCode', 'ExpandedBirthDateSearchIndicator',
    'dexStateUserId', 'InquiryLevel', 'FormORI', 'Requestor'
)

# Mirror of audit_metadata.ps1:37-41 -- XML combo may reference one name, QIDM targetField the other.
# Plus State<->RegistrationState: NCIC-pattern providers (NJ/NY/...) serialize the metadata "State"
# field as the wire element <RegistrationState> (the QIDM targetField); FL emits <State> directly.
# This alias lets the wire element reconcile to the metadata combo field either way.
$script:MetaFieldAliases = @{
    'CaRequestPurposeCode' = 'PurposeCode'
    'PurposeCode'          = 'CaRequestPurposeCode'
    'State'                = 'RegistrationState'
    'RegistrationState'    = 'State'
}

# Mirror of audit_metadata.ps1:128-133 (Test-FieldEquiv).
function Test-MetaFieldEquiv([string]$a, [string]$b) {
    if ($a -ieq $b) { return $true }
    if ($script:MetaFieldAliases.ContainsKey($a) -and $script:MetaFieldAliases[$a] -ieq $b) { return $true }
    if ($script:MetaFieldAliases.ContainsKey($b) -and $script:MetaFieldAliases[$b] -ieq $a) { return $true }
    return $false
}

function Test-MetaFormOnly([string]$f) {
    foreach ($fo in $script:MetaFormOnlyFields) { if ($fo -ieq $f) { return $true } }
    return $false
}

# Expand a <Set> requirements node into a list of ALTERNATIVE required-field-sets (each inner
# array = one valid minimal required set). Handles the CommSys grammar:
#   <Field reference=..>  -> required in the current set (AND)
#   <Choice> <Set/>.. </Choice> -> each child <Set> is an alternative (OR); cross-producted with
#                                   the surrounding required fields
#   nested <Set>          -> AND (its own alternatives cross-product in)
#   <Any>                 -> optional, ignored for required-sets
# FL/NJ use flat Sets (no Choice) -> one alternative = the flat field list. NY uses <Choice>
# (e.g. Vehicle plate: {Plate} OR {Plate,Type,Year,State}) -> multiple alternatives.
# ARRAY-UNWRAP HAZARD -- this function returns an array OF ARRAYS, and PowerShell destroys that
# shape twice over unless every step is written defensively. Both traps were LIVE here until
# 2026-07-30 and silently degraded the grammar above into something much weaker:
#   1. `return $combos` on a ONE-alternative result unwraps to the bare inner field array, so the
#      caller receives string[] instead of string[][]. Fixed with Write-Output -NoEnumerate.
#   2. `$alts += (Get-MetaAltSets $opt)` then ENUMERATES that unwrapped array and appends each
#      FIELD as its own alternative.
# Net effect on NY_NYSPIN_EJUSTICE's documented example: {Plate} OR {Plate,Type,Year,State} came
# back as FIVE single-field alternatives -- [Plate], [Plate], [Type], [Year], [State]. Every
# consumer then believed a one-field request satisfied the four-field branch. audit_log_metadata
# (gate 6d) is the consumer that matters: it validated 6 providers' logs against requirements it
# had silently shredded, and it could not fail, because a single-field set matches almost anything.
# The comment block above was CORRECT the whole time -- documented intent, degraded implementation,
# no gate on the gate. Use `+= ,@(...)` for every append, and -NoEnumerate on every return.
# Verify a change here with:  Get-MetadataTransactions on NY VehicleRegistrationQuery must yield
# exactly TWO RVEH alternatives, the second of which has FOUR fields.
function Get-MetaAltSets($setNode) {
    $direct = @()
    $groups = @()   # each entry = an array-of-alternatives (from a Choice or nested Set)
    foreach ($child in $setNode.ChildNodes) {
        switch ($child.LocalName) {
            'Field' {
                $ref = $child.GetAttribute('reference'); if (-not $ref) { $ref = $child.GetAttribute('name') }
                if ($ref) { $direct += $ref }
            }
            'Choice' {
                $alts = @()
                foreach ($opt in $child.ChildNodes) {
                    if ($opt.LocalName -eq 'Set') {
                        # each returned alternative must be appended as ONE element, not spliced
                        foreach ($a in (Get-MetaAltSets $opt)) { $alts += ,@($a) }
                    }
                    elseif ($opt.LocalName -eq 'Field') {
                        $r = $opt.GetAttribute('reference'); if (-not $r) { $r = $opt.GetAttribute('name') }
                        if ($r) { $alts += ,@($r) }
                    }
                }
                if ($alts.Count) { $groups += ,$alts }
            }
            'Set' {
                $sub = @(); foreach ($a in (Get-MetaAltSets $child)) { $sub += ,@($a) }
                if ($sub.Count) { $groups += ,$sub }
            }
            # 'Any' ignored -- optional fields do not constrain the required set.
        }
    }
    # Cross-product base [$direct] with every OR-group.
    $combos = @( ,@($direct) )
    foreach ($group in $groups) {
        $next = @()
        foreach ($existing in $combos) {
            foreach ($alt in $group) { $next += ,@(@($existing) + @($alt)) }
        }
        $combos = $next
    }
    Write-Output $combos -NoEnumerate
}

function Get-MetadataTransactions {
    param([Parameter(Mandatory)][string]$XmlPath)

    [xml]$metadata = Get-Content $XmlPath -Raw
    $nsm = New-Object System.Xml.XmlNamespaceManager($metadata.NameTable)
    $defaultNs = $metadata.DocumentElement.NamespaceURI
    if ($defaultNs) { $nsm.AddNamespace('ns', $defaultNs) }
    $pre = if ($defaultNs) { 'ns:' } else { '' }

    $transactions = @{}
    foreach ($txNode in $metadata.SelectNodes("//${pre}Transaction[@name]", $nsm)) {
        $txName = $txNode.GetAttribute('name')

        $fields = @()
        $fieldsNode = $txNode.SelectSingleNode("${pre}Fields", $nsm)
        if ($fieldsNode) {
            foreach ($f in $fieldsNode.ChildNodes) {
                if ($f.LocalName -eq 'Field') { $fields += $f.GetAttribute('name') }
            }
        }

        $combos = @()
        $combosNode = $txNode.SelectSingleNode("${pre}Combinations", $nsm)
        if ($combosNode) {
            foreach ($c in $combosNode.ChildNodes) {
                if ($c.LocalName -ne 'Combination') { continue }
                $reqNode = $c.SelectSingleNode("${pre}Requirements", $nsm)
                $setNode = if ($reqNode) { $reqNode.SelectSingleNode("${pre}Set", $nsm) } else { $null }
                $altSets = if ($setNode) { @(Get-MetaAltSets $setNode) } else { @() }
                $combos += @{
                    keyReference = $c.GetAttribute('keyReference')
                    primaryField = $c.GetAttribute('primaryFieldReference')
                    requiredSets = $altSets   # list of alternative required-field arrays
                }
            }
        }

        if (-not $transactions.ContainsKey($txName)) {
            $transactions[$txName] = @{ version = $txNode.GetAttribute('version'); fields = $fields; combos = $combos }
        } else {
            $transactions[$txName].combos += $combos
            $transactions[$txName].fields += $fields
        }
    }
    return $transactions
}
