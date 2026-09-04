# =====================================================================
#  CA_eSUN v3.0 -- THE MAINLINE. First FROM-SCRATCH build of this provider,
#  driven by the DEVDOC (query authority) + METADATA (field authority), using the
#  shared modules every other provider uses.
#
#  Rob 2026-09-03: "start a new josn at 3.0 from scratch using the build skill ...
#  this line will be distinct from the mainline which is not yet built."
#
#  THIS IS A DIFFERENT LINE FROM v1.x/v2.x AND DELIBERATELY SO. Those are the
#  RADIOBUTTON line: a faithful capture of the hand-built San Diego Sheriff config
#  (v1.0) plus the RND-71815 radio conversion. This one owes nothing to that form.
#  It therefore carries NO "RADIOBUTTON" token -- that token marks the other line.
#
#  SCOPE, MEASURED NOT ASSUMED (tools/_probes/esun_v3_scope.ps1):
#    devdoc "Basic Queries Supported" authorizes SIX queries (devdoc lines 33-288).
#    Those six hold 26 metadata combinations / 27 variant branches.
#    The XML holds 63 transactions / 144 combinations in total -- the remaining 118
#    are ENTRY / MODIFY / CANCEL record operations and Expanded transactions, a
#    different product surface. Building those would be scope invention.
#
#  DELIBERATELY NOT BUILT, on Rob's explicit ruling 2026-09-03:
#    AFS         -- appears ZERO times in 145 KB of devdoc. No authority anywhere.
#    LojackQuery -- devdoc line 7070, but under EXPANDED Transactions, not Basic.
#  Both remain available on the v2.2 radiobutton line, which is the capture of what
#  San Diego actually runs.
#
#  STATE ROUTING USES EXISTENCE-ONLY GATES, unlike the captured line.
#  v1.0/v2.x fork in/out-of-state with IN / NOT_IN value lists like
#  ["CA","null","59872938171"] -- note the stray platform id sitting beside a state
#  code. The portfolio convention is EXISTS / NOT_EXISTS, which needs no value list,
#  cannot rot when a code changes, and sidesteps the poisoned-array question
#  entirely. The v2.2 sweep proved value-comparison operators DO evaluate here, so
#  this is a cleanliness choice rather than a correctness fix.
# =====================================================================
#  SYNTHETIC keyRef INVENTORY -- LIMITATION #21 / #36.
#  Metadata gives ONE keyRef several primaryField variants (QV{Plate} and QV{VIN}; DQ{OLN}
#  and DQ{Name}; BQ{Reg} and BQ{Hull}), but a keyReference must be UNIQUE inside a QIDM, so
#  each variant is built under a suffixed name. THE SUFFIX IS OURS AND NEVER REACHES THE WIRE
#  -- a request carries <MessageType><QueryName></MessageType> plus the fields, nothing else.
#  Per QIDM, the split keyRefs and the metadata keyRef each implements:
#    VehicleRegistrationQuery : RQ.P RQ.V (RQ) · 4.P (4) · QV.P QV.V (QV) · VP.N (VP)
#    DriverLicenseQuery       : DQ.O DQ.N (DQ) · L1.O L1.N (L1) · QW.N (QW)
#    DriverHistoryQuery       : KQ.O KQ.N (KQ) · L1.ODH L1.NDH (L1)
#      ^ DH-SUFFIXED because metadata L1 sits under BOTH DriverLicenseQuery and
#        DriverHistoryQuery, and a bare L1.O/L1.N in both QIDMs raised two validator WARNs
#        ("keyReference appears in multiple QIDMs -- may cause routing ambiguity"). The
#        suffix is bookkeeping only; both still resolve to metadata L1 on the officer guide.
#    GunQuery                 : QG.S (QG) · QGH.A QGH.B (QGH)
#    BoatQuery                : BQ.R BQ.H (BQ) · QB.R QB.H (QB)
#    ArticleSingleQuery       : QA -- metadata-exact, no split needed
#  The officer guide resolves these BACK to the metadata keyRef, so a supervisor reading a
#  state manual sees QV / DQ / BQ and not our bookkeeping.
param([string]$Version = '3.1')
$ErrorActionPreference = 'Stop'

$DIR  = Split-Path $PSScriptRoot -Parent
$OUT  = Join-Path $DIR "CA_eSUN_v${Version}.json"
$PROV = 'CA_eSUN'

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

