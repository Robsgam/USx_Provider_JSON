<#
  import_picklists.ps1 -- merge usx_picklists_<provider>_<entity>.json downloads into
  providers/<P>/docs/reference/TENANT_PICKLISTS.json and validate current test values
  against the tenant's ACTUAL option lists.

  Validation report:
    FAIL  select with 0 options (empty tenant table -- CA gunTypeCode class... would have been)
    FAIL  the planned test value for a select matches no tenant option (NJ GunMake 'IMI' class)
    WARN  scope field missing from the capture / capture errors
    INFO  rendered selects that were not in the scope plan

  Usage: .\tools\import_picklists.ps1 -Path <file|dir>   (dir: all usx_picklists_*.json in it)
#>
param([Parameter(Mandatory)][string]$Path)

$files = @()
if (Test-Path $Path -PathType Container) { $files = @(Get-ChildItem $Path -Filter 'usx_picklists_*.json' -File) }
else { $files = @(Get-Item $Path) }
if (-not $files.Count) { Write-Error "No picklist capture files at $Path"; exit 1 }

$fail = 0; $warn = 0
$byProvider = @{}
foreach ($f in $files) {
    $cap = Get-Content $f.FullName -Raw | ConvertFrom-Json
    if (-not $cap.provider -or -not $cap.entity) { Write-Host "[import-picklists] WARN: $($f.Name) missing provider/entity -- skipped" -ForegroundColor Yellow; $warn++; continue }
    if (-not $byProvider.ContainsKey($cap.provider)) { $byProvider[$cap.provider] = @() }
    $byProvider[$cap.provider] += $cap
}

