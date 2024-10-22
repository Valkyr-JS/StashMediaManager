$headers = @{
    "Cookie" = $null
}

# Get headers for an AF web request
function Get-AFHeaders {
    return $headers
}

# Set the data required for headers in an AF web request
function Set-AFHeaders {
    Write-Host `n"Please enter your 'nvgn_auth' key, found under 'Cookie' in a logged-in request header." -ForegroundColor Cyan
    
    do { $auth = Read-Host "nvgn_auth=" }
    while ($auth.Length -eq 0)

    $headers.Cookie = "nvgn_auth=$auth"
}

# Set the query parameters for the web request
function Set-AFQueryParameters {
    param (
        [Parameter(Mandatory)][ValidateSet('getvideo', 'get-tags', 'model-archive', 'user-init')][String]$apiType,
        [String]$id,
        [String]$slug
    )

    $headers = Get-AFHeaders
    $urlapi = "https://addfriends.com/vip/actions/$apiType.php"
    $body = @{}

    if ($apiType -eq "getvideo") { $body.Add("v", $id) }
    if ($apiType -eq "get-tags") { $body.Add("v", $id) }
    if ($apiType -eq "model-archive") { $body.Add("site", $slug) }

    $params = @{
        "Uri"     = $urlapi
        "Headers" = $headers
        "Body"    = $body
    }

    return $params
}


# Attempt to fetch the given data from the AF API
function Get-AFQueryData {
    param(
        [Parameter(Mandatory)][ValidateSet('getvideo', 'get-tags', 'model-archive', 'user-init')][String]$apiType,
        [String]$id,
        [String]$slug
    )

    $params = Set-AFQueryParameters -apiType $apiType -id $id -slug $slug

    if ($null -eq $headers.cookie) { Set-AFHeaders }

    try { $result = Invoke-RestMethod @params }
    catch {
        Write-Host "WARNING: Scene scrape failed." -ForegroundColor Yellow
        Write-Host "$_"
        exit
    }

    return $result
}

# Fetch the AF model-archive data to use as site data.
function Get-AFModelSiteJson {
    param (
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$siteName,
        [Parameter(Mandatory)][String]$slug
    )
    Write-Host `n"Starting scrape for site addfriends.com/vip/$slug" -ForegroundColor Cyan

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $result = Get-AFQueryData -apiType "model-archive" -slug $slug
    $subDir = Join-Path "addfriends" "model-archive" $siteName

    if ($result) {
        # Output the JSON file
        $title = Get-SanitizedTitle -title $result.site.site_name
        $date = Get-Date -Format "yyyy-MM-dd"
        $filename = "$($result.site.id) $title $date.json"
        $outputDir = Join-Path $userConfig.general.dataDownloadDirectory $subDir
        if (!(Test-Path -LiteralPath $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        $outputDest = Join-Path $outputDir $filename
        if (Test-Path -LiteralPath $outputDest) { 
            Write-Host "Site data already generated for today. Skipping."
            return $outputDest
        }

        Write-Host "Generating site JSON: $filename"
        $result | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest

        if (!(Test-Path -LiteralPath $outputDest)) {
            Write-Host "ERROR: site JSON generation failed - $outputDest" -ForegroundColor Red
            return $null
        }  
        else {
            Write-Host "SUCCESS: site JSON generated - $outputDest" -ForegroundColor Green
            return $outputDest
        }  
    }
}

function Get-AFSceneJson {
    param (
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$sceneID,
        [Parameter(Mandatory)][String]$siteName
    )

    Write-Host `n"Starting scrape for scene #$sceneID" -ForegroundColor Cyan
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json

    # First scrape the video data
    $video = Get-AFQueryData -apiType "getvideo" -id $sceneID

    # Skip creating JSON if the content already exists in either the download or
    # storage directory
    $topDirs = @($userConfig.general.contentDownloadDirectory, $userConfig.general.contentDirectory)
    $subDir = Join-Path "addfriends" "video" $siteName

    foreach ($topDir in $topDirs) {
        $contentDir = Join-Path $topDir $subDir
        
        # Skip creating JSON if the content already exists
        if (Test-Path -LiteralPath $contentDir) {
            $contentFile = Get-ChildItem $contentDir | Where-Object { $_.BaseName -match "^$sceneID\s" }
            if ($contentFile.Length -gt 0) {
                Write-Host "Media already exists at $($contentFile.FullName). Skipping JSON generation for scene #$sceneID."

                # Return the path to the existing JSON file
                $title = Get-SanitizedTitle -title $video.title
                $filename = "$($video.id) $title.json"
                $pathToExistingJson = Join-Path $userConfig.general.dataDownloadDirectory $subDir $filename
                return $pathToExistingJson
            }
        }
    }

    if ($video) {
        # Output the JSON file
        $filename = Set-MediaFilename -mediaType "data" -extension "json" -id $video.id -title $video.title -siteName $siteName -date $video.released_date
        $outputDir = Join-Path $userConfig.general.dataDownloadDirectory $subDir
        if (!(Test-Path -LiteralPath $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        $videoDest = Join-Path $outputDir $filename
        
        Write-Host "Generating site JSON: $filename"
        $video | ConvertTo-Json -Depth 32 | Out-File -FilePath $videoDest
        
        if (!(Test-Path -LiteralPath $videoDest)) {
            Write-Host "ERROR: site JSON generation failed - $videoDest" -ForegroundColor Red
            return $null
        }  
                        
        # Next scrape the tags data
        $tags = Get-AFQueryData -apiType "get-tags" -id $sceneID

        if ($tags.success) {
            $subDir = Join-Path "addfriends" "tags" $siteName
            $outputDir = Join-Path $userConfig.general.dataDownloadDirectory $subDir
            if (!(Test-Path -LiteralPath $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
            $tagsDest = Join-Path $outputDir $filename
            $tags.success | ConvertTo-Json -Depth 32 | Out-File -FilePath $tagsDest
        }

        Write-Host "SUCCESS: site JSON generated - $videoDest" -ForegroundColor Green

        return $videoDest
    }
}