# This is the API name used in the string, akin to "aylo" in the Aylo paths.
# This distinguishes from the parent studio "Vixen Media Group", which will sit
# alongside "Channels" as the other parent studio.
$API_NAME = "VMG"

$headers = @{
    "Content-Length" = $null
    "Content-Type"   = "application/json"
    "Cookie"         = $null
    "Host"           = "members.vixen.com"
    "User-Agent"     = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
}

# Get headers for a VMG web request
function Get-VMGHeaders {
    return $headers
}

# Set the data required for headers in a VMG web request
function Set-VMGHeaders {
    param (
        [Parameter(Mandatory)][Int]$contentLength
    )
    # Only set the header cookie when it is null
    if ($null -eq $headers.Cookie) {
        Write-Host `n"Please copy-paste the access_token and refresh_token from the login cookie" -ForegroundColor Cyan
        do { $access_token = read-host "access_token" }
        while ($access_token.Length -eq 0)
        do { $refresh_token = read-host "refresh_token" }
        while ($refresh_token.Length -eq 0)
        $headers.Cookie = "access_token=$access_token; refresh_token=$refresh_token"
    }

    # Content length needs to be updated on every request.
    $headers["Content-Length"] = $contentLength
}

# Set the query parameters for the web request
function Set-VMGQueryParameters {
    param (
        [Parameter(Mandatory)]$body
    )
    
    $urlapi = "https://members.vixen.com/graphql"
    $header = Get-VMGHeaders

    $params = @{
        "Uri"     = $urlapi
        "Body"    = $body
        "Headers" = $header
    }
    return $params
}

# Attempt to fetch the given data from the VMG API
function Get-VMGQueryData {
    param(
        [Parameter(Mandatory)][String]$operation,
        [Parameter(Mandatory)][String]$query,
        [Parameter(Mandatory)][Object]$variables
    )

    # Create the body here so we can get the file size for the header request
    $body = @{
        "operationName" = $operation
        "query"         = $query
        "variables"     = $variables
    } | ConvertTo-Json

    $params = Set-VMGQueryParameters $body
    Set-VMGHeaders $body.Length
    
    try { $result = Invoke-RestMethod -Method Post @params }
    catch {
        Write-Host "WARNING: Scrape failed." -ForegroundColor Red
        Write-Host "$_" -ForegroundColor Red
        $result = $null
    }

    return $result
}

# Get data for a piece of content
function Get-VMGJson {
    param (
        [Parameter(Mandatory)][ValidateSet('gallery', 'model', 'scene', 'trailer')][String]$contentType,
        [Parameter(Mandatory)][String]$contentID,
        [Parameter(Mandatory)][String]$operation,
        [Parameter(Mandatory)][String]$query,
        [Object]$variables
    )
    Write-Host `n"Starting scrape for $contentType #$contentID." -ForegroundColor Cyan

    # Attempt to scrape data
    $result = Get-VMGQueryData $operation $query $variables
    if ($null -eq $result) {
        Write-Host "No $operation data found with $contentType ID $contentID." -ForegroundColor Red
        return $null
    }
    return $result
}

# Create a JSON file from the retrieved data after checking existing data
function Set-VMGJson {
    param (
        [Parameter(Mandatory)][String]$contentID,
        [Parameter(Mandatory)][Object]$data,
        [Parameter(Mandatory)][String]$operation,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$subDir,
        [Parameter(Mandatory)][String]$title
    )
    $userConfig = Get-Content $pathToUserConfig -raw | ConvertFrom-Json
    $contentDir = $userConfig.general.contentDirectory
    $contentDownloadDir = $userConfig.general.contentDownloadDirectory
    $dataDir = $userConfig.general.dataDirectory
    $dataDownloadDir = $userConfig.general.dataDownloadDirectory

    # Skip creating JSON if both the JSON and the content already exist in
    # either directory
    $existingPath = $null
    $existingJson = $null
    foreach ($dir in @($contentDir, $contentDownloadDir)) {
        $testPath = Join-Path $dir $subDir
        if (Test-Path -LiteralPath $testPath) {
            $filename = Get-ChildItem -LiteralPath $testPath | Where-Object { $_.BaseName -match "^$contentID\s" }
            if ($null -ne $filename -and (Test-Path -LiteralPath $filename.FullName)) {
                # Check the associated JSON also exists
                foreach ($dDir in @($dataDir, $dataDownloadDir)) {
                    $dataTestPath = Join-Path $dDir $subDir
                    if (Test-Path -LiteralPath $dataTestPath) {
                        $jsonFilename = Get-ChildItem -LiteralPath $dataTestPath | Where-Object { $_.BaseName -match "^$contentID\s" }
                        if ($null -ne $jsonFilename -and (Test-Path -LiteralPath $jsonFilename.FullName)) {
                            # Check the file exists in the directory
                            $existingPath = $filename.FullName
                            $existingJson = $jsonFilename.FullName
                        }
                    }
                }
            }
        }
    }

    if ($null -eq $existingPath -or $null -eq $existingJson) {
        # Output the JSON file
        $title = Get-SanitizedFilename -title $title
        $filename = "$contentID $title.json"
        $outputDir = Join-Path $userConfig.general.dataDownloadDirectory $subDir
        if (!(Test-Path -LiteralPath $outputDir)) { New-Item -ItemType "directory" -Path $outputDir }
        $outputDest = Join-Path $outputDir $filename
    
        Write-Host "Generating JSON: $filename"
        $data | ConvertTo-Json -Depth 32 | Out-File -LiteralPath $outputDest
    
        if (!(Test-Path -LiteralPath $outputDest)) {
            Write-Host "ERROR: $operation JSON generation failed - $outputDest" -ForegroundColor Red
            return $null
        }  
        else {
            Write-Host "SUCCESS: $operation JSON generated - $outputDest" -ForegroundColor Green
            return $outputDest
        }  
    }
    else {
        Write-Host "Media already exists at $($existingPath). Skipping JSON generation for $operation #$contentID."
        return $existingJson
    }
}

# Get the getModel data for the given VMG model and output it to a JSON file.
# Returns the path to the JSON file.
function Get-VMGModelJson {
    param (
        [Parameter(Mandatory)][String]$modelSlug,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$studio
    )

    $query = 'query getModel($slug:String!,$site:Site!){findOneModel(input:{slug:$slug,site:$site}){modelId globalId name slug biography rating globalRating onlyFans images{listing{...ImageInfo __typename}poster{...ImageInfo __typename}profile{...ImageInfo __typename}__typename}__typename}}fragment ImageInfo on Image{src placeholder width height highdpi{double triple __typename}__typename}'
    $variables = @{
        "slug" = $modelSlug
        "site" = $studio.ToUpper()
    }

    $result = Get-VMGJson -contentType "model" -contentID $modelSlug -operation "getModel" -query $query -variables $variables
    $subDir = Join-Path $API_NAME "model" "getModel"
    $name = $result.data.findOneModel.name

    Set-VMGJson -contentID $modelSlug -data $result -operation "getModel" -pathToUserConfig $pathToUserConfig -subDir $subDir -title $name
}

# Get the getPictureSet data for the given VMG gallery and output it to a JSON
# file. Returns the path to the JSON file.
function Get-VMGPictureSetJson {
    param (
        [Parameter(Mandatory)][Int]$galleryID,
        [Parameter(Mandatory)][String]$parentStudio,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$studio,
        [Parameter(Mandatory)][String]$title
    )

    $query = 'query getPictureSet($pictureSetId:ID,$site:Site!){findOnePictureSet(input:{pictureSetId:$pictureSetId,site:$site}){pictureSetId zip video{id:uuid videoId freeVideo isFreeLimitedTrial site categories{slug name __typename}__typename}images{listing{src width height __typename}main{src width height __typename}__typename}__typename}}'
    $variables = @{
        "pictureSetId" = $galleryID
        "site"         = $studio.ToUpper()
    }

    $result = Get-VMGJson -contentType "gallery" -contentID $galleryID -operation "getPictureSet" -query $query -variables $variables
    $subDir = Join-Path $API_NAME "gallery" "getPictureSet" $parentStudio $studio

    Set-VMGJson -contentID $galleryID -data $result -operation "getPictureSet" -pathToUserConfig $pathToUserConfig -subDir $subDir -title $title
}

# Get the getToken data for the given VMG content and output it to a JSON file.
# Returns the path to the JSON file.
function Get-VMGTokenJson {
    param (
        [Parameter(Mandatory)][ValidateSet('scene', 'trailer')][String]$contentType,
        [Parameter(Mandatory)][Int]$contentID,
        [Parameter(Mandatory)][String]$parentStudio,
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][String]$studio,
        [Parameter(Mandatory)][String]$title
    )

    $query = 'query getToken($videoId:ID!,$device:Device!){generateVideoToken(input:{videoId:$videoId,device:$device}){p270{token cdn __typename}p360{token cdn __typename}p480{token cdn __typename}p480l{token cdn __typename}p720{token cdn __typename}p1080{token cdn __typename}p2160{token cdn __typename}hls{token cdn __typename}__typename}}'

    $variables = @{ "videoId" = $contentID }
    if ($contentType -eq "scene") { $variables.Add("device", "desktop") }
    elseif ($contentType -eq "trailer") { $variables.Add("device", "trailer") }

    $result = Get-VMGJson -contentType $contentType -contentID $sceneID -operation "getToken" -query $query -variables $variables
    $subDir = Join-Path $API_NAME $contentType "getToken" $parentStudio $studio

    Set-VMGJson -contentID $sceneID -data $result -operation "getToken" -pathToUserConfig $pathToUserConfig -subDir $subDir -title $title
}

