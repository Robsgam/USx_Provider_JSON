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
            $logsDir = Join-Path (Join-Path $providersDir $prov) 'logs'
            $file = $null
            if (Test-Path $logsDir) {
                if ($kind -eq 'plan') {
                    $file = Get-ChildItem $logsDir -Filter "${prov}_TEST_PLAN_v*.json" -ErrorAction SilentlyContinue |
                            Sort-Object Name | Select-Object -Last 1
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
