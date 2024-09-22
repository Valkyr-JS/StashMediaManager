. "../../config-management.ps1"

$pathToUserConfig = "../../config.dev.json"
$userConfig = Get-Content -Raw $pathToUserConfig | ConvertFrom-Json

$login = [PSCustomObject]@{
    "password" = ""
    "username" = ""
    "url"      = "https://site-ma.$($userConfig.aylo.masterSite).com/login"
}

$headers = @{
    "authorization" = $null
    "dnt"           = "1"
    "instance"      = $null
}

# Set the login details for an Aylo site
function Set-AyloLoginDetails {
    param(
        [Boolean]$setLoginUrl = $false
    )

    do { $ayloUsername = read-host "Enter your Aylo username" }
    while ($ayloUsername.Length -eq 0)
    $login.username = $ayloUsername

    do { $ayloPassword = read-host "Enter your Aylo password - THIS WILL BE SHOWN ON YOUR SCREEN" }
    while ($ayloPassword.Length -eq 0)
    $login.password = $ayloPassword

    if ($setLoginUrl) {
        Set-ConfigAyloMasterSite -pathToUserConfig $pathToUserConfig
    }
}

# Get headers for an Aylo web request
function Get-AyloHeaders {
    return $headers
}

# Set the data required for headers in an Aylo web request
function Set-AyloHeaders {
    # Set login details if required. Login details should be entered at the
    # start of every session and cleared at the very end.
    do {
        Set-AyloLoginDetails -setLoginUrl ($userConfig.aylo.masterSite.Length -eq 0)
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
    Find-SeElement -Driver $Driver -Wait -Timeout 15 -Id "root"

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
        [Int]$id,
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
    }
    else {
        $urlapi = "https://site-api.project1service.com/v2/releases"
        $body.Add("orderBy", "-dateReleased")
        $body.Add('type', $apiType)
        $body.Add('brand', $parentStudio)
        $body.Add('id', $id)
    }
    
    $params = @{
        "Uri"     = $urlapi
        "Body"    = $body
        "Headers" = $header
    }
    return $params
}



# Get data for all content related to the given Aylo scene
function Get-AyloSceneData {
    $results = New-Object -TypeName System.Collections.ArrayList

    # Attempt to scrape data
    $params = Set-AyloQueryParameters -apiType "scene" -id 10409621 -parentStudio "brazzers"
    try {
        $scenes = Invoke-RestMethod @params 
    }
    catch {
        # If initial scrape fails, try fetching new auth keys
        Write-Host "WARNING: $contentType scrape failed. Attempting to fetch new auth keys" -ForegroundColor Yellow
        Set-AyloHeaders
        $params = Set-AyloQueryParameters -apiType "scene" -id 10409621 -parentStudio "brazzers"

        # Retry scrape once with new keys
        try {
            $scenes = Invoke-RestMethod @params 
        }
        catch {
            Write-Host "ERROR: $contentType scrape failed." -ForegroundColor Red
            Write-Host "$_" -ForegroundColor Red
        }
    }
    
    $results.AddRange($scenes.result)

    $results | ConvertTo-Json -Depth 32 | Out-File -FilePath "$($userConfig.general.scrapedDataDirectory)/results.json"
    Write-Host $results
}