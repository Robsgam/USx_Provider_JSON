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
        [string[]]$FrOrder       = @('Vehicle','Person','Firearm','Article','Boat')
    )
    [PSCustomObject]@{
        configurations = $Configurations
        description    = 'Entity form configurations'
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

function Write-ProviderJson {
    param(
        [Parameter(Mandatory)]$BundleObject,
        [Parameter(Mandatory)][string]$OutPath,
        [Parameter(Mandatory)][string]$ReadablePath,
        [string]$PhasePath,
        [string]$Label
    )
    $json = $BundleObject | ConvertTo-Json -Depth 100 -Compress
    $jsonReadable = $BundleObject | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($OutPath,      $json,         [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($ReadablePath, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
    if ($PhasePath) {
        [System.IO.File]::WriteAllText($PhasePath, $json, [System.Text.UTF8Encoding]::new($false))
    }
    if ($Label) { Write-Host $Label }
    Write-Host "  -> $OutPath (minified)"
    Write-Host "  -> $ReadablePath (readable)"
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
}
