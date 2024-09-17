# ? Dev variables
$useDevConfig = $true

# Global variables
if ($IsWindows) { $directorydelimiter = '\' }
else { $directorydelimiter = '/' }

if ($useDevConfig) {
    $pathToUserConfig = ".$directorydelimiter" + "config.dev.json"
}
else {
    $pathToUserConfig = ".$directorydelimiter" + "config.json"
}

$userConfig = Get-Content -Raw $pathToUserConfig | ConvertFrom-Json

# Load the entrypoint for the script.
function Set-Entry {
    Clear-Host
    Write-Host "Stash Media Manager"
    Write-Host "-------------------"

    # User first selects an API
    Write-Host "What API are you working with?"
    Write-Host "1. Aylo"
    do { $apiSelection = read-host "Enter your selection (1)" }
    while (($apiSelection -notmatch "[1]"))

    # Next, user selects an operation
    Write-Host "What would you like to do?"
    Write-Host "1. Update the database"
    Write-Host "2. Download content"
    Write-Host "3. Update Stash"
    do { $operationSelection = read-host "Enter your selection (1-3)" }
    while (($operationSelection -notmatch "[1-3]"))

    if ($operationSelection -eq 1) {
        # Load the scraper
        . "./apis/aylo/aylo-scraper.ps1"

        # ? Dev testing only
        $headers = Get-Headers -apikey $userConfig.aylo.apikey -authorization $userConfig.aylo.authorization -studio "brazzers"
        Write-Host $headers
    }
    
    else { Write-Host "This feature is awaiting development." }
}

Set-Entry