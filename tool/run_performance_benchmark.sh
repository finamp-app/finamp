#!/usr/bin/env bash
set -euo pipefail

device_id="${1:-}"
variant="${2:-}"
run_id="${3:-}"
[[ -n "$device_id" ]] || { echo "Usage: $0 <ios-device-id> <variant> <run-id>" >&2; exit 2; }
[[ -n "$variant" ]] || { echo "Usage: $0 <ios-device-id> <variant> <run-id>" >&2; exit 2; }
[[ -n "$run_id" ]] || { echo "Usage: $0 <ios-device-id> <variant> <run-id>" >&2; exit 2; }

timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
out_dir="${FINAMP_BENCH_OUT:-benchmark-results}"
mkdir -p "$out_dir"

raw_log="$out_dir/finamp-benchmark-$timestamp.log"
jsonl="$out_dir/finamp-benchmark-$timestamp.jsonl"
summary_json="$out_dir/finamp-benchmark-$timestamp-summary.json"
summary_md="$out_dir/finamp-benchmark-$timestamp-summary.md"
app_path="build/ios/iphoneos/Runner.app"
remote_stream="Documents/finamp-benchmark-stream-$variant-$run_id.jsonl"
poll_seconds="${FINAMP_BENCH_POLL_SECONDS:-2}"
timeout_seconds="${FINAMP_BENCH_TIMEOUT_SECONDS:-259200}"
smoke_define="${FINAMP_BENCH_SMOKE:-false}"
case "$smoke_define" in
  1|true|TRUE|True|yes|YES|Yes|on|ON|On) smoke_define="true" ;;
  0|false|FALSE|False|no|NO|No|off|OFF|Off|"") smoke_define="false" ;;
  *) echo "FINAMP_BENCH_SMOKE must be true/false, 1/0, yes/no, or on/off" >&2; exit 2 ;;
esac

targeted_download_define="${FINAMP_BENCH_DOWNLOAD_BENCH100_ONLY:-false}"
case "$targeted_download_define" in
  1|true|TRUE|True|yes|YES|Yes|on|ON|On) targeted_download_define="true" ;;
  0|false|FALSE|False|no|NO|No|off|OFF|Off|"") targeted_download_define="false" ;;
  *) echo "FINAMP_BENCH_DOWNLOAD_BENCH100_ONLY must be true/false, 1/0, yes/no, or on/off" >&2; exit 2 ;;
esac

targeted_download_1000_define="${FINAMP_BENCH_DOWNLOAD_BENCH1000_ONLY:-false}"
case "$targeted_download_1000_define" in
  1|true|TRUE|True|yes|YES|Yes|on|ON|On) targeted_download_1000_define="true" ;;
  0|false|FALSE|False|no|NO|No|off|OFF|Off|"") targeted_download_1000_define="false" ;;
  *) echo "FINAMP_BENCH_DOWNLOAD_BENCH1000_ONLY must be true/false, 1/0, yes/no, or on/off" >&2; exit 2 ;;
esac
if [[ "$targeted_download_define" == "true" && "$targeted_download_1000_define" == "true" ]]; then
  echo "FINAMP_BENCH_DOWNLOAD_BENCH100_ONLY and FINAMP_BENCH_DOWNLOAD_BENCH1000_ONLY are mutually exclusive" >&2
  exit 2
fi
if [[ "$smoke_define" == "true" && ( "$targeted_download_define" == "true" || "$targeted_download_1000_define" == "true" ) ]]; then
  echo "Targeted download diagnostics and FINAMP_BENCH_SMOKE are mutually exclusive" >&2
  exit 2
fi

search_query_1="${FINAMP_BENCH_SEARCH_QUERY_1:-}"
search_query_2="${FINAMP_BENCH_SEARCH_QUERY_2:-}"
search_query_3="${FINAMP_BENCH_SEARCH_QUERY_3:-}"
if [[ "$targeted_download_define" == "false" && "$targeted_download_1000_define" == "false" ]]; then
  [[ -n "$search_query_1" ]] || {
    echo "FINAMP_BENCH_SEARCH_QUERY_1 must be set locally for smoke/full benchmark runs" >&2
    exit 2
  }
  if [[ "$smoke_define" == "false" ]]; then
    [[ -n "$search_query_2" ]] || {
      echo "FINAMP_BENCH_SEARCH_QUERY_2 must be set locally for a full benchmark run" >&2
      exit 2
    }
    [[ -n "$search_query_3" ]] || {
      echo "FINAMP_BENCH_SEARCH_QUERY_3 must be set locally for a full benchmark run" >&2
      exit 2
    }
  fi
