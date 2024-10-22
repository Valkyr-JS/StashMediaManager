$apiData = Get-Content -Raw "$PSScriptRoot/apis/apiData.json" | ConvertFrom-Json

# ---------------------------------- GENERAL --------------------------------- #

# Set the user config value for the assets directory
function Set-ConfigAssetsDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your assets folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path -LiteralPath $userInput))

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
    while (($userInput.Length -eq 0) -or !(Test-Path -LiteralPath $userInput))

    $userConfig.general.assetsDownloadDirectory = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig
    return $userConfig
}

# Set the user config value for the content directory
function Set-ConfigContentDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your content folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path -Literal $userInput))

    $userConfig.general.contentDirectory = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig
    return $userConfig
}

# Set the user config value for the content download directory
function Set-ConfigContentDownloadDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your content download folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path -LiteralPath $userInput))

    $userConfig.general.contentDownloadDirectory = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig
    return $userConfig
}

# Set the user config value for the data directory
function Set-ConfigDataDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your data folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path -LiteralPath $userInput))

    $userConfig.general.dataDownloadDirectory = "$userInput"
    $userConfig | ConvertTo-Json -depth 32 | set-content $pathToUserConfig
    return $userConfig
}

# Set the user config value for the data directory
function Set-ConfigDataDownloadDirectory {
    param(
        [String]$pathToUserConfig
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    do { $userInput = read-host "Please enter a valid path to your data download folder" }
    while (($userInput.Length -eq 0) -or !(Test-Path -LiteralPath $userInput))

    $userConfig.general.dataDownloadDirectory = "$userInput"
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