$currentYear = (Get-Date).Year.ToString()

# ---------------------------------------------------------------------
#  AUTH / QMF / QRDM -- standard 3-attribute AUTH plus DeviceId, which THIS
#  provider's devdoc line 8 requires in the ConnectCIC header alongside ORI,
#  Mnemonic and UserName.
# ---------------------------------------------------------------------
$auth    = Build-Auth -ProviderName $PROV
$results = Build-ProviderQrdm -ProviderName $PROV
$qmf     = Build-Qmf -ProviderName $PROV

# ---------------------------------------------------------------------
#  Shared attribute builders -- every QIDM needs the same purpose code and name
#  composition, and repeating them by hand is how one drifts.
# ---------------------------------------------------------------------
function PurposeAttr([string]$src = 'PurposeCode') {
    # CaRequestPurposeCode is MANDATORY on all 27 metadata branches of all six
    # transactions -- there is no variant that omits it.
    [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @($src); targetField = 'CaRequestPurposeCode' }
}
function NameAttr([string]$last = 'NameLast', [string]$first = 'NameFirst', [string]$mid = 'nameMiddle', [string]$sfx = 'nameSuffix') {
    # ConnectCIC name format is LAST-first: "LAST, FIRST MIDDLE SUFFIX".
    # sourceField ORDER is the contract (knowledge-base/FIELD_REFERENCE.txt Sec 7).
    [PSCustomObject]@{
        name = 'Name'
        rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
        size = 30; sourceField = @($last, $first, $mid, $sfx); targetField = 'Name'
    }
}
function DateAttr([string]$name, [string]$src, [string]$target) {
    [PSCustomObject]@{
        name = $name
        rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd', 'MMddyyyy') }
        size = 10; sourceField = @($src); targetField = $target
    }
}
function StateAttr([string]$src = 'RegistrationState') {
    [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @($src); targetField = 'State'; codeTypeProvider = 'NCIC' }
}
# Existence-only state gates -- the house convention. See the header note.
function StateOut([string]$f = 'RegistrationState') { [PSCustomObject]@{ field = @($f); operator = 'EXISTS' } }
function StateIn ([string]$f = 'RegistrationState') { [PSCustomObject]@{ field = @($f); operator = 'NOT_EXISTS' } }
function Absent  ([string[]]$f) { $f | ForEach-Object { [PSCustomObject]@{ field = @($_); operator = 'NOT_EXISTS' } } }

