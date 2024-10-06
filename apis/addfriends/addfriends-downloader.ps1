# Get all media associated with a given AF scene ID
function Get-AFSceneAllMedia {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$siteName,
        [Parameter(Mandatory)]$sceneData
    )

    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $assetsDir = $userConfig.general.assetsDirectory
    $downloadDir = $userConfig.general.downloadDirectory
    $storageDir = $userConfig.general.storageDirectory
    $subDir = Join-Path "addfriends" "video" $siteName
    
    Write-Host `n"Downloading all media for scene #$($sceneData.id) - $($sceneData.title)." -ForegroundColor Cyan

    # POSTER
    $posterCdnFilename = $sceneData.file_name.split(".")[0]
    $posterFilename = Set-MediaFilename -mediaType "poster" -extension "jpg" -id $sceneData.id -title $sceneData.title
    $posterUrl = "https://static.addfriends.com/vip/posters/$posterCdnFilename-big.jpg"

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

    # GIF
    $gifFilename = Set-MediaFilename -mediaType "poster" -extension "gif" -id $sceneData.id -title $sceneData.title
    $gifUrl = "https://static.addfriends.com/vip/posters/$posterCdnFilename.gif"

    # Check if the file exists
    $existingPath = $null
    $outputPath = Join-Path $outputDir $gifFilename
    if (Test-Path -LiteralPath $outputPath) { $existingPath = $outputPath }

    # Download the file if it doesn't exist
    if ($null -eq $existingPath) {
        Write-Host "Downloading gif: $outputPath"
        if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        try {
            Invoke-WebRequest -uri $gifUrl -OutFile ( New-Item -Path $outputPath -Force ) 
        }
        catch {
            Write-Host "ERROR: Could not download gif: $outputPath" -ForegroundColor Red
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
        Write-Host "Skipping gif as it already exists at $existingPath."
    }

    # SCENE
    $filename = Set-MediaFilename -mediaType "scene" -extension "mp4" -id $sceneData.id -title $sceneData.title
    $subDir = Join-Path "addfriends" "video" $siteName

    # Check if the file exists
    $existingPath = $null
    foreach ($dir in @($downloadDir, $storageDir)) {
        $testPath = Join-Path $dir $subDir $filename
        if (Test-Path -LiteralPath $testPath) { $existingPath = $testPath }
    }

    # Download if the file doesn't exist
    if ($null -eq $existingPath) {
        $outputPath = Join-Path $downloadDir $subDir $filename

        Write-Host "Downloading scene: $outputPath"
        if (!(Test-Path $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        try {
            Invoke-WebRequest -uri $sceneData.dl -OutFile ( New-Item -Path $outputPath -Force ) 
        }
        catch {
            Write-Host "ERROR: Could not download scene: $outputPath" -ForegroundColor Red
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
        Write-Host "Skipping scene as it already exists at $existingPath."
    }
}