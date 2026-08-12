# Personal-team iOS sideload (Debug)

Free Apple Developer accounts cannot sign **CarPlay** or **Siri**. If those
capabilities are present in the Debug entitlements / Info.plist, iOS often
**kills the app immediately** after you tap “Trust” (no Flutter error UI).

## What this fork does for Debug

| File | Behavior |
|------|----------|
| `ios/Runner/RunnerDebug.entitlements` | Empty (no CarPlay / Siri) |
| `ios/Runner/Info-Debug.plist` | No CarPlay `UIScene`; uses `FlutterSceneDelegate` |
| `ios/Flutter/Debug.xcconfig` | Defaults + optional `Local.xcconfig` overrides |
| `ios/Runner/Runner.entitlements` | Unchanged CarPlay + Siri for Release / Profile |

## Local overrides (gitignored)

Create `ios/Flutter/Local.xcconfig`:

```
DEVELOPMENT_TEAM=YOUR_PERSONAL_TEAM_ID
PRODUCT_BUNDLE_IDENTIFIER=com.anonymous.finamp
```

Debug **does not** hardcode team/bundle in `project.pbxproj`, so this file applies.

## Run

```bash
# Dev MacBook
export DEVELOPER_DIR=/Applications/Xcode-16.2.app/Contents/Developer
export PATH="$HOME/go/bin:$HOME/.cargo/bin:/Users/macadmin/Development/flutter/bin:$PATH"
cd /Users/macadmin/Development/finamp
flutter run -d <device-id>
```

First launch: Settings → General → VPN & Device Management → trust your Apple ID.
Trust is expected once per reinstall / new signing identity — not every launch.

## UIScene

Debug / Release phone UI use Flutter’s `FlutterSceneDelegate` +
`FlutterImplicitEngineDelegate` (see [UIScene migration](https://docs.flutter.dev/to/uiscene-migration)).
CarPlay remains on Release/Profile via the shared `FlutterEngine` in `AppDelegate`.
