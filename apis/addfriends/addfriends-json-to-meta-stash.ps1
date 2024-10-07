function Set-AFJsonToMetaStash {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    $userConfig = Get-Content -Raw $pathToUserConfig | ConvertFrom-Json

    # Ensure the URL to the Stash instance has been setup
    if ($userConfig.addfriends.stashUrl.Length -eq 0) {
        $userConfig = Set-ConfigAddFriendsStashURL -pathToUserConfig $pathToUserConfig
    }

    # Ensure that the Stash instance can be connected to
    do {
        $StashGQL_Query = 'query version{version{version}}'
        $stashURL = $userConfig.addfriends.stashUrl
        $stashGQL_URL = $stashURL
        if ($stashURL[-1] -ne "/") { $stashGQL_URL += "/" }
        $stashGQL_URL += "graphql"
        
        Write-Host "Attempting to connect to Stash at $stashURL"
        try {
            $stashVersion = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $stashGQL_URL
        }
        catch {
            Write-Host "ERROR: Could not connect to Stash at $stashURL" -ForegroundColor Red
            $userConfig = Set-ConfigAddFriendsStashURL -pathToUserConfig $pathToUserConfig
        }
    }
    while ($null -eq $stashVersion)
    
    $stashVersion = $stashVersion.data.version.version
    Write-Host "Connected to Stash at $stashURL ($stashVersion)" -ForegroundColor Green
    
    # Ensure the Stash URL doesn't have a trailing forward slash
    [string]$stashUrl = $userConfig.addfriends.stashUrl
    if ($stashUrl[-1] -eq "/") { $stashUrl = $stashUrl.Substring(0, $stashUrl.Length - 1) }

    # Create a helper function for Stash GQL queries now that the connection has
    # been tested.
    function Invoke-StashGQLQuery {
        param(
            [Parameter(Mandatory)][String]$query,
            [String]$variables
        )
        try {
            Invoke-GraphQLQuery -Query $query -Uri $StashGQL_URL -Variables $variables
        }
        catch {
            Write-Host "ERROR: There was an issue with the GraphQL query/mutation." -ForegroundColor Red
            Write-Host "Query: `n$query"
            if ($variables) { Write-Host "Variables: `n$variables" }
            Write-Host "$_" -ForegroundColor Red
            Read-Host "Press [Enter] to exit"
            exit
        }

    }
    
    # --------------------------- Ask for Stash backup --------------------------- #
    
    Invoke-StashBackupRequest

    $dataDir = Join-Path $userConfig.general.scrapedDataDirectory "addfriends"
    $modelArchiveDataDir = Join-Path $dataDir "model-archive"
    $tagsDataDir = Join-Path $dataDir "tags"
    $videoDataDir = Join-Path $dataDir "video"

    # Logging meta
    $metaScenesUpdated = 0

    # ---------------------------------------------------------------------------- #
    #                                    Scenes                                    #
    # ---------------------------------------------------------------------------- #

    # Fetch all Stash scenes not marked as organized
    $StashGQL_Query = 'query FindUnorganizedScenes($filter: FindFilterType, $scene_filter: SceneFilterType) {
        findScenes(filter: $filter, scene_filter: $scene_filter) {
            scenes {
                files { path }
                id
                title
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "filter": { "per_page": -1 }
    }' 
    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $stashScenesToProcess = [array]$result.data.findScenes.scenes

    foreach ($stashScene in $stashScenesToProcess) {
        Write-Host "Updating Stash scene $($stashScene.id)" -ForegroundColor Cyan

        # Get the associated data file
        $afID = $stashScene.files.path.split("/")[4].split(" ")[0]
        $sceneData = Get-ChildItem -Path $videoDataDir -Recurse -File -Filter "*.json" | Where-Object { $_.BaseName -match "^$afID\s" }
        
        if (!($sceneData)) {
            Write-Host "FAILED: No data file found that matches Stash scene $($stashScene.id)." -ForegroundColor Red
        }
        else {
            $sceneData = Get-Content $sceneData -raw | ConvertFrom-Json

            # --------------------------------- Performer -------------------------------- #

            # There is no dedicated performer data available, other than the
            # data for the content creator page. Use this to create a performer.

            # Get the associated data file
            $pageID = $sceneData.site_id
            $pageData = Get-ChildItem -Path $modelArchiveDataDir -Recurse -File -Filter "*.json" | Where-Object { $_.BaseName -match "^$pageID\s" }

            $performerIDs = @()

            if (!($pageData)) {
                Write-Host "FAILED: No data file found that matches AddFriends page $pageID." -ForegroundColor Red
            }
            else {
                # Get the most recently scraped data
                $pageData = Get-Content $pageData[$pageData.Count - 1] -raw | ConvertFrom-Json

                # Create new tags that aren't in Stash yet. 
                if ($pageData.site.tags.Count) { $null = Set-TagsFromAFTagList -tagList $pageData.site.tags }

                # Query Stash to see if the performer exists. Disambiguation is the
                # performer ID, which we use to query.
                $existingPerformer = Get-StashPerformerByDisambiguation -disambiguation $pageData.site.id

                # If no data is found, create the new performer
                if ($existingPerformer.data.findPerformers.performers.count -eq 0) {

                    # URLs
                    $urls = @("https://addfriends.com/$($pageData.site.site_url)")
                    if ($pageData.site.free_snapchat) {
                        $urls += "https://www.snapchat.com/add/$($pageData.site.free_snapchat)"
                    }
            
                    # Get tags
                    $tagIDs = @()
                    foreach ($id in $pageData.site.tags.hashtag_id) {
                        $result = Get-StashTagByAlias -alias "af-$id"
                        $tagIDs += $result.data.findTags.tags.id
                    }

                    $stashPerformer = Set-StashPerformer -disambiguation $pageData.site.id -name $pageData.site.site_name -details $pageData.site.news -image "https://static.addfriends.com/images/friends/$($pageData.site.site_url).jpg" -tag_ids $tagIDs -urls $urls

                    $performerIDs += $stashPerformer.data.performerCreate.id
                }
                else {
                    $performerIDs += $existingPerformer.data.findPerformers.performers[0].id
                }

                # ---------------------------------- Studio ---------------------------------- #

                # Check if the studio is already in Stash
                $stashStudio = Get-StashStudioByAlias "af-$($pageData.site.id)"

                if ($stashStudio.data.findStudios.studios.count -eq 0) {
                    # Check if the parent studio is already in Stash
                    $stashParentStudioName = "+AddFriends (network)"
                    $stashParentStudio = Get-StashStudioByName $stashParentStudioName
            
                    if ($stashParentStudio.data.findStudios.studios.count -eq 0) { 
                        $stashParentStudio = Set-StashStudio -name $stashParentStudioName -url "https://addfriends.com/"
                        $stashParentStudioID = $stashParentStudio.data.studioCreate.id
                    }
                    else {
                        $stashParentStudioID = $stashParentStudio.data.findStudios.studios[0].id
                    }
            
                    $aliases = @("af-$($pageData.site.id)")
            
                    $details = $null
                    if ($pageData.site.news) { $details = $pageData.site.news }
            
                    $image = "https://static.addfriends.com/images/friends/$($pageData.site.site_url).jpg"
                    
                    $url = "https://addfriends.com/$($pageData.site.site_url)"

                    # Get tags
                    $tagIDs = @()
                    foreach ($id in $pageData.site.tags.hashtag_id) {
                        $result = Get-StashTagByAlias -alias "af-$id"
                        $tagIDs += $result.data.findTags.tags.id
                    }
            
                    $stashStudio = Set-StashStudio -name $pageData.site.site_name -aliases $aliases -details $details -image $image -parent_id $stashParentStudioID -tag_ids $tagIDs -url $url
                    $stashStudio = Get-StashStudioByAlias "af-$($pageData.site.id)"
                }
            }

            # ----------------------------------- Tags ----------------------------------- #

            # Get the associated tags data file
            $tagsData = Get-ChildItem -Path $tagsDataDir -Recurse -File -Filter "*.json" | Where-Object { $_.BaseName -match "^$afID\s" }
            $tagsData = Get-Content $tagsData -raw | ConvertFrom-Json
            $tagIDs = @()

            if (!($tagsData)) {
                Write-Host "FAILED: No tags data file found that matches Stash scene $($stashScene.id)." -ForegroundColor Red
            }
            else {
                # Create new tags that aren't in Stash yet
                if ($tagsData.Count) { $null = Set-TagsFromAFTagList -tagList $tagsData }
    
                # Fetch all tag IDs from Stash
                foreach ($id in $tagsData.hashtag_id) {
                    $result = Get-StashTagByAlias -alias "af-$id"
                    $tagIDs += $result.data.findTags.tags.id
                }
            }

            # -------------------------------- Other data -------------------------------- #

            # Non-members URL
            [array]$urls = @("https://addfriends.com/vip/video/$($sceneData.id)")

            # Post
            $posterCdnFilename = $sceneData.file_name.split(".")[0]
            $gifUrl = "https://static.addfriends.com/vip/posters/$posterCdnFilename.gif"

            # Update the scene
            $stashScene = Set-StashSceneUpdate -id $stashScene.id -code $sceneData.id -cover_image $gifUrl -performer_ids $performerIDs -studio_id $stashStudio.data.findStudios.studios[0].id -tag_ids $tagIDs -title $sceneData.title -urls $urls -date $sceneData.released_date
            $metaScenesUpdated++
        }
    }

    Write-Host `n"All updates complete" -ForegroundColor Cyan
    Write-Host "Scenes updated: $metaScenesUpdated"
}

# ---------------------------------------------------------------------------- #
#                              AddFriends helpers                              #
# ---------------------------------------------------------------------------- #

# Create Stash tags from a list of AddFriends parent tags
function Set-TagsFromAFTagList {
    param (
        [Parameter(Mandatory)]$tagList
    )
    foreach ($tag in $tagList) {
        # Query Stash to see if the tag exists. Aliases include the tag ID,
        # which we use to query. Make sure to include the "af-" prefix.
        $existingTag = Get-StashTagByAlias -alias "af-$($tag.hashtag_id)"
        
        # If no data is found, also check to see if the tag exists under a
        # different ID.
        if ($existingTag.data.findTags.tags.count -eq 0) {
            $existingTag = Get-StashTagByName -name $tag.hash_tag.Trim()
        
            # If a matching tag name is found, update it with the new alias
            if ($existingTag.data.findTags.tags.count -gt 0) {
                $tagAliases = $existingTag.data.findTags.tags[0].aliases
                $tagAliases += "af-$($tag.id)"
        
                $existingTag = Set-StashTagUpdate -id $existingTag.data.findTags.tags[0].id -aliases $tagAliases
            }
        
            # If no data is found, create the new tag
            else {
                # Add the "af-" prefix to the alias for the AddFriends tag.
                $aliases = @()
                $aliases += "af-$($tag.hashtag_id)"
        
                # Create the tag
                $null = Set-StashTag -name $tag.hash_tag.Trim() -aliases $aliases
            }
        }
    }
}
