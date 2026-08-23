# Installing DejaPoo on Android

DejaPoo isn't on the Play Store yet, so the Android app is installed by *sideloading*:
downloading the APK straight from GitHub and telling Android it's OK to install it.

It takes about a minute. You only have to do the "allow from this source" part once.

## 1. Download the APK

Open this page **on your Android phone**:

**https://github.com/ryan-shah/DejaPoo/releases/latest**

Under **Assets**, tap the file ending in **`.apk`**. (Every push to `main` publishes a fresh release
with the APK attached, so "latest" is always the current build.)

Chrome may warn that "this type of file can harm your device" — that's the standard warning
for any APK. Tap **Download anyway**.

## 2. Install it

1. When the download finishes, tap the **download notification** (or open Chrome's
   **Downloads**, or the **Files** app → **Downloads**, and tap the `.apk` file).
2. On Android 8 and newer, Android will block the install with a message like
   **"For your security, your phone is not allowed to install unknown apps from this source."**
   Tap **Settings** in that dialog.
3. Turn on **Allow from this source** (also labelled **Install unknown apps**) for the app
   that's doing the installing — usually **Chrome**, or **Files**/**My Files** if you're
   opening the APK from your downloads folder.
4. Tap **Back**. The install screen returns — tap **Install**, then **Open**.

### If you dismissed the prompt

Nothing is lost; the APK is still on your phone.

- **Get back to the file:** open Chrome → ⋮ menu → **Downloads**, or open the **Files** app →
  **Downloads**, and tap the `.apk` file again.
- **Grant the permission ahead of time:** **Settings** → **Apps** → **Special app access**
  (on some phones: **Advanced** → **Special access**) → **Install unknown apps** → pick
  **Chrome** → turn on **Allow from this source**. Then tap the APK again.

Menu names vary a little by manufacturer (Samsung, Pixel, OnePlus…), but the setting is always
under Apps → special access.

## 3. Sign in (optional)

DejaPoo works fully offline; Google Sign-In is only needed for Google Drive sync and export.

## Things to know before you install

**Google Sign-In may not work on every build.** CI builds are signed with a fixed *test*
keystore, and Google only accepts a sign-in request from an app whose signing certificate
SHA-1 fingerprint is registered on the Android OAuth client. If that fingerprint hasn't been
registered, sign-in fails on the installed APK even though the rest of the app works — see
[`designs/GOOGLE_OAUTH_SETUP.md`](../designs/GOOGLE_OAUTH_SETUP.md) for how fingerprints are
registered. PR test builds carry the same caveat. Local logging, reports, and file export are
unaffected.

**A future signing-key change means uninstalling first.** Android refuses to update an
installed app with a build signed by a different key. If DejaPoo later moves from the CI test
keystore to a real release key (or to a Play Store install), the new APK will fail to install
with a message like *"App not installed"* until you uninstall the current copy. Uninstalling
deletes the app's local database, so **export your data first** (Settings → Export) or turn on
Google Drive sync before you uninstall.

**Updates are manual.** Sideloaded builds don't auto-update. Revisit the
[releases page](https://github.com/ryan-shah/DejaPoo/releases/latest) and install the newer
APK over the top — as long as the signing key is unchanged, your data is kept.

## Prefer the web app?

You don't have to install anything. DejaPoo runs in the browser at
**https://ryan-shah.github.io/DejaPoo/**, with the same logging, reports, and Drive sync. You
can also add it to your home screen from Chrome's ⋮ menu → **Add to Home screen**. The native
Android app is worth it mainly for reliable offline use and daily reminder notifications.
