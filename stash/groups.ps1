# Get Stash group data with the given group name. Returns the graphql query
# result.
function Get-StashGroupByName {
    param(
        [Parameter(Mandatory)][String]$name
    )
    $StashGQL_Query = 'query FindGroupByName($group_filter: GroupFilterType) {
        findGroups(group_filter: $group_filter) {
            groups {
                aliases
                id
                name
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "group_filter": {
            "name": {
                "value": "'+ $name + '",
                "modifier": "EQUALS"
            }
        }
    }'
    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}

# Create a new group in Stash with the given data. Returns the graphql query
# result.
function Set-StashGroup {
    param(
        [Parameter(Mandatory)][String]$name,
        [String]$aliases,
        [String]$back_image,
        [String]$front_image,
        [String]$studio_id,
        [String]$synopsis,
        [String[]]$tag_ids,
        $date
    )

    # Aliases are currently limited to a single string in Stash groups, rather
    # than a list of string.
    if ($aliases) { $aliases = '"aliases": "' + $aliases + '",' }
    # if ($aliases -and $aliases.Count) {
    #     $aliases = ConvertTo-Json $aliases -depth 32
    #     $aliases = '"aliases": ' + $aliases + ','
    # }

    if ($date) {
        $date = Get-Date $date -format "yyyy-MM-dd"
        [string]$date = '"date": "' + $date + '",'
    }

    if ($studio_id) { $studio_id = '"studio_id": "' + $studio_id + '",' }

    if ($synopsis) {
        # Need to escape the quotation marks in JSON.
        $synopsis = $synopsis.replace('"', '\"')
        $synopsis = '"synopsis": "' + $synopsis + '",'
    }

    if ($tag_ids -and $tag_ids.Count) {
        $tag_ids = ConvertTo-Json $tag_ids -depth 32
        $tag_ids = '"tag_ids": ' + $tag_ids + ','
    }

    if ($front_image) { $front_image = '"front_image": "' + $front_image + '",' }
    if ($back_image) { $back_image = '"back_image": "' + $back_image + '",' }

    $StashGQL_Query = 'mutation CreateGroup($input: GroupCreateInput!) {
        groupCreate(input: $input) {
            aliases
            back_image_path
            date
            front_image_path
            id
            name
            studio {
                id
                name
            }
            synopsis
            tags {
                id
                name
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "input": {
            '+ $aliases + '
            '+ $date + '
            '+ $studio_id + '
            '+ $synopsis + '
            '+ $tag_ids + '
            '+ $front_image + '
            '+ $back_image + '
            "name": "'+ $name + '"
        }
    }'
    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $newGroup = $result.data.groupCreate
    Write-Host "SUCCESS: Created group $($newGroup.name) (Stash ID $($newGroup.id))." -ForegroundColor Green
    return $result
}