// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
    "provider":  "TX_TLETS",
    "version":  "4.23",
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
                       "fieldId":  "RegistrationState",
                       "label":  "State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
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
                       "label":  "State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
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
                       "fieldId":  "SexCodeDH",
                       "label":  "Sex",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "SEX"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "RegistrationStateDH",
                       "label":  "State",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "ImageIndicatorDH",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "GunMake",
                       "label":  "Gun Make",
                       "codeTypeCategory":  "NCIC_FIREARM_MAKE",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "GunCaliber",
                       "label":  "Caliber",
                       "codeTypeCategory":  "NCIC_FIREARM_CALIBER",
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
                       "fieldId":  "relatedHitSearchIndicator",
                       "label":  "Stolen Check",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "ArticleTypeCode",
                       "label":  "Article Type",
                       "codeTypeCategory":  "NCIC_ARTICLE_TYPE",
                       "codeTypeSource":  "CA_CLETS",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "ImageIndicator",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Article",
                       "fieldId":  "relatedHitSearchIndicator",
                       "label":  "Stolen Check",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
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
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "ImageIndicator",
                       "label":  "NCIC Image",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Boat",
                       "fieldId":  "relatedHitSearchIndicator",
                       "label":  "Stolen Check",
                       "codeTypeCategory":  "YES_NO_UNKNOWN",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   }
               ]
};
console.log('%c[USx-SCOPE] scope loaded: TX_TLETS v4.23 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
