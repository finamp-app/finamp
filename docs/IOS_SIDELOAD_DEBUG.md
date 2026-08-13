# Personal-team iOS sideload

Free Apple Developer accounts cannot sign **CarPlay** or **Siri**. Declaring
those capabilities (or a CarPlay `UIScene` without the entitlement) makes iOS
**kill the app immediately** after “Trust” — no Flutter error UI.

## Prefer Profile (smooth launch)

Use **Profile**, not Debug, for day-to-day device testing.

For a **detached** install (no Xcode/debugger) that **does not uninstall** the
existing app — required so iOS keeps the trusted personal-team profile:

```bash
# Dev MacBook
./scripts/install-ios-profile.sh
# optional: IOS_DEVICE=<udid> SKIP_BUILD=1 ./scripts/install-ios-profile.sh
```

That runs `flutter build ios --profile` then
`xcrun devicectl device install app` (in-place upgrade).

**Do not** use `flutter install` for these drops. It uninstalls the old copy
first (`Uninstalling old version…`). If Finamp is the only app signed with
personal team `F3E25E64U6`, iOS **removes** the developer management profile
and the next launch shows **Untrusted Developer** again.

`flutter run --profile` is fine when you want an attached session:

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

Trust is **per developer certificate on the device**, not per app version.

1. Install Finamp (or any other app signed with the **same** personal team).
2. **Settings → General → VPN & Device Management** → your Apple ID → **Trust**.
3. Leave **at least one** app from that team on the device at all times.

A one-time **Settings → Privacy & Security → Developer Mode** prompt is
separate from Untrusted Developer.

You should **not** need to re-trust after each Profile drop if installs are
in-place (`./scripts/install-ios-profile.sh`). Re-trust is expected if:

- you deleted Finamp **and** every other app from this personal team, or
- the signing identity/certificate actually changed (new Apple ID, new cert).

Optional: keep a tiny second Xcode app on the phone signed with `F3E25E64U6`
so uninstalling Finamp does not wipe the profile.

Free personal teams cannot permanently “accept this Apple ID forever” with no
app installed. TestFlight / App Store (paid Apple Developer Program) never
show Untrusted Developer.

## UIScene

Phone UI uses `FlutterSceneDelegate` + `FlutterImplicitEngineDelegate`
([migration guide](https://docs.flutter.dev/to/uiscene-migration)).
CarPlay stays on Release via the shared `FlutterEngine` in `AppDelegate`.
