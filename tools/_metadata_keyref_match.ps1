<#
  _metadata_keyref_match.ps1 -- shared XML-keyRef-to-JSON-built-combo matcher.

  Extracted 2026-07-06 to fix a real divergence: `audit_metadata.ps1` CHECK 4's
  "invented-variant fallback" and `extract_metadata_reference.ps1`'s BUILD COVERAGE section
  each independently decided whether an XML metadata keyRef was "built" in the JSON, using
  different heuristics that could (and did) disagree about the same fact -- confirmed live on
  FL_FCIC's QV/QW (audit_metadata said [PASS] covered; extract_metadata_reference said UNBUILT).
  This module is now the single source of truth both tools call.

  MECHANICAL DEFAULT (verbatim from extract_metadata_reference.ps1's pre-2026-07-06 BUILD
  COVERAGE logic): an XML combo (keyRef=K, primaryField=P) is built if some JSON built keyRef
  equals K exactly, equals K with a trailing ".SUFFIX" stripped (dotted-variant base, e.g. CA's
  "IA.QB.H" -> "IA.QB"), equals the synthetic "K+P" (e.g. HI's "QG"+"GunSerialNumber" ->
  "QGGunSerialNumber"), or starts with "K+P".

  This default is INSUFFICIENT on its own -- NJ_NJCJIS proves it. NJ builds
  VehicleRegistrationQuery as a single combo named "RANDFULL"/"RANDFULLN", a compound
  concatenation of the XML's two separate keyRefs "RAND" and "FULL" (the devdoc defines 4 combos
  under keyReference RAND and FULL, each identical Set/Any per identifier -- NJ merged them into
  one physical combo per identifier). Neither "RAND"+field nor "FULL" is a prefix of
  "RANDFULL"/"RANDFULLN" (FULL is embedded mid-string), so the mechanical rule cannot derive
  this and would falsely report a fully-built query as not-built.

  DECLARATION LAYER (checked FIRST, mechanical rule is the fallback): a provider's
  <PROVIDER>_ACCEPTED_DIVERGENCES.txt may carry two new keyRef-level rule rows (existing
  field-level rules like "promoted-to-set" are untouched and ignored here):
    query | keyRef | JsonKeyRef1,JsonKeyRef2,... | built-as | reason | source | date
    query | keyRef | *                          | not-built | reason | source | date
  "built-as" declares which specific JSON keyRef(s) satisfy this XML keyRef (NJ's case: both
  "RAND" and "FULL" declared built-as "RANDFULL,RANDFULLN"). "not-built" declares an XML keyRef
  as an intentional non-build (e.g. FL's QV/QW -- CommSys auto-sends these) so callers report it
  honestly instead of guessing via field-overlap heuristics.

  Usage (dot-source):
    . "$PSScriptRoot\_metadata_keyref_match.ps1"
    $decls = Get-KeyRefDeclarations -JsonDir $jsonDir -ProviderName $providerName
    $result = Resolve-XmlKeyRefBuild -XmlKeyRef $kr -XmlPrimaryField $primaryField `
                -Query $qName -BuiltKeyRefs $jsonKeyRefsForThisQuery -Declarations $decls
    # $result.Status  = 'built' | 'not-built'
    # $result.Matches = @(...)   -- the JSON keyRef(s) that satisfy it (built only)
    # $result.Source  = 'declaration' | 'mechanical'
#>

function Get-KeyRefDeclarations {
    param(
        [Parameter(Mandatory=$true)][string]$JsonDir,
        [Parameter(Mandatory=$true)][string]$ProviderName
    )

    $decls = @{}   # "query|keyref" (lowercased) -> @{ Rule='built-as'|'not-built'; Targets=@(...) }

    # docs/ reorg (2026-07-01): ACCEPTED_DIVERGENCES is a "tracking" category doc for migrated
    # providers (docs/tracking/), flat docs/ for the rest. Check tracking/ first, then fall back
    # -- matches the existing lookup convention in audit_metadata.ps1.
    $divFile = Join-Path $JsonDir ("docs\tracking\{0}_ACCEPTED_DIVERGENCES.txt" -f $ProviderName)
    if (-not (Test-Path $divFile)) {
        $divFile = Join-Path $JsonDir ("docs\{0}_ACCEPTED_DIVERGENCES.txt" -f $ProviderName)
    }
    if (-not (Test-Path $divFile)) { return $decls }

    foreach ($ln in (Get-Content $divFile)) {
        $s = $ln.Trim()
        if (-not $s -or $s.StartsWith('#')) { continue }
        $parts = $s -split '\|'
        if ($parts.Count -lt 4) { continue }

        $query  = $parts[0].Trim()
        $keyRef = $parts[1].Trim()
        $field  = $parts[2].Trim()
        $rule   = $parts[3].Trim().ToLower()

        # This module only cares about keyRef-level rules. Field-level rules (promoted-to-set,
        # etc.) are a different concern already handled by audit_metadata.ps1's Test-AllowListed
        # -- same file, different rule names, no collision.
        if ($rule -ne 'built-as' -and $rule -ne 'not-built') { continue }

        $key = ('{0}|{1}' -f $query, $keyRef).ToLower()
        $targets = if ($rule -eq 'built-as') {
            @($field -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        } else {
            @()
        }
        $decls[$key] = @{ Rule = $rule; Targets = $targets }
    }

    return $decls
}

function Resolve-XmlKeyRefBuild {
    param(
        [Parameter(Mandatory=$true)][string]$XmlKeyRef,
        [string]$XmlPrimaryField = '',
        [Parameter(Mandatory=$true)][string]$Query,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$BuiltKeyRefs,
        [Parameter(Mandatory=$true)][hashtable]$Declarations
    )

    $declKey = ('{0}|{1}' -f $Query, $XmlKeyRef).ToLower()
    if ($Declarations.ContainsKey($declKey)) {
        $decl = $Declarations[$declKey]
        if ($decl.Rule -eq 'not-built') {
            return @{ Status = 'not-built'; Matches = @(); Source = 'declaration' }
        }
        if ($decl.Rule -eq 'built-as') {
            # Only report targets that actually exist among this query's built keyRefs --
            # a stale declaration (target renamed/removed) should not silently claim coverage.
            $confirmed = @($decl.Targets | Where-Object { $BuiltKeyRefs -icontains $_ })
            if ($confirmed.Count -gt 0) {
                return @{ Status = 'built'; Matches = $confirmed; Source = 'declaration' }
            }
            # Declared target(s) no longer exist -- fall through to mechanical as a safety net
            # rather than silently going stale; a future audit pass should flag this drift.
        }
    }

    # Mechanical default -- verbatim rule from extract_metadata_reference.ps1's original
    # BUILD COVERAGE matching (pre-2026-07-06).
    $syntheticKr = "$XmlKeyRef$XmlPrimaryField"
    $matches = @()
    foreach ($bkr in $BuiltKeyRefs) {
        $bBase = $bkr -replace '\.[A-Z0-9]+$', ''
        if ($bBase -eq $XmlKeyRef -or $bkr -eq $XmlKeyRef -or
            $bkr -eq $syntheticKr -or $bkr.StartsWith($syntheticKr)) {
            $matches += $bkr
        }
    }

    if ($matches.Count -gt 0) {
        return @{ Status = 'built'; Matches = @($matches); Source = 'mechanical' }
    }
    return @{ Status = 'not-built'; Matches = @(); Source = 'mechanical' }
}
