# Sideload OTA (fork)

Self-hosted updates for personal Profile builds via GitHub Releases on
`itdir/finamp`. **Android** can silent-install after one-time setup. **iOS**
(personal team) can only notify and point at SideStore / USB — never silent
install without a paid Apple program.

## Versioning

`pubspec.yaml` uses upstream base + channel suffix:

| Example | Meaning |
|---------|---------|
| `0.9.25-sideload.1+127` | Upstream `0.9.25`, first sideload revision, build `127` |
| `0.9.25-sideload.2+128` | Another fork-only drop |
| `0.9.26-sideload.1+141` | After sync to upstream `0.9.26+140` |

OTA compares the **integer** after `+` only (`latest.json` → `build`).

## Publish (Dev MacBook)

```bash
cd /Users/macadmin/Development/finamp
# Optional: bump -sideload.N and +build
BUMP=1 ./scripts/publish-sideload-release.sh

# Or publish current pubspec version:
./scripts/publish-sideload-release.sh
```

Produces under `dist/` (gitignored):

- `finamp-android-profile.apk` (`applicationId` `…finamp.profile` — not `.debug`)
- `finamp-ios-profile.ipa`
- `latest.json`
- `sideload-source.json` (SideStore)

Uploads a version tag (`v0.9.25-sideload.1+127`) **and** refreshes floating
release/tag **`sideload-latest`** so the app’s baked URL stays stable:

`https://github.com/itdir/finamp/releases/download/sideload-latest/latest.json`

Useful flags: `SKIP_IOS=1`, `SKIP_ANDROID=1`, `SKIP_UPLOAD=1`, `NOTES='…'`,
`GITHUB_REPO=itdir/finamp`.

Also see [MOBILE_INSTALLERS.md](MOBILE_INSTALLERS.md) for USB bootstrap /
emergency `adb install -r`.

## Android signing key (critical)

Silent update only works if every OTA APK is signed with the **same** key as
the installed app.

- Local (gitignored): `android/upload-keystore.jks` + `android/key.properties`
- **Backup:** Bitwarden / Vaultwarden Secure Note named  
  **`Finamp sideload Android keystore`**  
  Attach the `.jks`, and store `storePassword`, `keyPassword`, `keyAlias`, plus
  a one-line reminder of `applicationId` (`com.unicornsonlsd.finamp.profile`
  for Profile).
- Do **not** commit the keystore or `key.properties`.
- Mixing `adb` debug signing vs this keystore → `UPDATE_INCOMPATIBLE` /
  full uninstall.

The publish script generates a local keystore if missing; copy it into Bitwarden
immediately.

## In-app Settings → Updates

- **Automatic** (default): at configured local time (default **3:33 AM**),
  fetch manifest; on Android download + silent `PackageInstaller` when allowed.
- **Manual:** Check now only.
- Wi‑Fi / unmetered by default; optional cellular.
- Defers silent install while music is playing; catch-up on next launch if the
  alarm was deferred (Doze does not promise second-accurate delivery).

### One-time Android setup

1. Allow **Install unknown apps** for Finamp.
2. If this build was installed with `adb`, the installer-of-record is shell —
   complete **one** confirmed Install from in-app so Finamp owns later silent
   Auto updates.
3. After that, Auto at 3:33 should not show a confirmation sheet.

Emergency: `adb install -r dist/finamp-android-profile.apk` (may reset
installer-of-record to shell — redo step 2).

## iOS (personal team)

Same check / notify UX. Auto does **not** install the IPA. Use:

- SideStore source URL from `latest.json` / Settings sheet
- Or USB: `./scripts/install-ios-profile.sh`

Weekly / 7-day personal cert refresh is still required; version OTA does not
refresh code signing.

## Private GitHub repos

Phones cannot download private Release assets without auth. Prefer:

- Public release assets, or a public sibling artifacts repo, **or**
- Optional read-only token in secure storage (never commit secrets). Document
  any token-based download if you enable it later.

## Manifest shape

See `dist/latest.json` after a publish. Fields used by the app:

- `version` (display), `build` (int compare), `notes`
- `android.apkUrl` / `sha256` / `sizeBytes`
- `ios.ipaUrl` / `sha256` / `sideStoreSourceUrl`
