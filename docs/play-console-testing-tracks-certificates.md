# Google Play Console Testing Tracks & Certificates

## Important: Different Tracks Use Different Certificates

Google Play Console has multiple testing tracks, and **each track may use a different signing certificate**. You need to add the SHA-1/SHA-256 fingerprints for **each track** to Firebase and Google Cloud Console.

---

## Testing Tracks Overview

### 1. **Internal Testing** ✅ (You've already added this)
- **Certificate:** Internal testing certificate (unique to internal testing)
- **SHA-1:** `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17`
- **Status:** ✅ Fingerprints provided - needs to be added to Firebase

### 2. **Closed Testing** ⚠️ (Different certificate!)
- **Certificate:** **App signing key certificate** (same as production if Play App Signing is enabled)
- **Location:** Play Console → Release → Setup → **App signing** → **App signing key certificate**
- **Status:** ⚠️ Need to get these fingerprints

### 3. **Open Testing** ⚠️ (Same as closed testing)
- **Certificate:** **App signing key certificate** (same as closed testing/production)
- **Location:** Play Console → Release → Setup → **App signing** → **App signing key certificate**
- **Status:** ⚠️ Same as closed testing

### 4. **Production** ⚠️ (Same as closed/open testing)
- **Certificate:** **App signing key certificate**
- **Location:** Play Console → Release → Setup → **App signing** → **App signing key certificate**
- **Status:** ⚠️ Same as closed/open testing

---

## How to Get Certificates for Each Track

### Internal Testing Certificate ✅ (Already have this)
- **Location:** Play Console → Release → Setup → **App signing** → **Internal testing certificate**
- **SHA-1:** `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17`
- **SHA-256:** `BF:F8:68:97:9C:D1:A8:0E:9D:C1:8B:EC:3D:54:70:39:43:D9:1F:E9:94:5A:2C:94:13:BD:79:AC:9F:9E:4E:5E`

### App Signing Key Certificate (For Closed/Open/Production) ⚠️
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: **DriveMate**
3. In the left sidebar, navigate to: **Test and release** → **App integrity**
   - (Alternatively: **Test and release** → **Setup** → **App signing**)
4. On the App integrity page, scroll to find **App signing key certificate** section
   - ⚠️ **Important:** This is DIFFERENT from "Internal testing certificate" section
   - You'll see TWO certificate sections - use the "App signing key certificate" one
5. Copy the **SHA-1 certificate fingerprint** and **SHA-256 certificate fingerprint**

**This is different from the internal testing certificate!**

---

## What You Need to Do

### Step 1: Add Internal Testing Certificate ✅ (Do this first)
Follow the guide in `docs/add-internal-test-certificates.md` to add:
- SHA-1: `BE:81:37:E7:20:0E:6F:89:70:E6:AF:55:F2:6F:DF:56:D4:52:B7:17`
- SHA-256: `BF:F8:68:97:9C:D1:A8:0E:9D:C1:8B:EC:3D:54:70:39:43:D9:1F:E9:94:5A:2C:94:13:BD:79:AC:9F:9E:4E:5E`

### Step 2: Get App Signing Key Certificate (For Closed/Open/Production) ⚠️
1. Go to Play Console → Release → Setup → **App signing**
2. Find **App signing key certificate** section
3. Copy the SHA-1 and SHA-256 fingerprints
4. Add them to Firebase and Google Cloud Console (same process as Step 1)

---

## Summary: Which Certificates Do You Need?

| Testing Track | Certificate Type | Status |
|--------------|------------------|--------|
| **Internal Testing** | Internal testing certificate | ✅ Have fingerprints - need to add |
| **Closed Testing** | App signing key certificate | ⚠️ Need to get from Play Console |
| **Open Testing** | App signing key certificate | ⚠️ Same as closed testing |
| **Production** | App signing key certificate | ⚠️ Same as closed/open testing |

**Important:** 
- Internal testing uses a **different certificate** than closed/open/production
- Closed, Open, and Production all use the **same certificate** (App signing key certificate)
- You need to add **both certificates** to Firebase and Google Cloud Console

---

## Quick Action Plan

1. ✅ **Add internal testing certificate** (SHA-1: `BE:81:37:E7:...`) to Firebase and Google Cloud
2. ⚠️ **Get app signing key certificate** from Play Console → Release → Setup → App signing
3. ⚠️ **Add app signing key certificate** SHA-1/SHA-256 to Firebase and Google Cloud
4. ✅ **Download updated `google-services.json`** after adding both certificates
5. ✅ **Rebuild and test** in both internal testing and closed testing tracks

---

## Why This Matters

- **Internal Testing:** Uses internal testing certificate → Google Sign-In will work ✅
- **Closed Testing:** Uses app signing key certificate → Google Sign-In will **fail** unless you add this certificate too ❌
- **Production:** Uses app signing key certificate → Google Sign-In will **fail** unless you add this certificate too ❌

**Solution:** Add **both certificates** to Firebase and Google Cloud Console to support all testing tracks and production! 🎯
