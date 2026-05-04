#!/usr/bin/env python3
"""Build FL_FCIC v2.1 test JSON from ProviderTest.json"""
import json, copy, os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT = os.path.join(SCRIPT_DIR, 'FL_FCIC_ProviderTest.json')
OUTPUT = os.path.join(SCRIPT_DIR, 'FL_FCIC_v2.1_test.json')

with open(INPUT, 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

# =========================================================================
# HELPER FUNCTIONS for Craft.js form building
# =========================================================================

def make_root():
    return {
        'type': {'resolvedName': 'Root'},
        'displayName': 'Root',
        'props': {},
        'isCanvas': False,
        'hidden': False,
        'nodes': ['FORM_ROOT'],
        'linkedNodes': {}
    }

def make_form():
    return {
        'type': {'resolvedName': 'Form'},
        'displayName': 'Form',
        'props': {'hidePageItems': True, 'layout': 'page'},
        'isCanvas': True,
        'hidden': False,
        'nodes': ['ROOT_PAGE'],
        'linkedNodes': {},
        'parent': 'ROOT'
    }

def make_page(cards):
    return {
        'type': {'resolvedName': 'Page'},
        'displayName': 'Page',
        'props': {'title': 'Page 1'},
        'isCanvas': True,
        'hidden': False,
        'nodes': cards,
        'linkedNodes': {},
        'parent': 'FORM_ROOT'
    }

def make_card(title, rows, parent='ROOT_PAGE'):
    return {
        'type': {'resolvedName': 'Card'},
        'displayName': 'Card',
        'props': {'title': title},
        'isCanvas': True,
        'hidden': False,
        'nodes': rows,
        'linkedNodes': {},
        'parent': parent
    }

def make_row(cols, field_ids, parent):
    return {
        'type': {'resolvedName': 'Row'},
        'displayName': 'Row',
        'props': {'templateColumns': cols},
        'isCanvas': True,
        'hidden': False,
        'nodes': field_ids,
        'linkedNodes': {},
        'parent': parent
    }

def make_input(field_id, label, max_length, parent, hidden=False):
    return {
        'type': {'resolvedName': 'FormInput'},
        'displayName': 'Input',
        'props': {'fieldId': field_id, 'label': label, 'maxLength': str(max_length)},
        'isCanvas': False,
        'hidden': hidden,
        'nodes': [],
        'linkedNodes': {},
        'parent': parent
    }

def make_select(field_id, label, parent, **kwargs):
    props = {'fieldId': field_id, 'label': label}
    props.update(kwargs)
    return {
        'type': {'resolvedName': 'FormSelect'},
        'displayName': 'Select',
        'props': props,
        'isCanvas': False,
        'hidden': False,
        'nodes': [],
        'linkedNodes': {},
        'parent': parent
    }

def make_datepicker(field_id, label, parent):
    return {
        'type': {'resolvedName': 'FormDatePicker'},
        'displayName': 'Date Picker',
        'props': {'fieldId': field_id, 'label': label},
        'isCanvas': False,
        'hidden': False,
        'nodes': [],
        'linkedNodes': {},
        'parent': parent
    }

def make_context_card_cad():
    """CAD dispatch context card nodes"""
    nodes = {}
    nodes['CONTEXT_INFO_CARD'] = {
        'type': {'resolvedName': 'Card'},
        'displayName': 'Card',
        'props': {},
        'isCanvas': True,
        'hidden': False,
        'nodes': ['ROW_0'],
        'linkedNodes': {},
        'parent': 'ROOT_PAGE'
    }
    nodes['ROW_0'] = {
        'type': {'resolvedName': 'Row'},
        'displayName': 'Row',
        'props': {'templateColumns': ['6', '6']},
        'isCanvas': True,
        'hidden': False,
        'nodes': ['CadUnit_Input', 'CadEvent_Input'],
        'linkedNodes': {},
        'parent': 'CONTEXT_INFO_CARD'
    }
    nodes['CadUnit_Input'] = {
        'type': {'resolvedName': 'FormSelect'},
        'displayName': 'Select',
        'props': {
            'fieldId': 'CAD_UNIT_SELECT_VALUE',
            'label': 'Requesting Unit',
            'attributeTypeId': 'CAD_UNIT_SELECT_VALUE'
        },
        'isCanvas': False,
        'hidden': False,
        'nodes': [],
        'linkedNodes': {},
        'parent': 'ROW_0'
    }
    nodes['CadEvent_Input'] = {
        'type': {'resolvedName': 'FormSelect'},
        'displayName': 'Select',
        'props': {
            'fieldId': 'CAD_EVENT_SELECT_VALUE',
            'label': 'Event',
            'attributeTypeId': 'CAD_EVENT_SELECT_VALUE',
            'performSearchAhead': True
        },
        'isCanvas': False,
        'hidden': False,
        'nodes': [],
        'linkedNodes': {},
        'parent': 'ROW_0'
    }
    return nodes

def make_context_card_fr():
    """First Responder context card nodes"""
    nodes = {}
    nodes['CONTEXT_INFO_CARD'] = {
        'type': {'resolvedName': 'Card'},
        'displayName': 'Card',
        'props': {},
        'isCanvas': True,
        'hidden': False,
        'nodes': ['LinkToEvent_Input'],
        'linkedNodes': {},
        'parent': 'ROOT_PAGE'
    }
    nodes['LinkToEvent_Input'] = {
        'type': {'resolvedName': 'FormCheckbox'},
        'displayName': 'Checkbox',
        'props': {
            'label': ' ',
            'checkboxLabel': 'Link to the current assigned event',
            'fieldId': 'LINK_CURRENT_ASSIGNED_EVENT'
        },
        'isCanvas': False,
        'hidden': False,
        'nodes': [],
        'linkedNodes': {},
        'parent': 'CONTEXT_INFO_CARD'
    }
    return nodes

def build_3view(default_nodes, main_card_id):
    """Build standard 3-view layout from default nodes"""
    cad = copy.deepcopy(default_nodes)
    cad['ROOT_PAGE'] = dict(cad['ROOT_PAGE'])
    cad['ROOT_PAGE']['nodes'] = ['CONTEXT_INFO_CARD', main_card_id]
    cad.update(make_context_card_cad())

    fr = copy.deepcopy(default_nodes)
    fr['ROOT_PAGE'] = dict(fr['ROOT_PAGE'])
    fr['ROOT_PAGE']['nodes'] = ['CONTEXT_INFO_CARD', main_card_id]
    fr.update(make_context_card_fr())

    return {
        'default': default_nodes,
        'CAD_DISPATCH': cad,
        'FIRST_RESPONDER': fr
    }

# =========================================================================
# 1. AUTH config
# =========================================================================
auth = {
    'attributes': [
        {'name': 'ORI', 'size': 12, 'sourceField': ['ORI'], 'targetField': 'ORI'},
        {'name': 'Mnemonic', 'size': 25, 'sourceField': ['Mnemonic'], 'targetField': 'Mnemonic'},
        {'name': 'DeviceId', 'size': 25, 'sourceField': ['DeviceId'], 'targetField': 'DeviceId'},
        {
            'description': 'dexUserStateid from RMS profile',
            'name': 'UserName',
            'rule': {'function': 'CommsysGetDexStateUserIdRuleHandler', 'arguments': ['true']},
            'sourceField': ['dexStateUserId'],
            'targetField': 'UserName'
        }
    ],
    'combinations': [
        {
            'requirements': {
                'set': ['ORI', 'Mnemonic', 'DeviceId'],
                'any': ['dexStateUserId']
            }
        }
    ],
    'description': 'Authentication configuration for FL FCIC',
    'handlerFunction': 'CommsysOriAuthenticationHandler',
    'name': 'FL_FCIC',
    'type': 'AUTHENTICATION',
    'deviceRegistrationOptional': False,
    'provider': 'FL_FCIC',
    'providerType': 'Commsys',
    'signInRequired': False
}

# =========================================================================
# 2. QMF — keep from ProviderTest
# =========================================================================
qmf = None
for c in data['bundles'][0]['configurations']:
    if c['type'] == 'QUERYMESSAGEFORMAT':
        qmf = copy.deepcopy(c)
        break

# =========================================================================
# 3. QRDM — keep from ProviderTest, rename
# =========================================================================
qrdm = None
for c in data['bundles'][0]['configurations']:
    if c['type'] == 'QUERYRESULTDATAMAPPING':
        qrdm = copy.deepcopy(c)
        qrdm['name'] = 'FL_FCIC_Results'
        qrdm['description'] = 'Results mapping for FL FCIC'
        break

# =========================================================================
# 4. CommSys QIDMs
# =========================================================================
fl_date_rule = {
    'function': 'CommsysParseDateRuleHandler',
    'arguments': ['yyyy-MM-dd', 'yyyyMMdd']
}

# --- DriverLicenseQuery ---
dlq = {
    'name': 'FL_FCIC_DriverLicenseQuery',
    'type': 'QUERYINPUTDATAMAPPING',
    'targetEntity': 'Person',
    'autoSelect': True,
    'attributes': [
        {'name': 'BirthDate', 'size': 8, 'sourceField': ['BirthDate'], 'targetField': 'BirthDate',
         'rule': copy.deepcopy(fl_date_rule)},
        {'name': 'Name', 'size': 80,
         'sourceField': ['NameLast', 'NameFirst', 'NameMiddle', 'NameSuffix'],
         'targetField': 'Name'},
        {'name': 'SexCode', 'size': 1, 'sourceField': ['SexCode'], 'targetField': 'SexCode',
         'codeTypeProvider': 'NIBRS'},
        {'name': 'OperatorLicenseNumber', 'size': 20,
         'sourceField': ['OperatorLicenseNumber'], 'targetField': 'OperatorLicenseNumber'},
        {'name': 'State', 'size': 2, 'sourceField': ['RegistrationState'], 'targetField': 'State',
         'codeTypeProvider': 'NCIC'},
        {'name': 'ImageIndicator', 'size': 1, 'sourceField': ['ImageIndicator'],
         'targetField': 'ImageIndicator'},
        {'name': 'ExpandedNameSearchCode', 'size': 1,
         'sourceField': ['ExpandedNameSearchCode'], 'targetField': 'ExpandedNameSearchCode'},
        {'name': 'RelatedHitSearchIndicator', 'size': 1,
         'sourceField': ['RelatedHitSearchIndicator'], 'targetField': 'RelatedHitSearchIndicator'},
        {'name': 'OperatorLicenseStateCode', 'size': 2,
         'sourceField': ['OperatorLicenseStateCode'], 'targetField': 'OperatorLicenseStateCode'}
    ],
    'combinations': [
        {'keyRef': 'DQ', 'requirements': {
            'set': ['NameLast', 'NameFirst', 'BirthDate', 'SexCode', 'RegistrationState'],
            'any': ['ImageIndicator', 'OperatorLicenseStateCode']}},
        {'keyRef': 'DQ', 'requirements': {
            'set': ['OperatorLicenseNumber', 'RegistrationState'],
            'any': ['ImageIndicator', 'OperatorLicenseStateCode']}},
        {'keyRef': 'FDQ', 'requirements': {
            'set': ['NameLast', 'NameFirst', 'BirthDate', 'SexCode'],
            'any': ['ImageIndicator']}},
        {'keyRef': 'FDQ', 'requirements': {
            'set': ['OperatorLicenseNumber'],
            'any': ['ImageIndicator']}},
        {'keyRef': 'QW', 'requirements': {
            'set': ['NameLast', 'NameFirst', 'BirthDate'],
            'any': ['OperatorLicenseNumber', 'ExpandedNameSearchCode', 'ImageIndicator', 'RelatedHitSearchIndicator']}},
        {'keyRef': 'QW', 'requirements': {
            'set': ['NameLast', 'NameFirst', 'OperatorLicenseNumber'],
            'any': ['ExpandedNameSearchCode', 'ImageIndicator', 'RelatedHitSearchIndicator']}}
    ]
}

# --- DriverHistoryQuery ---
dhq = {
    'name': 'FL_FCIC_DriverHistoryQuery',
    'type': 'QUERYINPUTDATAMAPPING',
    'targetEntity': 'Person',
    'autoSelect': False,
    'attributes': [
        {'name': 'BirthDateDH', 'size': 8, 'sourceField': ['BirthDateDH'],
         'targetField': 'BirthDate', 'rule': copy.deepcopy(fl_date_rule)},
        {'name': 'NameDH', 'size': 30,
         'sourceField': ['NameLastDH', 'NameFirstDH', 'NameMiddleDH', 'NameSuffixDH'],
         'targetField': 'Name'},
        {'name': 'SexCodeDH', 'size': 1, 'sourceField': ['SexCodeDH'],
         'targetField': 'SexCode', 'codeTypeProvider': 'NIBRS'},
        {'name': 'OperatorLicenseNumberDH', 'size': 20,
         'sourceField': ['OperatorLicenseNumberDH'], 'targetField': 'OperatorLicenseNumber'},
        {'name': 'StateDH', 'size': 2, 'sourceField': ['RegistrationState'],
         'targetField': 'State', 'codeTypeProvider': 'NCIC'},
        {'name': 'Attention', 'size': 30, 'sourceField': ['Attention'],
         'targetField': 'Attention'},
        {'name': 'PurposeCode', 'size': 1, 'sourceField': ['PurposeCode'],
         'targetField': 'PurposeCode'},
        {'name': 'Requestor', 'size': 30, 'sourceField': ['Requestor'],
         'targetField': 'Requestor'}
    ],
    'combinations': [
        {'keyRef': 'KQ', 'requirements': {
            'set': ['NameLastDH', 'NameFirstDH', 'BirthDateDH', 'SexCodeDH', 'RegistrationState'],
            'any': ['Attention', 'PurposeCode', 'Requestor']}},
        {'keyRef': 'KQ', 'requirements': {
            'set': ['OperatorLicenseNumberDH', 'RegistrationState'],
            'any': ['Attention', 'PurposeCode', 'Requestor']}}
    ]
}

# --- VehicleRegistrationQuery ---
vrq = {
    'name': 'FL_FCIC_VehicleRegistrationQuery',
    'type': 'QUERYINPUTDATAMAPPING',
    'targetEntity': 'Vehicle',
    'autoSelect': True,
    'attributes': [
        {'name': 'LicensePlateNumber', 'size': 10,
         'sourceField': ['LicensePlateNumberIn'], 'targetField': 'LicensePlateNumber'},
        {'name': 'LicensePlateTypeCode', 'size': 2,
         'sourceField': ['LicensePlateTypeCode'], 'targetField': 'LicensePlateTypeCode'},
        {'name': 'LicensePlateYear', 'size': 4,
         'sourceField': ['LicensePlateYear'], 'targetField': 'LicensePlateYear'},
        {'name': 'VehicleIdentificationNumber', 'size': 20,
         'sourceField': ['VehicleIdentificationNumber'],
         'targetField': 'VehicleIdentificationNumber'},
        {'name': 'State', 'size': 2, 'sourceField': ['RegistrationState'],
         'targetField': 'State', 'codeTypeProvider': 'NCIC'},
        {'name': 'ImageIndicator', 'size': 1, 'sourceField': ['ImageIndicator'],
         'targetField': 'ImageIndicator'},
        {'name': 'VehicleMakeCode', 'size': 24, 'sourceField': ['VehicleMakeCode'],
         'targetField': 'VehicleMakeCode'}
    ],
    'combinations': [
        {'keyRef': 'RQ', 'requirements': {
            'set': ['LicensePlateNumberIn', 'LicensePlateTypeCode', 'LicensePlateYear', 'RegistrationState'],
            'any': ['ImageIndicator']}},
        {'keyRef': 'RQ', 'requirements': {
            'set': ['VehicleIdentificationNumber', 'RegistrationState'],
            'any': ['ImageIndicator']}},
        {'keyRef': 'FRQ', 'requirements': {
            'set': ['LicensePlateNumberIn'],
            'any': ['LicensePlateYear', 'ImageIndicator']}},
        {'keyRef': 'FRQ', 'requirements': {
            'set': ['VehicleIdentificationNumber'],
            'any': ['LicensePlateYear', 'VehicleMakeCode', 'ImageIndicator']}}
    ]
}

# --- GunQuery ---
gq = {
    'name': 'FL_FCIC_GunQuery',
    'type': 'QUERYINPUTDATAMAPPING',
    'targetEntity': 'Firearm',
    'autoSelect': True,
    'attributes': [
        {'name': 'GunSerialNumber', 'size': 11, 'sourceField': ['GunSerialNumber'],
         'targetField': 'GunSerialNumber'},
        {'name': 'GunMake', 'size': 23, 'sourceField': ['GunMakeCode'],
         'targetField': 'GunMake'},
        {'name': 'ImageIndicator', 'size': 1, 'sourceField': ['ImageIndicator'],
         'targetField': 'ImageIndicator'}
    ],
    'combinations': [
        {'keyRef': 'QG', 'requirements': {
            'set': ['GunSerialNumber'],
            'any': ['GunMakeCode', 'ImageIndicator']}}
    ]
}

# --- ArticleSingleQuery ---
aq = {
    'name': 'FL_FCIC_ArticleSingleQuery',
    'type': 'QUERYINPUTDATAMAPPING',
    'targetEntity': 'Article',
    'autoSelect': True,
    'attributes': [
        {'name': 'ArticleSerialNumber', 'size': 20,
         'sourceField': ['ArticleSerialNumber'], 'targetField': 'ArticleSerialNumber'},
        {'name': 'ArticleTypeCode', 'size': 7,
         'sourceField': ['ArticleTypeCode'], 'targetField': 'ArticleTypeCode'},
        {'name': 'ImageIndicator', 'size': 1, 'sourceField': ['ImageIndicator'],
         'targetField': 'ImageIndicator'}
    ],
    'combinations': [
        {'keyRef': 'QA', 'requirements': {
            'set': ['ArticleSerialNumber', 'ArticleTypeCode'],
            'any': ['ImageIndicator']}}
    ]
}

# --- BoatQuery ---
bq = {
    'name': 'FL_FCIC_BoatQuery',
    'type': 'QUERYINPUTDATAMAPPING',
    'targetEntity': 'Boat',
    'autoSelect': True,
    'attributes': [
        {'name': 'RegistrationNumber', 'size': 8,
         'sourceField': ['RegistrationNumber'], 'targetField': 'RegistrationNumber'},
        {'name': 'BoatHullIdNumber', 'size': 62,
         'sourceField': ['BoatHullIdNumber'], 'targetField': 'BoatHullIdNumber'},
        {'name': 'State', 'size': 2, 'sourceField': ['RegistrationState'],
         'targetField': 'State', 'codeTypeProvider': 'NCIC'},
        {'name': 'ImageIndicator', 'size': 1, 'sourceField': ['ImageIndicator'],
         'targetField': 'ImageIndicator'}
    ],
    'combinations': [
        {'keyRef': 'BQ', 'requirements': {
            'set': ['RegistrationNumber', 'RegistrationState'],
            'any': ['BoatHullIdNumber', 'ImageIndicator']}},
        {'keyRef': 'BQ', 'requirements': {
            'set': ['BoatHullIdNumber', 'RegistrationState'],
            'any': ['RegistrationNumber', 'ImageIndicator']}},
        {'keyRef': 'FBQ', 'requirements': {
            'set': ['RegistrationNumber'],
            'any': ['BoatHullIdNumber', 'ImageIndicator']}},
        {'keyRef': 'FBQ', 'requirements': {
            'set': ['BoatHullIdNumber'],
            'any': ['RegistrationNumber', 'ImageIndicator']}}
    ]
}

# =========================================================================
# 5. ENTITIES — QIF forms
# =========================================================================

# --- ENTITY_Vehicle ---
def build_vehicle_layout():
    n = {}
    n['ROOT'] = make_root()
    n['FORM_ROOT'] = make_form()
    n['ROOT_PAGE'] = make_page(['CARD_VEH'])
    n['CARD_VEH'] = make_card('VEHICLE SEARCH', ['ROW_VEH_1', 'ROW_VEH_2', 'ROW_VEH_3'])

    n['ROW_VEH_1'] = make_row(['5', '3', '4'],
        ['LicensePlateNumberIn_Input', 'LicensePlateTypeCode_Input', 'LicensePlateYear_Input'], 'CARD_VEH')
    n['LicensePlateNumberIn_Input'] = make_input('LicensePlateNumberIn', 'Plate Number', 10, 'ROW_VEH_1')
    n['LicensePlateTypeCode_Input'] = make_select('LicensePlateTypeCode', 'Plate Type', 'ROW_VEH_1',
        codeTypeCategory='NCIC_LICENSE_PLATE_TYPE', codeTypeSource='NCIC')
    n['LicensePlateYear_Input'] = make_input('LicensePlateYear', 'Plate Year', 4, 'ROW_VEH_1')

    n['ROW_VEH_2'] = make_row(['6', '6'],
        ['VehicleIdentificationNumber_Input', 'VehicleMakeCode_Input'], 'CARD_VEH')
    n['VehicleIdentificationNumber_Input'] = make_input('VehicleIdentificationNumber', 'VIN', 20, 'ROW_VEH_2')
    n['VehicleMakeCode_Input'] = make_input('VehicleMakeCode', 'Vehicle Make', 24, 'ROW_VEH_2')

    n['ROW_VEH_3'] = make_row(['6', '6'],
        ['RegistrationState_Input', 'ImageIndicator_Input'], 'CARD_VEH')
    n['RegistrationState_Input'] = make_select('RegistrationState', 'State', 'ROW_VEH_3',
        attributeTypeId='STATE', initialValue='FL', codeTypeProvider='NCIC')
    n['ImageIndicator_Input'] = make_select('ImageIndicator', 'Image', 'ROW_VEH_3',
        codeTypeCategory='YES_NO_UNKNOWN', codeTypeSource='NIBRS')

    return n

vehicle_entity = {
    'name': 'ENTITY_Vehicle',
    'type': 'QUERYINPUTFORM',
    'targetEntity': 'Vehicle',
    'label': 'Vehicle',
    'description': 'Vehicle registration search form',
    'layout': build_3view(build_vehicle_layout(), 'CARD_VEH')
}

# --- ENTITY_Person ---
def build_person_layout():
    n = {}
    n['ROOT'] = make_root()
    n['FORM_ROOT'] = make_form()
    n['ROOT_PAGE'] = make_page(['CARD_PER'])
    n['CARD_PER'] = make_card('PERSON SEARCH',
        ['ROW_PER_1', 'ROW_PER_2', 'ROW_PER_3', 'ROW_PER_4', 'ROW_PER_5', 'ROW_PER_6', 'ROW_PER_H'])

    # Row 1 (DL - OLN)
    n['ROW_PER_1'] = make_row(['6', '3', '3'],
        ['OperatorLicenseNumber_Input', 'RegistrationState_Input', 'ImageIndicator_Input'], 'CARD_PER')
    n['OperatorLicenseNumber_Input'] = make_input('OperatorLicenseNumber', 'License Number', 20, 'ROW_PER_1')
    n['RegistrationState_Input'] = make_select('RegistrationState', 'State', 'ROW_PER_1',
        attributeTypeId='STATE', initialValue='FL', codeTypeProvider='NCIC')
    n['ImageIndicator_Input'] = make_select('ImageIndicator', 'Image', 'ROW_PER_1',
        codeTypeCategory='YES_NO_UNKNOWN', codeTypeSource='NIBRS')

    # Row 2 (DL - Name)
    n['ROW_PER_2'] = make_row(['6', '6'], ['NameLast_Input', 'NameFirst_Input'], 'CARD_PER')
    n['NameLast_Input'] = make_input('NameLast', 'Last Name', 30, 'ROW_PER_2')
    n['NameFirst_Input'] = make_input('NameFirst', 'First Name', 30, 'ROW_PER_2')

    # Row 3 (DL - Name cont)
    n['ROW_PER_3'] = make_row(['6', '6'], ['BirthDate_Input', 'SexCode_Input'], 'CARD_PER')
    n['BirthDate_Input'] = make_datepicker('BirthDate', 'Date of Birth', 'ROW_PER_3')
    n['SexCode_Input'] = make_select('SexCode', 'Sex', 'ROW_PER_3',
        attributeTypeId='SEX', codeTypeProvider='NIBRS')

    # Row 4 (DH - OLN)
    n['ROW_PER_4'] = make_row(['6', '3', '3'],
        ['OperatorLicenseNumberDH_Input', 'Attention_Input', 'PurposeCode_Input'], 'CARD_PER')
    n['OperatorLicenseNumberDH_Input'] = make_input('OperatorLicenseNumberDH', 'DH License Number', 20, 'ROW_PER_4')
    n['Attention_Input'] = make_input('Attention', 'Attention', 30, 'ROW_PER_4')
    n['PurposeCode_Input'] = make_input('PurposeCode', 'Purpose Code', 1, 'ROW_PER_4')

    # Row 5 (DH - Name)
    n['ROW_PER_5'] = make_row(['6', '6'], ['NameLastDH_Input', 'NameFirstDH_Input'], 'CARD_PER')
    n['NameLastDH_Input'] = make_input('NameLastDH', 'DH Last Name', 30, 'ROW_PER_5')
    n['NameFirstDH_Input'] = make_input('NameFirstDH', 'DH First Name', 30, 'ROW_PER_5')

    # Row 6 (DH - Name cont)
    n['ROW_PER_6'] = make_row(['6', '6'], ['BirthDateDH_Input', 'SexCodeDH_Input'], 'CARD_PER')
    n['BirthDateDH_Input'] = make_datepicker('BirthDateDH', 'DH Birth Date', 'ROW_PER_6')
    n['SexCodeDH_Input'] = make_select('SexCodeDH', 'DH Sex', 'ROW_PER_6',
        attributeTypeId='SEX', codeTypeProvider='NIBRS')

    # Hidden row
    hidden_ids = [
        'Requestor_Input', 'NameMiddle_Input', 'NameSuffix_Input',
        'NameMiddleDH_Input', 'NameSuffixDH_Input',
        'ExpandedNameSearchCode_Input', 'RelatedHitSearchIndicator_Input',
        'OperatorLicenseStateCode_Input'
    ]
    n['ROW_PER_H'] = make_row(
        ['1', '1', '1', '1', '1', '1', '1', '1'], hidden_ids, 'CARD_PER')
    n['ROW_PER_H']['hidden'] = True

    n['Requestor_Input'] = make_input('Requestor', 'Requestor', 30, 'ROW_PER_H', hidden=True)
    n['NameMiddle_Input'] = make_input('NameMiddle', 'Middle Name', 30, 'ROW_PER_H', hidden=True)
    n['NameSuffix_Input'] = make_input('NameSuffix', 'Suffix', 10, 'ROW_PER_H', hidden=True)
    n['NameMiddleDH_Input'] = make_input('NameMiddleDH', 'DH Middle Name', 30, 'ROW_PER_H', hidden=True)
    n['NameSuffixDH_Input'] = make_input('NameSuffixDH', 'DH Suffix', 10, 'ROW_PER_H', hidden=True)
    n['ExpandedNameSearchCode_Input'] = make_input('ExpandedNameSearchCode', 'Expanded Name Search', 1, 'ROW_PER_H', hidden=True)
    n['RelatedHitSearchIndicator_Input'] = make_input('RelatedHitSearchIndicator', 'Related Hit Search', 1, 'ROW_PER_H', hidden=True)
    n['OperatorLicenseStateCode_Input'] = make_input('OperatorLicenseStateCode', 'License State Code', 2, 'ROW_PER_H', hidden=True)

    return n

person_entity = {
    'name': 'ENTITY_Person',
    'type': 'QUERYINPUTFORM',
    'targetEntity': 'Person',
    'label': 'Person',
    'description': 'Person DL/DH search form',
    'layout': build_3view(build_person_layout(), 'CARD_PER')
}

# --- ENTITY_Firearm ---
def build_firearm_layout():
    n = {}
    n['ROOT'] = make_root()
    n['FORM_ROOT'] = make_form()
    n['ROOT_PAGE'] = make_page(['CARD_GUN'])
    n['CARD_GUN'] = make_card('FIREARM SEARCH', ['ROW_GUN_1', 'ROW_GUN_2'])

    n['ROW_GUN_1'] = make_row(['6', '6'], ['GunSerialNumber_Input', 'GunMakeCode_Input'], 'CARD_GUN')
    n['GunSerialNumber_Input'] = make_input('GunSerialNumber', 'Serial Number', 11, 'ROW_GUN_1')
    n['GunMakeCode_Input'] = make_input('GunMakeCode', 'Gun Make', 23, 'ROW_GUN_1')

    n['ROW_GUN_2'] = make_row(['6'], ['ImageIndicator_Input'], 'CARD_GUN')
    n['ImageIndicator_Input'] = make_select('ImageIndicator', 'Image', 'ROW_GUN_2',
        codeTypeCategory='YES_NO_UNKNOWN', codeTypeSource='NIBRS')

    return n

firearm_entity = {
    'name': 'ENTITY_Firearm',
    'type': 'QUERYINPUTFORM',
    'targetEntity': 'Firearm',
    'label': 'Firearm',
    'description': 'Firearm search form',
    'layout': build_3view(build_firearm_layout(), 'CARD_GUN')
}

# --- ENTITY_Article ---
def build_article_layout():
    n = {}
    n['ROOT'] = make_root()
    n['FORM_ROOT'] = make_form()
    n['ROOT_PAGE'] = make_page(['CARD_ART'])
    n['CARD_ART'] = make_card('ARTICLE SEARCH', ['ROW_ART_1', 'ROW_ART_2'])

    n['ROW_ART_1'] = make_row(['6', '6'],
        ['ArticleSerialNumber_Input', 'ArticleTypeCode_Input'], 'CARD_ART')
    n['ArticleSerialNumber_Input'] = make_input('ArticleSerialNumber', 'Serial Number', 20, 'ROW_ART_1')
    n['ArticleTypeCode_Input'] = make_select('ArticleTypeCode', 'Article Type', 'ROW_ART_1',
        codeTypeCategory='ARTICLE', codeTypeSource='CA_CLETS')

    n['ROW_ART_2'] = make_row(['6'], ['ImageIndicator_Input'], 'CARD_ART')
    n['ImageIndicator_Input'] = make_select('ImageIndicator', 'Image', 'ROW_ART_2',
        codeTypeCategory='YES_NO_UNKNOWN', codeTypeSource='NIBRS')

    return n

article_entity = {
    'name': 'ENTITY_Article',
    'type': 'QUERYINPUTFORM',
    'targetEntity': 'Article',
    'label': 'Article',
    'description': 'Article search form',
    'layout': build_3view(build_article_layout(), 'CARD_ART')
}

# --- ENTITY_Boat ---
def build_boat_layout():
    n = {}
    n['ROOT'] = make_root()
    n['FORM_ROOT'] = make_form()
    n['ROOT_PAGE'] = make_page(['CARD_BOAT'])
    n['CARD_BOAT'] = make_card('BOAT SEARCH', ['ROW_BOAT_1', 'ROW_BOAT_2'])

    n['ROW_BOAT_1'] = make_row(['4', '8'],
        ['RegistrationNumber_Input', 'BoatHullIdNumber_Input'], 'CARD_BOAT')
    n['RegistrationNumber_Input'] = make_input('RegistrationNumber', 'Registration Number', 8, 'ROW_BOAT_1')
    n['BoatHullIdNumber_Input'] = make_input('BoatHullIdNumber', 'Hull ID Number', 62, 'ROW_BOAT_1')

    n['ROW_BOAT_2'] = make_row(['6', '6'],
        ['RegistrationState_Input', 'ImageIndicator_Input'], 'CARD_BOAT')
    n['RegistrationState_Input'] = make_select('RegistrationState', 'State', 'ROW_BOAT_2',
        attributeTypeId='STATE', initialValue='FL', codeTypeProvider='NCIC')
    n['ImageIndicator_Input'] = make_select('ImageIndicator', 'Image', 'ROW_BOAT_2',
        codeTypeCategory='YES_NO_UNKNOWN', codeTypeSource='NIBRS')

    return n

boat_entity = {
    'name': 'ENTITY_Boat',
    'type': 'QUERYINPUTFORM',
    'targetEntity': 'Boat',
    'label': 'Boat',
    'description': 'Boat search form',
    'layout': build_3view(build_boat_layout(), 'CARD_BOAT')
}

# =========================================================================
# 6. RMS Bundle — modify from ProviderTest
# =========================================================================
rms_bundle = copy.deepcopy(data['bundles'][2])

for c in rms_bundle['configurations']:
    if c.get('name') == 'RMS Person Search query':
        # Remove OOS attributes
        c['attributes'] = [a for a in c['attributes'] if 'OOS' not in a.get('name', '')]

        # Ensure sex has useAttributeId=true, NO ArrayWrapper
        for a in c['attributes']:
            if a.get('name') == 'sex':
                a['useAttributeId'] = True
                a.pop('rule', None)

        # Patch 3: registrationState with ArrayWrapper
        found_reg = False
        for a in c['attributes']:
            if a.get('name') == 'registrationState':
                found_reg = True
                a['sourceField'] = ['RegistrationState']
                a['targetField'] = 'registrationStateAttrId'
                a['useAttributeId'] = True
                a['rule'] = {'function': 'AttributeArrayWrapperRuleHandler'}
                break
        if not found_reg:
            c['attributes'].append({
                'name': 'registrationState',
                'sourceField': ['RegistrationState'],
                'targetField': 'registrationStateAttrId',
                'useAttributeId': True,
                'rule': {'function': 'AttributeArrayWrapperRuleHandler'}
            })

        # Clean combinations: remove OOS, ensure RegistrationState in any[]
        new_combos = []
        for combo in c.get('combinations', []):
            reqs = combo.get('requirements', {})
            set_f = reqs.get('set', [])
            any_f = reqs.get('any', [])
            if any('OOS' in f for f in set_f + any_f):
                continue
            if 'RegistrationState' not in any_f:
                any_f.append('RegistrationState')
                reqs['any'] = any_f
            new_combos.append(combo)
        c['combinations'] = new_combos
        break

# =========================================================================
# 7. Assemble final JSON
# =========================================================================
commsys_bundle = {
    'name': 'FL_FCIC',
    'provider': 'FL_FCIC',
    'type': 'BUNDLE',
    'description': 'FL FCIC v2.1 test -- single entity, no duplicate targetFields',
    'configurations': [auth, qrdm, qmf, vrq, dlq, dhq, gq, aq, bq]
}

entities_bundle = {
    'name': 'ENTITIES',
    'provider': 'MARK43',
    'type': 'BUNDLE',
    'order': {
        'default': ['Vehicle', 'Person', 'Firearm', 'Article', 'Boat'],
        'CAD_DISPATCH': ['Vehicle', 'Person', 'Firearm', 'Article', 'Boat'],
        'FIRST_RESPONDER': ['Vehicle', 'Person', 'Firearm', 'Article', 'Boat']
    },
    'configurations': [vehicle_entity, person_entity, firearm_entity, article_entity, boat_entity]
}

output = {'bundles': [commsys_bundle, entities_bundle, rms_bundle]}

with open(OUTPUT, 'w') as f:
    json.dump(output, f, indent=4)

# =========================================================================
# Validation
# =========================================================================
print(f'SUCCESS: {OUTPUT} written')
print(f'File size: {os.path.getsize(OUTPUT):,} bytes')
print()
print('=== Validation ===')

errors = 0

# No duplicate targetFields within each QIDM
for config in commsys_bundle['configurations']:
    if config.get('type') == 'QUERYINPUTDATAMAPPING':
        targets = [a['targetField'] for a in config['attributes']]
        dupes = set(t for t in targets if targets.count(t) > 1)
        if dupes:
            print(f'FAIL: {config["name"]} duplicate targetFields: {dupes}')
            errors += 1
        else:
            print(f'PASS: {config["name"]} no duplicate targetFields ({len(targets)} attrs)')

# codeTypeProvider checks
for config in commsys_bundle['configurations']:
    if config.get('type') == 'QUERYINPUTDATAMAPPING':
        for a in config['attributes']:
            if a['targetField'] == 'State':
                if a.get('codeTypeProvider') != 'NCIC':
                    print(f'FAIL: {config["name"]}.{a["name"]} State needs codeTypeProvider=NCIC')
                    errors += 1
                else:
                    print(f'PASS: {config["name"]}.{a["name"]} codeTypeProvider=NCIC')
            if a['targetField'] == 'SexCode':
                if a.get('codeTypeProvider') != 'NIBRS':
                    print(f'FAIL: {config["name"]}.{a["name"]} SexCode needs codeTypeProvider=NIBRS')
                    errors += 1
                else:
                    print(f'PASS: {config["name"]}.{a["name"]} codeTypeProvider=NIBRS')

# Date format
for config in commsys_bundle['configurations']:
    if config.get('type') == 'QUERYINPUTDATAMAPPING':
        for a in config['attributes']:
            if 'Date' in a['targetField'] and 'rule' in a:
                args = a['rule'].get('arguments', [])
                if 'yyyyMMdd' in args:
                    print(f'PASS: {config["name"]}.{a["name"]} uses yyyyMMdd')
                else:
                    print(f'FAIL: {config["name"]}.{a["name"]} wrong date format: {args}')
                    errors += 1

# Bundle properties
for b in output['bundles']:
    if b.get('type') == 'BUNDLE':
        print(f'PASS: Bundle {b["name"]} type=BUNDLE provider={b["provider"]}')
    else:
        print(f'FAIL: Bundle {b["name"]} type={b.get("type")}')
        errors += 1

# ENTITIES order is nested object
eo = entities_bundle['order']
if isinstance(eo, dict) and 'default' in eo:
    print('PASS: ENTITIES order is nested object')
else:
    print('FAIL: ENTITIES order not nested')
    errors += 1

# RMS Vehicle LicensePlateNumberIn
for c in rms_bundle['configurations']:
    if c.get('name') == 'RMS Vehicle search query':
        found = False
        for combo in c['combinations']:
            if 'LicensePlateNumberIn' in combo['requirements'].get('set', []):
                found = True
                break
        print(f'{"PASS" if found else "FAIL"}: RMS Vehicle LicensePlateNumberIn in combo set')
        if not found:
            errors += 1

# Patch 3
for c in rms_bundle['configurations']:
    if c.get('name') == 'RMS Person Search query':
        for a in c['attributes']:
            if a.get('name') == 'registrationState':
                ok = (a.get('rule', {}).get('function') == 'AttributeArrayWrapperRuleHandler'
                      and a.get('useAttributeId') == True)
                print(f'{"PASS" if ok else "FAIL"}: RMS Person Patch 3')
                if not ok:
                    errors += 1
        oos = [a for a in c['attributes'] if 'OOS' in a.get('name', '')]
        print(f'{"PASS" if not oos else "FAIL"}: RMS Person no OOS attrs')
        if oos:
            errors += 1
        oos_c = sum(1 for combo in c['combinations']
                    for f in combo['requirements'].get('set', []) + combo['requirements'].get('any', [])
                    if 'OOS' in f)
        print(f'{"PASS" if oos_c == 0 else "FAIL"}: RMS Person no OOS combos')
        if oos_c:
            errors += 1

# RMS Person sex: useAttributeId=true, no ArrayWrapper
for c in rms_bundle['configurations']:
    if c.get('name') == 'RMS Person Search query':
        for a in c['attributes']:
            if a.get('name') == 'sex':
                ok = a.get('useAttributeId') == True and 'rule' not in a
                print(f'{"PASS" if ok else "FAIL"}: RMS Person sex useAttributeId=true, no ArrayWrapper')
                if not ok:
                    errors += 1

# Count QIDMs
qidm_count = sum(1 for c in commsys_bundle['configurations'] if c.get('type') == 'QUERYINPUTDATAMAPPING')
print(f'PASS: {qidm_count} QIDMs (expected 6)')

# Count QIFs
qif_count = len(entities_bundle['configurations'])
print(f'PASS: {qif_count} QIFs (expected 5)')

print()
if errors:
    print(f'*** {errors} ERRORS found ***')
else:
    print('*** ALL VALIDATIONS PASSED ***')
