# Google OAuth Setup Guide

This guide walks through configuring Google OAuth for DejaPoo's Google Drive sync
and export features. All steps are performed in the
[Google Cloud Console](https://console.cloud.google.com/).

## 1. Create a Google Cloud Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com/)
2. Click the project selector (top bar) > **New Project**
3. Name: `DejaPoo` (or any name you prefer)
4. Click **Create**, then select the new project

## 2. Enable the Google Drive API

1. Navigate to **APIs & Services > Library**
2. Search for **Google Drive API**
3. Click it, then click **Enable**

## 3. Configure the OAuth Consent Screen

1. Navigate to **APIs & Services > OAuth consent screen**
2. Select **External** user type > **Create**
3. Fill in the required fields:
   - **App name:** DejaPoo
   - **User support email:** your email
   - **Developer contact email:** your email
4. Click **Save and Continue**
5. On the **Scopes** page, click **Add or Remove Scopes** and add:
   - `https://www.googleapis.com/auth/drive.appdata` (app-specific data folder)
   - `https://www.googleapis.com/auth/drive.file` (files created by the app)
6. Click **Update**, then **Save and Continue**
7. On the **Test users** page, click **Add Users** and add your Gmail address
8. Click **Save and Continue**, then **Back to Dashboard**

**Important:** Leave the app in **Testing** mode. This is a personal-use app, so
there is no need to submit for Google verification. In Testing mode, only the test
users you added can sign in. The `drive.appdata` scope would trigger a verification
review if the app were published, but Testing mode avoids this entirely.

## 4. Create an Android OAuth Client ID

1. Navigate to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. **Application type:** Android
4. **Name:** DejaPoo Android
5. **Package name:** `com.example.dejapoo`
   (check `android/app/build.gradle.kts` for the actual `applicationId`)
6. **SHA-1 certificate fingerprint:** obtain from the debug keystore:

   ```bash
   # Windows (Git Bash or CMD)
   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

   # macOS / Linux
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

   Copy the `SHA1:` line (e.g., `AB:CD:EF:...`).

7. Click **Create**

**Release builds:** Before distributing a signed APK/AAB, create a second Android
OAuth client ID with the **release keystore** SHA-1. The debug and release keystores
have different fingerprints, so both client IDs are needed.

**Note:** No code changes are needed for Android. The `google_sign_in` plugin
matches the app's package name and signing certificate against the registered
OAuth client IDs automatically.

## 5. Create a Web OAuth Client ID

1. Navigate to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. **Application type:** Web application
4. **Name:** DejaPoo Web
5. **Authorized JavaScript origins:**
   - `http://localhost:5000` (for local development; pin the port with
     `flutter run -d chrome --web-port 5000`)
   - `https://ryan-shah.github.io` (for the GitHub Pages deployment; origins
     are host-only, so this covers the `/DejaPoo/` path automatically)
6. Click **Create**
7. Copy the **Client ID** (looks like `123456789-abc.apps.googleusercontent.com`)

### Configure the Web Client ID in the App

Edit `web/index.html` and replace the placeholder in the meta tag:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

Replace `YOUR_WEB_CLIENT_ID.apps.googleusercontent.com` with the actual client ID
you copied above.

## 6. iOS OAuth Client ID (Document Only)

**Note:** iOS setup cannot be verified on a Windows development machine. A follow-up
issue has been filed for iOS verification.

### Steps (to be verified on a macOS machine)

1. Navigate to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. **Application type:** iOS
4. **Name:** DejaPoo iOS
5. **Bundle ID:** `com.example.dejapoo`
   (check `ios/Runner.xcodeproj/project.pbxproj` for the actual bundle identifier)
6. Click **Create**
7. Download the generated `GoogleService-Info.plist`

### Configure iOS in the App

1. Copy the **reversed client ID** from the plist (e.g.,
   `com.googleusercontent.apps.123456789-abc`)
2. Add it as a URL scheme in `ios/Runner/Info.plist`:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

3. Add the `GoogleService-Info.plist` to the Xcode project's Runner target

## Troubleshooting

### "Access blocked: This app's request is invalid" (Error 400)
- Verify the **Authorized JavaScript origins** include your exact origin
  (protocol + host + port, no trailing slash)
- For local dev, ensure you are using `--web-port 5000` and the origin is
  `http://localhost:5000`

### "This app isn't verified" warning
- This is expected in Testing mode. Click **Continue** (only test users can proceed)
- Do NOT submit for verification unless you plan to distribute publicly

### Android sign-in silently fails
- Verify the SHA-1 fingerprint matches your signing keystore
- Run `./gradlew signingReport` in the `android/` directory to check
- Ensure the package name in the OAuth client matches `applicationId` in
  `build.gradle.kts`

### Token expiration on web
- Web access tokens expire after approximately 1 hour
- The app re-checks authorization before each sync; if expired, it will prompt
  the user to re-authorize rather than failing silently
