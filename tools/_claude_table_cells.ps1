# ─────────────────────────────────────────────────────────────────────────────
#  _claude_table_cells.ps1 -- canonical CLAUDE.md Provider Status cell renderers
#                             (dot-sourced; requires _test_status_lib.ps1)
#
#  ONE definition of what each derived cell should read, consumed by BOTH:
#    tools\sync_provider_table.ps1   (writes the cells)
#    tools\enforce.ps1  CHECK 3j     (verifies the cells)
#
#  WHY THIS FILE EXISTS (2026-07-29): sync_provider_table.ps1 carried its own private
#  score format while the CLAUDE.md table used a different one. The formats diverged, the
#  tool's regex silently stopped matching every row, and it reported "no change" for all 20
#  providers while the table rotted. If the writer and the checker each own a format string,
#  they will drift again -- so both now call these functions. Change a format HERE only.
#
#  Exports:
#    Format-ClaudeValidatorCell -Score <Get-ProviderValidatorScore result>
#    Format-ClaudeTenantCell    -State <Get-ProviderTestState result>
#    Format-ClaudeVersionCell   -State <Get-ProviderTestState result>
#    Test-ClaudeScoreCellShape  -Cell <string>   (accepts with OR without the LIM segment)
# ─────────────────────────────────────────────────────────────────────────────

# Accepts BOTH "76P/0F/0W" and "76P/0F/0W/1LIM". The historical bug was a regex that
# demanded the LIM segment; anything reading this cell must tolerate its absence.
$script:CT_ScoreRx = '^\d+P/\d+F/\d+W(?:/\d+LIM)?$'

function Test-ClaudeScoreCellShape {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Cell)
    return ($Cell.Trim() -match $script:CT_ScoreRx)
}

function Format-ClaudeValidatorCell {
    <#
      "76P/0F/0W"  when LIM == 0  (the portfolio-wide steady state -- 0 FAIL/0 WARN/0 LIM)
      "69P/0F/0W/1LIM"             when LIM > 0, so a LIMITATION can never hide.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Score)

    if ($null -eq $Score -or $null -eq $Score.Pass) { return $null }

    $w = if ($null -ne $Score.Warn) { [int]$Score.Warn } else { 0 }
    $l = if ($null -ne $Score.Lim)  { [int]$Score.Lim }  else { 0 }

    $cell = "$([int]$Score.Pass)P/$([int]$Score.Fail)F/${w}W"
    if ($l -gt 0) { $cell += "/${l}LIM" }
    return $cell
}

function Format-ClaudeTenantCell {
    <#
      Mirrors the wording portfolio_status.ps1 prints, in the shape the CLAUDE.md table
      has always used:
        ALL-PASS 5/5 (35 logs)
        PARTIAL (111 logs, 7 owed)     <- owed plan tests are the headline when present
        PARTIAL 3/5 (40 logs)
        HAS-FAIL 5/5 (90 logs, 2 FAIL)
        NEVER 0/5
        NOT-TRACKED
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State)

    if ($null -eq $State) { return $null }

    $total  = 5
    $tested = [int]$State.EntitiesTested
    $logs   = [int]$State.Pass + [int]$State.Fail + [int]$State.Pending + [int]$State.Unknown
    $owed   = if ($null -ne $State.OwedPlanTests) { [int]$State.OwedPlanTests } else { 0 }

    switch ("$($State.State)") {
        'NOT-TRACKED'  { return 'NOT-TRACKED' }
        'NEVER-TESTED' { return "NEVER 0/$total" }
        'ALL-PASS'     { return "ALL-PASS $tested/$total ($logs logs)" }
        'HAS-FAIL'     { return "HAS-FAIL $tested/$total ($logs logs, $([int]$State.Fail) FAIL)" }
        'PARTIAL'      {
            if ($owed -gt 0) { return "PARTIAL ($logs logs, $owed owed)" }
            return "PARTIAL $tested/$total ($logs logs)"
        }
    }
    return $null
}

function Format-ClaudeVersionCell {
    <#
      "v4.13" -- from the active root JSON filename (Get-ProviderTestState resolves it).
      Returns $null when undeterminable, so the caller leaves the existing cell untouched.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State)

    if ($null -eq $State -or -not $State.Version) { return $null }
    return "v$($State.Version)"
}
