param(
  [string]$DatabaseUrl = $env:JDBC_DATABASE_URL,
  [string]$DbUser = $env:DB_USER,
  [string]$DbPassword = $env:DB_PASSWORD,
  [switch]$DisableSeedData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw 'Provide a Neon connection string with -DatabaseUrl or the JDBC_DATABASE_URL environment variable.'
}

$env:JDBC_DATABASE_URL = $DatabaseUrl

if (-not [string]::IsNullOrWhiteSpace($DbUser)) {
  $env:DB_USER = $DbUser
}

if (-not [string]::IsNullOrWhiteSpace($DbPassword)) {
  $env:DB_PASSWORD = $DbPassword
}

if ($DisableSeedData.IsPresent) {
  $env:INIT_TEST_DATA = 'false'
}

$backendDir = Join-Path $PSScriptRoot 'back-end'

Write-Host 'Starting Nirdist backend with Neon PostgreSQL...' -ForegroundColor Cyan
Write-Host 'Backend directory:' $backendDir -ForegroundColor DarkGray
Write-Host 'Health URL: http://127.0.0.1:8080/api/health' -ForegroundColor DarkGray

Push-Location $backendDir
try {
  mvn -q spring-boot:run
} finally {
  Pop-Location
}
