# Scrape then download all content featuring the provided actor ID/s
function Get-AyloAllContentByActorIDs {
    param(
        [Parameter(Mandatory)][Int[]]$actorIDs,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [String]$parentStudio
    )

    foreach ($actorID in $actorIDs) {
        $sceneIDs = Get-AyloSceneIDsByActorID -actorID $actorID -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig

        foreach ($sceneID in $sceneIDs) {
            $pathToSceneJson = Get-AyloSceneJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            if ($null -eq $pathToSceneJson) { return }
            if (!(Test-Path $pathToSceneJson)) {
                return Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
            }
            else {
                $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
                $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
                Get-AyloSceneAllMedia -data $sceneData -assetsDir $userConfig.general.assetsDirectory -outputDir $userConfig.general.downloadDirectory
            }
        }
    }
}