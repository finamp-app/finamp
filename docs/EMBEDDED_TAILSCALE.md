# Embedded Tailscale (tsnet)

Fork-only feature: Finamp can join your tailnet **in-process** via
[`package:tailscale`](https://pub.dev/packages/tailscale) (upstream Go `tsnet`).
This is **not** a system VPN, so it can coexist with ExpressVPN on iOS/Android.

## Why

iOS and Android allow only one system VPN profile at a time. The official
Tailscale app and ExpressVPN cannot both be active. Userspace `tsnet` speaks
WireGuard-over-UDP from inside Finamp and leaves the OS routing table alone.

## User flow

1. Settings → **Embedded Tailscale**
2. Paste a Tailscale **auth key** (`tskey-auth-…` from the admin console).
   On **iOS/Android**, an auth key is **required** — interactive browser login
   is disabled (it can abort the app via an empty `NSUserActivity` / autofill
   path). Prefer a reusable / tagged key.
3. Enable **Connect via embedded Tailscale** (or tap Connect). First connect
   uses the auth key (and briefly sets `TSNET_FORCE_LOGIN=1` so tsnet does not
   ignore the key on `NoState`). Later app launches **resume from disk without
   re-submitting the key** — that is what makes MagicDNS work immediately
   without opening Settings.
4. Status should become **Running** with a tailnet IP. Until then MagicDNS
   names like `*.ts.net` will fail lookup and downloads may pause
   (“Connection interrupted”).
5. Set the Jellyfin server URL to a MagicDNS name, e.g.
   `https://jellyfin.tailnet.ts.net:8096`
   (the login screen still normalizes the common `jellyfin@tailnet` typo)
6. Jellyfin API calls (Chopper), library `getItems`, cover-art cache downloads,
   **Music Finder** health/search/add, and **Network → Test both connections**
   go through `FinampHttpClient` / tsnet when embedded Tailscale is Running.

Library browsing uses a background isolate with a plain `IOClient` when
Tailscale is **off**. When Embedded Tailscale is on (or the active URL is
MagicDNS / `100.x`), those calls stay on the **main isolate** so they use
`FinampHttpClient`. Otherwise you can pass Network Test while albums fail to
load.

**Not routed through FinampHttpClient** (OS / media stacks): streaming playback
(`just_audio` URI fetch) and `background_downloader` file downloads. Prefer
LAN or a reachable public URL for those until a dedicated tsnet media path
exists; downloaded tracks still play offline.

When the toggle is on, app launch calls `EmbeddedTailscaleService.up()` which
resumes persisted credentials (falling back to the stored auth key only if
resume fails or returns `needsLogin`).

Toggle off to use the normal LAN / public HTTP client again.

### Network settings vs Tailscale

| Field | Typical value | Wi‑Fi at home | Cellular |
|-------|---------------|---------------|----------|
| **Local** | LAN IP / `.local` | Should pass | Fails (expected — not on LAN) |
| **Public** | MagicDNS `*.ts.net` (or `100.x` CGNAT) | Passes when tsnet Running | Passes when tsnet Running |

The public URL is saved on keyboard submit, unfocus, Test, and when you leave
the screen. Older builds only saved on the keyboard **Done** key, so leaving
Network settings discarded a typed MagicDNS name and showed the login/LAN
address again — Test on cellular then pinged LAN and both checks failed.

**Cellular:** Local failing is expected. Public should pass if Embedded
Tailscale is **Running** and the public field is actually `*.ts.net` (not the
LAN IP). After a radio switch, Finamp resumes tsnet and allows up to 15s for
the public ping (LAN pings stay at 3s).

If Public still fails while Embedded Tailscale shows Running, confirm the
public field is MagicDNS, then rebuild. Older builds used a plain `IOClient`
for that test and always failed MagicDNS.

## Build requirements

- Flutter with **Dart ≥ 3.10.4** (this branch bumps `sdk: ^3.10.4`)
- **Go 1.25+** on `PATH` (Go 1.26 recommended). The first build compiles the
  native tsnet asset; later builds are cached.
- **Rust / rustup** on `PATH` (Finamp’s `flutter_discord_rpc` builds via Cargokit;
  iOS needs `rustup target add aarch64-apple-ios`)
- Xcode (iOS/macOS) / Android NDK via Flutter
- On **Xcode 16.2** (iOS 18.2 SDK), keep plugin caps in `pubspec.yaml` so the
  tree does not pull iOS 26-only APIs that still support Finamp’s **iOS 14+**
  deployment target:
  - `device_info_plus: ">=12.1.0 <12.4.0"`
  - `connectivity_plus: ">=7.0.0 <7.3.0"`

```bash
# Dev MacBook — Finamp repo
go version   # expect go1.25+
rustc --version
flutter pub get
flutter run
```

## Security notes

- Node WireGuard private key lives under application support
  (`…/embedded_tailscale/`). Do not back this directory up to iCloud.
- **Auth keys** and the **Music Finder server URL** are stored with
  `flutter_secure_storage` (iOS/macOS Keychain, Android EncryptedSharedPreferences /
  Keystore)—not Hive or plain SharedPreferences. Older plaintext copies are
  migrated once at startup and deleted.
- Prefer short-lived or tagged auth keys from the Tailscale admin console.
- Use **Log out / reset node** before handing a device away.

## Scope / non-goals

- This stacked branch includes Music Finder + External Search. Hive
  `useEmbeddedTailscale` is `@HiveField(154)`; legacy plaintext
  `musicFinderServerUrl` was `@HiveField(155)` and is cleared after migration
  into secure storage. Music Finder HTTP uses `FinampHttpClient` (tsnet).
- Audio streaming (`just_audio`) may still use the platform HTTP stack; if
  streams fail over MagicDNS while API works, a follow-up must route media
  fetches through the same client.
- Not proposed to upstream until device-tested and package:tailscale reviewed
  for key storage.

## Related

- Copilot task: https://github.com/itdir/finamp/tasks/5fd20a6a-e3ee-44ab-82d3-8a34c7646131
- Plan: `~/.cursor/plans/finamp_embedded_tsnet_5fd20a6a.plan.md`
- Personal-team device installs: prefer `flutter run --profile` — see [IOS_SIDELOAD_DEBUG.md](IOS_SIDELOAD_DEBUG.md)
