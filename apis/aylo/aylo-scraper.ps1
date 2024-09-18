# Get headers to send a request to the Aylo site
function Get-Headers {
  param(
    [String]$apiKey,
    [String]$authCode,
    [ValidateSet("bangbros", "realitykings", "twistys", "milehigh", "biempire", `
        "babes", "erito", "mofos", "fakehub", "sexyhub", "propertysex", "metrohd", `
        "brazzers", "milfed", "gilfed", "dilfed", "men", "whynotbi", `
        "seancody", "iconmale", "realitydudes", "spicevids", ErrorMessage = "Error: studio argumement is not supported" )]
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
    [string]$groupid = $null,
    [Int]$offset = 0,
    [Parameter(Mandatory)]
    [string]$studio,
    #content types can only be {actor, scene, movie}
    [Parameter(Mandatory)]
    [ValidateSet('actor', 'movie', 'scene')]
    [string]$ContentType
  )
  #initialize variables
  $Body = @{
    limit  = 100
    offset = $offset
  }
  $header = Get-Headers -apiKey $apiKey -authCode $authCode -studio $studio
  If ($null -eq $groupid) { $body.Add("groupID", $groupid) }
  #api call for actors is different from movies and releases
  If ($ContentType -eq "actor") {
    $urlapi = "https://site-api.project1service.com/v1/actors"
  }
  else {
    $urlapi = "https://site-api.project1service.com/v2/releases"
    $body.Add("orderBy", "-dateReleased")
    $body.Add('type', $ContentType)
  }

  if ($null -ne $actorId) {
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
    [string]$groupid = $null,
    [Parameter(Mandatory)]
    [string]$studio,
    #content types can only be {actor, scene, movie}
    [Parameter(Mandatory)]
    [ValidateSet('actor', 'movie', 'scene')]
    [string]$ContentType
  )

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
    [ValidateSet('actor', 'movie', 'scene')]
    [string[]]$ContentTypes,
    [string[]]$studios,
    [string]$outputDir
  )

  foreach ($ContentType in $ContentTypes ) {
    foreach ($studio in $studios) {
      foreach ($actorID in $actorIds) {
        Write-Host "Downloading: $studio : $ContentType : $actorID" 
        $json = Get-StudioJsonData -actorId $actorID -apiKey $apiKey -authCode $authCode -studio $studio -ContentType $ContentType
        if ($json.Length -gt 0) {
          $filedir = "$outputDir/$studio/$actorID"
          $filepath = Join-Path -Path $filedir -ChildPath "$ContentType.json"
          if (!(Test-Path $filedir)) { New-Item -ItemType "directory" -Path $filedir }  
          $json | ConvertTo-Json -Depth 32 | Out-File -FilePath $filepath
        }
      }
    }
  }
}