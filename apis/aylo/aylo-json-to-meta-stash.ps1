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

    # ---------------------------------------------------------------------------- #
    #                                  PERFORMERS                                  #
    # ---------------------------------------------------------------------------- #
    
    $actorsDir = Join-Path $dataDir "actor"
    $actorsData = Get-ChildItem $actorsDir -Filter "*.json"

    # Loop through each set of actor data
    foreach ($actor in $actorsData) {
        $actor = Get-Content $actor -raw | ConvertFrom-Json

        # ------------------------------ Performer tags ------------------------------ #

        [array]$newTags = $actor.tags
        [array]$newParentNames = Get-ParentTagsFromTagsList -tagList $actor.tags

        # Create new parent tags if they don't already exist
        if ($newParentNames.Count) { $null = Set-ParentTagsFromTagNameList -tagList $newParentNames }

        # Create new tags if they don't already exist
        if ($newTags.Count) { $null = Set-TagsFromTagList -tagList $newTags }

        # -------------------------------- Performers -------------------------------- #

        # Query Stash to see if the performer exists. Disambiguation is the
        # performer ID, which we use to query.
        $existingActor = Get-StashPerformerByDisambiguation $actor.id

        # If no data is found, create the new performer
        if ($existingActor.data.findPerformers.performers.count -eq 0) {

            # Format alias list
            [array]$alias_list = @()
            if ($actor.aliases.count -gt 0) {
                foreach ($alias in $aliases) {
                    # Add each valid alias to the list
                    if ($alias.Trim().Length -gt 0) {
                        $alias_list += "$($alias.Trim())"
                    }
                }
            }

            # Format gender
            $gender = $actor.gender
            if ($gender -eq "trans") { $gender = "TRANSGENDER_FEMALE" }
            $gender = $gender.ToUpper()

            # Format measurements / penis length - value is mostly gender
            # dependent but this is inconsistent.
            $measurements = $null
            $penis_length = $null
            $measurementsAsPlength = $gender -like "FEMALE" -or $measurements -match "-"
            if ($actor.measurements) {
                if ($measurementsAsPlength) {
                    $measurements = $actor.measurements
                }
                else {
                    # Remove any unit from the string
                    $penis_length = $actor.measurements -replace "[^0-9]", ""

                    # Check if the value is a number, and if not don't use it
                    if ($penis_length) {
                        # Convert inches to cm
                        $penis_length = Get-InchesToCm ([Int]$penis_length)
                    }
                }
            }

            # Get tags
            $actorTagIDs = @()
            foreach ($tagID in $actor.tags.id) {
                $result = Get-StashTagByAlias -alias "aylo-$tagID"
                $actorTagIDs += $result.data.findTags.tags.id
            }

            $null = Set-StashPerformer -disambiguation $actor.id -name $actor.name -gender $gender -alias_list $alias_list -birthdate $actor.birthday -details $actor.bio -height_cm ([math]::Round((Get-InchesToCm $actor.height))) -image $actor.images.profile."0".lg.url -measurements $measurements -penis_length $penis_length -weight ([math]::Round((Get-LbsToKilos $actor.weight))) -tag_ids $actorTagIDs
        }
    }

    # ---------------------------------------------------------------------------- #
    #                                    Scenes                                    #
    # ---------------------------------------------------------------------------- #


    $scenesDir = Join-Path $dataDir "scene"
    $scenesData = Get-ChildItem -Path $scenesDir -Recurse -File -Filter "*.json"

    foreach ($scene in $scenesData) {
        $scene = Get-Content $scene -raw | ConvertFrom-Json
        Write-Host `n"Starting update for $($scene.title)" -ForegroundColor Cyan

        # -------------------------------- Scene tags -------------------------------- #

        [array]$newTags = $scene.tags
        [array]$newParentNames = Get-ParentTagsFromTagsList -tagList $scene.tags

        # Create new parent tags if they don't already exist
        if ($newParentNames.Count) { $null = Set-ParentTagsFromTagNameList -tagList $newParentNames }

        # Create new tags if they don't already exist
        if ($newTags.Count) { $null = Set-TagsFromTagList -tagList $newTags }

        # ---------------------------------- Scenes ---------------------------------- #

        # Query Stash to see if the scene already exists and data has been added.
        # $existingScene = Get-StashSceneByCode $scene.id

        # If no data is found, query Stash to see if the scene exists but hasn't
        # had data added yet.
        # if ($existingScene.data.findScenes.scenes.count -eq 0) {
        $existingScene = Get-StashSceneByIdInPath $scene.id
        if ($existingScene.data.findScenes.scenes.count -eq 0) {
            Write-Host "Scene $($scene.title) not found in Stash." -ForegroundColor Yellow
        }
        else {
            # Get performers
            $performerIDs = @()
            foreach ($id in $scene.actors.id) {
                $result = Get-StashPerformerByDisambiguation -disambiguation $id
                $performerIDs += $result.data.findPerformers.performers.id
            }

            # Get tags
            $tagIDs = @()
            foreach ($id in $scene.tags.id) {
                $result = Get-StashTagByAlias -alias "aylo-$id"
                $tagIDs += $result.data.findTags.tags.id
            }

            # Update the found scene
            $null = Set-StashSceneUpdate -id $existingScene.data.findScenes.scenes.id -code $scene.id -cover_image $scene.images.poster."0".xx.url -details $scene.description -performer_ids $performerIDs -tag_ids $tagIDs -title $scene.title -date $scene.dateReleased
        }
    }
    # }
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