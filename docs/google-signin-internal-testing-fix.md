# Fixing Google Sign-In for Internal Testing/Internal Sharing

When uploading your app to Google Play Console for **internal testing** or **internal sharing**, Google Sign-In may fail because:

1. **Release SHA-1 fingerprint not registered** - Internal testing builds use release signing keys
2. **Web Client ID missing** - Required for Google Sign-In to return ID tokens on Android

---

## Issue: Google Sign-In Not Working in Internal Testing Builds

**Symptoms:**
- Google Sign-In works in debug builds but fails in release/internal testing builds
- Error: "Google Sign-In did not return an ID token"
- Error: "DEVELOPER_ERROR" in logcat
- Sign-in button doesn't respond or shows error

**Root Cause:**
Internal testing builds are signed with your **release keystore**, which has different SHA-1/SHA-256 fingerprints than your debug keystore. These fingerprints must be registered in Firebase and Google Cloud Console.

---

## Solution Steps

### Step 1: Get Your Release Keystore SHA-1 and SHA-256

If you have your release keystore (`upload-keystore.jks`), get the fingerprints:

```powershell
cd drivemate_app\android
keytool -list -v -keystore upload-keystore.jks -alias upload
```

Enter your keystore password when prompted. Copy the **SHA-1** and **SHA-256** values.

**Example output:**
```
Certificate fingerprints:
     SHA1: E5:CC:BF:3C:41:48:5D:A9:B5:13:B7:69:2A:8B:EB:2B:9D:33:D1:16
     SHA256: A1:B2:C3:D4:E5:F6:... (longer string)
```

**If you don't have the keystore password:**
- Check your `android/key.properties` file (if it exists)
- Or check your password manager/secure notes
- **Important:** If you've lost the keystore, you'll need to create a new one and register new fingerprints

---

### Step 2: Add Release SHA-1/SHA-256 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **drivemate-ac4ad**
3. Click the **gear icon** → **Project settings**
4. Scroll to **Your apps** section
5. Click on your **Android app** (package: `app.techsol.drivemate`)
6. Click **Add fingerprint** button
7. Paste your **release SHA-1** fingerprint
8. Click **Add fingerprint** again and paste your **release SHA-256** fingerprint
9. Click **Save**
10. **Download the updated `google-services.json`** file
11. Replace `drivemate_app/android/app/google-services.json` with the downloaded file

---

### Step 3: Verify Release SHA-1 in Google Cloud Console (OAuth)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **drivemate-ac4ad**
3. Navigate to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client ID** of type **Android** (package: `app.techsol.drivemate`)
5. Click to edit it
6. Verify the **SHA-1 certificate fingerprint** matches your release SHA-1
7. If it doesn't match or is missing:
   - Add your release SHA-1 fingerprint
   - Save the changes

**Note:** There should be separate OAuth clients for:
- Debug SHA-1 (for local testing)
- Release SHA-1 (for Play Store builds)

---

### Step 4: Verify Web Client ID is Set

The Web Client ID is required for Google Sign-In to return ID tokens on Android.

1. Check `drivemate_app/lib/firebase_options.dart`:
   ```dart
   static const String? googleSignInWebClientId = '98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com';
   ```
   It should **NOT** be `null`.

2. **To find the Web Client ID manually:**
   - Firebase Console → **Authentication** → **Sign-in method**
   - Click **Google** provider
   - Open **Web SDK configuration**
   - Copy the **Web client ID** (format: `98973897901-xxxx.apps.googleusercontent.com`)

3. **Alternative:** Check `google-services.json`:
   - Look for `client_type: 3` in the `oauth_client` array
   - That's your Web client ID

---

### Step 5: Rebuild and Test

After updating fingerprints and Web Client ID:

```powershell
cd drivemate_app
flutter clean
flutter pub get
flutter build appbundle  # or flutter build apk
```

Upload the new build to Google Play Console → Internal testing track.

---

## Verification Checklist

Before uploading to internal testing, verify:

- [ ] Release SHA-1 added to Firebase Console → Project settings → Android app → Fingerprints
- [ ] Release SHA-256 added to Firebase Console → Project settings → Android app → Fingerprints
- [ ] Release SHA-1 matches in Google Cloud Console → Credentials → OAuth 2.0 Client ID (Android)
- [ ] `google-services.json` downloaded and updated in `android/app/`
- [ ] `firebase_options.dart` has `googleSignInWebClientId` set (not null)
- [ ] Google Sign-In enabled in Firebase Console → Authentication → Sign-in method → Google
- [ ] New build created after making changes

---

## Current Configuration Status

Based on your `google-services.json`:

✅ **Debug SHA-1 registered:** `c1fa02a901890d9596849f4f05d2fac57d95927b`  
✅ **Release SHA-1 registered:** `e5ccbf3c41485da9b513b7692a8beb2b9d33d116`  
✅ **Web Client ID:** `98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com`

**If Google Sign-In still fails after these steps:**

1. **Double-check** the release SHA-1 in Firebase matches the keystore you're using
2. **Verify** the Web Client ID is correct in `firebase_options.dart`
3. **Check logcat** for specific error messages:
   ```powershell
   flutter run --release
   # Then check logcat for DEVELOPER_ERROR or other Google Sign-In errors
   ```
4. **Wait 5-10 minutes** after updating Firebase/Google Cloud settings (propagation delay)

---

## Troubleshooting Common Errors

### "DEVELOPER_ERROR" in logcat
- **Cause:** SHA-1 fingerprint mismatch
- **Fix:** Verify release SHA-1 is correctly added in Firebase and Google Cloud Console

### "Google Sign-In did not return an ID token"
- **Cause:** Missing or incorrect Web Client ID
- **Fix:** Set `googleSignInWebClientId` in `firebase_options.dart` to the Web client ID

### Sign-in button doesn't respond
- **Cause:** Missing SHA-1 or Web Client ID configuration
- **Fix:** Follow Steps 1-4 above

### Works in debug but not release
- **Cause:** Only debug SHA-1 is registered, release SHA-1 is missing
- **Fix:** Add release SHA-1/SHA-256 to Firebase and Google Cloud Console

---

## Additional Notes

- **Google Play App Signing:** If you're using Google Play App Signing, Google may re-sign your app with their own key. In that case, you need to:
  1. Go to Google Play Console → Your app → Release → Setup → App signing
  2. Copy the **App signing key certificate** SHA-1/SHA-256
  3. Add those fingerprints to Firebase (not your upload keystore fingerprints)

- **Internal Testing vs Production:** Both use release signing, so the same fingerprints apply.

- **Multiple Build Variants:** If you have different build variants (e.g., staging, production), each may need its own SHA-1 registered if they use different signing keys.
