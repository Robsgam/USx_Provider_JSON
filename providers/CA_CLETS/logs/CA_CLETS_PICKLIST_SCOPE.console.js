// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
  "provider": "CA_CLETS",
  "version": "2.12",
  "note": "Paste as scope; render each entity form; __usxScopePicklists(scope, '<Entity>'). One download per entity.",
  "fields": [
    {
      "entity": "Vehicle",
      "fieldId": "RegistrationState",
      "label": "State (leave blank for CA)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Vehicle",
      "fieldId": "LicensePlateTypeCode",
      "label": "Plate Type (out-of-state plates)",
      "codeTypeCategory": "NCIC_LICENSE_PLATE_TYPE",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Vehicle",
      "fieldId": "VehicleMakeCode",
      "label": "Vehicle Make (optional)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Person",
      "fieldId": "RegistrationState",
      "label": "State (leave blank for CA)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Person",
      "fieldId": "SexCode",
      "label": "Sex (required with Name)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Person",
      "fieldId": "raceCode",
      "label": "Race (optional)",
      "codeTypeCategory": "NIBRS_RACE",
      "codeTypeSource": "NIBRS"
    },
    {
      "entity": "Person",
      "fieldId": "appsRequestIndicator",
      "label": "APPS Check - prohibited persons (Name search)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Person",
      "fieldId": "SexCodeDH",
      "label": "Sex (DH) - required with Name",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Firearm",
      "fieldId": "GunMake",
      "label": "Make (optional)",
      "codeTypeCategory": "NCIC_FIREARM_MAKE",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Firearm",
      "fieldId": "gunCaliber",
      "label": "Caliber (optional)",
      "codeTypeCategory": "NCIC_FIREARM_CALIBER",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Firearm",
      "fieldId": "gunTypeCode",
      "label": "Type (optional)",
      "codeTypeCategory": "NCIC_FIREARM_TYPE",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Article",
      "fieldId": "ArticleTypeCode",
      "label": "Article Type (optional)",
      "codeTypeCategory": "NCIC_ARTICLE_TYPE",
      "codeTypeSource": "CA_CLETS"
    },
    {
      "entity": "Boat",
      "fieldId": "RegistrationState",
      "label": "State (leave blank for CA; required with Name)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    }
  ]
};
console.log('%c[USx-SCOPE] scope loaded: CA_CLETS v2.12 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
