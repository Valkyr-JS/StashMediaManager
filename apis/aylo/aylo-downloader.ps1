# Get all media associated with a given Aylo scene ID
function Get-AyloSceneAllMedia {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)]$sceneData
    )
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $assetsDir = $userConfig.general.assetsDirectory
    $dataDir = $userConfig.general.scrapedDataDirectory
    $downloadDir = $userConfig.general.downloadDirectory
    $storageDir = $userConfig.general.storageDirectory

    $parentStudio = $sceneData.brandMeta.displayName
    if ($sceneData.collections.count -gt 0) { $studio = $sceneData.collections[0].name }
    else { $studio = $parentStudio }
    
    Write-Host `n"Downloading all media for scene #$($sceneData.id) - $($sceneData.title)." -ForegroundColor Cyan

    function Get-AyloPath {
        param(
            [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
            [Parameter(Mandatory)][String]$root
        )
        return Join-Path $root "aylo" $apiType $parentStudio $studio
    }

    function Get-AyloSeriesPath {
        param(
            [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
            [Parameter(Mandatory)][String]$root,
            [Parameter(Mandatory)][String]$studio
        )
        return Join-Path $root "aylo" $apiType $parentStudio $studio
    }


    # Galleries
    [array]$galleries = $sceneData.children | Where-Object { $_.type -eq "gallery" }
    if ($galleries.count -eq 0) {
        Write-Host "No gallery available to download." -ForegroundColor Yellow
    }
    else {
        foreach ($gID in $galleries.id) {
            $pathToGalleryJson = Get-ChildItem (Get-AyloPath -apiType "gallery" -root $dataDir) | Where-Object { $_.BaseName -match "^$gID\s" }
            $galleryData = Get-Content $pathToGalleryJson -raw | ConvertFrom-Json
            $subDir = Join-Path "aylo" "gallery" $parentStudio $studio
            $null = Get-AyloSceneGallery -downloadDir $downloadDir -galleryData $galleryData -storageDir $storageDir -subDir $subDir
        }
    }

    # Trailers
    [array]$trailers = $sceneData.children | Where-Object { $_.type -eq "trailer" }
    if ($trailers.count -eq 0) {
        Write-Host "No trailer available to download." -ForegroundColor Yellow
    }
    else {
        foreach ($tID in $trailers.id) {
            $pathToTrailerJson = Get-ChildItem (Get-AyloPath -apiType "trailer" -root $dataDir) | Where-Object { $_.BaseName -match "^$tID\s" }
            $trailerData = Get-Content $pathToTrailerJson -raw | ConvertFrom-Json
            $subDir = Join-Path "aylo" "trailer" $parentStudio $studio
    
            $null = Get-AyloSceneTrailer -downloadDir $downloadDir -trailerData $trailerData -storageDir $storageDir -subDir $subDir
        }
    }


    # Series
    if ($sceneData.parent -and $sceneData.parent.type -eq "serie") {
        $seriesData = $sceneData.parent
        if ($seriesData.collections.count -gt 0) {
            $seriesStudio = $seriesData.collections[0].name
        }
        else { $seriesStudio = $parentStudio }
    
        $pathToSeriesJson = Get-ChildItem (Get-AyloSeriesPath -apiType "serie" -root $dataDir -studio $seriesStudio) | Where-Object { $_.BaseName -match "^$($seriesData.id)\s" }
        $seriesData = Get-Content $pathToSeriesJson -raw | ConvertFrom-Json

        # Series galleries
        [array]$seriesGalleries = $seriesData.children | Where-Object { $_.type -eq "gallery" }
        if ($seriesGalleries.count -eq 0) {
            Write-Host "No series gallery available to download." -ForegroundColor Yellow
        }
        else {
            foreach ($gID in $seriesGalleries.id) {
                $pathToGalleryJson = Get-ChildItem (Get-AyloSeriesPath -apiType "gallery" -root $dataDir -studio $seriesStudio) | Where-Object { $_.BaseName -match "^$gID\s" }
                $galleryData = Get-Content $pathToGalleryJson -raw | ConvertFrom-Json
                $subDir = Join-Path "aylo" "gallery" $parentStudio $seriesStudio
        
                $null = Get-AyloSceneGallery -downloadDir $downloadDir -galleryData $galleryData -storageDir $storageDir -subDir $subDir
            }
        }
    
        # Series trailers
        [array]$seriesTrailers = $seriesData.children | Where-Object { $_.type -eq "trailer" }
        if ($seriesTrailers.count -eq 0) {
            Write-Host "No series trailer available to download." -ForegroundColor Yellow
        }
        else {
            foreach ($tID in $seriesTrailers.id) {
                $pathToTrailerJson = Get-ChildItem (Get-AyloSeriesPath -apiType "trailer" -root $dataDir -studio $seriesStudio) | Where-Object { $_.BaseName -match "^$tID\s" }
                $trailerData = Get-Content $pathToTrailerJson -raw | ConvertFrom-Json
                $subDir = Join-Path "aylo" "gallery" $parentStudio $seriesStudio
        
                $null = Get-AyloSceneTrailer -downloadDir $downloadDir -trailerData $traile-trailerData -storageDir $storageDir -subDir $subDir
            }
        }

        # Series poster
        $outputDir = Get-AyloSeriesPath -apiType "serie" -root $assetsDir -studio $seriesStudio
        $null = Get-AyloMediaPoster -downloadDir $assetsDir -sceneData $seriesData -storageDir $storageDir -subDir $subDir

    }
    else { Write-Host "Scene #$($sceneData.id) is not part of a series." -ForegroundColor Yellow }

    # Actors
    foreach ($aID in $sceneData.actors.id) {
        $pathToActorJson = Get-ChildItem (Join-Path $dataDir "aylo" "actor") | Where-Object { $_.BaseName -match "^$aID\s" }
        $actorData = Get-Content $pathToActorJson -raw | ConvertFrom-Json
        $outputDir = Join-Path $assetsDir "aylo" "actor"

        $null = Get-AyloActorAssets -actorData $actorData -assetsDir $outputDir
    }

    # Scene poster
    $subDir = Join-Path "aylo" "scene" $parentStudio $studio
    $null = Get-AyloMediaPoster -downloadDir $assetsDir -sceneData $sceneData -storageDir $storageDir -subDir $subDir


    # Scene
    $subDir = Join-Path "aylo" "scene" $parentStudio $studio
    $null = Get-AyloSceneVideo -downloadDir $downloadDir -sceneData $sceneData -storageDir $storageDir -subDir $subDir

}

# Download a media file into the appropriate directory.
function Get-AyloMediaFile {
    param(
        [Parameter(Mandatory)][ValidateSet("gallery", "poster", "scene", "trailer", ErrorMessage = "Error: mediaType argumement is not supported" )][String]$mediaType,
        [Parameter(Mandatory)][String]$downloadDir,
        [Parameter(Mandatory)][string]$filename,
        [Parameter(Mandatory)][String]$storageDir,
        [Parameter(Mandatory)][String]$subDir,
        [Parameter(Mandatory)][String]$target
    )

    $mediaTypeCap = ( Get-Culture ).TextInfo.ToTitleCase( $mediaType.ToLower() )

    # Check if the file exists
    $existingPath = $null
    foreach ($dir in @($downloadDir, $storageDir)) {
        $testPath = Join-Path $dir $subDir $filename
        if (Test-Path -LiteralPath $testPath) { $existingPath = $testPath }
    }

    # Download if the file doesn't exist
    if ($null -eq $existingPath) {
        $outputPath = Join-Path $downloadDir $subDir $filename

        Write-Host "Downloading $($mediaType): $outputPath"
        try {
            Invoke-WebRequest -uri $target -OutFile ( New-Item -Path $outputPath -Force ) 
        }
        catch {
            Write-Host "ERROR: Could not download $($mediaType): $outputPath" -ForegroundColor Red
            Write-Host "$_" -ForegroundColor Red
            
            # If an empty or partial file has been generated, delete it
            if (Test-Path $outputPath) { Remove-Item $outputPath }
        }

        # Check the file has been downloaded successfully.
        # TODO - Check existing file matches db MD5 hash
        if (!(Test-Path -LiteralPath $outputPath)) {
            Write-Host "FAILED: File not downloaded." -ForegroundColor Red
        }
        else {
            Write-Host "SUCCESS: Downloaded $outputPath" -ForegroundColor Green
        }

    }
    else {
        Write-Host "Skipping $mediaTypeCap as it already exists at $existingPath."
    }
}

# Download the scene gallery
function Get-AyloSceneGallery {
    param(
        [Parameter(Mandatory)][string]$downloadDir,
        [Parameter(Mandatory)][string]$storageDir,
        [Parameter(Mandatory)][string]$subDir,
        [Parameter(Mandatory)]$galleryData
    )

    [array]$files = $galleryData.galleries | Where-Object { $_.format -eq "download" }

    # If the array is empty, show a warning
    if ($files.count -eq 0) {
        Write-Host "No gallery available to download." -ForegroundColor Yellow
    }
    
    $fileToDownload = $files[0]
    $filename = Set-MediaFilename -mediaType "gallery" -extension "zip" -id $galleryData.id -title $galleryData.title

    return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "gallery" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
}

# Download the scene poster
function Get-AyloMediaPoster {
    param(
        [Parameter(Mandatory)][string]$downloadDir,
        [Parameter(Mandatory)][string]$storageDir,
        [Parameter(Mandatory)][string]$subDir,
        [Parameter(Mandatory)]$sceneData
    )

    $fileToDownload = $sceneData.images.poster."0".xx
    $resolution = "$($fileToDownload.height)px"

    $filename = Set-MediaFilename -mediaType "poster" -extension "webp" -id $sceneData.id -resolution $resolution -title $sceneData.title

    return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "poster" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.webp
}

# Download the scene trailer
function Get-AyloSceneTrailer {
    param(
        [Parameter(Mandatory)][string]$downloadDir,
        [Parameter(Mandatory)][string]$storageDir,
        [Parameter(Mandatory)][string]$subDir,
        [Parameter(Mandatory)]$trailerData
    )

    # Filter videos to get the optimal file
    [array]$files = $trailerData.videos.full.files
    # If the array is empty, return a warning
    if ($files.count -eq 0) {
        Write-Host "No trailer available to download." -ForegroundColor Yellow
    }

    # 1. Prefer AV1 codec
    [array]$filteredFiles = $files | Where-Object { $_.codec -eq "av1" }
    if ($filteredFiles.count -gt 0) {
        # For AV1 codec files, get the biggest file
        $filteredFiles = $filteredFiles | Sort-Object -Property "height" -Descending
        $fileToDownload = $filteredFiles[0]
        $filename = Set-MediaFilename -mediaType "trailer" -extension "mp4" -id $trailerData.id -resolution $fileToDownload.label -title $trailerData.title

        return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "trailer" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.view
    }

    # 2. Get the highest resoltion file available
    $filteredFiles = $files
    $filteredFiles = $filteredFiles | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    $filename = Set-MediaFilename -mediaType "trailer" -extension "mp4" -id $trailerData.id -resolution $fileToDownload.label -title $trailerData.title

    return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "trailer" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.view
}

# Download the preferred scene file
function Get-AyloSceneVideo {
    param(
        [Parameter(Mandatory)][string]$downloadDir,
        [Parameter(Mandatory)][string]$storageDir,
        [Parameter(Mandatory)][string]$subDir,
        [Parameter(Mandatory)]$sceneData
    )

    # Filter videos to get the optimal file
    [array]$files = $sceneData.videos.full.files

    # If the array is empty, show a warning
    if ($files.count -eq 0) {
        Write-Host "ERROR: No files available to download" -ForegroundColor Red
    }

    # 1. Prefer AV1 codec
    [array]$filteredFiles = $files | Where-Object { $_.codec -eq "av1" }
    if ($filteredFiles.count -gt 0) {
        # For AV1 codec files, get the biggest file
        $filteredFiles = $filteredFiles | Sort-Object -Property "height" -Descending
        $fileToDownload = $filteredFiles[0]
        $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

        return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "scene" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
    }

    # 2. Get the highest resolution file under 8GB as long as it's at least HD
    $sizeLimitBytes = Get-GigabytesToBytes -gb 8
    $filteredFiles = $files | Where-Object { $_.sizeBytes -le $sizeLimitBytes }

    # Not all non-AV1 codec items have width and height properties. Get the height from the label if needed, and find the highest resolution file
    $filteredFiles = $filteredFiles | Where-Object { [int]($_.label.TrimEnd('p')) -ge 1080 }
    if ($filteredFiles.count -gt 0) {
        $biggestHeight = [int]($filteredFiles[0].label.TrimEnd('p'))
        $biggestFile = $filteredFiles[0]
        foreach ($f in $filteredFiles) {
            if ($null -ne $f.height) { $thisHeight = $f.height }
            else { $thisHeight = [int]($f.label.TrimEnd('p')) }

            if ($thisHeight -gt $biggestHeight) {
                $biggestHeight = $thisHeight
                $biggestFile = $f
            }
        }
        $fileToDownload = $biggestFile
        $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

        return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "scene" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
    }

    # 3. Get the HD file if there's one available
    $filteredFiles = $files | Where-Object { $_.height -eq 1080 -or [int]($_.label.TrimEnd('p')) -eq 1080 }
    if ($filteredFiles.count -gt 0) {
        $fileToDownload = $filteredFiles[0]
        $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

        return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "scene" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
    }

    # 4. Just get the biggest file available
    $filteredFiles = $files
    $filteredFiles = $filteredFiles | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

    return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "scene" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
}

#Download the actor assets
function Get-AyloActorAssets {
    param (
        [Parameter(Mandatory)]$actorData,
        [Parameter(Mandatory)][string]$assetsDir
    )
    $actorID = $actorData.id
    $actorName = $actorData.name

    # Download the actor's profile image
    $imgUrl = $actorData.images.master_profile."0".lg.url
    $filename = Set-AssetFilename -assetType "profile" -extension "jpg" -id $actorData.id -title $actorName
    
    $assetsDest = Join-Path $assetsDir $filename
    if (Test-Path $assetsDest) { 
        Write-Host "Profile image for actor $actorName (#$actorID) already downloaded."
    }
    else {
        try {
            Write-Host "Downloading profile image for actor $actorName (#$actorID)."
            Invoke-WebRequest -uri $imgUrl -OutFile ( New-Item -Path $assetsDest -Force ) 
        }
        catch {
            Write-Host "ERROR: Failed to download the profile image for actor $actorName (#$actorID)." -ForegroundColor Red
        }
        Write-Host "SUCCESS: Downloaded the profile image for actor $actorName (#$actorID)." -ForegroundColor Green
    }
    
}