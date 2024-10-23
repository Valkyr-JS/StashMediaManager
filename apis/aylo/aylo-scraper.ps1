$headers = @{
    "authorization" = $null
    "dnt"           = "1"
    "instance"      = $null
}

# Get headers for an Aylo web request
function Get-AyloHeaders {
    return $headers
}

# Set the data required for headers in an Aylo web request
function Set-AyloHeaders {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    Write-Host `n"Please login to the master site in the new browser window, then wait until it closes automatically." -ForegroundColor Cyan

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    if ($userConfig.aylo.masterSite.Length -eq 0) {
        Set-ConfigAyloMasterSite -pathToUserConfig $pathToUserConfig
        $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    }
    $loginUrl = "https://site-ma.$($userConfig.aylo.masterSite).com/login"

    # Open Firefox then wait for the user to login
    $Driver = Start-SeFirefox -PrivateBrowsing
    Enter-SeUrl $loginUrl -Driver $Driver
    Find-SeElement -Driver $Driver -Wait -By XPath "//*[text()='Continue to Members Area']"

    # Get new page content
    $html = $Driver.PageSource
    $groups = $html | Select-String -Pattern "window.__JUAN.initialState\s+=\s(.+);"
    $keys = $groups.Matches.groups[1].Value | ConvertFrom-Json -AsHashtable
    $headers.authorization = $keys.client.authToken

    $groups = $html | Select-String -Pattern "window.__JUAN.rawInstance\s+=\s(.+);"
    $keys = $groups.Matches.groups[1].Value | ConvertFrom-Json -AsHashtable
    $headers.instance = $keys.jwt

    # Close the browser
    $Driver.Close()
}

# Set the query parameters for the web request
function Set-AyloQueryParameters {
    param (
        [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Int]$actorID,
        [Int]$id,
        [Int]$parentId,
        [string]$parentStudio,
        [Int]$offset
    )
    
    $header = Get-AyloHeaders
    $body = @{
        limit  = 100
        offset = $offset
    }

    # The API call for actors is different from other content types
    if ($apiType -eq "actor") {
        $urlapi = "https://site-api.project1service.com/v1/actors"
        $body.Add('id', $id)
    }
    else {
        $urlapi = "https://site-api.project1service.com/v2/releases"
        $body.Add("orderBy", "-dateReleased")
        $body.Add('type', $apiType)

        # Allow all unlocked sites to be queried
        $body.Add("groupFilter", "unlocked")

        if ($actorID) { $body.Add('actorId', $actorID) }
        if ($id) { $body.Add('id', $id) }
        if ($parentId) { $body.Add('parentId', $parentId) }
        if ($parentStudio) { $body.Add('brand', $parentStudio) }
    }
    
    $params = @{
        "Uri"     = $urlapi
        "Body"    = $body
        "Headers" = $header
    }
    return $params
}


# Attempt to fetch the given data from the Aylo API
function Get-AyloQueryData {
    param(
        [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Int]$actorID,
        [Int]$contentID,
        [Int]$offset,
        [Int]$parentId,
        [string]$parentStudio
    )

    $params = Set-AyloQueryParameters -actorID $actorID -apiType $apiType -id $contentID -offset $offset -parentId $parentId -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig

    if (($null -eq $headers.authorization) -or ($null -eq $headers.instance)) {
        Set-AyloHeaders -pathToUserConfig $pathToUserConfig
    }

    try { $result = Invoke-RestMethod @params }
    catch {
        Write-Host "WARNING: $apiType scrape failed." -ForegroundColor Red
        Write-Host "$_" -ForegroundColor Red
        exit
    }

    return $result
}

# Get data for all content related to the given Aylo actor and output it to a JSON file
function Get-AyloActorJson {
    param (
        [Parameter(Mandatory)][Int]$actorID,
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $dataDir = $userConfig.general.dataDirectory
    $dataDownloadDir = $userConfig.general.dataDownloadDirectory
    $subDir = Join-Path "aylo" "actor"

    Write-Host "Scraping actor #$actorID."
    
    # Attempt to scrape actor data
    $actorResult = Get-AyloQueryData -apiType "actor" -contentID $actorID -pathToUserConfig $pathToUserConfig
    $actorResult = $actorResult.result[0]

    # Skip creating JSON if it already exists
    $existingJson = $null
    foreach ($dir in @($dataDir, $dataDownloadDir)) {
        $testPath = Join-Path $dir $subDir
        if (Test-Path -LiteralPath $testPath) {
            $filename = Get-ChildItem -LiteralPath $testPath | Where-Object { $_.BaseName -match "^$actorID\s" }
            if ($null -ne $filename -and (Test-Path -LiteralPath $filename.FullName)) {
                $existingJson = $filename.FullName
                break;
            }
        }
    }

    if ($null -eq $existingJson) {
        # Output the actor JSON file
        $actorName = Get-SanitizedFilename -title $actorResult.name
        $filename = "$actorID $actorName.json"
        $outputDir = Join-Path $dataDownloadDirectory $subDir
        if (!(Test-Path -LiteralPath $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        $outputDest = Join-Path $outputDir $filename
        $actorResult | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest

        if (!(Test-Path -LiteralPath $outputDest)) {
            Write-Host "ERROR: actor JSON generation failed - $outputDest" -ForegroundColor Red
            return $null
        }  
        else {
            Write-Host "SUCCESS: actor JSON generated - $outputDest" -ForegroundColor Green
            return $outputDest
        }  
    }
    else {
        Write-Host "JSON already exists at $($existingJson). Skipping JSON generation for actor #$actorID."
        return $existingJson
    }

}

# Get data for a piece of content
function Get-AyloJson {
    param (
        [Parameter(Mandatory)][ValidateSet('gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
        [Parameter(Mandatory)][Int]$contentID,
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    Write-Host `n"Starting scrape for $apiType #$contentID." -ForegroundColor Cyan

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $contentDir = $userConfig.general.contentDirectory
    $contentDownloadDir = $userConfig.general.contentDownloadDirectory
    $dataDir = $userConfig.general.dataDirectory
    $dataDownloadDir = $userConfig.general.dataDownloadDirectory

    if ($apiType -eq "trailer") {
        $contentDir = $userConfig.general.assetsDirectory
        $contentDownloadDir = $userConfig.general.assetsDownloadDirectory
    }

    # Attempt to scrape content data
    $result = Get-AyloQueryData -apiType $apiType -contentID $contentID -pathToUserConfig $pathToUserConfig
    if ($result.meta.count -eq 0) {
        Write-Host "No $apiType found with ID $contentID." -ForegroundColor Red
    }

    $result = $result.result[0]
    $parentStudio = $result.brandMeta.displayName
    if ($result.collections.count -gt 0) { $studio = $result.collections[0].name }
    else { $studio = $parentStudio }
    $subDir = Join-Path "aylo" $apiType $parentStudio $studio

    # Skip creating JSON if both the JSON and the content already exist in either directory
    $existingPath = $null
    $existingJson = $null
    foreach ($dir in @($contentDir, $contentDownloadDir)) {
        $testPath = Join-Path $dir $subDir
        if (Test-Path -LiteralPath $testPath) {
            $filename = Get-ChildItem -LiteralPath $testPath | Where-Object { $_.BaseName -match "^$contentID\s" }
            if ($null -ne $filename -and (Test-Path -LiteralPath $filename.FullName)) {
                # Check the associated JSON also exists
                foreach ($dDir in @($dataDir, $dataDownloadDir)) {
                    $dataTestPath = Join-Path $dDir $subDir
                    if (Test-Path -LiteralPath $dataTestPath) {
                        $jsonFilename = Get-ChildItem -LiteralPath $dataTestPath | Where-Object { $_.BaseName -match "^$contentID\s" }
                        if ($null -ne $jsonFilename -and (Test-Path -LiteralPath $jsonFilename.FullName)) {
                            # Check the file exists in the directory
                            $existingPath = $filename.FullName
                            $existingJson = $jsonFilename.FullName
                        }
                    }
                }
            }
        }
    }

    if ($null -eq $existingPath -or $null -eq $existingJson) {
        # Output the JSON file
        $title = Get-SanitizedFilename -title $result.title
        $filename = "$contentID $title.json"
        $outputDir = Join-Path $userConfig.general.dataDownloadDirectory $subDir
        if (!(Test-Path -LiteralPath $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        $outputDest = Join-Path $outputDir $filename

        Write-Host "Generating JSON: $filename"
        $result | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest

        if (!(Test-Path -LiteralPath $outputDest)) {
            Write-Host "ERROR: $apiType JSON generation failed - $outputDest" -ForegroundColor Red
            return $null
        }  
        else {
            Write-Host "SUCCESS: $apiType JSON generated - $outputDest" -ForegroundColor Green
            return $outputDest
        }  
    }
    else {
        Write-Host "Media already exists at $($existingPath). Skipping JSON generation for $apiType #$contentID."
        return $existingJson
    }
}

# Get data for content related to the given Aylo gallery and output it to a JSON
# file. Returns the path to the JSON file.
function Get-AyloGalleryJson {
    param (
        [Parameter(Mandatory)][Int]$galleryID,
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    Get-AyloJson -apiType "gallery" -contentID $galleryID -pathToUserConfig $pathToUserConfig
}

# Get data for content related to the given Aylo scene and output it to a JSON
# file. Returns the path to the JSON file.
function Get-AyloSceneJson {
    param (
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int]$sceneID
    )
    Get-AyloJson -apiType "scene" -contentID $sceneID -pathToUserConfig $pathToUserConfig
}

# Get data for content related to the given Aylo series and output it to a JSON
# file. Returns the path to the JSON file.
function Get-AyloSeriesJson {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int]$seriesID
    )
    Get-AyloJson -apiType "serie" -contentID $seriesID -pathToUserConfig $pathToUserConfig
}

