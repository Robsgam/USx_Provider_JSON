// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
  "provider": "NJ_NJCJIS",
  "version": "4.8",
  "note": "Paste as scope; render each entity form; __usxScopePicklists(scope, '<Entity>'). One download per entity.",
  "fields": [
    {
      "entity": "Vehicle",
      "fieldId": "RegistrationState",
      "label": "State (default NJ - change for out-of-state)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Vehicle",
      "fieldId": "RandomRequest",
      "label": "Random Request (N = full record; Y = random)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
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
      "label": "Plate Type (optional)",
      "codeTypeCategory": "NCIC_LICENSE_PLATE_TYPE",
      "codeTypeSource": "NCIC"
    },
    {
      "entity": "Person",
      "fieldId": "RegistrationState",
      "label": "State (default NJ - change for out-of-state)",
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
      "label": "Sex (optional)",
      "codeTypeCategory": "",
      "codeTypeSource": ""
    },
    {
      "entity": "Firearm",
      "fieldId": "GunMake",
      "label": "Make (optional)",
      "codeTypeCategory": "NCIC_FIREARM_MAKE",
      "codeTypeSource": "NJ_NIBRS"
    },
    {
      "entity": "Firearm",
      "fieldId": "GunCaliber",
      "label": "Caliber (optional)",
      "codeTypeCategory": "NCIC_FIREARM_CALIBER",
      "codeTypeSource": "NJ_NIBRS"
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
      "fieldId": "ImageIndicator",
      "label": "Image (optional)",
      "codeTypeCategory": "YES_NO_UNKNOWN",
      "codeTypeSource": "NCIC"
    }
  ]
};
console.log('%c[USx-SCOPE] scope loaded: NJ_NJCJIS v4.8 --', 'color:#0aa;font-weight:bold', scope.fields.length, 'select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')');
