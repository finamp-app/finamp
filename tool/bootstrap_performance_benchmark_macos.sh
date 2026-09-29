#!/usr/bin/env bash
set -euo pipefail

BRANCH="${FINAMP_BENCH_BRANCH:-$(git branch --show-current)}"
OUT_DIR="${FINAMP_BENCH_OUT:-benchmark-results}"

fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

command -v git >/dev/null || fail "git not found"
command -v flutter >/dev/null || fail "flutter not found"
command -v python3 >/dev/null || fail "python3 not found"
command -v xcodebuild >/dev/null || fail "Xcode command line tools not found"
command -v xcrun >/dev/null || fail "xcrun not found"
command -v pod >/dev/null || fail "CocoaPods not found"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Run this inside the Finamp repository"

# Allow known machine-local iOS/dev files while still refusing to run over
# real source changes. These files may be required for local signing/build setup.
dirty_lines="$(git status --porcelain | python3 -c '
import sys
allowed_exact = {
    " M ios/Podfile.lock",
    " M ios/Runner.xcodeproj/project.pbxproj",
    " D ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    " D ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    " M ios/Runner/Info-Debug.plist",
    " M ios/Runner/Info-Profile.plist",
    " M ios/Runner/Info-Release.plist",
    " M ios/Runner/Runner.entitlements",
    " M pubspec.lock",
    "?? ios/Runner/RunnerDebug.entitlements",
    "?? ios/Runner/RunnerRelease.entitlements",
    "?? pubspec_overrides.yaml",
}
allowed_prefixes = (
    "?? benchmark-results/",
    "?? \"Build Runner_",
)
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    if line in allowed_exact:
        continue
    if any(line.startswith(prefix) for prefix in allowed_prefixes):
        continue
    print(line)
')"
if [[ -n "$dirty_lines" ]]; then
  printf '%s\n' "$dirty_lines" >&2
  fail "Working tree contains source/tracked changes. Restore/commit/stash those first; known local entitlements and pubspec_overrides.yaml are allowed."
fi

if [[ -z "$BRANCH" ]]; then
  fail "Detached HEAD is not supported. Check out the branch you want to benchmark or set FINAMP_BENCH_BRANCH."
fi

step "Updating benchmark branch: $BRANCH"
git fetch origin "$BRANCH"

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "$BRANCH" ]]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git switch "$BRANCH"
  else
    git switch --track -c "$BRANCH" "origin/$BRANCH"
  fi
fi

git merge --ff-only "origin/$BRANCH"

step "Flutter / Xcode sanity checks"
flutter --version
xcodebuild -version
pod --version

step "Resolving Flutter dependencies"
flutter pub get

step "Static benchmark preflight"
if ! dart format --output=none --set-exit-if-changed \
  lib/services/performance_benchmark_service.dart \
  lib/services/performance_benchmark_suite_runner.dart \
  lib/services/queue_service.dart \
  lib/services/downloads_service.dart \
  lib/services/downloads_service_backend.dart \
  lib/services/jellyfin_api_helper.dart \
  lib/services/music_player_background_task.dart \
  lib/services/album_image_provider.dart \
  lib/services/http_aggregate_logging_interceptor.dart \
  lib/main.dart \
  lib/screens/music_screen.dart \
  lib/components/MusicScreen/music_screen_tab_view.dart \
  lib/components/AlbumScreen/album_screen_content.dart \
  lib/components/ArtistScreen/artist_screen_content.dart \
  lib/components/GenreScreen/genre_screen_content.dart \
  lib/components/HomeScreen/home_screen_content.dart; then
  printf 'WARNING: Dart formatter would change benchmark-touched files. Continuing because Finamp CI does not enforce dart format; analyzer/build remain hard gates.\n' >&2
fi
flutter analyze --no-fatal-infos --no-fatal-warnings

python3 -m py_compile \
  tool/summarize_performance_benchmark.py \
  tool/test_performance_benchmark_summary.py
python3 tool/test_performance_benchmark_summary.py
bash -n tool/run_performance_benchmark.sh
bash -n tool/bootstrap_performance_benchmark_macos.sh

step "Checking iOS pods"
(
  cd ios
  pod install
)

case "${FINAMP_BENCH_PREFLIGHT_ONLY:-false}" in
  1|true|TRUE|True|yes|YES|Yes|on|ON|On)
    step "Compiling iOS PROFILE benchmark app without codesigning"
    flutter build ios \
      --profile \
      --no-codesign \
      --dart-define=FINAMP_PERFORMANCE_BENCHMARK=true \
      --dart-define=FINAMP_BENCH_SMOKE=false \
      --dart-define=FINAMP_BENCH_SEARCH_QUERY_1=compile-probe-1 \
      --dart-define=FINAMP_BENCH_SEARCH_QUERY_2=compile-probe-2 \
      --dart-define=FINAMP_BENCH_SEARCH_QUERY_3=compile-probe-3 \
      --dart-define=FINAMP_BENCH_VARIANT=compile-preflight \
      --dart-define=FINAMP_BENCH_RUN_ID=compile-preflight
    step "Host-only benchmark preflight complete"
    printf 'No iPhone was required and no app was installed.\n'
    exit 0
    ;;
esac

step "Finding a physical iOS device"
DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  set +e
  DEVICE_ID="$(flutter devices --machine | python3 -c '
import json,sys
devices=json.load(sys.stdin)
physical=[d for d in devices if d.get("targetPlatform")=="ios" and not d.get("emulator",False)]
if len(physical)==1:
    print(physical[0]["id"])
elif len(physical)==0:
    sys.exit(2)
else:
    sys.exit(3)
')"
  status=$?
  set -e

  if [[ "$status" -eq 2 ]]; then
    flutter devices
    fail "No physical iOS device found. Connect/unlock/trust the iPhone and try again."
  elif [[ "$status" -eq 3 ]]; then
    flutter devices
    fail "More than one physical iOS device found. Re-run with the device id as the only argument."
  elif [[ "$status" -ne 0 ]]; then
    fail "Could not determine iOS device."
  fi
fi

step "Selected device: $DEVICE_ID"
mkdir -p "$OUT_DIR"

step "Starting Finamp benchmark in PROFILE mode"
case "${FINAMP_BENCH_DOWNLOAD_BENCH1000_ONLY:-false}" in
  1|true|TRUE|True|yes|YES|Yes|on|ON|On)
    printf 'Targeted bench-1000 download diagnostics enabled.\n'
    ;;
  *)
    case "${FINAMP_BENCH_DOWNLOAD_BENCH100_ONLY:-false}" in
      1|true|TRUE|True|yes|YES|Yes|on|ON|On)
        printf 'Targeted bench-100 download diagnostics enabled.\n'
        ;;
      *)
        case "${FINAMP_BENCH_SMOKE:-false}" in
      1|true|TRUE|True|yes|YES|Yes|on|ON|On)
        printf 'Smoke matrix enabled via FINAMP_BENCH_SMOKE.\n'
        ;;
          *)
            printf 'Full benchmark matrix enabled.\n'
            ;;
        esac
        ;;
    esac
    ;;
esac
printf 'Results will be written continuously under %s/\n' "$OUT_DIR"
printf 'The app will be built, installed and launched via Xcode devicectl.\n'
printf 'No Flutter mDNS / Dart VM service connection is required.\n\n'

BENCH_VARIANT="$(git rev-parse --short=12 HEAD)"
BENCH_RUN_ID="$(date -u +"%Y%m%dT%H%M%SZ")"
bash tool/run_performance_benchmark.sh "$DEVICE_ID" "$BENCH_VARIANT" "$BENCH_RUN_ID"
