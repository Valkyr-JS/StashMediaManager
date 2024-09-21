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
    $apiName = $apiData.name

    Write-Host `n"WARNING: Please make sure your authorization code is up to date in your config before you continue. If it needs updating, cancel this script, manually update the config, then run the script again." -ForegroundColor Yellow

    # Next, user selects an operation
    Write-Host `n"What would you like to do?"
    Write-Host "1. Download media"
    Write-Host "2. Update Stash"
    do { $operationSelection = read-host "Enter your selection (1-2)" }
    while (($operationSelection -notmatch "[1-2]"))

    # AYLO
    if ($operationSelection -eq 1 -and $apiData.name -eq "Aylo") {
        Write-Host `n"Specify the studios you wish to download from in a space-separated list, e.g. 'bangbros mofos brazzers'."
        Write-Host "Accepted studios are: $($apiData.studios)"
        do {
            $studios = read-host "Studios"
            $studiosValid = $true
            foreach ($s in ($studios -split " ")) {
                if ($apiData.studios -notcontains $s.Trim()) {
                    $studiosValid = $false
                }
            }
        }
        while ($studiosValid -eq $false)

        $studios = $studios -split (" ")

        # Update the config if needed
        . "./config-management.ps1"
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

        if ($userConfig.aylo.apiKey.Length -eq 0) {
            $userConfig = Set-ConfigAyloApikey -pathToUserConfig $pathToUserConfig
        }

        # Next, user specifies what to download
        Write-Host `n"What content do you want to download?"
        Write-Host "1. All content from a group of performers"
        do { $contentSelection = read-host "Enter your selection (1)" }
        while (($contentSelection -notmatch "[1]"))

        # Load the scraper
        . "./apis/aylo/aylo-scraper.ps1"

        if ($contentSelection -eq 1) {
            # Next, user specifies performer IDs
            Write-Host `n"Specify all performer IDs you wish to download in a space-separated list, e.g. '123 2534 1563'."
            $performerIDs = read-host "Performer IDs"
            $performerIDs = $performerIDs -split (" ")
            $outputDir = ($scrapedDataDirectory + $directorydelimiter + "aylo")

            Set-AllContentDataByActorID -actorIDs $performerIDs -apiKey $userConfig.aylo.apiKey -authCode $userConfig.aylo.authCode -downloadDirectory $downloadDirectory -outputDir $outputDir -studioNames $studios

            # Load the downloader
            . "./apis/aylo/aylo-downloader.ps1"

            foreach ($studio in $studios) {
                foreach ($actorID in $performerIDs) {
                    # Get the JSON data for the actor to download
                    $actorJson = Join-Path $scrapedDataDirectory $apiName "actor" "$actorID.json"
                    if (!(Test-Path $actorJson)) {
                        return Write-Host "ERROR: Actor JSON not found - $actorJson." -ForegroundColor Red
                    }
                    $actorJson = Get-Content $actorJson -raw | ConvertFrom-Json

                    # Loop through all scraped scene data to find scenes the actor features in
                    $scenesFolder = Join-Path $scrapedDataDirectory $apiName $studio "scene"
                    if (!(Test-Path $scenesFolder)) {
                        return Write-Host "ERROR: Folder not found - $scenesFolder." -ForegroundColor Red
                    }

                    $actorScenes = @()
                    Get-ChildItem $scenesFolder -Filter *.json | Foreach-Object {
                        $sceneData = Get-Content $_ -raw | ConvertFrom-Json
                        if ($sceneData.actors.id -eq $actorJson.id) {
                            $actorScenes += $sceneData
                        }
                    }

                    # Loop through all scraped gallery data to find galleries the actor features in
                    $galleryFolder = Join-Path $scrapedDataDirectory $apiName $studio "gallery"
                    if (!(Test-Path $galleryFolder)) {
                        return Write-Host "ERROR: Folder not found - $galleryFolder." -ForegroundColor Red
                    }

                    $actorGalleries = @()
                    Get-ChildItem $galleryFolder -Filter *.json | Foreach-Object {
                        $galleryData = Get-Content $_ -raw | ConvertFrom-Json
                        if ($galleryData.parent.actors.id -eq $actorJson.id) {
                            $actorGalleries += $galleryData
                        }
                    }
       
                    foreach ($sceneData in $actorScenes) {
                        $studioName = $sceneData.collections[0].name
                        if ($null -eq $studioName) { $studioName = $studio }
                        Write-Host `n"Downloading $studio scene $($sceneData.id) - $studioName - $($sceneData.title)" -ForegroundColor Cyan
                        # Get the gallery data for the specific scene
                        $galleryID = ($sceneData.children | Where-Object { $_.type -eq "gallery" }).id
                        $galleryData = $actorGalleries | Where-Object { $_.id -eq $galleryID }
                        if ($galleryData.count -eq 0) {
                            Write-Host "WARNING: No gallery data found for scene $($sceneData.id)" -ForegroundColor Yellow
                        }
        
                        Get-AllSceneMedia -galleryData $galleryData -outputDir $downloadDirectory -sceneData $sceneData
                    }
                }
            }
        }

    }
    
    else { Write-Host "This feature is awaiting development." }
}

Set-Entry