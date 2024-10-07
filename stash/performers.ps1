# Get Stash performer data with the given disambiguation. Returns the graphql
# query.
function Get-StashPerformerByDisambiguation {
    param(
        [Parameter(Mandatory)][String]$disambiguation
    )
    $StashGQL_Query = 'query FindPerformers($performer_filter: PerformerFilterType) {
        findPerformers(performer_filter: $performer_filter) {
            performers {
                id
                name
            }
        }
    }'
    $StashGQL_QueryVariables = '{
        "performer_filter": {
            "disambiguation": {
                "value": "'+ $disambiguation + '",
                "modifier": "EQUALS"
            }
        }
    }' 

    Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
}

# Create a new performer in Stash with the given data. Returns the graphql result.
function Set-StashPerformer {
    param (
        [Parameter(Mandatory)][String]$disambiguation,
        [Parameter(Mandatory)][String]$name,
        [ValidateSet('MALE', 'FEMALE', 'TRANSGENDER_MALE', 'TRANSGENDER_FEMALE', 'INTERSEX', 'NONBINARY')][String]$gender,
        [String[]]$alias_list,
        [String]$details,
        [Int]$height_cm,
        [String]$image,
        [String]$measurements,
        [Int]$penis_length,
        [String[]]$tag_ids,
        [String[]]$urls,
        [Int]$weight,
        $birthdate
    )
    if ($alias_list -and $alias_list.Count) {
        $alias_list = ConvertTo-Json $aliases -depth 32
        $alias_list = '"alias_list": ' + $alias_list + ','
    }

    if ($birthdate) {
        $birthdate = Get-Date $birthdate -format "yyyy-MM-dd"
        [string]$birthdate = '"birthdate": "' + $birthdate + '",'
    }

    if ($details) {
        # Need to escape the quotation marks in JSON.
        $details = $details.replace('"', '\"')
        $details = '"details": "' + $details + '",'
    }

    if ($gender) {
        $gender = $gender.ToUpper()
        [string]$gender = '"gender": "' + $gender + '",'
    }

    if ($height_cm) { [string]$height_cm = '"height_cm": ' + $height_cm + ',' }
    else { [string]$height_cm = '' }

    if ($image) { $image = '"image": "' + $image + '",' }
    if ($measurements) { $measurements = '"measurements": "' + $measurements.Trim() + '",' }

    if ($penis_length -and $penis_length -ne 0) { [string]$penis_length = '"penis_length": ' + $penis_length + ',' }
    else { [string]$penis_length = '' }

    if ($tag_ids -and $tag_ids.Count) {
        $tag_ids = ConvertTo-Json $tag_ids -depth 32
        $tag_ids = '"tag_ids": ' + $tag_ids + ','
    }

    if ($urls.count) {
        $urls = ConvertTo-Json $urls -depth 32
        $urls = '"urls": ' + $urls + ','
    }

    if ($weight) { [string]$weight = '"weight": ' + $weight + ',' }
    else { [string]$weight = '' }

    $StashGQL_Query = 'mutation CreatePerformer($input: PerformerCreateInput!) {
        performerCreate(input: $input) {
            id
            name
        }
    }'
    $StashGQL_QueryVariables = '{
        "input": {
            '+ $alias_list + '
            '+ $birthdate + '
            '+ $details + '
            '+ $gender + '
            '+ $height_cm + '
            '+ $image + '
            '+ $measurements + '
            '+ $penis_length + '
            '+ $tag_ids + '
            '+ $weight + '
            '+ $urls + '
            "disambiguation": "'+ $disambiguation + '",
            "name": "'+ $name.Trim() + '",
            "ignore_auto_tag": true
        }
    }'
    $result = Invoke-StashGQLQuery -query $StashGQL_Query -variables $StashGQL_QueryVariables
    $newPerformer = $result.data.performerCreate
    Write-Host "SUCCESS: Created performer $($newPerformer.name) (Stash ID $($newPerformer.id))." -ForegroundColor Green
    return $result
}