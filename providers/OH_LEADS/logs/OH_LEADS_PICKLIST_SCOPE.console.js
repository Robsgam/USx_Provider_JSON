// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
    "provider":  "OH_LEADS",
    "version":  "2.3",
    "note":  "Paste as scope; render each entity form; __usxScopePicklists(scope, \u0027\u003cEntity\u003e\u0027). One download per entity.",
    "fields":  [
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "RegistrationState",
                       "label":  "State (leave blank for OH)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "LicensePlateTypeCode",
                       "label":  "Plate Type",
                       "codeTypeCategory":  "NCIC_LICENSE_PLATE_TYPE",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "VehicleMakeCode",
                       "label":  "Vehicle Make (with State, optional)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "RegistrationState",
                       "label":  "State (leave blank for OH)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "ImageIndicator",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "SexCode",
                       "label":  "Sex (out-of-state)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "SexCodeDH",
                       "label":  "Sex",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "firearmMake",
                       "label":  "Make",
                       "codeTypeCategory":  "NCIC_FIREARM_MAKE",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "gunCaliber",
                       "label":  "Caliber",
                       "codeTypeCategory":  "NCIC_FIREARM_CALIBER",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "relatedHitSearchIndicator",
                       "label":  "Stolen Check",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "articleTypeCode",
                       "label":  "Article Type",
                       "codeTypeCategory":  "NCIC_ARTICLE_TYPE",
                       "codeTypeSource":  "CA_CLETS"
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "ImageIndicator",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "relatedHitSearchIndicator",
                       "label":  "Stolen Check",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "RegistrationState",
                       "label":  "State (leave blank for OH)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "ImageIndicator",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "relatedHitSearchIndicator",
                       "label":  "Stolen Check",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC"
                   }
               ]
};
console.log('%c[USx-SCOPE] scope loaded: OH_LEADS v2.3 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
