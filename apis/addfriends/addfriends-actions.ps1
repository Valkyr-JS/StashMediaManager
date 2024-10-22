function Get-AFAllContentBySite {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$siteName,
        [Parameter(Mandatory)][String]$slug
    )

    # Fetch the site data
    $modelArchive = Get-AFModelSiteJson -pathToUserConfig $pathToUserConfig -siteName $siteName -slug $slug
    if (($null -ne $modelArchive) -and !(Test-Path -LiteralPath $modelArchive)) {
        Write-Host `n"ERROR: site JSON data not found - $modelArchive." -ForegroundColor Red
        exit
    }

    $modelArchive = Get-Content $modelArchive -raw | ConvertFrom-Json
    $sceneIDs = [string[]]$modelArchive.videos.id
    $sceneIndex = 1

    $null = Get-AFAssets -pathToUserConfig $pathToUserConfig -siteData $modelArchive.site

    # Fetch data for each scene
    foreach ($id in $sceneIDs) {
        Write-Host `n"Scene $sceneIndex/$($sceneIDs.Length)" -Foreground Cyan
        $pathToSceneJson = Get-AFSceneJson -pathToUserConfig $pathToUserConfig -sceneID $id -siteName $siteName
        if (($null -ne $pathToSceneJson) -and !(Test-Path -LiteralPath $pathToSceneJson)) {
            Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
        }
        elseif ($null -ne $pathToSceneJson) {
            $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
            Get-AFSceneAllMedia -pathToUserConfig $pathToUserConfig -sceneData $sceneData -siteName $siteName
        }
        $sceneIndex++
    }
}