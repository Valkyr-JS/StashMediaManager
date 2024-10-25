# Get all media associated with a given Aylo scene ID
function Get-AyloSceneAllMedia {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)]$sceneData
    )
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $assetsDir = $userConfig.general.assetsDirectory
    $assetsDownloadDir = $userConfig.general.assetsDownloadDirectory
    $dataDir = $userConfig.general.dataDownloadDirectory
    $downloadDir = $userConfig.general.contentDownloadDirectory
    $storageDir = $userConfig.general.contentDirectory

    $parentStudio = $sceneData.brandMeta.displayName
    if ($sceneData.collections.count -gt 0) { $studio = $sceneData.collections[0].name }
    else { $studio = $parentStudio }
    
    Write-Host `n"Downloading all media for scene #$($sceneData.id) - $($sceneData.title)." -ForegroundColor Cyan

    function Get-AyloPath {
        param(
            [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
            [Parameter(Mandatory)][String]$root
        )
        return [String](Join-Path $root "aylo" $apiType $parentStudio $studio)
    }

    function Get-AyloSeriesPath {
        param(
            [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
            [Parameter(Mandatory)][String]$root,
            [Parameter(Mandatory)][String]$studio
        )
        return [String](Join-Path $root "aylo" $apiType $parentStudio $studio)
    }


    # Galleries
    [array]$galleries = $sceneData.children | Where-Object { $_.type -eq "gallery" }
    if ($galleries.count -eq 0) {
        Write-Host "No gallery available to download." -ForegroundColor Yellow
    }
    else {
        foreach ($gID in $galleries.id) {
            $pathToGalleryJson = Get-ChildItem -LiteralPath (Get-AyloPath -apiType "gallery" -root $dataDir) | Where-Object { $_.BaseName -match "^$gID\s" }
            $galleryData = Get-Content -LiteralPath $pathToGalleryJson -raw | ConvertFrom-Json
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
            $pathToTrailerJson = Get-ChildItem -LiteralPath (Get-AyloPath -apiType "trailer" -root $dataDir) | Where-Object { $_.BaseName -match "^$tID\s" }
            $trailerData = Get-Content -LiteralPath $pathToTrailerJson -raw | ConvertFrom-Json
            $subDir = Join-Path "aylo" "trailer" $parentStudio $studio
    
            $null = Get-AyloSceneTrailer -downloadDir $assetsDownloadDir -trailerData $trailerData -storageDir $assetsDir -subDir $subDir
        }
    }


    # Series
    if ($sceneData.parent -and $sceneData.parent.type -eq "serie") {
        $seriesData = $sceneData.parent
        if ($seriesData.collections.count -gt 0) {
            $seriesStudio = $seriesData.collections[0].name
        }
        else { $seriesStudio = $parentStudio }
    
        $pathToSeriesJson = Get-ChildItem -LiteralPath (Get-AyloSeriesPath -apiType "serie" -root $dataDir -studio $seriesStudio) | Where-Object { $_.BaseName -match "^$($seriesData.id)\s" }
        $seriesData = Get-Content -LiteralPath $pathToSeriesJson -raw | ConvertFrom-Json

        # Series galleries
        [array]$seriesGalleries = $seriesData.children | Where-Object { $_.type -eq "gallery" }
        if ($seriesGalleries.count -eq 0) {
            Write-Host "No series gallery available to download." -ForegroundColor Yellow
        }
        else {
            foreach ($gID in $seriesGalleries.id) {
                $pathToGalleryJson = Get-ChildItem -LiteralPath (Get-AyloSeriesPath -apiType "gallery" -root $dataDir -studio $seriesStudio) | Where-Object { $_.BaseName -match "^$gID\s" }
                $galleryData = Get-Content -LiteralPath $pathToGalleryJson -raw | ConvertFrom-Json
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
                $pathToTrailerJson = Get-ChildItem -LiteralPath (Get-AyloSeriesPath -apiType "trailer" -root $dataDir -studio $seriesStudio) | Where-Object { $_.BaseName -match "^$tID\s" }
                $trailerData = Get-Content -LiteralPath $pathToTrailerJson -raw | ConvertFrom-Json
                $subDir = Join-Path "aylo" "trailer" $parentStudio $seriesStudio
        
                $null = Get-AyloSceneTrailer -downloadDir $assetsDownloadDir -trailerData $trailerData -storageDir $assetsDir -subDir $subDir
            }
        }

        # Series poster
        $subDir = Join-Path "aylo" "serie" $parentStudio $studio
        $null = Get-AyloMediaPoster -downloadDir $assetsDownloadDir -sceneData $seriesData -storageDir $assetsDir -subDir $subDir

    }
    else { Write-Host "Scene #$($sceneData.id) is not part of a series." -ForegroundColor Yellow }

    # Actors
    foreach ($aID in $sceneData.actors.id) {
        $pathToActorJson = Get-ChildItem -LiteralPath (Join-Path $dataDir "aylo" "actor") | Where-Object { $_.BaseName -match "^$aID\s" }
        $actorData = Get-Content -LiteralPath $pathToActorJson -raw | ConvertFrom-Json

        $subDir = Join-Path "aylo" "actor"
        $null = Get-AyloActorAssets -actorData $actorData -downloadDir $assetsDownloadDir -storageDir $assetsDir -subDir $subDir
    }

    # Scene poster
    $subDir = Join-Path "aylo" "scene" $parentStudio $studio
    $null = Get-AyloMediaPoster -downloadDir $assetsDownloadDir -sceneData $sceneData -storageDir $assetsDir -subDir $subDir


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
            if (Test-Path -LiteralPath $outputPath) { Remove-Item $outputPath }
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
        Write-Host "Skipping $mediaType as it already exists at $existingPath."
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

    [array]$files = $galleryData.galleries

    # If the array is empty, show a warning
    if ($files.count -eq 0) {
        Write-Host "No gallery available to download." -ForegroundColor Yellow
        return $null
    }

    # 1. Download the gallery zip file if there's one available
    [array]$filteredFiles = $files | Where-Object { $_.format -eq "download" }
    if ($filteredFiles.Count -gt 0) {
        $fileToDownload = $filteredFiles[0]
        $filename = Set-MediaFilename -mediaType "gallery" -extension "zip" -id $galleryData.id -title $galleryData.title
    
        return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "gallery" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
    }

    # 2. Download the loose images then zip them up
    [array]$filteredFiles = $files | Where-Object { $_.format -eq "pictures" }
    $zipName = Set-MediaFilename -mediaType "gallery" -extension "zip" -id $galleryData.id -title $galleryData.title

    # Requires a separate check to see if the gallery already exists
    foreach ($dir in @($downloadDir, $storageDir)) {
        $testPath = Join-Path $dir $subDir $zipName
        if (Test-Path -LiteralPath $testPath) { $existingPath = $testPath }
    }
    if ($null -ne $existingPath) {
        Write-Host "Skipping gallery as it already exists at $existingPath."
        return $existingPath
    }

    # Download if a zip file doesn't exist already, and there are loose files
    # available to download.
    if ($filteredFiles.Count -gt 0) {
        $galleryObject = $filteredFiles[0]
        $url = $galleryObject.url
        $galleryIndex = 0
        $folderName = Get-SanitizedFilename $galleryData.title
        [String]$tempDest = Join-Path $downloadDir $subDir "$($galleryData.id) $folderName"
        if (!(Test-Path -LiteralPath $tempDest)) { New-Item -ItemType "directory" -Path $tempDest }

        # Check file pattern is 4 digits. Update this as needed.
        $filePattern = ($galleryObject.filePattern.split("."))[0]
        if ($filePattern -eq "%04d") {
            # Loop through and download each image
            while ($galleryIndex -lt $galleryObject.filesCount) {
                $galleryIndex++
                $paddedIndex = "{0:d4}" -f $galleryIndex
                $imageUrl = $url.replace($filePattern, $paddedIndex)
                $imageName = Set-MediaFilename -mediaType "image" -extension $galleryObject.filePattern.split(".")[1] -id $galleryData.id -title "$($galleryData.title) $paddedIndex"

                try {
                    Write-Host "Downloading gallery image $galleryIndex/$($galleryObject.filesCount)"
                    Invoke-WebRequest -uri $imageUrl -OutFile ( New-Item -Path "$tempDest\$imageName" -Force ) 
                }
                catch {
                    Write-Host "ERROR: Failed to download gallery image #$galleryIndex" -ForegroundColor Red
                }
            }
            $zipPath = Join-Path $downloadDir $subDir $zipName

            # ! I don't know why this throws error "Join-Path: Cannot bind
            # argument to parameter 'Path' because it is null.", but it's fine
            # ¯\_(ツ)_/¯
            Get-ChildItem -LiteralPath $tempDest | Compress-Archive -DestinationPath $zipPath

            # Delete the temp folder once zip is complete
            Remove-Item -LiteralPath $tempDest -Recurse
            return $zipPath
        }
    }
    # Otherwise, download nothing
    Write-Host "Script is not configured to download this gallery." -ForegroundColor Yellow
    return $null
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
        return $null
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

    # 2. Get the biggest file available. Use file size rather than resolution as
    #    res is unavailable for most non-AV1 codec files, and file size should
    #    filter out corrupted files.
    $filteredFiles = $files | Sort-Object -Property "sizeBytes" -Descending
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
        return $null
    }

    # 1. Prefer AV1 codec files
    [array]$filteredFiles = $files | Where-Object { $_.codec -eq "av1" }
    if ($filteredFiles.count -gt 0) {
        # For AV1 codec files, get the file with the highest resolution
        $filteredFiles = $filteredFiles | Sort-Object -Property "height" -Descending
        $fileToDownload = $filteredFiles[0]
        $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

        return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "scene" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
    }

    # 2. Get the biggest file available. Use file size rather than resolution as
    #    res is unavailable for most non-AV1 codec files, and file size should
    #    filter out corrupted files.
    $filteredFiles = $files | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

    return Get-AyloMediaFile -downloadDir $downloadDir -filename $filename -mediaType "scene" -storageDir $storageDir -subDir $subDir -target $fileToDownload.urls.download
}

# Download the actor assets
function Get-AyloActorAssets {
    param (
        [Parameter(Mandatory)]$actorData,
        [Parameter(Mandatory)][string]$downloadDir,
        [Parameter(Mandatory)][string]$storageDir,
        [Parameter(Mandatory)][string]$subDir
    )
    $actorID = $actorData.id
    $actorName = $actorData.name
    $filename = Set-AssetFilename -assetType "profile" -extension "jpg" -id $actorID -title $actorName

    # Check if the file exists
    $existingPath = $null
    foreach ($dir in @($downloadDir, $storageDir)) {
        $testPath = Join-Path $dir $subDir $filename
        if (Test-Path -LiteralPath $testPath) { $existingPath = $testPath }
    }

    $assetsDest = Join-Path $downloadDir $subDir $filename
    if (Test-Path -LiteralPath $assetsDest) { $existingPath = $assetsDest }
    
    # Download the actor's profile image if it doesn't exist
    $imgUrl = $actorData.images.master_profile."0".lg.url
    if ($null -eq $existingPath) {
        try {
            Write-Host "Downloading profile image for actor $actorName (#$actorID)."
            Invoke-WebRequest -uri $imgUrl -OutFile ( New-Item -Path $assetsDest -Force ) 
        }
        catch {
            Write-Host "ERROR: Failed to download the profile image for actor $actorName (#$actorID)." -ForegroundColor Red
        }
        Write-Host "SUCCESS: Downloaded the profile image for actor $actorName (#$actorID)." -ForegroundColor Green
    }
    else {
        Write-Host "Skipping profile image for $actorName as it already exists at $existingPath."
    }    
}