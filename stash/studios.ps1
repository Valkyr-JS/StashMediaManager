# Get Stash studio data with the given studio name. Returns the graphql query
# result.
function Get-StashStudioByName {
    param(
        [Parameter(Mandatory)][String]$name
    )
    $StashGQL_Query = 'query FindStudiosByName($studio_filter: StudioFilterType) {
        findStudios(studio_filter: $studio_filter) {
            studios {
                id
                name
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "studio_filter": {
            "name": {
                "value": "'+ $name + '",
                "modifier": "EQUALS"
            }
        }
    }'

    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}

# Create a new studio in Stash with the given data. Returns the graphql query
# result.
function Set-StashStudio {
    param(
        [Parameter(Mandatory)][String]$name,
        [String[]]$aliases,
        [String]$details,
        [String]$image,
        [String]$parent_id,
        [String]$url
    )

    if ($aliases -and $aliases.Count) {
        $aliases = ConvertTo-Json $aliases -depth 32
        $aliases = '"aliases": ' + $aliases + ','
    }

    if ($details) {
        # Need to escape the quotation marks in JSON.
        $details = $details.replace('"', '\"')
        $details = '"details": "' + $details + '",'
    }

    if ($image) { $image = '"image": "' + $image + '",' }
    if ($parent_id) { $parent_id = '"parent_id": "' + $parent_id + '",' }
    if ($url) { $url = '"url": "' + $url + '",' }

    $StashGQL_Query = 'mutation CreateStudio($input: StudioCreateInput!) {
    studioCreate(input: $input) {
            aliases
            id
            name
        }
    }'
    $StashGQL_QueryVariables = '{
        "input": {
            '+ $aliases + '
            '+ $details + '
            '+ $parent_id + '
            '+ $image + '
            '+ $url + '
            "ignore_auto_tag": true,
            "name": "'+ $name + '"
        }
    }'
    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $newStudio = $result.data.studioCreate
    Write-Host "SUCCESS: Created studio $($newStudio.name) (Stash ID $($newStudio.id))." -ForegroundColor Green
    return $result
}