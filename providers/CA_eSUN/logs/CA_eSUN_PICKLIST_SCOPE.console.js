// PASTE THIS ENTIRE FILE into the tenant DevTools console (F12 -> Console), press Enter.
// Then render each entity form and run its line (one at a time; each downloads one file):
var scope = {
    "provider":  "CA_eSUN",
    "version":  "3.0",
    "note":  "Paste as scope; render each entity form; __usxScopePicklists(scope, \u0027\u003cEntity\u003e\u0027). One download per entity.",
    "fields":  [
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "DEX_INQUIRY_PURPOSE_CODE"
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
                       "fieldId":  "LicensePlateTypeCode",
                       "label":  "Plate Type",
                       "codeTypeCategory":  "NCIC_LICENSE_PLATE_TYPE",
                       "codeTypeSource":  "NCIC",
                       "attributeTypeId":  ""
                   },
                   {
                       "entity":  "Vehicle",
                       "fieldId":  "VehicleMakeCode",
                       "label":  "Make",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "VEHICLE_MAKE"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "DEX_INQUIRY_PURPOSE_CODE"
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
                       "fieldId":  "SexCode",
                       "label":  "Sex",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "SEX"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "PurposeCodeDH",
                       "label":  "CA Purpose Code (DH)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "DEX_INQUIRY_PURPOSE_CODE"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "RegistrationStateDH",
                       "label":  "State (DH)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "STATE"
                   },
                   {
                       "entity":  "Person",
                       "fieldId":  "SexCodeDH",
                       "label":  "Sex (DH)",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "SEX"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "DEX_INQUIRY_PURPOSE_CODE"
                   },
                   {
                       "entity":  "Firearm",
                       "fieldId":  "GunMake",
                       "label":  "Make",
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
                       "fieldId":  "GunTypeCode",
                       "label":  "Type",
                       "codeTypeCategory":  "NCIC_FIREARM_TYPE",
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
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "DEX_INQUIRY_PURPOSE_CODE"
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
                       "entity":  "Boat",
                       "fieldId":  "PurposeCode",
                       "label":  "CA Purpose Code",
                       "codeTypeCategory":  "",
                       "codeTypeSource":  "",
                       "attributeTypeId":  "DEX_INQUIRY_PURPOSE_CODE"
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
console.log('%c[USx-SCOPE] scope loaded: CA_eSUN v3.0 --', 'color:#0aa;font-weight:bold', scope.fields.length, "select field(s). Now render an entity form and run:\n  __usxScopePicklists(scope, 'Article')\n  __usxScopePicklists(scope, 'Boat')\n  __usxScopePicklists(scope, 'Firearm')\n  __usxScopePicklists(scope, 'Person')\n  __usxScopePicklists(scope, 'Vehicle')");
