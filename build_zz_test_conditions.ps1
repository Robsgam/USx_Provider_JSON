# build_zz_test_conditions.ps1  --  TEST-ONLY platform-behavior BASELINE (NOT a real provider)
# Probes how a tenant actually evaluates QueryInputDataMapping conditions + defaults vs the
# Cringer "QueryInputDataMapping / Attribute Handle" docs. Read answers from REQUEST XML markers
# (hidden fields with initialValue that serialize when their combo fires). Each query has a
# no-condition KEEP-ALIVE combo (ordered last) so the query never fully grays out -> you always
# get a request and can read which conditioned combos fired.
#
# GROUPS (one query each):
#   A Person/DriverLicenseQuery      -- EQUALS / NOT_EQUALS
#   B Person/DriverHistoryQuery      -- EXISTS / NOT_EXISTS / poisoned-array (value-cond beside NOT_EXISTS)
#   C Vehicle/VehicleRegistrationQuery-- defaults on set[] (no-op per doc) vs any[] (applies)
#   D Firearm/GunQuery               -- IN / NOT_IN (incl. "null" literal = matches absent field)
#   E Article/ArticleSingleQuery     -- REGEX
#   F Boat/BoatQuery                 -- EXCLUSIVE (doc: frontend-only; backend always passes)
#
# Run per tenant (NJ, HI, FL USx test tenants) and diff -- baseline should be identical if all
# tenants are same platform level. See instructions printed at end / chat.
param([string]$ProviderName = 'ZZ_TEST_CONDITIONS')

. "$PSScriptRoot\tools\_build_rms_bundle.ps1"
. "$PSScriptRoot\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\tools\_build_provider_helpers.ps1"

$P = $ProviderName
function MkAttr($n)        { Build-QidmAttribute -Name $n -Size 20 -SourceField @($n) }
function MkMarker($n,$row,$val) { @{ id = "${n}_Input"; node = InpH $n 'marker' '20' $row @{ initialValue = $val } } }
function InField($n,$lbl,$sz,$row) { @{ id = "${n}_Input"; node = Inp $n $lbl $sz $row } }
function Cond($field,$op,$vals) {
    if ($PSBoundParameters.ContainsKey('vals') -and $null -ne $vals) {
        [PSCustomObject]@{ field = @($field); operator = $op; value = @($vals) }
    } else {
        [PSCustomObject]@{ field = @($field); operator = $op }
    }
}
function Qidm($entity,$query,$label,$attrs,$combos) {
    [PSCustomObject]@{
        attributes = $attrs; combinations = $combos
        description = "BASELINE $label"; handlerFunction = 'CommsysTransactionRequestHandler'
        name = "${P}_${query}"; type = 'QUERYINPUTDATAMAPPING'; autoSelect = $true
        provider = $P; providerType = 'Commsys'; query = $query; queryLabel = $label; targetEntity = $entity
    }
}

$auth    = Build-Auth        -ProviderName $P
$results = Build-ProviderQrdm -ProviderName $P
$qmf     = Build-Qmf         -ProviderName $P

# ===== A: EQUALS / NOT_EQUALS (Person / DriverLicenseQuery) =====
$qA = Qidm 'Person' 'DriverLicenseQuery' 'A EQUALS-NOTEQUALS' @(
    MkAttr 'A_OLN'; MkAttr 'A_STATE'; MkAttr 'MK_AEQ'; MkAttr 'MK_ANE'; MkAttr 'MK_AKEEP'
) @(
    Build-QidmCombo -KeyReference 'A_EQ'   -PrimaryFieldReference 'A_OLN' -Set @('A_OLN') -Any @('MK_AEQ') -Conditions @( (Cond 'A_STATE' 'EQUALS'     'CA') )
    Build-QidmCombo -KeyReference 'A_NE'   -PrimaryFieldReference 'A_OLN' -Set @('A_OLN') -Any @('MK_ANE') -Conditions @( (Cond 'A_STATE' 'NOT_EQUALS' 'CA') )
    Build-QidmCombo -KeyReference 'A_KEEP' -PrimaryFieldReference 'A_OLN' -Set @('A_OLN') -Any @('MK_AKEEP')
)

