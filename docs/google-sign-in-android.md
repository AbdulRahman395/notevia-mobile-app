# Continue with Google on Android

The app already has the code. Android only needs one more OAuth client in the
Google Cloud project you set up for the website.

## How it works

1. The phone's Google account sheet signs the person in.
2. Google returns an **ID token made for your Web client ID**. The app asks for
   this via `serverClientId` in `lib/config.dart`.
3. The app sends it to `POST /auth/google`, the same endpoint the website uses.
   The backend checks it against `GOOGLE_CLIENT_ID` (the Web client ID) and
   returns the usual login token.
4. The PIN screen comes next, as with email sign-in. New Google accounts are
   sent on to create a PIN.

The backend and the website need no changes.

## Setup (about 5 minutes)

### 1. Create the Android OAuth client

Google Cloud Console → **the same project as the website** → APIs & Services →
Credentials → **Create credentials → OAuth client ID**.

| Field | Value |
| --- | --- |
| Application type | Android |
| Name | Notevia Android |
| Package name | `com.example.notevia_mobile_app` |
| SHA-1 certificate fingerprint | `5D:D9:A6:D9:F3:F7:57:7B:D2:24:A9:9C:26:E1:D8:AD:51:9E:30:25` |

That SHA-1 belongs to the debug key on this PC. Release builds use the same key
for now (see `android/app/build.gradle.kts`), so it covers both the debug and
release APKs you install yourself.

Click Create. Don't copy its client ID anywhere: Android finds this client
using the package name and SHA-1. It just has to exist.

### 2. Check the consent screen

Go to APIs & Services → **OAuth consent screen** (Google Auth Platform →
Audience). If the app is in **Testing**, only the listed test users can sign in.
Add your Google account there, or publish the app.

### 3. Try it

Changes in Google Cloud can take 5 minutes, sometimes longer, to apply. Then
open the app and tap **Continue with Google**.

## Before the Play Store

- **Change the package name.** `com.example.…` is a placeholder. Set
  `applicationId` in `android/app/build.gradle.kts` (for example
  `com.notevia.app`), then create a new Android OAuth client with that name.
- **Add your Play fingerprints.** With Play App Signing, Google re-signs the
  app. Play Console → your app → Test and release → App integrity → App signing
  shows two SHA-1s: the **app signing key** and the **upload key**. Create an
  Android OAuth client for each one, with the same package name.
- If you sign with your own release keystore, get its SHA-1 with:

  ```bash
  keytool -list -v -keystore path/to/release.jks -alias your-alias
  ```

## Another Web client ID

`lib/config.dart` holds the Web client ID, copied from the website's
`VITE_GOOGLE_CLIENT_ID`. To build with a different one:

```bash
flutter build apk --release --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
```

It must match `GOOGLE_CLIENT_ID` in the backend, which can hold several IDs
separated by commas.

## Troubleshooting

| What you see | Cause |
| --- | --- |
| "Google sign-in isn't set up for this app yet", "Google sign-in didn't work", or the sheet closes straight away | Usually no Android OAuth client matches this package name and SHA-1, or it was created only minutes ago. Also check the account is a test user while the consent screen is in Testing. |
| "Invalid or expired Google sign-in" from the server | The backend's `GOOGLE_CLIENT_ID` doesn't include the Web client ID in `lib/config.dart`. |
| "This email is already linked to a different Google account" | That Notevia account is linked to another Google account. |