# Get the getVideo data for the given VMG content and output it to a JSON file.
# Returns the path to the JSON file.
function Get-VMGVideoJson {
    param (
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int]$sceneID
    )
    $query = 'query getVideo($videoId:ID){findOneVideo(input:{videoId:$videoId}){id:uuid videoId newId:videoId uuid slug site title description descriptionHtml absoluteUrl denied:isDenied isUpcoming releaseDate runLength directors{name __typename}categories{slug name __typename}channel{channelId isThirdPartyChannel __typename}chapters{trailerThumbPattern videoThumbPattern video{title seconds _id:videoChapterId __typename}__typename}showcase{showcaseId title itsupId{mobile desktop __typename}__typename}tour{views __typename}modelsSlugged:models{name slugged:slug __typename}expertReview{global properties{name slug rating __typename}models{slug rating name __typename}__typename}runLengthFormatted:runLength releaseDate videoUrl1080P:videoTokenId trailerTokenId picturesInSet carousel{listing{...PictureSetInfo __typename}main{...PictureSetInfo __typename}__typename}images{poster{...ImageInfo __typename}__typename}tags downloadResolutions{label size width res __typename}freeVideo isFreeLimitedTrial userVideoReview{slug rating __typename}crossNavigation{slug channel{slug __typename}__typename}__typename}}fragment PictureSetInfo on PictureSetImage{src width height name __typename}fragment ImageInfo on Image{src placeholder width height highdpi{double triple __typename}__typename}'
    $variables = @{ "videoId" = $sceneID }

    $result = Get-VMGJson -contentType "scene" -contentID $sceneID -operation "getVideo" -query $query -variables $variables
    $studio = (Get-Culture).TextInfo.ToTitleCase($result.data.findOneVideo.site)
    $subDir = Join-Path $API_NAME "scene" "getVideo" "Vixen Media Group" $studio

    Set-VMGJson -contentID $sceneID -data $result -operation "getVideo" -pathToUserConfig $pathToUserConfig -subDir $subDir -title $result.data.findOneVideo.title
}

