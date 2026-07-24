# _build_rms_bundle.ps1 — Shared module: RMS bundle + CommSys QRDM
# Defines all RMS and CommSys result-mapping data from KB specs.
# No external template dependencies (no HIDLE.json).
#
# Usage: dot-source in build scripts, call Build-RmsBundle / Build-CommsysQrdm
#   . "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"
#   $rmsBundle = Build-RmsBundle                         # standard (no SSN, with race)
#   $rmsBundle = Build-RmsBundle -KeepSsn                # AZ, TN
#   $rmsBundle = Build-RmsBundle -SkipRace               # TX_TLETS, TX_TLETS_CCH, LA_LEMS, MD_METERS, CA_CONTRA_COSTA, CA_CLETS
#   $results   = Build-CommsysQrdm -ProviderName 'FL_FCIC'

# =====================================================================
# HELPERS
# =====================================================================
function _A($n, $sf, $tf, $extra) {
    $a = [ordered]@{ name = $n; sourceField = @($sf); targetField = $tf }
    if ($extra) { foreach ($k in $extra.Keys) { $a[$k] = $extra[$k] } }
    [PSCustomObject]$a
}
function _As($n) { [PSCustomObject]@{ name = $n; sourceField = @($n); targetField = $n } }
function _R($fn, $ruleArgs) {
    # NOTE: param renamed from $args (PowerShell reserved automatic var) — the
    # collision silently dropped every passed arguments array (regression vs the
    # HIDLE engineering baseline). When no args are supplied, omit the property
    # entirely to match the HIDLE baseline (which had no 'arguments' key on
    # no-arg handlers), rather than emitting null/[].
    if ($null -eq $ruleArgs) { [PSCustomObject]@{ function = $fn } }
    else { [PSCustomObject]@{ function = $fn; arguments = $ruleArgs } }
}
function _C($kr, $set, $any, $pfr) {
    $req = [ordered]@{ set = $set; any = $any; conditions = $null; defaults = $null }
    $c = [ordered]@{ requirements = [PSCustomObject]$req; keyReference = $kr }
    if ($pfr) { $c['primaryFieldReference'] = $pfr }
    [PSCustomObject]$c
}

# Canonical PascalCase for the USx CAD-integration form fields that the RMS
# Person/Vehicle search QIDMs read FROM the form (sourceField / set / any). Only
# these form-fed references are recased; Mark43-internal targetFields, response
# QRDM names, and non-USx tokens (raceCode, SocialSecurityNumber) stay as-is.
$script:UsxPascalMap = @{
    vehicleIdentificationNumber = 'VehicleIdentificationNumber'
    licensePlateNumber          = 'LicensePlateNumber'
    registrationState           = 'RegistrationState'
    nameFirst                   = 'NameFirst'
    nameLast                    = 'NameLast'
    operatorLicenseNumber       = 'OperatorLicenseNumber'
    birthDate                   = 'BirthDate'
    sexCode                     = 'SexCode'
}
# _U recases a form-field reference array to PascalCase when the calling
# Build-RmsBundle was invoked with -PascalCaseUsxFields (read via dynamic scope).
# Tokens absent from the map pass through unchanged. Always returns an array.
function _U($arr) {
    if (-not $PascalCaseUsxFields) { return ,@($arr) }
    ,@($arr | ForEach-Object {
        if ($_ -and $script:UsxPascalMap.ContainsKey([string]$_)) { $script:UsxPascalMap[[string]$_] } else { $_ }
    })
}

