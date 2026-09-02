// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
    "provider":  "CA_eSUN",
    "version":  "1.0",
    "note":  "Paste as scope; render each entity form; __usxScopePicklists(scope, \u0027\u003cEntity\u003e\u0027). One download per entity.",
    "fields":  [
                   {
                       "entity":  "Article",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "ArticleTypeCode",
                       "label":  "Article Type",
                       "codeTypeCategory":  "NCIC_ARTICLE_TYPE",
                       "codeTypeSource":  "CA_CLETS"
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
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "RegistrationState",
                       "label":  "State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "VehicleMakeCode",
                       "label":  "Vehicle Make Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "SexCode",
                       "label":  "Sex",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "RegistrationState",
                       "label":  "License State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "FirearmCaliber",
                       "label":  "Firearm Caliber",
                       "codeTypeCategory":  "NCIC_FIREARM_CALIBER",
                       "codeTypeSource":  "NJ_NIBRS"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "FirearmMake",
                       "label":  "Firearm Make",
                       "codeTypeCategory":  "NCIC_FIREARM_MAKE",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "FirearmType",
                       "label":  "Firearm Type",
                       "codeTypeCategory":  "NCIC_FIREARM_TYPE",
                       "codeTypeSource":  "NCIC"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "RegistrationState",
                       "label":  "State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  ""
                   }
               ]
};
console.log('%c[USx-SCOPE] scope loaded: CA_eSUN v1.0 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
