# report_cad_mapping.ps1
# Generates an HTML report mapping CAD field names to each provider JSON's
# field configuration. Shows sourceField→targetField per QIDM, plus
# unassociated fields at the bottom.
#
# Usage: .\report_cad_mapping.ps1 [-ProvidersDir <path>] [-OutFile <path>]
# Default: scans all *_BASE.json under providers/

param(
    [string]$ProvidersDir,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

if (-not $ProvidersDir) {
    $ProvidersDir = Join-Path (Split-Path $PSScriptRoot) 'providers'
}
if (-not (Test-Path $ProvidersDir)) { Write-Error "Providers dir not found: $ProvidersDir"; return }

if (-not $OutFile) {
    $OutFile = Join-Path (Split-Path $PSScriptRoot) 'docs' 'CAD_FIELD_MAPPING_REPORT.html'
    $docsDir = Split-Path $OutFile
    if (-not (Test-Path $docsDir)) { New-Item -ItemType Directory -Path $docsDir -Force | Out-Null }
}

# CAD field master list (camelCase) grouped by entity
$cadFields = [ordered]@{
    'Vehicle' = @(
        'licensePlateNumber','licensePlateTypeCode','licensePlateYear',
        'vehicleIdentificationNumber','registrationState','vehicleMakeCode',
        'vehicleYear','imageIndicator','addressCity','addressStreetNumber',
        'purposeCode','nameFirst','nameLast','nameMiddle','nameSuffix',
        'licensePlateColorCode'
    )
    'Person' = @(
        'operatorLicenseNumber','nameFirst','nameLast','nameMiddle','nameSuffix',
        'birthDate','sexCode','registrationState','imageIndicator','purposeCode',
        'raceCode','socialSecurityNumber','driverHistoryPurposeCode',
        'height','age','attention','criminalIdNumber',
        'address','addressCity','addressState','addressStreetName',
        'addressStreetNameSecond','addressStreetNumber','addressZipCode','addressZone',
        'hairColor','relatedHitSearchIndicator'
    )
    'Firearm' = @(
        'serialNumber','firearmMake','gunCaliber','gunModel','gunTypeCode',
        'imageIndicator','purposeCode','nameFirst','nameLast','nameMiddle',
        'nameSuffix','age','birthDate','relatedHitSearchIndicator','attention','address'
    )
    'Article' = @(
        'serialNumber','articleBrand','articleTypeCode','articleCategory',
        'ownerAppliedNumber','imageIndicator','purposeCode',
        'nameFirst','nameLast','nameMiddle','attention',
        'birthDate','relatedHitSearchIndicator'
    )
    'Boat' = @(
        'boatHullIdNumber','registrationNumber','registrationState',
        'ownerAppliedNumber','imageIndicator','purposeCode',
        'nameFirst','nameLast','nameMiddle','nameSuffix',
        'birthDate','relatedHitSearchIndicator','attention'
    )
}

# Find all BASE JSONs
$jsonFiles = Get-ChildItem -Path $ProvidersDir -Filter '*_BASE.json' -Recurse |
    Where-Object { $_.DirectoryName -notmatch '(archive|phases|release|v1[\\\/])' } |
    Sort-Object Name

if ($jsonFiles.Count -eq 0) { Write-Error "No *_BASE.json files found"; return }

# Extract data from each provider
$providers = [ordered]@{}

foreach ($jf in $jsonFiles) {
    $provName = $jf.BaseName -replace '_BASE$',''
    $data = Get-Content $jf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    $provInfo = @{
        Name = $provName
        Path = $jf.FullName
        Entities = @{}    # entity -> { qifFields = @{fieldId -> {label,type}}, qidms = @[ {query, attrs=@{sourceField->targetField}} ] }
    }

    foreach ($bundle in $data.bundles) {
        # QIF fields from ENTITIES bundle
        foreach ($config in $bundle.configurations) {
            if ($config.type -eq 'QUERYINPUTFORM') {
                $entity = $config.targetEntity
                if (-not $provInfo.Entities[$entity]) {
                    $provInfo.Entities[$entity] = @{ qifFields = @{}; qidms = @() }
                }

                # Scan layout nodes for field definitions
                $layoutObj = $null
                try { $layoutObj = $config.layout.default } catch {}
                if (-not $layoutObj) { try { $layoutObj = $config.layout.PSObject.Properties['default'].Value } catch {} }
                if (-not $layoutObj) { continue }

                foreach ($prop in $layoutObj.PSObject.Properties) {
                    $node = $prop.Value
                    if (-not $node.type) { continue }
                    $resolved = $null
                    try { $resolved = $node.type.resolvedName } catch {}
                    if (-not $resolved) { continue }

                    if ($resolved -in @('FormInput','FormSelect','FormDate','FormCheckbox')) {
                        $fid = $null
                        try { $fid = $node.props.fieldId } catch {}
                        if (-not $fid) { continue }

                        $lbl = ''
                        try { $lbl = $node.props.label } catch {}
                        $hidden = $false
                        try { $hidden = $node.props.hidden } catch {}

                        $provInfo.Entities[$entity].qifFields[$fid] = @{
                            label = $lbl
                            type = $resolved
                            hidden = $hidden
                        }
                    }
                }
            }

            # QIDM attributes from PROVIDER bundle
            if ($config.type -eq 'QUERYINPUTDATAMAPPING') {
                $entity = $config.targetEntity
                if (-not $provInfo.Entities[$entity]) {
                    $provInfo.Entities[$entity] = @{ qifFields = @{}; qidms = @() }
                }

                $qidm = @{
                    query = $config.query
                    queryLabel = ''
                    attrs = @{}
                }
                try { $qidm.queryLabel = $config.queryLabel } catch {}

                if ($config.attributes) {
                    foreach ($attr in $config.attributes) {
                        $srcFields = @()
                        if ($attr.sourceField) {
                            foreach ($sf in $attr.sourceField) { $srcFields += $sf }
                        }
                        $tgt = ''
                        try { $tgt = $attr.targetField } catch {}
                        $attrName = ''
                        try { $attrName = $attr.name } catch {}
                        $rule = ''
                        try { $rule = $attr.rule.function } catch {}
                        $ctp = ''
                        try { $ctp = $attr.codeTypeProvider } catch {}

                        foreach ($sf in $srcFields) {
                            $qidm.attrs[$sf] = @{
                                targetField = $tgt
                                name = $attrName
                                rule = $rule
                                codeTypeProvider = $ctp
                                allSourceFields = $srcFields
                            }
                        }
                    }
                }

                $provInfo.Entities[$entity].qidms += $qidm
            }
        }
    }

    $providers[$provName] = $provInfo
}

$provNames = @($providers.Keys)

# Build HTML
$html = @()
$html += '<!DOCTYPE html>'
$html += '<html><head><meta charset="utf-8">'
$html += '<title>CAD Field Mapping Report</title>'
$html += '<style>'
$html += 'body { font-family: Consolas, monospace; font-size: 12px; margin: 20px; background: #1e1e1e; color: #d4d4d4; }'
$html += 'h1 { color: #569cd6; font-size: 18px; }'
$html += 'h2 { color: #4ec9b0; font-size: 15px; margin-top: 30px; border-bottom: 1px solid #444; padding-bottom: 4px; }'
$html += 'h3 { color: #ce9178; font-size: 13px; margin-top: 20px; }'
$html += 'table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }'
$html += 'th { background: #264f78; color: #fff; padding: 6px 8px; text-align: left; font-size: 11px; position: sticky; top: 0; }'
$html += 'td { border: 1px solid #333; padding: 4px 8px; font-size: 11px; vertical-align: top; }'
$html += 'tr:nth-child(even) { background: #252526; }'
$html += 'tr:nth-child(odd) { background: #1e1e1e; }'
$html += '.match { color: #6a9955; }'
$html += '.diff { color: #d7ba7d; }'
$html += '.missing { color: #808080; font-style: italic; }'
$html += '.hidden { color: #569cd6; }'
$html += '.handler { color: #ce9178; font-size: 10px; }'
$html += '.ctp { color: #9cdcfe; font-size: 10px; }'
$html += '.unassoc { background: #3c2020; }'
$html += '.section-unassoc { color: #f44747; margin-top: 10px; font-weight: bold; }'
$html += '.toc a { color: #569cd6; text-decoration: none; margin-right: 15px; }'
$html += '.toc a:hover { text-decoration: underline; }'
$html += '</style></head><body>'
$html += "<h1>CAD Field Mapping Report</h1>"
$html += "<p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') | Providers: $($provNames.Count) | Entities: $($cadFields.Keys.Count)</p>"

# TOC
$html += '<div class="toc">'
foreach ($entity in $cadFields.Keys) {
    $html += "<a href=`"#$entity`">$entity</a>"
}
$html += '</div>'

foreach ($entity in $cadFields.Keys) {
    $html += "<h2 id=`"$entity`">$entity Entity</h2>"

    # Build header row
    $html += '<table><thead><tr><th>CAD Field (camelCase)</th>'
    foreach ($pn in $provNames) {
        $short = $pn -replace '_.*',''
        $html += "<th>$short</th>"
    }
    $html += '</tr></thead><tbody>'

    # Track which JSON fields are "associated" per provider
    $associatedFields = @{}
    foreach ($pn in $provNames) { $associatedFields[$pn] = @{} }

    # One row per CAD field
    foreach ($cadField in $cadFields[$entity]) {
        $html += "<tr><td><b>$cadField</b></td>"

        foreach ($pn in $provNames) {
            $prov = $providers[$pn]
            $entData = $prov.Entities[$entity]
            $cell = ''

            if (-not $entData) {
                $cell = '<span class="missing">no entity</span>'
                $html += "<td>$cell</td>"
                continue
            }

            # Check QIF field
            $qifMatch = $null
            # Try exact match first
            if ($entData.qifFields.ContainsKey($cadField)) {
                $qifMatch = $entData.qifFields[$cadField]
                $associatedFields[$pn][$cadField] = $true
            } else {
                # Try PascalCase match
                $pascal = $cadField.Substring(0,1).ToUpper() + $cadField.Substring(1)
                if ($entData.qifFields.ContainsKey($pascal)) {
                    $qifMatch = $entData.qifFields[$pascal]
                    $associatedFields[$pn][$pascal] = $true
                }
            }

            # Check QIDM mappings
            $qidmMappings = @()
            foreach ($qidm in $entData.qidms) {
                $attrInfo = $null
                if ($qidm.attrs.ContainsKey($cadField)) {
                    $attrInfo = $qidm.attrs[$cadField]
                    $associatedFields[$pn][$cadField] = $true
                } else {
                    $pascal = $cadField.Substring(0,1).ToUpper() + $cadField.Substring(1)
                    if ($qidm.attrs.ContainsKey($pascal)) {
                        $attrInfo = $qidm.attrs[$pascal]
                        $associatedFields[$pn][$pascal] = $true
                    }
                }
                if ($attrInfo) {
                    $mapping = "$cadField &rarr; $($attrInfo.targetField)"
                    $ql = $qidm.queryLabel
                    if (-not $ql) { $ql = $qidm.query -replace 'Query$','' }
                    $extra = ''
                    if ($attrInfo.rule) { $extra += "<br><span class=`"handler`">handler: $($attrInfo.rule)</span>" }
                    if ($attrInfo.codeTypeProvider) { $extra += "<br><span class=`"ctp`">codeType: $($attrInfo.codeTypeProvider)</span>" }
                    if ($attrInfo.allSourceFields.Count -gt 1) {
                        $extra += "<br><span class=`"handler`">multi: $($attrInfo.allSourceFields -join ' + ')</span>"
                    }
                    $qidmMappings += "<span class=`"match`">[$ql]</span> $mapping$extra"
                }
            }

            if ($qifMatch -and $qidmMappings.Count -gt 0) {
                $hiddenTag = if ($qifMatch.hidden -eq $true) { ' <span class="hidden">[hidden]</span>' } else { '' }
                $cell = "<span class=`"match`">QIF: $($qifMatch.type)</span>$hiddenTag<br>" + ($qidmMappings -join '<br>')
            } elseif ($qifMatch) {
                $hiddenTag = if ($qifMatch.hidden -eq $true) { ' <span class="hidden">[hidden]</span>' } else { '' }
                $cell = "<span class=`"diff`">QIF only: $($qifMatch.type) &quot;$($qifMatch.label)&quot;</span>$hiddenTag"
            } elseif ($qidmMappings.Count -gt 0) {
                $cell = ($qidmMappings -join '<br>')
            } else {
                $cell = '<span class="missing">--</span>'
            }

            $html += "<td>$cell</td>"
        }
        $html += '</tr>'
    }

    $html += '</tbody></table>'

    # Unassociated JSON fields (in provider but not in CAD list)
    $hasUnassoc = $false
    foreach ($pn in $provNames) {
        $prov = $providers[$pn]
        $entData = $prov.Entities[$entity]
        if (-not $entData) { continue }

        $unassocQif = @()
        foreach ($fid in $entData.qifFields.Keys) {
            $lower = $fid.Substring(0,1).ToLower() + $fid.Substring(1)
            if (-not $associatedFields[$pn].ContainsKey($fid) -and -not $associatedFields[$pn].ContainsKey($lower)) {
                $info = $entData.qifFields[$fid]
                $unassocQif += "$fid ($($info.type)$(if($info.hidden){' hidden'}))"
            }
        }

        $unassocQidm = @()
        foreach ($qidm in $entData.qidms) {
            foreach ($sf in $qidm.attrs.Keys) {
                $lower = $sf.Substring(0,1).ToLower() + $sf.Substring(1)
                if (-not $associatedFields[$pn].ContainsKey($sf) -and -not $associatedFields[$pn].ContainsKey($lower)) {
                    $tgt = $qidm.attrs[$sf].targetField
                    $ql = $qidm.queryLabel
                    if (-not $ql) { $ql = $qidm.query }
                    $unassocQidm += "$sf&rarr;$tgt [$ql]"
                    $associatedFields[$pn][$sf] = $true
                }
            }
        }

        if ($unassocQif.Count -gt 0 -or $unassocQidm.Count -gt 0) {
            if (-not $hasUnassoc) {
                $html += "<h3>Unassociated JSON Fields (not in CAD list)</h3>"
                $hasUnassoc = $true
            }
            $short = $pn -replace '_.*',''
            $html += "<p><b>$short ($entity):</b>"
            if ($unassocQif.Count -gt 0) {
                $html += "<br>QIF: " + ($unassocQif -join ', ')
            }
            if ($unassocQidm.Count -gt 0) {
                $html += "<br>QIDM: " + ($unassocQidm -join ', ')
            }
            $html += "</p>"
        }
    }

    # Unassociated CAD fields (in CAD list but not in any provider)
    $unassocCad = @()
    foreach ($cadField in $cadFields[$entity]) {
        $found = $false
        foreach ($pn in $provNames) {
            if ($associatedFields[$pn].ContainsKey($cadField)) { $found = $true; break }
            $pascal = $cadField.Substring(0,1).ToUpper() + $cadField.Substring(1)
            if ($associatedFields[$pn].ContainsKey($pascal)) { $found = $true; break }
        }
        if (-not $found) { $unassocCad += $cadField }
    }

    if ($unassocCad.Count -gt 0) {
        $html += "<p class=`"section-unassoc`">CAD fields not in ANY provider ($entity): " + ($unassocCad -join ', ') + "</p>"
    }
}

$html += '</body></html>'

$htmlContent = $html -join "`r`n"
$htmlContent | Out-File -FilePath $OutFile -Encoding UTF8
Write-Host "HTML report written to: $OutFile"
Write-Host "Providers scanned: $($provNames -join ', ')"
