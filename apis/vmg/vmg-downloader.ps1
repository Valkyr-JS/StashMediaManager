# Get all media associated with a given Vixen Media Group scene ID
function Get-VMGSceneAllMedia {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Object]$sceneData
    )
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    # $assetsDir = $userConfig.general.assetsDirectory
    # $assetsDownloadDir = $userConfig.general.assetsDownloadDirectory
    $dataDir = $userConfig.general.dataDownloadDirectory
    $downloadDir = $userConfig.general.contentDownloadDirectory
    $storageDir = $userConfig.general.contentDirectory

    $parentStudio = "Vixen Media Group"
    $studio = (Get-Culture).TextInfo.ToTitleCase($sceneData.site)
    $sceneID = $sceneData.videoId

    Write-Host `n"Downloading all media for scene #$sceneID - $($sceneData.title)." -ForegroundColor Cyan

    # Scene
    $parentDir = Join-Path $dataDir "VMG" "scene" "getVideo" $parentStudio $studio
    $pathToSceneJson = Get-ChildItem -LiteralPath $parentDir -Recurse | Where-Object { $_.BaseName -match "^$sceneID\s" }

    $sceneData = Get-Content -LiteralPath $pathToSceneJson -raw | ConvertFrom-Json
    $subDir = Join-Path "VMG" "scene" $parentStudio $studio

    $null = Get-VMGScene -downloadDir $downloadDir -sceneData $sceneData -storageDir $storageDir -subDir $subDir
}

# Download the scene
function Get-VMGScene {
    param(
        [Parameter(Mandatory)][string]$downloadDir,
        [Parameter(Mandatory)][Object]$sceneData,
        [Parameter(Mandatory)][string]$storageDir,
        [Parameter(Mandatory)][string]$subDir
    )

    $sceneData = $sceneData.data.findOneVideo
    $parentStudio = "Vixen Media Group"
    $studio = (Get-Culture).TextInfo.ToTitleCase($sceneData.site)

    # Get the link from the getToken file
    $tokenDir = Join-Path $dataDir "VMG" "scene" "getToken" $parentStudio $studio
    $pathToTokenJson = Get-ChildItem -LiteralPath $tokenDir -Recurse | Where-Object { $_.BaseName -match "^$sceneID\s" }
    $tokenData = Get-Content -LiteralPath $pathToTokenJson -raw | ConvertFrom-Json
    $tokenData = $tokenData.data.generateVideoToken

    # Get the highest resolution file
    $tokenLinkData = $null
    $sceneRes = $null
    if ($tokenData.p2160) {
        $tokenLinkData = $tokenData.p2160
        $sceneRes = "2160p"
    }
    elseif ($tokenData.p1080) {
        $tokenLinkData = $tokenData.p1080
        $sceneRes = "1080p"
    }
    else {
        $tokenLinkData = $tokenData.p720
        $sceneRes = "720p"
    }
    $tokenLink = $tokenLinkData.token

    # Download the scene file
    $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.videoId -resolution $sceneRes -title $sceneData.title
    return Get-VMGMediaFile -downloadDir $downloadDir -filename $filename -mediaType "scene" -storageDir $storageDir -subDir $subDir -target $tokenLink
}

# Download a media file into the appropriate directory.
function Get-VMGMediaFile {
    param(
        [Parameter(Mandatory)][ValidateSet("scene", ErrorMessage = "Error: mediaType argumement is not supported" )][String]$mediaType,
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
