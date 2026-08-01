<#
  audit_log_metadata.ps1 -- DIRECT log-vs-metadata integrity gate.

  The log-capture package exists to prove the CommSys query is 100% correct and every combination
  is accounted for. audit_log_content.ps1 proves each log matches the JSON-derived test PLAN;
  audit_metadata.ps1 proves the JSON matches the metadata XML. This tool closes the gap between
  them: it parses each captured COMMSYS wire XML and validates it DIRECTLY against the metadata --
  every element on the wire must be a metadata-defined field for that query, and the present-field
  set must satisfy a real metadata combination (not a Frankenstein).

  Exit 0 only when every current-version log is metadata-verified (or there are no logs to audit).
  Wired into enforce.ps1 PHASE 6 (6d) alongside the log-content gate.

  Usage: .\tools\audit_log_metadata.ps1 -Provider <name> [-Quiet]
#>
param(
    [Parameter(Mandatory)][string]$Provider,
    [switch]$Quiet
)

. (Join-Path $PSScriptRoot '_metadata_parse.ps1')
. (Join-Path $PSScriptRoot '_resolve_provider_json.ps1')
. (Join-Path $PSScriptRoot '_resolve_provider_xml.ps1')

function Out-Line($msg, $color = 'Gray') { if (-not $Quiet) { Write-Host $msg -ForegroundColor $color } }

$provDir = Join-Path (Join-Path $PSScriptRoot '..\providers') $Provider
if (-not (Test-Path $provDir)) { Write-Host "[audit-log-meta] provider dir not found: $Provider"; exit 0 }

# ── Active JSON + version ─────────────────────────────────────────────────────
$jsonPath = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $jsonPath) { Write-Host "[audit-log-meta] no active JSON for $Provider -- nothing to audit (PASS by absence)"; exit 0 }
$version = if ([System.IO.Path]::GetFileNameWithoutExtension($jsonPath) -match '_v([\d.]+)$') { $Matches[1] } else { $null }
if (-not $version) { Write-Host "[audit-log-meta] cannot derive version from $([System.IO.Path]::GetFileName($jsonPath)) -- skipping"; exit 0 }

# ── Metadata XML (audit_metadata.ps1:176-203 convention) ──────────────────────
$srcDir = Join-Path $provDir 'source'
# Shared resolver (_resolve_provider_xml.ps1) -- exact <PROVIDER>.xml, then base-provider fallback
# for variants, then the only XML present, and it REFUSES to guess between multiple candidates.
# Replaces a 3-tier hand-rolled glob whose middle tier ('notmatch old' + First 1) guessed
# alphabetically; that is the class that made audit_defect_classes read a JAWS-only excerpt.
$xmlResolved = Get-ProviderMetadataXml -Provider $Provider -ProvDir $provDir
$xml = if ($xmlResolved) { Get-Item $xmlResolved } else { $null }
# legacy: a stray XML directly in the provider root rather than source/
if (-not $xml) {
    $xml = Get-ChildItem $provDir -Filter '*.xml' -File -ErrorAction SilentlyContinue |
           Where-Object { $_.BaseName -ieq $Provider } | Select-Object -First 1
}
if (-not $xml) { Write-Host "[audit-log-meta] no metadata XML for $Provider -- nothing to audit (PASS by absence)"; exit 0 }

$meta = Get-MetadataTransactions -XmlPath $xml.FullName

