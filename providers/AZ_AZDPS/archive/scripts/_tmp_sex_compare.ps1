$az = Get-Content 'C:\Users\RobSgambellone\.local\bin\AZ_AZDPS\AZ_AZDPS.json' -Raw | ConvertFrom-Json
$nj = Get-Content 'C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS\NJ_NJCJIS.json'  -Raw | ConvertFrom-Json

# ── Form field ──────────────────────────────────────────────────────────────
function Get-SexFormFields($json, $label) {
    Write-Host ""
    Write-Host "=== $label -- QIF Sex form fields ===" -ForegroundColor Cyan
    foreach ($bundle in $json.bundles) {
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -eq 'QUERYINPUTFORM') {
                foreach ($layoutKey in $cfg.layout.PSObject.Properties.Name) {
                    $layout = $cfg.layout.$layoutKey
                    if ($layout -isnot [string]) {
                        foreach ($nodeKey in $layout.PSObject.Properties.Name) {
                            $node = $layout.$nodeKey
                            if ($node.props -and ($node.props.fieldId -match 'Sex')) {
                                Write-Host ("  form=" + $cfg.name + " layoutVariant=" + $layoutKey + " node=" + $nodeKey)
                                Write-Host ("  props=" + ($node.props | ConvertTo-Json -Compress))
                                break  # only need one layout variant to show the props
                            }
                        }
                    }
                }
            }
        }
    }
}

# ── CommSys QIDM SexCode attribute ──────────────────────────────────────────
function Get-SexQidmAttrs($json, $label) {
    Write-Host ""
    Write-Host "=== $label -- CommSys QIDM SexCode attributes ===" -ForegroundColor Cyan
    foreach ($bundle in $json.bundles) {
        if ($bundle.provider -ne 'MARK43' -and $bundle.name -ne 'RMS') {
            foreach ($cfg in $bundle.configurations) {
                if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') {
                    foreach ($attr in $cfg.attributes) {
                        if ($attr.targetField -match 'Sex|sex') {
                            Write-Host ("  bundle=" + $bundle.name + " qidm=" + $cfg.name)
                            Write-Host ("  attr=" + ($attr | ConvertTo-Json -Compress))
                        }
                    }
                }
            }
        }
    }
}

# ── RMS QIDM sex attribute ───────────────────────────────────────────────────
function Get-SexRmsAttrs($json, $label) {
    Write-Host ""
    Write-Host "=== $label -- RMS QIDM sex attributes ===" -ForegroundColor Cyan
    $rms = $json.bundles | Where-Object { $_.name -eq 'RMS' }
    foreach ($cfg in $rms.configurations) {
        if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') {
            foreach ($attr in $cfg.attributes) {
                if ($attr.targetField -match 'sex') {
                    Write-Host ("  qidm=" + $cfg.name + "  attr=" + ($attr | ConvertTo-Json -Compress))
                }
            }
        }
    }
}

Get-SexFormFields $az 'AZ_AZDPS'
Get-SexFormFields $nj 'NJ_NJCJIS'

Get-SexQidmAttrs $az 'AZ_AZDPS'
Get-SexQidmAttrs $nj 'NJ_NJCJIS'

Get-SexRmsAttrs $az 'AZ_AZDPS'
Get-SexRmsAttrs $nj 'NJ_NJCJIS'

Write-Host ""
Write-Host "=== RESULT OBSERVED ===" -ForegroundColor Yellow
Write-Host "  AZ CommSys: <SexCode>F</SexCode>              [codeTypeProvider=NIBRS reverse-lookup WORKED]"
Write-Host "  NJ CommSys: <SexCode>69585932695</SexCode>    [codeTypeProvider=NIBRS reverse-lookup DID NOT WORK]"
Write-Host "  AZ RMS:     sexAttrId:69585932695             [correct]"
Write-Host "  NJ RMS:     sexAttrId:69585932695             [correct]"
Write-Host ""
Write-Host "  JSON is identical. Behavior differs. Platform-level Sex/NIBRS code type"
Write-Host "  entries must exist under AZ_AZDPS but not under NJ_NJCJIS."
