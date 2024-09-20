# ---------------------------------- GENERAL --------------------------------- #

# Set the user config value for the download directory
function Set-ConfigDownloadDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your download folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path $userInput))

    $userConfig.general.downloadDirectory = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig
    return $userConfig
}

# Set the user config value for the scraped data directory
function Set-ConfigScrapedDataDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your scraped data folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path $userInput))

    $userConfig.general.scrapedDataDirectory = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig
    return $userConfig
}

# ----------------------------------- AYLO ----------------------------------- #

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

# Set the user config value for aylo.authCode.
function Set-ConfigAyloAuthCode {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $userInput = read-host "Please enter your auth code"
    if ($userInput.Length -eq 0) {
        Write-Host "WARNING: No code entered." -ForegroundColor Yellow
        return
    }
    $userConfig.aylo.authCode = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig

    return $userConfig
}