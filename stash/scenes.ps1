# Get Stash scene data with the given studio code. Returns the graphql query.
function Get-StashSceneByCode {
    param (
        [Parameter(Mandatory)][String]$code
    )

    $StashGQL_Query = 'query FindSceneByCode($scene_filter: SceneFilterType) {
        findScenes(scene_filter: $scene_filter) {
            scenes {
                code
                id
                title
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "scene_filter": {
            "code": {
                "value": "'+ $code + '",
                "modifier": "EQUALS"
            }
        }
    }'

    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}

# Get Stash scene data with the unique scene id found in the path. Returns the
# graphql query.
function Get-StashSceneByIdInPath {
    param (
        [Parameter(Mandatory)][String]$id
    )

    $StashGQL_Query = 'query FindSceneByCode($scene_filter: SceneFilterType) {
        findScenes(scene_filter: $scene_filter) {
            scenes {
                code
                id
                title
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "scene_filter": {
            "path": {
                "value": "\/'+ $id + '\\s",
                "modifier": "MATCHES_REGEX"
            }
        }
    }'

    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}

function Set-StashSceneUpdate {
    param(
        [Parameter(Mandatory)][String]$id,
        [String]$code,
        [String]$cover_image,
        [String]$details,
        [array]$groups,
        [String[]]$performer_ids,
        [String]$studio_id,
        [String[]]$tag_ids,
        [String[]]$urls,
        [String]$title,
        $date
    )
    if ($code) { $code = '"code": "' + $code + '",' }
    if ($cover_image) { $cover_image = '"cover_image": "' + $cover_image + '",' }

    if ($date) {
        $date = Get-Date $date -format "yyyy-MM-dd"
        [string]$date = '"date": "' + $date + '",'
    }

    if ($details) {
        # Need to escape the quotation marks in JSON.
        $details = $details.replace('"', '\"')
        $details = '"details": "' + $details + '",'
    }

    if ($groups -and $groups.Count) {
        $groups = ConvertTo-Json $groups -depth 32
        $groups = '"groups": ' + $groups + ','
    }

    if ($performer_ids -and $performer_ids.Count) {
        $performer_ids = ConvertTo-Json $performer_ids -depth 32
        $performer_ids = '"performer_ids": ' + $performer_ids + ','
    }

    if ($studio_id) { $studio_id = '"studio_id": "' + $studio_id + '",' }

    if ($tag_ids -and $tag_ids.Count) {
        $tag_ids = ConvertTo-Json $tag_ids -depth 32
        $tag_ids = '"tag_ids": ' + $tag_ids + ','
    }

    if ($title) { $title = '"title": "' + $title + '",' }

    if ($urls.count) {
        $urls = ConvertTo-Json $urls -depth 32
        $urls = '"urls": ' + $urls + ','
    }

    $StashGQL_Query = 'mutation UpdateScene($input: SceneUpdateInput!) {
        sceneUpdate(input: $input) {
            code
            date
            details
            groups { group {
                id
                name
            }}
            id
            paths { screenshot }
            performers {
                id
                name
            }
            title
        }
    }'
    $StashGQL_QueryVariables = '{
        "input": {
            '+ $code + '
            '+ $cover_image + '
            '+ $date + '
            '+ $details + '
            '+ $groups + '
            '+ $performer_ids + '
            '+ $studio_id + '
            '+ $tag_ids + '
            '+ $title + '
            '+ $urls + '
            "id": "'+ $id + '"
        }
    }'

    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $updatedScene = $result.data.sceneUpdate
    Write-Host "SUCCESS: Updated scene $($updatedScene.title) (Stash ID $($updatedScene.id))." -ForegroundColor Green
    return $result
}