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
            Get-AyloSceneJson -parentStudio $parentStudio -pathToUserConfig $pathToUserConfig -sceneID $sceneID
        }
    }
}