# build_or_leds.ps1  -- OR_LEDS (galvanized v2.0, single-JSON native PascalCase)
# Single-JSON: PascalCase USx fieldIds, multi-card layout.
# Phase 2 multi-card. No cross-entity combos. No DriverHistoryQuery.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# OR-SPECIFIC:
#   NO CaRequestPurposeCode     -- Oregon, not California.
#   NO DriverHistoryQuery        -- not in metadata or devdoc.
#   ImageIndicator: in DL metadata (Y/blank field), default Y.
#   Date format: yyyyMMdd (size=8 in metadata).
#   LIMITATION #30: No State initialValue (In vs Out routing).
#   State: NCIC pattern (codeTypeProvider='NCIC').
#   Sex: NIBRS pattern (codeTypeProvider='NIBRS').
#   PlateType: PC, PlateYear: 2026.
#   RelatedHitSearchIndicator: Y-only flag (FormInput maxLength=1).
#
# METADATA SUMMARY (OR_LEDS -- 5 basic queries, 8 combos):
#   ArticleSingleQuery       v4  -- 1 combo: QA (Serial+ArticleType)
#   BoatQuery                v3  -- 2 combos: BQ (Reg), BQ (Hull) -- same keyRef, invented BQ.R/BQ.H
#   DriverLicenseQuery       v3  -- 2 combos: DQ (Name+DOB+Sex), DQ (OLN) -- same keyRef, invented DQ.N/DQ.O
#   GunQuery                 v3  -- 1 combo: QG (Serial)
#   VehicleRegistrationQuery v3  -- 2 combos: RQ (Plate), RQ (VIN) -- same keyRef, invented RQ.P/RQ.V
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_or_leds.ps1

$ErrorActionPreference = "Stop"
$Version     = '2.4'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\OR_LEDS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; OR LEDS, 5 basic queries, no DH,
# OOS RegistrationState EXISTS/NOT_EXISTS routing gates + identifier-priority guardrails):
#   VehicleRegistrationQuery : RQ.PO (OOS plate), RQ.V (VIN), RQ.P (in-state plate)
#   DriverLicenseQuery       : DQ.N (Name+DOB), DQ.O (OLN)
#   GunQuery                 : QG (serial)
#   ArticleSingleQuery       : QA (serial+type)
#   BoatQuery                : BQ.H (hull), BQ.R (reg)

# =====================================================================
# BUNDLE 1: OR_LEDS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'OR_LEDS'

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'OR_LEDS'

$qmf = Build-Qmf -ProviderName 'OR_LEDS'

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase sourceField + combo refs
# Devdoc: In plate, In VIN, Out plate+State, Out VIN+State
# LIMITATION #30: No State initialValue (In vs Out routing)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        # OOS plate (most specific -- RegistrationState EXISTS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('LicensePlateTypeCode','LicensePlateYear','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.PO'
            state                 = 'In/Out'
        }
        # VIN (Plate>VIN guardrail -- LicensePlateNumber NOT_EXISTS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @('RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # In-state plate (RegistrationState NOT_EXISTS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('LicensePlateTypeCode','LicensePlateYear')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ.PO (OOS plate), RQ.V (VIN), RQ.P (in-state plate). EXISTS/NOT_EXISTS routing + Plate>VIN guardrail. Single-JSON PascalCase.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'OR_LEDS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'OR_LEDS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase sourceField + combo refs
# Devdoc: In Name+DOB+[Sex], In OLN, Out Name+DOB+State+[Sex,Img], Out OLN+State+[Img]
# LIMITATION #30: No State initialValue (In vs Out routing)
# ImageIndicator: in metadata (any[])
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size = 30; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Name+DOB+Sex (OLN>Name guardrail -- OperatorLicenseNumber NOT_EXISTS; State in any[] routes in/out)
        # v2.1: SexCode PROMOTED from any[] to set[]. Metadata DQ{Name} is
        #     Set[BirthDate, Name, SexCode] Any[ImageIndicator, State]
        # -- SexCode is MANDATORY there, and DQ{Name} is the ONLY name variant (its lone sibling is
        # DQ{OperatorLicenseNumber}), so there is no looser alternative to fall back on. With SexCode
        # in any[] this combination could FIRE WITHOUT IT and emit a request the metadata calls
        # invalid -- an UNDER-REQUIRED wire defect. That is the class gate 6d catches on a live log
        # while 6c and 2i cannot see it at all, because a MISSING REQUIREMENT is invisible to content
        # and attribution checks.
        # Consequence, stated plainly rather than buried: a name-based licence search on this provider
        # now requires Sex. That is what this provider's metadata demands, not a build preference.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BirthDate','NameLast','NameFirst','SexCode'); any = @('RegistrationState','ImageIndicator','nameMiddle','nameSuffix')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # OLN (State in any[] routes in/out)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @('RegistrationState','ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ.N (Name+DOB), DQ.O (OLN). OLN>Name guardrail; State any[] in/out routing. Single-JSON PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. GunQuery -- QG (serial), any[GunMake, GunCaliber] -- PascalCase
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';          size = 23; sourceField = @('gunMake');         targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';  size = 11; sourceField = @('serialNumber');    targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','gunMake') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). NCIC firearm query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1g. ArticleSingleQuery -- QA (Serial+ArticleType) -- PascalCase
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');    targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode'); targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial+type). NCIC article query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1h. BoatQuery -- BQ (Reg), BQ (Hull) -- PascalCase
# State in any[] for both combos
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        # Reg (Hull>Reg guardrail -- BoatHullIdNumber NOT_EXISTS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ.H (hull), BQ.R (reg). Hull>Reg guardrail. Single-JSON PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# Provider bundle assembly (5 basic QIDMs only)
# =====================================================================
$providerBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery
    )
    description    = "Provider configuration for OR_LEDS v${Version} -- 5 QIDMs (VehReg + DL + Gun + Article + Boat)"
    name           = 'OR_LEDS'
    type           = 'BUNDLE'
    provider       = 'OR_LEDS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Firearm:  1 card  (single combo -- QG serial)