# Get data for content related to the given Aylo trailer and output it to a JSON
# file. Returns the path to the JSON file.
function Get-AyloTrailerJson {
    param (
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int]$trailerID
    )
    Get-AyloJson -apiType "trailer" -contentID $trailerID -pathToUserConfig $pathToUserConfig
}

# Get data for all content related to the given Aylo scene and output it to JSON
# files. Returns the path to the scene JSON file.
function Get-AyloAllJson {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int]$sceneID
    )
    # Generate the scene JSON first, and use it to create the rest
    $pathToSceneJson = Get-AyloSceneJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
    $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json

    # Galleries
    [array]$galleries = $sceneData.children | Where-Object { $_.type -eq "gallery" }
    foreach ($gID in $galleries.id) {
        $null = Get-AyloGalleryJson -pathToUserConfig $pathToUserConfig -galleryID $gID
    }

    # Trailers
    [array]$trailers = $sceneData.children | Where-Object { $_.type -eq "trailer" }
    foreach ($tID in $trailers.id) {
        $null = Get-AyloTrailerJson -pathToUserConfig $pathToUserConfig -trailerID $tID
    }

    # Actors
    Write-Host `n"Starting scrape for actors in scene #$sceneID." -ForegroundColor Cyan
    foreach ($aID in $sceneData.actors.id) {
        $null = Get-AyloActorJson -actorID $aID -pathToUserConfig $pathToUserConfig
    }
    
    # Series
    if ($sceneData.parent -and $sceneData.parent.type -eq "serie") {
        $pathToSeriesJson = Get-AyloSeriesJson -pathToUserConfig $pathToUserConfig -seriesID $sceneData.parent.id
        $seriesData = Get-Content $pathToSeriesJson -raw | ConvertFrom-Json
        
        # Series galleries
        [array]$galleries = $seriesData.children | Where-Object { $_.type -eq "gallery" }
        foreach ($gID in $galleries.id) {
            $null = Get-AyloGalleryJson -pathToUserConfig $pathToUserConfig -galleryID $gID
        }

        # Series trailers
        [array]$trailers = $seriesData.children | Where-Object { $_.type -eq "trailer" }
        foreach ($tID in $trailers.id) {
            $null = Get-AyloTrailerJson -pathToUserConfig $pathToUserConfig -trailerID $tID
        }
    }
    return $pathToSceneJson
}

# ---------------------------- Get scene IDs by... --------------------------- #

# Get IDs for scenes featuring the provided actor's ID
function Get-AyloSceneIDsByActorID {
    param (
        [Parameter(Mandatory)][Int]$actorID,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [String]$parentStudio
    )

    Write-Host `n"Searching for scenes featuring actor ID $actorID." -ForegroundColor Cyan

    $results = Get-AyloQueryData -apiType "scene" -actorID $actorID -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig
    
    if ($results.meta.count -eq 0) {
        Write-Host "No scenes found with the provided actor ID $actorID." -ForegroundColor Red
    }
    else {
        if ($results.meta.count -eq 1) { $sceneWord = "scene" }
        else { $sceneWord = "scenes" }
        Write-Host "$($results.meta.count) $sceneWord found featuring actor ID $actorID."
    }

    $sceneIDs = @()
    foreach ($scene in $results.result) {
        $sceneIDs += $scene.id
    }
    return $sceneIDs
}


# Get IDs for scenes featured in the provided series ID
function Get-AyloSceneIDsBySeriesID {
    param (
        [Parameter(Mandatory)][Int]$seriesID,
        [Parameter(Mandatory)][String]$pathToUserConfig
    )

    Write-Host `n"Searching for scenes featured in series ID $seriesID." -ForegroundColor Cyan

    $results = Get-AyloQueryData -apiType "scene" -parentId $seriesID -pathToUserConfig $pathToUserConfig
    
    if ($results.meta.count -eq 0) {
        Write-Host "No scenes found with the provided series ID $seriesID." -ForegroundColor Red
    }
    else {
        if ($results.meta.count -eq 1) { $sceneWord = "scene" }
        else { $sceneWord = "scenes" }
        Write-Host "$($results.meta.count) $sceneWord found featuring series ID $seriesID."
    }

    $sceneIDs = @()
    foreach ($scene in $results.result) {
        $sceneIDs += $scene.id
    }
    return $sceneIDs
}