# ===== B: EXISTS / NOT_EXISTS / poisoned-array (Person / DriverHistoryQuery) =====
$qB = Qidm 'Person' 'DriverHistoryQuery' 'B EXISTS-NOTEXISTS-POISON' @(
    MkAttr 'B_OLN'; MkAttr 'B_EXIST'; MkAttr 'B_NOTEXIST'; MkAttr 'B_STATE'
    MkAttr 'MK_BEXIST'; MkAttr 'MK_BNOTEXIST'; MkAttr 'MK_BPOISON'; MkAttr 'MK_BKEEP'
) @(
    Build-QidmCombo -KeyReference 'B_EXISTS'    -PrimaryFieldReference 'B_OLN' -Set @('B_OLN') -Any @('MK_BEXIST')    -Conditions @( (Cond 'B_EXIST'    'EXISTS') )
    Build-QidmCombo -KeyReference 'B_NOTEXISTS' -PrimaryFieldReference 'B_OLN' -Set @('B_OLN') -Any @('MK_BNOTEXIST') -Conditions @( (Cond 'B_NOTEXIST' 'NOT_EXISTS') )
    Build-QidmCombo -KeyReference 'B_POISON'    -PrimaryFieldReference 'B_OLN' -Set @('B_OLN') -Any @('MK_BPOISON')   -Conditions @( (Cond 'B_NOTEXIST' 'NOT_EXISTS'), (Cond 'B_STATE' 'EQUALS' 'CA') )
    Build-QidmCombo -KeyReference 'B_KEEP'      -PrimaryFieldReference 'B_OLN' -Set @('B_OLN') -Any @('MK_BKEEP')
)

# ===== C: defaults set[] vs any[] (Vehicle / VehicleRegistrationQuery) =====
$qC = Qidm 'Vehicle' 'VehicleRegistrationQuery' 'C DEFAULTS set-vs-any' @(
    MkAttr 'C_VIN'; MkAttr 'C_PLATE'; MkAttr 'C_ANYDEF'; MkAttr 'C_SETDEF'; MkAttr 'MK_C1'; MkAttr 'MK_C2'
) @(
    Build-QidmCombo -KeyReference 'C1_ANYDEF' -PrimaryFieldReference 'C_VIN'   -Set @('C_VIN')           -Any @('C_ANYDEF','MK_C1') -Defaults @( [PSCustomObject]@{ field = 'C_ANYDEF'; value = 'ANYDEF_OK' } )
    Build-QidmCombo -KeyReference 'C2_SETDEF' -PrimaryFieldReference 'C_PLATE' -Set @('C_PLATE','C_SETDEF') -Any @('MK_C2')        -Defaults @( [PSCustomObject]@{ field = 'C_SETDEF'; value = 'SETDEF_OK' } )
)

# ===== D: IN / NOT_IN (Firearm / GunQuery) =====
$qD = Qidm 'Firearm' 'GunQuery' 'D IN-NOTIN' @(
    MkAttr 'D_SERIAL'; MkAttr 'D_VAL'; MkAttr 'MK_DIN'; MkAttr 'MK_DNOTIN'; MkAttr 'MK_DINNULL'; MkAttr 'MK_DKEEP'
) @(
    Build-QidmCombo -KeyReference 'D_IN'     -PrimaryFieldReference 'D_SERIAL' -Set @('D_SERIAL') -Any @('MK_DIN')     -Conditions @( (Cond 'D_VAL' 'IN'     @('CA','NY')) )
    Build-QidmCombo -KeyReference 'D_NOTIN'  -PrimaryFieldReference 'D_SERIAL' -Set @('D_SERIAL') -Any @('MK_DNOTIN')  -Conditions @( (Cond 'D_VAL' 'NOT_IN' @('CA','NY')) )
    Build-QidmCombo -KeyReference 'D_INNULL' -PrimaryFieldReference 'D_SERIAL' -Set @('D_SERIAL') -Any @('MK_DINNULL') -Conditions @( (Cond 'D_VAL' 'IN'     @('CA','null')) )
    Build-QidmCombo -KeyReference 'D_KEEP'   -PrimaryFieldReference 'D_SERIAL' -Set @('D_SERIAL') -Any @('MK_DKEEP')
)

# ===== E: REGEX (Article / ArticleSingleQuery) =====
$qE = Qidm 'Article' 'ArticleSingleQuery' 'E REGEX' @(
    MkAttr 'E_SERIAL'; MkAttr 'E_VAL'; MkAttr 'MK_EREGEX'; MkAttr 'MK_EKEEP'
) @(
    Build-QidmCombo -KeyReference 'E_REGEX' -PrimaryFieldReference 'E_SERIAL' -Set @('E_SERIAL') -Any @('MK_EREGEX') -Conditions @( (Cond 'E_VAL' 'REGEX' '^[A-Z]{2}[0-9]{3}$') )
    Build-QidmCombo -KeyReference 'E_KEEP'  -PrimaryFieldReference 'E_SERIAL' -Set @('E_SERIAL') -Any @('MK_EKEEP')
)