# =====================================================================
#  1. VehicleRegistrationQuery -- 7 metadata branches, 6 built.
#     QV{Plate} QV{VIN} 4{Plate+Type} 4V{VIN} RQ{Plate+Type+Year} RQ{VIN} VP{Name}
#     4V{VIN} is NOT built: its set[] is identical to QV{VIN} and its <Any> adds
#     nothing QV{VIN} lacks, so no fill can distinguish them and whichever is
#     ordered first takes everything. Routing impossibility, registered.
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        (PurposeAttr)
        [PSCustomObject]@{ name = 'LicensePlateNumber';  size = 10; sourceField = @('LicensePlateNumber');  targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode'; size = 2; sourceField = @('LicensePlateTypeCode'); targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';     size = 4; sourceField = @('LicensePlateYear');     targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode'; size = 24; sourceField = @('VehicleMakeCode'); targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';     size = 4;  sourceField = @('vehicleYear');     targetField = 'VehicleYear' }
        (NameAttr)
        [PSCustomObject]@{ name = 'AddressCity';          size = 20; sourceField = @('AddressCity');          targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'AddressStreetNumber';  size = 10; sourceField = @('AddressStreetNumber');  targetField = 'AddressStreetNumber' }
        (StateAttr)
    )
    combinations = @(
        # --- PLATE family, most-specific first -------------------------------
        [PSCustomObject]@{   # RQ{Plate+Type+Year} -- out of state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear')
                any = @('RegistrationState'); conditions = @((StateOut))
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' },
                             [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
            }
            primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQ.P'; state = 'Out'
        }
        [PSCustomObject]@{   # 4{Plate+Type} -- in state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','LicensePlateNumber','LicensePlateTypeCode')
                any = @(); conditions = @((StateIn))
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' })
            }
            primaryFieldReference = 'LicensePlateNumber'; keyReference = '4.P'; state = 'In'
        }
        [PSCustomObject]@{   # QV{Plate} -- in state, plain
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','LicensePlateNumber'); any = @(); conditions = @((StateIn))
            }
            primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QV.P'; state = 'In'
        }
        # --- VIN family. Plate outranks VIN, so both are gated on Plate absent.
        [PSCustomObject]@{   # RQ{VIN} -- out of state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','VehicleIdentificationNumber')
                any = @('RegistrationState','VehicleMakeCode','vehicleYear')
                conditions = @((StateOut)) + (Absent @('LicensePlateNumber'))
            }
            primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQ.V'; state = 'Out'
        }
        [PSCustomObject]@{   # QV{VIN} -- in state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','VehicleIdentificationNumber')
                any = @('VehicleMakeCode','vehicleYear')
                conditions = @((StateIn)) + (Absent @('LicensePlateNumber'))
            }
            primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QV.V'; state = 'In'
        }
        # --- OWNER NAME. Weakest identifier: gated on both Plate and VIN absent.
        [PSCustomObject]@{   # VP{Name}
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','NameLast','NameFirst')
                any = @('AddressCity','AddressStreetNumber','nameMiddle','nameSuffix')
                conditions = (Absent @('LicensePlateNumber','VehicleIdentificationNumber'))
            }
            primaryFieldReference = 'Name'; keyReference = 'VP.N'; state = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- 6 of 7 metadata branches. Plate (RQ out / 4 in / QV in), VIN (RQ out / QV in), owner Name (VP). 4V{VIN} not built: set[] identical to QV{VIN}, routing-impossible.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${PROV}_VehicleRegistrationQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $PROV
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
#  2. DriverLicenseQuery -- 6 metadata branches, 5 built.
#     QW{OLN} is NOT built: identical set[] to L1{OLN} with an empty <Any>.
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        (PurposeAttr)
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        (NameAttr)
        (DateAttr 'BirthDate' 'BirthDate' 'BirthDate')
        [PSCustomObject]@{ name = 'Age';     size = 3; sourceField = @('Age');     targetField = 'Age' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        (StateAttr)
    )
    combinations = @(
        # OLN outranks Name, so the OLN family is ordered first.
        [PSCustomObject]@{   # DQ{OLN} -- out of state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','OperatorLicenseNumber'); any = @('RegistrationState'); conditions = @((StateOut))
            }
            primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQ.O'; state = 'Out'
        }
        [PSCustomObject]@{   # L1{OLN} -- in state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','OperatorLicenseNumber'); any = @(); conditions = @((StateIn))
            }
            primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'L1.O'; state = 'In'
        }
        [PSCustomObject]@{   # DQ{Name} -- most specific name path
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','NameLast','NameFirst','SexCode','BirthDate')
                any = @('RegistrationState','nameMiddle','nameSuffix')
                conditions = (Absent @('OperatorLicenseNumber'))
            }
            primaryFieldReference = 'Name'; keyReference = 'DQ.N'; state = 'In/Out'
        }
        [PSCustomObject]@{   # QW{Name+DOB}
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','NameLast','NameFirst','BirthDate')
                any = @('Age','SexCode','nameMiddle','nameSuffix')
                conditions = (Absent @('OperatorLicenseNumber'))
            }
            primaryFieldReference = 'Name'; keyReference = 'QW.N'; state = 'In/Out'
        }
        [PSCustomObject]@{   # L1{Name} -- plain name
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','NameLast','NameFirst')
                any = @('Age','BirthDate','nameMiddle','nameSuffix')
                conditions = (Absent @('OperatorLicenseNumber'))
            }
            primaryFieldReference = 'Name'; keyReference = 'L1.N'; state = 'In/Out'
        }
    )
    description        = 'DriverLicenseQuery -- 5 of 6 metadata branches. OLN (DQ out / L1 in) then Name (DQ full / QW +DOB / L1 plain), all gated OLN NOT_EXISTS. QW{OLN} not built: identical to L1{OLN}.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = "${PROV}_DriverLicenseQuery"
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('DriverHistoryQuery')
    provider           = $PROV
    providerType       = 'Commsys'
    query              = 'DriverLicenseQuery'
    queryLabel         = 'Driver License'
    targetEntity       = 'Person'
}

