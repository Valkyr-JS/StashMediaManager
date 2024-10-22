# Scrape then download all content featuring the provided actor ID/s
function Get-AyloAllContentByActorIDs {
    param(
        [Parameter(Mandatory)][Int[]]$actorIDs,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [String]$parentStudio
    )
    $actorIndex = 1;

    foreach ($actorID in $actorIDs) {
        $sceneIDs = Get-AyloSceneIDsByActorID -actorID $actorID -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig
        $sceneIndex = 1

        foreach ($sceneID in $sceneIDs) {
            Write-Host `n"Scene $sceneIndex/$($sceneIDs.Length) of actor $actorIndex/$($actorIDs.Length)" -Foreground Cyan

            $pathToSceneJson = Get-AyloAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            if (($null -ne $pathToSceneJson) -and !(Test-Path -LiteralPath $pathToSceneJson)) {
                Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
            }
            elseif ($null -ne $pathToSceneJson) {
                $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
                Get-AyloSceneAllMedia -sceneData $sceneData -pathToUserConfig $pathToUserConfig
            }
            $sceneIndex++
        }
        $actorIndex++
    }
}

# Scrape then download all content featured in the provided scene ID/s
function Get-AyloAllContentBySceneIDs {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int[]]$sceneIDs
    )
    $sceneIndex = 1
    foreach ($sceneID in $sceneIDs) {
        Write-Host `n"Scene $sceneIndex/$($sceneIDs.Length)" -Foreground Cyan
        $pathToSceneJson = Get-AyloAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
        if (($null -ne $pathToSceneJson) -and !(Test-Path -LiteralPath $pathToSceneJson)) {
            Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
        }
        elseif ($null -ne $pathToSceneJson) {
            $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
            Get-AyloSceneAllMedia -sceneData $sceneData -pathToUserConfig $pathToUserConfig
        }
        $sceneIndex++
    }
}

# Scrape then download all content featured in the provided series ID/s
function Get-AyloAllContentBySeriesIDs {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int[]]$seriesIDs
    )
    $seriesIndex = 1
    foreach ($seriesID in $seriesIDs) {
        # Fetch the scene IDs
        $sceneIDs = Get-AyloSceneIDsBySeriesID -seriesID $seriesID -pathToUserConfig $pathToUserConfig
        $sceneIndex = 1

        foreach ($sceneID in $sceneIDs) {
            Write-Host `n"Scene $sceneIndex/$($sceneIDs.Length) of series $seriesIndex/$($seriesIDs.Length)" -Foreground Cyan
            $pathToSceneJson = Get-AyloAllJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            if (($null -ne $pathToSceneJson) -and !(Test-Path -LiteralPath $pathToSceneJson)) {
                Write-Host `n"ERROR: scene $sceneID JSON data not found - $pathToSceneJson." -ForegroundColor Red
            }
            elseif ($null -ne $pathToSceneJson) {
                $sceneData = Get-Content $pathToSceneJson -raw | ConvertFrom-Json
                Get-AyloSceneAllMedia -sceneData $sceneData -pathToUserConfig $pathToUserConfig
            }
            $sceneIndex++
        }
        $seriesIndex++
    }
}