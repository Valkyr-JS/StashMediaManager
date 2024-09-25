$apiData = Get-Content -Raw "$PSScriptRoot/apis/apiData.json" | ConvertFrom-Json

# ---------------------------------- GENERAL --------------------------------- #

# Set the user config value for the assets directory
function Set-ConfigAssetsDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your assets folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path $userInput))

    $userConfig.general.assetsDirectory = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig
    return $userConfig
}

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

# Set the user config value for aylo.masterSite
function Set-ConfigAyloMasterSite {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json

    do { $userInput = read-host "Which Aylo site do you login through?" }
    while ($apiData -notcontains $userInput)

    $userConfig.aylo.masterSite = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig

    return $userConfig
}
