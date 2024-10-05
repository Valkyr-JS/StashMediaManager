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
        [Parameter(Mandatory)][ValidateSet('getVideo', 'get-tags', 'model-archive', 'user-init')][String]$apiType,
        [String]$id,
        [String]$slug
    )

    $headers = Get-AFHeaders
    $urlapi = "https://addfriends.com/vip/actions/$apiType.php"
    $body = @{}

    if ($apiType -eq "getVideo") { $body.Add("v", $id) }
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
        [Parameter(Mandatory)][ValidateSet('getVideo', 'get-tags', 'model-archive', 'user-init')][String]$apiType,
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
        [Parameter(Mandatory)][String]$slug
    )
    Write-Host `n"Starting scrape for site addfriends.com/vip/$slug" -ForegroundColor Cyan

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $result = Get-AFQueryData -apiType "model-archive" -slug $slug
    $subDir = Join-Path "addfriends" "model-archive" $slug

    if ($result) {
        # Output the JSON file
        $title = Get-SanitizedTitle -title $result.site.site_name
        $date = Get-Date -Format "yyyy-MM-dd"
        $filename = "$($result.site.id) $title $date.json"
        $outputDir = Join-Path $userConfig.general.scrapedDataDirectory $subDir
        if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        $outputDest = Join-Path $outputDir $filename
        if (Test-Path $outputDest) { 
            Write-Host "Site data already generated for today. Skipping."
            return $null
        }

        Write-Host "Generating site JSON: $filename"
        $result | ConvertTo-Json -Depth 32 | Out-File -FilePath $outputDest

        if (!(Test-Path $outputDest)) {
            Write-Host "ERROR: site JSON generation failed - $outputDest" -ForegroundColor Red
            return $null
        }  
        else {
            Write-Host "SUCCESS: site JSON generated - $outputDest" -ForegroundColor Green
            return $outputDest
        }  
    }
}