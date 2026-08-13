# build_il_leads_ofml.ps1  -- IL_LEADS_OFML (galvanized v2.0, single-JSON native PascalCase)
# MC variant: PascalCase fieldIds, multi-card layout, no Patch 8 (CAD rename).
# Phase 2 multi-card. No cross-entity combos. No DriverHistoryQuery.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# IL-SPECIFIC:
#   No CaRequestPurposeCode
#   No DriverHistoryQuery (not in IL metadata)
#   ImageIndicator: 'Y' on EVERY entity that has the control -- Vehicle=Y, Person=Y, Firearm=Y,
#     Boat=Y (v2.4, Rob 2026-08-12 "ncic image should default to y everywhere"). Set in BOTH the
#     form initialValue AND every carrying combo's defaults[], because CAD ignores form
#     initialValue and a form-only flip leaves CAD-originated queries still asking 'N'.
#     ARTICLE HAS NO CONTROL AND MUST NOT GAIN ONE: IL metadata defines ImageIndicator on
#     BoatQuery/DriverLicenseQuery/GunQuery/VehicleRegistrationQuery (and the unbuilt WMPI/QWX
#     transactions) but NOT on ArticleSingleQuery, so adding it there would OVER-PERMIT.
#     Safe here -- ImageIndicator sits in any[] on all 8 carrying combos and in 0 set[] and 0
#     conditions, so no prefill can move routing (BUILD_RULES 24). Contrast AZ_AZDPS (2 set[]s)
#     and LA_LEMS (1 set[] + 2 conditions), which need a ruling rather than a flip.
#     TX_TLETS T6 gate cleared: the IL devdoc has no "must be filled if ImageIndicator = Y"
#     conditional -- it carries no conditional-requirement wording at all, and every devdoc
#     mention of ImageIndicator is inside optional brackets.
#     NOTE the line this replaced claimed "Vehicle=N, Person=Y, Firearm=Y, Boat=Y" and was WRONG
#     about two of the four -- the code set Firearm=N and Boat=N. Comments drift; the emitted JSON
#     was the authority for the v2.4 measurement.
#   Date format: MMddyyyy (CommsysParseDateRuleHandler arguments=['yyyy-MM-dd','MMddyyyy'])
#   State initialValue=IL (safe for this provider)
#   CDCName in AUTH
#   RelatedHitSearchIndicator hidden on most entities
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_il_leads_ofml_mc.ps1 [-Version X.X]

$ErrorActionPreference = "Stop"
$Version     = '2.4'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\IL_LEADS_OFML_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; IL LEADS, 5 basic queries, no DH,
# OOS RegistrationState EXISTS/NOT_EXISTS routing gates + identifier-priority guardrails):
#   VehicleRegistrationQuery : Z2.P (OOS plate), Z2.V (OOS VIN), Z5 (in-state plate)
#   DriverLicenseQuery       : Z2.N (Name+DOB), Z2.O (OLN)
#   GunQuery                 : QG (serial)
#   ArticleSingleQuery       : QA (serial+type)
#   BoatQuery                : BQ.H (hull), BQ.R (reg)

