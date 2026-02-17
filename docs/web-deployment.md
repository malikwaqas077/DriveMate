# Deploying DriveMate to Web

This guide covers deploying your Flutter app to the web using Firebase Hosting (recommended) and alternative hosting options.

---

## Prerequisites

1. **Flutter SDK** installed and configured
2. **Firebase CLI** installed:
   ```powershell
   npm install -g firebase-tools
   ```
3. **Firebase project** already set up (`drivemate-ac4ad`)
4. **Firebase web app** already configured (already done ✅)

---

## Option 1: Firebase Hosting (Recommended)

Firebase Hosting is the recommended option since you're already using Firebase for authentication and Firestore.

### Step 1: Install Firebase CLI (if not already installed)

```powershell
npm install -g firebase-tools
```

### Step 2: Login to Firebase

```powershell
firebase login
```

This will open your browser to authenticate with your Google account.

### Step 3: Initialize Firebase Hosting

Navigate to your project root:

```powershell
cd d:\DriveMate
firebase init hosting
```

**Configuration options:**
- **What do you want to use as your public directory?** → `drivemate_app/build/web`
- **Configure as a single-page app (rewrite all urls to /index.html)?** → **Yes** (important for Flutter web)
- **Set up automatic builds and deploys with GitHub?** → **No** (or Yes if you want CI/CD)
- **File build/web/index.html already exists. Overwrite?** → **No**

This will create/update `firebase.json` with hosting configuration.

### Step 4: Update firebase.json

Your `firebase.json` should look like this:

```json
{
  "functions": {
    "source": "functions"
  },
  "hosting": {
    "public": "drivemate_app/build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|wasm|woff|woff2|ttf|otf)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000, immutable"
          }
        ]
      },
      {
        "source": "**",
        "headers": [
          {
            "key": "X-Content-Type-Options",
            "value": "nosniff"
          },
          {
            "key": "X-Frame-Options",
            "value": "DENY"
          },
          {
            "key": "X-XSS-Protection",
            "value": "1; mode=block"
          }
        ]
      }
    ]
  }
}
```

### Step 5: Build Flutter Web App

```powershell
cd drivemate_app
flutter clean
flutter pub get
flutter build web --release
```

**Note:** The `--release` flag creates an optimized production build.

### Step 6: Deploy to Firebase Hosting

```powershell
cd ..
firebase deploy --only hosting
```

Your app will be deployed to: `https://drivemate-ac4ad.web.app` and `https://drivemate-ac4ad.firebaseapp.com`

### Step 7: Set Custom Domain (Optional)

