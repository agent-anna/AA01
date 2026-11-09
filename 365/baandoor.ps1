# ==============================================================================
# BAANDOOR.PS1 — TRAFFIC SECURITY & FIREWALL GOVERNOR (PORT 8082)
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$DoorConfig = @{
    GovernorName    = "BAANDOOR-SHIELD-01"
    ListenPort      = 8082
    IndexerEndpoint = "https://api.doggy.market/v1/drc20/shi*"
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " [BAANDOOR.PS1] STARTING SECURITY GOVERNOR & FIREWALL SHIELD" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

function Initialize-ShieldFirewall {
    $RuleName = "BAANDOOR_TRAFFIC_SHIELD"
    if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $DoorConfig.ListenPort -Profile Any | Out-Null
        Write-Host "[+] Firewall Shield Active on Port $($DoorConfig.ListenPort)" -ForegroundColor Green
    } else {
        Write-Host "[+] Firewall Shield Rule Verified." -ForegroundColor DarkGreen
    }
}

Initialize-ShieldFirewall
$Listener = New-Object System.Net.HttpListener
$Prefix = "http://localhost:$($DoorConfig.ListenPort)/"
$Listener.Prefixes.Add($Prefix)

try {
    $Listener.Start()
    Write-Host "[+] Security Governor Active: $Prefix" -ForegroundColor Green
    Write-Host "    Filtering incoming traffic and telemetry. Press CTRL+C to exit.`n" -ForegroundColor Gray
    
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response
        
        $Response.Headers.Add("Access-Control-Allow-Origin", "*")
        $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization")
        $Response.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
        
        if ($Request.HttpMethod -eq "OPTIONS") {
            $Response.StatusCode = 200
            $Response.Close()
            continue
        }
        
        if ($Request.Url.AbsolutePath -eq "/api/telemetry") {
            $Telemetry = @{
                status    = "SECURE_SHIELD_ONLINE"
                ticker    = "SHI*"
                priceDoge = 0.00000100
                timestamp = (Get-Date).ToString("o")
            } | ConvertTo-Json
            
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($Telemetry)
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        else {
            $Response.StatusCode = 403
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes("Access Denied: Guarded by Baandoor Governor")
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        $Response.Close()
    }
}
catch {
    Write-Host "[-] Security Governor Error: $_" -ForegroundColor Red
}
finally {
    $Listener.Stop()
}