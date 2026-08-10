param(
  [string]$BaseUrl = 'http://127.0.0.1:5000'
)

$ErrorActionPreference = 'Stop'

function Assert-Header {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$Expected
  )

  $response = Invoke-WebRequest -Uri "$BaseUrl$Path" -Method Head
  $actual = [string]$response.Headers[$Name]
  if ($actual -ne $Expected) {
    throw "$Path retornou $Name='$actual'; esperado '$Expected'."
  }
}

$immutable = 'public,max-age=31536000,immutable'
$revalidated = 'public,max-age=3600,must-revalidate'
$noStore = 'no-cache, no-store, must-revalidate'

Assert-Header -Path '/index.html' -Name 'Cache-Control' -Expected $noStore
Assert-Header -Path '/' -Name 'Cache-Control' -Expected $noStore
Assert-Header -Path '/flutter_service_worker.js' -Name 'Cache-Control' -Expected $noStore
Assert-Header -Path '/version.json' -Name 'Cache-Control' -Expected $noStore
Assert-Header -Path '/manifest.json' -Name 'Cache-Control' -Expected 'no-cache, must-revalidate'
Assert-Header -Path '/assets/AssetManifest.bin.json' -Name 'Cache-Control' -Expected $immutable
Assert-Header -Path '/canvaskit/canvaskit.wasm' -Name 'Cache-Control' -Expected $immutable
Assert-Header -Path '/icons/Icon-192.png' -Name 'Cache-Control' -Expected $immutable
Assert-Header -Path '/main.dart.js' -Name 'Cache-Control' -Expected $revalidated
Assert-Header -Path '/downloads/natus-android-1.1.0.apk' -Name 'Cache-Control' -Expected $immutable
Assert-Header -Path '/downloads/natus-android-1.1.0.apk' -Name 'Content-Type' -Expected 'application/vnd.android.package-archive'
Assert-Header -Path '/downloads/natus-android-1.1.0.apk' -Name 'Content-Disposition' -Expected 'attachment; filename="natus-android-1.1.0.apk"'

$home = Invoke-WebRequest -Uri "$BaseUrl/" -Method Head
foreach ($headerName in @(
  'Content-Security-Policy',
  'Strict-Transport-Security',
  'X-Content-Type-Options',
  'X-Frame-Options',
  'Referrer-Policy',
  'Permissions-Policy'
)) {
  if ([string]::IsNullOrWhiteSpace([string]$home.Headers[$headerName])) {
    throw "Header de segurança ausente: $headerName."
  }
}

Write-Output 'Headers do Firebase Hosting validados.'
