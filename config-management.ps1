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

# Set the user config value for the assets download directory
function Set-ConfigAssetsDownloadDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your assets download folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path $userInput))

    $userConfig.general.assetsDownloadDirectory = "$userInput"
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

# Set the user config value for the storage directory
function Set-ConfigStorageDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your storage folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path $userInput))

    $userConfig.general.storageDirectory = "$userInput"
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

# Set the user config value for aylo.metaStashUrl
function Set-ConfigAyloStashURL {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json

    do {
        $userInput = read-host "Please check your connection, or correct the link to your Stash instance"

        #Now we can check to ensure this address is valid-- we'll use a very simple GQL query and get the Stash version
        $StashGQL_Query = 'query version{version{version}}'
        try {
            $stashUrl = $userInput
            if ($stashUrl[-1] -ne "/") { $stashUrl += "/" }
            $stashUrl += "graphql"
            $stashVersion = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $stashUrl
        }
        catch {
            write-host "ERROR: Could not connect to Stash at $userInput" -ForegroundColor Red
        }
    }
    while ($null -eq $stashVersion)

    $userConfig.aylo.metaStashUrl = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig

    return $userConfig
}


# Set the user config value for addfriends.stashUrl
function Set-ConfigAddFriendsStashURL {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json

    do {
        $userInput = read-host "Please check your connection, or correct the link to your Stash instance"

        $StashGQL_Query = 'query version{version{version}}'
        try {
            $stashUrl = $userInput
            if ($stashUrl[-1] -ne "/") { $stashUrl += "/" }
            $stashUrl += "graphql"
            $stashVersion = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $stashUrl
        }
        catch {
            write-host "ERROR: Could not connect to Stash at $userInput" -ForegroundColor Red
        }
    }
    while ($null -eq $stashVersion)

    $userConfig.addfriends.stashUrl = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig

    return $userConfig
}