1. Go to [Firebase Console](https://console.firebase.google.com/) → **Hosting**
2. Click **Add custom domain**
3. Enter your domain name (e.g., `drivemate.com`)
4. Follow the DNS configuration instructions
5. Wait for SSL certificate provisioning (usually 5-10 minutes)

---

## Option 2: Vercel

Vercel provides excellent Flutter web hosting with automatic deployments.

### Step 1: Install Vercel CLI

```powershell
npm install -g vercel
```

### Step 2: Build Flutter Web App

```powershell
cd drivemate_app
flutter build web --release
```

### Step 3: Deploy to Vercel

```powershell
cd build/web
vercel
```

Follow the prompts:
- **Set up and deploy?** → **Yes**
- **Which scope?** → Select your account
- **Link to existing project?** → **No** (or Yes if redeploying)
- **Project name?** → `drivemate` (or your preferred name)
- **Directory?** → `.` (current directory)

### Step 4: Configure Vercel for Flutter (vercel.json)

Create `vercel.json` in your project root (`d:\DriveMate\vercel.json`):

```json
{
  "buildCommand": "cd drivemate_app && flutter build web --release",
  "outputDirectory": "drivemate_app/build/web",
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        }
      ]
    }
  ]
}
```

---

## Option 3: Netlify

Netlify is another popular option for Flutter web apps.

### Step 1: Install Netlify CLI

```powershell
npm install -g netlify-cli
```

### Step 2: Build Flutter Web App

```powershell
cd drivemate_app
flutter build web --release
```

### Step 3: Deploy to Netlify

```powershell
cd build/web
netlify deploy --prod
```

### Step 4: Configure Netlify (netlify.toml)

Create `netlify.toml` in your project root (`d:\DriveMate\netlify.toml`):

```toml
[build]
  command = "cd drivemate_app && flutter build web --release"
  publish = "drivemate_app/build/web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

---

## Web-Specific Considerations

### 1. Update Web App Metadata

Update `drivemate_app/web/index.html` with better metadata:

```html
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="DriveMate - Driving school management app for instructors, students, and owners.">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="DriveMate">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>DriveMate - Driving School Management</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
```

### 2. Update Web Manifest

Update `drivemate_app/web/manifest.json`:

```json
{
    "name": "DriveMate",
    "short_name": "DriveMate",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#0175C2",
    "theme_color": "#0175C2",
    "description": "Driving school management app for instructors, students, and owners.",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        },
        {
            "src": "icons/Icon-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable"
        }
    ]
}
```

### 3. Firebase Web Configuration

Your Firebase web configuration is already set up in `firebase_options.dart`:
- ✅ API Key: `AIzaSyAIvn_EVuZ6t8uyPwk9lBdfQCqZeMIseio`
- ✅ App ID: `1:98973897901:web:51fb5a776a457544c1a224`
- ✅ Auth Domain: `drivemate-ac4ad.firebaseapp.com`
- ✅ Web Client ID for Google Sign-In: `98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com`

### 4. Google Sign-In on Web

Google Sign-In should work automatically on web using the configured Web Client ID. Make sure:

1. **Firebase Console** → **Authentication** → **Sign-in method** → **Google** → **Web SDK configuration** is enabled
2. **Authorized domains** includes your hosting domain:
   - `drivemate-ac4ad.firebaseapp.com`
   - `drivemate-ac4ad.web.app`
   - Your custom domain (if configured)

### 5. Firestore Security Rules

Ensure your Firestore security rules allow web access. Check `firestore.rules` in Firebase Console.

### 6. CORS Configuration

If you're using Firebase Storage, ensure CORS is configured for your web domain.

---

## Continuous Deployment (CI/CD)

### GitHub Actions (Firebase Hosting)

Create `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy Web to Firebase Hosting

on:
  push:
    branches:
      - main
    paths:
      - 'drivemate_app/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.7'
          channel: 'stable'
      
      - name: Install dependencies
        run: |
          cd drivemate_app
          flutter pub get
      
      - name: Build web
        run: |
          cd drivemate_app
          flutter build web --release
      
      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: drivemate-ac4ad
```

**Setup:**
1. Go to Firebase Console → Project Settings → Service Accounts
2. Click **Generate new private key**
3. Add the JSON content as `FIREBASE_SERVICE_ACCOUNT` secret in GitHub repository settings

---

## Testing Web Build Locally

Before deploying, test your web build locally:

```powershell
cd drivemate_app
flutter build web --release
cd build/web
python -m http.server 8000
# Or use any local server
```

Then open `http://localhost:8000` in your browser.

---

## Troubleshooting

### Issue: Blank white screen after deployment

**Solution:**
1. Check browser console for errors
2. Verify Firebase configuration is correct
3. Ensure `index.html` has correct base href
4. Check that all assets are loading correctly

### Issue: Google Sign-In not working on web

**Solution:**
1. Verify Web Client ID is correct in `firebase_options.dart`
2. Check Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration
3. Ensure authorized domains include your hosting domain
4. Check browser console for OAuth errors

### Issue: Routing not working (404 errors)

**Solution:**
1. Ensure hosting configuration has rewrite rules (all routes → `/index.html`)
2. Verify `firebase.json` or hosting config has correct rewrites

### Issue: Assets not loading

