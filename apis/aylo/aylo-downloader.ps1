# Get all media associated with a given Aylo scene ID
function Get-AyloSceneAllMedia {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)]$sceneData
    )
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $dataDir = $userConfig.general.scrapedDataDirectory
    $downloadDir = $userConfig.general.downloadDirectory

    function Get-AyloPath {
        param(
            [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene', 'serie', 'trailer')][String]$apiType,
            [Parameter(Mandatory)][String]$root
        )
        return Join-Path $root "aylo" $apiType $parentStudio $studio
    }

    Write-Host `n"Downloading all media for scene $($sceneData.id) - $($sceneData.title)." -ForegroundColor Cyan

    $parentStudio = $sceneData.brandMeta.displayName
    if ($sceneData.collections.count -gt 0) { $studio = $sceneData.collections[0].name }
    else { $studio = $parentStudio }

    # Galleries
    [array]$galleries = $sceneData.children | Where-Object { $_.type -eq "gallery" }
    if ($galleries.count -eq 0) {
        return Write-Host "No gallery available to download." -ForegroundColor Yellow
    }
    else {
        foreach ($gID in $galleries.id) {
            $pathToGalleryJson = Get-ChildItem (Get-AyloPath -apiType "gallery" -root $dataDir) | Where-Object { $_.BaseName -match $gID }
            $galleryData = Get-Content $pathToGalleryJson -raw | ConvertFrom-Json
            $outputDir = Get-AyloPath -apiType "gallery" -root $downloadDir
    
            $null = Get-AyloSceneGallery -galleryData $galleryData -outputDir $outputDir
        }
    }

    # Trailers
    [array]$trailers = $sceneData.children | Where-Object { $_.type -eq "trailer" }
    if ($trailers.count -eq 0) {
        return Write-Host "No trailer available to download." -ForegroundColor Yellow
    }
    else {
        foreach ($tID in $trailers.id) {
            $pathToTrailerJson = Get-ChildItem (Get-AyloPath -apiType "trailer" -root $dataDir) | Where-Object { $_.BaseName -match $tID }
            $trailerData = Get-Content $pathToTrailerJson -raw | ConvertFrom-Json
            $outputDir = Get-AyloPath -apiType "trailer" -root $downloadDir
    
            $null = Get-AyloSceneTrailer -trailerData $trailerData -outputDir $outputDir
        }
    }


    # Series


    # Series galleries


    # Series trailers


    # Actors

    
    # Scene
    $outputDir = Get-AyloPath -apiType "scene" -root $downloadDir
    $null = Get-AyloSceneVideo -outputDir $outputDir -sceneData $sceneData


    # ------------------------------------ Old ----------------------------------- #


    # # Create the full assets and output directories
    # $assetsDir = Join-Path $assetsDir "aylo" "scenes" $parentStudio $studio
    # if (!(Test-Path $assetsDir)) { New-Item -ItemType "directory" -Path $assetsDir }

    # $contentFolder = "$sceneID $sceneTitle"
    # $outputDir = Join-Path $outputDir $parentStudio $studio $contentFolder
    # if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }

    # # Download content
    # Get-AyloSceneGallery -outputDir $outputDir -sceneData $sceneData
    # Get-AyloSceneVideo -outputDir $outputDir -sceneData $sceneData
    # Get-AyloScenePoster -outputDir $assetsDir -sceneData $sceneData
    # Get-AyloSceneTrailer -outputDir $outputDir -sceneData $sceneData
}

# Download a media file into the appropriate directory.
function Get-AyloMediaFile {
    param(
        [Parameter(Mandatory)][string]$filename,
        [Parameter(Mandatory)]
        [ValidateSet("gallery", "poster", "scene", "trailer", ErrorMessage = "Error: mediaType argumement is not supported" )]
        [String]$mediaType,
        [Parameter(Mandatory)][String]$outputDir,
        [Parameter(Mandatory)][String]$target
    )

    $outputPath = Join-Path $outputDir $filename
    $existingFile = Test-Path -LiteralPath $outputPath
    $mediaTypeCap = ( Get-Culture ).TextInfo.ToTitleCase( $mediaType.ToLower() )

    # Download if the file doesn't exist
    if (!$existingFile) {
        Write-Host "Downloading $($mediaType): $outputPath"
        try {
            Invoke-WebRequest -uri $target -OutFile ( New-Item -Path $outputPath -Force ) 
        }
        catch {
            Write-Host "ERROR: Could not download $($mediaType): $outputPath" -ForegroundColor Red
            Write-Host "$_" -ForegroundColor Red
        }

        # Check the file has been downloaded successfully.
        # TODO - Check existing file matches db MD5 hash
        if (!(Test-Path -LiteralPath $outputPath)) {
            Write-Host "FAILED: $outputPath" -ForegroundColor Red
        }
        else {
            Write-Host "SUCCESS: Downloaded $outputPath" -ForegroundColor Green
        }

    }
    else {
        Write-Host "$mediaTypeCap already exists. Skipping $outputPath"
    }
}

# Download the scene gallery
function Get-AyloSceneGallery {
    param(
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)]$galleryData
    )

    [array]$files = $galleryData.galleries | Where-Object { $_.format -eq "download" }

    # If the array is empty, show a warning
    if ($files.count -eq 0) {
        Write-Host "No gallery available to download." -ForegroundColor Yellow
    }
    
    $fileToDownload = $files[0]
    $filename = Set-MediaFilename -mediaType "gallery" -extension "zip" -id $galleryData.id -title $galleryData.title

    return Get-AyloMediaFile -filename $filename -mediaType "gallery" -outputDir $outputDir -target $fileToDownload.urls.download
}

# Download the scene poster
function Get-AyloScenePoster {
    param(
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)]$sceneData
    )

    $fileToDownload = $sceneData.images.poster."0".xx
    $resolution = "$($fileToDownload.height)px"

    $filename = Set-MediaFilename -mediaType "poster" -extension "webp" -id $sceneData.id -resolution $resolution -title $sceneData.title

    return Get-AyloMediaFile -filename $filename -mediaType "poster" -outputDir $outputDir -target $fileToDownload.urls.webp
}

# Download the scene trailer
function Get-AyloSceneTrailer {
    param(
        [Parameter(Mandatory)][string]$outputDir,
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
        $filename = Set-MediaFilename -mediaType "trailer" -extension "mp4" -id $trailerData.id -resolution $fileToDownload.label -title $sceneData.title

        return Get-AyloMediaFile -filename $filename -mediaType "trailer" -outputDir $outputDir -target $fileToDownload.urls.view
    }

    # 2. Get the highest resoltion file available
    $filteredFiles = $files
    $filteredFiles = $filteredFiles | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    $filename = Set-MediaFilename -mediaType "trailer" -extension "mp4" -id $trailerData.id -resolution $fileToDownload.label -title $sceneData.title

    return Get-AyloMediaFile -filename $filename -mediaType "trailer" -outputDir $outputDir -target $fileToDownload.urls.view
}

# Download the preferred scene file
function Get-AyloSceneVideo {
    param(
        [Parameter(Mandatory)][string]$outputDir,
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

        return Get-AyloMediaFile -filename $filename -mediaType "scene" -outputDir $outputDir -target $fileToDownload.urls.download
    }

    # 2. Get the highest resoltion file under 6GB as long as it's at least HD
    $sizeLimitBytes = 6442450944
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

        return Get-AyloMediaFile -filename $filename -mediaType "scene" -outputDir $outputDir -target $fileToDownload.urls.download
    }

    # 3. Get the HD file if there's one available
    $filteredFiles = $files | Where-Object { $_.height -eq 1080 -or [int]($_.label.TrimEnd('p')) -eq 1080 }
    if ($filteredFiles.count -gt 0) {
        $fileToDownload = $filteredFiles[0]
        $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

        return Get-AyloMediaFile -filename $filename -mediaType "scene" -outputDir $outputDir -target $fileToDownload.urls.download
    }

    # 4. Just get the biggest file available
    $filteredFiles = $files
    $filteredFiles = $filteredFiles | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -resolution $fileToDownload.label -title $sceneData.title

    return Get-AyloMediaFile -filename $filename -mediaType "scene" -outputDir $outputDir -target $fileToDownload.urls.download
}