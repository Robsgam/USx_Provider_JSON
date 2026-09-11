<#
  serve_plans.ps1 -- tiny localhost HTTP server so the browser extension can load the
  repo's CURRENT test plan / picklist scope itself instead of the operator file-picking.

  Endpoints (CORS: *):
    GET /ping               -> {"ok":true}
    GET /plan/<PROVIDER>    -> newest providers/<P>/logs/<P>_TEST_PLAN_v*.json
    GET /scope/<PROVIDER>   -> providers/<P>/logs/<P>_PICKLIST_SCOPE.json
    GET /build/<PROVIDER>   -> providers/<P>/<P>_v*.json  (the CURRENT build, for the deploy path)
    GET /target/<deptId>    -> which PROVIDER that tenant is SUPPOSED to run (intent, not install)

  TcpListener on 127.0.0.1:8477 (no admin/urlacl needed, unlike HttpListener).
  http://localhost is exempt from mixed-content blocking, so the https tenant page can
  fetch it. Start once per session (background), like watch_captures.ps1.

  Usage: pwsh -File tools\serve_plans.ps1   (Ctrl+C to stop)
#>
param([int]$Port = 8477)

$providersDir = Join-Path $PSScriptRoot '..\providers'
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try { $listener.Start() } catch { Write-Error "Port $Port busy? $_"; exit 1 }
Write-Host "[SERVE] plan server on http://localhost:$Port  (/plan/<PROVIDER>, /scope/<PROVIDER>)" -ForegroundColor Cyan

