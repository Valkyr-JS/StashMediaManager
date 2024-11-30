# Scrape then download all content featuring the provided model slug
function Get-VMGAllContentByModelSlug {
    param(
        [Parameter(Mandatory)][String]$modelSlug,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$site
    )
    $sceneIDs = Get-VMGSceneIDsByModelSlug -modelSlug $modelSlug -pathToUserConfig $pathToUserConfig -site $site
    $sceneIndex = 1

    foreach ($sceneID in $sceneIDs) {
        Write-Host `n"Scene $sceneIndex/$($sceneIDs.Length)" -Foreground Cyan
        Get-VMGAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
        $sceneIndex++
    }
}

# Scrape then download all content featured in the provided scene ID/s
function Get-VMGAllContentBySceneIDs {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int[]]$sceneIDs
    )
    $sceneIndex = 1
    foreach ($sceneID in $sceneIDs) {
        Write-Host `n"Scene $sceneIndex/$($sceneIDs.Length)" -Foreground Cyan
        Get-VMGAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
        $sceneIndex++
    }
}