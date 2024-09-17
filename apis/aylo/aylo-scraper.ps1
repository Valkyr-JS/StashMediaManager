# Get headers to send a request to the Aylo site.
function Get-Headers {
  param(
    [String]$authCode,
    [String]$apiKey,
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
    $headers.authCode = "$authCode"
  }
  return $headers
}