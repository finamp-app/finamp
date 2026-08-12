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
2. Enable **Connect via embedded Tailscale**
3. Paste a Tailscale **auth key** (recommended) or complete interactive login
4. Set the Jellyfin server URL to a MagicDNS name, e.g.
   `https://jellyfin.tailnet.ts.net:8096`
   (the login screen still normalizes the common `jellyfin@tailnet` typo)
5. Jellyfin API calls (Chopper) go through `Tailscale.instance.http.client`

When the toggle is on, app launch calls `Tailscale.up()` again so MagicDNS
works without reopening Settings (saved credentials / auth key flow).

Until tsnet reports running (after auth key / interactive login), Chopper falls
back to the platform HTTP client — MagicDNS names like `*.ts.net` will fail
with `Failed host lookup` until login finishes. Prefer an **auth key** over
interactive login on iOS sideloads (fewer Safari/autofill edge cases).

Toggle off to use the normal LAN / public HTTP client again.

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
- Prefer short-lived or tagged auth keys from the Tailscale admin console.
- Use **Log out / reset node** before handing a device away.

## Scope / non-goals

- Music Finder / External Search is **not** on this branch (personal fork work).
- Audio streaming (`just_audio`) may still use the platform HTTP stack; if
  streams fail over MagicDNS while API works, a follow-up must route media
  fetches through the same client.
- Not proposed to upstream until device-tested and package:tailscale reviewed
  for key storage.

## Related

- Copilot task: https://github.com/itdir/finamp/tasks/5fd20a6a-e3ee-44ab-82d3-8a34c7646131
- Plan: `~/.cursor/plans/finamp_embedded_tsnet_5fd20a6a.plan.md`
- Personal-team device installs: prefer `flutter run --profile` — see [IOS_SIDELOAD_DEBUG.md](IOS_SIDELOAD_DEBUG.md)
