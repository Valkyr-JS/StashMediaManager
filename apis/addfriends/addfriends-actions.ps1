function Get-AFAllContentBySite {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$slug
    )

    # Fetch the site data
    $modelArchive = Get-AFModelSiteJson -pathToUserConfig $pathToUserConfig -slug $slug
    if (($null -ne $modelArchive) -and !(Test-Path $modelArchive)) {
        Write-Host `n"ERROR: site JSON data not found - $modelArchive." -ForegroundColor Red
        exit
    }

    $modelArchive = Get-Content $modelArchive -raw | ConvertFrom-Json
    $sceneIDs = [string[]]$modelArchive.videos.id

    # Fetch data for each scene
    foreach ($id in $sceneIDs) {
        Get-AFSceneJson -pathToUserConfig $pathToUserConfig -sceneID $id
    }
}