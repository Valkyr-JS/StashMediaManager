# Global variables
if ($IsWindows) { $directorydelimiter = '\' }
else { $directorydelimiter = '/' }

# Get headers to send a request to the Aylo site
function Get-Headers {
  param(
    [String]$apiKey,
    [String]$authCode,
    [String]$studio
  )

  # Cannot execute without an API key.
  if ($apiKey.Length -eq 0) {
    Write-Host "ERROR: The Aylo API key has not been set. Please update your config." -ForegroundColor Red
    return
  }
  
  $useragent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36"
  $headers = @{
    "UserAgent" = "$useragent";
    "instance"  = "$apiKey";
  }

  # Only non-member data is available without an auth code.
  if ($authCode.Length -eq 0) {
    Write-Host "WARNING: No auth code provided. Scraping non-member data only." -ForegroundColor Yellow
  }

  else {
    $headers.authorization = "$authCode"
  }
  return $headers
}

# Set the query parameters for the web request
function Set-QueryParameters {
  param (
    [Int]$actorId,
    [String]$apiKey,
    [String]$authCode,
    [Int]$galleryId,
    [string]$groupid = $null,
    [Int]$offset = 0,
    [Parameter(Mandatory)]
    [string]$studio,
    #content types can only be {actor, scene, movie}
    [Parameter(Mandatory)]
    [ValidateSet('actor', 'gallery', 'movie', 'scene')]
    [string]$ContentType
  )
  #initialize variables
  $Body = @{
    limit  = 100
    offset = $offset
  }
  $header = Get-Headers -apiKey $apiKey -authCode $authCode -studio $studio
  if ($null -eq $groupid) { $body.Add("groupID", $groupid) }
  #api call for actors is different from movies and releases
  if ($ContentType -eq "actor") {
    $urlapi = "https://site-api.project1service.com/v1/actors"
  }
  else {
    $urlapi = "https://site-api.project1service.com/v2/releases"
    $body.Add("orderBy", "-dateReleased")
    $body.Add('type', $ContentType)
    $body.Add('brand', $studio)
  }

  if ($ContentType -eq "gallery") {
    $body.Add("id", $galleryId)
  }

  if ($null -ne $actorId -and $ContentType -ne "gallery") {
    $body.Add("actorId", $actorId)
  }

  $params = @{
    "Uri"     = $urlapi
    "Body"    = $Body
    "Headers" = $header
  }
  return $params
}

# Get the number of pages the data is split into
function Get-MaxPages ($meta) {
  $limit = $meta.count
  if ($meta.count -eq 0) {
    return 0
  }
  $maxpage = $meta.total / $limit
  $maxpage = [Math]::Ceiling($maxpage)
  return $maxpage
}

# Get the studio JSON data from the site
function Get-StudioJsonData () {
  param (
    [Int]$actorId,
    [String]$apiKey,
    [String]$authCode,
    [Parameter(Mandatory)]
    [ValidateSet('actor', 'gallery', 'movie', 'scene')]
    [string]$ContentType,
    [Int[]]$galleryIds,
    [string]$groupid = $null,
    [Parameter(Mandatory)]
    [string]$studio
  )

  # Handle gallery scrapes separately as they rely on scene data. Each scene needs a separate scrape.
  if ($ContentType -eq "gallery") {
    $gallerylist = New-Object -TypeName System.Collections.ArrayList
  
    for ($p = 0; $p -lt $galleryIds.Length; $p++) {
      Write-Host "Downloading: gallery $($p + 1) of $($galleryIds.Length)"
      $galleryId = $galleryIds[$p]
      $offset = 0
      $params = Set-QueryParameters -actorID $actorId -apiKey $apiKey -authCode $authCode -ContentType $ContentType -galleryID $galleryId -offset $offset -studio $studio
      $gallery = Invoke-RestMethod @params 
      $gallerylist.AddRange($gallery.result)
    }
    return $gallerylist
  }

  $scenelist = New-Object -TypeName System.Collections.ArrayList
  $params = Set-QueryParameters -actorID $actorId -apiKey $apiKey -authCode $authCode -studio $studio -ContentType $ContentType
  $scenes0 = Invoke-RestMethod @params 
  $limit = $scenes0.meta.count
  $maxpage = Get-MaxPages -meta $scenes0.meta

  if ($maxpage -eq 0) {
    Write-Host "No content found for this query." -ForegroundColor Yellow
    return $scenelist
  }

  for ($p = 1; $p -le $maxpage; $p++) {
    $page = $p - 1
    Write-Host "Downloading: page $p of $maxpage" 
    $offset = $page * $limit
    $params = Set-QueryParameters -actorID $actorId -apiKey $apiKey -authCode $authCode -studio $studio -ContentType $ContentType -offset $offset
    $scenes = Invoke-RestMethod @params 
    $scenelist.AddRange($scenes.result)
  }
  return $scenelist
}

# Create the studio data JSON file
function Set-StudioData {
  param(
    [Int[]]$actorIds,
    [String]$apiKey,
    [String]$authCode,
    [Parameter(Mandatory)]
    [ValidateSet('actor', 'gallery', 'movie', 'scene')]
    [string[]]$ContentTypes,
    [string[]]$studios,
    [string]$outputDir
  )
  foreach ($ContentType in $ContentTypes ) {
    # The galleries API doesn't use the actorId parameter. Instead, get all the
    # scene IDs from the scene scrape.
    #
    # ! This means the scenes MUST be scraped before galleries!
    if ($ContentType -eq "gallery") {
      foreach ($studio in $studios) {
        foreach ($actorID in $actorIds) {
          # Make sure that scene data exists
          $scenesJsonFile = @($outputDir, $studio, $actorID, "scene.json") -join $directorydelimiter
          if (!(Test-Path $scenesJsonFile)) {
            Write-Host "No scenes data available for gallery scrape. Skipping."
          }
          else {
            # Get the scene IDs from the scene scrape
            $scenesJson = Get-Content $scenesJsonFile -raw | ConvertFrom-Json
            $galleryIds = @()
            $galleryIds += ($scenesJson.children | Where-Object { $_.type -eq "gallery" }).id

            Write-Host `n"Scraping: $studio : $ContentType : actor ID $actorID" 
            $json = Get-StudioJsonData -actorId $actorID -apiKey $apiKey -authCode $authCode -ContentType $ContentType -galleryIds $galleryIds -studio $studio
            if ($json.Length -gt 0) {
              $filedir = ($outputDir, $studio, $actorID) -join $directorydelimiter
              $filepath = Join-Path -Path $filedir -ChildPath "$ContentType.json"
              if (!(Test-Path $filedir)) { New-Item -ItemType "directory" -Path $filedir }  
              Write-Host "Generating JSON: $filepath"
              $json | ConvertTo-Json -Depth 32 | Out-File -FilePath $filepath
              if (!(Test-Path $filedir)) { Write-Host "ERROR: generating gallery JSON failed" -ForegroundColor Red }  
              else { Write-Host "SUCCESS: gallery JSON generated at $filedir " -ForegroundColor Green }  
            }
          }
        }
      }
    }
    else {
      foreach ($studio in $studios) {
        foreach ($actorID in $actorIds) {
          Write-Host `n"Scraping: $studio : $ContentType : actor ID $actorID" 
          $json = Get-StudioJsonData -actorId $actorID -apiKey $apiKey -authCode $authCode -studio $studio -ContentType $ContentType
          if ($json.Length -gt 0) {
            $filedir = ($outputDir, $studio, $actorID) -join $directorydelimiter
            $filepath = Join-Path -Path $filedir -ChildPath "$ContentType.json"
            if (!(Test-Path $filedir)) { New-Item -ItemType "directory" -Path $filedir } 
            Write-Host "Generating JSON: $filepath"
            $json | ConvertTo-Json -Depth 32 | Out-File -FilePath $filepath
            if (!(Test-Path $filedir)) { Write-Host "ERROR: generating $ContentType JSON failed" -ForegroundColor Red }  
            else { Write-Host "SUCCESS: $ContentType JSON generated at $filedir" -ForegroundColor Green }  
          }
        }
      }
    }
  }
}