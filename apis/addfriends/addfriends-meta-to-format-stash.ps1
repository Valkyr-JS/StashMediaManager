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
            $userConfig = Set-ConfigAFFormatStashURL -pathToUserConfig $pathToUserConfig
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
            Invoke-GraphQLQuery -Query $query -Uri $OriginGQL_Query -Variables $variables
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
    $metaScenesUpdated = 0

    # ---------------------------------------------------------------------------- #
    #                                    Scenes                                    #
    # ---------------------------------------------------------------------------- #

    # Fetch all target Stash scenes not marked as organized
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
        "scene_filter": { "organized": false }
    }' 
    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $stashScenesToProcess = [array]$result.data.findScenes.scenes

    foreach ($stashScene in $stashScenesToProcess) {
        Write-Host $stashScene.title
    }
    Write-Host "Scenes updated: $metaScenesUpdated"
}