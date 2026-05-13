param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl
)

$ErrorActionPreference = "Stop"

function Invoke-Check {
    param(
        [string]$Name,
        [string]$Url
    )

    Write-Host "Checking $Name -> $Url" -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $Url -Method Get
    Write-Host "OK: $Name" -ForegroundColor Green
    return $response
}

$normalizedBaseUrl = $BaseUrl.TrimEnd("/")

Invoke-Check -Name "Gateway Health" -Url "$normalizedBaseUrl/health" | Out-Null
Invoke-Check -Name "Gateway Routes" -Url "$normalizedBaseUrl/api/routes" | Out-Null
Invoke-Check -Name "Users Swagger JSON" -Url "$normalizedBaseUrl/swagger/users/v1/swagger.json" | Out-Null
Invoke-Check -Name "Catalog Games" -Url "$normalizedBaseUrl/api/games?page=1&pageSize=5" | Out-Null
Invoke-Check -Name "Catalog Search" -Url "$normalizedBaseUrl/api/games/search?q=halo&page=1&pageSize=5" | Out-Null

Write-Host "Smoke test completed successfully." -ForegroundColor Green
