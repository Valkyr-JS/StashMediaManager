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
$apiOptions = ("Aylo")

# Load the entrypoint for the script.
function Set-Entry {
    Clear-Host
    Write-Host "Stash Media Manager"
    Write-Host "-------------------"

    # User first selects an API
    Write-Host "What API are you working with?"
    $apicounter = 1
    foreach ($op in $apiOptions) {
        Write-Host "$apicounter. $op";
        $apicounter++
    }

    do { $apiSelection = read-host "Enter your selection (1)" }
    while (($apiSelection -notmatch "[1-$apicounter]"))

    Write-Host `n"WARNING: Please make sure your auth code is up to date in your config before you continue, as it cannot be set as part of this script." -ForegroundColor Yellow

    # Next, user selects an operation
    Write-Host `n"What would you like to do?"
    Write-Host "1. Download media"
    Write-Host "2. Update Stash"
    do { $operationSelection = read-host "Enter your selection (1-2)" }
    while (($operationSelection -notmatch "[1-2]"))

    if ($operationSelection -eq 1 -and $apiSelection -eq 1) {
        # Update the config if needed
        if ($userConfig.aylo.apiKey.Length -eq 0) {
            . "./config-management.ps1"
            $userConfig = Set-ConfigAyloApikey -pathToUserConfig $pathToUserConfig
        }

        # Next, user specifies what to download
        Write-Host `n"What content do you want to download?"
        Write-Host "1. All content from a group of performers"
        do { $contentSelection = read-host "Enter your selection (1)" }
        while (($contentSelection -notmatch "[1]"))

        # Ask whether to force scraping gallery data
        Write-Host `n"Should gallery data be scraped if it already exists? This may take some time."
        do { $forceGalleryScrape = read-host "Enter your selection (y/N)" }
        while (($forceGalleryScrape -notmatch "[yn]"))

        # Load the scraper
        . "./apis/aylo/aylo-scraper.ps1"

        if ($contentSelection -eq 1) {
            # Next, user specifies performer IDs
            Write-Host `n"Specify all performer IDs you wish to download in a space-separated list, e.g. '123 2534 1563'."
            $performerIDs = read-host "Performer IDs"
            $performerIDs = $performerIDs -split (" ")
            $forceGalleryScrape = $forceGalleryScrape -eq "y"

            Set-StudioData -actorIds $performerIDs -apiKey $userConfig.aylo.apiKey -authCode $userConfig.aylo.authCode -studio "brazzers" -ContentTypes ("actor", "scene", "gallery") -forceGalleryScrape $forceGalleryScrape -outputDir "./apis/aylo/data"

            # Load the downloader
            . "./apis/aylo/aylo-downloader.ps1"
            
            # Gallery data is all in one big file. Get it now and filter as needed.
            $allGalleriesJSON = Get-Content "./apis/aylo/data/brazzers/gallery.json" -raw | ConvertFrom-Json

            foreach ($perfid in $performerIDs) {
                $scenesJSON = Get-Content "./apis/aylo/data/brazzers/$perfid/scene.json" -raw | ConvertFrom-Json

                # Filter the galleries that the performer appears in
                $galleriesJSON = $allGalleriesJSON | Where-Object { $_.parent.actors.id -eq $perfid }

                foreach ($sceneData in $scenesJSON) {
                    # Get the gallery data for the specific scene
                    $galleryData = $galleriesJSON | Where-Object { $_.parent.id -eq $sceneData.id }

                    Get-AllSceneMedia -galleryData $galleryData -outputDir "J:\Synapse\Downloads" -sceneData $sceneData
                }
            }
        }

    }
    
    else { Write-Host "This feature is awaiting development." }
}

Set-Entry