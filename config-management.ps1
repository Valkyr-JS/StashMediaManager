# Set the user config value for aylo.apiKey.
function Set-ConfigAyloApiKey {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $userInput = read-host "Please enter your API key"
    if ($userInput.Length -eq 0) {
        Write-Host "WARNING: No key entered." -ForegroundColor Yellow
        return
    }
    $userConfig.aylo.apiKey = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig

    return $userConfig
}

function Set-ConfigAyloAuthCode {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $userInput = read-host "Please enter your auth code"
    if ($userInput.Length -eq 0) {
        Write-Host "WARNING: No key entered." -ForegroundColor Yellow
        return
    }
    $userConfig.aylo.authCode = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig

    return $userConfig
}