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
        [Parameter(Mandatory)][ValidateSet('gallery', 'scene', 'trailer')][String]$mediaType,
        [Parameter(Mandatory)][String]$extension,
        [Parameter(Mandatory)][Int]$id,
        [Parameter(Mandatory)][String]$title,
        [String]$resolution
    )
    # Sanitise the title string
    $title = Get-SanitizedTitle -title $title

    $filename = "$id $title [$mediaType" 
    if ($mediaType -eq "trailer" -or $mediaType -eq "scene") {
        $filename += " $resolution"
    }
    $filename += "].$extension"
    return $filename
}