# Get data for all content related to the given VMG scene and output it to JSON
# files. Returns the path to the scene JSON file.
function Get-VMGAllJson {
    param(
        [Parameter(Mandatory)][String]$pathToUserConfig,
        [Parameter(Mandatory)][Int]$sceneID
    )
    # Generate the scene JSON first, and use it to create the rest
    $pathToSceneJson = Get-VMGVideoJson -pathToUserConfig $pathToUserConfig -sceneID $sceneID
    $sceneData = Get-Content -LiteralPath $pathToSceneJson -raw | ConvertFrom-Json
    $sceneData = $sceneData.data.findOneVideo

    $studio = (Get-Culture).TextInfo.ToTitleCase($sceneData.site)
    $title = $sceneData.title

    # Get scene token
    Get-VMGTokenJson -contentType "scene" -contentID $sceneID -parentStudio "Vixen Media Group" -pathToUserConfig $pathToUserConfig -studio $studio -title $title

    #Gallery - scene ID matches the gallery ID.
    Get-VMGPictureSetJson -galleryID $sceneID -parentStudio "Vixen Media Group" -pathToUserConfig $pathToUserConfig -studio $studio -title $title

    #Trailer
    Get-VMGTokenJson -contentType "trailer" -contentID $sceneID -parentStudio "Vixen Media Group" -pathToUserConfig $pathToUserConfig -studio $studio -title $title

    # Actors
    Write-Host `n"Starting scrape for actors in scene #$sceneID." -ForegroundColor Cyan
    foreach ($aID in $sceneData.modelsSlugged.slugged) {
        $null = Get-VMGModelJson -modelSlug $aID -pathToUserConfig $pathToUserConfig -studio $studio
    }

    return $pathToSceneJson
}
