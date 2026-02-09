# App Icon Setup Guide

This guide explains how to generate app icons from your source image for DriveMate.

## Source Image

Your source image is located at:
```
C:\Users\wa1\Downloads\ChatGPT Image Feb 5, 2026, 03_09_45 PM.png
```

This image contains the "DM" logo with a blue-to-teal gradient swoosh on a black background.

---

## Method 1: Using Flutter Launcher Icons (Recommended)

### Step 1: Add flutter_launcher_icons to pubspec.yaml

Add this to your `dev_dependencies` section in `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.13.1  # Add this line
```

### Step 2: Configure flutter_launcher_icons

Add this configuration section to `pubspec.yaml` (at the root level, same level as `dependencies`):

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/app_icon.png"  # We'll copy your image here
  adaptive_icon_background: "#000000"  # Black background
  adaptive_icon_foreground: "assets/app_icon.png"
  remove_alpha_ios: true
```

### Step 3: Copy Your Image

1. Create an `assets` folder in `drivemate_app` if it doesn't exist
2. Copy your source image to `drivemate_app/assets/app_icon.png`
   ```powershell
   Copy-Item "C:\Users\wa1\Downloads\ChatGPT Image Feb 5, 2026, 03_09_45 PM.png" "d:\DriveMate\drivemate_app\assets\app_icon.png"
   ```

### Step 4: Generate Icons

```powershell
cd d:\DriveMate\drivemate_app
flutter pub get
flutter pub run flutter_launcher_icons
```

This will automatically generate all required icon sizes for Android and iOS!

---

## Method 2: Manual Generation (Alternative)

If you prefer manual control or Method 1 doesn't work, you can use online tools or image editing software.

### Required Android Icon Sizes

Copy your source image to these locations with the correct sizes:

| Density | Size | Location |
|---------|------|----------|
| mdpi | 48x48 px | `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` |
| hdpi | 72x72 px | `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` |
| xhdpi | 96x96 px | `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` |
| xxhdpi | 144x144 px | `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` |
| xxxhdpi | 192x192 px | `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` |

### Online Tools

You can use these online tools to generate icons:
- [App Icon Generator](https://appicon.co/)
- [Icon Kitchen](https://icon.kitchen/)
- [MakeAppIcon](https://makeappicon.com/)

Upload your source image and download the generated icons, then place them in the appropriate folders.

---

## Method 3: Using ImageMagick (PowerShell Script)

If you have ImageMagick installed, you can use this PowerShell script:

```powershell
# Install ImageMagick first: https://imagemagick.org/script/download.php

$sourceImage = "C:\Users\wa1\Downloads\ChatGPT Image Feb 5, 2026, 03_09_45 PM.png"
$basePath = "d:\DriveMate\drivemate_app\android\app\src\main\res"

# Create directories if they don't exist
$sizes = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($folder in $sizes.Keys) {
    $size = $sizes[$folder]
    $outputPath = Join-Path $basePath $folder "ic_launcher.png"
    New-Item -ItemType Directory -Force -Path (Split-Path $outputPath) | Out-Null
    magick convert $sourceImage -resize "${size}x${size}" -background black -gravity center -extent "${size}x${size}" $outputPath
    Write-Host "Generated $outputPath ($size x $size)"
}
```

---

## Verification

After generating icons, verify they exist:

```powershell
cd d:\DriveMate\drivemate_app\android\app\src\main\res
Get-ChildItem -Recurse -Filter "ic_launcher.png" | Select-Object FullName
```

You should see 5 icon files (one for each density).

---

## Next Steps

After generating icons:
1. Rebuild your app: `flutter clean && flutter build apk`
2. Install and verify the icon appears correctly on your device
3. Test on different screen densities if possible

---

## Notes

- The source image should be square (or will be cropped to square)
- For best results, use a high-resolution source image (at least 1024x1024 px)
- The black background matches your logo design
- Android adaptive icons require both foreground and background layers (handled automatically by flutter_launcher_icons)
