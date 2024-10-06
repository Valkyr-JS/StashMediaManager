function Get-AFAllContentBySite {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$siteName,
        [Parameter(Mandatory)][String]$slug
    )

    # Fetch the site data
    $modelArchive = Get-AFModelSiteJson -pathToUserConfig $pathToUserConfig -siteName $siteName -slug $slug
    if (($null -ne $modelArchive) -and !(Test-Path $modelArchive)) {
        Write-Host `n"ERROR: site JSON data not found - $modelArchive." -ForegroundColor Red
        exit
    }

    $modelArchive = Get-Content $modelArchive -raw | ConvertFrom-Json
    $sceneIDs = [string[]]$modelArchive.videos.id

    # Fetch data for each scene
    foreach ($id in $sceneIDs) {
        $pathToSceneJson = Get-AFSceneJson -pathToUserConfig $pathToUserConfig -sceneID $id -siteName $siteName
        if (($null -ne $pathToSceneJson) -and !(Test-Path $pathToSceneJson)) {
            Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
        }
        elseif ($null -ne $pathToSceneJson) {
            $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
            Get-AFSceneAllMedia -pathToUserConfig $pathToUserConfig -sceneData $sceneData -siteName $siteName
        }
    }
}