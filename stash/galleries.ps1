# Update a Stash gallery with the provided data. Returns the gallery data.
function Set-StashGalleryUpdate {
    param(
        [Parameter(Mandatory)][String]$id,
        [String]$code,
        [String]$details,
        [bool]$organized,
        [String[]]$performer_ids,
        [String[]]$scene_ids,
        [String]$studio_id,
        [String]$title,
        $date
    )
    if ($code) { $code = '"code": "' + $code + '",' }

    if ($date) {
        $date = Get-Date $date -format "yyyy-MM-dd"
        [string]$date = '"date": "' + $date + '",'
    }

    if ($details) {
        # Need to escape the quotation marks in JSON.
        $details = $details.replace('"', '\"')
        $details = '"details": "' + $details + '",'
    }

    if ($organized -eq $true) { [string]$organized = '"organized": true,' }
    if ($organized -eq $false) { [string]$organized = '"organized": false,' }

    if ($performer_ids -and $performer_ids.Count) {
        $performer_ids = ConvertTo-Json $performer_ids -depth 32
        $performer_ids = '"performer_ids": ' + $performer_ids + ','
    }

    if ($scene_ids -and $scene_ids.Count) {
        $scene_ids = ConvertTo-Json $scene_ids -depth 32
        $scene_ids = '"scene_ids": ' + $scene_ids + ','
    }

    if ($studio_id) { $studio_id = '"studio_id": "' + $studio_id + '",' }
    if ($title) { $title = '"title": "' + $title + '",' }

    $StashGQL_Query = 'mutation UpdateGallery($input: GalleryUpdateInput!) {
        galleryUpdate(input: $input) {
            code
            date
            details
            id
            organized
            performers {
                id
                name
            }
            scenes {
                id
                title
            }
            studio {
                id
                name
            }
            title
        }
    }'
    $StashGQL_QueryVariables = '{
        "input": {
            '+ $code + '
            '+ $date + '
            '+ $details + '
            '+ $organized + '
            '+ $performer_ids + '
            '+ $scene_ids + '
            '+ $studio_id + '
            '+ $title + '
            "id": "'+ $id + '"
        }
    }'

    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $updatedGallery = $result.data.galleryUpdate
    Write-Host "SUCCESS: Updated gallery $($updatedGallery.title) (Stash ID $($updatedGallery.id))." -ForegroundColor Green
    return $result
}