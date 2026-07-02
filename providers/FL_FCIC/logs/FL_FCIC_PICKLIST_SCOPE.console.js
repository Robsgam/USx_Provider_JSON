// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
  "provider": "FL_FCIC",
  "version": "7.1",
  "note": "Paste as scope; render each entity form; __usxScopePicklists(scope, '<Entity>'). One download per entity.",
  "fields": [
    {
      "entity": "Person",
      "fieldId": "RegistrationState",
      "label": "State (leave blank for FL)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Person",
      "fieldId": "ImageIndicator",
      "label": "Image (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
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
      "fieldId": "RegistrationStateDH",
      "label": "Destination State (DH, not FL)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Person",
      "fieldId": "SexCodeDH",
      "label": "Sex (DH) - required with Name",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Vehicle",
      "fieldId": "RegistrationState",
      "label": "State (leave blank for FL)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Vehicle",
      "fieldId": "ImageIndicator",
      "label": "Image (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
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
      "entity": "Firearm",
      "fieldId": "GunMake",
      "label": "Gun Make (optional)",
      "codeTypeCategory": "NCIC_FIREARM_MAKE",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Firearm",
      "fieldId": "ImageIndicator",
      "label": "Image (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Article",
      "fieldId": "ArticleTypeCode",
      "label": "Article Type (required)",
      "codeTypeCategory": "NCIC_ARTICLE_TYPE",
      "codeTypeSource": "CA_CLETS"
    },
    {
      "entity": "Article",
      "fieldId": "ImageIndicator",
      "label": "Image (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Boat",
      "fieldId": "RegistrationState",
      "label": "Destination State (blank for FL, required for name/DOB)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Boat",
      "fieldId": "relatedHitSearchIndicator",
      "label": "Stolen Search (Y for NCIC stolen-boat check)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Boat",
      "fieldId": "ImageIndicator",
      "label": "Image (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    }
  ]
};
console.log('%c[USx-SCOPE] scope loaded: FL_FCIC v7.1 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
