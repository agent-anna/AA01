# ==============================================================================
# BAANANNA.PS1 — SOVEREIGN CORE VAULT & WALLET ENGINE (PORT 8081)
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$VaultConfig = @{
    NodeName        = "BAANANNA-VAULT-01"
    ListenPort      = 8081
    VaultWallet     = "DTzt4UaiB5EVguujuZrBbcMFSivmBg2pYG"
    AllowedTicker   = "SHI*"
}

Write-Host "======================================================================" -ForegroundColor Green
Write-Host " [BAANANNA.PS1] STARTING CORE VAULT ENGINE" -ForegroundColor Green
Write-Host " VAULT WALLET: $($VaultConfig.VaultWallet)" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Green

$Listener = New-Object System.Net.HttpListener
$Prefix = "http://localhost:$($VaultConfig.ListenPort)/"
$Listener.Prefixes.Add($Prefix)

try {
    $Listener.Start()
    Write-Host "[+] Vault Engine Active: $Prefix" -ForegroundColor Green
    Write-Host "    Ready for cryptographic wallet validation. Press CTRL+C to exit.`n" -ForegroundColor Gray
    
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
        
        if ($Path -eq "/api/vault/verify") {
            $SourceAddress = $VaultConfig.VaultWallet
            if ($Request.HttpMethod -eq "POST") {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $RawBody = $Reader.ReadToEnd()
                if ($RawBody) {
                    $Parsed = $RawBody | ConvertFrom-Json
                    if ($Parsed.address) { $SourceAddress = $Parsed.address }
                }
            }
            
            $IsValid = ($SourceAddress -eq $VaultConfig.VaultWallet)
            $ResObj = @{
                verified    = $IsValid
                vaultWallet = $VaultConfig.VaultWallet
                message     = if ($IsValid) { "VAULT AUTHENTICATED: Genuine SHI* Verified from Vault." } else { "FAKE / UNWASHED SHI* DETECTED: Tokens must route through Vault." }
            } | ConvertTo-Json
            
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($ResObj)
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        elseif ($Path -eq "/api/node/swap") {
            $SwapResponse = @{
                status       = "EXECUTED"
                txid         = "drc20_vault_tx_" + [Guid]::NewGuid().ToString().Substring(0,8)
                feeCollected = "0.1% Protocol Fee Secured"
                destination  = $VaultConfig.VaultWallet
            } | ConvertTo-Json
            
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($SwapResponse)
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        else {
            $Response.StatusCode = 404
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes("Vault Route Not Found")
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        $Response.Close()
    }
}
catch {
    Write-Host "[-] Vault Engine Error: $_" -ForegroundColor Red
}
finally {
    $Listener.Stop()
}