function Send-Http($stream, [int]$code, [string]$body, [string]$ctype = 'application/json') {
    # 409 was sent by three code paths while absent from this table, so every refusal went out as
    # "HTTP/1.1 409 " with an EMPTY reason phrase -- legal, but it reads as a malformed response in
    # devtools and hid which refusal fired.
    $codeText = @{200 = 'OK'; 400 = 'Bad Request'; 404 = 'Not Found'; 409 = 'Conflict'}[$code]
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $hdr = "HTTP/1.1 $code $codeText`r`nContent-Type: $ctype; charset=utf-8`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    $hb = [System.Text.Encoding]::ASCII.GetBytes($hdr)
    $stream.Write($hb, 0, $hb.Length); $stream.Write($bytes, 0, $bytes.Length); $stream.Flush()
}

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 3000
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
        $reqLine = $reader.ReadLine()
        while (($l = $reader.ReadLine()) -and $l -ne '') { }   # drain headers
        if (-not $reqLine) { $client.Close(); continue }
        $parts = $reqLine -split '\s+'
        $urlPath = if ($parts.Count -ge 2) { $parts[1] } else { '/' }
        Write-Host "[SERVE] $reqLine" -ForegroundColor DarkGray

        if ($urlPath -eq '/ping') { Send-Http $stream 200 '{"ok":true}' }
        elseif ($urlPath -match '^/(plan|scope)/([A-Za-z0-9_]+)/?$') {
            $kind = $Matches[1]; $prov = $Matches[2]

            # PROVIDER RESOLUTION: exact -> UNIQUE prefix -> refuse. Added 2026-08-20.
            # The extension derives the provider from the TENANT HOSTNAME, and the hostname does not
            # always carry the provider directory's full name: `usx-nm-nmlets` yields NM_NMLETS while
            # the directory is NM_NMLETS_OFML, so the driver got
            #   {"error":"no plan for NM_NMLETS"}
            # and the operator saw "repo load failed -- is serve_plans.ps1 running?" -- which points at
            # the wrong thing entirely. The server WAS running; it was a name mismatch. (HI and IL are
            # unaffected only because their tenants happen to spell the -ofml suffix out.)
            # AMBIGUITY IS REFUSED, NOT GUESSED -- the Get-ProviderMetadataXml rule: a caller can handle
            # an error but cannot detect a plausible WRONG answer. `CA_CLETS` prefix-matches BOTH
            # CA_CLETS and CA_CLETS_OCATS, so exact-match MUST win first, and a genuinely ambiguous
            # prefix returns 409 naming the candidates instead of silently serving one.
            if (-not (Test-Path (Join-Path $providersDir $prov))) {
                $pfx = @(Get-ChildItem $providersDir -Directory -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -like "${prov}_*" -and (Test-Path (Join-Path $_.FullName 'scripts')) })
                if ($pfx.Count -eq 1) {
                    Write-Host "[SERVE] resolved '$prov' -> '$($pfx[0].Name)' (unique prefix match)" -ForegroundColor Cyan
                    $prov = $pfx[0].Name
                }
                elseif ($pfx.Count -gt 1) {
                    $names = ($pfx | ForEach-Object { $_.Name }) -join ', '
                    Write-Host "[SERVE] AMBIGUOUS '$prov' -> $names ; refusing to guess" -ForegroundColor Red
                    Send-Http $stream 409 ('{"error":"ambiguous provider ' + $prov + '","candidates":"' + $names + '"}')
                    # NO explicit Close here: `continue` targets the outer accept loop and the
                    # finally block at the bottom already closes $client. Closing twice was the
                    # first draft of this line.
                    continue
                }
            }

            $logsDir = Join-Path (Join-Path $providersDir $prov) 'logs'
            $file = $null
            if (Test-Path $logsDir) {
                if ($kind -eq 'plan') {
                    # VERSION-AWARE sort, not a STRING sort (fixed 2026-08-04). `Sort-Object Name`
                    # compares text, so v3.4 sorts AFTER v3.10 ('4' > '1') and the server would hand
                    # the driver a SUPERSEDED plan -- every resulting log then filed against a package
                    # that no longer exists, which is unrecoverable evidence-wise because the wire XML
                    # carries no version. Latent rather than live only because reset_test_package
                    # archives the previous plan, so exactly one file normally sits here; the window is
                    # real between a bump and that archive, and the portfolio is already at v4.18 /
                    # v4.19 / v7.17, where two-digit minors are one bump away.
                    # Proof of the old behaviour: v3.0, v3.4, v3.10 -> string sort picked v3.4.
                    $cands = @(Get-ChildItem $logsDir -Filter "${prov}_TEST_PLAN_v*.json" -ErrorAction SilentlyContinue)
                    $file = $cands |
                            Sort-Object -Property @{ Expression = {
                                if ($_.Name -match '_TEST_PLAN_v([0-9]+)\.([0-9]+)\.json$') {
                                    [int]$Matches[1] * 100000 + [int]$Matches[2]
                                } else { -1 }
                            } } | Select-Object -Last 1
                    if ($cands.Count -gt 1) {
                        Write-Host "[SERVE] WARNING: $($cands.Count) plan files for ${prov}; serving $($file.Name) (highest VERSION). Stale siblings should be archived by reset_test_package." -ForegroundColor Yellow
                    }
                } else {
                    $file = Get-ChildItem $logsDir -Filter "${prov}_PICKLIST_SCOPE.json" -ErrorAction SilentlyContinue |
                            Select-Object -First 1
                }
            }
            if ($file) { Send-Http $stream 200 (Get-Content $file.FullName -Raw) }
            else { Send-Http $stream 404 ('{"error":"no ' + $kind + ' for ' + $prov + '"}') }
        }
        elseif ($urlPath -match '^/build/([A-Za-z0-9_]+)/?$') {
            # /build/<PROVIDER> -- the CURRENT versioned root JSON, for the deploy path.
            # WHY THIS ENDPOINT EXISTS: the import payload must be the repo build BYTE-FOR-BYTE.
            # A file the operator hand-picks can be stale, renamed, or from _versions/ -- and the
            # whole point of verify_tenant_import is comparing against the repo build, so if the
            # payload came from somewhere else the verification would compare a tenant to a build
            # it was never given. Serving it from here removes the question.
            #
            # ⚠️ READ-ONLY, like every other endpoint. Handing out a file is not importing it;
            # the write happens in the browser, gated in deploy_probe.js.
            $prov = $Matches[1]
            if (-not (Test-Path (Join-Path $providersDir $prov))) {
                $pfx = @(Get-ChildItem $providersDir -Directory -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -like "${prov}_*" -and (Test-Path (Join-Path $_.FullName 'scripts')) })
                if ($pfx.Count -eq 1) { $prov = $pfx[0].Name }
                elseif ($pfx.Count -gt 1) {
                    $names = ($pfx | ForEach-Object { $_.Name }) -join ', '
                    Send-Http $stream 409 ('{"error":"ambiguous provider ' + $prov + '","candidates":"' + $names + '"}')
                    continue
                }
            }
            $pdir = Join-Path $providersDir $prov
            # ONE-JSON-IN-ROOT is the repo rule, so more than one is a repo defect, not a choice
            # to make here. Refuse rather than serve an arbitrary sibling as "the build".
            $cands = @(Get-ChildItem $pdir -Filter "${prov}_v*.json" -File -ErrorAction SilentlyContinue)
            if ($cands.Count -eq 1) {
                Write-Host "[SERVE] /build/$prov -> $($cands[0].Name) ($('{0:N0}' -f $cands[0].Length) bytes)" -ForegroundColor Cyan
                Send-Http $stream 200 (Get-Content $cands[0].FullName -Raw)
            }
            elseif ($cands.Count -eq 0) { Send-Http $stream 404 ('{"error":"no versioned root JSON for ' + $prov + '"}') }
            else {
                $names = ($cands | ForEach-Object { $_.Name }) -join ', '
                Write-Host "[SERVE] $($cands.Count) root JSONs for ${prov} -- refusing to pick one: $names" -ForegroundColor Red
                Send-Http $stream 409 ('{"error":"multiple root JSONs for ' + $prov + ' -- ONE-JSON-IN-ROOT violated","candidates":"' + $names + '"}')
            }
        }
        elseif ($urlPath -match '^/target/([0-9]+)/?$') {
            # /target/<deptId> -- WHICH PROVIDER IS THIS TENANT SUPPOSED TO RUN.
            #
            # WHY THIS EXISTS. Rob, 2026-09-11, on being asked to type FL_FCIC into the deploy box:
            #   "typing fcic in tath window is not right you should already know what the tenatn is
            #    supposed to be based on my direct input intitally since you ahve not deployed any
            #    on your own"
            # He is right, and it is a SAFETY point rather than a convenience one: a typo in that box
            # imports the WRONG PROVIDER into a real tenant, and every guard downstream would pass --
            # the payload would be a valid version-stamped build, the deptId would match the page, the
            # modal target field would agree. Nothing in the chain compares the payload's provider to
            # the tenant's intended one, because until now nothing KNEW the intended one.
            #
            # AUTHORITY ORDER, and each answer says which one it used:
            #   1. `intendedProvider` recorded on the tenant's row in tenant_map.json  -> "explicit-map"
            #   2. the `usx-<slug>` subdomain, which encodes it by construction        -> "usx-subdomain"
            #   3. nothing                                                             -> REFUSE (409)
            #
            # ⚠️ THE INSTALLED BUNDLE IS NOT AN AUTHORITY and is returned for CONTEXT ONLY. usx-fl-fcic
            # is the proof: it was carrying a CA_eSUN bundle, so "what is installed" would have named
            # exactly the wrong provider on the one tenant we deployed to first. Intent comes from the
            # record; the install is what we are correcting.
            $deptId = $Matches[1]
            $mapPath = Join-Path $PSScriptRoot 'config\tenant_map.json'
            if (-not (Test-Path $mapPath)) {
                Send-Http $stream 404 '{"error":"tenant_map.json not found"}'
                continue
            }
            # Re-read per request on purpose: a stale in-memory copy is exactly how a server started
            # yesterday served pre-change data for a day (the /build endpoint, 2026-09-11).
            $map = Get-Content $mapPath -Raw | ConvertFrom-Json
            $row = @($map.tenants | Where-Object { $_.deptId -eq $deptId })
            if ($row.Count -ne 1) {
                Write-Host "[SERVE] /target/$deptId -> $($row.Count) matching tenant rows; refusing" -ForegroundColor Red
                Send-Http $stream 404 ('{"error":"deptId ' + $deptId + ' is not in tenant_map.json (' + $row.Count + ' rows matched) -- it cannot be a deploy target until it is recorded"}')
                continue
            }
            $t = $row[0]
            $sub = [string]$t.subdomain
            $intended = $null; $src = $null
            if ($t.PSObject.Properties.Name -contains 'intendedProvider' -and $t.intendedProvider) {
                $intended = [string]$t.intendedProvider; $src = 'explicit-map'
            }
            elseif ($sub -like 'usx-*') {
                $derived = ($sub -replace '^usx-', '') -replace '-', '_'
                # CANONICALISE THE CASING OFF DISK. The derived string is upper-case, so CA_eSUN comes
                # out "CA_ESUN" -- which Test-Path happily accepts on Windows and which would then be
                # compared, character by character, against the "CA_eSUN" written inside the bundles.
                # A case-insensitive filesystem hides this until something does a string compare.
                $dirs = @(Get-ChildItem $providersDir -Directory -ErrorAction SilentlyContinue)
                $hit = @($dirs | Where-Object { $_.Name -eq $derived })
                if ($hit.Count -ne 1) { $hit = @($dirs | Where-Object { $_.Name -like "${derived}_*" -and (Test-Path (Join-Path $_.FullName 'scripts')) }) }
                if ($hit.Count -eq 1) { $intended = $hit[0].Name; $src = 'usx-subdomain' }
                elseif ($hit.Count -gt 1) {
                    $names = ($hit | ForEach-Object { $_.Name }) -join ', '
                    Send-Http $stream 409 ('{"error":"subdomain ' + $sub + ' is ambiguous","candidates":"' + $names + '"}')
                    continue
                }
            }
            if (-not $intended) {
                Write-Host "[SERVE] /target/$deptId ($sub) -> NO RECORDED INTENT; refusing" -ForegroundColor Red
                Send-Http $stream 409 ('{"error":"no recorded intended provider for ' + $sub + ' (' + $deptId + ')","fix":"record intendedProvider on its tenant_map.json row -- the deploy target is a decision, not something to type at the keyboard"}')
                continue
            }
            $installed = @($t.bundles | ForEach-Object { $_.name }) -join ','
            $excl = ''
            try {
                . (Join-Path $PSScriptRoot '_tenant_scope.ps1')
                $e = Get-TenantExclusion $deptId
                if ($e) { $excl = [string]$e.reason }
            } catch { }
            Write-Host "[SERVE] /target/$deptId ($sub) -> $intended [$src]" -ForegroundColor Cyan
            $body = '{"deptId":"' + $deptId + '","subdomain":"' + $sub + '","provider":"' + $intended +
                    '","source":"' + $src + '","class":"' + [string]$t.class + '","status":"' + [string]$t.status +
                    '","installedBundles":"' + $installed + '","scopeExcluded":"' + ($excl -replace '"', "'") + '"}'
            Send-Http $stream 200 $body
        }
        else { Send-Http $stream 404 '{"error":"unknown path"}' }
    } catch { Write-Host "[SERVE] request error: $_" -ForegroundColor DarkYellow }
    finally { $client.Close() }
}
