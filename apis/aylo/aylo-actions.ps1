# Scrape then download all content featuring the provided actor ID/s
function Get-AyloAllContentByActorIDs {
    param(
        [Parameter(Mandatory)][Int[]]$actorIDs,
        [Parameter(Mandatory)][String]$parentStudio,
        [Parameter(Mandatory)][String]$pathToUserConfig
    )

    foreach ($actorID in $actorIDs) {
        $sceneIDs = Get-AyloSceneIDsByActorID -actorID $actorID -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig

        foreach ($sceneID in $sceneIDs) {
            # TODO - Check for existing media - Create the scene JSON file ONLY
            # if the associated scene hasn't already been scraped.
            $pathToJson = Get-AyloSceneJson -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig -sceneID $sceneID
            
            if (($null -eq $pathToJson) -or (!(Test-Path $pathToJson))) {
                return Write-Host "ERROR: scene $sceneID JSON not found - $pathToJson" -ForegroundColor Red
            }
            else {
                $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
                $sceneData = Get-Content $pathToJson -raw | ConvertFrom-Json
                Get-AyloSceneAllMedia -data $sceneData -outputDir $userConfig.general.downloadDirectory
            }
        }
    }
}