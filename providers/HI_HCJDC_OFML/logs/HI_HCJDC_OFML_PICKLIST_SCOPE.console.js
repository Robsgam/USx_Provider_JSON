// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
  "provider": "HI_HCJDC_OFML",
  "version": "4.7",
  "note": "Paste as scope; render each entity form; __usxScopePicklists(scope, '<Entity>'). One download per entity.",
  "fields": [
    {
      "entity": "Vehicle",
      "fieldId": "vehicleTypeCode",
      "label": "Vehicle Type - Auto (Hawaii queries)",
      "codeTypeCategory": "VEHICLE_TYPE",
      "codeTypeSource": "HI_NIBRS"
    },
    {
      "entity": "Vehicle",
      "fieldId": "RegistrationState",
      "label": "State (leave blank for Hawaii)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Vehicle",
      "fieldId": "ImageIndicator",
      "label": "NCIC Image - include image (Y/N)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Vehicle",
      "fieldId": "LicensePlateTypeCode",
      "label": "Plate Type - out-of-state plates only",
      "codeTypeCategory": "NCIC_LICENSE_PLATE_TYPE",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Person",
      "fieldId": "RegistrationState",
      "label": "State (leave blank for in-state)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Person",
      "fieldId": "SexCode",
      "label": "Sex (optional)",
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
      "entity": "Firearm",
      "fieldId": "GunMake",
      "label": "Make (optional)",
      "codeTypeCategory": "NCIC_FIREARM_MAKE",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Firearm",
      "fieldId": "GunCaliber",
      "label": "Caliber (optional)",
      "codeTypeCategory": "NCIC_FIREARM_CALIBER",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Firearm",
      "fieldId": "relatedSearchHitIndicator",
      "label": "Search Hit (optional)",
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
      "fieldId": "relatedSearchHitIndicator",
      "label": "Search Hit (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Boat",
      "fieldId": "RegistrationState",
      "label": "State (optional)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Boat",
      "fieldId": "relatedSearchHitIndicator",
      "label": "Search Hit (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    }
  ]
};
console.log('%c[USx-SCOPE] scope loaded: HI_HCJDC_OFML v4.7 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
