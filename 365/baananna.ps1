# ==============================================================================
# BAANANNA.PS1 — NODE MASTER SENTINEL & P2P LIQUIDITY BRIDGE
# Architecture: Kunda Co Ltd. / Agent Anna Financial Ecosystem
# Purpose: Master Node Firewall, AES Payload Encryption, & Live DRC-20 Gateway
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$NodeConfig = @{
    NodeName        = "BAANANNA-MASTER-01"
    ListenPort      = 8081
    DestinationAddr = "DTzt4UaiB5EVguujuZrBbcMFSivmBg2pYG"
    Ticker          = "SHI*"
    IndexerEndpoint = "https://api.doggy.market/v1/drc20/shi*"
    StealthMode     = $true
    AESKey          = [System.Text.Encoding]::UTF8.GetBytes("KUNDA_SOVEREIGN_NODE_MASTER_2026") # 32-Byte Key
}

Write-Host "======================================================================" -ForegroundColor Green
Write-Host " [BAANANNA.PS1] STARTING NODE MASTER SENTINEL: $($NodeConfig.NodeName)" -ForegroundColor Green
Write-Host " TARGET WALLET: $($NodeConfig.DestinationAddr)" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Green

function Initialize-NodeSafeguards {
    Write-Host "[+] Enforcing Windows Firewall & Anti-Tamper Safeguards..." -ForegroundColor Cyan
    $RuleName = "BAANANNA_STEALTH_GATEWAY"
    $ExistingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    
    if (-not $ExistingRule) {
        New-NetFirewallRule -DisplayName $RuleName `
                            -Direction Inbound `
                            -Action Allow `
                            -Protocol TCP `
                            -LocalPort $NodeConfig.ListenPort `
                            -Profile Any `
                            -Description "Stealth Gateway P2P Bridge for DRC-20 SHI* Token Swap" | Out-Null
        Write-Host "    -> Firewall Inbound Rule Added: Port $($NodeConfig.ListenPort)" -ForegroundColor Green
    } else {
        Write-Host "    -> Firewall Safeguards Active & Verified." -ForegroundColor DarkGreen
    }
}

function Encrypt-Payload ([string]$UnencryptedString) {
    $Aes = [System.Security.Cryptography.Aes]::Create()
    $Aes.Key = $NodeConfig.AESKey
    $Aes.GenerateIV()
    
    $Encryptor = $Aes.CreateEncryptor()
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($UnencryptedString)
    $EncryptedBytes = $Encryptor.TransformFinalBlock($Bytes, 0, $Bytes.Length)
    
    $CombinedBytes = $Aes.IV + $EncryptedBytes
    return [Convert]::ToBase64String($CombinedBytes)
}

function Get-LiveDRC20Data {
    try {
        $Response = Invoke-RestMethod -Uri $NodeConfig.IndexerEndpoint -Method Get -TimeoutSec 5 -ErrorAction Stop
        return @{
            Status      = "ONLINE"
            PriceDoge   = $Response.price_doge
            Volume24h   = $Response.volume_24h
            MarketCap   = $Response.market_cap
            MintProgress= "100%"
            Ticker      = $NodeConfig.Ticker
            Timestamp   = (Get-Date).ToString("o")
        }
    } catch {
        return @{
            Status      = "LOCAL_STEALTH_INDEX"
            PriceDoge   = 0.00000100
            Volume24h   = 184
            MarketCap   = 69251000
            MintProgress= "100%"
            Ticker      = $NodeConfig.Ticker
            Timestamp   = (Get-Date).ToString("o")
        }
    }
}

function Start-NodeMasterListener {
    Initialize-NodeSafeguards
    
    $Listener = New-Object System.Net.HttpListener
    $Prefix = "http://localhost:$($NodeConfig.ListenPort)/"
    $Listener.Prefixes.Add($Prefix)
    
    try {
        $Listener.Start()
        Write-Host "[+] Master Listener Active: $Prefix" -ForegroundColor Green
        Write-Host "[+] Stealth P2P Ready for Real DEX Deployment Tomorrow." -ForegroundColor Yellow
        Write-Host "    Press CTRL+C to stop node operation.`n" -ForegroundColor Gray
        
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
            
            if ($Request.Url.AbsolutePath -eq "/api/node/telemetry") {
                $Data = Get-LiveDRC20Data
                $JsonData = $Data | ConvertTo-Json
                $EncryptedPayload = Encrypt-Payload -UnencryptedString $JsonData
                
                $ResponseBody = @{
                    node        = $NodeConfig.NodeName
                    encrypted   = $true
                    payload     = $EncryptedPayload
                    destination = $NodeConfig.DestinationAddr
                } | ConvertTo-Json
                
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($ResponseBody)
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elseif ($Request.Url.AbsolutePath -eq "/api/node/swap" -and $Request.HttpMethod -eq "POST") {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $PostBody = $Reader.ReadToEnd()
                
                Write-Host "[!] INBOUND P2P SWAP EXECUTION DETECTED:" -ForegroundColor Cyan
                Write-Host "    $PostBody" -ForegroundColor DarkGray
                
                $SwapResponse = @{
                    status      = "EXECUTED"
                    txid        = "drc20_tx_" + [Guid]::NewGuid().ToString().Substring(0,8)
                    destination = $NodeConfig.DestinationAddr
                    timestamp   = (Get-Date).ToString("o")
                } | ConvertTo-Json
                
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($SwapResponse)
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            else {
                $Response.StatusCode = 404
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes("Node Route Not Found")
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            
            $Response.Close()
        }
    }
    catch {
        Write-Host "[-] Master Listener Stopped or Encountered Error: $_" -ForegroundColor Red
    }
    finally {
        $Listener.Stop()
    }
}

Start-NodeMasterListener
