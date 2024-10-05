# Get all media associated with a given AF scene ID
function Get-AFSceneAllMedia {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)]$sceneData
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $assetsDir = $userConfig.general.assetsDirectory
    # $dataDir = $userConfig.general.scrapedDataDirectory
    # $downloadDir = $userConfig.general.downloadDirectory
    # $storageDir = $userConfig.general.storageDirectory
    $subDir = Join-Path "addfriends" "video" $slug

    # Get the filename for the poster
    $posterCdnFilename = $sceneData.file_name.split(".")[0]
    $posterFilename = Set-MediaFilename -mediaType "scene" -extension "jpg" -id $sceneData.id -title $sceneData.title
    
    Write-Host `n"Downloading all media for scene #$($sceneData.id) - $($sceneData.title)." -ForegroundColor Cyan

    # Poster
    $posterUrl = "https://static.addfriends.com/vip/posters/$posterCdnFilename-big.jpg"
    Write-Host $posterUrl

    # Check if the file exists
    $existingPath = $null
    $outputDir = Join-Path $assetsDir $subDir
    $outputPath = Join-Path $outputDir $posterFilename
    if (Test-Path -LiteralPath $outputPath) { $existingPath = $outputPath }

    # Download the file if it doesn't exist
    if ($null -eq $existingPath) {
        Write-Host "Downloading poster: $outputPath"
        if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        try {
            Invoke-WebRequest -uri $posterUrl -OutFile ( New-Item -Path $outputPath -Force ) 
        }
        catch {
            Write-Host "ERROR: Could not download poster: $outputPath" -ForegroundColor Red
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
        Write-Host "Skipping poster as it already exists at $existingPath."
    }
    
    # Scene
}