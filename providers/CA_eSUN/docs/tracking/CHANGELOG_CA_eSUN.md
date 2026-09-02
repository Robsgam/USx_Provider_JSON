# CA_eSUN -- Changelog

Auto-generated from `CA_eSUN_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v1.0** | Generated: 2026-09-02

---

## v1.0 -- 2026-09-02 -- HAND BUILT BY ENGINEERING -- captured from the San Diego Sheriff live tenant

ORIGIN: not built by this repo's process. This is the configuration engineering hand-built and  
  that San Diego Sheriff actually runs, exported from the tenant on 2026-09-02 12:55.  
VERBATIM BASELINE ARCHIVE: source/CA_eSUN_v1.0_SDSO_BASELINE_2026-09-02.json  
  SHA-verified byte-identical to the download. That file is the archive point and is never edited.  
THE WORKING v1.0 DIFFERS FROM THE ARCHIVE IN EXACTLY TWO WAYS, both mechanical, both required:  
  1. UNWRAPPED. The download is a DEPARTMENT EXPORT: {departmentBundle:{bundles,behaviors},  
     m43Forms}. Our validator rejects that outright -- "[FAIL] Missing top-level 'bundles' array"  
     -- so it can be neither validated nor imported as-is. Taking departmentBundle as the root  
     yields {bundles, behaviors}, which is EXACTLY the root shape of the previous SDSO export, so  
     the unwrap is lossless. m43Forms was null; nothing was discarded. Fidelity re-verified after  
     every write: 2 bundles / 16 configurations / 8 QIDMs / 25 combinations / behaviors present.  
  2. VERSION STAMPED INTO THE BUNDLE DESCRIPTION. Was "Provider configuration for CA eSUN" --  
     carrying no version at all. CLAUDE.md's Versioning Policy requires the version to live in  
     the filename AND the bundle description (enforce CHECK 3i reads it), and without it  
     reset_test_package failed outright with "[ERROR] Could not determine version for CA_eSUN".  
     That tool derives the version from the build script or a versioned description, and a  
     hand-built JSON has neither.  