# Article:  1 card  (single combo -- QA serial+type)
# Boat:     3 cards (OPTIONS + REGISTRATION SEARCH + HULL SEARCH)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState)
# live on a separate card to avoid duplicate fieldId across cards (= ISE).
# NCIC state pattern: visible RegistrationState, NO initialValue
# (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards (MC)
# OPTIONS: RegistrationState (shared by all combos, LIMITATION #30)
# PLATE SEARCH: Plate + PlateType + PlateYear
# VIN SEARCH: VIN only. VehicleMake/VehicleYear REMOVED at v2.4 -- the devdoc lists them as
# optionals on combination #2 but metadata RQ{VehicleIdentificationNumber} defines Any[State] ONLY,
# so transmitting them would OVER-PERMIT. Registered devdoc-optional-unreachable.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for OR queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE_1'; cols = @('12'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_PLATE_1' }
            )}
            @{ id = 'ROW_VEH_PLATE_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (optional)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_PLATE_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (optional)' '4' 'ROW_VEH_PLATE_2' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_VIN_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State) + PLATE (RQ.P/RQ.PO) + VIN (RQ.V/RQ.VO)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC)
# OPTIONS: RegistrationState + ImageIndicator + RelatedHitSearchIndicator
# OLN SEARCH: OperatorLicenseNumber
# NAME SEARCH: First + Last + Middle + Suffix + DOB + Sex + Race
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for OR queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator'          'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
                # LABEL-OVERRIDE: nameMiddle -- bare 'Middle Name' (any[] optional). RESTORED v2.3;
                # ROW_PER_NAME_2 was removed at v2.2 as dead controls, but OR metadata declares Name
                # with four components -- the fix was to WIRE them, not delete them.
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_NAME_1' }
                # LABEL-OVERRIDE: nameSuffix -- bare 'Suffix' (any[] optional). RESTORED v2.3.
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '5'  'ROW_PER_NAME_1' }
            )}
            # v2.2: ROW_PER_NAME_2 REMOVED (Rob 2026-08-02) -- it held nameMiddle + nameSuffix, both
            # visible controls wired to nothing. The Name attribute sources only [NameLast, NameFirst],
            # so an officer's middle name or suffix was silently discarded on every DriverLicense
            # query. Found by audit_wiring_closure. Removed rather than wired: no wire behaviour
            # changes, and the form stops implying a precision it never delivered.
            @{ id = 'ROW_PER_NAME_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_NAME_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex (optional)'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_3' }
                @{ id = 'RaceCode_Input';  node = Sel 'raceCode'  'Race (optional)' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Image) + OLN (DQ.O) + NAME (DQ.N)'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (single combo QG)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';      node = Sel 'gunMake'      'Make (optional)'           @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            # v2.2: gunTypeCode REMOVED (Rob 2026-08-02). Not merely unwired -- UNWIREABLE. This XML
            # defines GunTypeCode exactly ONCE, under CPICBIGunQuery, a transaction this build does not
            # carry; the built GunQuery defines only GunCaliber, GunMake and GunSerialNumber (probe
            # validated -- both siblings resolve inside GunQuery). The dropdown offered a filter the
            # query cannot accept and discarded the officer's choice. If CPICBIGunQuery is ever brought
            # into scope it comes back WITH its attribute and combination.
            @{ id = 'ROW_GUN_2'; cols = @('12'); fields = @(
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- single card (QG serial)'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (single combo QA)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- single card (QA serial+type)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 3 cards (MC)
# OPTIONS: RegistrationState (shared by both combos)
# REGISTRATION SEARCH: RegistrationNumber (BQ.R)
# HULL SEARCH: BoatHullIdNumber (BQ.H)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for OR queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_REG_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_HULL_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State) + REG (BQ.R) + HULL (BQ.H)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm) `
    -DefaultOrder @('Person','Vehicle','Firearm','Article','Boat')

# =====================================================================
# BUNDLE 3: RMS (from KB specs â€” camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built OR_LEDS v${Version}" `
    -Version $Version