# =====================================================================
#  3. DriverHistoryQuery -- 4 metadata branches, all 4 built.
#     DH-SUFFIX fieldIds throughout (Scenario A): DL and DH share the Person
#     entity, so a shared field pool would make queriesToDeselect ineffective and
#     every DL fill would co-fire DH.
#     Attention is a HIDDEN gate-feeder: membership in any[] alone feeds
#     CommsysGetLastNameFirstNameInitialRuleHandler. No prefill, no combo default.
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        (PurposeAttr 'PurposeCodeDH')
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        (NameAttr 'NameLastDH' 'NameFirstDH' 'nameMiddleDH' 'nameSuffixDH')
        (DateAttr 'BirthDate' 'BirthDateDH' 'BirthDate')
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('AttentionDH'); targetField = 'Attention'
        }
        (StateAttr 'RegistrationStateDH')
    )
    combinations = @(
        [PSCustomObject]@{   # KQ{OLN} -- out of state
            requirements = [PSCustomObject]@{
                set = @('PurposeCodeDH','OperatorLicenseNumberDH')
                any = @('AttentionDH','RegistrationStateDH'); conditions = @((StateOut 'RegistrationStateDH'))
            }
            primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQ.O'; state = 'Out'
        }
        [PSCustomObject]@{   # L1{OLN} -- in state
            requirements = [PSCustomObject]@{
                set = @('PurposeCodeDH','OperatorLicenseNumberDH')
                any = @(); conditions = @((StateIn 'RegistrationStateDH'))
            }
            primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'L1.ODH'; state = 'In'
        }
        [PSCustomObject]@{   # KQ{Name+Sex+DOB}
            requirements = [PSCustomObject]@{
                set = @('PurposeCodeDH','NameLastDH','NameFirstDH','SexCodeDH','BirthDateDH')
                any = @('AttentionDH','RegistrationStateDH','nameMiddleDH','nameSuffixDH')
                conditions = (Absent @('OperatorLicenseNumberDH'))
            }
            primaryFieldReference = 'Name'; keyReference = 'KQ.N'; state = 'In/Out'
        }
        [PSCustomObject]@{   # L1{Name} -- plain
            requirements = [PSCustomObject]@{
                set = @('PurposeCodeDH','NameLastDH','NameFirstDH')
                any = @('nameMiddleDH','nameSuffixDH')
                conditions = (Absent @('OperatorLicenseNumberDH'))
            }
            primaryFieldReference = 'Name'; keyReference = 'L1.NDH'; state = 'In/Out'
        }
    )
    combinationsNote   = 'DH-suffix isolation'
    description        = 'DriverHistoryQuery -- all 4 metadata branches. DH-suffix fieldIds isolate it from DriverLicenseQuery on the shared Person entity. Attention auto-populated by handler from the DH name fields.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = "${PROV}_DriverHistoryQuery"
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $false
    queriesToDeselect  = @('DriverLicenseQuery')
    provider           = $PROV
    providerType       = 'Commsys'
    query              = 'DriverHistoryQuery'
    queryLabel         = 'Driver History'
    targetEntity       = 'Person'
}

