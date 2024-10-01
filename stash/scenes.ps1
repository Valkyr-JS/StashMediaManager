# Get Stash scene data with the given studio code. Returns the graphql query.
Get-StashSceneByCode {
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
Get-StashSceneByIdInPath {
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
                "value": "/'+ $id + '\\s",
                "modifier": "EQUALS"
            }
        }
    }'

    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}