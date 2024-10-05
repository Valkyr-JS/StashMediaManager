function Get-AFAllContentBySite {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$slug
    )

    Get-AFModelSiteJson -pathToUserConfig $pathToUserConfig -slug $slug
}