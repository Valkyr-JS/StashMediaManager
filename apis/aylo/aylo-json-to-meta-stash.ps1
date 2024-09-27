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

    # Get all JSON files
    $dataDir = Join-Path $userConfig.general.scrapedDataDirectory "aylo"
    $actorsDir = Join-Path $dataDir "actors"
    $actorsData = Get-ChildItem $actorsDir -Filter "*.json"

    # Logging values - for use in the end report
    $numNewTags = 0
    $numNewParentTags = 0

    # ---------------------------------------------------------------------------- #
    #                                  Scrape tags                                 #
    # ---------------------------------------------------------------------------- #

    $tagsData = @()
    $parentTagsNames = @()

    # Loop through each set of actor data
    foreach ($actor in $actorsData) {
        $actor = Get-Content $actor -raw | ConvertFrom-Json

        # Get any tags that haven't been found yet
        $newTags = $actor.tags | Where-Object { $_.id -notin $tagsData.id }
        
        foreach ($newTag in $newTags) {
            # Add the tag to the array
            $tagsData += $newTag

            # Check if the category has been found yet, and add it if it hasn't
            if ($newTag.category -notin $parentTagsNames -and $newTag.category.Length -gt 0) {
                $parentTagsNames += $newTag.category
            }
        }
    }
    
    Write-Host `n"============= TAGS ==============" -ForegroundColor Yellow
    foreach ($tag in $tagsData) {
        Write-Host "* $($tag.id) $($tag.name)"
    }
    
    Write-Host `n"========== PARENT TAGS ==========" -ForegroundColor Yellow
    foreach ($tagName in $parentTagsNames) {
        Write-Host "* $tagName"
    }

    # Create new parent tags if they don't already exist
    foreach ($tagName in $parentTagsNames) {
        # Query Stash to see if the tag exists
        $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
            findTags(tag_filter: $tag_filter) {
                tags {
                    id
                }
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
                tagCreate(input: $input) {
                    name
                }
            }'
            $StashGQL_QueryVariables = '{
                "input": {
                    "name": "[Category] '+ $tagName + '"
                }
            }' 
            $null = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
            Write-Host "SUCCESS: Created parent tag $tagName." -ForegroundColor Green
            $numNewParentTags++
        }
        else { Write-Host "Parent tag $tagName already exists in the Stash database." }
    }


    # TODO - Create new tags if they don't already exist
}