# =====================================================================
# BUNDLE 1: IL_LEADS_OFML PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'IL_LEADS_OFML' `
    -ExtraAttributes @([PSCustomObject]@{ name='CDCName'; size=10; sourceField=@('CDCName'); targetField='CDCName' }) `
    -ExtraAny @('CDCName')

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'IL_LEADS_OFML'

$qmf = Build-Qmf -ProviderName 'IL_LEADS_OFML'

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase
# XML v2: 3 combos: Z2 plate (OOS), Z2 VIN (OOS), Z5 plate (in-state)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';   size = 1;  sourceField = @('relatedHitSearchIndicator');   targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS plate (most specific -- requires State in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'Z2.P'
            state                 = 'In/Out'
        }
        # OOS VIN (requires State in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','VehicleMakeCode','vehicleYear','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'Z2.V'
            state                 = 'In/Out'
        }
        # In-state plate (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'Z5'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- Z5 (in-state plate), Z2 (OOS plate/VIN). MC PascalCase.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'IL_LEADS_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'IL_LEADS_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase
# XML v2: 2 combos: Z2 Name+DOB, Z2 OLN
# No DH in IL metadata
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Name+DOB
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BirthDate','NameLast','NameFirst'); any = @('ImageIndicator','relatedHitSearchIndicator','SexCode')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'Z2.N'
            state                 = 'In/Out'
        }
        # OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'Z2.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- Z2 (Name+DOB, OLN). IL DMV driver license query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. GunQuery -- PascalCase
# XML v2: 1 combo: QG serial
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                   size = 4;  sourceField = @('gunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                      size = 3;  sourceField = @('firearmMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';              size = 20; sourceField = @('serialNumber');              targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';    size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('serialNumber'); any = @('gunCaliber','firearmMake','ImageIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). IL NCIC firearm query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1g. ArticleSingleQuery -- PascalCase
# XML v4: 1 combo: QA serial+type (OAN in any[])
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');    targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber'); targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @('ownerAppliedNumber') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial+type). IL article inquiry. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1h. BoatQuery -- PascalCase
# XML v4: 2 combos: BQ hull, BQ reg
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 20; sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (hull, reg). IL boat inquiry. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# Build the provider bundle with 5 basic QIDMs
$ilBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $vehRegQuery,
        $dlQuery,
        $gunQuery, $artQuery, $boatQuery
    )
    description    = "Provider configuration for IL_LEADS_OFML v${Version} MC (5 basic queries)"
    name           = 'IL_LEADS_OFML'
    type           = 'BUNDLE'
    provider       = 'IL_LEADS_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES (5 QIFs)
#
# Vehicle:  1 card (collapsed from OPTIONS+PLATE+VIN, v2.1)
# Person:   1 card (collapsed from OPTIONS+OLN+NAME, v2.1)
# Firearm:  1 card
# Article:  1 card
# Boat:     1 card (collapsed from OPTIONS+HULL+REG, v2.1)
#
# v2.1 DEX-1284 convention pass: the separate shared "OPTIONS" card is the
# RETIRED pre-DEX-1284 layout (see HI v4.14 / FL v7.18 / NY / TX, all of which
# collapsed it). The option fields fold onto the single entity card -- there is
# no duplicate-fieldId risk because each fieldId still appears exactly ONCE per
# QIF. Card titles carry the query paths and are ALL-CAPS; labels are lean
# (BUILD_RULES Section 11), and State keeps its mandatory routing hint.
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card, uniform 4/4/4 grid
# Plate path (Z5 in-state / Z2.P OOS) + VIN path (Z2.V)
# LABEL-OVERRIDE: VehicleMakeCode -- bare per DEX-1284 lean pass (any[] optional VIN qualifier)
# LABEL-OVERRIDE: vehicleYear -- bare per DEX-1284 lean pass (any[] optional VIN qualifier)
# LABEL-OVERRIDE: LicensePlateTypeCode -- bare per DEX-1284 lean pass (any[] optional, prefilled PC)
# LABEL-OVERRIDE: LicensePlateYear -- bare per DEX-1284 lean pass (any[] optional, prefilled)
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
# LABEL-OVERRIDE: VehicleIdentificationNumber -- bare "Vehicle Identification Number", Rob 2026-08-07
#   v2.2 cosmetic pass. The "(Plate wins if both entered)" identifier-priority hint is REMOVED at
#   Rob's direction; the Plate>VIN guardrail itself is untouched (Z2.V still carries
#   LicensePlateNumber NOT_EXISTS), so this is label-only and changes no routing.
#   Spelled out rather than "VIN": the portfolio is SPLIT 10 "VIN" / 9 "Vehicle Identification
#   Number" (measured 2026-08-07, NOT a settled convention) -- recorded so the next reader knows
#   this was a choice on a split field, not conformance to a rule.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH BY PLATE, "OR" VIN'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for IL)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'ImageIndicator_Input';       node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_3' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Year' '4' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card: plate (Z5 in-state / Z2.P OOS) + VIN (Z2.V)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card. DL only (IL metadata has no DriverHistoryQuery in Basic scope).
# OLN path (Z2.O) + Name+DOB path (Z2.N, gated OperatorLicenseNumber NOT_EXISTS)
# Top row 6/3/3 per BUILD_RULES Section 11 PERSON CARDS pattern: primary
# identifier keeps the width, State/Image are short codes.
# raceCode is RMS-only (IL metadata defines no RaceCode on either DL variant) --
# it feeds the RMS Person QIDM, which is why wiring closure counts it as reached.
# LABEL-OVERRIDE: raceCode -- bare per DEX-1284 lean pass (RMS-only refinement)
# LABEL-OVERRIDE: SexCode -- bare per DEX-1284 lean pass (any[] optional)
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
# LABEL-OVERRIDE: NameLast -- bare "Last Name", Rob 2026-08-07 (v2.2 cosmetic pass). The
#   "(OLN wins if both entered)" identifier-priority hint is REMOVED at Rob's direction. The
#   guardrail itself is UNTOUCHED: Z2.N still carries OperatorLicenseNumber NOT_EXISTS, so OLN
#   still beats Name on a co-entry -- only the on-screen hint is gone.
# NAME FIELD ORDER: First then Last on the form (Rob 2026-08-07; matches NY v4.8, which reordered
#   First-before-Last on all its Person cards). THE FORM ORDER IS NOT THE WIRE ORDER -- the
#   composite 'Name' attribute keeps sourceField = @('NameLast','NameFirst') with
#   FormatStringRuleHandler ', ', which is what produces the authoritative ConnectCIC
#   "LAST, FIRST" wire format (FIELD_REFERENCE Section 7). That array is deliberately NOT touched
#   here; swapping it would silently invert every name search on the wire.
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, "OR" NAME'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for IL)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator'    'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt 'BirthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
                @{ id = 'RaceCode_Input';  node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('4'); fields = @(
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 1 card: DL by OLN (Z2.O) or Name+DOB (Z2.N)'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card, uniform 4/4/4 grid
# LABEL-OVERRIDE: firearmMake -- bare per DEX-1284 lean pass (any[] optional)
# LABEL-OVERRIDE: gunCaliber -- bare per DEX-1284 lean pass (any[] optional)
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';     node = Sel 'firearmMake'    'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'ImageIndicator_Input';  node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4'); fields = @(
                @{ id = 'GunCaliber_Input'; node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: FIREARM SEARCH (QG serial). 1 card with hidden RelatedHitSearch.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card, uniform 4/4/4 grid
# Single card: SerialNumber + ArticleTypeCode + OwnerAppliedNumber
# No ImageIndicator, no RelatedHitSearchIndicator (not in Article QIDM)
# Devdoc combination #2 (OwnerAppliedNumber + ArticleTypeCode, no serial) is NOT
#   buildable -- metadata defines ONE combination, QA{ArticleSerialNumber}, which
#   makes ArticleSerialNumber mandatory on every Article query. OwnerAppliedNumber
#   is an OPTIONAL on the serial path, not a search key. Registered 2026-08-02.
# LABEL-OVERRIDE: ownerAppliedNumber -- bare per DEX-1284 lean pass (any[] optional article qualifier)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL NUMBER + TYPE'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'        '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';    node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: ARTICLE SEARCH (QA serial+type). 1 card.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card, uniform 4/4/4 grid
# Hull path (BQ.H) + Registration-number path (BQ.R, gated Hull NOT_EXISTS)
# State2-State5: metadata AND devdoc list them as optionals, but they are NOT
#   implementable -- the platform has no multi-state mechanism (one State field
#   per query). Same standing ruling as HI_HCJDC_OFML (which excludes State2-5 on
#   DL/VehicleReg for this reason). Registered, not built. See ACCEPTED_DIVERGENCES.
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
# LABEL-OVERRIDE: RegistrationNumber -- bare "Registration Number", Rob 2026-08-07 (v2.2 cosmetic
#   pass). The "(Hull ID wins if both entered)" identifier-priority hint is REMOVED at Rob's
#   direction. The guardrail is UNTOUCHED: BQ.R still carries BoatHullIdNumber NOT_EXISTS, so hull
#   still beats registration number on a co-entry -- label-only, no routing change.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY HULL ID, "OR" REGISTRATION NUMBER'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for IL)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4'); fields = @(
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card: hull (BQ.H) or registration number (BQ.R)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ilBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built IL_LEADS_OFML v${Version}" `
    -Version $Version
