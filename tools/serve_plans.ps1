<#
  serve_plans.ps1 -- tiny localhost HTTP server so the browser extension can load the
  repo's CURRENT test plan / picklist scope itself instead of the operator file-picking.

  Endpoints (CORS: *):
    GET /ping               -> {"ok":true}
    GET /plan/<PROVIDER>    -> newest providers/<P>/logs/<P>_TEST_PLAN_v*.json
    GET /scope/<PROVIDER>   -> providers/<P>/logs/<P>_PICKLIST_SCOPE.json

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
    $codeText = @{200 = 'OK'; 404 = 'Not Found'; 400 = 'Bad Request'}[$code]
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
        else { Send-Http $stream 404 '{"error":"unknown path"}' }
    } catch { Write-Host "[SERVE] request error: $_" -ForegroundColor DarkYellow }
    finally { $client.Close() }
}