foreach ($prov in $byProvider.Keys) {
    $provDir = Join-Path (Join-Path $PSScriptRoot '..\providers') $prov
    if (-not (Test-Path $provDir)) { Write-Host "[import-picklists] FAIL: unknown provider $prov" -ForegroundColor Red; $fail++; continue }
    $refDir = Join-Path $provDir 'docs\reference'
    if (-not (Test-Path $refDir)) { New-Item -ItemType Directory -Path $refDir | Out-Null }
    $outPath = Join-Path $refDir 'TENANT_PICKLISTS.json'

    # Merge into existing (per-entity downloads accumulate)
    $doc = if (Test-Path $outPath) { Get-Content $outPath -Raw | ConvertFrom-Json } else { $null }
    $entities = [ordered]@{}
    if ($doc -and $doc.entities) { foreach ($e in $doc.entities.PSObject.Properties) { $entities[$e.Name] = $e.Value } }

    $version = $null
    foreach ($cap in $byProvider[$prov]) {
        # RECENCY GUARD (added 2026-09-01). A capture is EVIDENCE, so an OLDER one must never
        # overwrite a NEWER one -- but this loop was last-write-wins and did exactly that.
        # HOW IT BIT: two captures of the SAME entity can sit in Downloads at once, because Chrome
        # names a re-download '<name> (1).json'. '(1)' sorts BEFORE the bare name, so the watcher's
        # startup sweep fed the NEWER file first and the stale one second. That silently destroyed
        # CA_CLETS_OCATS' verified v2.11 Article capture (300 options, codeTypeSource CA_CLETS) by
        # replacing it with the v2.10 empty-table capture -- i.e. it reinstated the very defect the
        # v2.11 bump existed to fix, and the only reason it was noticed is that import_picklists'
        # own validation FAILed on the result. Recovered from git; the guard is so it cannot recur.
        $prior = $entities[$cap.entity]
        if ($prior -and $prior.capturedAt -and $cap.capturedAt) {
            $pT = try { [datetime]$prior.capturedAt } catch { $null }
            $cT = try { [datetime]$cap.capturedAt }   catch { $null }
            if ($pT -and $cT -and $cT -lt $pT) {
                Write-Host "[import-picklists] STALE SKIP $prov/$($cap.entity): capture $($cap.capturedAt) is OLDER than the stored $($prior.capturedAt) -- kept the newer one" -ForegroundColor Yellow
                $warn++
                continue
            }
        }
        # Take the HIGHEST version among ACCEPTED captures, not the last one processed. Assigning
        # unconditionally is what rolled the file's own version 2.11 -> 2.10 above. [version] cast,
        # not string compare: lexically '2.9' > '2.10', which is the wrong answer.
        if (-not $version) {
            $version = $cap.version
        } else {
            $cv = try { [version]"$($cap.version)" } catch { $null }
            $bv = try { [version]"$version" }        catch { $null }
            if ($cv -and $bv) { if ($cv -gt $bv) { $version = $cap.version } }
            elseif ($cap.version) { $version = $cap.version }
        }
        $entMap = [ordered]@{}
        foreach ($fld in @($cap.fields)) {
            # attributeTypeId carried through 2026-09-02 -- see emit_picklist_scope. Without it an
            # attributeTypeId-driven dropdown was stored with NO source identification at all.
            $entMap[$fld.fieldId] = [ordered]@{
                label = $fld.label; codeTypeCategory = $fld.codeTypeCategory; codeTypeSource = $fld.codeTypeSource
                attributeTypeId = $fld.attributeTypeId
                count = $fld.count; truncated = [bool]$fld.truncated; error = $fld.error; options = @($fld.options)
            }
        }
        $entities[$cap.entity] = [pscustomobject]@{ capturedAt = $cap.capturedAt; renderedSelectsNotInScope = @($cap.renderedSelectsNotInScope); fields = [pscustomobject]$entMap }
        Write-Host "[import-picklists] $prov/$($cap.entity): $(@($cap.fields).Count) select(s) merged" -ForegroundColor Cyan
        if (@($cap.renderedSelectsNotInScope).Count) { Write-Host "  INFO rendered selects not in scope: $(@($cap.renderedSelectsNotInScope) -join ', ')" -ForegroundColor DarkCyan }
    }

    [pscustomobject]@{ provider = $prov; version = $version; updatedAt = (Get-Date).ToString('s'); entities = [pscustomobject]$entities } |
        ConvertTo-Json -Depth 8 | Set-Content $outPath -Encoding utf8
    Write-Host "[import-picklists] wrote $outPath" -ForegroundColor Green

    # ── Validation: current plan's select fills vs tenant options ──
    $planPath = Get-ChildItem (Join-Path $provDir 'logs') -Filter "${prov}_TEST_PLAN_v*.json" -ErrorAction SilentlyContinue |
                Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
    $plan = if ($planPath) { Get-Content $planPath -Raw | ConvertFrom-Json } else { $null }

    foreach ($entName in $entities.Keys) {
        $ent = $entities[$entName]
        foreach ($fp in $ent.fields.PSObject.Properties) {
            $fld = $fp.Value
            if ($fld.error) { Write-Host "[import-picklists] WARN ${entName}.$($fp.Name): capture error: $($fld.error)" -ForegroundColor Yellow; $warn++; continue }
            if (-not @($fld.options).Count) {
                # Name whichever source the field actually declares. This used to print a bare
                # "()" for every attributeTypeId-driven dropdown, so the one fact the failure
                # exists to report -- WHICH tenant table is empty -- was missing exactly where it
                # matters most (DEX_INQUIRY_PURPOSE_CODE, LIMITATION #39).
                $srcDesc = if ($fld.codeTypeCategory -or $fld.codeTypeSource) { "$($fld.codeTypeCategory)/$($fld.codeTypeSource)" }
                           elseif ($fld.attributeTypeId) { "attributeTypeId=$($fld.attributeTypeId)" }
                           else { 'NO SOURCE DECLARED ON THE CONTROL' }
                Write-Host "[import-picklists] FAIL ${entName}.$($fp.Name): tenant table EMPTY ($srcDesc)" -ForegroundColor Red; $fail++; continue
            }
            if ($plan) {
                # Every distinct value the plan fills into this select must match an option
                # the way usx_lib matches (option text anchored at the code: ^CODE\b).
                $vals = @($plan.tests | ForEach-Object { @($_.fills) } | Where-Object { $_ -and $_.fieldId -eq $fp.Name } | ForEach-Object { "$($_.value)" } | Sort-Object -Unique)
                foreach ($v in $vals) {
                    $re = '^' + [regex]::Escape($v) + '\b'
                    if (-not @($fld.options | Where-Object { $_ -match $re }).Count) {
                        # The DOM capture only sees the first server page of large lists
                        # (~300, live-confirmed on GunMake/ArticleTypeCode). A miss in a
                        # truncated/large capture is INCONCLUSIVE, not a failure -- the live
                        # fill is the authority there (HI GunMake=IMI filled fine beyond
                        # the captured page). Small complete lists still hard-FAIL.
                        if ($fld.truncated -or @($fld.options).Count -ge 250) {
                            Write-Host "[import-picklists] WARN ${entName}.$($fp.Name): value '$v' not in the captured subset ($(@($fld.options).Count) of a larger list) -- inconclusive; verify by live fill" -ForegroundColor Yellow
                            $warn++
                        } else {
                            $suggest = @($fld.options)[0]
                            Write-Host "[import-picklists] FAIL ${entName}.$($fp.Name): test value '$v' matches NO tenant option (first option: '$suggest') -- fix via TEST_VALUE_OVERRIDES.txt" -ForegroundColor Red
                            $fail++
                        }
                    }
                }
            }
        }
    }
}

if ($fail) { Write-Host "[import-picklists] $fail FAIL / $warn WARN" -ForegroundColor Red; exit 1 }
Write-Host "[import-picklists] all validations PASS ($warn WARN)" -ForegroundColor Green
exit 0
