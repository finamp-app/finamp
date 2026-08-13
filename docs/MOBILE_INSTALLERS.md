# Mobile installers (personal builds)

> **Fork workflow:** Day-to-day Finamp work on this fork bases on canonical
> `upstream/redesign` (`finamp-app/finamp`), not `main`. Keep `main` frozen —
> open PRs against `redesign` only.

Build sideload packages for Android phones and iPhones from this fork.

## One-command build

```bash
# Dev MacBook — Finamp repo root
cd /Users/macadmin/Development/finamp
./scripts/build-mobile-installers.sh
```

Outputs land in `dist/` (gitignored):

| Artifact | Purpose |
|----------|---------|
| `finamp-android-debug.apk` | Installs **alongside** Play Store / F-Droid Finamp (`…finamp.debug`) |
| `finamp-ios-development.ipa` | Development IPA for your Apple ID (requires Xcode signed in + device registered) |

Options:

```bash
SKIP_IOS=1 ./scripts/build-mobile-installers.sh              # Android only
SKIP_ANDROID=1 ./scripts/build-mobile-installers.sh          # iOS only
ANDROID_MODE=release ./scripts/build-mobile-installers.sh    # release APK (local keystore)
IOS_BUNDLE_ID=com.anonymous.finamp IOS_TEAM_ID=F3E25E64U6 ./scripts/build-mobile-installers.sh
```

## Prerequisites

- Flutter stable with **Dart ≥ 3.9** (`flutter doctor` green for Android + Xcode) — redesign requires `sdk: ^3.9.0`
- **JDK** matching the current Android Gradle Plugin in this tree (`flutter doctor` / Gradle errors will say if the JDK is wrong)
- Android SDK at `~/Library/Android/sdk` (script / `flutter config --android-sdk` sets this)
- Xcode 16.x with CocoaPods

## Install Android (Pixel / any device)

```bash
# Dev MacBook — USB debugging enabled on the phone
adb install -r dist/finamp-android-debug.apk
```

Or copy the APK to the phone and open it (allow install from that source).

## Install iPhone

### 1. Sign into Xcode (required once)

Xcode must have a valid Apple ID session. If `xcodebuild` reports `missing Xcode-Token` or **No Accounts**:

1. Open **Xcode → Settings → Accounts**
2. Add / re-authenticate **perkinsfam.bp@gmail.com** (Brian Perkins team `F3E25E64U6`)
3. Plug in **iPhone XS** via USB, trust the computer, and let Xcode register the device

### 2. Build the IPA

```bash
SKIP_ANDROID=1 ./scripts/build-mobile-installers.sh
```

The script temporarily overrides the upstream Finamp team/bundle id to:

- Team: `F3E25E64U6`
- Bundle ID: `com.anonymous.finamp`

then restores `ios/Runner.xcodeproj/project.pbxproj` afterward.

### 3. Install the IPA

**Do not** AirDrop/Finder-copy the `.ipa` and tap it on the phone. Development IPAs are not installable that way and show *Unable to Install “Finamp” / Please try again later*.

Use one of these instead (phone USB-connected):

- Xcode → **Window → Devices and Simulators** → select iPhone → **+** under Installed Apps → choose `dist/finamp-ios-development.ipa`
- Apple Configurator 2 → Add → that IPA
- Or from source: `flutter run --release -d <iphone-device-id>`

Then on iPhone: **Settings → General → VPN & Device Management** → trust the developer certificate **once**. Leave Finamp (or another app from the same personal team) installed so that profile stays.

Day-to-day Profile upgrades (no debugger, no Untrusted Developer loop):

```bash
# Dev MacBook — in-place install; do not use flutter install
./scripts/install-ios-profile.sh
```

`flutter install` **uninstalls** the old copy first. If that was the last app
from team `F3E25E64U6`, iOS drops the trusted developer profile and the next
launch asks you to Trust again. Details: [IOS_SIDELOAD_DEBUG.md](IOS_SIDELOAD_DEBUG.md).

If install fails with a vague *Unable to Install* message, check the Mac console/`devicectl` log. A common build bug is every embedded framework sharing the app bundle id (`DuplicateIdentifier`) — the installer script avoids that by only changing the Runner target’s bundle id.

## Local signing overrides

`ios/Flutter/Local.xcconfig` is gitignored (see `Local.xcconfig.example`).  
`android/key.properties` + `*.jks` are already gitignored; release mode generates a local keystore automatically.

## Sideload OTA (Profile channel)

For recurring updates without USB every time, use the **Profile** publish pipeline
and in-app **Settings → Updates**:

```bash
# Dev MacBook — builds Profile APK + IPA, latest.json, uploads sideload-latest
./scripts/publish-sideload-release.sh
```

- Android Auto mode can silent-install after one-time “Install unknown apps” +
  installer-of-record setup.
- iOS personal team: notify + SideStore / USB only (no silent install).
- Do **not** publish the `*.debug` APK into `sideload-latest` — OTA targets
  `…finamp.profile`.

Full checklist, versioning (`0.9.25-sideload.N+build`), Bitwarden keystore
backup name, and private-repo notes: [SIDELOAD_OTA.md](SIDELOAD_OTA.md).
