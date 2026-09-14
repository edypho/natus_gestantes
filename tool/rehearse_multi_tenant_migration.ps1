param(
  [Parameter(Mandatory = $true)]
  [string]$BackupPath
)

$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $PSScriptRoot
$backup = (Resolve-Path -LiteralPath $BackupPath).Path
$tenantFile = Join-Path $workspace '.local-private\migration\target-tenant.txt'
$tenant = (Get-Content -LiteralPath $tenantFile -Raw).Trim()

if ([string]::IsNullOrWhiteSpace($tenant)) {
  throw 'Tenant de ensaio ausente.'
}

$firestoreHost = $env:FIRESTORE_EMULATOR_HOST
$authHost = $env:FIREBASE_AUTH_EMULATOR_HOST
$storageHost = $env:FIREBASE_STORAGE_EMULATOR_HOST

if ([string]::IsNullOrWhiteSpace($firestoreHost) -or
    [string]::IsNullOrWhiteSpace($authHost) -or
    [string]::IsNullOrWhiteSpace($storageHost)) {
  throw 'Os três Emulators precisam estar ativos.'
}

Push-Location $workspace
try {
  node functions/scripts/restore_firebase_emulator.js `
    --project demo-natus `
    --input $backup `
    --firestore-emulator-host $firestoreHost `
    --auth-emulator-host $authHost `
    --storage-emulator-host $storageHost `
    --storage-bucket natus-gestantes.firebasestorage.app `
    --restore-storage
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao restaurar o backup.' }

  node functions/scripts/migrate_multi_tenant.js `
    --project demo-natus `
    --emulator-host $firestoreHost `
    --auth-emulator-host $authHost `
    --tenant $tenant `
    --output .local-private\migration\emulator-plan `
    --apply
  if ($LASTEXITCODE -ne 0) { throw 'Falha no backfill do Emulator.' }

  node functions/scripts/migrate_multi_tenant.js `
    --project demo-natus `
    --emulator-host $firestoreHost `
    --auth-emulator-host $authHost `
    --tenant $tenant `
    --output .local-private\migration\emulator-plan-second-pass `
    --apply
  if ($LASTEXITCODE -ne 0) { throw 'O segundo backfill não foi idempotente.' }

  node functions/scripts/audit_multi_tenant.js `
    --project demo-natus `
    --emulator-host $firestoreHost `
    --auth-emulator-host $authHost `
    --include-auth `
    --output .local-private\migration\emulator-audit
  if ($LASTEXITCODE -ne 0) { throw 'A auditoria pós-migração não ficou verde.' }

  npm --prefix functions run test:emulator
  if ($LASTEXITCODE -ne 0) { throw 'Os testes integrados falharam.' }
} finally {
  Pop-Location
}
