Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$backendDir = Join-Path $PSScriptRoot 'back-end'

Write-Host 'Starting Nirdist backend with the local H2 profile...' -ForegroundColor Cyan
Write-Host 'Backend directory:' $backendDir -ForegroundColor DarkGray
Write-Host 'URL: http://127.0.0.1:8080/api/health' -ForegroundColor DarkGray

Push-Location $backendDir
try {
  mvn -q spring-boot:run -Dspring-boot.run.profiles=local
} finally {
  Pop-Location
}
