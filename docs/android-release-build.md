# Creating a Signed APK/AAB for Google Play Console

This guide explains how to build a signed **Android App Bundle (AAB)** or **APK** for publishing DriveMate to Google Play Console.

> **Note:** Google Play requires **AAB (Android App Bundle)** for new app submissions. AAB produces smaller downloads for users. Use APK only if you need to distribute outside Play Store.

---

## Step 1: Create an Upload Keystore

Run this command **once** to create your release signing key. Store the keystore file and passwords securely—you'll need them for all future updates.

**From `drivemate_app` directory:**

```powershell
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted for:
- **Keystore password** – choose a strong password
- **Key password** – can be the same as keystore password
- **Name, organization, city, etc.** – used for certificate metadata

**Important:** Keep the keystore file (`upload-keystore.jks`) and passwords in a safe place. If you lose them, you cannot update your app on Play Store.

---

## Step 2: Create `key.properties`

1. Copy the example file:
   ```powershell
   copy android\key.properties.example android\key.properties
   ```

2. Edit `android/key.properties` and fill in your values:

   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

   - `storeFile` is relative to the `android/` folder. If your keystore is elsewhere, use a path like `../path/to/upload-keystore.jks`.

`key.properties` and `*.jks` are in `.gitignore`—never commit them.

---

## Step 3: Add Release SHA-1/SHA-256 to Firebase

Google Sign-In and other Google APIs require your **release** certificate fingerprints.

1. Get the fingerprints:
   ```powershell
   cd drivemate_app\android
   keytool -list -v -keystore upload-keystore.jks -alias upload
   ```
   Copy the **SHA-1** and **SHA-256** values.

2. In [Firebase Console](https://console.firebase.google.com/) → Project settings → Your apps → Android app:
   - Add both **SHA-1** and **SHA-256** as fingerprints.
   - Download the updated `google-services.json` and replace `android/app/google-services.json`.

3. If using Google Sign-In, add the same SHA-1 in [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → OAuth 2.0 Client IDs (Android client).

---

## Step 4: Build the App

### Option A: Android App Bundle (recommended for Play Store)

```powershell
cd d:\DriveMate\drivemate_app
flutter build appbundle
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Upload this file to [Google Play Console](https://play.google.com/console) → Your app → Production (or Testing) → Create new release.

### Option B: Signed APK

```powershell
cd d:\DriveMate\drivemate_app
flutter build apk
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Use this for direct distribution or internal testing. Play Store prefers AAB.

---

## Step 5: Versioning

Update version in `pubspec.yaml` before each release:

```yaml
version: 1.0.0+1   # 1.0.0 = versionName, 1 = versionCode
```

- **versionName** (e.g. `1.0.0`) – shown to users
- **versionCode** (e.g. `1`) – must increase for each Play Store upload

Or override at build time:

```powershell
flutter build appbundle --build-name=1.0.1 --build-number=2
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `key.properties` not found | Ensure the file exists at `android/key.properties` |
| Wrong signing | Verify `keyAlias` matches the alias used in `keytool -genkey` |
| DEVELOPER_ERROR after release | Add release SHA-1/SHA-256 to Firebase and Google Cloud Console |
| Build fails with signing error | Check passwords and `storeFile` path in `key.properties` |

---

## Summary

1. Create keystore: `keytool -genkey -v -keystore android/upload-keystore.jks ...`
2. Create `android/key.properties` with store/key passwords and alias
3. Add release SHA-1/SHA-256 to Firebase and Google Cloud
4. Build: `flutter build appbundle` (or `flutter build apk`)
5. Upload the `.aab` to Google Play Console
