# Adding Internal Testing Certificate Fingerprints

## Certificate Fingerprints from Play Console

**SHA-1:** `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17`  
**SHA-256:** `BF:F8:68:97:9C:D1:A8:0E:9D:C1:8B:EC:3D:54:70:39:43:D9:1F:E9:94:5A:2C:94:13:BD:79:AC:9F:9E:4E:5E`

**Formatted for Firebase (lowercase, no colons):**
- SHA-1: `be8137e7200e6f8970e6af55f26fdf56d452b717`
- SHA-256: `bff868979cd1a80e9dc18bec3d54703943d91fe9945a2c9413bd79ac9f9e4e5e`

---

## Step-by-Step Instructions

### Step 1: Add to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **drivemate-ac4ad**
3. Click **gear icon** → **Project settings**
4. Scroll to **Your apps** section
5. Click on your **Android app** (package: `app.techsol.drivemate`)
6. Click **Add fingerprint** button
7. Paste: `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17` (SHA-1 with colons)
8. Click **Add fingerprint** again
9. Paste: `BF:F8:68:97:9C:D1:A8:0E:9D:C1:8B:EC:3D:54:70:39:43:D9:1F:E9:94:5A:2C:94:13:BD:79:AC:9F:9E:4E:5E` (SHA-256 with colons)
10. Click **Save**
11. **Download the updated `google-services.json`** file
12. Replace `drivemate_app/android/app/google-services.json` with the downloaded file

---

### Step 2: Add SHA-1 to Google Cloud Console (OAuth)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **drivemate-ac4ad**
3. Navigate to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client ID** of type **Android** (package: `app.techsol.drivemate`)
5. Click to edit it
6. In the **SHA-1 certificate fingerprint** field, add:
   ```
   BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17
   ```
   (You can have multiple SHA-1 fingerprints - one per line)
7. Click **Save**

---

### Step 3: Update google-services.json

After downloading from Firebase, the `google-services.json` should include a new OAuth client entry with:
```json
{
  "client_id": "...",
  "client_type": 1,
  "android_info": {
    "package_name": "app.techsol.drivemate",
    "certificate_hash": "be8137e7200e6f8970e6af55f26fdf56d452b717"
  }
}
```

---

### Step 4: Wait and Test

1. **Wait 5-10 minutes** for Firebase/Google Cloud changes to propagate
2. Build a new AAB:
   ```powershell
   cd d:\DriveMate\drivemate_app
   flutter clean
   flutter build appbundle
   ```
3. Upload to Play Console → **Internal testing** track
4. Install and test Google Sign-In

---

## Verification

After adding the fingerprints, verify:

- [ ] SHA-1 `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17` appears in Firebase Console → Project settings → Android app → Fingerprints
- [ ] SHA-256 `BF:F8:68:97:9C:D1:A8:0E:9D:C1:8B:EC:3D:54:70:39:43:D9:1F:E9:94:5A:2C:94:13:BD:79:AC:9F:9E:4E:5E` appears in Firebase Console
- [ ] SHA-1 `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17` appears in Google Cloud Console → Credentials → OAuth 2.0 Client ID (Android)
- [ ] Updated `google-services.json` downloaded and replaced in `android/app/`
- [ ] New build created after updating `google-services.json`

---

## Current Fingerprints Status

**Debug SHA-1:** `c1fa02a901890d9596849f4f05d2fac57d95927b` ✅ (already registered)  
**Release SHA-1:** `e5ccbf3c41485da9b513b7692a8beb2b9d33d116` ✅ (already registered)  
**Internal Testing SHA-1:** `be8137e7200e6f8970e6af55f26fdf56d452b717` ⚠️ (needs to be added)

After adding the internal testing certificate fingerprints, Google Sign-In should work in internal testing builds! 🎉
