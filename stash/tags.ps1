# Get Stash tag data with the given tag alias name. Returns the graphql query.
function Get-StashTagByAlias {
    param(
        [Parameter(Mandatory)][String]$alias
    )
    $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
        findTags(tag_filter: $tag_filter) {
            tags {
                aliases
                id
                name
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "tag_filter": {
            "aliases": {
                "value": "'+ $alias + '",
                "modifier": "EQUALS"
            }
        }
    }'

    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}

# Get Stash tag data with the given tag name. Returns the graphql query.
function Get-StashTagByName {
    param(
        [Parameter(Mandatory)][String]$name
    )
    $StashGQL_Query = 'query FindTags($tag_filter: TagFilterType) {
        findTags(tag_filter: $tag_filter) {
            count
            tags {
                aliases
                id
                name
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "tag_filter": {
            "name": {
                "value": "'+ $name + '",
                "modifier": "EQUALS"
            }
        }
    }'

    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}

# Create a new tag in Stash with the given data. Returns the graphql result.
function Set-StashTag {
    param(
        [Parameter(Mandatory)][String]$name,
        [String[]]$aliases,
        [String[]]$parent_ids
    )
    if ($aliases -and $aliases.Count) {
        $aliases = ConvertTo-Json $aliases -depth 32
        $aliases = '"aliases": ' + $aliases + ','
    }

    if ($parent_ids -and $parent_ids.Count) {
        $parent_ids = ConvertTo-Json $parent_ids -depth 32
        $parent_ids = '"parent_ids": ' + $parent_ids + ','
    }

    $StashGQL_Query = 'mutation CreateTag($input: TagCreateInput!) {
        tagCreate(input: $input) {
            aliases
            id
            name
            parents {
                id
                name
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "input": {
            '+ $aliases + '
            "ignore_auto_tag": true,
            '+ $parent_ids + '
            "name": "'+ $name + '"
        }
    }'

    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $newTag = $result.data.tagCreate
    Write-Host "SUCCESS: Created tag $($newTag.name) (Stash ID $($newTag.id))." -ForegroundColor Green
    return $result
}

# Update an existing tag in Stash with the given data. Returns the graphql
# result.
function Set-StashTagUpdate {
    param(
        [Parameter(Mandatory)][String]$id,
        [String[]]$aliases
    )
    if ($aliases -and $aliases.Count) {
        $aliases = ConvertTo-Json $aliases -depth 32
        $aliases = '"aliases": ' + $aliases + ','
    }

    $StashGQL_Query = 'mutation UpdateTag($input: TagUpdateInput!) {
        tagUpdate(input: $input) {
            aliases
            id
            name
        }
    }'
    $StashGQL_QueryVariables = '{
        "input": {
            '+ $aliases + '
            "id": '+ $id + '
        }
    }'

    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $updatedTag = $result.data.tagUpdate
    Write-Host "SUCCESS: Updated tag $($updatedTag.name) (Stash ID $($updatedTag.id))." -ForegroundColor Green
    return $result
}

# Returns the ID for a process tag applied to a content item. If the tag does
# not exist, it will create it.
function Get-ProcessTagIDByName {
    param(
        [Parameter(Mandatory)][String]$tagName
    )

    $tagName = "| Process | $($tagName)"
    $tag = Get-StashTagByName $tagName
    
    if ($tag.data.findTags.count -eq 0) {
        $tag = Set-StashTag $tagName
        $tag = $tag.data.tagCreate
    } else {
        $tag = $tag.data.findTags.tags[0]
    }

    return $tag.id
}