# =====================================================================
# Build-RmsBundle — Constructs the complete RMS bundle from KB specs
# =====================================================================
function Build-RmsBundle {
    param(
        [switch]$KeepSsn,             # AZ, TN: include socialSecurityNumber attr + combo
        [switch]$SkipRace,            # TX, LA, MD, CA_CONTRA_COSTA: exclude race attr + raceCode from any[]
        [switch]$PascalCaseUsxFields, # NJ, FL, HI: form-fed sourceField/set/any in PascalCase (match PascalCase form fieldIds)
        # Pass a version-stamped string (e.g. "Provider configuration for X v4.6 -- RMS bundle")
        # to embed the version. Defaults to the generic label (no change for callers that don't pass it).
        [string]$Description = 'Provider configuration for RMS'
    )

    # --- RMS AUTHENTICATION (REST) ---
    $rmsAuth = [PSCustomObject]@{
        attributes = @(
            [PSCustomObject]@{ description = 'Mark43 cookie'; name = 'M43Cookie'; sourceField = @('Cookie'); targetField = 'cookie' }
            [PSCustomObject]@{ description = 'Mark43 API token'; name = 'M43APIToken'; sourceField = @('ApiToken'); targetField = 'x-api-token' }
            [PSCustomObject]@{ description = 'M43 Authorization token'; name = 'M43AuthorizationToken'; sourceField = @('Authorization'); targetField = 'Authorization' }
        )
        combinations = @(
            [PSCustomObject]@{
                requirements = [PSCustomObject]@{ set = $null; any = @('Authorization','ApiToken','Cookie'); conditions = $null; defaults = $null }
            }
        )
        description                = 'Authentication configuration for RMS'
        handlerFunction            = 'RestAuthenticationHandler'
        name                       = 'RMS'
        type                       = 'AUTHENTICATION'
        deviceRegistrationOptional = $true
        provider                   = 'RMS'
    }

    # --- RMS QUERYMESSAGEFORMAT (REST) ---
    $rmsQmf = [PSCustomObject]@{
        description         = 'Configuration for Query format'
        handlerFunction     = 'RestRequestHandler'
        name                = 'RMS_QueryMessageFormat'
        type                = 'QUERYMESSAGEFORMAT'
        url                 = [PSCustomObject]@{
            person  = [PSCustomObject]@{ protocol = 'https'; path = '/rms/api/elastic_search/persons';  addDepartmentSubdomain = $true }
            vehicle = [PSCustomObject]@{ protocol = 'https'; path = '/rms/api/elastic_search/vehicles'; addDepartmentSubdomain = $true }
        }
        authenticationParent = 'headers'
        payloadParent        = 'body'
    }

    # --- RMS VEHICLE QIDM (3 attrs, 2 combos — primary keys only, no year/make/model filtering) ---
    $rmsVeh = [PSCustomObject]@{
        attributes = @(
            [PSCustomObject]@{ name = 'vinNumber';            sourceField = (_U @('vehicleIdentificationNumber')); targetField = 'vehicle.vinNumber' }
            [PSCustomObject]@{ name = 'licensePlateNumber';   sourceField = (_U @('licensePlateNumber'));           targetField = 'vehicle.tag' }
            [PSCustomObject]@{
                name            = 'registrationState'
                rule            = _R 'AttributeArrayWrapperRuleHandler' $null
                sourceField     = (_U @('registrationState'))
                targetField     = 'vehicle.registrationStateAttrIds'
                useAttributeId  = $true
            }
        )
        combinations = @(
            _C 'vehicleIdentificationNumber' (_U @('vehicleIdentificationNumber')) (_U @('licensePlateNumber','registrationState')) $null
            _C 'licensePlateIn'              (_U @('licensePlateNumber'))           (_U @('registrationState')) $null
        )
        description     = 'Configuration for handling elastic query with various attributes'
        handlerFunction = 'RmsRestPayloadHandler'
        name            = 'RMS Vehicle search query'
        type            = 'QUERYINPUTDATAMAPPING'
        provider        = 'RMS'
        query           = 'Vehicle'
        queryLabel      = 'RMS'
        targetEntity    = 'Vehicle'
        autoSelect      = $true
    }

    # --- RMS PERSON QIDM (parameterized) ---
    $personAny = [System.Collections.Generic.List[string]]::new()
    if (-not $SkipRace) { $personAny.Add('raceCode') }
    $personAny.Add('sexCode')
    $personAny.Add('registrationState')
    $anyArr = (_U @($personAny))

    $personAttrs = [System.Collections.Generic.List[object]]::new()
    $personAttrs.Add([PSCustomObject]@{ name = 'firstName';     size = 60; sourceField = (_U @('nameFirst'));              targetField = 'firstName' })
    $personAttrs.Add([PSCustomObject]@{ name = 'lastName';      size = 60; sourceField = (_U @('nameLast'));               targetField = 'lastName' })
    $personAttrs.Add([PSCustomObject]@{ name = 'licenseNumber'; size = 60; sourceField = (_U @('operatorLicenseNumber'));  targetField = 'dlNumber' })
    $personAttrs.Add([PSCustomObject]@{ name = 'dateOfBirth';              sourceField = (_U @('birthDate'));              targetField = 'dateOfBirth' })
    if (-not $SkipRace) {
        $personAttrs.Add([PSCustomObject]@{
            name           = 'race'
            rule           = _R 'AttributeArrayWrapperRuleHandler' $null
            sourceField    = @('raceCode')
            targetField    = 'raceAttrIds'
            useAttributeId = $true
        })
    }
    $personAttrs.Add([PSCustomObject]@{ name = 'sex'; sourceField = (_U @('sexCode')); targetField = 'sexAttrId'; useAttributeId = $true })
    $personAttrs.Add([PSCustomObject]@{ name = 'registrationState'; sourceField = (_U @('registrationState')); targetField = 'registrationStateAttrId'; useAttributeId = $true })
    if ($KeepSsn) {
        $personAttrs.Add([PSCustomObject]@{ name = 'socialSecurityNumber'; size = 60; sourceField = @('SocialSecurityNumber'); targetField = 'ssn' })
    }

    $personCombos = [System.Collections.Generic.List[object]]::new()
    if ($KeepSsn) {
        $personCombos.Add((_C 'firstNameLastNameSocialSecurityNumber' (_U @('SocialSecurityNumber','nameFirst','nameLast')) $anyArr $null))
    }
    $personCombos.Add((_C 'firstNameLastNameDriversLicenseNumber' (_U @('operatorLicenseNumber','nameFirst','nameLast')) $anyArr $null))
    $personCombos.Add((_C 'firstNameLastNameDateOfBirth'          (_U @('nameFirst','nameLast','birthDate'))             $anyArr $null))
    $personCombos.Add((_C 'firstNameLastName'                     (_U @('nameFirst','nameLast'))                         $anyArr $null))
    $personCombos.Add((_C 'driversLicenseNumber'                  (_U @('operatorLicenseNumber'))                        $anyArr $null))

    $rmsPer = [PSCustomObject]@{
        attributes      = @($personAttrs)
        combinations    = @($personCombos)
        description     = 'Configuration for handling elastic query with various attributes'
        handlerFunction = 'RmsRestPayloadHandler'
        name            = 'RMS Person Search query'
        type            = 'QUERYINPUTDATAMAPPING'
        provider        = 'RMS'
        query           = 'Person'
        queryLabel      = 'RMS'
        targetEntity    = 'Person'
        autoSelect      = $true
    }

    # --- RMS QRDM (72 attrs, 2 combos — result display mapping) ---
    $rmsQrdmAttrs = @(
        _A 'AddressCity'    'mainLocation.locationAddress.locality'                 'AddressCity'
        _A 'AddressState'   'mainLocation.locationAddress.administrativeAreaLevel1' 'AddressState'
        _A 'AddressStreet'  'mainLocation.locationAddress.streetAddress'            'AddressStreet'
        _A 'AddressZipCode' 'mainLocation.locationAddress.postalCode'              'AddressZipCode'
        _A 'birthDate'      'dateOfBirth'           'BirthDate'
        _A 'EyeColorCode'   'eyeColorAttrDetail.displayValue'  'EyeColorCode'
        _A 'HairColorCode'  'hairColorAttrDetail.displayValue'  'HairColorCode'
        _A 'nameFirst'      'firstName'             'NameFirst'
        _A 'nameLast'       'lastName'              'NameLast'
        _A 'RaceCode'       'raceAttrDetail.displayValue'       'RaceCode'
        _A 'sexCode'        'sexAttrDetail.displayValue'        'SexCode'
        _A 'SocialSecurityNumber' 'ssn'             'SocialSecurityNumber'
        _A 'VehicleColorCode'     'primaryColorAttrDetail.displayValue' 'VehicleColorCode'
        _A 'vehicleIdentificationNumber' 'vinNumber'                    'VehicleIdentificationNumber'
        _A 'vehicleMakeCode'     'makeNcicCode'                        'VehicleMakeCode'
        _A 'VehicleModelCode'    'modelNcicCode'                       'VehicleModelCode'
        _A 'vehicleYear'         'yearOfManufacture'                   'VehicleYear'
        _A 'RegistrationYear'    'registrationYear'                    'RegistrationYear'
        _A 'BodyStyle'           'itemCategoryAttrDetail.displayValue' 'BodyStyle'
        _A 'licensePlateNumber'  'tag'                                 'LicensePlateNumber'
        _A 'RegistrationStateCode' 'registrationStateAttrDetail.displayValue' 'RegistrationStateCode'
        _A 'VehicleInsurance'    'insuranceProviderName'               'VehicleInsurance'
        _A 'VehicleMakeName'     'vehicleMakeOther'                   'VehicleMakeName'
        _A 'VehicleModelName'    'vehicleModelOther'                   'VehicleModelName'
        _A 'Weight'              'weight'                              'Weight'
        _A 'operatorLicenseNumber' 'dlNumber'                          'OperatorLicenseNumber'
        _A 'Age'                 'age'                                 'Age'
        _A 'Mark43Id'            'id'                                  'Mark43Id'
        _A 'Alias'               'nicknames.0'                         'Alias'
        _A 'AliasBirthDate'      'dateOfBirthOthers.0'                'AliasBirthDate'
        _A 'Phone'               'phoneNumbers.0'                      'Phone'
        # Cautions (person — nameAttributes)
        [PSCustomObject]@{
            name = 'Cautions'
            rule = _R 'FormatArrayRuleHandler' @(
                ,@('entityType','nameId','nameAttrDetail.id','nameAttrDetail.displayValue','nameAttrDetail.type')
                ,@('entityType','id','attributeId','displayValue','type')
            )
            sourceField = @('nameAttributes')
            targetField = 'Cautions'
        }
        _A 'HasPotentialActiveWarrant' 'hasPotentialActiveWarrant' 'HasPotentialActiveWarrant'
        # Warrants (complex FormatArrayRuleHandler)
        [PSCustomObject]@{
            name = 'Warrants'
            rule = _R 'FormatArrayRuleHandler' @(
                ,@('warrantId','warrantNumber','warrantTypeAttrDetail.displayValue','warrantStatusAttrDetail.displayValue','warrantIssuedDateUtc','warrantCharges[chargeName,chargeCount,offenseClassificationAttrDetail.displayValue,offenseDateUtc]')
                ,@('Id','Number','Type','Status','IssuedDateUtc','Charges[Name,Count,OffenseClassification,OffenseDateUtc]')
            )
            sourceField = @('warrantDetails')
            targetField = 'WarrantDetails'
        }
        _A 'IsJuvenile'           'isJuvenile'           'IsJuvenile'
        _A 'IsSuspectedGangMember' 'isSuspectedGangMember' 'IsSuspectedGangMember'
        _A 'IsVulnerable'         'isVulnerable'         'IsVulnerable'
        _A 'IsActiveTarget'       'isActiveTarget'        'IsActiveTarget'
        _A 'DateVulnerableTo'     'dateVulnerableTo'      'DateVulnerableTo'
        _A 'IsStolen'             'isStolen'              'IsStolen'
        # Cautions (vehicle — itemAttributes)
        [PSCustomObject]@{
            name = 'Cautions'
            rule = _R 'FormatArrayRuleHandler' @(
                ,@('entityType','itemProfileId','itemAttrDetail.id','itemAttrDetail.displayValue','itemAttrDetail.type')
                ,@('entityType','id','attributeId','displayValue','type')
            )
            sourceField = @('itemAttributes')
            targetField = 'Cautions'
        }
        # Addresses (FormatArrayRuleHandler)
        [PSCustomObject]@{
            name = 'Addresses'
            rule = _R 'FormatArrayRuleHandler' @(
                ,@('type','id','locationAddress.streetAddress','locationAddress.streetNumber','locationAddress.locality','locationAddress.country','locationAddress.postalCode')
                ,@('type','attributeId','streetAddress','streetNumber','locality','country','postalCode')
            )
            sourceField = @('involvedLocations')
            targetField = 'Addresses'
        }
        # IdentifyingMarks (FormatArrayRuleHandler)
        [PSCustomObject]@{
            name = 'IdentifyingMarks'
            rule = _R 'FormatArrayRuleHandler' @(
                ,@('id','description','bodyPartAttrDetail.displayValue','identifyingMarkTypeAttrDetail.displayValue')
                ,@('attributeId','description','bodyPart','identifyingMarkType')
            )
            sourceField = @('identifyingMarks')
            targetField = 'IdentifyingMarks'
        }
        _A 'Ethnicity'          'ethnicityAttrDetail.displayValue'      'Ethnicity'
        _A 'EthnicityAttrId'    'ethnicityAttrDetail.id'                'EthnicityAttrId'
        _A 'FacialHairType'     'facialHairTypeAttrDetail.displayValue' 'FacialHairType'
        _A 'FacialHairTypeAttrId' 'facialHairTypeAttrDetail.id'         'FacialHairTypeAttrId'
        _A 'HairColor'          'hairColorAttrDetail.displayValue'      'HairColor'
        _A 'HairColorAttrId'    'hairColorAttrDetail.id'                'HairColorAttrId'
        _A 'HairStyle'          'hairStyleAttrDetail.displayValue'      'HairStyle'
        _A 'HairStyleAttrId'    'hairStyleAttrDetail.id'                'HairStyleAttrId'
        _A 'HairLength'         'hairLengthAttrDetail.displayValue'     'HairLength'
        _A 'HairLengthAttrId'   'hairLengthAttrDetail.id'              'HairLengthAttrId'
        _A 'SkinTone'           'skinToneAttrDetail.displayValue'       'SkinTone'
        _A 'SkinToneAttrId'     'skinToneAttrDetail.id'                'SkinToneAttrId'
        _A 'Build'              'buildAttrDetail.displayValue'          'Build'
        _A 'BuildAttrId'        'buildAttrDetail.id'                   'BuildAttrId'
        _A 'Vision'             'visionAttrDetail.displayValue'         'Vision'
        _A 'VisionAttrId'       'visionAttrDetail.id'                  'VisionAttrId'
        # HeightDisplay (HeightParserRuleHandler)
        [PSCustomObject]@{
            name = 'HeightDisplay'
            rule = _R 'HeightParserRuleHandler' @(,@('heightFeet','heightInches'),'height')
            sourceField = @('HeightDisplay')
            targetField = 'HeightDisplay'
        }
        [PSCustomObject]@{
            name = 'HeightFeet'
            rule = _R 'HeightParserRuleHandler' @(,@('heightFeet','heightInches'),'feet')
            sourceField = @('HeightFeet')
            targetField = 'HeightFeet'
        }
        [PSCustomObject]@{
            name = 'HeightInches'
            rule = _R 'HeightParserRuleHandler' @(,@('heightFeet','heightInches'),'inches')
            sourceField = @('HeightInches')
            targetField = 'HeightInches'
        }
        [PSCustomObject]@{
            name = 'Height'
            rule = _R 'HeightParserRuleHandler' @(,@('heightFeet','heightInches'),'total')
            sourceField = @('Height')
            targetField = 'Height'
        }
        _A 'PhoneNumbers'       'phoneNumbers'     'PhoneNumbers'
        _A 'RegistrationStateAttrId' 'registrationStateAttrDetail.id' 'RegistrationStateAttrId'
        _A 'VehicleColorAttrId' 'primaryColorAttrDetail.id'           'VehicleColorAttrId'
        _A 'EyeColorAttrId'    'eyeColorAttrDetail.id'               'EyeColorAttrId'
        _A 'BodyStyle'          'itemCategoryAttrDetail.id'           'BodyStyle'
        _A 'RaceAttrId'         'raceAttrDetail.id'                   'RaceAttrId'
        _A 'SexAttrId'          'sexAttrDetail.id'                    'SexAttrId'
        _A 'nameMiddle'         'middleNameAnalyzed'                  'NameMiddle'
        # Name (FormatNameRuleHandler)
        [PSCustomObject]@{
            name = 'Name'
            rule = _R 'FormatNameRuleHandler' @(
                ,@('firstName','lastName','middleNameAnalyzed')
                ,@(', ',' ',' ')
            )
            sourceField = @('name')
            targetField = 'Name'
        }
    )

    $rmsQrdmCombos = @(
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = $null
                any = @(
                    'mainLocation.locationAddress.locality','mainLocation.locationAddress.administrativeAreaLevel1',
                    'mainLocation.locationAddress.streetAddress','mainLocation.locationAddress.postalCode',
                    'dateOfBirth','eyeColorAttrDetail.displayValue','eyeColorAttrDetail.id',
                    'hairColorAttrDetail.displayValue','hairColorAttrDetail.id',
                    'height','heightDisplay','heightFeet','heightInches',
                    'firstName','lastName','race','sex','ssn','vinNumber','weight',
                    'sexAttrDetail.displayValue','sexAttrDetail.id',
                    'raceAttrDetail.displayValue','raceAttrDetail.id',
                    'dlNumber','age','nicknames.0','phoneNumbers.0','id','dateOfBirthOthers.0',
                    'hasPotentialActiveWarrant','warrantDetails','isJuvenile','isSuspectedGangMember',
                    'isVulnerable','isActiveTarget','nameAttributes','dateVulnerableTo',
                    'involvedLocations','identifyingMarks','phoneNumbers',
                    'ethnicityAttrDetail.displayValue','hairStyleAttrDetail.displayValue',
                    'hairLengthAttrDetail.displayValue','skinToneAttrDetail.displayValue',
                    'buildAttrDetail.displayValue','visionAttrDetail.displayValue',
                    'facialHairTypeAttrDetail.displayValue','facialHairTypeAttrDetail.id',
                    'ethnicityAttrDetail.id','hairStyleAttrDetail.id','hairLengthAttrDetail.id',
                    'skinToneAttrDetail.id','buildAttrDetail.id','visionAttrDetail.id',
                    'middleNameAnalyzed','name'
                )
                conditions = $null
                defaults   = $null
            }
            primaryFieldReference = 'Person'
            keyReference          = 'Person'
        }
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = $null
                any = @(
                    'primaryColor','vinNumber','makeNcicCode','modelNcicCode','vehicleYear',
                    'itemAttributes','id','tag',
                    'registrationStateAttrDetail.displayValue','registrationStateAttrDetail.id',
                    'registrationYear','yearOfManufacture',
                    'itemCategoryAttrDetail.displayValue','itemCategoryAttrDetail.id',
                    'insuranceProviderName',
                    'primaryColorAttrDetail.displayValue','primaryColorAttrDetail.id',
                    'vehicleMakeOther','vehicleModelOther','isStolen','isActiveTarget'
                )
                conditions = $null
                defaults   = $null
            }
            primaryFieldReference = 'Vehicle'
            keyReference          = 'Vehicle'
        }
    )

    $rmsQrdm = [PSCustomObject]@{
        attributes      = $rmsQrdmAttrs
        combinations    = $rmsQrdmCombos
        description     = 'Results mapping for RMS search'
        handlerFunction = 'RmsRestResultsHandler'
        label           = 'RMS'
        name            = 'RMS_Results'
        type            = 'QUERYRESULTDATAMAPPING'
        provider        = 'RMS'
        providerType    = 'RMS'
    }

    # --- RMS RESULTS LAYOUT (empty — platform handles display) ---
    $rmsLayout = [PSCustomObject]@{
        description     = 'Results layout for RMS'
        handlerFunction = 'QueryResultsLayoutHandler'
        label           = 'Results layout'
        name            = 'RMS_ResultsLayout'
        type            = 'QUERYRESULTSLAYOUT'
        layouts         = [PSCustomObject]@{}
        provider        = 'RMS'
        providerType    = 'RMS'
    }

    # --- ASSEMBLE BUNDLE (description first for near-the-top version visibility) ---
    return [PSCustomObject]@{
        description    = $Description
        name           = 'RMS'
        type           = 'BUNDLE'
        provider       = 'RMS'
        configurations = @($rmsAuth, $rmsQmf, $rmsPer, $rmsVeh, $rmsQrdm, $rmsLayout)
    }
}

