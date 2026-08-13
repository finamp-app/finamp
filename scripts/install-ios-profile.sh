#!/usr/bin/env bash
# Build a Profile iOS app and install it in-place (no uninstall).
#
# Paste on: Dev MacBook, from anywhere (script cds to repo root).
#
# Do NOT use `flutter install` here. That uninstalls the old copy first; if
# Finamp is the only app from the personal team, iOS drops the trusted
# developer profile and the next launch shows Untrusted Developer again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-16.2.app/Contents/Developer}"
export PATH="${FLUTTER_BIN:-$HOME/Development/flutter/bin}:$HOME/go/bin:$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"

IOS_DEVICE="${IOS_DEVICE:-00008020-0004484921F0002E}"
APP="${APP:-$ROOT/build/ios/iphoneos/Runner.app}"
SKIP_BUILD="${SKIP_BUILD:-0}"

echo "==> In-place Profile install (no uninstall)"
echo "    device=$IOS_DEVICE"
echo "    app=$APP"

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "==> flutter build ios --profile"
  flutter build ios --profile
fi

if [[ ! -d "$APP" ]]; then
  echo "✗ Missing $APP — run without SKIP_BUILD=1 or set APP="
  exit 1
fi

echo "==> xcrun devicectl device install app (upgrade in place)"
xcrun devicectl device install app --device "$IOS_DEVICE" "$APP"
echo "✓ Installed. Launch Finamp from the home screen (no debugger attached)."
echo "  Trust should persist unless you deleted every app from this personal team."
