param(
    [string]$Query = "martin strayd"
)

# Set up headers to mimic a legitimate browser request and prevent blocking
$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Accept-Language" = "en-US,en;q=0.9"
}

# Construct direct Google search URI cleanly without search engine routing leakage
$targetUri = "https://www.google.com/search?q=" + [System.Uri]::EscapeDataString($Query)

try {
    # Execute web request
    $response = Invoke-WebRequest -Uri $targetUri -Headers $headers -UseBasicParsing -TimeoutSec 10
    
    # Extract visible text content from HTML tags
    $rawHtml = $response.Content
    $cleanText = [System.Text.RegularExpressions.Regex]::Replace($rawHtml, "<script[^>]*>[\s\S]*?</script>", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $cleanText = [System.Text.RegularExpressions.Regex]::Replace($cleanText, "<style[^>]*>[\s\S]*?</style>", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $cleanText = [System.Text.RegularExpressions.Regex]::Replace($cleanText, "<[^>]+>", " ", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $cleanText = [System.Net.WebUtility]::HtmlDecode($cleanText)
    
    # Purge any residual search footers, regional headers, or metadata debris
    $cleanText = $cleanText -replace "All Regions.*?(?:United Kingdom|Vietnam)", ""
    $cleanText = $cleanText -replace "Argentina Australia Austria.*?(?:United Kingdom|Vietnam)", ""
    $cleanText = $cleanText -replace "Any Time Past Day Past Week Past Month Past Year", ""
    $cleanText = $cleanText -replace "DuckDuckGo", ""
    $cleanText = $cleanText -replace "\s+", " "
    
    $cleanText = $cleanText.Trim()
    
    # Return formatted JSON payload for local endpoint consumption
    $output = @{
        status = "SUCCESS"
        target = $Query
        result = $cleanText
    } | ConvertTo-Json -Compress
    
    Write-Output $output
}
catch {
    $errorOutput = @{
        status = "ERROR"
        target = $Query
        result = "Failed to scrape target: $_"
    } | ConvertTo-Json -Compress
    
    Write-Output $errorOutput
}