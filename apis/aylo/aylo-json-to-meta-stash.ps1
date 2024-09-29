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

        $newTags = @()
        $newParentNames = @()
    
        # Get any tags that haven't been found yet
        foreach ($tag in $actor.tags | Where-Object { $_.id -notin $newTags.id }) {
            # Add the tag to the array
            $newTags += $tag

            # Check if the category has been found yet, and add it if it hasn't
            if ($tag.category -notin $newParentNames -and $tag.category.Length -gt 0) {
                $newParentNames += $tag.category
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
                    "aliases": {
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
                            "value": "[Category] '+ $tag.category + '",
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

                if ($existingTag.data.findTags.tags.count -eq 0) {
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
                                    "name": "'+ $tag.name + '"
                                    '+ $parentIDField + '
                                }
                            }' 
                    $null = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
                    Write-Host "SUCCESS: Created tag $($tag.name)." -ForegroundColor Green
                    $numNewTags++
                }
            }
        }

        # -------------------------------- Performers -------------------------------- #

        # Query Stash to see if the performer exists. Aliases include the
        # performer ID, which we use to query.
        $StashGQL_Query = 'query FindPerformers($performer_filter: PerformerFilterType) {
            findPerformers(performer_filter: $performer_filter) {
                performers { id }
            }
        }'
        $StashGQL_QueryVariables = '{
            "performer_filter": {
                "aliases": {
                    "value": "'+ $actor.id + '",
                    "modifier": "EQUALS"
                }
            }
        }' 

        $existingActor = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables

        # If no data is found, create the new tag
        if ($existingActor.data.findPerformers.performers.count -eq 0) {

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

            $StashGQL_Query = 'mutation CreatePerformer($input: PerformerCreateInput!) {
                performerCreate(input: $input) {
                    id
                }
            }'
            $StashGQL_QueryVariables = '{
                "input": {
                    "alias_list": ["'+ $actor.id + '"],
                    '+ $birthdate + '
                    '+ $details + '
                    "gender": "'+ $gender + '",
                    "ignore_auto_tag": true,
                    "image": "'+ $actor.images.profile."0".lg.url + '",
                    "name": "'+ $actor.name + '"
                }
            }' 

            $null = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
            Write-Host "SUCCESS: Created tag $($tag.name)." -ForegroundColor Green
            $numNewPerformers++
        }
    }
}