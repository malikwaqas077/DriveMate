# Fixing Google Sign-In After Uploading to Play Store

When Google Sign-In works in debug mode but fails after uploading to Play Store, it's because the **signing certificate SHA-1/SHA-256** used by Play Store is not registered in Firebase.

---

## Important: Play App Signing vs Upload Keystore

**Google Play App Signing** (enabled by default for new apps) means:
- You upload an AAB signed with your **upload keystore**
- Google Play **re-signs** your app with their own **app signing key**
- Users download apps signed with Google Play's key, **not** your upload keystore

**Therefore:** You need to add **Google Play's app signing certificate SHA-1/SHA-256** to Firebase, not your upload keystore SHA-1.

---

## Solution: Get Play Store App Signing Certificate

### Step 1: Get Google Play App Signing Certificate SHA-1/SHA-256

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: **DriveMate**
3. In the left sidebar, navigate to: **Test and release** → **App integrity**
   - (Alternatively: **Test and release** → **Setup** → **App signing**)
4. On the App integrity page, scroll to **App signing key certificate** section
   - ⚠️ **Note:** This is different from "Internal testing certificate" section
5. Copy the **SHA-1 certificate fingerprint** and **SHA-256 certificate fingerprint**

**Example:**
```
SHA-1: A1:B2:C3:D4:E5:F6:...
SHA-256: 12:34:56:78:90:AB:CD:EF:...
```

**Note:** If you don't see this section, Play App Signing might not be enabled. In that case, use your upload keystore SHA-1 (see Step 2).

---

### Step 2: Alternative - Get Your Upload Keystore SHA-1 (if Play App Signing is disabled)

If Play App Signing is **disabled**, get your upload keystore fingerprints:

```powershell
cd drivemate_app\android
keytool -list -v -keystore upload-keystore.jks -alias upload
```

Enter your keystore password (check `android/key.properties` if you forgot it).

Copy the **SHA-1** and **SHA-256** values from the output.

---

### Step 3: Add SHA-1/SHA-256 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **drivemate-ac4ad**
3. Click **gear icon** → **Project settings**
4. Scroll to **Your apps** section
5. Click on your **Android app** (package: `app.techsol.drivemate`)
6. Click **Add fingerprint** button
7. Paste the **SHA-1** fingerprint (from Step 1 or Step 2)
8. Click **Add fingerprint** again
9. Paste the **SHA-256** fingerprint
10. Click **Save**
11. **Download the updated `google-services.json`** file
12. Replace `drivemate_app/android/app/google-services.json` with the downloaded file

---

### Step 4: Add SHA-1 to Google Cloud Console (OAuth)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **drivemate-ac4ad**
3. Navigate to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client ID** of type **Android** (package: `app.techsol.drivemate`)
5. Click to edit it
6. In the **SHA-1 certificate fingerprint** field, add the SHA-1 from Step 1 or Step 2
7. Click **Save**

**Note:** You can have multiple SHA-1 fingerprints (one for debug, one for release/Play Store).

---

### Step 5: Verify Web Client ID is Set

The Web Client ID is already configured correctly in your `firebase_options.dart`:

```dart
static const String? googleSignInWebClientId = '98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com';
```

✅ This is correct and doesn't need to be changed.

---

### Step 6: Wait for Propagation

After updating Firebase and Google Cloud Console:
- **Wait 5-10 minutes** for changes to propagate
- Changes may take up to 30 minutes in rare cases

---

### Step 7: Test the Fix

You have two options:

#### Option A: Test with Internal Testing Track (Recommended)

1. Build a new AAB:
   ```powershell
   cd drivemate_app
   flutter clean
   flutter build appbundle
   ```

2. Upload to Play Console → **Internal testing** track
3. Install the app from the internal testing link
4. Test Google Sign-In

#### Option B: Test with Release APK (Faster)

1. Build a release APK signed with your upload keystore:
   ```powershell
   cd drivemate_app
   flutter clean
   flutter build apk --release
   ```

2. Install the APK directly on your device:
   ```powershell
   flutter install --release
   ```

3. Test Google Sign-In

**Note:** Option B only works if Play App Signing is disabled. If Play App Signing is enabled, you must use Option A (internal testing track) because Google Play re-signs the app.

---

## Verification Checklist

Before testing, verify:

- [ ] **SHA-1 added to Firebase** → Project settings → Android app → Fingerprints
- [ ] **SHA-256 added to Firebase** → Project settings → Android app → Fingerprints  
- [ ] **SHA-1 added to Google Cloud** → Credentials → OAuth 2.0 Client ID (Android)
- [ ] **`google-services.json` updated** → Downloaded from Firebase and replaced in `android/app/`
- [ ] **Web Client ID set** → `firebase_options.dart` has `googleSignInWebClientId` (already done ✅)
- [ ] **Waited 5-10 minutes** → For Firebase/Google Cloud changes to propagate
- [ ] **New build created** → After making all changes

---

## Current Configuration Status

Based on your `google-services.json`:

✅ **Debug SHA-1 registered:** `c1fa02a901890d9596849f4f05d2fac57d95927b`  
✅ **Release SHA-1 registered:** `e5ccbf3c41485da9b513b7692a8beb2b9d33d116`  
✅ **Web Client ID:** `98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com`

**If Google Sign-In still fails:**

1. **Check Play App Signing status** in Play Console → Release → Setup → App signing
2. **If Play App Signing is enabled:** Add Google Play's app signing certificate SHA-1/SHA-256 (from Step 1)
3. **If Play App Signing is disabled:** Verify your upload keystore SHA-1 matches what's in Firebase
4. **Check logcat** for specific errors:
   ```powershell
   adb logcat | findstr "GoogleSignIn\|DEVELOPER_ERROR\|FirebaseAuth"
   ```

---

## Troubleshooting

### Error: "DEVELOPER_ERROR"
- **Cause:** SHA-1 fingerprint mismatch between the app and Firebase/Google Cloud
- **Fix:** Verify the correct SHA-1 is added (Play App Signing certificate if enabled, upload keystore if disabled)

### Error: "Google Sign-In did not return an ID token"
- **Cause:** Missing or incorrect Web Client ID
- **Fix:** Already configured correctly ✅

### Works in debug but not after Play Store install
- **Cause:** Play Store uses a different signing certificate than debug
- **Fix:** Add Play Store app signing certificate SHA-1/SHA-256 to Firebase (Step 1)

### Changes not taking effect
- **Wait longer:** Firebase/Google Cloud changes can take 5-30 minutes to propagate
- **Clear app data:** Uninstall and reinstall the app
- **Rebuild:** Create a fresh build after updating `google-services.json`

---

## Summary

1. **Get SHA-1/SHA-256** from Play Console → Release → Setup → App signing (if Play App Signing enabled)
   OR from your upload keystore (if Play App Signing disabled)
2. **Add to Firebase** → Project settings → Android app → Fingerprints
3. **Add to Google Cloud** → Credentials → OAuth 2.0 Client ID (Android)
4. **Download updated `google-services.json`** and replace in `android/app/`
5. **Wait 5-10 minutes** for propagation
6. **Build and test** via internal testing track

After these steps, Google Sign-In should work in Play Store builds! 🎉
