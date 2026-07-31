function Build-Auth {
    param(
        [Parameter(Mandatory)][string]$ProviderName,
        [array]$ExtraAttributes,
        [array]$ExtraAny
    )
    $attrs = [System.Collections.Generic.List[object]]::new()
    $attrs.Add([PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');      targetField = 'ORI' })
    $attrs.Add([PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic'); targetField = 'Mnemonic' })
    $attrs.Add([PSCustomObject]@{
        description = 'dexUserStateid from RMS profile'
        name        = 'UserName'
        rule        = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }
        sourceField = @('dexStateUserId')
        targetField = 'UserName'
    })
    if ($ExtraAttributes) { foreach ($a in $ExtraAttributes) { $attrs.Add($a) } }

    $anyFields = [System.Collections.Generic.List[string]]::new()
    $anyFields.Add('dexStateUserId')
    if ($ExtraAny) { foreach ($f in $ExtraAny) { $anyFields.Add($f) } }

    $displayName = ($ProviderName -replace '_',' ').Trim()
    [PSCustomObject]@{
        attributes  = @($attrs)
        combinations = @(
            [PSCustomObject]@{
                keyReference = 'AUTH'
                requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @($anyFields) }
            }
        )
        description                = "Authentication configuration for $displayName"
        handlerFunction            = 'CommsysOriAuthenticationHandler'
        name                       = $ProviderName
        type                       = 'AUTHENTICATION'
        deviceRegistrationOptional = $false
        provider                   = $ProviderName
        providerType               = 'Commsys'
        signInRequired             = $false
    }
}

function Build-Qmf {
    param([Parameter(Mandatory)][string]$ProviderName)
    [PSCustomObject]@{
        description          = 'Configuration for Query format'
        handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
        name                 = "${ProviderName}_QueryMessageFormat"
        type                 = 'QUERYMESSAGEFORMAT'
        authenticationParent = 'LawEnforcementTransaction'
        payloadParent        = 'LawEnforcementTransaction'
        provider             = $ProviderName
    }
}

function Build-ProviderQrdm {
    param([Parameter(Mandatory)][string]$ProviderName)
    $r = Build-CommsysQrdm -ProviderName $ProviderName
    $displayName = ($ProviderName -replace '_',' ').Trim()
    $r.name        = "${ProviderName}_Results"
    $r.description = "Results mapping for $displayName"
    $r.provider    = $ProviderName
    $r
}

function Build-EntitiesBundle {
    param(
        [Parameter(Mandatory)][array]$Configurations,
        [string[]]$DefaultOrder  = @('Vehicle','Person','Firearm','Article','Boat'),
        [string[]]$CadOrder      = @('Vehicle','Person','Firearm','Article','Boat'),
        [string[]]$FrOrder       = @('Vehicle','Person','Firearm','Article','Boat'),
        # Pass a version-stamped string (e.g. "Provider configuration for X v4.6 -- entity forms")
        # to embed the version near the top. Defaults to the generic label (no change for callers
        # that don't pass it). `description` is emitted FIRST so it renders at the top of the bundle.
        [string]$Description = 'Entity form configurations'
    )
    [PSCustomObject]@{
        description    = $Description
        configurations = $Configurations
        name           = 'ENTITIES'
        type           = 'BUNDLE'
        order          = [PSCustomObject]@{
            default         = $DefaultOrder
            CAD_DISPATCH    = $CadOrder
            FIRST_RESPONDER = $FrOrder
        }
        provider       = 'MARK43'
    }
}

# -----------------------------------------------------------------------------
# QIDM builders (opt-in convenience; promote the _A/_C patterns from
# _build_rms_bundle.ps1 to the CommSys provider QIDMs). Reduce ~200 lines of
# [PSCustomObject]@{...} boilerplate per build script.
#
# ADOPTION NOTE: output is SEMANTIC-identical and validator-clean, but property
# ORDER may differ from legacy hand-written attrs (ConvertTo-Json preserves
# insertion order; hand-written attrs vary -- e.g. BirthDate has rule before
# size, State has codeTypeProvider last). So adoption is a one-time reformat:
# verify with validate.ps1 + render_layout/test_commsys diff (combos/fields
# unchanged), NOT a byte-diff. Adopt per provider at its next rebuild.
# -----------------------------------------------------------------------------
function Build-QidmAttribute {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Size,
        [Parameter(Mandatory)][string[]]$SourceField,
        [string]$TargetField,
        [object]$Rule,                 # [PSCustomObject]@{ function=...; arguments=@(...) }
        [string]$CodeTypeProvider,     # e.g. 'NIBRS','NCIC'
        [string]$Description
    )
    if (-not $TargetField) { $TargetField = $Name }
    $o = [ordered]@{ name = $Name }
    if ($Rule) { $o.rule = $Rule }
    $o.size = $Size
    $o.sourceField = @($SourceField)
    $o.targetField = $TargetField
    if ($CodeTypeProvider) { $o.codeTypeProvider = $CodeTypeProvider }
    if ($Description)      { $o.description = $Description }
    [PSCustomObject]$o
}

function Build-QidmCombo {
    param(
        [Parameter(Mandatory)][string]$KeyReference,
        [Parameter(Mandatory)][string]$PrimaryFieldReference,
        [string[]]$Set = @(),
        [string[]]$Any = @(),
        [array]$Conditions,
        [array]$Defaults,
        [string]$State = 'In/Out'
    )
    $req = [ordered]@{ set = @($Set); any = @($Any) }
    if ($PSBoundParameters.ContainsKey('Conditions')) { $req.conditions = $Conditions }
    if ($PSBoundParameters.ContainsKey('Defaults'))   { $req.defaults   = $Defaults }
    [PSCustomObject]@{
        requirements          = [PSCustomObject]$req
        primaryFieldReference = $PrimaryFieldReference
        keyReference          = $KeyReference
        state                 = $State
    }
}

function Write-ProviderJson {
    param(
        [Parameter(Mandatory)]$BundleObject,
        [Parameter(Mandatory)][string]$OutPath,
        [string]$PhasePath,
        [string]$Label,
        [string]$Version
    )
    # NOTE: top-level `version` field omitted -- platform deserializes it as java.lang.Integer
    # and rejects the dotted string format (e.g. "4.5"). Version tracked in bundle description
    # and all docs; enforce CHECK 3i reads from description regex, not this field.
    $json = $BundleObject | ConvertTo-Json -Depth 100

    # SCRATCH-BUILD HOOK (reproducibility audit): when $env:REPRO_OUTPATH is set, any
    # build script writes to that scratch path instead of the committed JSON, skips the
    # phase archive, and skips the validator-abort -- so audit_reproducible.ps1 can run
    # the REAL build into a temp file without touching committed files. One central
    # change gives every build script this behavior. See tools/audit_reproducible.ps1.
    if ($env:REPRO_OUTPATH) {
        [System.IO.File]::WriteAllText($env:REPRO_OUTPATH, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  -> [REPRO] $($env:REPRO_OUTPATH) (scratch; phase archive + validator skipped)"
        return
    }

    # ONE-JSON-IN-ROOT cleanup: the root JSON name carries the version
    # (<PROVIDER>_v<X.Y>.json). On a version bump (or a switch from the old bare
    # name) the prior root JSON would otherwise linger, leaving two JSONs in root
    # and tripping enforce's one-JSON-in-root rule. Remove every sibling that is
    # the bare name or a versioned name for THIS provider, except the file we are
    # about to write. Phase archives live in phases/ and are never touched here.
    $outDir  = Split-Path $OutPath -Parent
    $outName = Split-Path $OutPath -Leaf
    # Provider prefix = output leaf minus any _v<X.Y> suffix and .json
    $prefix  = [System.IO.Path]::GetFileNameWithoutExtension($outName) -replace '_v[\d.]+$', ''
    if ($outDir -and (Test-Path $outDir)) {
        Get-ChildItem $outDir -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -ne $outName -and
                ($_.Name -eq "$prefix.json" -or $_.Name -match "^$([regex]::Escape($prefix))_v[\d.]+\.json$" -or $_.Name -match "^$([regex]::Escape($prefix))_(BASE|MC)\.json$")
            } |
            ForEach-Object {
                Write-Host "  -> removing stale root JSON: $($_.Name)" -ForegroundColor DarkYellow
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
    }

    [System.IO.File]::WriteAllText($OutPath, $json, [System.Text.UTF8Encoding]::new($false))
    if ($PhasePath) {
        [System.IO.File]::WriteAllText($PhasePath, $json, [System.Text.UTF8Encoding]::new($false))
    }
    if ($Label) { Write-Host $Label }
    Write-Host "  -> $OutPath"
    if ($PhasePath) { Write-Host "  -> $PhasePath (phase archive)" }

    $validatorPath = Join-Path $PSScriptRoot "validate.ps1"
    Write-Host ""
    Write-Host "Running structural validation..." -ForegroundColor Cyan
    powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OutPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
        exit 1
    }
    Write-Host "Validation passed." -ForegroundColor Green

    # ── TEST-PACKAGE FRESHNESS: a direct build MUST NOT leave a stale package ────────────────────
    # pipeline.ps1 calls reset_test_package.ps1 as its step 1, but invoking a provider's build script
    # DIRECTLY skipped it -- so the prior version's TEST_PLAN survived a version bump and kept naming
    # combos that no longer exist. That is not a cosmetic gap: audit_simulator_parity is a GLOBAL
    # cross-check over EVERY provider's plan, so one stale plan made [FAIL] simulator parity appear on
    # five unrelated providers, and the iterate-phase gate then flipped all six tested providers from
    # ENFORCED to BLOCKED. One self-inflicted defect, six providers' worth of false signal.
    #
    # This happened TWICE on 2026-07-31 -- CA_CONTRA_COSTA v2.2, then CA_eSUN v2.1 an hour later,
    # AFTER the rule had been written into the usx-build skill as Step 4b. A rule I demonstrably
    # ignore twice in one session is a MECHANISM problem, not a memory problem. So the build now does
    # it, the same way this function already refuses to leave a stale sibling root JSON above.
    #
    # reset_test_package is itself version-gated and idempotent: it archives logs and regenerates the
    # plan ONLY when the version actually changed, so a same-version rebuild is a no-op. Failure here
    # WARNS rather than aborts -- the JSON is already written and validated, and a reset problem must
    # not masquerade as a build failure.
    if ($Version) {
        $provDir  = Split-Path $OutPath -Parent
        $provName = Split-Path $provDir -Leaf
        $tvFile   = Join-Path $provDir 'logs\.test_version'
        $stamped  = if (Test-Path $tvFile) { (Get-Content $tvFile -Raw).Trim() } else { '' }
        if ($stamped -and ($stamped -replace '^v','') -ne ($Version -replace '^v','')) {
            Write-Host ""
            Write-Host "  Test package is stamped v$stamped but this build is v$Version -- resetting" -ForegroundColor Yellow
            $resetPath = Join-Path $PSScriptRoot 'reset_test_package.ps1'
            if (Test-Path $resetPath) {
                try {
                    & powershell.exe -ExecutionPolicy Bypass -File $resetPath -Provider $provName -Force 2>&1 |
                        Where-Object { $_ -match 'RESET|archived|reset |cleared|stamped|regenerated|WARN' } |
                        ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
                } catch {
                    Write-Host "  [WARN] reset_test_package failed: $_" -ForegroundColor Red
                    Write-Host "  [WARN] RUN IT MANUALLY: tools\reset_test_package.ps1 -Provider $provName -Force" -ForegroundColor Red
                }
            }
            Write-Host "  REMINDER: docs are NOT synced by a direct build -- run" -ForegroundColor Yellow
            Write-Host "    tools\build_report.ps1 -Path $OutPath ; tools\sync_version_docs.ps1 -Provider $provName ; tools\sync_provider_table.ps1" -ForegroundColor Yellow
            Write-Host "  (or just use tools\pipeline.ps1 -Provider $provName, which does all of it)" -ForegroundColor Yellow
        }
    }
}