# =====================================================================
# Build-CommsysQrdm — Constructs the CommSys QRDM for the PROVIDER bundle
# =====================================================================
function Build-CommsysQrdm {
    param(
        [Parameter(Mandatory)][string]$ProviderName
    )

    $attrs = @(
        [PSCustomObject]@{ name = 'Image';        sourceField = @('Image');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
        _As 'AddressCity'
        [PSCustomObject]@{
            name = 'AddressStateCode'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('AddressStateCode')
            targetField = 'AddressStateCode'
            codeTypeCategory = 'NJ_NIBRS_STATE'
            codeTypeSource   = 'NJ_NIBRS'
        }
        _As 'AddressStreet'
        _As 'AddressStreetName'
        _As 'AddressStreetNumber'
        _As 'AddressZipCode'
        _As 'ArticleBrand'
        _As 'ArticleModel'
        _As 'ArticleSerialNumber'
        _As 'ArticleTypeCode'
        _As 'AutoInsuranceCarrier'
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:DOB\s(\d{8})','trim')
            name = 'BirthDate'; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        _As 'BoatBrand'
        _As 'BoatHullIdNumber'
        _As 'BoatMakeCode'
        _As 'BoatName'
        _As 'BoatSerialNumber'
        _As 'EthnicityCode'
        _As 'ExpirationDate'
        [PSCustomObject]@{ name = 'EyeColor'; sourceField = @('EyeColor'); targetField = 'EyeColorCode' }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:EYE/([^\s]+)','trim','rule')
            name = 'EyeColorCode'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('EyeColorCode')
            targetField = 'EyeColorCode'
            attributeType = 'EYE_COLOR'
            codeTypeSource = 'NCIC'
        }
        [PSCustomObject]@{ name = 'GunCaliber'; sourceField = @('GunCaliber'); targetField = 'Caliber' }
        [PSCustomObject]@{ name = 'GunMake';    sourceField = @('GunMake');    targetField = 'FirearmMake' }
        _As 'GunModel'
        _As 'GunSerialNumber'
        _As 'GunTypeCode'
        [PSCustomObject]@{ name = 'HairColor'; sourceField = @('HairColor'); targetField = 'HairColorCode' }
        [PSCustomObject]@{
            name = 'HairColorCode'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('HairColorCode')
            targetField = 'HairColorCode'
            attributeType = 'HAIR_COLOR'
            codeTypeSource = 'NCIC'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:HGT/([^\s]+)','trim','rule')
            name = 'HeightDisplay'
            rule = _R 'HeightParserRuleHandler' @(,@('Height'),'height')
            sourceField = @('Height')
            targetField = 'HeightDisplay'
        }
        [PSCustomObject]@{
            name = 'HeightFeet'
            rule = _R 'HeightParserRuleHandler' @(,@('Height'),'feet')
            sourceField = @('HeightFeet')
            targetField = 'HeightFeet'
        }
        [PSCustomObject]@{
            name = 'HeightInches'
            rule = _R 'HeightParserRuleHandler' @(,@('Height'),'inches')
            sourceField = @('HeightInches')
            targetField = 'HeightInches'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:HGT/([^\s]+)','trim','rule')
            name = 'Height'
            rule = _R 'HeightParserRuleHandler' @(,@('Height'),'total')
            sourceField = @('Height')
            targetField = 'Height'
        }
        [PSCustomObject]@{ name = 'Hit'; sourceField = @('Hit'); targetField = 'hit' }
        [PSCustomObject]@{ name = 'ImageId'; sourceField = @('ImageId'); targetField = 'imageId' }
        [PSCustomObject]@{ name = 'ImpliedLicensePlateStateCode'; sourceField = @('ImpliedLicensePlateStateCode'); targetField = 'LicensePlateStateCode' }
        _As 'IntInterfaceName'
        _As 'IntSystemName'
        _As 'System'
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:LIC/\s*([^\s]+)','regex:LIC/([^\s]+)','trim')
            name = 'LicensePlateNumber'
            sourceField = @('LicensePlateNumber')
            targetField = 'LicensePlateNumber'
        }
        _A 'LicensePlateStateCode' 'LicensePlateStateCode' 'LicensePlateStateCode'
        # Name fields (ParseCommsysNameRuleHandler)
        [PSCustomObject]@{
            name = 'NameLast'
            rule = _R 'ParseCommsysNameRuleHandler' @(
                ,@('NormalizedNameLast','NormalizedNameFirst','NormalizedNameMiddle')
                ,@('NormalizedName')
                ,@('Name')
                ,@(', ',' ',' ')
            )
            sourceField = @('NormalizedNameLast')
            targetField = 'NameLast'
        }
        [PSCustomObject]@{
            name = 'NameFirst'
            rule = _R 'ParseCommsysNameRuleHandler' @(
                ,@('NormalizedNameLast','NormalizedNameFirst','NormalizedNameMiddle')
                ,@('NormalizedName')
                ,@('Name')
                ,@(', ',' ',' ')
            )
            sourceField = @('NormalizedNameFirst')
            targetField = 'NameFirst'
        }
        [PSCustomObject]@{
            name = 'NameMiddle'
            rule = _R 'ParseCommsysNameRuleHandler' @(
                ,@('NormalizedNameLast','NormalizedNameFirst','NormalizedNameMiddle')
                ,@('NormalizedName')
                ,@('Name')
                ,@(', ',' ',' ')
            )
            sourceField = @('NormalizedNameMiddle')
            targetField = 'NameMiddle'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = _R 'ParseCommsysNameRuleHandler' @(
                ,@('NormalizedNameLast','NormalizedNameFirst','NormalizedNameMiddle')
                ,@('NormalizedName')
                ,@('Name')
                ,@(', ',' ',' ')
            )
            sourceField = @('Name')
            targetField = 'Name'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:OLN/\s*([^\s]+)','regex:OLN/([^\s]+)','trim')
            name = 'OperatorLicenseNumber'
            sourceField = @('OperatorLicenseNumber')
            targetField = 'OperatorLicenseNumber'
        }
        _As 'OperatorLicenseRestrictions'
        _As 'OperatorLicenseStateCode'
        _As 'OperatorLicenseStatusCode'
        _As 'OrganDonor'
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:RAC/([^\s]+)','trim','rule')
            name = 'RaceCode'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('RaceCode')
            targetField = 'RaceCode'
            codeTypeCategory = 'NIBRS_RACE'
            codeTypeSource   = 'NIBRS'
        }
        _As 'SerialNumber'
        _As 'SecondaryRequests'
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:SEX/([^\s]+)','trim','rule')
            name = 'SexCode'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('SexCode')
            targetField = 'SexCode'
            attributeType  = 'SEX'
            codeTypeSource = 'NIBRS'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:SSN/([^\s]+)','regex:SSN ([^\s]+)','trim','rule')
            name = 'SocialSecurityNumber'
            rule = _R 'truncate' $null
            size = 11
            sourceField = @('SocialSecurityNumber')
            targetField = 'SocialSecurityNumber'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:VCO/([^\s]+)','trim','rule')
            name = 'VehicleColorCode'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('VehicleColorCode')
            targetField = 'VehicleColorCode'
            attributeType  = 'ITEM_COLOR'
            codeTypeSource = 'NCIC'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:VIN/([^\s]+)','trim')
            name = 'VehicleIdentificationNumber'
            sourceField = @('VehicleIdentificationNumber')
            targetField = 'VehicleIdentificationNumber'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:VMA/([^\s]+)','trim','rule')
            name = 'VehicleMakeName'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('VehicleMakeCode')
            targetField = 'VehicleMakeName'
            # Vehicle MAKE resolves via AttributesDataMapping under attributeType=VEHICLE_MAKE + NCIC.
            # RND-62365: the CODETYPE_TEST probe proved VehicleType/VEHICLE is ABSENT on the Newark
            # instance (empty dropdown / no such code table) -- it broke v4.6 vehicle result mapping.
            # VEHICLE_MAKE/NCIC is probe-confirmed present (VM04) and matches the RND-54190 runbook and
            # the sibling VehicleModelName. Prior NCIC_FIREARM_MAKE/NJ_NIBRS was a firearm-make table
            # (AP #24) -- also wrong for vehicles. See providers/NJ_NJCJIS/RND-62365/CATALOG_RND-62365.md.
            attributeType  = 'VEHICLE_MAKE'
            codeTypeSource = 'NCIC'
        }
        [PSCustomObject]@{ name = 'VehicleMakeCode'; sourceField = @('VehicleMakeCode'); targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'RegistrationStateCode'; sourceField = @('RegistrationState'); targetField = 'RegistrationStateCode' }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:VST/([^\s]+)','trim','rule')
            name = 'VehicleStyleCode'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('VehicleStyleCode')
            targetField = 'BodyStyle'
            codeTypeCategory = 'VEHICLE_BODY_STYLE'
            codeTypeSource   = 'NJ_NIBRS'
        }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:VMO/([^\s]+)','trim','rule')
            name = 'VehicleModelName'
            rule = _R 'CommsysResultAttributeMappingRuleHandler' $null
            sourceField = @('VehicleModelCode')
            targetField = 'VehicleModelName'
            attributeType  = 'VEHICLE_MODEL'
            codeTypeSource = 'NCIC'
        }
        [PSCustomObject]@{ name = 'VehicleModelCode'; sourceField = @('VehicleModelCode'); targetField = 'VehicleModelCode' }
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:VYR/([^\s]+)','regex:YRMD:([^\s]+)','trim','rule')
            name = 'VehicleYear'
            rule = _R 'ParseCommsysVehicleYearRuleHandler' @('50')
            sourceField = @('VehicleYear')
            targetField = 'VehicleYear'
        }
        _As 'VehicleTypeCode'
        [PSCustomObject]@{
            fallbackRule = _R 'CommysResultFallbackRegexRuleHandler' @('regex:WGT/([^\s]+)','trim')
            name = 'Weight'
            sourceField = @('Weight')
            targetField = 'Weight'
        }
    )

    $combos = @(
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = @('ArticleBrand','ArticleModel','ArticleTypeCode','ArticleSerialNumber')
                any = @('ArticleBrand','ArticleModel','SerialNumber','ArticleTypeCode','ArticleSerialNumber','Img','ImageId')
                conditions = $null; defaults = $null
            }
            primaryFieldReference = 'Article'
            keyReference = 'Article'
        }
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = $null
                any = @('Img','ImageId','BoatBrand','BoatHullIdNumber','BoatMakeCode','BoatName','BoatSerialNumber','LicensePlateNumber','LicensePlateStateCode')
                conditions = $null; defaults = $null
            }
            primaryFieldReference = 'Boat'
            keyReference = 'Boat'
        }
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = $null
                any = @(
                    'AddressCity','AddressStateCode','AddressStreet','AddressStreetName','AddressStreetNumber','AddressZipCode',
                    'AutoInsuranceCarrier','BirthDate','EnableSecondaryInquiry','EyeColorCode','HairColorCode',
                    'Height','HeightDisplay','HeightFeet','HeightInches',
                    'IntInterfaceName','IntSystemName','System',
                    'LicensePlateNumber','LicensePlateStateCode',
                    'Name','NameFirst','NameLast','NameMiddle',
                    'NormalizedName','NormalizedNameFirst','NormalizedNameLast','NormalizedNameMiddle',
                    'OperatorLicenseClassCode','OperatorLicenseNumber','OperatorLicenseRestrictions',
                    'OperatorLicenseStateCode','OperatorLicenseStatusCode','OrganDonor',
                    'RaceCode','SecondaryRequests','SexCode','SocialSecurityNumber','Weight'
                )
                conditions = $null; defaults = $null
            }
            primaryFieldReference = 'Person'
            keyReference = 'Person'
        }
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = $null
                any = @(
                    'Img','ImageId','RegistrationYear','VehicleColor','VehicleMakeName','VehicleMakeCode',
                    'VehicleModelName','VehicleModelCode','VehicleIdentificationNumber','VehicleYear','VehicleTypeCode',
                    'LicensePlateTypeCode','LicensePlateYear','LicensePlateNumber','LicensePlateStatusCode','LicensePlateStateCode',
                    'OperatorLicenseClassCode','VehicleColorCode','VehicleStyleCode','Weight',
                    'AddressCity','AddressStreetNumber','AddressCounty','AddressStateCode','AddressStreet',
                    'BirthDate','NameFirst','NameLast','NameMiddle','NameSuffix',
                    'NormalizedVehicleYear','IntSystemName','System','IntInterfaceName'
                )
                conditions = $null; defaults = $null
            }
            primaryFieldReference = 'Vehicle'
            keyReference = 'Vehicle'
        }
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = $null
                any = @('Img','ImageId','Caliber','FirearmMake','SerialNumber','FreeText','GunModel','GunSerialNumber','GunType','GunTypeCode')
                conditions = $null; defaults = $null
            }
            primaryFieldReference = 'Firearm'
            keyReference = 'Firearm'
        }
    )

    return [PSCustomObject]@{
        attributes      = $attrs
        combinations    = $combos
        description     = "Results mapping for $ProviderName"
        handlerFunction = 'CommsysResultsHandler'
        name            = "${ProviderName}_Results"
        type            = 'QUERYRESULTDATAMAPPING'
        provider        = $ProviderName
        providerType    = 'Commsys'
        specialResultTypeMapping = [PSCustomObject]@{
            hitDetected = '1'
            mappings    = @(
                [PSCustomObject]@{ description = 'Used for hit special result';    m43Value = 'Hit';            priority = 1; providerValue = 'Hit' }
                [PSCustomObject]@{ description = 'Special type for the person caution';  m43Value = 'Person Caution';  priority = 1; providerValue = 'Criminal' }
                [PSCustomObject]@{ description = 'Special type for the vehicle caution'; m43Value = 'Vehicle Caution'; priority = 1; providerValue = 'Stolen vehicle' }
                [PSCustomObject]@{ description = ''; m43Value = 'SVS STOLEN VEHICLE';  priority = 1; providerValue = 'SVS STOLEN VEHICLE' }
                [PSCustomObject]@{ description = ''; m43Value = 'NCIC STOLEN VEHICLE'; priority = 1; providerValue = 'NCIC STOLEN VEHICLE' }
                [PSCustomObject]@{ description = ''; m43Value = 'NCIC WANTED PERSON';  priority = 1; providerValue = 'NCIC WANTED PERSON' }
            )
        }
    }
}
