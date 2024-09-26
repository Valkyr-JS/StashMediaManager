. "./config-management.ps1"
. "./helpers.ps1"

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

    # Next, user selects an operation
    Write-Host `n"What would you like to do?"
    Write-Host "1. Download media"
    Write-Host "2. Update Stash"
    do { $operationSelection = read-host "Enter your selection (1-2)" }
    while (($operationSelection -notmatch "[1-2]"))

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

        # Update the config if needed
        if ($userConfig.general.downloadDirectory.Length -eq 0) {
            $userConfig = Set-ConfigDownloadDirectory -pathToUserConfig $pathToUserConfig
        }

        # Ensure the download directory doesn't have a trailing directory delimiter
        [string]$downloadDirectory = $userConfig.general.downloadDirectory
        if ($downloadDirectory[-1] -eq $directorydelimiter) {
            $downloadDirectory = $downloadDirectory.Substring(0, $downloadDirectory.Length - 1)
        }

        if ($userConfig.general.scrapedDataDirectory.Length -eq 0) {
            $userConfig = Set-ConfigScrapedDataDirectory -pathToUserConfig $pathToUserConfig
        }

        # Ensure the scraped data directory doesn't have a trailing directory delimiter
        [string]$scrapedDataDirectory = $userConfig.general.scrapedDataDirectory
        if ($scrapedDataDirectory[-1] -eq $directorydelimiter) {
            $scrapedDataDirectory = $scrapedDataDirectory.Substring(0, $scrapedDataDirectory.Length - 1)
        }

        if ($userConfig.general.assetsDirectory.Length -eq 0) {
            $userConfig = Set-ConfigAssetsDirectory -pathToUserConfig $pathToUserConfig
        }

        # Ensure the assets directory doesn't have a trailing directory delimiter
        [string]$assetsDirectory = $userConfig.general.assetsDirectory
        if ($assetsDirectory[-1] -eq $directorydelimiter) {
            $assetsDirectory = $assetsDirectory.Substring(0, $assetsDirectory.Length - 1)
        }

        # Next, user specifies what to download
        Write-Host `n"What content do you want to download?"
        Write-Host "1. All content from a group of performers"
        Write-Host "2. All content from a series"
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
            # Next, user specifies series IDs
            Write-Host `n"Specify all series IDs you wish to download in a space-separated list, e.g. '123 2534 1563'."
            $seriesIDs = read-host "Series IDs"
            $seriesIDs = $seriesIDs -split (" ")

            Get-AyloAllContentBySeriesID -pathToUserConfig $pathToUserConfig -seriesIDs $seriesIDs
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