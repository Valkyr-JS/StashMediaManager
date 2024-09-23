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
    do {
        Set-AyloLoginDetails -pathToUserConfig $pathToUserConfig -setLoginUrl ($userConfig.aylo.masterSite.Length -eq 0)
    }
    while (
        ($login.username.Length -eq 0) -or
        ($login.password.Length -eq 0) -or
        ($login.url.Length -eq 0)
    )

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
    Find-SeElement -Driver $Driver -Wait -Timeout 8 -Id "root"

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
        [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene')][String]$apiType,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Int]$actorID,
        [Int]$id,
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

        if ($actorID) { $body.Add('actorId', $actorID) }
        if ($id) { $body.Add('id', $id) }
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
        [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene')][String]$apiType,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Int]$actorID,
        [Int]$contentID,
        [Int]$offset,
        [string]$parentStudio
    )

    $params = Set-AyloQueryParameters -actorID $actorID -apiType $apiType -id $contentID -offset $offset -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig

    Write-Host $params.Body

    try { $result = Invoke-RestMethod @params }
    catch {
        # If initial scrape fails, try fetching new auth keys
        Write-Host "WARNING: Scene scrape failed. Attempting to fetch new auth keys." -ForegroundColor Yellow
        Set-AyloHeaders -pathToUserConfig $pathToUserConfig
        $params = Set-AyloQueryParameters -actorID $actorID -apiType $apiType -id $contentID -offset $offset -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig

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

    # Attempt to scrape actor data
    $actorResult = Get-AyloQueryData -apiType "actor" -contentID $actorID -pathToUserConfig $pathToUserConfig
    $actorResult = $actorResult.result[0]

    # Output the actor JSON file
    $actorName = Get-SanitizedTitle -title $actorResult.name
    $filename = "$actorID $actorName.json"
    $outputDir = Join-Path $userConfig.general.scrapedDataDirectory "aylo" "actors"
    if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
    $outputDest = Join-Path $outputDir $filename
    $actorResult | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest
}

# Get data for all content related to the given Aylo scene and output it to a JSON file
function Get-AyloSceneJson {
    param (
        [Parameter(Mandatory)][String]$parentStudio,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int]$sceneID
    )
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json

    # Attempt to scrape scene data
    $sceneResult = Get-AyloQueryData -apiType "scene" -contentID $sceneID -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig
    if ($sceneResult.meta.count -eq 0) {
        return Write-Host "No scene found with the provided ID $sceneID." -ForegroundColor Red
    }

    $sceneResult = $sceneResult.result[0]

    # Next fetch the gallery data
    $galleryID = $sceneResult.children | Where-Object { $_.type -eq "gallery" }
    $galleryID = $galleryID.id

    $galleryResult = Get-AyloQueryData -apiType "gallery" -contentID $galleryID -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig

    # If gallery data is found, merge it into the scene data
    if ($galleryResult.meta.count -eq 0) {
        Write-Host "No gallery found with the provided ID $galleryID." -ForegroundColor Yellow
    }
    else {
        $galleryResult = $galleryResult.result[0]

        # Remove duplicate data to reduce file size
        $galleryResult.PSObject.Properties.Remove("brand")
        $galleryResult.PSObject.Properties.Remove("brandMeta")
        $galleryResult.PSObject.Properties.Remove("parent")
    
        for ($i = 0; $i -lt $sceneResult.children.count; $i++) {
            if ($sceneResult.children[$i].type -eq "gallery") {
                $sceneResult.children[$i] = $galleryResult
            }
        }
    }

    # Scrape actors data into separate files if required.
    foreach ($actor in $sceneResult.actors) {
        Get-AyloActorJson -actorID $actor.id -pathToUserConfig $pathToUserConfig
    }

    # Output the scene JSON file
    $sceneTitle = Get-SanitizedTitle -title $sceneResult.title
    $filename = "$sceneID $sceneTitle.json"
    $outputDir = Join-Path $userConfig.general.scrapedDataDirectory "aylo" "scenes" $parentStudio
    if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
    $outputDest = Join-Path $outputDir $filename
    $sceneResult | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest
}

# ---------------------------- Get scene IDs by... --------------------------- #

# Get IDs for scene featuring the provided actor's ID
function Get-AyloSceneIDsByActorID {
    param (
        [Parameter(Mandatory)][Int]$actorID,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [String]$parentStudio
    )

    $results = Get-AyloQueryData -apiType "scene" -actorID $actorID -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig
    
    if ($results.meta.count -eq 0) {
        Write-Host "No scenes found with the provided actor ID $actorID." -ForegroundColor Red
    }

    $sceneIDs = @()
    foreach ($scene in $results.result) {
        $sceneIDs += $scene.id
    }
    return $sceneIDs
}
