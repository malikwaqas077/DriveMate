# Adding Closed Testing Certificate Fingerprints

## Why You Need This

**Internal Testing** and **Closed Testing** use **different certificates**:
- ✅ **Internal Testing** uses: Internal testing certificate (already added - that's why it works!)
- ❌ **Closed Testing** uses: **App signing key certificate** (NOT added yet - that's why closed testing fails!)

**Closed Testing, Open Testing, and Production all use the same certificate** (App signing key certificate).

---

## Step 1: Get App Signing Key Certificate from Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: **DriveMate**
3. In the left sidebar, click **Test and release** → **App integrity**
   - (Alternatively, it might be under **Test and release** → **Setup** → **App signing**)
4. On the App integrity page, scroll down to find the **App signing** section
5. Look for **App signing key certificate** section
   - ⚠️ **Important:** This is DIFFERENT from "Internal testing certificate" section
   - You should see TWO certificate sections:
     - **Internal testing certificate** (you already have this one)
     - **App signing key certificate** ← **This is what you need!**
6. Copy both from the **App signing key certificate** section:
   - **SHA-1 certificate fingerprint** (format: `XX:XX:XX:XX:...`)
   - **SHA-256 certificate fingerprint** (format: `XX:XX:XX:XX:...`)

**Example of what you'll see:**
```
App signing key certificate
SHA-1 certificate fingerprint: A1:B2:C3:D4:E5:F6:...
SHA-256 certificate fingerprint: 12:34:56:78:90:AB:CD:EF:...
```

---

## Step 2: Add SHA-1 and SHA-256 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **drivemate-ac4ad**
3. Click **gear icon** → **Project settings**
4. Scroll to **Your apps** section
5. Click on your **Android app** (package: `app.techsol.drivemate`)
6. Click **Add fingerprint** button
7. Paste the **SHA-1** fingerprint from Step 1 (with colons, e.g., `A1:B2:C3:D4:...`)
8. Click **Add fingerprint** button again
9. Paste the **SHA-256** fingerprint from Step 1 (with colons)
10. Click **Save**
11. **Download the updated `google-services.json`** file
12. Replace `drivemate_app/android/app/google-services.json` with the downloaded file

---

## Step 3: Add SHA-1 to Google Cloud Console (OAuth)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **drivemate-ac4ad**
3. Navigate to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client ID** of type **Android** (package: `app.techsol.drivemate`)
5. Click to edit it
6. In the **SHA-1 certificate fingerprint** field, add the SHA-1 from Step 1:
   ```
   A1:B2:C3:D4:E5:F6:...
   ```
   (You can have multiple SHA-1 fingerprints - one per line)
7. Click **Save**

---

## Step 4: Wait for Propagation

After updating Firebase and Google Cloud Console:
- **Wait 5-10 minutes** for changes to propagate
- Changes may take up to 30 minutes in rare cases

---

## Step 5: Test Closed Testing

1. Make sure you've downloaded and replaced `google-services.json` (from Step 2)
2. Build a new AAB:
   ```powershell
   cd drivemate_app
   flutter clean
   flutter build appbundle
   ```
3. Upload to Play Console → **Closed testing** track
4. Install the app from the closed testing link
5. Test Google Sign-In - it should now work! ✅

---

## Verification Checklist

After completing all steps, verify:

- [ ] **SHA-1 added to Firebase** → Project settings → Android app → Fingerprints (should see both internal testing AND app signing key SHA-1)
- [ ] **SHA-256 added to Firebase** → Project settings → Android app → Fingerprints (should see both internal testing AND app signing key SHA-256)
- [ ] **SHA-1 added to Google Cloud** → Credentials → OAuth 2.0 Client ID (Android) - should have multiple SHA-1 fingerprints listed
- [ ] **`google-services.json` updated** → Downloaded from Firebase and replaced in `android/app/`
- [ ] **Waited 5-10 minutes** → For Firebase/Google Cloud changes to propagate
- [ ] **New build created** → After making all changes

---

## Summary: Certificate Requirements

| Testing Track | Certificate Type | Status |
|--------------|------------------|--------|
| **Internal Testing** | Internal testing certificate | ✅ Already added (works!) |
| **Closed Testing** | App signing key certificate | ⚠️ **Need to add this** |
| **Open Testing** | App signing key certificate | ✅ Same as closed testing |
| **Production** | App signing key certificate | ✅ Same as closed testing |

**You need BOTH certificates registered:**
1. ✅ Internal testing certificate (already done)
2. ⚠️ App signing key certificate (do this now!)

After adding the app signing key certificate, Google Sign-In will work in:
- ✅ Internal Testing (already works)
- ✅ Closed Testing (will work after adding certificate)
- ✅ Open Testing (will work)
- ✅ Production (will work)

---

## Troubleshooting

### Still not working after adding certificates?

1. **Double-check you got the right certificate:**
   - Make sure you copied from **"App signing key certificate"** section
   - NOT from "Internal testing certificate" section
   - NOT from "Upload key certificate" section

2. **Verify certificates are added:**
   - Firebase Console → Project settings → Android app → Should show multiple fingerprints
   - Google Cloud Console → Credentials → OAuth 2.0 Client ID → Should show multiple SHA-1 fingerprints

3. **Wait longer:**
   - Sometimes changes take 15-30 minutes to propagate
   - Try again after waiting

4. **Clear app data:**
   - Uninstall the closed testing app completely
   - Reinstall from Play Console
   - Test Google Sign-In again

5. **Check logcat for errors:**
   ```powershell
   adb logcat | findstr "GoogleSignIn\|DEVELOPER_ERROR\|FirebaseAuth"
   ```

---

## Quick Reference

**Internal Testing Certificate:**
- SHA-1: `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17` ✅ (already added)

**App Signing Key Certificate (for Closed/Open/Production):**
- SHA-1: `[Get from Play Console]` ⚠️ (need to add)
- SHA-256: `[Get from Play Console]` ⚠️ (need to add)
