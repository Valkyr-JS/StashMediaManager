function Set-AFMetaToFormatStash {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    $userConfig = Get-Content -Raw $pathToUserConfig | ConvertFrom-Json

    # -------------------------- Origin Stash connection ------------------------- #

    # Ensure the URL to the origin (i.e. meta) Stash instance has been setup.
    if ($userConfig.addfriends.metaStashUrl.Length -eq 0) {
        $userConfig = Set-ConfigAFMetaStashURL -pathToUserConfig $pathToUserConfig
    }

    # Ensure that the origin Stash instance can be connected to
    do {
        $OriginGQL_Query = 'query version{version{version}}'
        $originURL = $userConfig.addfriends.metaStashUrl
        $originGQL_URL = $originURL
        if ($originURL[-1] -ne "/") { $originGQL_URL += "/" }
        $originGQL_URL += "graphql"
        
            
        Write-Host "Attempting to connect to origin Stash instance at $originURL"
        try {
            $originVersion = Invoke-GraphQLQuery -Query $OriginGQL_Query -Uri $originGQL_URL
        }
        catch {
            Write-Host "ERROR: Could not connect to origin Stash instance at $originURL" -ForegroundColor Red
            $userConfig = Set-ConfigAFMetaStashURL -pathToUserConfig $pathToUserConfig
        }
    }
    while ($null -eq $originVersion)
        
    $originVersion = $originVersion.data.version.version
    Write-Host "Connected to origin Stash instance at $originURL ($originVersion)" -ForegroundColor Green

    # Ensure the Stash URL doesn't have a trailing forward slash
    [string]$originUrl = $userConfig.addfriends.metaStashUrl
    if ($originUrl[-1] -eq "/") { $originUrl = $originUrl.Substring(0, $originUrl.Length - 1) }

    # Create a helper function for origin Stash GQL queries now that the
    # connection has been tested.
    function Get-OriginStashGQLQuery {
        param(
            [Parameter(Mandatory)][String]$query,
            [String]$variables
        )
        try {
            $result = Invoke-GraphQLQuery -Query $query -Uri "$originUrl/graphql" -Variables $variables
        }
        catch {
            Write-Host "ERROR: There was an issue with the GraphQL query/mutation." -ForegroundColor Red
            Write-Host "Query: `n$query"
            if ($variables) { Write-Host "Variables: `n$variables" }
            Write-Host "$_" -ForegroundColor Red
            Read-Host "Press [Enter] to exit"
            exit
        }
        return $result
    }

    # -------------------------- Target Stash connection ------------------------- #

    # Ensure the URL to the target (i.e. formatting) Stash instance has been
    # setup.
    if ($userConfig.addfriends.formatStashUrl.Length -eq 0) {
        $userConfig = Set-ConfigAFFormatStashURL -pathToUserConfig $pathToUserConfig
    }

    # Ensure that the target Stash instance can be connected to
    do {
        $StashGQL_Query = 'query version{version{version}}'
        $stashURL = $userConfig.addfriends.formatStashUrl
        $stashGQL_URL = $stashURL
        if ($stashURL[-1] -ne "/") { $stashGQL_URL += "/" }
        $stashGQL_URL += "graphql"
        
        Write-Host "Attempting to connect to target Stash at $stashURL"
        try {
            $stashVersion = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $stashGQL_URL
        }
        catch {
            Write-Host "ERROR: Could not connect to target Stash at $stashURL" -ForegroundColor Red
            $userConfig = Set-ConfigAFFormatStashURL -pathToUserConfig $pathToUserConfig
        }
    }
    while ($null -eq $stashVersion)
    
    $stashVersion = $stashVersion.data.version.version
    Write-Host "Connected to target Stash at $stashURL ($stashVersion)" -ForegroundColor Green
    
    # Ensure the Stash URL doesn't have a trailing forward slash
    [string]$stashUrl = $userConfig.addfriends.formatStashUrl
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

    # $dataDir = Join-Path $userConfig.general.scrapedDataDirectory "addfriends"
    # $modelArchiveDataDir = Join-Path $dataDir "model-archive"
    # $tagsDataDir = Join-Path $dataDir "tags"
    # $videoDataDir = Join-Path $dataDir "video"

    # Logging meta
    $metaPerformersCreated = 0
    $metaScenesUpdated = 0
    $metaStudiosCreated = 0

    # ---------------------------------------------------------------------------- #
    #                                    Scenes                                    #
    # ---------------------------------------------------------------------------- #

    # Fetch all target Stash scenes which are not marked as organized
    $StashGQL_Query = 'query FindUnorganizedScenes($filter: FindFilterType, $scene_filter: SceneFilterType) {
        findScenes(filter: $filter, scene_filter: $scene_filter) {
            scenes {
                files { path }
                id
                stash_ids {
                    endpoint
                    stash_id
                }
                title
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "filter": { "per_page": -1 },
        "scene_filter": {
            "organized": false
        }
    }' 
    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $stashScenesToProcess = [array]$result.data.findScenes.scenes

    foreach ($stashScene in $stashScenesToProcess) {
        Write-Host "Updating Stash scene $($stashScene.id)" -ForegroundColor Cyan

        # Get the matching scene in the origin stash instance
        $OriginGQL_Query = 'query FindMatchingOriginScene($filter: FindFilterType, $scene_filter: SceneFilterType) {
            findScenes(filter: $filter, scene_filter: $scene_filter) {
                scenes {
                    code
                    date
                    files { path }
                    id
                    paths { screenshot }
                    performers {
                        details
                        disambiguation
                        id
                        image_path
                        name
                        tags {
                            aliases
                            id
                            name
                        }
                        urls
                    }
                    studio {
                        aliases
                        details
                        image_path
                        name
                        parent_studio {
                            name
                            url
                        }
                        tags {
                            aliases
                            id
                            name
                        }
                    }
                    tags {
                        aliases
                        id
                        name
                    }
                    title
                    urls
                }
            }
        }'
        $OriginGQL_QueryVariables = '{
            "filter": {},
            "scene_filter": {
                "path": {
                    "value": "'+ $stashScene.files[0].path + '",
                    "modifier": "EQUALS"
                }
            }
        }'
        $result = Get-OriginStashGQLQuery -query $OriginGQL_Query -variables $OriginGQL_QueryVariables
        $originScene = $result.data.findScenes.scenes[0]

        # -------------------------------- Performers -------------------------------- #

        $performerIDs = @()

        # Loop through each performer in the origin scene data 
        foreach ($originPerformer in $originScene.performers) {
            # Check if the performer is in the target Stash
            $result = Get-StashPerformerByDisambiguation $originPerformer.disambiguation

            # If they exist, add them to the ID list
            if ($result.data.findPerformers.performers.count -gt 0) {
                $performerIDs += $result.data.findPerformers.performers[0].id
            }

            # Otherwise, add them to the target Stash instance
            else {
                # Create new tags that aren't in Stash yet.
                $performerTagIDS = @()
                Set-TagsFromStashTagList $originPerformer.tags

                # Fetch all tag IDs from Stash
                foreach ($tag in $originPerformer.tags) {
                    $result = Get-StashTagByAlias -alias $tag.aliases[0]
                    $performerTagIDS += $result.data.findTags.tags.id
                }
                
                # Create the new performer
                $stashPerformer = Set-StashPerformer -disambiguation $originPerformer.disambiguation -name $originPerformer.name -details $originPerformer.details -image $originPerformer.image_path -tag_ids $performerTagIDS -urls $originPerformer.urls

                $performerIDs += $stashPerformer.data.performerCreate.id

                $metaPerformersCreated++
            }
        }

        # ---------------------------------- Studio ---------------------------------- #

        # Check if the studio is already in Stash
        $stashStudio = Get-StashStudioByAlias "$($originScene.studio.aliases[0])"

        if ($stashStudio.data.findStudios.studios.count -eq 0) {
            # Check if the parent studio is already in Stash
            $stashParentStudioName = $originScene.studio.parent_studio.name
            $stashParentStudio = Get-StashStudioByName $stashParentStudioName
            
            if ($stashParentStudio.data.findStudios.studios.count -eq 0) { 
                $stashParentStudio = Set-StashStudio -name $stashParentStudioName -url $originScene.studio.parent_studio.name.url
                $stashParentStudioID = $stashParentStudio.data.studioCreate.id
                $metaStudiosCreated++
            }
            else {
                $stashParentStudioID = $stashParentStudio.data.findStudios.studios[0].id
            }

            # Get tags
            $tagIDs = @()
            foreach ($tag in $originScene.studio.tags) {
                $result = Get-StashTagByAlias -alias $tag.aliases[0]
                $tagIDs += $result.data.findTags.tags.id
            }
            
            $stashStudio = Set-StashStudio -name $originScene.studio.name -aliases $originScene.studio.aliases -details $originScene.studio.details -image $originScene.studio.image_path -parent_id $stashParentStudioID -tag_ids $tagIDs -url $originScene.url
            $stashStudio = Get-StashStudioByAlias "$($originScene.studio.aliases[0])"
            $metaStudiosCreated++
        }
        
        # ----------------------------- Update the scene ----------------------------- #

        # Create new tags that aren't in Stash yet
        if ($originScene.tags.count) { $null = Set-TagsFromStashTagList -tagList $originScene.tags }
    
        # Fetch all tag IDs from Stash
        $tagIDs = @()
        foreach ($tag in $originScene.tags) {
            $result = Get-StashTagByAlias -alias $tag.aliases[0]
            $tagIDs += $result.data.findTags.tags.id
        }
    
        # Update the scene
        $stashScene = Set-StashSceneUpdate -id $stashScene.id -code $originScene.code -cover_image $originScene.paths.screenshot -performer_ids $performerIDs -studio_id $stashStudio.data.findStudios.studios[0].id -tag_ids $tagIDs -title $originScene.title -urls $originScene.urls -date $originScene.date
        $metaScenesUpdated++
    }
    Write-Host "Scenes updated: $metaScenesUpdated"
    Write-Host "Performers created: $metaPerformersCreated"
}

