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

    # Logging values - for use in the end report
    $numNewTags = 0
    $numNewParentTags = 0
    $numNewPerformers = 0

    # ---------------------------------------------------------------------------- #
    #                                  PERFORMERS                                  #
    # ---------------------------------------------------------------------------- #
    
    $actorsDir = Join-Path $dataDir "actor"
    $actorsData = Get-ChildItem $actorsDir -Filter "*.json"

    # Loop through each set of actor data
    foreach ($actor in $actorsData) {
        $actor = Get-Content $actor -raw | ConvertFrom-Json

        # ------------------------------ Performer tags ------------------------------ #

        $newTags = $actor.tags
        $newParentNames = @()
    
        # Get unique parent tags
        foreach ($tag in $newTags) {
            if ($tag.category -notin $newParentNames -and $tag.category.Length -gt 0) {
                $newParentNames += $tag.category.Trim()
            }
        }

        # Create new parent tags if they don't already exist
        foreach ($tagName in $newParentNames) {
            # Query Stash to see if the tag exists
            $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
                findTags(tag_filter: $tag_filter) {
                    tags { id }
                }
            }'
            $StashGQL_QueryVariables = '{
                "tag_filter": {
                    "name": {
                        "value": "[Category] '+ $tagName + '",
                        "modifier": "EQUALS"
                    }
                }
            }' 
    
            $existingTag = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables

            # If no data is found, create the new parent tag
            if ($existingTag.data.findTags.tags.count -eq 0) {
                $StashGQL_Query = 'mutation CreateTag($input: TagCreateInput!) {
                    tagCreate(input: $input) { name }
                }'
                $StashGQL_QueryVariables = '{
                    "input": {
                        "ignore_auto_tag": true,
                        "name": "[Category] '+ $tagName + '"
                    }
                }' 
                $null = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
                Write-Host "SUCCESS: Created parent tag $tagName." -ForegroundColor Green
                $numNewParentTags++
            }
        }

        # Create new tags if they don't already exist
        foreach ($tag in $newTags) {
            # Query Stash to see if the tag exists. Aliases include the tag ID,
            # which we use to query.
            $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
                findTags(tag_filter: $tag_filter) {
                    tags { id }
                }
            }'
            $StashGQL_QueryVariables = '{
                "tag_filter": {
                    "aliases": {
                        "value": "'+ $tag.id + '",
                        "modifier": "EQUALS"
                    }
                }
            }' 
    
            $existingTag = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables

            # If no data is found, also check to see if the tag exists under a
            # different ID.
            if ($existingTag.data.findTags.tags.count -eq 0) {
                $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
                    findTags(tag_filter: $tag_filter) {
                        tags {
                            aliases
                            id
                        }
                    }
                }'
                $StashGQL_QueryVariables = '{
                    "tag_filter": {
                        "name": {
                            "value": "'+ $tag.name.Trim() + '",
                            "modifier": "EQUALS"
                        }
                    }
                }'

                $existingTag = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables

                # If a matching tag name is found, update it with the new alias
                if ($existingTag.data.findTags.tags.count -gt 0) {
                    $tagAliases = $existingTag.data.findTags.tags[0].aliases
                    $tagAliases += $tag.id
                    $tagAliases = ConvertTo-Json $tagAliases -depth 32

                    $StashGQL_Query = 'mutation UpdateTag($input: TagUpdateInput!) {
                        tagUpdate(input: $input) { id }
                    }'
                    $StashGQL_QueryVariables = '{
                        "input": {
                            "id": '+ $existingTag.data.findTags.tags[0].id + ',
                            "aliases": '+ $tagAliases + '
                        }
                    }'
                    $existingTag = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
                }
            }

            # If no data is found, create the new tag
            if ($existingTag.data.findTags.tags.count -eq 0) {
                # Get the parent tag ID
                $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
                    findTags(tag_filter: $tag_filter) {
                        tags { id }
                    }
                }'
                $StashGQL_QueryVariables = '{
                    "tag_filter": {
                        "name": {
                            "value": "[Category] '+ $tag.category.Trim() + '",
                            "modifier": "EQUALS"
                        }
                    }
                }' 
    
                # Only search for the parent tag if it is not an empty string.
                if ($tag.category.Length -gt 0) {
                    $parentTag = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
                    
                    if ($parentTag.data.findTags.tags.count -eq 0) {
                        Write-Host "Parent tag '$($tag.category)' not found." -ForegroundColor Yellow
                    }
                    else { $parentTagID = $parentTag.data.findTags.tags[0].id }
                }

                # Create the tag
                if ($parentTagID) { $parentIDField = ', "parent_ids": ' + $parentTagID + '' }

                $StashGQL_Query = 'mutation CreateTag($input: TagCreateInput!) {
                    tagCreate(input: $input) {
                        aliases
                        name
                    }
                }'
                $StashGQL_QueryVariables = '{
                    "input": {
                        "aliases": "'+ $tag.id + '",
                        "ignore_auto_tag": true,
                        "name": "'+ $tag.name.Trim() + '"
                        '+ $parentIDField + '
                    }
                }' 
                $null = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
                Write-Host "SUCCESS: Created tag $($tag.name)." -ForegroundColor Green
                $numNewTags++
            }
        }

        # -------------------------------- Performers -------------------------------- #

        # Query Stash to see if the performer exists. Disambiguation is the
        # performer ID, which we use to query.
        $StashGQL_Query = 'query FindPerformers($performer_filter: PerformerFilterType) {
            findPerformers(performer_filter: $performer_filter) {
                performers { id }
            }
        }'
        $StashGQL_QueryVariables = '{
            "performer_filter": {
                "disambiguation": {
                    "value": "'+ $actor.id + '",
                    "modifier": "EQUALS"
                }
            }
        }' 

        $existingActor = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables

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

            # Convert the list into JSON
            $alias_list = ConvertTo-Json $alias_list -depth 32

            # Format birthdate
            $birthdate = ""
            if ($actor.birthday) {
                $birthdate = Get-Date $actor.birthday -format "yyyy-MM-dd"
                $birthdate = '"birthdate": "' + $birthdate + '",'
            }

            # Format details
            $details = ""
            if ($actor.bio) {
                # Need to escape the quotation marks in JSON.
                $details = $actor.bio.replace('"', '\"')
                $details = '"details": "' + $details + '",'
            }

            # Format gender
            $gender = $actor.gender
            if ($gender -eq "trans") { $gender = "TRANSGENDER_FEMALE" }
            $gender = $gender.ToUpper()

            # Format height (inches > cm)
            $height_cm = $null
            if ($actor.height) {
                $height_cm = [math]::Round($actor.height * 2.54)
                $height_cm = '"height_cm": ' + $height_cm + ','
            }

            # Format measurements - value is mostly gender dependent but this is
            # inconsistent.
            $measurements = ""
            if ($actor.measurements) {
                $measurements = $actor.measurements.Trim()
                if ($gender -like "FEMALE" -or $measurements -match "-") {
                    $measurements = '"measurements": "' + $measurements + '",'
                }
                else {
                    # Remove any unit from the string
                    $measurements = $measurements -replace "[^0-9]", ""

                    # Check if the value is a number, and if not don't use it
                    if ($measurements.Length -gt 0) {
                        # Convert inches to cm
                        $measurements = [Int]$measurements
                        $measurements = $measurements * 2.54
                        $measurements = '"penis_length": ' + $measurements + ','
                    }
                    else { $measurements = "" }
                }
            }

            # Format weight (lbs > kg)
            $weight = $null
            if ($actor.weight) {
                $weight = [math]::Round($actor.weight / 2.2046226218)
                $weight = '"weight": ' + $weight + ''
            }

            # Get tags
            $actorTagIDs = @()
            foreach ($tagID in $actor.tags.id) {
                # Query Stash to see if the tag exists. Aliases include the tag ID,
                # which we use to query.
                $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
                    findTags(tag_filter: $tag_filter) {
                        tags { id }
                    }
                }'
                $StashGQL_QueryVariables = '{
                    "tag_filter": {
                        "aliases": {
                            "value": "'+ $tagID + '",
                            "modifier": "EQUALS"
                        }
                    }
                }' 
    
                $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
                $actorTagIDs += $result.data.findTags.tags.id
            }
            $actorTagIDs = ConvertTo-Json $actorTagIDs -depth 32

            $StashGQL_Query = 'mutation CreatePerformer($input: PerformerCreateInput!) {
                performerCreate(input: $input) {
                    id
                }
            }'
            $StashGQL_QueryVariables = '{
                "input": {
                    "alias_list": '+ $alias_list + ',
                    '+ $birthdate + '
                    '+ $details + '
                    "disambiguation": "'+ $actor.id + '",
                    "gender": "'+ $gender + '",
                    '+ $height_cm + '
                    "ignore_auto_tag": true,
                    "image": "'+ $actor.images.profile."0".lg.url + '",
                    '+ $measurements + '
                    "name": "'+ $actor.name.Trim() + '",
                    "tag_ids": '+ $actorTagIDs + ',
                    '+ $weight + '
                }
            }' 

            $null = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
            Write-Host "SUCCESS: Created performer $($actor.name)." -ForegroundColor Green
            $numNewPerformers++
        }
    }
}