
# Get all available scene media
function Get-AllSceneMedia {
    param(
        $galleryData,
        [Parameter(Mandatory)][String]$outputDir,
        [Parameter(Mandatory)]$sceneData
    )
    $date = Get-Date -Date $sceneData.dateReleased -Format "yyyy-MM-dd"
    $parentStudio = $sceneData.brandMeta.displayName
    $sceneID = $sceneData.id
    $studio = $sceneData.collections[0].name
    $title = $sceneData.title.Split([IO.Path]::GetInvalidFileNameChars()) -join ''
    $title = $title.replace("  ", " ")

    # Create the final output directory
    $contentFolder = "$sceneID $date $title"

    # Check if the final string in outputDir is a backslash, and add one if needed.
    if ($outputDir.Substring($outputDir.Length - 1) -ne "\") {
        $outputDir += "\"
    }

    $outputDir = "$outputDir$(if($parentStudio.Length){"$parentStudio\"})$studio\$contentFolder\"

    # Get downloading
    Get-SceneVideo -outputDir $outputDir -sceneData $sceneData
    Get-SceneTrailer -outputDir $outputDir -sceneData $sceneData
    Get-SceneGallery -galleryData $galleryData -outputDir $outputDir -sceneData $sceneData
}

# Download a media file into the appropriate directory.
function Get-MediaFile {
    param(
        [string]$filename,
        [Parameter(Mandatory)]
        [ValidateSet("gallery", "scene", "trailer", ErrorMessage = "Error: mediaType argumement is not supported" )]
        [String]$mediaType,
        [Parameter(Mandatory)][String]$outputDir,
        [Parameter(Mandatory)]$sceneData,
        [Parameter(Mandatory)][String]$target
    )

    # ? Gallery filenames are passed as an argument, as the default filename is
    # available in the API.

    if ($mediaType -eq "scene") {
        # Use the default filename that would be used for downloading manually.
        $filename = $target.split("filename=")[1]
    }

    if ($mediaType -eq "trailer") {
        Write-Host "Trailer target: $target"
        # Use the default filename that would be used for downloading manually.
        $filename = $target.split("/")[-1]
    }

    $outputPath = $outputDir + $filename
    $existingFile = Test-Path $outputPath

    # Download if the file doesn't exist
    # TODO - Check existing file matches db MD5 hash
    if (!$existingFile) {
        Write-Host "Downloading $($mediaType): $outputPath"
        return Invoke-WebRequest -uri $target -OutFile ( New-Item -Path $outputPath -Force )
    }
    else {
        return Write-Host "$mediaType file already exists. Skipped." -ForegroundColor Yellow
    }
}

# Download the scene gallery
function Get-SceneGallery {
    param(
        $galleryData,
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)]$sceneData
    )
    $fileToDownload = $galleryData.galleries | Where-Object { $_.format -eq "download" }
    $fileToDownload = $fileToDownload[0]

    return Get-MediaFile -filename $fileToDownload.filePattern -mediaType "gallery" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
}

# Download the scene trailer
function Get-SceneTrailer {
    param(
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)]$sceneData
    )

    # Filter videos to get the optimal file
    [array]$files = $sceneData.children | Where-Object { $_.type -eq "trailer" }
    $files = $files.videos.full.files

    # 1. Prefer AV1 codec
    [array]$filteredFiles = $files | Where-Object { $_.codec -eq "av1" }
    if ($filteredFiles.count -gt 0) {
        # For AV1 codec files, get the biggest file
        $filteredFiles = $filteredFiles | Sort-Object -Property "height" -Descending
        $fileToDownload = $filteredFiles[0]
        return Get-MediaFile -mediaType "trailer" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.view
    }

    # 2. Get the highest resoltion file available
    $filteredFiles = $files
    $filteredFiles = $filteredFiles | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    return Get-MediaFile -mediaType "trailer" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.view
}

# Download the preferred scene file
function Get-SceneVideo {
    param(
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)]$sceneData
    )

    # Filter videos to get the optimal file
    [array]$files = $sceneData.videos.full.files

    # If the array is empty, return a warning
    if ($files.count -eq 0) {
        return Write-Host "ERROR: No files available to download" -ForegroundColor Red
    }

    # 1. Prefer AV1 codec
    [array]$filteredFiles = $files | Where-Object { $_.codec -eq "av1" }
    if ($filteredFiles.count -gt 0) {
        # For AV1 codec files, get the biggest file
        $filteredFiles = $filteredFiles | Sort-Object -Property "height" -Descending
        $fileToDownload = $filteredFiles[0]
        return Get-MediaFile -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
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
        return Get-MediaFile -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
    }

    # 3. Get the HD file if there's one available
    $filteredFiles = $files | Where-Object { $_.height -eq 1080 -or [int]($_.label.TrimEnd('p')) -eq 1080 }
    if ($filteredFiles.count -gt 0) {
        $fileToDownload = $filteredFiles[0]
        return Get-MediaFile -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
    }

    # 4. Just get the biggest file available
    $filteredFiles = $files
    $filteredFiles = $filteredFiles | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    return Get-MediaFile -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
}