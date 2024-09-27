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
        # Create series JSON
        $pathToSeriesJson = Get-AyloSeriesJson -pathToUserConfig $pathToUserConfig -seriesID $seriesID

        $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
        $seriesData = Get-Content $pathToSeriesJson -raw | ConvertFrom-Json

        # Download the trailer for the series
        $seriesTitle = Get-SanitizedTitle -title $seriesData.title
        $parentStudio = $seriesData.brandMeta.displayName
        if ($seriesData.collections.count -gt 0) { $studio = $seriesData.collections[0].name }
        else { $studio = $parentStudio }
        $contentFolder = "$seriesID $seriesTitle"

        $outputDir = Join-Path $userConfig.general.downloadDirectory $parentStudio $studio $contentFolder
        Get-AyloSceneTrailer -outputDir $outputDir -sceneData $seriesData

        # Fetch the scene IDs
        $sceneIDs = Get-AyloSceneIDsBySeriesID -seriesID $seriesID -pathToUserConfig $pathToUserConfig

        foreach ($sceneID in $sceneIDs) {
            $pathToSceneJson = Get-AyloSceneJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            if (($null -ne $pathToSceneJson) -and !(Test-Path $pathToSceneJson)) {
                Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
            }
            elseif ($null -ne $pathToSceneJson) {
                Write-Host $pathToSceneJson
                $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
                Write-Host $sceneData
                Get-AyloSceneAllMedia -data $sceneData -assetsDir $userConfig.general.assetsDirectory -outputDir $userConfig.general.downloadDirectory
            }
        }
    }
}