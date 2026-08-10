param(
  [ValidateSet('PreMigration', 'PostMigration')]
  [string]$DataGate = 'PreMigration',
  [string]$OutputPath = '.local-private\release\release-candidate.json'
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$projectId = 'natus-gestantes'
$packageId = 'br.enf.natus.app'
$versionName = '1.1.0'
$versionCode = '3'

function Assert-Natus {
  param(
    [bool]$Condition,
    [string]$Message
  )
  if (-not $Condition) { throw $Message }
}

function Invoke-NatusCommand {
  param(
    [string]$Description,
    [scriptblock]$Command
  )
  Write-Output "[gate] $Description"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Description falhou com código $LASTEXITCODE."
  }
}

Push-Location $workspace
try {
  $firebaseConfig = Get-Content firebase.json -Raw | ConvertFrom-Json
  $indexes = Get-Content firebase\security\firestore.indexes.json -Raw |
    ConvertFrom-Json
  $firebaseRc = Get-Content .firebaserc -Raw | ConvertFrom-Json
  Assert-Natus ($firebaseRc.projects.default -eq $projectId) `
    'O projeto padrão do Firebase diverge da produção esperada.'
  Assert-Natus ($firebaseConfig.hosting.public -eq 'build/web') `
    'O diretório público do Hosting está incorreto.'
  Assert-Natus ($indexes.indexes.Count -gt 0) `
    'O arquivo de índices está vazio.'

  Invoke-NatusCommand 'dart format' {
    dart format --output=none --set-exit-if-changed lib test
  }
  Invoke-NatusCommand 'flutter analyze' { flutter analyze }
  Invoke-NatusCommand 'flutter test' { flutter test }
  Invoke-NatusCommand 'lint das Functions' {
    npm --prefix functions run lint
  }
  Invoke-NatusCommand 'testes das Functions' {
    npm --prefix functions test
  }
  Invoke-NatusCommand 'contrato das Functions' {
    npm --prefix functions run check:function-contract
  }
  Invoke-NatusCommand 'auditoria npm de produção' {
    npm --prefix functions audit --omit=dev --audit-level=high
  }
  Invoke-NatusCommand 'auditoria npm completa' {
    npm --prefix functions audit --audit-level=high
  }
  Invoke-NatusCommand 'integridade do diff' {
    git -c safe.directory=D:/Aplicativos/natus_gestantes diff --check
  }

  $previousErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & node functions/scripts/verify_hosting_release_readiness.js *> $null
  $dataGateExit = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorPreference
  if ($DataGate -eq 'PreMigration') {
    Assert-Natus ($dataGateExit -ne 0) `
      'O guard deveria bloquear o cliente antes da migração.'
  } else {
    Assert-Natus ($dataGateExit -eq 0) `
      'A auditoria pós-migração ainda não liberou o cliente.'
  }

  $pubspec = Get-Content pubspec.yaml -Raw
  Assert-Natus ($pubspec -match "(?m)^version:\s+$versionName\+$versionCode$") `
    'A versão do pubspec não corresponde ao release.'
  $gradle = Get-Content android\app\build.gradle.kts -Raw
  Assert-Natus ($gradle.Contains("applicationId = `"$packageId`"")) `
    'O applicationId Android está incorreto.'
  Assert-Natus ($gradle.Contains("namespace = `"$packageId`"")) `
    'O namespace Android está incorreto.'
  $googleServices = Get-Content android\app\google-services.json -Raw |
    ConvertFrom-Json
  $androidPackages = @(
    $googleServices.client.client_info.android_client_info.package_name
  )
  Assert-Natus ($androidPackages -contains $packageId) `
    'google-services.json não contém o pacote de produção.'

  $releaseApk = Resolve-Path build\app\outputs\flutter-apk\app-release.apk
  $siteApk = Resolve-Path web\downloads\natus-android-1.1.0.apk
  $builtSiteApk = Resolve-Path build\web\downloads\natus-android-1.1.0.apk
  $checksumFile = Resolve-Path web\downloads\natus-android-1.1.0.sha256
  $releaseHash = (Get-FileHash $releaseApk -Algorithm SHA256).Hash
  $siteHash = (Get-FileHash $siteApk -Algorithm SHA256).Hash
  $builtSiteHash = (Get-FileHash $builtSiteApk -Algorithm SHA256).Hash
  $declaredHash = ((Get-Content $checksumFile -Raw).Trim() -split '\s+')[0]
  Assert-Natus ($releaseHash -eq $siteHash) `
    'O APK assinado difere do APK do site.'
  Assert-Natus ($releaseHash -eq $builtSiteHash) `
    'O build web não contém o APK atual.'
  Assert-Natus ($releaseHash -eq $declaredHash.ToUpperInvariant()) `
    'O checksum publicado do APK está incorreto.'

  $buildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
    -Directory | Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
  Assert-Natus ($null -ne $buildTools) 'Android build-tools não encontrado.'
  $apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
  $newSignature = & $apksigner verify --verbose --print-certs $releaseApk 2>&1
  Assert-Natus ($LASTEXITCODE -eq 0) 'A assinatura do APK atual é inválida.'
  Assert-Natus (($newSignature -join "`n") -match `
      'Verified using v2 scheme \(APK Signature Scheme v2\): true') `
    'O APK atual não possui assinatura v2.'
  $newCertificate = [regex]::Match(
    ($newSignature -join "`n"),
    'Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)'
  ).Groups[1].Value
  Assert-Natus (-not [string]::IsNullOrWhiteSpace($newCertificate)) `
    'Não foi possível identificar o certificado do APK atual.'

  $expectedCertificate = (Get-Content android\release-cert.sha256 -Raw).Trim()
  Assert-Natus ($expectedCertificate -match '^[0-9A-F]{64}$') `
    'O fingerprint esperado do certificado é inválido.'
  Assert-Natus ($newCertificate.ToUpperInvariant() -eq $expectedCertificate) `
    'O certificado mudou e impediria a atualização do APK instalado.'

  $apkanalyzer = Get-ChildItem `
    "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools" -Recurse `
    -Filter apkanalyzer.bat | Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  Assert-Natus ($null -ne $apkanalyzer) 'apkanalyzer não encontrado.'
  $manifest = & $apkanalyzer.FullName manifest print $releaseApk 2>&1
  Assert-Natus ($LASTEXITCODE -eq 0) 'Não foi possível ler o manifesto do APK.'
  $manifestText = $manifest -join "`n"
  Assert-Natus ($manifestText -match "package=.?$([regex]::Escape($packageId))") `
    'O pacote compilado do APK está incorreto.'
  Assert-Natus ($manifestText -match 'com.google.android.geo.API_KEY') `
    'O APK não contém a configuração do Maps Android.'
  Assert-Natus ($manifestText -match 'AIza[0-9A-Za-z_-]{30,100}') `
    'O APK não contém a chave pública restrita do Maps.'

  $version = Get-Content build\web\version.json -Raw | ConvertFrom-Json
  Assert-Natus ($version.version -eq $versionName) `
    'A versão do build web está incorreta.'
  Assert-Natus ($version.build_number -eq $versionCode) `
    'O build number do web está incorreto.'
  Assert-Natus (Test-Path build\web\main.dart.js) `
    'main.dart.js não foi gerado.'
  $sourceMaps = @(Get-ChildItem build\web -Recurse -File -Filter *.map)
  Assert-Natus ($sourceMaps.Count -eq 0) `
    'O build web contém source maps.'
  $symbolsOutsideCanvasKit = @(
    Get-ChildItem build\web -Recurse -File -Filter *.symbols |
      Where-Object { $_.FullName -notlike '*\build\web\canvaskit\*' }
  )
  Assert-Natus ($symbolsOutsideCanvasKit.Count -eq 0) `
    'O build web contém símbolos fora do CanvasKit.'
  Assert-Natus ($firebaseConfig.hosting.ignore -contains '**/*.symbols') `
    'O Hosting precisa excluir símbolos do CanvasKit.'
  $webJavaScript = [IO.File]::ReadAllText(
    (Resolve-Path build\web\main.dart.js)
  )
  $googleApiKeys = @(
    [regex]::Matches($webJavaScript, 'AIza[0-9A-Za-z_-]{30,100}') |
      ForEach-Object Value | Sort-Object -Unique
  )
  $recaptchaKeys = @(
    [regex]::Matches(
      $webJavaScript,
      '["''](6L[0-9A-Za-z_-]{38})["'']'
    ) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  )
  Assert-Natus ($googleApiKeys.Count -ge 2) `
    'O build web não contém Firebase e Maps configurados.'
  Assert-Natus ($recaptchaKeys.Count -eq 1) `
    'O build web não contém exatamente uma chave do App Check.'

  $output = Join-Path $workspace $OutputPath
  $outputDirectory = Split-Path -Parent $output
  New-Item -ItemType Directory -Force $outputDirectory | Out-Null
  $manifestOutput = [ordered]@{
    schemaVersion = 1
    verifiedAt = [DateTimeOffset]::Now.ToString('o')
    projectId = $projectId
    dataGate = $DataGate
    gitCommit = (git -c safe.directory=D:/Aplicativos/natus_gestantes `
      rev-parse HEAD).Trim()
    version = "$versionName+$versionCode"
    packageId = $packageId
    apkSha256 = $releaseHash
    webMainSha256 = (Get-FileHash build\web\main.dart.js -Algorithm SHA256).Hash
    indexes = $indexes.indexes.Count
    status = 'ready'
  }
  $manifestOutput | ConvertTo-Json | Set-Content -LiteralPath $output `
    -Encoding utf8
  Write-Output "[gate] release candidate aprovado: $output"
} finally {
  Pop-Location
}
