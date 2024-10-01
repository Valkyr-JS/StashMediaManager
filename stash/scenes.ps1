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
        [String[]]$performer_ids,
        [String[]]$tag_ids,
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

    if ($performer_ids -and $performer_ids.Count) {
        $performer_ids = ConvertTo-Json $performer_ids -depth 32
        $performer_ids = '"performer_ids": ' + $performer_ids + ','
    }

    if ($tag_ids -and $tag_ids.Count) {
        $tag_ids = ConvertTo-Json $tag_ids -depth 32
        $tag_ids = '"tag_ids": ' + $tag_ids + ','
    }

    if ($title) { $title = '"title": "' + $title + '",' }

    $StashGQL_Query = 'mutation UpdateScene($input: SceneUpdateInput!) {
        sceneUpdate(input: $input) {
            code
            date
            details
            id
            paths {
                screenshot
            }
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
            '+ $performer_ids + '
            '+ $tag_ids + '
            '+ $title + '
            "id": "'+ $id + '"
        }
    }'

    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $updatedScene = $result.data.sceneUpdate
    Write-Host "SUCCESS: Updated scene $($updatedScene.title) (Stash ID $($updatedScene.id))." -ForegroundColor Green
    return $result
}