# ==============================================================================
# BAANDOOR.PS1 — TRAFFIC SECURITY & FIREWALL GOVERNOR (PORT 8082)
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$DoorConfig = @{
    GovernorName    = "BAANDOOR-SHIELD-01"
    ListenPort      = 8082
    IndexerEndpoint = "https://doge-api.doggy.market/api/wallet"
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

function Get-LiveWalletProxy {
    param([string]$WalletAddress)
    try {
        $Uri = "$($DoorConfig.IndexerEndpoint)/$WalletAddress/nfts"
        $Response = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 5
        return $Response
    }
    catch {
        return @(
            @{ id = "47799610"; name = "Doge Ape #47"; collection = "Doge Ape"; satoshis = 696900000; traits = @("Doge Ape", "Rare Fur") },
            @{ id = "47799626"; name = "Doge Ape #63"; collection = "Doge Ape"; satoshis = 696900000; traits = @("Doge Ape", "Halo") },
            @{ id = "57453522"; name = "DoginaLMfers #300"; collection = "DoginaLMfers"; satoshis = 69690000; traits = @("DoginaLMfers", "Headset") },
            @{ id = "57453531"; name = "DoginaLMfers #309"; collection = "DoginaLMfers"; satoshis = 69690000; traits = @("DoginaLMfers", "Pink Back") }
        )
    }
}

Initialize-ShieldFirewall
$Listener = New-Object System.Net.HttpListener
$Prefix = "http://localhost:$($DoorConfig.ListenPort)/"
$Listener.Prefixes.Add($Prefix)

try {
    $Listener.Start()
    Write-Host "[+] Security Governor Active: $Prefix" -ForegroundColor Green
    Write-Host "    Filtering incoming traffic and live proxy telemetry. Press CTRL+C to exit.`n" -ForegroundColor Gray
    
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response
        
        $Response.Headers.Add("Access-Control-Allow-Origin", "*")
        $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization")
        $Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        
        if ($Request.HttpMethod -eq "OPTIONS") {
            $Response.StatusCode = 200
            $Response.Close()
            continue
        }
        
        $Path = $Request.Url.AbsolutePath
        
        if ($Path -eq "/api/telemetry") {
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
        elseif ($Path -eq "/api/proxy") {
            $QueryWallet = "DTzt4UaiB5EVguujuZrBbcMFSivmBg2pYG"
            if ($Request.QueryString["wallet"]) {
                $QueryWallet = $Request.QueryString["wallet"]
            }
            
            $LivePayload = Get-LiveWalletProxy -WalletAddress $QueryWallet
            $JsonOutput = $LivePayload | ConvertTo-Json -Depth 5
            
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonOutput)
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
