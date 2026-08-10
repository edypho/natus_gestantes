[CmdletBinding()]
param(
    [string]$KeystorePath = "$env:USERPROFILE\.natus\android-signing\natus-release.jks",
    [string]$PropertiesPath = "$PSScriptRoot\..\android\key.properties",
    [string]$KeyAlias = "natus-release"
)

$ErrorActionPreference = "Stop"

$resolvedPropertiesPath = [System.IO.Path]::GetFullPath($PropertiesPath)
$resolvedKeystorePath = [System.IO.Path]::GetFullPath($KeystorePath)

if (Test-Path -LiteralPath $resolvedKeystorePath) {
    throw "O keystore ja existe. A operacao foi interrompida para preservar a identidade de assinatura."
}

if (Test-Path -LiteralPath $resolvedPropertiesPath) {
    throw "android/key.properties ja existe. A operacao foi interrompida sem sobrescrever segredos."
}

$keytoolCommand = Get-Command keytool -ErrorAction SilentlyContinue
$keytoolPath = if ($keytoolCommand) {
    $keytoolCommand.Source
} else {
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
}

if (-not (Test-Path -LiteralPath $keytoolPath)) {
    throw "keytool nao encontrado. Instale ou configure o JDK do Android Studio."
}

$keystoreDirectory = Split-Path -Parent $resolvedKeystorePath
$propertiesDirectory = Split-Path -Parent $resolvedPropertiesPath
New-Item -ItemType Directory -Path $keystoreDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $propertiesDirectory -Force | Out-Null

$passwordBytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
$password = [Convert]::ToHexString($passwordBytes)
$env:NATUS_ANDROID_STORE_PASSWORD = $password
$env:NATUS_ANDROID_KEY_PASSWORD = $password

try {
    & $keytoolPath `
        -genkeypair `
        -v `
        -storetype PKCS12 `
        -keystore $resolvedKeystorePath `
        -alias $KeyAlias `
        -keyalg RSA `
        -keysize 4096 `
        -validity 10000 `
        -dname "CN=Natus, OU=Aplicativos, O=Natus, L=Curitiba, ST=Parana, C=BR" `
        -storepass:env NATUS_ANDROID_STORE_PASSWORD `
        -keypass:env NATUS_ANDROID_KEY_PASSWORD

    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao gerar o keystore Android."
    }

    $propertiesContent = @(
        "storeFile=$($resolvedKeystorePath.Replace('\', '/'))"
        "storePassword=$password"
        "keyAlias=$KeyAlias"
        "keyPassword=$password"
        ""
    ) -join [Environment]::NewLine

    [System.IO.File]::WriteAllText(
        $resolvedPropertiesPath,
        $propertiesContent,
        [System.Text.UTF8Encoding]::new($false)
    )

    & $keytoolPath `
        -list `
        -keystore $resolvedKeystorePath `
        -alias $KeyAlias `
        -storepass:env NATUS_ANDROID_STORE_PASSWORD | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "O keystore foi criado, mas a verificacao do alias falhou."
    }

    Write-Output "ANDROID_SIGNING_CREATED"
    Write-Output "KEYSTORE_PATH=$resolvedKeystorePath"
    Write-Output "PROPERTIES_PATH=$resolvedPropertiesPath"
    Write-Output "KEY_ALIAS=$KeyAlias"
} finally {
    Remove-Item Env:NATUS_ANDROID_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:NATUS_ANDROID_KEY_PASSWORD -ErrorAction SilentlyContinue
    if ($passwordBytes) {
        [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
    }
    $password = $null
}
