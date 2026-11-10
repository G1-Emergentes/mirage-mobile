param([string]$Device = 'windows', [string]$ApiBaseUrl = '')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if ($ApiBaseUrl) {
        flutter run -d $Device "--dart-define=API_BASE_URL=$ApiBaseUrl"
    } elseif ($Device -eq 'windows') {
        flutter run -d $Device --dart-define-from-file=config/local.json
    } else {
        flutter run -d $Device
    }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter exited with an error.' }
} finally { Pop-Location }
