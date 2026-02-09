# Fix App Icon Margins - Add Safe Zone Padding
# This script adds proper padding to existing app icons to comply with Android adaptive icon safe zone

Write-Host "DriveMate Icon Margin Fix" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will add proper padding (safe zone) to your app icons." -ForegroundColor Yellow
Write-Host "Android adaptive icons require 17% padding on all sides (safe zone)." -ForegroundColor Gray
Write-Host ""

$basePath = "d:\DriveMate\drivemate_app\android\app\src\main\res"
$backupPath = "d:\DriveMate\drivemate_app\android\app\src\main\res\icon_backup"

# Check if ImageMagick is available
$magickAvailable = $false
try {
    $null = Get-Command magick -ErrorAction Stop
    $magickAvailable = $true
    Write-Host "✓ ImageMagick found" -ForegroundColor Green
} catch {
    Write-Host "✗ ImageMagick not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install ImageMagick to use this script:" -ForegroundColor Yellow
    Write-Host "  Download: https://imagemagick.org/script/download.php" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Alternative: Recreate icons manually with proper padding (see docs/fix-icon-margins.md)" -ForegroundColor Cyan
    exit 1
}

# Create backup
Write-Host ""
Write-Host "Creating backup of existing icons..." -ForegroundColor Yellow
if (-not (Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath | Out-Null
}

$densities = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($folder in $densities.Keys) {
    $iconPath = Join-Path $basePath $folder "ic_launcher.png"
    $backupIconPath = Join-Path $backupPath "$folder-ic_launcher.png"
    
    if (Test-Path $iconPath) {
        Copy-Item $iconPath $backupIconPath -Force
        Write-Host "  Backed up: $folder" -ForegroundColor Gray
    }
}

Write-Host "✓ Backup created" -ForegroundColor Green
Write-Host ""

# Process each icon
Write-Host "Processing icons with safe zone padding..." -ForegroundColor Yellow
Write-Host ""

foreach ($folder in $densities.Keys) {
    $size = $densities[$folder]
    $iconPath = Join-Path $basePath $folder "ic_launcher.png"
    
    if (-not (Test-Path $iconPath)) {
        Write-Host "  ⚠ Skipping $folder (icon not found)" -ForegroundColor Yellow
        continue
    }
    
    # Calculate safe zone: 66% of total size (centered)
    # This means we scale the logo to 66% and center it
    $safeZoneSize = [math]::Round($size * 0.66)
    $padding = [math]::Round(($size - $safeZoneSize) / 2)
    
    # Create temporary padded version
    $tempFile = Join-Path $env:TEMP "icon_temp_$folder.png"
    
    # Step 1: Scale logo to safe zone size (66%)
    magick convert $iconPath -resize "${safeZoneSize}x${safeZoneSize}" $tempFile
    
    # Step 2: Add black padding to center it in full size
    magick convert $tempFile -background black -gravity center -extent "${size}x${size}" $iconPath
    
    # Cleanup temp file
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    Write-Host "  ✓ Processed $folder (${size}x${size} → safe zone: ${safeZoneSize}x${safeZoneSize})" -ForegroundColor Green
}

Write-Host ""
Write-Host "✓ Icon processing complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Clean build: flutter clean" -ForegroundColor White
Write-Host "  2. Build APK: flutter build apk" -ForegroundColor White
Write-Host "  3. Install and verify icon has proper margins" -ForegroundColor White
Write-Host ""
Write-Host "Note: The logo will appear slightly smaller to accommodate the safe zone." -ForegroundColor Gray
Write-Host "If you want the logo larger, recreate icons from source with proper padding." -ForegroundColor Gray
Write-Host ""
Write-Host "Backup location: $backupPath" -ForegroundColor Gray
