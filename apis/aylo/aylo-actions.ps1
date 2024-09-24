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
            # TODO - Check for existing media - Create the scene JSON file ONLY
            # if the associated scene hasn't already been scraped.
            $sceneData = Get-AyloSceneJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            
            if (($null -eq $sceneData)) {
                return Write-Host "ERROR: scene $sceneID data not accessible." -ForegroundColor Red
            }
            else {
                $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
                Get-AyloSceneAllMedia -data $sceneData -outputDir $userConfig.general.downloadDirectory
            }
        }
    }
}