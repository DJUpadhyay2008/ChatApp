# Deployment Guide: ₹0/Month Production Stack

This guide details deploying the private chat application across **Render** (FastAPI backend), **Vercel** (Flutter Web frontend), and **GitHub Actions** (Android release APK builds).

---

## 1. Render Deployment (FastAPI Backend)

### Render Free Tier Characteristics:
- **Cost**: ₹0/month.
- **Sleep Behavior**: Free instances spin down after 15 minutes of inactivity. First request after spin-down incurs a cold start of ~45–50 seconds.
- **WebSocket Behavior**: WebSockets are terminated on spin-down. The Flutter client includes automated exponential backoff reconnection.

### Deployment Steps:
1. Push this repository to your GitHub account (`main` branch).
2. Go to [dashboard.render.com](https://dashboard.render.com) and click **New + -> Blueprint** (or **Web Service**).
3. Connect your GitHub repository. Render will automatically detect [`backend/render.yaml`](./backend/render.yaml).
4. Configure the required environment variables in Render:
   - `SUPABASE_URL`: `https://<your-project>.supabase.co`
   - `SUPABASE_ANON_KEY`: Your Supabase anon public key
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (kept securely on the server)
   - `SUPABASE_JWT_AUDIENCE`: `authenticated`
   - `ALLOWED_ORIGINS`: Comma-separated allowed frontend origins (e.g., `https://your-app.vercel.app,http://localhost:3000`)
   - `ADMIN_EMAIL`: Designated administrator email
5. Click **Create Web Service**.
6. Once deployed, note your service URL: `https://private-chat-backend.onrender.com`.
7. Verify by opening `https://private-chat-backend.onrender.com/health` in your browser.

---

## 2. Vercel Deployment (Flutter Web)

### Vercel Free Tier Characteristics:
- **Cost**: ₹0/month.
- Unlimited static deployments with high-speed global CDN edge caching.

### Deployment Steps:
1. Go to [vercel.com](https://vercel.com) and click **Add New -> Project**.
2. Import your GitHub repository.
3. Configure the project settings:
   - **Root Directory**: `apps/chat_app`
   - **Framework Preset**: Other
   - **Build Command**: `flutter/bin/flutter build web --release`
   - **Output Directory**: `build/web`
   - **Install Command**: `if [ ! -d "flutter" ]; then git clone https://github.com/flutter/flutter.git -b stable --depth 1; fi && flutter/bin/flutter precache --web`
4. Add Environment Variables in Vercel:
   - `API_BASE_URL`: `https://private-chat-backend.onrender.com`
   - `WS_BASE_URL`: `wss://private-chat-backend.onrender.com/ws`
   - `SUPABASE_URL`: `https://<your-project>.supabase.co`
   - `SUPABASE_ANON_KEY`: `<your-supabase-anon-key>`
5. Click **Deploy**. Vercel will build the Flutter web bundle and deploy it to a global HTTPS URL.
6. Remember to add your Vercel URL to the `ALLOWED_ORIGINS` setting on Render.

---

## 3. GitHub Actions (Cloud Android APK Builds)

> **Important**: You do **not** need Android Studio or Android SDK installed on your local machine. All APK builds run automatically in GitHub's cloud CI runners.

### Automatic Builds on Push:
- Every push to `main` touching `apps/chat_app/` triggers the workflow `.github/workflows/android-apk.yml`.

### Manual On-Demand Builds:
1. On GitHub, navigate to the **Actions** tab.
2. Select **Android APK Cloud Build** from the left sidebar.
3. Click **Run workflow**.
4. (Optional) Provide custom `api_base_url` or `ws_base_url` if pointing to a staging or production backend.
5. Wait for the build to finish (~4–5 minutes).
6. Under the completed workflow run, scroll down to the **Artifacts** section.
7. Click **`private-chat-android-apk`** to download the zip file containing `app-release.apk`.

### Installing the APK on Android:
1. Transfer `app-release.apk` to your Android device (via WhatsApp, Google Drive, or USB).
2. Open the file on your device.
3. If prompted, allow "Install unknown apps" from your browser or file manager.
4. Tap **Install**.
