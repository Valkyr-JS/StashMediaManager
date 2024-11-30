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