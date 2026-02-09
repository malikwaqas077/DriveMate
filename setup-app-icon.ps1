# DriveMate App Icon Setup Script
# This script copies your source image and sets up app icons

Write-Host "DriveMate App Icon Setup" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Source image path
$sourceImage = "C:\Users\wa1\Downloads\ChatGPT Image Feb 5, 2026, 03_09_45 PM.png"
$targetImage = "d:\DriveMate\drivemate_app\assets\app_icon.png"
$assetsDir = "d:\DriveMate\drivemate_app\assets"

# Check if source image exists
if (-not (Test-Path $sourceImage)) {
    Write-Host "ERROR: Source image not found at:" -ForegroundColor Red
    Write-Host "  $sourceImage" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please check the path and try again." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Source image found" -ForegroundColor Green

# Create assets directory if it doesn't exist
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir | Out-Null
    Write-Host "✓ Created assets directory" -ForegroundColor Green
} else {
    Write-Host "✓ Assets directory exists" -ForegroundColor Green
}

# Copy source image
Write-Host ""
Write-Host "Copying source image..." -ForegroundColor Yellow
Copy-Item $sourceImage $targetImage -Force
Write-Host "✓ Image copied to: $targetImage" -ForegroundColor Green

# Check if flutter_launcher_icons is installed
Write-Host ""
Write-Host "Checking dependencies..." -ForegroundColor Yellow
Set-Location "d:\DriveMate\drivemate_app"
flutter pub get | Out-Null

# Generate icons
Write-Host ""
Write-Host "Generating app icons..." -ForegroundColor Yellow
Write-Host "This may take a moment..." -ForegroundColor Gray
flutter pub run flutter_launcher_icons

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ App icons generated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Test the app: flutter run" -ForegroundColor White
    Write-Host "  2. Check the animated splash screen" -ForegroundColor White
    Write-Host "  3. Verify app icon appears on device" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "ERROR: Icon generation failed" -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: See docs/app-icon-setup.md for manual methods" -ForegroundColor Cyan
}
