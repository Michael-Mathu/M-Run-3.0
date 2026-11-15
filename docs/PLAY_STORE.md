# Publishing Mwendo on Google Play

What is already done in the code, and the steps only the account owner can
do. Written 15 November 2026 against Play Console as it was then; Google
moves menus around, so follow the labels rather than exact positions.

## Already done in the project

| Item | State |
| :--- | :--- |
| Target API level | 36 (Play requires a recent level; this passes) |
| App name on the phone | "Mwendo" (was `mwendo_app`) |
| Release signing | Reads `app/android/key.properties`; see step 2 |
| App bundle (`.aab`) | `flutter build appbundle --release` builds |
| Background location | **Removed.** Recording uses a foreground service, so "Allow all the time" is not needed, and Play's background-location review is avoided |
| Account / leaderboard | Hidden in store builds (there is no production server yet), so there is no sign-in that cannot work and no account-deletion requirement |
| Delete your data | Each activity can be deleted in the app |
| Privacy policy | [`PRIVACY.md`](../PRIVACY.md), public at `https://github.com/Michael-Mathu/M-Run-3.0/blob/main/PRIVACY.md` |
| Store assets | [`docs/play-store/`](play-store/): 512 px icon, 1024×500 feature graphic, 9:16 phone screenshots with no athlete photos |
| SOS on Android 11+ | Manifest `<queries>` added so the SMS app and dialer can be opened |

## Your steps

### 1. Create the developer account (one-off)

1. Go to <https://play.google.com/console/signup>, choose **Personal** (or
   Organisation if you have a registered business), pay the **US$25** one-off
   fee and complete identity verification (ID document; can take a few days).
2. A **personal** account created after November 2023 must run a **closed
   test with at least 12 testers opted in for 14 days in a row** before it
   can apply for production. Start collecting 12 Google-account emails now
   (friends, a running club). Organisation accounts skip this.

### 2. Create the upload key (one-off, 2 minutes)

The key proves updates come from you. Choose the passwords yourself and keep
the file and passwords somewhere safe (a password manager and a backup). In
PowerShell:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore "$env:USERPROFILE\mwendo-upload.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `app/android/key.properties.example` to `app/android/key.properties`
and fill in the two passwords. That file and the `.jks` are git-ignored;
never commit or share them.

### 3. Build the bundle

```powershell
cd app
flutter build appbundle --release
```

Upload `app/build/app/outputs/bundle/release/app-release.aab`. For every
later upload, first raise the number after the `+` in `version:` in
`app/pubspec.yaml` (for example `1.2.0+5` → `1.2.1+6`); Play rejects a
repeated number.

### 4. Create the app in Play Console

**Create app** → name **Mwendo**, default language English, **App**, **Free**.
When asked, accept **Play App Signing** (Google keeps the real signing key;
yours is only the upload key, which can be reset if lost).

> The package name `com.mwendo.mwendo_app` becomes permanent at the first
> upload. If you want a different one (for example `com.mwendo.app`), say so
> before uploading.

### 5. "App content" declarations

| Section | Answer |
| :--- | :--- |
| Privacy policy | The `PRIVACY.md` URL above |
| App access | All functionality is available without special access (no login) |
| Ads | No, the app does not contain ads |
| Content rating | Fill in the questionnaire: category *Utility / Productivity / Other*; no violence, sexual content, gambling, user-to-user communication or location *sharing* → expect "Everyone" |
| Target audience | 13 and over (do not tick under-13 groups) |
| Data safety | See below |
| Health apps | Tick **Activity and fitness** |
| Government / Financial / News | No |
| Advertising ID | No, the app does not use an advertising ID |

**Foreground service permission** (asked when the bundle is uploaded): type
**Location**, task **"User-initiated location tracking, e.g. fitness / run
tracking"**. Google asks for a short video link showing it: record your
phone screen starting a run, locking the screen, unlocking, and stopping
(the ongoing notification must be visible). An unlisted YouTube link is fine.

**Data safety form.** Nothing is sent to a server of yours. The only thing
that leaves the phone automatically is the map-tile request, which shows the
tile provider roughly which area is on screen. The cautious, honest answers:

- Does the app collect or share user data? **Yes**
- Is all data encrypted in transit? **Yes** (HTTPS only)
- Can users request deletion? Choose the option that data is not stored by
  you / users delete it in the app
- Data type: **Location → Approximate location**: collected **yes**, shared
  **no**, **processed ephemerally: yes**, **required**, purpose **App
  functionality**
- Everything else (precise location, health and fitness, photos, contacts,
  personal info): **not collected**, because it never leaves the device

This is my best reading of Google's definitions, not legal advice; if you
later add the online account or leaderboard, the form and `PRIVACY.md` must
both be updated first.

### 6. Store listing

- **App name (30):** `Mwendo: Run with Legends`
- **Short description (80):**
  `Track runs, walks and rides, race the pace of running legends, learn as you go.`
- **Full description:** see [`play-store/listing.md`](play-store/listing.md)
- **App icon:** `play-store/icon-512.png`
- **Feature graphic:** `play-store/feature-graphic.png`
- **Phone screenshots:** the PNGs in `play-store/screenshots/` (at least 2,
  up to 8)
- **Category:** Health & Fitness. **Contact email:** required, shown publicly.

Keep athlete photos out of the listing images, and do not use an athlete's
name in the app title: that is where Play's impersonation and
intellectual-property rules bite.

### 7. Test, then release

1. **Testing → Internal testing**: upload the `.aab`, add yourself, install
   from the opt-in link and do a real run. (Uninstall the GitHub APK first:
   it is signed with a different key, and Android will refuse to install over
   it. Runs stored in it are lost.)
2. **Testing → Closed testing**: add your 12+ testers and send them the
   opt-in link. Leave it running 14 days.
3. **Production → Apply for access**, answer the questions about your test,
   then create the production release and choose countries. First review
   usually takes a few days.

## Still open (not blockers)

- **Adaptive icon.** The launcher icon is a legacy square image; newer
  launchers show it inside a white circle. An adaptive icon needs the logo as
  a foreground layer with transparent padding.
- **App size.** The bundle includes Inter fonts and 28 portraits; Play
  delivers a smaller per-device download than the 96 MB universal APK.
- **Online features.** To ship accounts and the leaderboard, deploy the
  backend, build with `--dart-define=API_BASE_URL=https://…`, add in-app
  account deletion (a Play requirement), and update the privacy policy and
  Data safety form.
- **iOS.** Not built or tested (no Xcode on the development machine).
