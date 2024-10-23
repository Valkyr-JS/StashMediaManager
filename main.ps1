. "./config-management.ps1"
. "./helpers.ps1"

. "./stash/galleries.ps1"
. "./stash/groups.ps1"
. "./stash/performers.ps1"
. "./stash/scenes.ps1"
. "./stash/studios.ps1"
. "./stash/tags.ps1"

# ? Dev variables
$useDevConfig = $true

# Global variables
if ($IsWindows) { $directorydelimiter = '\' }
else { $directorydelimiter = '/' }

if ($useDevConfig) {
    $pathToUserConfig = ".$directorydelimiter" + "config.dev.json"
}
else {
    $pathToUserConfig = ".$directorydelimiter" + "config.json"
}

$userConfig = Get-Content -Raw $pathToUserConfig | ConvertFrom-Json
$apiData = Get-Content -Raw "./apis/apiData.json" | ConvertFrom-Json

# Load the entrypoint for the script.
function Set-Entry {
    Clear-Host
    Write-Host "Stash Media Manager"
    Write-Host "-------------------"

    # User first selects an API
    Write-Host "Which API are you working with?"
    $apicounter = 1
    foreach ($item in $apiData) {
        Write-Host "$apicounter. $($item.name)";
        $apicounter++
    }

    do { $apiSelection = read-host "Enter your selection (1)" }
    while (($apiSelection -notmatch "[1-$apicounter]"))

    $apiData = $apiData[$apiSelection - 1]

    # -------------------------- General config updates -------------------------- #
    
    # Check that the assets directory has been set
    if ($userConfig.general.assetsDirectory.Length -eq 0) {
        $userConfig = Set-ConfigAssetsDirectory -pathToUserConfig $pathToUserConfig
    }

    # Ensure the assets directory doesn't have a trailing directory delimiter
    [string]$assetsDirectory = $userConfig.general.assetsDirectory
    if ($assetsDirectory[-1] -eq $directorydelimiter) {
        $assetsDirectory = $assetsDirectory.Substring(0, $assetsDirectory.Length - 1)
    }

    # Check that the assets download directory has been set
    if ($userConfig.general.assetsDownloadDirectory.Length -eq 0) {
        $userConfig = Set-ConfigAssetsDownloadDirectory -pathToUserConfig $pathToUserConfig
    }

    # Ensure the assets download directory doesn't have a trailing directory delimiter
    [string]$assetsDownloadDirectory = $userConfig.general.assetsDownloadDirectory
    if ($assetsDownloadDirectory[-1] -eq $directorydelimiter) {
        $assetsDownloadDirectory = $assetsDownloadDirectory.Substring(0, $assetsDownloadDirectory.Length - 1)
    }

    # Check that the content directory has been set
    if ($userConfig.general.contentDirectory.Length -eq 0) {
        $userConfig = Set-ConfigContentDirectory -pathToUserConfig $pathToUserConfig
    }

    # Ensure the content directory doesn't have a trailing directory delimiter
    [string]$contentDirectory = $userConfig.general.contentDirectory
    if ($contentDirectory[-1] -eq $directorydelimiter) {
        $contentDirectory = $contentDirectory.Substring(0, $contentDirectory.Length - 1)
    }

    # Check that the content download directory has been set
    if ($userConfig.general.contentDownloadDirectory.Length -eq 0) {
        $userConfig = Set-ConfigContentDownloadDirectory -pathToUserConfig $pathToUserConfig
    }

    # Ensure the download directory doesn't have a trailing directory delimiter
    [string]$contentDownloadDirectory = $userConfig.general.contentDownloadDirectory
    if ($contentDownloadDirectory[-1] -eq $directorydelimiter) {
        $contentDownloadDirectory = $contentDownloadDirectory.Substring(0, $contentDownloadDirectory.Length - 1)
    }

    # Check that the data directory has been set
    if ($userConfig.general.dataDirectory.Length -eq 0) {
        $userConfig = Set-ConfigDataDirectory -pathToUserConfig $pathToUserConfig
    }

    # Ensure the data directory doesn't have a trailing directory delimiter
    [string]$dataDirectory = $userConfig.general.dataDirectory
    if ($dataDirectory[-1] -eq $directorydelimiter) {
        $dataDirectory = $dataDirectory.Substring(0, $dataDirectory.Length - 1)
    }

    # Check that the data download directory has been set
    if ($userConfig.general.dataDownloadDirectory.Length -eq 0) {
        $userConfig = Set-ConfigDataDownloadDirectory -pathToUserConfig $pathToUserConfig
    }

    # Ensure the data download directory doesn't have a trailing directory delimiter
    [string]$dataDownloadDirectory = $userConfig.general.dataDownloadDirectory
    if ($dataDownloadDirectory[-1] -eq $directorydelimiter) {
        $dataDownloadDirectory = $dataDownloadDirectory.Substring(0, $dataDownloadDirectory.Length - 1)
    }

    # Next, user selects an operation
    Write-Host `n"What would you like to do?"
    Write-Host "1. Download media"
    Write-Host "2. Update Stash"
    do { $operationSelection = read-host "Enter your selection (1-2)" }
    while (($operationSelection -notmatch "[1-2]"))

    # --------------------------- AddFriends : Download -------------------------- #

    if ($operationSelection -eq 1 -and $apiData.name -eq "AddFriends") {
        Write-Host `n"Which site do you want to download from?"

        $addFriendsApiCounter = 1
        $addFriendsApiData = $apiData | Where-Object { $_.name -eq "AddFriends" }

        foreach ($site in $addFriendsApiData.sites) {
            Write-Host "$addFriendsApiCounter. $($site.site_name)";
            $addFriendsApiCounter++
        }
    
        do { $siteSelection = read-host "Enter your selection" }
        while (($siteSelection -notmatch "[1-$addFriendsApiCounter]"))
    
        $addFriendsApiData = $addFriendsApiData.sites[$siteSelection - 1]
    
        Write-Host `n"Begin downloading all missing content from addfriends.com/vip/$($addFriendsApiData.url)?"
        do { $userInput = Read-Host "[Y/N]" }
        while ($userInput -notlike "Y" -and $userInput -notlike "N")

        if ($userInput -like "Y") {
            # Load the required files
            . "./apis/addfriends/addfriends-actions.ps1"
            . "./apis/addfriends/addfriends-downloader.ps1"
            . "./apis/addfriends/addfriends-scraper.ps1"

            Get-AFAllContentBySite -pathToUserConfig $pathToUserConfig -siteName $addFriendsApiData.site_name -slug $addFriendsApiData.url
        }
        else {
            Write-Host "Closing the script."
            exit
        }
    
    }

    # ----------------------------- AddFriend : Stash ---------------------------- #

    if ($operationSelection -eq 2 -and $apiData.name -eq "AddFriends") {
        # Load the required files
        . "./apis/addfriends/addfriends-json-to-meta-stash.ps1"
        
        Set-AFJsonToMetaStash -pathToUserConfig $pathToUserConfig
    }

    # ------------------------------ Aylo : Download ----------------------------- #

    if ($operationSelection -eq 1 -and $apiData.name -eq "Aylo") {
        Write-Host `n"Specify the networks you wish to download from in a space-separated list, e.g. 'bangbros mofos brazzers'. Leave blank to scan all networks you have access to."
        Write-Host "Accepted networks are: $($apiData.networks)"
        do {
            $networks = read-host "Networks"
            $networksValid = $true

            # Check if the answer is an empty string
            if ($networks.Length -ne 0) {
                # If not, check all networks are valid
                foreach ($s in ($networks -split " ")) {
                    if ($apiData.networks -notcontains $s.Trim()) {
                        $networksValid = $false
                    }
                }
            }
        }
        while ($networksValid -eq $false)

        $networks = $networks -split (" ")

        # Next, user specifies what to download
        Write-Host `n"What content do you want to download?"
        Write-Host "1. All content from a list of performers"
        Write-Host "2. All content from a list of scenes"
        Write-Host "3. All content from a list of series"
        do { $contentSelection = read-host "Enter your selection (1-2)" }
        while (($contentSelection -notmatch "[1-2]"))

        # Load the required files
        . "./apis/aylo/aylo-scraper.ps1"
        . "./apis/aylo/aylo-downloader.ps1"
        . "./apis/aylo/aylo-actions.ps1"

        if ($contentSelection -eq 1) {
            # Next, user specifies actor IDs
            Write-Host `n"Specify all performer IDs you wish to download in a space-separated list, e.g. '123 2534 1563'."
            $actorIDs = read-host "Performer IDs"
            $actorIDs = $actorIDs -split (" ")

            foreach ($network in $networks) {
                Get-AyloAllContentByActorIDs -actorIDs $actorIDs -parentStudio $network -pathToUserConfig $pathToUserConfig
            }
        }
        elseif ($contentSelection -eq 2) {
            # Next, user specifies scene IDs
            Write-Host `n"Specify all scene IDs you wish to download in a space-separated list, e.g. '123 2534 1563'."
            $sceneIDs = read-host "Scene IDs"
            $sceneIDs = $sceneIDs -split (" ")

            Get-AyloAllContentBySceneIDs -pathToUserConfig $pathToUserConfig -sceneIDs $sceneIDs
        }
        elseif ($contentSelection -eq 3) {
            # Next, user specifies series IDs
            Write-Host `n"Specify all series IDs you wish to download in a space-separated list, e.g. '123 2534 1563'."
            $seriesIDs = read-host "Series IDs"
            $seriesIDs = $seriesIDs -split (" ")

            Get-AyloAllContentBySeriesIDs -pathToUserConfig $pathToUserConfig -seriesIDs $seriesIDs
        }
    }

    # ------------------------------- Aylo : Stash ------------------------------- #

    if ($operationSelection -eq 2 -and $apiData.name -eq "Aylo") {
        # Load the required files
        . "./apis/aylo/aylo-json-to-meta-stash.ps1"
        
        Set-AyloJsonToMetaStash -pathToUserConfig $pathToUserConfig
    }
    
    else { Write-Host "This feature is awaiting development." }
}

Set-Entry