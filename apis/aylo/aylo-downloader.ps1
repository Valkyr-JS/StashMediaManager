# Download a media file into the appropriate directory.
function Get-Media {
    param(
        [uint64]$expectedFileSize,
        [Parameter(Mandatory)]
        [ValidateSet("scene", ErrorMessage = "Error: mediaType argumement is not supported" )]
        [String]$mediaType,
        [Parameter(Mandatory)]
        [String]$outputDir,
        [Parameter(Mandatory)]$sceneData,
        [Parameter(Mandatory)]
        [String]$target
    )
    $date = Get-Date -Date $sceneData.dateReleased -Format "yyyy-MM-dd"
    $parentStudio = $sceneData.brandMeta.displayName
    $sceneID = $sceneData.id
    $studio = $sceneData.collections[0].name
    $title = $sceneData.title.Split([IO.Path]::GetInvalidFileNameChars()) -join ''
    $title = $title.replace("  ", " ")

    # Check if the final string in outputDir is a backslash, and add one if needed.
    if ($outputDir.Substring($outputDir.Length - 1) -ne "\") {
        $outputDir += "\"
    }
    $outputDirectory = "$outputDir$(if($parentStudio.Length){"$parentStudio\"})$studio\"

    $contentFolder = "$sceneID $date $title"
    $outputDirectory += "$contentFolder\"

    if ($mediaType -eq "scene") {
        # Use the default filename that would be used for downloading manually.
        $filename = $target.split("filename=")[1]
        $outputPath = $outputDirectory + $filename
        $existingFile = Test-Path $outputPath

        # Download if the file doesn't exist, or the filesize is less than 95% accurate
        if ($null -eq $existingFile -or $existingFile.Length -le ($expectedFileSize * 0.95)) {
            Write-Host "Downloading scene: $outputPath"
            return Invoke-WebRequest -uri $target -OutFile ( New-Item -Path $outputPath -Force )
        }
        else {
            return Write-Host "File already exists. Skipped." -ForegroundColor Yellow
        }
    }
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
        return Get-Media -expectedFileSize $fileToDownload.sizeBytes -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
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
        return Get-Media -expectedFileSize $fileToDownload.sizeBytes -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
    }

    # 3. Get the HD file if there's one available
    $filteredFiles = $files | Where-Object { $_.height -eq 1080 -or [int]($_.label.TrimEnd('p')) -eq 1080 }
    if ($filteredFiles.count -gt 0) {
        $fileToDownload = $filteredFiles[0]
        return Get-Media -expectedFileSize $fileToDownload.sizeBytes -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
    }

    # 4. Just get the biggest file available
    $filteredFiles = $files
    $filteredFiles = $filteredFiles | Sort-Object -Property "sizeBytes" -Descending
    $fileToDownload = $filteredFiles[0]
    return Get-Media -expectedFileSize $fileToDownload.sizeBytes -mediaType "scene" -outputDir $outputDir -sceneData $sceneData -target $fileToDownload.urls.download
}