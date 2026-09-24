# GOOP for personal use

GOOP is a native SwiftUI iPhone app that reads Google Health data synced from Fitbit devices. The app talks to a small Node.js server deployed on Railway. Google OAuth secrets stay on that server; your Google refresh token is encrypted before it is stored on a Railway Volume.

This setup is for one person. The backend rejects sign-ins from any Google account other than `GOOP_ALLOWED_EMAIL`.

## What GOOP calculates

- Activity load is `active-zone-minutes / 90 * 21`, capped at 21.
- Readiness is a GOOP estimate using sleep duration and current HRV/resting heart rate compared with your 28-day medians. It is not shown until at least seven previous days of both HRV and resting-heart-rate history exist.
- These are GOOP wellness estimates, not medical measures or WHOOP's proprietary scores.
- Missing Google Health data stays missing. GOOP does not generate sample readings.

## Part 1: Create a Google Cloud project

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create a project for GOOP.
2. Enable **Google Health API** for that project.
3. Configure the OAuth consent screen. Choose **External** unless your Google account belongs to a managed Google Workspace organization that can use Internal.
4. Add the email you will use on your iPhone under **Audience → Test users**. Use the same address later for `GOOP_ALLOWED_EMAIL`.
5. Under **Data Access**, add only the scopes GOOP requests:
   - `openid`, `email`, `profile`
   - `googlehealth.activity_and_fitness.readonly`
   - `googlehealth.sleep.readonly`
   - `googlehealth.health_metrics_and_measurements.readonly`
6. Create an OAuth client with application type **Web application**. You will add its callback URL after you create the Railway service and generate its domain.

Google's [setup guide](https://developers.google.com/health/setup) explains project enablement, test users, and scope configuration. The first OAuth grant may show Google's unverified-app warning; proceed only with the Google account you added as a test user.

## Part 2: Deploy the GOOP server to Railway

The Git repository root is the `GOOP` folder containing `GOOP.xcodeproj`, `server/`, and this README.

1. Create a **private** GitHub repository, then from this local repository (`/Users/remus/Documents/GOOP/GOOP`) commit and push the project. The local repository currently has no Git remote configured:

   ```sh
   git add -A
   git commit -m "Prepare GOOP for personal Railway deployment"
   git remote add origin https://github.com/YOUR_GITHUB_NAME/YOUR_PRIVATE_REPO.git
   git push -u origin main
   ```

   Replace the remote URL with your private repository URL. Do not commit `server/.env` or any secrets; the repository ignore rules exclude them.
2. In [Railway](https://railway.com/), create a project and choose **Deploy from GitHub repo**. Select the repository.
3. Open the new service's **Settings → Build → Root Directory** and set it to `/server`. Railway will then detect `server/package.json` and run `npm start`.
4. In the service's **Settings → Networking**, choose **Generate Domain**. Copy the HTTPS domain, for example `https://goop-production-xxxx.up.railway.app`.
5. Return to Google Cloud and add this exact **Authorized redirect URI** to the Web application OAuth client:
   `https://YOUR-RAILWAY-DOMAIN/auth/google/callback`
   Replace `YOUR-RAILWAY-DOMAIN` with the hostname Railway generated. Do not add a trailing slash.
6. In Railway, open the service's **Variables** and add the following variables. For the two random secrets, generate values in Terminal with the commands below and paste each result into Railway. Keep both values private and unchanged across deploys.

   ```sh
   openssl rand -base64 32
   openssl rand -hex 32
   ```

   Set these Railway Variables:

   | Variable | Value |
   |---|---|
   | `GOOGLE_CLIENT_ID` | Client ID from the Google Web application OAuth client |
   | `GOOGLE_CLIENT_SECRET` | Client secret from that same OAuth client |
   | `GOOGLE_REDIRECT_URI` | `https://YOUR-RAILWAY-DOMAIN/auth/google/callback` |
   | `GOOP_ALLOWED_EMAIL` | The exact Google email you added as a test user |
   | `GOOP_TOKEN_ENCRYPTION_KEY` | Output of `openssl rand -base64 32` |
   | `GOOP_SESSION_PEPPER` | Output of `openssl rand -hex 32` |
   | `GOOP_DATA_FILE` | `/data/store.json` |
   | `IOS_CALLBACK_URI` | `goop://auth/callback` |

   Railway sets `PORT` automatically; do not set it manually.

7. In Railway, open the service's **Volumes** settings, add a Volume, and set its mount path to `/data`. The GOOP server writes the encrypted token store to `/data/store.json`. Railway's container filesystem is otherwise ephemeral, so the volume is necessary to keep your connection across deploys/restarts. See [Railway Volumes](https://docs.railway.com/volumes).
8. In Railway **Settings → Deploy**, set the health-check path to `/healthz`. Keep the service at one replica because the brief OAuth state and one-time code are held in memory. Deploy/redeploy the service. Open `https://YOUR-RAILWAY-DOMAIN/healthz`; it should respond with `{"ok":true}`.

Railway provides HTTPS for its generated domain. Use that same base URL in Google Cloud's callback and in the iOS app. Railway's [domain guide](https://docs.railway.com/networking/domains/working-with-domains) covers generated domains and SSL.

### Google test-mode expiry

Google OAuth projects left in **Testing** expire authorizations and refresh tokens after seven days when they request health-data scopes. That means you may need to sign in again about once a week. For personal use, Google documents a personal-use exception to verification, but publishing status, warning screens, and scope rules still apply. See Google's [Testing-mode behavior](https://support.google.com/cloud/answer/15549945) and [verification exceptions](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification). Do not assume that changing the app to In production will bypass every Google Health requirement; follow what the Google Cloud console allows for your project.

## Part 3: Point the iOS app to Railway

1. Open `GOOP.xcodeproj` in Xcode.
2. Select the GOOP app target, then **Build Settings**. Search for `GOOP_API_BASE_URL`.
3. Set both **Debug** and **Release** to the Railway base URL, such as `https://goop-production-xxxx.up.railway.app` (no trailing slash). Debug's default is localhost for local development; it will not reach Railway until you change it.
4. Choose your iPhone simulator or a connected iPhone and run GOOP.
5. Tap **Continue with Google**, sign in with the allowed/test-user Google account, and approve the requested scopes. After Google returns to GOOP, the app fetches the available data.

The app registers the `goop://auth/callback` URL scheme in `GOOP/GOOP-Info.plist`. Do not add the Google client secret to Xcode build settings or the iOS target.

## Personal-use security and limits

- Keep the Railway service to one replica: OAuth state and one-time exchange codes are held in server memory during the short sign-in round trip.
- Keep the Railway Volume attached, and do not change or lose `GOOP_TOKEN_ENCRYPTION_KEY`; without it, the stored Google refresh token cannot be decrypted.
- The Railway `/healthz` endpoint is public and reveals no account data. All health-data endpoints require the app's bearer session token.
- `GOOP_ALLOWED_EMAIL` restricts Google OAuth to one verified email address. This is a safeguard for personal deployment, not a substitute for keeping the domain and secrets private.
- This prototype has no automated database backups. Review Railway's volume backup options and keep a secure backup before relying on the data store.
- Google Health data types depend on the source device and what has synced to Google Health. GOOP only displays returned data.

## Local server development

From `server/`, copy `.env.example` to `.env` and export its variables into your shell (Node does not automatically load `.env`). Use `GOOP_DATA_FILE=./data/store.json` locally. Run `npm start`. For local simulator use, set the app's Debug `GOOP_API_BASE_URL` to `http://127.0.0.1:8787`; for an iPhone, use a publicly reachable HTTPS server such as Railway.
