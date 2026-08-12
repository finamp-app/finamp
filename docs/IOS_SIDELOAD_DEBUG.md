# Personal-team iOS sideload

Free Apple Developer accounts cannot sign **CarPlay** or **Siri**. Declaring
those capabilities (or a CarPlay `UIScene` without the entitlement) makes iOS
**kill the app immediately** after “Trust” — no Flutter error UI.

## Prefer Profile (smooth launch)

Use **Profile**, not Debug, for day-to-day device testing:

```bash
# Dev MacBook
export DEVELOPER_DIR=/Applications/Xcode-16.2.app/Contents/Developer
export PATH="$HOME/go/bin:$HOME/.cargo/bin:/Users/macadmin/Development/flutter/bin:$PATH"
cd /Users/macadmin/Development/finamp
flutter run --profile -d <device-id>
```

Profile is optimized (no debug VM / observatory), closer to Release, and on this
fork is personal-team–safe (empty entitlements, no CarPlay scene).

| Mode | Command | Personal sideload | Notes |
|------|---------|-------------------|--------|
| **Profile** | `flutter run --profile` | Yes | Preferred for smooth launch |
| Debug | `flutter run` | Yes | Use only when debugging |
| Release | `flutter run --release` | No* | Still has CarPlay/Siri entitlements for paid-team / store builds |

\* Personal `--release` will fail signing or get killed unless you temporarily
point Release at `RunnerDebug.entitlements` (not the default).

## What this fork changes

| File | Debug / Profile | Release |
|------|-----------------|---------|
| `RunnerDebug.entitlements` | Empty (no CarPlay / Siri) | — |
| `Runner.entitlements` | — | CarPlay + Siri |
| `Info-Debug.plist` / `Info-Profile.plist` | No CarPlay scene; **no Siri/`IN*` keys**; `FlutterSceneDelegate` | — |
| `Info-Release.plist` | — | CarPlay + Siri intents + `NSUserActivityTypes` |
| `Debug.xcconfig` / `Release.xcconfig` | Defaults + optional `Local.xcconfig` | Same file used by Profile |

## Crash: `NSUserActivity` / empty `activityType`

If Debug/Profile declare `INIntentsSupported` / Siri usage **without** a Siri
entitlement and `NSUserActivityTypes`, iOS can abort with:

`Caller did not provide an activityType, and this process does not have a NSUserActivityTypes in its Info.plist.`

That is **not** Tailscale. Fix: omit Siri/intent keys from sideload Info plists
(Release keeps them + `NSUserActivityTypes`).

Hang lines like `Hang detected: 0.48s (debugger attached, not reporting)` are
debugger noise while `flutter run` is attached — not the crash.

## Local overrides (gitignored)

`ios/Flutter/Local.xcconfig`:

```
DEVELOPMENT_TEAM=YOUR_PERSONAL_TEAM_ID
PRODUCT_BUNDLE_IDENTIFIER=com.anonymous.finamp
```

Debug and Profile do **not** hardcode team/bundle in `project.pbxproj`.

## Trust developer

Expected once per reinstall / new signing identity — not every launch.
Settings → General → VPN & Device Management → trust your Apple ID.

## UIScene

Phone UI uses `FlutterSceneDelegate` + `FlutterImplicitEngineDelegate`
([migration guide](https://docs.flutter.dev/to/uiscene-migration)).
CarPlay stays on Release via the shared `FlutterEngine` in `AppDelegate`.