fi

log() {
  printf '%s\n' "$*" | tee -a "$raw_log"
}

generate_summary() {
  if [[ ! -s "$jsonl" ]]; then
    log "No benchmark JSONL available for summary."
    return 0
  fi

  log "Generating benchmark summary..."
  if python3 tool/summarize_performance_benchmark.py \
    "$jsonl" \
    --json-out "$summary_json" \
    --md-out "$summary_md"; then
    log "Summary JSON: $summary_json"
    log "Summary Markdown: $summary_md"
  else
    log "WARNING: Summary generation failed; raw JSONL remains at $jsonl"
  fi
}

printf 'Full log: %s\nBenchmark JSONL: %s\n' "$raw_log" "$jsonl"
: > "$raw_log"
: > "$jsonl"

log ""
log "==> Building PROFILE app with benchmark mode enabled"
if [[ "$targeted_download_1000_define" == "true" ]]; then
  log "Benchmark suite mode: targeted bench-1000 download diagnostics"
elif [[ "$targeted_download_define" == "true" ]]; then
  log "Benchmark suite mode: targeted bench-100 download diagnostics"
elif [[ "$smoke_define" == "true" ]]; then
  log "Benchmark suite mode: smoke"
else
  log "Benchmark suite mode: full"
fi
flutter build ios \
  --profile \
  --dart-define=FINAMP_PERFORMANCE_BENCHMARK=true \
  --dart-define=FINAMP_BENCH_SMOKE="$smoke_define" \
  --dart-define=FINAMP_BENCH_DOWNLOAD_BENCH100_ONLY="$targeted_download_define" \
  --dart-define=FINAMP_BENCH_DOWNLOAD_BENCH1000_ONLY="$targeted_download_1000_define" \
  --dart-define=FINAMP_BENCH_SEARCH_QUERY_1="$search_query_1" \
  --dart-define=FINAMP_BENCH_SEARCH_QUERY_2="$search_query_2" \
  --dart-define=FINAMP_BENCH_SEARCH_QUERY_3="$search_query_3" \
  --dart-define=FINAMP_BENCH_VARIANT="$variant" \
  --dart-define=FINAMP_BENCH_RUN_ID="$run_id" 2>&1 | tee -a "$raw_log"

[[ -d "$app_path" ]] || {
  log "ERROR: Built app not found at $app_path"
  exit 1
}

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
[[ -n "$bundle_id" ]] || {
  log "ERROR: Could not determine CFBundleIdentifier from built app"
  exit 1
}

production_bundle_id="com.unicornsonlsd.finamp-ios"
allow_production_bundle="${FINAMP_BENCH_ALLOW_PRODUCTION_BUNDLE:-false}"
if [[ "$bundle_id" == "$production_bundle_id" ]]; then
  case "$allow_production_bundle" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On)
      log "WARNING: Explicit override allows benchmark installation over the normal Finamp bundle."
      ;;
    *)
      log "ERROR: Refusing to install the destructive benchmark over the normal Finamp bundle ($production_bundle_id)."
      log "Use a separate local benchmark bundle identifier. Only if replacement is intentional, set FINAMP_BENCH_ALLOW_PRODUCTION_BUNDLE=true."
      exit 2
      ;;
  esac
fi

log ""
log "==> Installing $bundle_id on device $device_id"
xcrun devicectl device install app   --device "$device_id"   "$app_path" 2>&1 | tee -a "$raw_log"

log ""
log "==> Launching app without console attachment"
xcrun devicectl device process launch   --device "$device_id"   --terminate-existing   "$bundle_id" 2>&1 | tee -a "$raw_log"

log ""
log "==> Polling benchmark JSONL from app container"
log "No Flutter mDNS, Dart VM service or devicectl --console attachment is used."
log "The app may remain open while the Mac copies benchmark checkpoints every ${poll_seconds}s."
log "Timeout: ${timeout_seconds}s"

pull_root="$(mktemp -d)"

cleanup() {
  rm -rf "$pull_root"
}

interrupt_benchmark() {
  local exit_code="$1"
  log "Benchmark interrupted by host signal."
  generate_summary
  exit "$exit_code"
}

