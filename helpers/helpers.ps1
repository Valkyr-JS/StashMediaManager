# Sanitize a string that is being used as a title.
function Get-SanitizedTitle {
    param(
        [Parameter(Mandatory)][String]$title
    )
    $title = ($result.title.Split([IO.Path]::GetInvalidFileNameChars()) -join '')
    $title = $title.replace("  ", " ")
    return $title
}

# Create the filename for a content item.
function Set-MediaFilename {
    param(
        [Parameter(Mandatory)][ValidateSet('gallery', 'scene', 'trailer')][Int]$contentType,
        [Parameter(Mandatory)][String]$extension,
        [Parameter(Mandatory)][Int]$id,
        [Parameter(Mandatory)][String]$title,
        [Int]$resolution
    )
    # Sanitise the title string
    $title = Get-SanitizedTitle -title $title

    $filename = "$id $title $contentType" 
    if ($contentType -eq "trailer" -or $contentType -eq "scene") {
        $filename += " $resolution"
    }
    $filename += ".$extension"
    return $filename
}