# ── Discover current-version logs (mirror audit_log_content.ps1:36-37) ────────
$logs = @(Get-ChildItem (Join-Path $provDir 'logs') -Recurse -Filter "${Provider}_v${version}_*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]_archive_' })
if (-not $logs.Count) { Write-Host "[audit-log-meta] $Provider v$version -- no current-version logs to audit (nothing to validate)"; exit 0 }

# Envelope elements that live in <Request> but are not query fields.
$envelope = @('MessageType', 'Id', 'MessageContinueKeyCode')

$ok = 0; $bad = @()
foreach ($f in $logs) {
    $content = Get-Content $f.FullName -Raw
    $rel = "$($f.Directory.Name)\$($f.Name)"

    # Isolate the COMMSYS XML body.
    if ($content -notmatch '(?s)COMMSYS XML\s*-+\s*(<\?xml.*?</api:ConnectCicApi>)') {
        $bad += "${rel}: no parseable COMMSYS XML"; continue
    }
    $xmlBody = $Matches[1]
    try { $doc = [xml]$xmlBody } catch { $bad += "${rel}: COMMSYS XML not well-formed"; continue }

    $reqNode = $doc.SelectNodes('//*') | Where-Object { $_.LocalName -eq 'Request' } | Select-Object -First 1
    if (-not $reqNode) { $bad += "${rel}: no <Request> element"; continue }

    $mt = ($reqNode.ChildNodes | Where-Object { $_.LocalName -eq 'MessageType' } | Select-Object -First 1).InnerText
    if (-not $mt) { $bad += "${rel}: no <MessageType>"; continue }

    # (a) query must exist in metadata
    if (-not $meta.ContainsKey($mt)) {
        $bad += "${rel}: MessageType '$mt' not defined in metadata"; continue
    }
    $tx = $meta[$mt]

    # Present <Request> fields (KEEP form-only -- some, e.g. State, are metadata combo set members).
    $present = @($reqNode.ChildNodes | ForEach-Object { $_.LocalName } |
        Where-Object { $_ -and ($envelope -notcontains $_) })

    # (b) every present field must be a metadata field for this query OR a known form-only field.
    $unknown = @()
    foreach ($p in $present) {
        $known = (Test-MetaFormOnly $p)
        if (-not $known) { foreach ($mf in $tx.fields) { if (Test-MetaFieldEquiv $p $mf) { $known = $true; break } } }
        if (-not $known) { $unknown += $p }
    }
    if ($unknown.Count) {
        $bad += "${rel} [$mt]: wire field(s) not defined in metadata: $($unknown -join ', ')"; continue
    }

    # (c) present fields must satisfy at least one metadata combo's required set[]. Extras are
    #     allowed -- they are metadata/form-only fields already validated by (b), and metadata
    #     combos do not enumerate every optional field (an extra-field rejection would false-fail,
    #     e.g. VehicleMakeCode sent alongside a plate). This proves a real routing identifier is
    #     present; mutual-exclusion / winner-only wire is audit_log_content's job.
    $matched = $false
    foreach ($combo in $tx.combos) {
        foreach ($reqSet in $combo.requiredSets) {
            if (-not @($reqSet).Count) { continue }
            $setOk = $true
            foreach ($s in $reqSet) {
                $has = $false
                foreach ($p in $present) { if (Test-MetaFieldEquiv $p $s) { $has = $true; break } }
                if (-not $has) { $setOk = $false; break }
            }
            if ($setOk) { $matched = $true; break }
        }
        if ($matched) { break }
    }
    if (-not $matched) {
        $fieldList = if ($present.Count) { $present -join ', ' } else { '(none)' }
        $bad += "${rel} [$mt]: wire field-set {$fieldList} satisfies no metadata combo set[]"; continue
    }

    $ok++
}

Out-Line "[audit-log-meta] $Provider v$version -- $($logs.Count) log(s) checked against metadata"
if ($bad.Count) {
    Out-Line "  OK: $ok"
    Out-Line "  METADATA MISMATCH:" 'Red'
    foreach ($b in $bad) { Out-Line "    $b" 'Red' }
    Write-Host "[audit-log-meta] $Provider FAIL: $($bad.Count) log(s) not metadata-verified" -ForegroundColor Red
    exit 1
}
Write-Host "[audit-log-meta] $Provider PASS: $ok/$($logs.Count) log(s) metadata-verified" -ForegroundColor Green
exit 0
