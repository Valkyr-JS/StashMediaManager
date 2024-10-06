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

# Sanitize a string that is being used as a title.
function Get-SanitizedTitle {
    param(
        [Parameter(Mandatory)][String]$title
    )
    $title = ($title.Split([IO.Path]::GetInvalidFileNameChars()) -join '')
    $title = $title.replace("  ", " ")
    return $title
}

# Create the filename for a content item.
function Set-MediaFilename {
    param(
        [Parameter(Mandatory)][ValidateSet('data', 'gallery', 'poster', 'scene', 'trailer')][String]$mediaType,
        [Parameter(Mandatory)][String]$extension,
        [Parameter(Mandatory)][Int]$id,
        [Parameter(Mandatory)][String]$title,
        [String]$resolution,
        [String]$siteName,
        $date
    )
    # Sanitise the title string
    $title = Get-SanitizedTitle -title $title

    # If the title is too short, replace with the site name and the date
    if ($title.Length -lt 3 -and $siteName -and $date) {
        $date = Get-Date $date -Format "yyyy-MM-dd"
        $siteName = Get-SanitizedTitle -title $siteName
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
    $title = Get-SanitizedTitle -title $title

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