trap cleanup EXIT
trap 'interrupt_benchmark 130' INT
trap 'interrupt_benchmark 143' TERM

start_epoch="$(date +%s)"
last_size=-1
handled_planned_restarts=0
recovery_restarts=0
max_recovery_restarts="${FINAMP_BENCH_MAX_RECOVERY_RESTARTS:-3}"
heartbeat_stall_seconds="${FINAMP_BENCH_HEARTBEAT_STALL_SECONDS:-600}"
benchmark_started=0
last_stream_change_epoch="$(date +%s)"
last_progress_signature=""

print_progress() {
  local progress
  progress="$(python3 - "$jsonl" <<'PY'
import json
import os
import sys

path = sys.argv[1]
last = None
window = 2 * 1024 * 1024

with open(path, "rb") as handle:
    size = os.fstat(handle.fileno()).st_size
    start = max(0, size - window)
    handle.seek(start)
    data = handle.read()

if start > 0:
    newline = data.find(b"\n")
    data = data[newline + 1:] if newline >= 0 else b""

for raw in data.decode("utf-8", errors="ignore").splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        record = json.loads(raw)
    except Exception:
        continue

    kind = record.get("type")
    if kind == "run-start":
        run = record.get("run") or {}
        last = (
            "RUN",
            run.get("scenario", ""),
            run.get("mode", ""),
            run.get("targetAlias") or run.get("targetType") or "",
        )
    elif kind == "run-end":
        run = record.get("run") or {}
        last = (
            "DONE",
            run.get("scenario", ""),
            run.get("mode", ""),
            run.get("result", ""),
        )
    elif kind == "diagnostic":
        name = record.get("name")
        values = record.get("values") or {}
        if name == "suite-phase-complete":
            last = ("PHASE", values.get("phase", ""), "", "")
        elif name == "host-restart-requested":
            last = (
                "RESTART",
                values.get("reason", ""),
                values.get("nextStage", ""),
                "",
            )
        elif name == "startup-fully-ready":
            last = ("STARTUP", values.get("phase", ""), "", "")

if last is not None:
    print("|".join(str(x) for x in last))
PY
)"
  if [[ -n "$progress" && "$progress" != "$last_progress_signature" ]]; then
    last_progress_signature="$progress"
    IFS='|' read -r kind first second third <<< "$progress"
    case "$kind" in
      RUN)
        if [[ -n "$third" ]]; then
          log "Progress: running $first [$second] target=$third"
        else
          log "Progress: running $first [$second]"
        fi
        ;;
      DONE)
        log "Progress: finished $first [$second] result=$third"
        ;;
      PHASE)
        log "Progress: phase complete: $first"
        ;;
      RESTART)
        log "Progress: restart requested: $first -> $second"
        ;;
      STARTUP)
        log "Progress: startup ready: $first"
        ;;
    esac
  fi
}


while true; do
  now_epoch="$(date +%s)"
  elapsed="$((now_epoch - start_epoch))"
  if (( elapsed >= timeout_seconds )); then
    log "ERROR: Benchmark timed out after ${timeout_seconds}s."
    generate_summary
    exit 124
  fi

  pulled_file="$pull_root/finamp-benchmark-stream-$variant-$run_id.jsonl"
  rm -f "$pulled_file"

  set +e
  xcrun devicectl device copy from \
    --device "$device_id" \
    --domain-type appDataContainer \
    --domain-identifier "$bundle_id" \
    --source "$remote_stream" \
    --destination "$pulled_file" \
    >"$pull_root/copy.out" 2>"$pull_root/copy.err"
  copy_status=$?
  set -e

  if [[ "$copy_status" -eq 0 && -f "$pulled_file" ]]; then
    delta_file="$pull_root/delta.jsonl"
    : > "$delta_file"

    set +e
    merge_output="$(python3 - "$jsonl" "$pulled_file" "$delta_file" <<'PY'
import os
import sys

local_path, remote_path, delta_path = sys.argv[1:4]
with open(local_path, "rb") as handle:
    local = handle.read()
with open(remote_path, "rb") as handle:
    remote = handle.read()

if len(remote) < len(local):
    print(f"shorter:{len(remote)}:{len(local)}")
    raise SystemExit(10)

if not remote.startswith(local):
    print(f"diverged:{len(remote)}:{len(local)}")
    raise SystemExit(11)