# =====================================================================
#  4. GunQuery -- 3 metadata branches, all 3 built.
#     QGH splits into two <Choice> branches: Name+BirthDate and Name+Age. The
#     Choice sits inside <Set>, so the qualifier is MANDATORY -- which is why this
#     is two combos and not one combo with both in any[]. That exact misreading
#     shipped a request no CA_CLETS variant accepted.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        (PurposeAttr)
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('GunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunCaliber'; size = 6; sourceField = @('GunCaliber'); targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';    size = 6; sourceField = @('GunMake');    targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunTypeCode'; size = 6; sourceField = @('GunTypeCode'); targetField = 'GunTypeCode' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedSearchHitIndicator' }
        (NameAttr)
        (DateAttr 'BirthDate' 'BirthDate' 'BirthDate')
        [PSCustomObject]@{ name = 'Age'; size = 3; sourceField = @('Age'); targetField = 'Age' }
    )
    combinations = @(
        [PSCustomObject]@{   # QGB{Serial} -- serial outranks name
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','GunSerialNumber')
                any = @('GunCaliber','GunMake','GunTypeCode','relatedHitSearchIndicator'); conditions = @()
            }
            primaryFieldReference = 'GunSerialNumber'; keyReference = 'QGB'; state = 'In/Out'
        }
        [PSCustomObject]@{   # QGH{Name+BirthDate}
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','NameLast','NameFirst','BirthDate')
                any = @('nameMiddle','nameSuffix'); conditions = (Absent @('GunSerialNumber'))
            }
            primaryFieldReference = 'Name'; keyReference = 'QGH.B'; state = 'In/Out'
        }
        [PSCustomObject]@{   # QGH{Name+Age}
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','NameLast','NameFirst','Age')
                any = @('nameMiddle','nameSuffix'); conditions = (Absent @('GunSerialNumber','BirthDate'))
            }
            primaryFieldReference = 'Name'; keyReference = 'QGH.A'; state = 'In/Out'
        }
    )
    description     = 'GunQuery -- all 3 metadata branches. QGB serial, then QGH split by its mandatory Choice qualifier (BirthDate | Age), both gated GunSerialNumber NOT_EXISTS.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${PROV}_GunQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $PROV
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
#  5. ArticleSingleQuery -- 1 metadata branch.
#     ArticleCategory and ArticleTypeCode are BOTH optionals of the same variant.
#     The live SDSO form feeds both from one picker and lets the platform split the
#     NCIC code; here they are separate optionals per the metadata.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        (PurposeAttr)
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleBrand';    size = 6; sourceField = @('ArticleBrand');    targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory'; size = 1; sourceField = @('ArticleCategory'); targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleTypeCode'; size = 6; sourceField = @('ArticleTypeCode'); targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','ArticleSerialNumber')
                any = @('ArticleBrand','ArticleCategory','ArticleTypeCode'); conditions = @()
            }
            primaryFieldReference = 'ArticleSerialNumber'; keyReference = 'QA'; state = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- the single metadata branch. Serial mandatory; brand, category and type optional.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${PROV}_ArticleSingleQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $PROV
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
#  6. BoatQuery -- 6 metadata branches, 4 built.
#     BQ carries State in <Any> (out-of-state path); 4B/4V/QB do not (in-state).
#     4B{Reg} is identical to QB{Reg}, and 4V{Hull} identical to QB{Hull} -- same
#     set[], same empty <Any> -- so each pair is one routable branch, not two.
#     Hull outranks Registration Number, so both Reg combos are gated Hull absent.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        (PurposeAttr)
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 10; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        (StateAttr)
    )
    combinations = @(
        [PSCustomObject]@{   # BQ{Hull} -- out of state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','BoatHullIdNumber'); any = @('RegistrationState'); conditions = @((StateOut))
            }
            primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'BQ.H'; state = 'Out'
        }
        [PSCustomObject]@{   # QB{Hull} -- in state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','BoatHullIdNumber'); any = @(); conditions = @((StateIn))
            }
            primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QB.H'; state = 'In'
        }
        [PSCustomObject]@{   # BQ{Reg} -- out of state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','RegistrationNumber'); any = @('RegistrationState')
                conditions = @((StateOut)) + (Absent @('BoatHullIdNumber'))
            }
            primaryFieldReference = 'RegistrationNumber'; keyReference = 'BQ.R'; state = 'Out'
        }
        [PSCustomObject]@{   # QB{Reg} -- in state
            requirements = [PSCustomObject]@{
                set = @('PurposeCode','RegistrationNumber'); any = @()
                conditions = @((StateIn)) + (Absent @('BoatHullIdNumber'))
            }
            primaryFieldReference = 'RegistrationNumber'; keyReference = 'QB.R'; state = 'In'
        }
    )
    description     = 'BoatQuery -- 4 of 6 metadata branches. Hull (BQ out / QB in) then Registration Number (BQ out / QB in), gated Hull NOT_EXISTS. 4B and 4V not built: identical set[] and empty Any to their QB twins.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${PROV}_BoatQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $PROV
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
#  LAYOUTS -- one card per entity, except Person which gets two (DL + DH),
#  which is the portfolio standard wherever both queries share the entity.
#  PurposeCode is a visible officer-selectable control on every entity: it is
#  MANDATORY on all 27 metadata branches, and it is NOT prefilled, so the officer
#  states the purpose deliberately.
# =====================================================================
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE -- plate, VIN or registered owner (leave State blank for California)'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'PurposeCode_Input';        node = Sel 'PurposeCode' 'CA Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for California)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Year (optional)' '4' 'ROW_VEH_3' }
            )}
            # MIDDLE + SUFFIX CONTROLS. The QIDM's Name composite has ALWAYS referenced nameMiddle
            # and nameSuffix (NameAttr's defaults), and metadata declares Name as
            # type="Name" maxLength="30" with Components First/Last/Middle/Suffix -- but v3.0 built
            # no controls for two of the four. That single omission produced 24 findings:
            # 8 verify_build FAILs ("sourceField not in QIF fieldIds") and all 16 audit_wiring_closure
            # class-C breaks ("references 'nameMiddle' -- no control on the form"), across Vehicle,
            # both Person cards and Firearm.
            # ADDING the controls is the fix, not stripping the sourceField: audit_name_components
            # records that 6 such controls were DELETED portfolio-wide on 2026-08-02 after
            # wiring-closure was misread as saying they should not exist -- that gate walks JSON->JSON
            # so it can say a control is USELESS, never that one is MISSING. The capability is
            # wire-proven (AZ_AZDPS v3.11 emits "DOE, JOHN A JR" and degrades cleanly).
            # Row widened 6+6 -> 4+4+2+2 so it still sums to 12 (audit_layout_flow L6); Last/First
            # keep the width, Middle/Suffix take the remainder.
            @{ id = 'ROW_VEH_4'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Owner Last Name'  '30' 'ROW_VEH_4' }
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'Owner First Name' '30' 'ROW_VEH_4' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name (optional)'      '30' 'ROW_VEH_4' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix (optional)'           '5'  'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('6','6'); fields = @(
                @{ id = 'AddressStreetNumber_Input'; node = Inp 'AddressStreetNumber' 'Street Number (optional)' '10' 'ROW_VEH_5' }
                @{ id = 'AddressCity_Input';         node = Inp 'AddressCity' 'City (optional)' '20' 'ROW_VEH_5' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle -- 1 card: plate (RQ/4/QV), VIN (RQ/QV), registered owner (VP).'
    label = 'Vehicle'; layout = $vehLayout; name = 'ENTITY_Vehicle'
    type  = 'QUERYINPUTFORM'; targetEntity = 'Vehicle'
}

$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_DL'
        title = 'DRIVER LICENSE -- OLN, or name with a qualifier (leave State blank for California)'
        rows  = @(
            @{ id = 'ROW_DL_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'PurposeCode_Input';           node = Sel 'PurposeCode' 'CA Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_DL_1' }
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_DL_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State (leave blank for California)' @{ attributeTypeId = 'STATE' } 'ROW_DL_1' }
            )}
            @{ id = 'ROW_DL_2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_DL_2' }
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_DL_2' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name (optional)' '30' 'ROW_DL_2' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix (optional)'      '5'  'ROW_DL_2' }
            )}
            @{ id = 'ROW_DL_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_DL_3' }
                @{ id = 'Age_Input';       node = Inp 'Age' 'Age' '3' 'ROW_DL_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_DH'
        title = 'DRIVER HISTORY -- separate query; fill these fields to run it'
        rows  = @(
            @{ id = 'ROW_DH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'PurposeCodeDH_Input';           node = Sel 'PurposeCodeDH' 'CA Purpose Code (DH)' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_DH_1' }
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_DH_1' }
                @{ id = 'RegistrationStateDH_Input';     node = Sel 'RegistrationStateDH' 'State (DH) (leave blank for California)' @{ attributeTypeId = 'STATE' } 'ROW_DH_1' }
            )}
            @{ id = 'ROW_DH_2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name (DH)'   '30' 'ROW_DH_2' }
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name (DH)'  '30' 'ROW_DH_2' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH)' '30' 'ROW_DH_2' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH)'      '5'  'ROW_DH_2' }
            )}
            @{ id = 'ROW_DH_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth (DH)' 'ROW_DH_3' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DH_3' }
            )}
            # Attention is auto-populated by CommsysGetLastNameFirstNameInitialRuleHandler from the
            # DH name fields. HIDDEN and NOT prefilled: any[] membership alone feeds the handler.
            @{ id = 'ROW_DH_HID'; cols = @('12'); fields = @(
                @{ id = 'AttentionDH_Input'; node = InpH 'AttentionDH' 'Attention (auto)' $null 'ROW_DH_HID' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person -- 2 cards: Driver License and Driver History. DH-suffix fieldIds keep the two query pools separate.'
    label = 'Person'; layout = $perLayout; name = 'ENTITY_Person'
    type  = 'QUERYINPUTFORM'; targetEntity = 'Person'
}

$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_FA'
        title = 'FIREARM -- serial number, or name with date of birth or age'
        rows  = @(
            @{ id = 'ROW_FA_1'; cols = @('6','6'); fields = @(
                @{ id = 'PurposeCode_Input';     node = Sel 'PurposeCode' 'CA Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_FA_1' }
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '20' 'ROW_FA_1' }
            )}
            @{ id = 'ROW_FA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunMake_Input';     node = Sel 'GunMake' 'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_FA_2' }
                @{ id = 'GunCaliber_Input';  node = Sel 'GunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_FA_2' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'GunTypeCode' 'Type (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' } 'ROW_FA_2' }
            )}
            @{ id = 'ROW_FA_3'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_FA_3' }
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_FA_3' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name (optional)' '30' 'ROW_FA_3' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix (optional)'      '5'  'ROW_FA_3' }
            )}
            @{ id = 'ROW_FA_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_FA_4' }
                @{ id = 'Age_Input';       node = Inp 'Age' 'Age' '3' 'ROW_FA_4' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_FA_4' }
            )}
        )
    }
)
$firearmForm = [PSCustomObject]@{
    description  = 'Firearm -- 1 card: serial (QGB) or name with the mandatory DOB/Age qualifier (QGH).'
    label = 'Firearm'; layout = $faLayout; name = 'ENTITY_Firearm'
    type  = 'QUERYINPUTFORM'; targetEntity = 'Firearm'
}

