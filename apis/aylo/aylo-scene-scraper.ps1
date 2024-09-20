# Get headers to send a request to the Aylo site
function Get-Headers {}

# Set the query parameters for the web request
function Set-QueryParameters {}

# Get the data for a single content item from the site
function Get-ContentData () {}

# Create the data JSON file for a single content item
function Set-ContentData {
    param(
        [Parameter(Mandatory)][ValidateSet('actor', 'gallery', 'movie', 'scene')][string]$contentType,
        [Parameter(Mandatory)][string]$outputDir,
        [Parameter(Mandatory)][string]$studio
    )
    $result = Get-ContentData

    if ($result.Length -gt 0) {
        # Create the file path
        $filedir = Join-Path $outputDir $studio $contentType

        $date = Get-Date -Date $result.dateReleased -Format "yyyy-MM-dd"
        $id = $result.id
        $title = ($result.title.Split([IO.Path]::GetInvalidFileNameChars()) -join '')
        $title = $title.replace("  ", " ")
        $filename = "$id $date $title.json"
        
        $filepath = Join-Path -Path $filedir -ChildPath $filename
        if (!(Test-Path $filedir)) { New-Item -ItemType "directory" -Path $filedir } 

        Write-Host "Generating JSON: $filepath"
        $json | ConvertTo-Json -Depth 32 | Out-File -FilePath $filepath

        if (!(Test-Path $filedir)) { Write-Host "ERROR: JSON generation failed - $filepath" -ForegroundColor Red }  
        else { Write-Host "SUCCESS: JSON generated - $filepath" -ForegroundColor Green }  
    }
}
