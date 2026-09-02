// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
    "provider":  "CA_eSUN",
    "version":  "1.1",
    "note":  "Paste as scope; render each entity form; __usxScopePicklists(scope, \u0027\u003cEntity\u003e\u0027). One download per entity.",
    "fields":  [
                   {
                       "entity":  "Article",
                       "fieldId":  "ArticleTypeCode",
                       "label":  "Article Type",
                       "codeTypeCategory":  "NCIC_ARTICLE_TYPE",
                       "codeTypeSource":  "CA_CLETS",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "LicensePlateTypeCode",
                       "label":  "Plate Type",
                       "codeTypeCategory":  "NCIC_LICENSE_PLATE_TYPE",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "RegistrationState",
                       "label":  "State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "VehicleMakeCode",
                       "label":  "Vehicle Make Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "VEHICLE_MAKE"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "SexCode",
                       "label":  "Sex",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "SEX"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "RegistrationState",
                       "label":  "License State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "FirearmCaliber",
                       "label":  "Firearm Caliber",
                       "codeTypeCategory":  "NCIC_FIREARM_CALIBER",
                       "codeTypeSource":  "NJ_NIBRS",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "FirearmMake",
                       "label":  "Firearm Make",
                       "codeTypeCategory":  "NCIC_FIREARM_MAKE",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "FirearmType",
                       "label":  "Firearm Type",
                       "codeTypeCategory":  "NCIC_FIREARM_TYPE",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "RegistrationState",
                       "label":  "State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   }
               ]
};
console.log('%c[USx-SCOPE] scope loaded: CA_eSUN v1.1 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