suffix = remote[len(local):]
if suffix:
    with open(local_path, "ab") as handle:
        handle.write(suffix)
    with open(delta_path, "wb") as handle:
        handle.write(suffix)

print(f"ok:{len(remote)}:{len(suffix)}")
PY
)"
    merge_status=$?
    set -e

    if [[ "$merge_status" -eq 10 ]]; then
      log "Ignoring shorter transient benchmark snapshot: $merge_output"
      sleep "$poll_seconds"
      continue
    elif [[ "$merge_status" -eq 11 ]]; then
      log "ERROR: Device benchmark stream diverged from the append-only host copy: $merge_output"
      generate_summary
      exit 126
    elif [[ "$merge_status" -ne 0 ]]; then
      log "ERROR: Could not merge benchmark stream: $merge_output"
      generate_summary
      exit 127
    fi

    size="$(wc -c < "$jsonl" | tr -d ' ')"
    if [[ "$size" != "$last_size" ]]; then
      log "Pulled benchmark stream: ${size} bytes"
      last_size="$size"
      last_stream_change_epoch="$(date +%s)"
      if (( size > 0 )); then
        benchmark_started=1
      fi
      print_progress
    fi

    if [[ -s "$delta_file" ]]; then
      if grep -q '"name":"suite-authenticated"' "$delta_file" ||
         grep -q '"name":"startup-baseline-complete"' "$delta_file"; then
        benchmark_started=1
      fi

      new_planned_restarts="$(grep -c '"name":"host-restart-requested"' "$delta_file" || true)"
      if (( new_planned_restarts > 0 )); then
        handled_planned_restarts="$((handled_planned_restarts + new_planned_restarts))"
        log ""
        log "==> Full suite requested planned process restart #$handled_planned_restarts"
        log "Relaunching the installed app with the same auth/settings/container..."
        xcrun devicectl device process launch \
          --device "$device_id" \
          --terminate-existing \
          "$bundle_id" 2>&1 | tee -a "$raw_log"
        benchmark_started=1
        last_stream_change_epoch="$(date +%s)"
        sleep 5
      fi

      if grep -q '"name":"targeted-download-complete"' "$delta_file"; then
        target_alias="$(grep '"name":"targeted-download-complete"' "$delta_file" | tail -1 | sed -n 's/.*"targetAlias":"\([^"]*\)".*/\1/p')"
        log "==> Targeted ${target_alias:-download} diagnostics completed"
        generate_summary
        exit 0
      fi
      if grep -q '"name":"suite-complete"' "$delta_file"; then
        log "==> Benchmark suite completed"
        generate_summary
        exit 0
      fi
      if grep -q '"name":"suite-blocked"' "$delta_file"; then
        log "ERROR: Benchmark suite blocked; inspect $jsonl"
        generate_summary
        exit 3
      fi
      if grep -q '"name":"suite-error"' "$delta_file"; then
        log "ERROR: Benchmark suite reported an error; inspect $jsonl"
        generate_summary
        exit 4
      fi
    fi
  else
    if [[ "$last_size" -lt 0 ]]; then
      copy_error="$(tr '\n' ' ' < "$pull_root/copy.err" | sed 's/[[:space:]]\+/ /g' | cut -c1-500)"
      if [[ -n "$copy_error" ]]; then
        log "Waiting for benchmark stream: $copy_error"
      else
        log "Waiting for benchmark stream: devicectl copy exited with status $copy_status"
      fi
      last_size=-2
    fi
  fi

  if [[ "$benchmark_started" -eq 1 ]]; then
    now_epoch="$(date +%s)"
    silent_seconds="$((now_epoch - last_stream_change_epoch))"
    if (( silent_seconds >= heartbeat_stall_seconds )); then
      if (( recovery_restarts >= max_recovery_restarts )); then
        log "ERROR: Benchmark heartbeat stalled for ${silent_seconds}s and recovery restart limit was reached."
        generate_summary
        exit 125
      fi
      recovery_restarts="$((recovery_restarts + 1))"
      log ""
      log "==> Benchmark heartbeat stalled for ${silent_seconds}s"
      log "Recovery relaunch ${recovery_restarts}/${max_recovery_restarts}..."
      xcrun devicectl device process launch \
        --device "$device_id" \
        --terminate-existing \
        "$bundle_id" 2>&1 | tee -a "$raw_log"
      last_stream_change_epoch="$(date +%s)"
      sleep 5
    fi
  fi

  sleep "$poll_seconds"
done
