$login = [PSCustomObject]@{
    "password" = ""
    "url"      = ""
    "username" = ""
}

$headers = @{
    "authorization" = $null
    "dnt"           = "1"
    "instance"      = $null
}

# Set the login details for an Aylo site
function Set-AyloLoginDetails {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Boolean]$setLoginUrl = $false
    )

    do { $ayloUsername = read-host "Enter your Aylo username" }
    while ($ayloUsername.Length -eq 0)
    $login.username = $ayloUsername

    do { $ayloPassword = read-host "Enter your Aylo password - THIS WILL BE SHOWN ON YOUR SCREEN" }
    while ($ayloPassword.Length -eq 0)
    $login.password = $ayloPassword

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    if ($setLoginUrl -or ($userConfig.aylo.masterSite.Length -eq 0)) {
        Set-ConfigAyloMasterSite -pathToUserConfig $pathToUserConfig
        $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    }
    $login.url = "https://site-ma.$($userConfig.aylo.masterSite).com/login"
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
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json

    # Set login details if required. Login details should be entered at the
    # start of every session and cleared at the very end.
    if (($login.username.Length -eq 0) -or
    ($login.password.Length -eq 0) -or
    ($login.url.Length -eq 0)) {
        do {
            Set-AyloLoginDetails -pathToUserConfig $pathToUserConfig -setLoginUrl ($userConfig.aylo.masterSite.Length -eq 0)
        }
        while (
            ($login.username.Length -eq 0) -or
            ($login.password.Length -eq 0) -or
            ($login.url.Length -eq 0)
        )
    }

    # Open Firefox
    $Driver = Start-SeFirefox -PrivateBrowsing
    Enter-SeUrl $login.url -Driver $Driver

    # Username
    $usernameInput = Find-SeElement -Driver $Driver -CssSelector "input[type=text][name=username]"
    Send-SeKeys -Element $usernameInput -Keys $login.username

    # Password
    $passwordInput = Find-SeElement -Driver $Driver -CssSelector "input[type=password][name=password]"
    Send-SeKeys -Element $passwordInput -Keys $login.password

    # Click login
    $loginBtn = Find-SeElement -Driver $Driver -CssSelector "button[type=submit]"
    Invoke-SeClick -Element $loginBtn
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
    
    $header = Get-AyloHeaders -pathToUserConfig $pathToUserConfig
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
        # If initial scrape fails, try fetching new auth keys
        Write-Host "WARNING: Scene scrape failed. Attempting to fetch new auth keys." -ForegroundColor Yellow
        Set-AyloHeaders -pathToUserConfig $pathToUserConfig
        $params = Set-AyloQueryParameters -actorID $actorID -apiType $apiType -id $contentID -offset $offset -parentId $parentId -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig

        # Retry scrape once with new keys
        try { $result = Invoke-RestMethod @params }
        catch {
            Write-Host "ERROR: $contentType scrape failed." -ForegroundColor Red
            return Write-Host "$_" -ForegroundColor Red
        }
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

    Write-Host `n"Starting scrape for actor #$actorID." -ForegroundColor Cyan
    
    # Attempt to scrape actor data
    $actorResult = Get-AyloQueryData -apiType "actor" -contentID $actorID -pathToUserConfig $pathToUserConfig
    $actorResult = $actorResult.result[0]

    # Output the actor JSON file
    $actorName = Get-SanitizedTitle -title $actorResult.name
    $filename = "$actorID $actorName.json"
    $outputDir = Join-Path $userConfig.general.scrapedDataDirectory "aylo" "actor"
    if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
    $outputDest = Join-Path $outputDir $filename
    $actorResult | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest

    if (!(Test-Path $outputDest)) {
        Write-Host "ERROR: actor JSON generation failed - $outputDest" -ForegroundColor Red
        return $null
    }  
    else {
        Write-Host "SUCCESS: actor JSON generated - $outputDest" -ForegroundColor Green
        return $outputDest
    }  
}

# Get data for a piece of content
function Get-AyloJson {
    param (
        [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
        [Parameter(Mandatory)][Int]$contentID,
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    Write-Host `n"Starting scrape for $apiType #$contentID." -ForegroundColor Cyan

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json

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
    $contentDir = Join-Path $userConfig.general.downloadDirectory $subDir

    # Skip creating JSON if the downloaded content already exists
    if (Test-Path -LiteralPath $contentDir) {
        $contentFile = Get-ChildItem $contentDir | Where-Object { $_.BaseName -match "^$contentID\s" }
        if ($contentFile.Length -gt 0) {
            Write-Host "Media already exists. Skipping JSON generation for $apiType #$contentID."

            # Return the path to the existing JSON file
            $title = Get-SanitizedTitle -title $result.title
            $filename = "$contentID $title.json"
            $pathToExistingJson = Join-Path $userConfig.general.scrapedDataDirectory $subDir $filename
            return $pathToExistingJson
        }
    }

    # Output the JSON file
    $title = Get-SanitizedTitle -title $result.title
    $filename = "$contentID $title.json"
    $outputDir = Join-Path $userConfig.general.scrapedDataDirectory $subDir
    if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
    $outputDest = Join-Path $outputDir $filename

    Write-Host "Generating JSON: $filename"
    $result | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest

    if (!(Test-Path $outputDest)) {
        Write-Host "ERROR: $apiType JSON generation failed - $outputDest" -ForegroundColor Red
        return $null
    }  
    else {
        Write-Host "SUCCESS: $apiType JSON generated - $outputDest" -ForegroundColor Green
        return $outputDest
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
