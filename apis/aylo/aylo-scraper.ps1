# Get headers to send a request to the Aylo site
function Get-Headers {
    param(
        [Parameter(Mandatory)][String]$apiKey,
        [Parameter(Mandatory)][String]$authCode,
        [Parameter(Mandatory)][string]$studioName
    )
    
    # Cannot execute without an API key.
    if ($apiKey.Length -eq 0) {
        Write-Host "ERROR: The Aylo API key has not been set. Please update your config." -ForegroundColor Red
        return
    }
      
    $useragent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36"
    $headers = @{
        "UserAgent" = "$useragent";
        "instance"  = "$apiKey";
    }
    
    # Only non-member data is available without an auth code.
    if ($authCode.Length -eq 0) {
        Write-Host "WARNING: No auth code provided. Scraping non-member data only." -ForegroundColor Yellow
    }
    
    else {
        $headers.authorization = "$authCode"
    }
    return $headers
}

# Set the query parameters for the web request
function Set-QueryParameters {
    param (
        [Parameter(Mandatory)][ValidateSet('actorID', 'id')][string]$method,
        [Parameter(Mandatory)][String]$apiKey,
        [Parameter(Mandatory)][String]$authCode,
        [Parameter(Mandatory)][string]$contentType,
        [Parameter(Mandatory)][string]$studioName,
        [Int]$actorID,
        [Int]$id,
        [Int]$offset
    )
    
    $header = Get-Headers -apiKey $apiKey -authCode $authCode -studioName $studioName
    $body = @{
        limit  = 100
        offset = $offset
    }

    # The API call for actors is different from other content types
    if ($contentType -eq "actor") {
        $urlapi = "https://site-api.project1service.com/v1/actors"
    }
    else {
        $urlapi = "https://site-api.project1service.com/v2/releases"
        $body.Add("orderBy", "-dateReleased")
        $body.Add('type', $contentType)
        $body.Add('brand', $studioName)
    }
    
    if ($method -eq "actorID") {
        $body.Add("actorId", $actorID)
    }
    elseif ($method -eq "id") {
        $body.Add("id", $id)
    }
    
    $params = @{
        "Uri"     = $urlapi
        "Body"    = $Body
        "Headers" = $header
    }
    return $params
}

# Get the number of pages the data is split into
function Get-MaxPages ($meta) {
    $limit = $meta.count
    if ($meta.count -eq 0) {
        return 0
    }
    $maxpage = $meta.total / $limit
    $maxpage = [Math]::Ceiling($maxpage)
    return $maxpage
}  

# Create the data JSON file for a single content item
function Set-ContentData {
    param(
        [Parameter(Mandatory)][string]$contentType,
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)]$result,
        [Parameter(Mandatory)][string]$studioName
    )

    # Create the file path
    $id = $result.id

    if ($contentType -eq "actor") {
        $filedir = Join-Path $outputDir $contentType
        $filename = "$id.json"
    }
    else {
        $filedir = Join-Path $outputDir $studioName $contentType
        $title = ($result.title.Split([IO.Path]::GetInvalidFileNameChars()) -join '')
        $title = $title.replace("  ", " ")
        $filename = "$id $title.json"
    }

    $filepath = Join-Path -Path $filedir -ChildPath $filename
    if (!(Test-Path $filedir)) { New-Item -ItemType "directory" -Path $filedir } 

    # Skip if data already exists
    if ((Test-Path $filepath)) { return Write-Host "Scraped data already exists. Skipping $filepath" } 

    Write-Host "Generating JSON: $filepath"
    $result | ConvertTo-Json -Depth 32 | Out-File -FilePath $filepath

    if (!(Test-Path $filedir)) { Write-Host "ERROR: JSON generation failed - $filepath" -ForegroundColor Red }  
    else { Write-Host "SUCCESS: JSON generated - $filepath" -ForegroundColor Green }  
}

# Get all gallery data items with an ID in a provided array
function Get-AllGalleryDataByID {
    param(
        [Parameter(Mandatory)][Int[]]$ids,
        [Parameter(Mandatory)][String]$apiKey,
        [Parameter(Mandatory)][String]$authCode,
        [Parameter(Mandatory)][string]$studioName
    )

    $results = New-Object -TypeName System.Collections.ArrayList
      
    for ($p = 0; $p -lt $ids.Length; $p++) {
        Write-Host "Scraping: gallery $($p + 1) of $($ids.Length)"
        $id = $ids[$p]
        $params = Set-QueryParameters -apiKey $apiKey -authCode $authCode -contentType "gallery" -id $id -method "id" -offset 0 -studioName $studioName
        try {
            $gallery = Invoke-RestMethod @params
        }
        catch {
            Write-Host "ERROR: gallery scrape failed." -ForegroundColor Red
            Write-Host "$_" -ForegroundColor Red
        }
        $results.AddRange($gallery.result)
    }
    return $results
}

