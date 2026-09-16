// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
    "provider":  "SC_SLED",
    "version":  "1.5",
    "note":  "Paste as scope; render each entity form; __usxScopePicklists(scope, \u0027\u003cEntity\u003e\u0027). One download per entity.",
    "fields":  [
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
                       "fieldId":  "VehicleMakeCode",
                       "label":  "Vehicle Make",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "VEHICLE_MAKE"
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "RegistrationState",
                       "label":  "State (leave blank for SC)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "RegistrationState",
                       "label":  "State (leave blank for SC)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
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
                       "fieldId":  "ImageIndicator",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "RegistrationStateDR",
                       "label":  "State (leave blank for SC)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "SexCodeDR",
                       "label":  "Sex (optional)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "SEX"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "ImageIndicatorDR",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "ImageIndicator",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "VehicleMakeCode",
                       "label":  "Vehicle Make",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "VEHICLE_MAKE"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "GunMake",
                       "label":  "Make (optional)",
                       "codeTypeCategory":  "NCIC_FIREARM_MAKE",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "GunCaliber",
                       "label":  "Caliber (optional)",
                       "codeTypeCategory":  "NCIC_FIREARM_CALIBER",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "ArticleTypeCode",
                       "label":  "Article Type (required)",
                       "codeTypeCategory":  "NCIC_ARTICLE_TYPE",
                       "codeTypeSource":  "CA_CLETS",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "RegistrationState",
                       "label":  "State (leave blank for SC)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   }
               ]
};
console.log('%c[USx-SCOPE] scope loaded: SC_SLED v1.5 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
