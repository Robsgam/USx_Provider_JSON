# ─────────────────────────────────────────────────────────────────────────────
#  _combo_match.ps1 -- shared CommSys combo extraction + test-log matching
#
#  Single source of truth for: enumerating a provider JSON's CommSys combos and
#  matching a test-log filename to a combo. audit_test_coverage.ps1 and
#  block_entity.ps1 both dot-source this so the matching rules cannot drift
#  between the coverage gate and the entity-block gate.
#
#  Dot-source this file; it defines functions only (no side effects, no param block).
# ─────────────────────────────────────────────────────────────────────────────

function Get-CommSysQidms($json) {
    $qidms = @()
    foreach ($bundle in $json.bundles) {
        if ($bundle.provider -eq 'RMS') { continue }
        if ($bundle.name -eq 'RMS') { continue }
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -eq "QUERYINPUTDATAMAPPING" -and
                $cfg.handlerFunction -eq "CommsysTransactionRequestHandler") {
                $qidms += $cfg
            }
        }
    }
    return $qidms
}

function Get-ComboInfo($qidm) {
    $combos = @()
    foreach ($c in $qidm.combinations) {
        $kr = $c.keyReference
        if (-not $kr) { $kr = $c.keyRef }
        $setFields = @()
        if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }
        $anyFields = @()
        if ($c.requirements -and $c.requirements.any) { $anyFields = @($c.requirements.any) }
        $combos += [PSCustomObject]@{
            KeyReference = $kr
            Entity       = $qidm.targetEntity
            Query        = $qidm.query
            QidmName     = $qidm.name
            Set          = $setFields
            Any          = $anyFields
            State        = $c.state
        }
    }
    return $combos
}

# Build a short label for a combo (e.g., "FRQ+Plate", "KQ+OLN", "IA.QV")
# This is what test log filenames typically contain.
function Get-ComboShortLabel($combo) {
    $kr = $combo.KeyReference
    if (-not $kr) { return $null }

    # For dotted keyRefs (CA providers: IA.QV, NLTS.RQ.P, etc.) return as-is
    if ($kr -match '\.') { return $kr }

    # Extract prefix (FRQ, DQ, KQ, QG, QA, QB, BQ, RQ, QV, QW, FDQ, FBQ, etc.)
    $prefix = ""
    if ($kr -match '^(FRQ|FDQ|FBQ|NLTS|QB|QV|QW|QG|QA|BQ|RQ|DQ|KQ)') {
        $prefix = $Matches[1]
    } elseif ($kr -match '^([A-Z]{2,4})') {
        $prefix = $Matches[1]
    }
    if (-not $prefix) { return $kr }

    # Determine the field keyword from what remains after the prefix
    $remainder = $kr.Substring($prefix.Length)
    $fieldWord = ""

    # Map common field names to their test-log abbreviations
    if ($remainder -match 'LicensePlateNumber') { $fieldWord = "Plate" }
    elseif ($remainder -match 'VehicleIdentificationNumber') { $fieldWord = "VIN" }
    elseif ($remainder -match 'OperatorLicenseNumber') { $fieldWord = "OLN" }
    elseif ($remainder -match '^Name$') { $fieldWord = "Name" }
    elseif ($remainder -match 'GunSerialNumber|ArticleSerialNumber|serialNumber') { $fieldWord = "Serial" }
    elseif ($remainder -match 'NCICNumber') { $fieldWord = "NCIC" }
    elseif ($remainder -match 'ProcessControlNumber') { $fieldWord = "PCN" }
    elseif ($remainder -match 'BoatHullIdNumber') { $fieldWord = "Hull" }
    elseif ($remainder -match 'RegistrationNumber') { $fieldWord = "Reg" }
    elseif ($remainder -match 'CoastGuardDocumentNumber') { $fieldWord = "CG" }
    elseif ($remainder -match 'DecalNumber') { $fieldWord = "Decal" }
    elseif ($remainder -match 'TitleLienInformation') { $fieldWord = "Title" }
    elseif ($remainder -match 'OwnerAppliedNumber') { $fieldWord = "OAN" }
    else { $fieldWord = $remainder }

    return "$prefix+$fieldWord"
}

function Match-TestLogToCombo($logName, $combo, $providerName) {
    $kr = $combo.KeyReference
    if (-not $kr) { return $false }

    $logUpper = $logName.ToUpper()
    $entity = $combo.Entity

    # ── TIER 0: Wildcard keyReference prefix match ──
    if ($kr.Contains('*')) {
        $prefix0 = $kr.Substring(0, $kr.IndexOf('*')).ToUpper()
        if ($prefix0 -and $logUpper.Contains($prefix0)) { return $true }
    }

    # ── TIER 1: Exact keyReference in filename ──
    if ($logUpper.Contains($kr.ToUpper())) { return $true }

    # ── TIER 1b: Trailing-suffix strip fallback ──
    $krU = $kr.ToUpper()
    for ($trim = 1; $trim -le 2; $trim++) {
        if ($krU.Length - $trim -ge 3) {
            $shortKr = $krU.Substring(0, $krU.Length - $trim)
            if ($logUpper.Contains($shortKr)) { return $true }
        }
    }

    # ── TIER 2: Short label match (PREFIX+FIELD) ──
    $shortLabel = Get-ComboShortLabel $combo
    if ($shortLabel) {
        $escaped = [regex]::Escape($shortLabel.ToUpper())
        if ($logUpper -match "(^|[_\.\s])${escaped}([_\.\+\s]|$)") { return $true }
    }

    # ── TIER 3: Entity + exact prefix match ──
    if (-not $entity) { return $false }
    if (-not $logUpper.Contains($entity.ToUpper())) { return $false }

    $prefix = ""
    if ($kr -match '^(FRQ|FDQ|FBQ|NLTS|QB|QV|QW|QG|QA|BQ|RQ|DQ|KQ)') {
        $prefix = $Matches[1]
    }
    $dottedPrefix = ""
    if ($kr -match '^([A-Z]+\.[A-Z]+(?:\.[A-Z]+)?)') {
        $dottedPrefix = $Matches[1]
    }

    if ($prefix) {
        $pUpper = $prefix.ToUpper()
        if ($logUpper -match "[\._]${pUpper}[\+\._]|[\._]${pUpper}\b") {
            $shortLabel2 = Get-ComboShortLabel $combo
            if ($shortLabel2) {
                $fieldPart = ($shortLabel2 -split '\+', 2)[1]
                if ($fieldPart) {
                    $fUpper = $fieldPart.ToUpper()
                    if ($logUpper.Contains($fUpper)) { return $true }
                }
            }
        }
    }
    if ($dottedPrefix) {
        if ($logUpper.Contains($dottedPrefix.ToUpper())) { return $true }
    }

    return $false
}