# ---------------------------------------------------------------------------- #
#                              AddFriends helpers                              #
# ---------------------------------------------------------------------------- #

# Create Stash tags from a list of Stash tags in a different instance
function Set-TagsFromStashTagList {
    param (
        [Parameter(Mandatory)]$tagList
    )
    foreach ($tag in $tagList) {
        # Query the target Stash to see if the tag already exists. Aliases
        # include the tag ID, which we use to query.
        $existingTag = Get-StashTagByAlias -alias $tag.aliases[0]

        # If no data is found, also check to see if the tag exists under a
        # different AF ID.
        if ($existingTag.data.findTags.tags.count -eq 0) {

            # If a matching tag is found, update it with the new alias
            if ($existingTag.data.findTags.tags.count -gt 0) {
                $tagAliases = $existingTag.data.findTags.tags[0].aliases
                $tagAliases += $tag.aliases[0]
        
                $existingTag = Set-StashTagUpdate -id $existingTag.data.findTags.tags[0].id -aliases $tagAliases
            }
        
            # If no data is found, create the new tag
            else {
                # Add the "af-" prefix to the alias for the AddFriends tag.
                $aliases = @($tag.aliases[0])
        
                # Create the tag
                $null = Set-StashTag -name $tag.name -aliases $aliases
            }
        }
    }
}