# ===== F: EXCLUSIVE (Boat / BoatQuery) -- doc: frontend-only =====
$qF = Qidm 'Boat' 'BoatQuery' 'F EXCLUSIVE' @(
    MkAttr 'F_HULL'; MkAttr 'F_A'; MkAttr 'F_B'; MkAttr 'MK_FEXCL'; MkAttr 'MK_FKEEP'
) @(
    Build-QidmCombo -KeyReference 'F_EXCL' -PrimaryFieldReference 'F_HULL' -Set @('F_HULL') -Any @('MK_FEXCL') -Conditions @( (Cond @('F_A','F_B') 'EXCLUSIVE') )
    Build-QidmCombo -KeyReference 'F_KEEP' -PrimaryFieldReference 'F_HULL' -Set @('F_HULL') -Any @('MK_FKEEP')
)

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $qA, $qB, $qC, $qD, $qE, $qF)
    description    = "TEST-ONLY behavior baseline for $P"; name = $P; type = 'BUNDLE'; provider = $P
}

# ===== FORMS =====
$perLayout = MakeLayouts @(
    @{ id = 'CARD_PER'; title = 'PERSON -- A: value-ops (DL), B: exists/poison (DH)'; rows = @(
        @{ id = 'ROW_A'; cols = @('6','6'); fields = @(
            (InField 'A_OLN'   'A: OLN (fill for Test A)'        '20' 'ROW_A')
            (InField 'A_STATE' 'A: State -- enter CA or NY'      '2'  'ROW_A')
        )}
        @{ id = 'ROW_B'; cols = @('3','3','3','3'); fields = @(
            (InField 'B_OLN'       'B: OLN (fill for Test B)'    '20' 'ROW_B')
            (InField 'B_EXIST'     'B: Exist fld (EXISTS test)'  '20' 'ROW_B')
            (InField 'B_NOTEXIST'  'B: NotExist fld'             '20' 'ROW_B')
            (InField 'B_STATE'     'B: State (poison, enter CA)' '2'  'ROW_B')
        )}
        @{ id = 'ROW_PMK1'; cols = @('4','4','4'); hidden = $true; fields = @(
            (MkMarker 'MK_AEQ'  'ROW_PMK1' 'AEQ'); (MkMarker 'MK_ANE' 'ROW_PMK1' 'ANE'); (MkMarker 'MK_AKEEP' 'ROW_PMK1' 'AKEEP')
        )}
        @{ id = 'ROW_PMK2'; cols = @('3','3','3','3'); hidden = $true; fields = @(
            (MkMarker 'MK_BEXIST' 'ROW_PMK2' 'BEXIST'); (MkMarker 'MK_BNOTEXIST' 'ROW_PMK2' 'BNOTEXIST'); (MkMarker 'MK_BPOISON' 'ROW_PMK2' 'BPOISON'); (MkMarker 'MK_BKEEP' 'ROW_PMK2' 'BKEEP')
        )}
    )}
)
$personForm = [PSCustomObject]@{ description = 'A + B'; label = 'Person'; layout = $perLayout; name = 'ENTITY_Person'; type = 'QUERYINPUTFORM'; targetEntity = 'Person' }

$vehLayout = MakeLayouts @(
    @{ id = 'CARD_VEH'; title = 'VEHICLE -- C: defaults set vs any'; rows = @(
        @{ id = 'ROW_C1'; cols = @('6','6'); fields = @( (InField 'C_VIN' 'C1: VIN (fill ALONE)' '20' 'ROW_C1'); (InField 'C_ANYDEF' 'C1: AnyDef -- LEAVE BLANK' '10' 'ROW_C1') )}
        @{ id = 'ROW_C2'; cols = @('6','6'); fields = @( (InField 'C_PLATE' 'C2: Plate (fill ALONE)' '10' 'ROW_C2'); (InField 'C_SETDEF' 'C2: SetDef -- LEAVE BLANK' '10' 'ROW_C2') )}
        @{ id = 'ROW_VMK'; cols = @('6','6'); hidden = $true; fields = @( (MkMarker 'MK_C1' 'ROW_VMK' 'C1'); (MkMarker 'MK_C2' 'ROW_VMK' 'C2') )}
    )}
)
$vehicleForm = [PSCustomObject]@{ description = 'C'; label = 'Vehicle'; layout = $vehLayout; name = 'ENTITY_Vehicle'; type = 'QUERYINPUTFORM'; targetEntity = 'Vehicle' }

