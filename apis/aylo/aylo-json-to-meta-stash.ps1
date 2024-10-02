function Set-AyloJsonToMetaStash {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig
    )
    $userConfig = Get-Content -Raw $pathToUserConfig | ConvertFrom-Json

    # Ensure the URL to the Stash instance has been setup
    if ($userConfig.aylo.stashUrl.Length -eq 0) {
        $userConfig = Set-ConfigAyloStashURL -pathToUserConfig $pathToUserConfig
    }

    # Ensure that the Stash instance can be connected to
    do {
        $StashGQL_Query = 'query version{version{version}}'
        $stashURL = $userConfig.aylo.stashUrl
        $stashGQL_URL = $stashURL
        if ($stashURL[-1] -ne "/") { $stashGQL_URL += "/" }
        $stashGQL_URL += "graphql"
        
        Write-Host "Attempting to connect to Stash at $stashURL"
        try {
            $stashVersion = Invoke-GraphQLQuery -Query $StashGQL_Query -Uri $stashGQL_URL
        }
        catch {
            Write-Host "ERROR: Could not connect to Stash at $stashURL" -ForegroundColor Red
            $userConfig = Set-ConfigAyloStashURL -pathToUserConfig $pathToUserConfig
        }
    }
    while ($null -eq $stashVersion)
    
    $stashVersion = $stashVersion.data.version.version
    Write-Host "Connected to Stash at $stashURL ($stashVersion)" -ForegroundColor Green
    
    # Ensure the Stash URL doesn't have a trailing forward slash
    [string]$stashUrl = $userConfig.aylo.stashUrl
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
    
    do {
        $backupConfirmation = Read-Host `n"Would you like to make a backup of your Stash Database first? [Y/N]"
    }
    while ($backupConfirmation -notlike "Y" -and $backupConfirmation -notlike "N")
    
    if (($backupConfirmation -like "Y")) {
        $StashGQL_Query = 'mutation BackupDatabase($input: BackupDatabaseInput!) {
            backupDatabase(input: $input)
        }'
        $StashGQL_QueryVariables = '{
            "input": {}
        }' 
    
        Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
        Write-Host "SUCCESS: Backup created" -ForegroundColor Green
    }
    else { Write-Host "Backup will not be created." }

    $dataDir = Join-Path $userConfig.general.scrapedDataDirectory "aylo"
    $actorsDataDir = Join-Path $dataDir "actor"
    $scenesDataDir = Join-Path $dataDir "scene"

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
        "filter": { "per_page": -1 },
        "scene_filter": {
            "organized": false,
            "path": {
                "value": "/scene/",
                "modifier": "MATCHES_REGEX"
            }
        }
    }' 

    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $stashScenesToProcess = [array]$result.data.findScenes.scenes

    foreach ($stashScene in $stashScenesToProcess) {
        Write-Host "Updating Stash scene $($stashScene.id)" -ForegroundColor Cyan

        # Get the associated data file
        $ayloID = $stashScene.files.path.split("/")[5].split(" ")[0]
        $sceneData = Get-ChildItem -Path $scenesDataDir -Recurse -File -Filter "*.json" | Where-Object { $_.BaseName -match "^$ayloID\s" }

        if (!($sceneData)) {
            Write-Host "FAILED: No data file found that matches Stash scene $($stashScene.id)." -ForegroundColor Red
        }
        else {
            $sceneData = Get-Content $sceneData -raw | ConvertFrom-Json

            # -------------------------------- Performers -------------------------------- #

            # Create any performers that aren't in Stash yet
            $null = Set-PerformersFromActorList -actorsDataDir $actorsDataDir -actorList $sceneData.actors

            # Fetch all performer IDs from Stash
            $performerIDs = @()
            foreach ($id in $sceneData.actors.id) {
                $result = Get-StashPerformerByDisambiguation -disambiguation $id
                $performerIDs += $result.data.findPerformers.performers.id
            }

            # ----------------------------------- Tags ----------------------------------- #

            # Create any parent tags that aren't in Stash yet
            [array]$parentTagNames = Get-ParentTagsFromTagsList -tagList $sceneData.tags
            if ($parentTagNames.Count) { $null = Set-ParentTagsFromTagNameList -tagList $parentTagNames }

            # Create new tags that aren't in Stash yet
            if ($sceneData.tags.Count) { $null = Set-TagsFromTagList -tagList $sceneData.tags }
    
            # Fetch all tag IDs from Stash
            $tagIDs = @()
            foreach ($id in $sceneData.tags.id) {
                $result = Get-StashTagByAlias -alias "aylo-$id"
                $tagIDs += $result.data.findTags.tags.id
            }

            # ----------------------------------- URLs ----------------------------------- #

            [array]$urls = @()

            # Non-members URL
            $slug = $sceneData.title -replace "ï¿½", "i-" # Fix for some corrupted titles in BB.
            $slug = $slug -replace "[^\w\s-]", "" # Remove all characters that aren't letters, numbers, spaces, or hyphens
            $slug = $slug -replace " ", "-" # Replace spaces with hyphens
            $slug = Get-TextWithoutDiacritics $slug # Simplify diacritics
            $slug = $slug.ToLower()

            # The page uses either .com/scene/... or .com/video/... depending on the site.
            $mediaName = "video"
            $mediaSceneBrands = @("realitykings", "twistys")
            if ($mediaSceneBrands -contains $sceneData.brand) { $mediaName = "scene" }

            $publicUrl = "https://www." + $sceneData.brand + ".com/" + $mediaName + "/" + $sceneData.id + "/"
            $publicUrl += $slug

            $urls += $publicUrl

            # Update the scene
            $null = Set-StashSceneUpdate -id $stashScene.id -code $sceneData.id -cover_image $sceneData.images.poster."0".xx.url -details $sceneData.description -performer_ids $performerIDs -tag_ids $tagIDs -title $sceneData.title -urls $urls -date $sceneData.dateReleased
            $metaScenesUpdated++
        }
    }

    Write-Host "All updates complete" -ForegroundColor Cyan
    Write-Host "Scenes updated: $metaScenesUpdated"
}

# ---------------------------------------------------------------------------- #
#                                 Aylo helpers                                 #
# ---------------------------------------------------------------------------- #

# Get all Aylo parent tag names from a list of Aylo tags
function Get-ParentTagsFromTagsList {
    param(
        [Parameter(Mandatory)]$tagList
    )
    $parentTagNames = @()
    foreach ($tag in $tagList) {
        if ($tag.category -notin $parentTagNames -and $tag.category.Length -gt 0) {
            $parentTagNames += $tag.category.Trim()
        }
    }
    return $parentTagNames
}

# Create Stash tags from a list of Aylo parent tags names
function Set-ParentTagsFromTagNameList {
    param (
        [Parameter(Mandatory)][String[]]$tagList
    )
    foreach ($tagName in $tagList) {
        $existingTag = Get-StashTagByName "[Category] $tagName"

        # If no data is found, create the new parent tag
        if ($existingTag.data.findTags.tags.count -eq 0) {
            $null = Set-StashTag -name "[Category] $tagName"
        }
    }
}

# Create Stash tags from a list of Aylo parent tags
function Set-TagsFromTagList {
    param (
        [Parameter(Mandatory)]$tagList
    )
    foreach ($tag in $tagList) {
        # Query Stash to see if the tag exists. Aliases include the tag ID,
        # which we use to query. Make sure to include the "aylo-" prefix.
        $existingTag = Get-StashTagByAlias -alias "aylo-$($tag.id)"
        
        # If no data is found, also check to see if the tag exists under a
        # different ID.
        if ($existingTag.data.findTags.tags.count -eq 0) {
            $existingTag = Get-StashTagByName -name $tag.name.Trim()
        
            # If a matching tag name is found, update it with the new alias
            if ($existingTag.data.findTags.tags.count -gt 0) {
                $tagAliases = $existingTag.data.findTags.tags[0].aliases
                $tagAliases += "aylo-$($tag.id)"
        
                $existingTag = Set-StashTagUpdate -id $existingTag.data.findTags.tags[0].id -aliases $tagAliases
            }
        
            # If no data is found, create the new tag
            else {
                $parentTagID = $null
                # Get the parent tag ID if there is one
                if ($tag.category.Trim().Length -gt 0) {
                    $parentTag = Get-StashTagByName -name "[Category] $($tag.category.Trim())"
                    if ($parentTag.data.findTags.tags.count -gt 0) {
                        $parentTagID = $parentTag.data.findTags.tags[0].id
                    }
                }

                # Add the "aylo-" prefix to the alias for the Aylo tag.
                $aliases = @()
                $aliases += "aylo-$($tag.id)"
        
                # Create the tag
                $null = Set-StashTag -name $tag.name.Trim() -aliases $aliases -parent_ids $parentTagID
            }
        }
    }
}

# Create missing Stash performers from a list of Aylo actors
function Set-PerformersFromActorList {
    param (
        [Parameter(Mandatory)][String]$actorsDataDir,
        [Parameter(Mandatory)][array]$actorList
    )

    foreach ($actor in $actorList) {
        # Get the associated data file
        $ayloID = $actor.id
        $actorData = Get-ChildItem -Path $actorsDataDir -Recurse -File -Filter "*.json" | Where-Object { $_.BaseName -match "^$ayloID\s" }
        
        if (!($actorData)) {
            Write-Host "FAILED: No data file found that matches Aylo performer $ayloID." -ForegroundColor Red
        }
        else {
            $actorData = Get-Content $actorData -raw | ConvertFrom-Json

            # ------------------------------ Performer tags ------------------------------ #

            # Create any parent tags that aren't in Stash yet
            [array]$parentTagNames = Get-ParentTagsFromTagsList -tagList $actorData.tags
            if ($parentTagNames.Count) { $null = Set-ParentTagsFromTagNameList -tagList $parentTagNames }

            # Create new tags that aren't in Stash yet
            if ($actorData.tags.Count) { $null = Set-TagsFromTagList -tagList $actorData.tags }

            # --------------------------------- Performer -------------------------------- #

            # Query Stash to see if the performer exists. Disambiguation is the
            # performer ID, which we use to query.
            $existingPerformer = Get-StashPerformerByDisambiguation $actorData.id

            # If no data is found, create the new performer
            if ($existingPerformer.data.findPerformers.performers.count -eq 0) {

                # Format alias list
                [array]$alias_list = @()
                if ($actorData.aliases.count -gt 0) {
                    foreach ($alias in $aliases) {
                        # Add each valid alias to the list
                        if ($alias.Trim().Length -gt 0) {
                            $alias_list += "$($alias.Trim())"
                        }
                    }
                }
        
                # Format gender
                $gender = $actorData.gender
                if ($gender -eq "trans") { $gender = "TRANSGENDER_FEMALE" }
                $gender = $gender.ToUpper()
        
                # Format measurements / penis length - value is mostly gender
                # dependent but this is inconsistent.
                $measurements = $null
                $penis_length = $null
                $measurementsAsPlength = $gender -like "FEMALE" -or $measurements -match "-"
                if ($actorData.measurements) {
                    if ($measurementsAsPlength) {
                        $measurements = $actorData.measurements
                    }
                    else {
                        # Remove any unit from the string
                        $penis_length = $actorData.measurements -replace "[^0-9]", ""
        
                        # Check if the value is a number, and if not don't use it
                        if ($penis_length) {
                            # Convert inches to cm
                            $penis_length = Get-InchesToCm ([Int]$penis_length)
                        }
                    }
                }
        
                # Get tags
                $tagIDs = @()
                foreach ($id in $actorData.tags.id) {
                    $result = Get-StashTagByAlias -alias "aylo-$id"
                    $tagIDs += $result.data.findTags.tags.id
                }
            
                $null = Set-StashPerformer -disambiguation $actorData.id -name $actorData.name -gender $gender -alias_list $alias_list -birthdate $actorData.birthday -details $actorData.bio -height_cm ([math]::Round((Get-InchesToCm $actorData.height))) -image $actorData.images.profile."0".lg.url -measurements $measurements -penis_length $penis_length -weight ([math]::Round((Get-LbsToKilos $actorData.weight))) -tag_ids $tagIDs
            }
        }
    }
}