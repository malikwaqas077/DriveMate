# Android: DEVELOPER_ERROR and Google Sign-In

## 1. Where to put `google-services.json`

The file must be **inside** the Android app folder, not in Downloads:

- **Correct path:** `drivemate_app/android/app/google-services.json`
- Copy your downloaded file from `C:\Users\wa1\Downloads\google-services.json` into that folder (replace the existing one).

## 2. Fixing DEVELOPER_ERROR (Google Play Services)

If you see in logcat:

```text
ConnectionResult{statusCode=DEVELOPER_ERROR, ...}
```

or "Not showing notification since connectionResult is not user-facing: DEVELOPER_ERROR", it means **your app’s signing certificate (SHA-1/SHA-256) is not registered** in the Firebase/Google Cloud project. Google Sign-In, FCM, and other Google APIs will fail until this is fixed.

## 1. Get your debug SHA-1 and SHA-256

From the project root (e.g. `D:\DriveMate\drivemate_app`), run:

**Windows (PowerShell):**
```powershell
cd android
./gradlew signingReport
```

Or with keytool (debug keystore is usually in `%USERPROFILE%\.android\debug.keystore`):

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copy the **SHA-1** and **SHA-256** lines from the output.

**Your current debug fingerprints** (from `./gradlew signingReport`):

- **SHA-1:** `C1:FA:02:A9:01:89:0D:95:96:84:9F:4F:05:D2:FA:C5:7D:95:92:7B`
- **SHA-256:** `BD:2D:2F:65:4B:E1:B4:BD:1D:E8:D5:AB:5C:3A:A6:19:F9:23:08:FA:B1:65:48:48:3A:9C:62:09:06:2B:DB:7D`

## 2. Add them in Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/) and select your project.
2. Go to **Project settings** (gear icon) → **Your apps**.
3. Select your **Android** app (package name: `app.techsol.drivemate`).
4. Click **Add fingerprint** and paste:
   - Your **SHA-1**
   - Then add another fingerprint with your **SHA-256**.
5. Save. Download the updated `google-services.json` if prompted and replace `android/app/google-services.json`.

## 3. If you use Google Sign-In

1. In Firebase: **Authentication** → **Sign-in method** → **Google** → enable and set support email.
2. In [Google Cloud Console](https://console.cloud.google.com/) for the same project:
   - **APIs & Services** → **Credentials**.
   - Ensure there is an **OAuth 2.0 Client ID** of type **Android** with:
     - Package name: `app.techsol.drivemate`
     - SHA-1: the same value you added in Firebase.

## 4. Rebuild and test

```bash
flutter clean
flutter pub get
flutter run
```

After adding the correct SHA-1 (and SHA-256) and matching package name, DEVELOPER_ERROR should stop and Google APIs will work.

---

## 3. Fixing "Google Sign-In did not return an ID token" (serverClientId)

On Android, Google Sign-In only returns an ID token (needed for Firebase Auth) if you pass the **Web client ID** as `serverClientId`.

**Steps:**

1. **Get the Web client ID**
   - Firebase Console → **Authentication** → **Sign-in method** → **Google** (enable if needed).
   - Open **Web SDK configuration** and copy the **Web client ID** (e.g. `98973897901-xxxx.apps.googleusercontent.com`).

2. **Set it in the app**
   - Open `drivemate_app/lib/firebase_options.dart`.
   - Find: `static const String? googleSignInWebClientId = null;`
   - Replace with: `static const String? googleSignInWebClientId = 'YOUR_WEB_CLIENT_ID';` (paste the ID you copied).

3. **Rebuild and run**
   - `flutter clean` → `flutter pub get` → `flutter run`

After this, "Continue with Google" should work and the red error banner should disappear.
