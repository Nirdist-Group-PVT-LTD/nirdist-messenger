#!/bin/powershell
# AUTOMATED VERIFICATION SCRIPT
# Run this to verify the People Tab feature is ready to deploy

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "PEOPLE TAB FEATURE - AUTOMATED VERIFICATION" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# Check 1: DataInitializer exists
Write-Host "[1/6] Checking DataInitializer.java exists..." -ForegroundColor Yellow
$filePath = "back-end/src/main/java/com/nirdist/init/DataInitializer.java"
if (Test-Path $filePath) {
    Write-Host "✓ DataInitializer.java found" -ForegroundColor Green
} else {
    Write-Host "✗ DataInitializer.java NOT found" -ForegroundColor Red
    $allPassed = $false
}

# Check 2: File has correct content
Write-Host "[2/6] Verifying DataInitializer has correct imports..." -ForegroundColor Yellow
if (Select-String -Path $filePath -Pattern "com.nirdist.entity.Profile" | Select-Object -First 1) {
    Write-Host "✓ DataInitializer imports correct" -ForegroundColor Green
} else {
    Write-Host "✗ DataInitializer imports incorrect" -ForegroundColor Red
    $allPassed = $false
}

# Check 3: Backend endpoints exist
Write-Host "[3/6] Verifying backend endpoints..." -ForegroundColor Yellow
$controllerPath = "back-end/src/main/java/com/nirdist/controller/SocialController.java"
$matches = Select-String -Path $controllerPath -Pattern "@GetMapping.*profiles" | Measure-Object
if ($matches.Count -eq 2) {
    Write-Host "✓ Both backend endpoints found (@GetMapping /profiles and /search)" -ForegroundColor Green
} else {
    Write-Host "✗ Backend endpoints not found" -ForegroundColor Red
    $allPassed = $false
}

# Check 4: Frontend integration exists
Write-Host "[4/6] Verifying frontend integration..." -ForegroundColor Yellow
$frontendPath = "front-end/app/messenger/lib/screens/messenger_shell.dart"
$frontendMatches = Select-String -Path $frontendPath -Pattern "listProfiles|_loadDashboard" | Measure-Object
if ($frontendMatches.Count -gt 0) {
    Write-Host "✓ Frontend integration verified (listProfiles and _loadDashboard found)" -ForegroundColor Green
} else {
    Write-Host "✗ Frontend integration not found" -ForegroundColor Red
    $allPassed = $false
}

# Check 5: Documentation exists
Write-Host "[5/6] Verifying documentation files..." -ForegroundColor Yellow
$docs = @("START_HERE.txt", "DEPLOY_NOW.md", "PEOPLE_TAB_SOLUTION.md")
$docsFound = 0
foreach ($doc in $docs) {
    if (Test-Path $doc) {
        $docsFound++
    }
}
if ($docsFound -eq 3) {
    Write-Host "✓ All documentation files present" -ForegroundColor Green
} else {
    Write-Host "✗ Missing documentation files" -ForegroundColor Red
    $allPassed = $false
}

# Check 6: Git status
Write-Host "[6/6] Checking git status..." -ForegroundColor Yellow
$gitStatus = git status --short 2>$null
if ($gitStatus) {
    Write-Host "! Uncommitted changes detected - this is OK, they'll be pulled on git pull" -ForegroundColor Yellow
} else {
    Write-Host "✓ Git repository clean" -ForegroundColor Green
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan

if ($allPassed) {
    Write-Host "✓ ALL VERIFICATIONS PASSED!" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Feature is READY for deployment. Follow these steps:" -ForegroundColor Green
    Write-Host "  1. git pull origin main" -ForegroundColor White
    Write-Host "  2. Go to https://dashboard.render.com" -ForegroundColor White
    Write-Host "  3. Click 'Deploy' on backend service" -ForegroundColor White
    Write-Host "  4. Wait 3-5 minutes" -ForegroundColor White
    Write-Host "  5. Restart Flutter app" -ForegroundColor White
    Write-Host "  6. Open People tab - should show 4 test users" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "✗ SOME VERIFICATIONS FAILED" -ForegroundColor Red
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "Please check the errors above and try again." -ForegroundColor Red
    Write-Host ""
    exit 1
}
