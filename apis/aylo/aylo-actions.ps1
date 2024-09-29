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
            $pathToSceneJson = Get-AyloAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            if (($null -ne $pathToSceneJson) -and !(Test-Path $pathToSceneJson)) {
                Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
            }
            elseif ($null -ne $pathToSceneJson) {
                $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
                Get-AyloSceneAllMedia -sceneData $sceneData -pathToUserConfig $pathToUserConfig
            }
        }
    }
}

# Scrape then download all content featured in the provided series ID/s
function Get-AyloAllContentBySeriesID {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int[]]$seriesIDs
    )
    foreach ($seriesID in $seriesIDs) {
        # Fetch the scene IDs
        $sceneIDs = Get-AyloSceneIDsBySeriesID -seriesID $seriesID -pathToUserConfig $pathToUserConfig

        foreach ($sceneID in $sceneIDs) {
            $pathToSceneJson = Get-AyloAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            if (($null -ne $pathToSceneJson) -and !(Test-Path $pathToSceneJson)) {
                Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
            }
            elseif ($null -ne $pathToSceneJson) {
                $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
                Get-AyloSceneAllMedia -sceneData $sceneData -pathToUserConfig $pathToUserConfig
            }
        }
    }
}