# Get all data items featuring a provided actor
function Get-AllContentDataByActorID {
    param (
        [Parameter(Mandatory)][Int]$actorID,
        [Parameter(Mandatory)][String]$apiKey,
        [Parameter(Mandatory)][String]$authCode,
        [Parameter(Mandatory)][string]$contentType,
        [Parameter(Mandatory)][string]$studioName
    )

    $results = New-Object -TypeName System.Collections.ArrayList
    $params = Set-QueryParameters -actorID $actorID -apiKey $apiKey -authCode $authCode -contentType $contentType -method "actorID" -studioName $studioName
    try {
        $scenes0 = Invoke-RestMethod @params 
    }
    catch {
        Write-Host "ERROR: $contentType scrape failed." -ForegroundColor Red
        Write-Host "$_" -ForegroundColor Red
    }
    $limit = $scenes0.meta.count
    $maxpage = Get-MaxPages -meta $scenes0.meta
  
    if ($maxpage -eq 0) {
        Write-Host "No content found for this query." -ForegroundColor Yellow
        return $results
    }
  
    for ($p = 1; $p -le $maxpage; $p++) {
        $page = $p - 1
        Write-Host "Scraping: page $p of $maxpage" 
        $offset = $page * $limit
        $params = Set-QueryParameters -actorID $actorID -apiKey $apiKey -authCode $authCode -contentType $contentType -method "actorID" -offset $offset -studioName $studioName
        try {
            $scenes = Invoke-RestMethod @params
        }
        catch {
            Write-Host "ERROR: $contentType scrape failed." -ForegroundColor Red
            Write-Host "$_" -ForegroundColor Red
        }
        $results.AddRange($scenes.result)
    }
    return $results
}

# Create all data JSON files for content items featuring a provided actor
function Set-AllContentDataByActorID {
    param(
        [Parameter(Mandatory)][Int[]]$actorIDs,
        [Parameter(Mandatory)][String]$apiKey,
        [Parameter(Mandatory)][String]$authCode,
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)][string[]]$studioNames
    )
    $contentTypes = @('actor', 'scene')

    foreach ($actorID in $actorIDs) {
        foreach ($studioName in $studioNames) {
            $costarIDs = @()
            $galleryIDs = @()
            foreach ($contentType in $contentTypes) {
                Write-Host "Scraping actor $actorID : $studioName : $contentType"
                $results = Get-AllContentDataByActorID -actorID $actorID -apiKey $apiKey -authCode $authCode -contentType $contentType -studioName $studioName
        
                foreach ($result in $results) {
                    if ($contentType -eq "scene") {
                        # Get other actors from the scene scrape so they can be scraped later on
                        $costarIDs += $result.actors.id

                        # Get gallery IDs from the scene scrape so they can be scraped later on
                        $galleryData = $result.children | Where-Object { $_.type -eq "gallery" }
                        if ($galleryData.count -gt 0) {
                            $galleryIDs += $galleryData[0].id
                        }
                    }
    
                    Set-ContentData -contentType $contentType -outputDir $outputDir -result $result -studioName $studioName
                }
            }
            # Scrape costars after other content types have been completed
            if ($costarIDs.count -gt 0) {
                $costarIDs = $costarIDs | Select-Object -Unique
                foreach ($costarID in $costarIDs) {
                    $results = Get-AllContentDataByActorID -actorID $costarID -apiKey $apiKey -authCode $authCode -contentType "actor" -studioName $studioName
                    foreach ($result in $results) {
                        Set-ContentData -contentType "actor" -outputDir $outputDir -result $result -studioName $studioName
                    }
                }
            }

            # Scrape galleries after other content types have been completed
            if ($galleryIDs.count -gt 0) {
                $results = Get-AllGalleryDataByID -apiKey $apiKey -authCode $authCode -ids $galleryIDs -studioName $studioName
                foreach ($result in $results) {
                    Set-ContentData -contentType "gallery" -outputDir $outputDir -result $result -studioName $studioName
                }
            }
        }
    }
}
