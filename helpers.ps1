# Get a gigabyte value in bytes
function Get-GigabytesToBytes {
    param (
        [Parameter(Mandatory)][Int]$gb
    )
    $mb = $gb * 1024
    $kb = $mb * 1024
    $b = $kb * 1024
    return $b
}

# Get an inches value in centimetres, unrounded
function Get-InchesToCm {
    param (
        [Parameter(Mandatory)][Int]$inches
    )
    return $inches * 2.54
}

# Get a lbs value in kg, unrounded
function Get-LbsToKilos {
    param (
        [Parameter(Mandatory)][Int]$lbs
    )
    return $lbs * 2.54 / 2.2046226218
}

# Sanitize a string that is being used in a filename.
function Get-SanitizedFilename {
    param(
        [Parameter(Mandatory)][String]$title
    )
    $title = ($title.Split([IO.Path]::GetInvalidFileNameChars()) -join '')
    $title = $title.Trim()
    $title = $title.replace("  ", " ")
    return $title
}

# Create the filename for a content item.
function Set-MediaFilename {
    param(
        [Parameter(Mandatory)][ValidateSet('data', 'gallery', 'image', 'poster', 'scene', 'trailer')][String]$mediaType,
        [Parameter(Mandatory)][String]$extension,
        [Parameter(Mandatory)][Int]$id,
        [Parameter(Mandatory)][String]$title,
        [String]$resolution,
        [String]$siteName,
        $date
    )
    # Sanitise the title string
    $title = Get-SanitizedFilename -title $title

    # If the title is too short, replace with the site name and the date
    if ($title.Length -lt 3 -and $siteName -and $date) {
        $date = Get-Date $date -Format "yyyy-MM-dd"
        $siteName = Get-SanitizedFilename -title $siteName
        $title = "$siteName $date"
    }

    $filename = "$id $title" 
    if (($mediaType -eq "poster" -or $mediaType -eq "scene" -or $mediaType -eq "trailer") -and $resolution) {
        $filename += " [$resolution]"
    }
    $filename += ".$extension"
    return $filename
}

# Create the filename for an asset
function Set-AssetFilename {
    param(
        [Parameter(Mandatory)][String]$assetType,
        [Parameter(Mandatory)][String]$extension,
        [Parameter(Mandatory)][Int]$id,
        [Parameter(Mandatory)][String]$title
    )

    # Sanitise the title string
    $title = Get-SanitizedFilename -title $title

    $filename = "$id $title [$assetType].$extension"
    return $filename
}

# Convert text with diacretics - e.g. accented characters - into simple character text
function Get-TextWithoutDiacritics {
    param (
        [System.String]$text
    )
    if ([System.String]::IsNullOrEmpty($text)) {
        return $text;
    }

    $Normalized = $text.Normalize([System.Text.NormalizationForm]::FormD)
    $NewString = New-Object -TypeName System.Text.StringBuilder

    $normalized.ToCharArray() | ForEach-Object {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($psitem) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$NewString.Append($psitem)
        }
    }

    return $NewString.ToString()
}

function Invoke-StashBackupRequest {
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
}