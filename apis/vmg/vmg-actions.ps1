# Scrape then download all content featured in the provided scene ID/s
function Get-VMGAllContentBySceneIDs {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int[]]$sceneIDs
    )
    $sceneIndex = 1
    foreach ($sceneID in $sceneIDs) {
        Write-Host `n"Scene $sceneIndex/$($sceneIDs.Length)" -Foreground Cyan
        $pathToSceneJson = Get-VMGAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
        if (($null -ne $pathToSceneJson) -and !(Test-Path -LiteralPath $pathToSceneJson)) {
            Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
        }
        elseif ($null -ne $pathToSceneJson) {
            $sceneData = Get-Content -LiteralPath $pathToSceneJson -raw | ConvertFrom-Json
            Get-VMGSceneAllMedia -sceneData $sceneData -pathToUserConfig $pathToUserConfig
        }
        $sceneIndex++
    }
}