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
| `Info-Debug.plist` / `Info-Profile.plist` | No CarPlay scene; **no Siri/`IN*` keys**; `NSUserActivityTypes`; `SceneDelegate` | — |
| `Info-Release.plist` | — | CarPlay + Siri intents + `NSUserActivityTypes` |
| `Debug.xcconfig` / `Release.xcconfig` | Defaults + optional `Local.xcconfig` | Same file used by Profile |

## Crash: `NSUserActivity` / empty `activityType`

iOS aborts with:

`Caller did not provide an activityType, and this process does not have a NSUserActivityTypes in its Info.plist.`

Seen during **keyboard autofill** / tsnet **interactive** login — not MagicDNS
itself. Declaring `NSUserActivityTypes` alone is **not** enough when
`activityType` is literally empty.

**Fix on this fork:**
- `NSUserActivityTypes` in Debug/Profile/Release Info plists
- `FinampNSUserActivityGuard.m` remaps empty `initWithActivityType:` values
- `SceneDelegate` ignores empty continue activities
- Mobile embedded Tailscale is **auth-key only** (no `StartLoginInteractive`)
- Auth-key field disables autofill hints

Hang lines like `Hang detected: 0.48s (debugger attached, not reporting)` are
debugger noise while `flutter run` is attached — not the crash.

If LLDB/`flutter run` disconnects but the app icon is still open, the **process
may still die a moment later** on the ObjC exception — force-quit and relaunch
after updating the build.

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
