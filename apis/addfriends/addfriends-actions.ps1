function Get-AFAllContentBySite {
    param(
        [Parameter(Mandatory)][Int[]]$siteID,
        [Parameter(Mandatory)][String]$pathToUserConfig
    )

    Write-Host "Scraping site $siteID."
}