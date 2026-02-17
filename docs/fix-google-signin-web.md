# Fixing Google Sign-In on Web

If Google Sign-In is not working on your deployed web app, follow these steps to fix it.

---

## Common Issues

1. **Authorized domains not configured** in Firebase Console
2. **OAuth consent screen not configured** in Google Cloud Console
3. **Redirect URIs missing** in OAuth 2.0 Client ID
4. **Web Client ID mismatch** or incorrect configuration

---

## Step 1: Add Authorized Domains in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **drivemate-ac4ad**
3. Navigate to **Authentication** → **Settings** → **Authorized domains**
4. Click **Add domain**
5. Add these domains:
   - `drivemate-ac4ad.web.app` ✅ (should already be there)
   - `drivemate-ac4ad.firebaseapp.com` ✅ (should already be there)
   - `localhost` (for local testing)
   - Your custom domain (if you have one)

**Note:** Firebase automatically adds `*.web.app` and `*.firebaseapp.com` domains, but verify they're listed.

---

## Step 2: Configure OAuth Consent Screen

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **drivemate-ac4ad**
3. Navigate to **APIs & Services** → **OAuth consent screen**
4. If not configured:
   - **User Type:** Select **External** (unless you have a Google Workspace)
   - **App name:** `DriveMate`
   - **User support email:** Your email
   - **Developer contact information:** Your email
   - Click **Save and Continue**
   - **Scopes:** Add `email`, `profile`, `openid` (if not already added)
   - **Test users:** Add test emails if app is in testing mode
   - Click **Save and Continue**
   - Review and **Back to Dashboard**

---

## Step 3: Configure OAuth 2.0 Client ID (Web) - CRITICAL STEP

1. In [Google Cloud Console](https://console.cloud.google.com/), navigate to **APIs & Services** → **Credentials**
2. Find your **OAuth 2.0 Client ID** of type **Web application** (not Android/iOS)
   - **If you don't see one**, create it:
     - Click **+ CREATE CREDENTIALS** → **OAuth client ID**
     - **Application type:** Web application
     - **Name:** `DriveMate Web`
     - **Authorized JavaScript origins:** Add these EXACT URLs:
       - `https://drivemate-ac4ad.web.app`
       - `https://drivemate-ac4ad.firebaseapp.com`
       - `http://localhost` (for local testing)
     - **Authorized redirect URIs:** Add these EXACT URLs (Firebase uses these):
       - `https://drivemate-ac4ad.firebaseapp.com/__/auth/handler`
       - `https://drivemate-ac4ad.web.app/__/auth/handler`
       - `http://localhost/__/auth/handler` (for local testing)
     - Click **Create**
   - **If you already have one**, click to edit it and ensure these redirect URIs are added:
     - `https://drivemate-ac4ad.firebaseapp.com/__/auth/handler`
     - `https://drivemate-ac4ad.web.app/__/auth/handler`
     - `http://localhost/__/auth/handler` (for local testing)
3. **Copy the Client ID** - it should match: `98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com`
4. **Save** the changes

**⚠️ IMPORTANT:** The redirect URIs must match EXACTLY (including trailing slashes and protocol). Firebase Hosting uses `/__/auth/handler` as the redirect endpoint.

---

## Step 4: Verify Firebase Authentication Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **drivemate-ac4ad**
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Google**
5. Ensure:
   - ✅ **Enable** toggle is ON
   - ✅ **Support email** is set
   - ✅ **Web SDK configuration** shows your Web Client ID: `98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com`

---

## Step 5: Verify Code Configuration

Your `firebase_options.dart` should have:

```dart
static const String? googleSignInWebClientId = '98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com';
```

✅ This is already configured correctly.

---

## Step 6: Check Browser Console for Errors

1. Open your web app: https://drivemate-ac4ad.web.app
2. Open browser DevTools (F12)
3. Go to **Console** tab
4. Try to sign in with Google
5. Look for errors like:
   - `redirect_uri_mismatch`
   - `access_denied`
   - `invalid_client`
   - `unauthorized_client`

Common error messages and fixes:

### Error: `redirect_uri_mismatch`
**Fix:** Add the redirect URI to OAuth 2.0 Client ID (Step 3)

### Error: `access_denied`
**Fix:** 
- Check OAuth consent screen is configured (Step 2)
- If app is in testing mode, add your email as a test user

### Error: `unauthorized_client`
**Fix:** 
- Verify authorized domains in Firebase Console (Step 1)
- Verify authorized JavaScript origins in Google Cloud Console (Step 3)

---

## Step 7: Rebuild and Redeploy

After making changes:

```powershell
cd D:\DriveMate\drivemate_app
flutter clean
flutter build web --release
cd ..
firebase deploy --only hosting
```

**Note:** Changes in Firebase/Google Cloud Console may take 5-10 minutes to propagate.

---

## Step 8: Test Locally First

Before deploying, test locally:

```powershell
cd D:\DriveMate\drivemate_app
flutter run -d chrome --web-renderer html
```

Then test Google Sign-In. If it works locally but not on deployed site, it's likely an authorized domains/redirect URI issue.

---

## Quick Checklist

- [ ] Authorized domains added in Firebase Console (Step 1)
- [ ] OAuth consent screen configured (Step 2)
- [ ] OAuth 2.0 Client ID (Web) has correct redirect URIs (Step 3)
- [ ] Google Sign-In enabled in Firebase Console (Step 4)
- [ ] Web Client ID matches in code (Step 5)
- [ ] No errors in browser console (Step 6)
- [ ] App rebuilt and redeployed (Step 7)

---

## Still Not Working?

### Check Browser Console
Open DevTools → Console and look for specific error messages.

### Verify OAuth Client ID
1. Go to Google Cloud Console → Credentials
2. Find your Web OAuth Client ID
3. Verify the Client ID matches: `98973897901-poqc7mksroa76n5e96ol4cvk9rljhdb.apps.googleusercontent.com`
4. If different, update `firebase_options.dart` and rebuild

### Test with Different Browser
Try incognito/private mode to rule out browser cache issues.

### Check Network Tab
In DevTools → Network, look for failed requests to `accounts.google.com` or `oauth2.googleapis.com`.

---

## Summary

The most common issue is **missing redirect URIs** in the OAuth 2.0 Client ID configuration. Make sure you add:
- `https://drivemate-ac4ad.firebaseapp.com/__/auth/handler`
- `https://drivemate-ac4ad.web.app/__/auth/handler`

After adding these, wait 5-10 minutes and try again.