$gunLayout = MakeLayouts @(
    @{ id = 'CARD_GUN'; title = 'FIREARM -- D: IN / NOT_IN'; rows = @(
        @{ id = 'ROW_D'; cols = @('6','6'); fields = @( (InField 'D_SERIAL' 'D: Serial (fill for Test D)' '20' 'ROW_D'); (InField 'D_VAL' 'D: Val -- enter CA / TX / blank' '20' 'ROW_D') )}
        @{ id = 'ROW_DMK'; cols = @('3','3','3','3'); hidden = $true; fields = @( (MkMarker 'MK_DIN' 'ROW_DMK' 'DIN'); (MkMarker 'MK_DNOTIN' 'ROW_DMK' 'DNOTIN'); (MkMarker 'MK_DINNULL' 'ROW_DMK' 'DINNULL'); (MkMarker 'MK_DKEEP' 'ROW_DMK' 'DKEEP') )}
    )}
)
$firearmForm = [PSCustomObject]@{ description = 'D'; label = 'Firearm'; layout = $gunLayout; name = 'ENTITY_Firearm'; type = 'QUERYINPUTFORM'; targetEntity = 'Firearm' }

$artLayout = MakeLayouts @(
    @{ id = 'CARD_ART'; title = 'ARTICLE -- E: REGEX (^[A-Z]{2}[0-9]{3}$)'; rows = @(
        @{ id = 'ROW_E'; cols = @('6','6'); fields = @( (InField 'E_SERIAL' 'E: Serial (fill for Test E)' '20' 'ROW_E'); (InField 'E_VAL' 'E: Val -- try AB123 vs XXXX' '20' 'ROW_E') )}
        @{ id = 'ROW_EMK'; cols = @('6','6'); hidden = $true; fields = @( (MkMarker 'MK_EREGEX' 'ROW_EMK' 'EREGEX'); (MkMarker 'MK_EKEEP' 'ROW_EMK' 'EKEEP') )}
    )}
)
$articleForm = [PSCustomObject]@{ description = 'E'; label = 'Article'; layout = $artLayout; name = 'ENTITY_Article'; type = 'QUERYINPUTFORM'; targetEntity = 'Article' }

$boaLayout = MakeLayouts @(
    @{ id = 'CARD_BOA'; title = 'BOAT -- F: EXCLUSIVE (F_A vs F_B)'; rows = @(
        @{ id = 'ROW_F'; cols = @('4','4','4'); fields = @( (InField 'F_HULL' 'F: Hull (fill for Test F)' '20' 'ROW_F'); (InField 'F_A' 'F: A (EXCLUSIVE)' '20' 'ROW_F'); (InField 'F_B' 'F: B (EXCLUSIVE)' '20' 'ROW_F') )}
        @{ id = 'ROW_FMK'; cols = @('6','6'); hidden = $true; fields = @( (MkMarker 'MK_FEXCL' 'ROW_FMK' 'FEXCL'); (MkMarker 'MK_FKEEP' 'ROW_FMK' 'FKEEP') )}
    )}
)
$boatForm = [PSCustomObject]@{ description = 'F'; label = 'Boat'; layout = $boaLayout; name = 'ENTITY_Boat'; type = 'QUERYINPUTFORM'; targetEntity = 'Boat' }

$entitiesBundle = Build-EntitiesBundle -Configurations @($personForm, $vehicleForm, $firearmForm, $articleForm, $boatForm) `
    -DefaultOrder @('Person','Vehicle','Firearm','Article','Boat') -CadOrder @('Person','Vehicle','Firearm','Article','Boat') -FrOrder @('Person','Vehicle','Firearm','Article','Boat')

$rmsBundle = Build-RmsBundle
$output = [PSCustomObject]@{ bundles = @($entitiesBundle, $provBundle, $rmsBundle) }

$OUT = Join-Path $PSScriptRoot 'ZZ_TEST_CONDITIONS.json'
Write-ProviderJson -BundleObject $output -OutPath $OUT -Label "Built TEST-ONLY behavior baseline $P"