$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE -- serial number'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'PurposeCode_Input';         node = Sel 'PurposeCode' 'CA Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_ART_1' }
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number / OAN' '20' 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type (optional)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_2' }
                @{ id = 'ArticleCategory_Input'; node = Inp 'ArticleCategory' 'Article Category (optional)' '1' 'ROW_ART_2' }
                @{ id = 'ArticleBrand_Input';    node = Inp 'ArticleBrand' 'Brand (optional)' '6' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article -- 1 card: serial mandatory, brand/category/type optional.'
    label = 'Article'; layout = $artLayout; name = 'ENTITY_Article'
    type  = 'QUERYINPUTFORM'; targetEntity = 'Article'
}

$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT -- hull ID or registration number (leave State blank for California)'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'PurposeCode_Input';      node = Sel 'PurposeCode' 'CA Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '10' 'ROW_BOA_2' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for California)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat -- 1 card: hull (BQ/QB) outranks registration number (BQ/QB).'
    label = 'Boat'; layout = $boaLayout; name = 'ENTITY_Boat'
    type  = 'QUERYINPUTFORM'; targetEntity = 'Boat'
}

# =====================================================================
#  ASSEMBLE -- ENTITIES first (forms do not render otherwise), then PROVIDER,
#  then RMS built from the KB specs.
# =====================================================================
$entitiesBundle = Build-EntitiesBundle -Configurations @(
    $vehicleForm, $personForm, $firearmForm, $articleForm, $boatForm)

$providerBundle = [PSCustomObject]@{
    configurations = @($auth, $qmf, $results,
        $vehQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description = "Provider configuration for ${PROV} v${Version} -- MAINLINE, built from scratch from the devdoc (query authority) and metadata (field authority). Six devdoc-Basic queries, 23 of 27 metadata variant branches built; 4 are routing-impossible duplicates and are registered. Existence-only State gates and identifier-priority guardrails throughout. Distinct from the v1.x/v2.x RADIOBUTTON line, which is a capture of the hand-built San Diego Sheriff configuration."
    name        = $PROV
    type        = 'BUNDLE'
    provider    = $PROV
}

$rmsBundle = Build-RmsBundle -PascalCaseUsxFields

$output = [PSCustomObject]@{ bundles = @($entitiesBundle, $providerBundle, $rmsBundle) }

Write-ProviderJson -BundleObject $output -OutPath $OUT -Label "${PROV} v${Version} (mainline, from scratch)" -Version $Version