**Solution:**
1. Check `pubspec.yaml` assets are correctly listed
2. Verify asset paths in code use relative paths
3. Ensure `flutter build web` completed without errors

---

## Performance Optimization

### 1. Enable CanvasKit Renderer (Optional)

For better performance, you can use CanvasKit renderer:

```powershell
flutter build web --release --web-renderer canvaskit
```

**Note:** This increases bundle size but provides better performance and compatibility.

### 2. Enable Tree Shaking

Already enabled by default in release builds. Ensure you're using `--release` flag.

### 3. Code Splitting

Flutter web automatically splits code. No additional configuration needed.

---

## Summary

**Quick Deploy to Firebase Hosting:**

```powershell
# 1. Build
cd drivemate_app
flutter build web --release

# 2. Deploy
cd ..
firebase deploy --only hosting
```

Your app will be live at:
- `https://drivemate-ac4ad.web.app`
- `https://drivemate-ac4ad.firebaseapp.com`

**Next Steps:**
1. Set up custom domain (optional)
2. Configure CI/CD for automatic deployments
3. Monitor performance and errors in Firebase Console
4. Set up analytics (Firebase Analytics is already configured)

---

## Pricing & Free Tiers

### Firebase Hosting (Free Tier)

**✅ FREE Forever:**
- **Storage:** 10 GB free (sufficient for most Flutter web apps)
- **Bandwidth:** 10 GB/month free outgoing bandwidth
- **SSL:** Free SSL certificates included
- **Custom domains:** Free (unlimited)
- **CDN:** Global CDN included

**Paid (if you exceed free tier):**
- Storage: $0.10/GB/month (after 10 GB)
- Bandwidth: $0.15/GB (cached) or $0.20/GB (uncached) after 10 GB/month

**For DriveMate:** The free tier should be more than enough unless you have very high traffic. A typical Flutter web app is 5-20 MB, so you can store hundreds of versions and serve thousands of users per month for free.

---

### Vercel (Free Tier - Hobby Plan)

**✅ FREE Forever:**
- **Projects:** Up to 200 projects
- **Bandwidth:** 100 GB/month included
- **Builds:** 100 builds/day, 2,000 CLI deployments/week
- **Build time:** 45 minutes per build
- **SSL:** Free SSL certificates
- **Custom domains:** Free (unlimited)

**Limitations:**
- 1 concurrent build (fine for most projects)
- 100 MB max file size per deployment

**For DriveMate:** Perfect for free hosting. The 100 GB bandwidth/month is generous for most apps.

---

### Netlify (Free Tier)

**✅ FREE Forever:**
- **Credits:** 300 credits/month (free tier)
- **Bandwidth:** Included in credits (~30 GB/month equivalent)
- **Builds:** Included in credits
- **SSL:** Free SSL certificates
- **Custom domains:** Free (unlimited)

**Credit costs:**
- Production deploy: 15 credits
- Bandwidth: 10 credits/GB
- Web requests: 3 credits per 10k requests

**For DriveMate:** The free tier should work well for moderate traffic. You get approximately 20 deployments and ~30 GB bandwidth per month.

---

## Cost Comparison Summary

| Feature | Firebase Hosting | Vercel | Netlify |
|---------|-----------------|--------|---------|
| **Free Forever** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Free Storage** | 10 GB | Unlimited* | Included |
| **Free Bandwidth** | 10 GB/month | 100 GB/month | ~30 GB/month |
| **Free SSL** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Custom Domains** | ✅ Free | ✅ Free | ✅ Free |
| **Best For** | Firebase projects | General use | General use |

**Recommendation:** Since you're already using Firebase (Auth, Firestore), **Firebase Hosting is the best choice** - it's free, integrates seamlessly, and 10 GB bandwidth/month is sufficient for most apps unless you have very high traffic.

---

## Additional Resources

- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
- [Firebase Hosting Pricing](https://firebase.google.com/docs/hosting/usage-quotas-pricing)
- [Flutter Web Performance](https://docs.flutter.dev/platform-integration/web/initialization)
