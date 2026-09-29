#!/usr/bin/env python3
import argparse
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


def p90(values):
    if not values:
        return None
    ordered = sorted(values)
    idx = max(0, math.ceil(0.90 * len(ordered)) - 1)
    return ordered[idx]


def ms(value):
    return round(value / 1000.0, 3)


def cardinality_bucket(value):
    if not isinstance(value, (int, float)):
        return None
    value = int(value)
    if value <= 0:
        return "0"
    if value < 100:
        return "1-99"
    if value < 1000:
        return "100-999"
    if value < 5000:
        return "1000-4999"
    if value < 10000:
        return "5000-9999"
    return "10000+"


PUBLIC_EVENT_DENYLIST = {
    # Repeated page-request milestones expose internal list-growth structure and
    # are stripped from new host JSONL. Keep legacy JSONL summaries consistent.
    "alphabet-jump-page-requested",
}


PUBLIC_NUMERIC_METRIC_DENYLIST = {
    # Combined with known page size, this can approximate private library
    # cardinality for late alphabet targets such as Z.
    "alphabetJumpPagesLoaded",

    # Target discovery needs these internally, but publishing them would expose
    # playlist cardinality or a tight approximation of it.
    "playlistItemsSeen",
    "playlistPagesFetched",

    # Deep paging can reach the terminal page. Together with the requested
    # page ordinal/size these counters can reveal an exact private collection
    # cardinality, so keep them out of public summaries even for older JSONL.
    "loadedItems",
    "itemsAdded",
    "pageItemsAdded",
    "pageSize",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("jsonl")
    parser.add_argument("--json-out", required=True)
    parser.add_argument("--md-out", required=True)
    args = parser.parse_args()

    source = Path(args.jsonl)
    groups = defaultdict(list)
    startup_tasks = defaultdict(list)
    queue_restores = []
    queue_restore_content = []
    startup_network = []
    startup_phase_results = []
    startup_frames = []
    startup_image_cache = []
    phase_memory = []
    network_target_events = []
    recovered_runs = []
    runtime_environments = []
    phases = []
    diagnostics = []

    for raw in source.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        try:
            record = json.loads(raw)
        except json.JSONDecodeError:
            continue

        if record.get("type") in {"run-end", "run-recovered"}:
            run = record.get("run") or {}
            if record.get("type") == "run-recovered":
                recovered_runs.append({
                    "scenario": run.get("scenario"),
                    "mode": run.get("mode"),
                    "targetType": run.get("targetType"),
                    "targetAlias": run.get("targetAlias"),
                    "lastStep": run.get("lastStep"),
                    "result": run.get("result"),
                })
            key = (
                run.get("scenario", "unknown"),
                run.get("mode", "unknown"),
                run.get("targetType"),
                run.get("targetAlias"),
            )
            groups[key].append(run)
        elif record.get("type") == "diagnostic":
            name = record.get("name")
            values = record.get("values") or {}
            if name == "startup-task-complete":
                duration = values.get("durationMs")
                task = values.get("task")
                if isinstance(duration, (int, float)) and isinstance(task, str):
                    startup_tasks[task].append(float(duration))
            elif name in {
                "queue-restore-complete",
                "queue-restore-explicit-complete",
            }:
                queue_restores.append({
                    "mode": (
                        "startup-autoload"
                        if name == "queue-restore-complete"
                        else "explicit-after-restart"
                    ),
                    "storedTrackCount": values.get("storedTrackCount"),
                    "restoredTrackCount": values.get("restoredTrackCount"),
                    "durationMs": values.get("durationMs"),
                    "emittedAt": record.get("emittedAt"),
                })
            elif name == "queue-restore-content-resolved":
                queue_restore_content.append({
                    "storedTrackCount": values.get("storedTrackCount"),
                    "loadedTrackCount": values.get("loadedTrackCount"),
                    "droppedTrackCount": values.get("droppedTrackCount"),
                    "emittedAt": record.get("emittedAt"),
                })
            elif name == "startup-network-summary":
                startup_network.append({
                    "phase": values.get("phase"),
                    "requestCount": values.get("requestCount"),
                    "responseBytes": values.get("responseBytes"),
                    "durationMicrosTotal": values.get("durationMicrosTotal"),
                    "durationMicrosMax": values.get("durationMicrosMax"),
                    "workerOperationCount": values.get("workerOperationCount"),
                    "workerOperationFailed": values.get("workerOperationFailed"),
                    "workerDurationMicrosTotal": values.get("workerDurationMicrosTotal"),
                    "workerDurationMicrosMax": values.get("workerDurationMicrosMax"),
                    "emittedAt": record.get("emittedAt"),
                })
            elif name == "startup-phase-result":
                startup_phase_results.append({
                    "phase": values.get("phase"),
                    "fullyReadyMs": values.get("fullyReadyMs"),
                    "nativeFullyReadyMs": values.get("nativeFullyReadyMs"),
                    "nativeToDartMainMs": values.get("nativeToDartMainMs"),
                    "requestCount": values.get("requestCount"),
                    "responseBytes": values.get("responseBytes"),
                    "httpDurationMicrosTotal": values.get("httpDurationMicrosTotal"),
                    "httpDurationMicrosMax": values.get("httpDurationMicrosMax"),
                    "workerOperationCount": values.get("workerOperationCount"),
                    "workerOperationFailed": values.get("workerOperationFailed"),
                    "workerDurationMicrosTotal": values.get("workerDurationMicrosTotal"),
                    "workerDurationMicrosMax": values.get("workerDurationMicrosMax"),
                    "frameCount": values.get("frameCount"),
                    "framesOver16_7ms": values.get("framesOver16_7ms"),
                    "framesOver33_3ms": values.get("framesOver33_3ms"),
                    "framesOver50ms": values.get("framesOver50ms"),
                    "frameMicrosMax": values.get("frameMicrosMax"),
                    "imageLoadStarted": values.get("imageLoadStarted"),
                    "imageLoadCompleted": values.get("imageLoadCompleted"),
                    "imageLoadFailed": values.get("imageLoadFailed"),
                    "imageMaxConcurrentLoads": values.get("imageMaxConcurrentLoads"),
                    "rssBytes": values.get("rssBytes"),
                    "maxRssBytes": values.get("maxRssBytes"),
                    "emittedAt": record.get("emittedAt"),
                })
            elif name == "startup-frame-summary":
                startup_frames.append({
                    "phase": values.get("phase"),
                    "frameCount": values.get("frameCount"),
                    "framesOver16_7ms": values.get("framesOver16_7ms"),
                    "framesOver33_3ms": values.get("framesOver33_3ms"),
                    "framesOver50ms": values.get("framesOver50ms"),
                    "buildMicrosMax": values.get("buildMicrosMax"),
                    "rasterMicrosMax": values.get("rasterMicrosMax"),
                    "frameMicrosMax": values.get("frameMicrosMax"),
                    "imageLoadStarted": values.get("imageLoadStarted"),
                    "imageLoadCompleted": values.get("imageLoadCompleted"),
                    "imageLoadFailed": values.get("imageLoadFailed"),
                    "imageLoadSynchronous": values.get("imageLoadSynchronous"),
                    "imageMaxConcurrentLoads": values.get("imageMaxConcurrentLoads"),
                    "rssBytes": values.get("rssBytes"),
                    "maxRssBytes": values.get("maxRssBytes"),
                    "processElapsedMs": values.get("processElapsedMs"),
                    "emittedAt": record.get("emittedAt"),
                })
            elif name == "startup-image-cache-index-loaded":
                startup_image_cache.append({
                    "persistentEntryBucket": cardinality_bucket(
                        values.get("persistentEntryCount")
                    ),
                    "mappedPlayerEntryBucket": cardinality_bucket(
                        values.get("mappedPlayerEntries")
                    ),
                    "emittedAt": record.get("emittedAt"),
                })
            elif name in {
                "network-target-ping",
                "network-target-state-changed",
                "network-target-changed",
            }:
                network_target_events.append({
                    "name": name,
                    "values": values,
                    "emittedAt": record.get("emittedAt"),
                })
            elif name == "runtime-environment":
                environment = {
                    "operatingSystem": values.get("operatingSystem"),
                    "operatingSystemVersion": values.get("operatingSystemVersion"),
                    "dartVersion": values.get("dartVersion"),
                    "processorCount": values.get("processorCount"),
                    "variant": values.get("variant"),
                }
                if environment not in runtime_environments:
                    runtime_environments.append(environment)
            elif name == "suite-phase-complete":
                phase = values.get("phase")
                if phase:
                    phases.append(phase)
                    phase_memory.append({
                        "phase": phase,
                        "rssBytes": values.get("rssBytes"),
                        "maxRssBytes": values.get("maxRssBytes"),
                        "processElapsedMs": values.get("processElapsedMs"),
                    })
            elif name == "suite-complete":
                phase_memory.append({
                    "phase": "suite-complete",
                    "rssBytes": values.get("rssBytes"),
                    "maxRssBytes": values.get("maxRssBytes"),
                    "processElapsedMs": values.get("processElapsedMs"),
                })
                diagnostics.append({
                    "name": name,
                    "emittedAt": record.get("emittedAt"),
                    "values": values,
                })
            elif name in {
                "startup-main-init-complete",
                "startup-first-frame",
                "startup-screen-first-rendered-content",
                "startup-quiescent",
                "image-loads-quiescent",
                "network-quiescent",
                "startup-fully-ready",
                "startup-baseline-complete",
                "startup-playlist-metadata-plan-start",
                "startup-playlist-metadata-plan-complete",
                "startup-playlist-metadata-settle-start",
                "startup-playlist-metadata-settle-complete",
                "host-restart-requested",
            }:
                diagnostics.append({
                    "name": name,
                    "emittedAt": record.get("emittedAt"),
                    "values": values,
                })

    summary_groups = []
    for key, runs in sorted(groups.items(), key=lambda x: tuple("" if v is None else str(v) for v in x[0])):
        durations = [
            int(run.get("durationMicros", 0))
            for run in runs
            if isinstance(run.get("durationMicros"), int)
        ]
        results = defaultdict(int)
        for run in runs:
            results[str(run.get("result", "unknown"))] += 1

        numeric_metrics = defaultdict(list)
        categorical_metrics = defaultdict(list)
        event_elapsed = defaultdict(list)
        playback_sources = defaultdict(int)
        for run in runs:
            run_metrics = run.get("metrics") or {}
            for metric_name, metric_value in run_metrics.items():
                if metric_name in PUBLIC_NUMERIC_METRIC_DENYLIST:
                    continue
                if isinstance(metric_value, (int, float)) and not isinstance(metric_value, bool):
                    numeric_metrics[metric_name].append(float(metric_value))
                elif isinstance(metric_value, str) and metric_name.endswith("Bucket"):
                    categorical_metrics[metric_name].append(metric_value)

            if str(run.get("scenario", "")).startswith("collection-page-"):
                worker_us = run_metrics.get("workerDurationMicrosTotal")
                http_us = run_metrics.get("httpDurationMicrosTotal")
                if (
                    isinstance(worker_us, (int, float))
                    and not isinstance(worker_us, bool)
                    and isinstance(http_us, (int, float))
                    and not isinstance(http_us, bool)
                ):
                    numeric_metrics["apiNonHttpMicrosApprox"].append(
                        float(max(0, worker_us - http_us))
                    )
            for event in run.get("events") or []:
                event_name = event.get("name")
                if event_name in PUBLIC_EVENT_DENYLIST:
                    continue
                elapsed = event.get("elapsedMicros")
                if isinstance(event_name, str) and isinstance(elapsed, int):
                    event_elapsed[event_name].append(elapsed)
                if event_name == "playback-source-selected":
                    values = event.get("values") or {}
                    playback_source = str(values.get("source", "unknown"))
                    server_target = values.get("serverTarget")
                    transcoded = bool(values.get("transcoded", False))
                    offline = bool(values.get("offline", False))
                    label = playback_source
                    if server_target is not None:
                        label += f"/{server_target}"
                    if transcoded:
                        label += "/transcoded"
                    if offline:
                        label += "/offline"
                    playback_sources[label] += 1

        metric_summary = {
            metric_name: {
                "median": statistics.median(values),
                "p90": p90(values),
                "min": min(values),
                "max": max(values),
            }
            for metric_name, values in sorted(numeric_metrics.items())
            if values
        }

        categorical_summary = {
            metric_name: dict(
                sorted(
                    {
                        value: values.count(value)
                        for value in set(values)
                    }.items()
                )
            )
            for metric_name, values in sorted(categorical_metrics.items())
            if values
        }

        event_summary = {
            event_name: {
                "medianMsFromRunStart": ms(statistics.median(values)),
                "p90MsFromRunStart": ms(p90(values)),
                "minMsFromRunStart": ms(min(values)),
                "maxMsFromRunStart": ms(max(values)),
            }
            for event_name, values in sorted(event_elapsed.items())
            if values
        }

        summary_groups.append({
            "scenario": key[0],
            "mode": key[1],
            "targetType": key[2],
            "targetAlias": key[3],
            "runs": len(runs),
            "medianMs": ms(statistics.median(durations)) if durations else None,
            "p90Ms": ms(p90(durations)) if durations else None,
            "minMs": ms(min(durations)) if durations else None,
            "maxMs": ms(max(durations)) if durations else None,
            "results": dict(results),
            "numericMetrics": metric_summary,
            "categoricalMetrics": categorical_summary,
            "eventMilestones": event_summary,
            "playbackSources": dict(playback_sources),
        })

    startup_summary = []
    for task, durations in sorted(startup_tasks.items()):
        startup_summary.append({
            "task": task,
            "runs": len(durations),
            "medianMs": round(statistics.median(durations), 3),
            "p90Ms": round(p90(durations), 3),
            "minMs": round(min(durations), 3),
            "maxMs": round(max(durations), 3),
        })

    startup_phase_grouped = []
    startup_phase_groups = defaultdict(list)
    for item in startup_phase_results:
        phase = item.get("phase") or "unknown"
        if phase.startswith("persistent-cache-startup-repeat-"):
            phase = "persistent-cache-startup"
        startup_phase_groups[phase].append(item)

    for phase, items in sorted(startup_phase_groups.items()):
        def numeric_values(key):
            return [
                float(item[key])
                for item in items
                if isinstance(item.get(key), (int, float))
                and not isinstance(item.get(key), bool)
            ]

        ready = numeric_values("fullyReadyMs")
        native_ready = numeric_values("nativeFullyReadyMs")
        native_to_dart = numeric_values("nativeToDartMainMs")
        requests = numeric_values("requestCount")
        http_total = numeric_values("httpDurationMicrosTotal")
        worker_total = numeric_values("workerDurationMicrosTotal")
        frames_50 = numeric_values("framesOver50ms")
        frame_max = numeric_values("frameMicrosMax")
        images = numeric_values("imageLoadStarted")
        rss = numeric_values("rssBytes")

        startup_phase_grouped.append({
            "phase": phase,
            "runs": len(items),
            "fullyReadyMedianMs": statistics.median(ready) if ready else None,
            "fullyReadyP90Ms": p90(ready) if ready else None,
            "nativeFullyReadyMedianMs": (
                statistics.median(native_ready) if native_ready else None
            ),
            "nativeFullyReadyP90Ms": p90(native_ready) if native_ready else None,
            "nativeToDartMainMedianMs": (
                statistics.median(native_to_dart)
                if native_to_dart else None
            ),
            "requestMedian": statistics.median(requests) if requests else None,
            "httpTotalMedianMs": (
                statistics.median(http_total) / 1000.0
                if http_total else None
            ),
            "workerTotalMedianMs": (
                statistics.median(worker_total) / 1000.0
                if worker_total else None
            ),
            "framesOver50Median": (
                statistics.median(frames_50) if frames_50 else None
            ),
            "frameMaxMedianMs": (
                statistics.median(frame_max) / 1000.0
                if frame_max else None
            ),
            "imageLoadMedian": statistics.median(images) if images else None,
            "rssMedianMiB": (
                statistics.median(rss) / (1024 * 1024)
                if rss else None
            ),
        })

    output = {
        "source": source.name,
        "completedPhases": phases,
        "startupTasks": startup_summary,
        "startupNetwork": startup_network,
        "startupPhaseResults": startup_phase_results,
        "startupPhaseGroups": startup_phase_grouped,
        "startupFrames": startup_frames,
        "startupImageCache": startup_image_cache,
        "phaseMemory": phase_memory,
        "networkTargetEvents": network_target_events,
        "queueRestores": queue_restores,
        "queueRestoreContent": queue_restore_content,
        "recoveredRuns": recovered_runs,
        "runtimeEnvironments": runtime_environments,
        "groups": summary_groups,
        "milestones": diagnostics,
    }
    Path(args.json_out).write_text(
        json.dumps(output, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# Finamp performance benchmark summary",
        "",
        f"Source: `{source.name}`",
        "",
        "## Completed phases",
        "",
    ]
    lines.extend(f"- {phase}" for phase in phases)
    if not phases:
        lines.append("- none recorded")

    lines.extend([
        "",
        "## Runtime environment",
        "",
        "| OS | OS version | Dart runtime | Processors | Variant |",
        "|---|---|---|---:|---|",
    ])
    if runtime_environments:
        for item in runtime_environments:
            dart_version = str(item.get("dartVersion") or "").replace("\n", " ")
            lines.append(
                f"| {item.get('operatingSystem', '')} | "
                f"{item.get('operatingSystemVersion', '')} | "
                f"{dart_version} | {item.get('processorCount', '')} | "
                f"{item.get('variant', '')} |"
            )
    else:
        lines.append("|  |  |  |  |  |")

    lines.extend([
        "",
        "## Startup tasks",
        "",
        "| Task | Runs | Median ms | p90 ms | Min ms | Max ms |",
        "|---|---:|---:|---:|---:|---:|",
    ])
    for item in startup_summary:
        lines.append(
            f"| {item['task']} | {item['runs']} | {item['medianMs']:.3f} | "
            f"{item['p90Ms']:.3f} | {item['minMs']:.3f} | {item['maxMs']:.3f} |"
        )

    startup_timeline = []
    for item in diagnostics:
        values = item.get("values") or {}
        elapsed = values.get("processElapsedMs")
        if isinstance(elapsed, (int, float)):
            startup_timeline.append({
                "name": item.get("name"),
                "processElapsedMs": float(elapsed),
                "nativeLaunchElapsedMs": (
                    float(values["nativeLaunchElapsedMs"])
                    if isinstance(values.get("nativeLaunchElapsedMs"), (int, float))
                    else None
                ),
                "nativeToDartMainMs": (
                    float(values["nativeToDartMainMs"])
                    if isinstance(values.get("nativeToDartMainMs"), (int, float))
                    else None
                ),
                "phase": values.get("phase"),
                "contentType": values.get("contentType"),
            })
    startup_timeline.sort(key=lambda item: item["processElapsedMs"])

    ready_events = [
        item for item in diagnostics
        if item.get("name") == "startup-fully-ready"
    ]
    lines.extend([
        "",
        "## Startup timeline",
        "",
        "| Milestone | Phase/content | Dart-main elapsed ms | Native-launch elapsed ms | Native -> Dart main ms |",
        "|---|---|---:|---:|---:|",
    ])
    if startup_timeline:
        for item in startup_timeline:
            context = item.get("phase") or item.get("contentType") or ""
            lines.append(
                f"| {item.get('name', '')} | {context} | "
                f"{item.get('processElapsedMs', ''):.3f} | "
                f"{'' if item.get('nativeLaunchElapsedMs') is None else round(item['nativeLaunchElapsedMs'], 3)} | "
                f"{'' if item.get('nativeToDartMainMs') is None else round(item['nativeToDartMainMs'], 3)} |"
            )
    else:
        lines.append("|  |  |  |  |  |")

    lines.extend([
        "",
        "## Startup fully ready",
        "",
        "| Phase | Dart-main elapsed ms | Native-launch elapsed ms |",
        "|---|---:|---:|",
    ])
    if ready_events:
        for item in ready_events:
            values = item.get("values") or {}
            native_elapsed = values.get("nativeLaunchElapsedMs")
            lines.append(
                f"| {values.get('phase', '')} | {values.get('processElapsedMs', '')} | "
                f"{'' if not isinstance(native_elapsed, (int, float)) else round(native_elapsed, 3)} |"
            )
    else:
        lines.append("|  |  |  |")

    lines.extend([
        "",
        "## Startup phase comparison",
        "",
        "| Phase | Runs | Dart ready med ms | Dart p90 ms | Native ready med ms | Native p90 ms | Native -> Dart main med ms | Requests med | HTTP total med ms | Worker total med ms | >50ms frames med | Max frame med ms | Image loads med | RSS med MiB |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ])
    if startup_phase_grouped:
        for item in startup_phase_grouped:
            def fmt(value):
                return "" if value is None else round(value, 3)

            lines.append(
                f"| {item['phase']} | {item['runs']} | "
                f"{fmt(item['fullyReadyMedianMs'])} | "
                f"{fmt(item['fullyReadyP90Ms'])} | "
                f"{fmt(item['nativeFullyReadyMedianMs'])} | "
                f"{fmt(item['nativeFullyReadyP90Ms'])} | "
                f"{fmt(item['nativeToDartMainMedianMs'])} | "
                f"{fmt(item['requestMedian'])} | "
                f"{fmt(item['httpTotalMedianMs'])} | "
                f"{fmt(item['workerTotalMedianMs'])} | "
                f"{fmt(item['framesOver50Median'])} | "
                f"{fmt(item['frameMaxMedianMs'])} | "
                f"{fmt(item['imageLoadMedian'])} | "
                f"{fmt(item['rssMedianMiB'])} |"
            )
    else:
        lines.append("|  |  |  |  |  |  |  |  |  |  |  |  |  |  |")

    lines.extend([
        "",
        "## Startup network",
        "",
        "| Phase | Requests | Response bytes | HTTP total ms | HTTP max ms | Worker ops | Worker failures | Worker total ms | Worker max ms |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ])
    if startup_network:
        for item in startup_network:
            total_us = item.get("durationMicrosTotal")
            max_us = item.get("durationMicrosMax")
            worker_total_us = item.get("workerDurationMicrosTotal")
            worker_max_us = item.get("workerDurationMicrosMax")
            total_ms = "" if not isinstance(total_us, (int, float)) else round(total_us / 1000.0, 3)
            max_ms = "" if not isinstance(max_us, (int, float)) else round(max_us / 1000.0, 3)
            worker_total_ms = "" if not isinstance(worker_total_us, (int, float)) else round(worker_total_us / 1000.0, 3)
            worker_max_ms = "" if not isinstance(worker_max_us, (int, float)) else round(worker_max_us / 1000.0, 3)
            lines.append(
                f"| {item.get('phase', '')} | {item.get('requestCount', '')} | "
                f"{item.get('responseBytes', '')} | {total_ms} | {max_ms} | "
                f"{item.get('workerOperationCount', '')} | "
                f"{item.get('workerOperationFailed', '')} | "
                f"{worker_total_ms} | {worker_max_ms} |"
            )
    else:
        lines.append("|  |  |  |  |  |  |  |  |  |")

    lines.extend([
        "",
        "## Startup frames and memory",
        "",
        "| Phase | Ready ms | Frames | >16.7 ms | >33.3 ms | >50 ms | Max frame ms | Max build ms | Max raster ms | Image loads | Image failed | Image max concurrent | RSS MiB | Max RSS MiB |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ])
    if startup_frames:
        for item in startup_frames:
            frame_max = item.get("frameMicrosMax")
            build_max = item.get("buildMicrosMax")
            raster_max = item.get("rasterMicrosMax")
            rss = item.get("rssBytes")
            max_rss = item.get("maxRssBytes")
            lines.append(
                f"| {item.get('phase', '')} | {item.get('processElapsedMs', '')} | "
                f"{item.get('frameCount', '')} | {item.get('framesOver16_7ms', '')} | "
                f"{item.get('framesOver33_3ms', '')} | {item.get('framesOver50ms', '')} | "
                f"{'' if not isinstance(frame_max, (int, float)) else round(frame_max / 1000.0, 3)} | "
                f"{'' if not isinstance(build_max, (int, float)) else round(build_max / 1000.0, 3)} | "
                f"{'' if not isinstance(raster_max, (int, float)) else round(raster_max / 1000.0, 3)} | "
                f"{item.get('imageLoadStarted', '')} | "
                f"{item.get('imageLoadFailed', '')} | "
                f"{item.get('imageMaxConcurrentLoads', '')} | "
                f"{'' if not isinstance(rss, (int, float)) else round(rss / (1024 * 1024), 3)} | "
                f"{'' if not isinstance(max_rss, (int, float)) else round(max_rss / (1024 * 1024), 3)} |"
            )
    else:
        lines.append("|  |  |  |  |  |  |  |  |  |  |  |  |  |  |")

    lines.extend([
        "",
        "## Startup persistent image cache",
        "",
        "| Persistent entries (bucket) | Mapped player entries (bucket) |",
        "|---|---|",
    ])
    if startup_image_cache:
        for item in startup_image_cache:
            lines.append(
                f"| {item.get('persistentEntryBucket', '')} | "
                f"{item.get('mappedPlayerEntryBucket', '')} |"
            )
    else:
        lines.append("|  |  |")

    lines.extend([
        "",
        "## Phase memory",
        "",
        "| Phase | RSS MiB | Max RSS MiB | Process elapsed ms |",
        "|---|---:|---:|---:|",
    ])
    if phase_memory:
        for item in phase_memory:
            rss = item.get("rssBytes")
            max_rss = item.get("maxRssBytes")
            elapsed = item.get("processElapsedMs")
            lines.append(
                f"| {item.get('phase', '')} | "
                f"{'' if not isinstance(rss, (int, float)) else round(rss / (1024 * 1024), 3)} | "
                f"{'' if not isinstance(max_rss, (int, float)) else round(max_rss / (1024 * 1024), 3)} | "
                f"{'' if not isinstance(elapsed, (int, float)) else round(elapsed, 3)} |"
            )
    else:
        lines.append("|  |  |  |  |")

    lines.extend([
        "",
        "## Network target diagnostics",
        "",
        "| Event | Target/state | Success | Duration ms |",
        "|---|---|---|---:|",
    ])
    if network_target_events:
        for item in network_target_events:
            values = item.get("values") or {}
            state = values.get("target")
            if state is None and "toLocalTarget" in values:
                state = (
                    "local"
                    if values.get("toLocalTarget")
                    else "public"
                )
            if state is None and (
                values.get("from") is not None
                or values.get("to") is not None
            ):
                state = f"{values.get('from', '')} -> {values.get('to', '')}"
            lines.append(
                f"| {item.get('name', '')} | {state or ''} | "
                f"{values.get('success', '')} | {values.get('durationMs', '')} |"
            )
    else:
        lines.append("| none observed |  |  |  |")

    lines.extend([
        "",
        "## Queue restore",
        "",
        "| Mode | Stored tracks | Restored tracks | Duration ms | Loaded tracks | Dropped tracks |",
        "|---|---:|---:|---:|---:|---:|",
    ])
    if queue_restores or queue_restore_content:
        row_count = max(len(queue_restores), len(queue_restore_content))
        for index in range(row_count):
            timing = queue_restores[index] if index < len(queue_restores) else {}
            content = (
                queue_restore_content[index]
                if index < len(queue_restore_content)
                else {}
            )
            stored = timing.get(
                "storedTrackCount",
                content.get("storedTrackCount", ""),
            )
            lines.append(
                f"| {timing.get('mode', '')} | {stored} | "
                f"{timing.get('restoredTrackCount', '')} | "
                f"{timing.get('durationMs', '')} | "
                f"{content.get('loadedTrackCount', '')} | "
                f"{content.get('droppedTrackCount', '')} |"
            )
    else:
        lines.append("|  |  |  |  |  |  |")

    lines.extend([
        "",
        "## Scenario groups",
        "",
        "| Scenario | Mode | Target | Runs | Median ms | p90 ms | HTTP req med | HTTP total ms med | Worker ops med | Worker total ms med | HTTP max ms med | Bytes med | RSS Δ MiB med | >50ms frames med | Results |",
        "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ])
    for item in summary_groups:
        target = item["targetAlias"] or item["targetType"] or ""
        results = ", ".join(
            f"{name}:{count}" for name, count in sorted(item["results"].items())
        )
        median = "" if item["medianMs"] is None else f"{item['medianMs']:.3f}"
        p90_value = "" if item["p90Ms"] is None else f"{item['p90Ms']:.3f}"
        metrics = item.get("numericMetrics") or {}
        http_requests = metrics.get("httpRequestCount", {}).get("median", "")
        http_total_us = metrics.get("httpDurationMicrosTotal", {}).get("median")
        worker_ops = metrics.get("workerOperationCount", {}).get("median", "")
        worker_total_us = metrics.get("workerDurationMicrosTotal", {}).get("median")
        http_max_us = metrics.get("httpDurationMicrosMax", {}).get("median")
        response_bytes = metrics.get("httpResponseBytes", {}).get("median", "")
        rss_delta = metrics.get("rssDeltaBytes", {}).get("median")
        frames_50 = metrics.get("framesOver50ms", {}).get("median", "")
        http_total_ms = "" if http_total_us is None else round(http_total_us / 1000.0, 3)
        worker_total_ms = "" if worker_total_us is None else round(worker_total_us / 1000.0, 3)
        http_max_ms = "" if http_max_us is None else round(http_max_us / 1000.0, 3)
        rss_delta_mib = "" if rss_delta is None else round(rss_delta / (1024 * 1024), 3)
        lines.append(
            f"| {item['scenario']} | {item['mode']} | {target} | {item['runs']} | "
            f"{median} | {p90_value} | {http_requests} | {http_total_ms} | "
            f"{worker_ops} | {worker_total_ms} | {http_max_ms} | "
            f"{response_bytes} | {rss_delta_mib} | {frames_50} | {results} |"
        )

    lines.extend([
        "",
        "## Recovered interrupted runs",
        "",
        "| Scenario | Mode | Target | Last step | Result |",
        "|---|---|---|---|---|",
    ])
    if recovered_runs:
        for item in recovered_runs:
            target = item.get("targetAlias") or item.get("targetType") or ""
            lines.append(
                f"| {item.get('scenario', '')} | {item.get('mode', '')} | "
                f"{target} | {item.get('lastStep', '')} | {item.get('result', '')} |"
            )
    else:
        lines.append("| none |  |  |  |  |")

    download_groups = [
        item for item in summary_groups
        if any(
            name.startswith("downloadMetadataBatch")
            or name.startswith("downloadUpdateChildren")
            or name.startswith("downloadAlbumView")
            or name.startswith("downloadSyncNodeMicros")
            for name in item.get("numericMetrics", {})
        )
        or any(
            name.startswith("downloadMetadataBatch")
            or name.startswith("downloadMetadataCache")
            or name.startswith("downloadChildCache")
            or name.startswith("downloadAlbumView")
            or name.startswith("downloadSyncNodeCount")
            for name in item.get("categoricalMetrics", {})
        )
    ]

    lines.extend([
        "",
        "## Download sync diagnostics",
        "",
        "Exact private graph/cardinality counts are not exported; count-like values are bucketed.",
        "",
        "| Scenario | Mode | Target | Metadata batches | Batch IDs total | Batch collect ms | Batch request ms | Metadata cache hit/miss | Child cache hit/miss | Album-view ms | Album IDs scanned | updateChildren req/info ms | Mixed field batches |",
        "|---|---|---|---|---|---:|---:|---|---|---:|---|---|---|",
    ])

    def _bucket(item, name):
        values = item.get("categoricalMetrics", {}).get(name, {})
        if not values:
            return ""
        return ", ".join(
            f"{value}:{count}" if count != 1 else value
            for value, count in values.items()
        )

    def _metric_ms(item, name):
        value = item.get("numericMetrics", {}).get(name, {}).get("median")
        return "" if value is None else round(value / 1000.0, 3)

    if download_groups:
        for item in download_groups:
            target = item["targetAlias"] or item["targetType"] or ""
            req_ms = _metric_ms(item, "downloadUpdateChildrenMicros_required")
            info_ms = _metric_ms(item, "downloadUpdateChildrenMicros_info")
            metadata_hit_miss = (
                f"{_bucket(item, 'downloadMetadataCacheHitBucket')}/"
                f"{_bucket(item, 'downloadMetadataCacheMissBucket')}"
            ).strip("/")
            child_hit_miss = (
                f"{_bucket(item, 'downloadChildCacheHitBucket')}/"
                f"{_bucket(item, 'downloadChildCacheMissBucket')}"
            ).strip("/")
            update_ms = f"{req_ms}/{info_ms}".strip("/")
            lines.append(
                f"| {item['scenario']} | {item['mode']} | {target} | "
                f"{_bucket(item, 'downloadMetadataBatchCountBucket')} | "
                f"{_bucket(item, 'downloadMetadataBatchIdsTotalBucket')} | "
                f"{_metric_ms(item, 'downloadMetadataBatchCollectMicros')} | "
                f"{_metric_ms(item, 'downloadMetadataBatchRequestMicros')} | "
                f"{metadata_hit_miss} | {child_hit_miss} | "
                f"{_metric_ms(item, 'downloadAlbumViewLookupMicros')} | "
                f"{_bucket(item, 'downloadAlbumViewIdsScannedBucket')} | "
                f"{update_ms} | "
                f"{_bucket(item, 'downloadMetadataBatchMixedFieldsBucket')} |"
            )
    else:
        lines.append("| none |  |  |  |  |  |  |  |  |  |  |  |  |")

    node_rows = []
    for item in download_groups:
        metrics = item.get("numericMetrics", {})
        categorical = item.get("categoricalMetrics", {})
        for name, timing in metrics.items():
            if not name.startswith("downloadSyncNodeMicros_"):
                continue
            suffix = name.removeprefix("downloadSyncNodeMicros_")
            if suffix.startswith("Max_"):
                continue
            max_metric = metrics.get(
                f"downloadSyncNodeMicrosMax_{suffix}", {}
            ).get("median")
            node_rows.append((
                item,
                suffix,
                timing.get("median"),
                max_metric,
                _bucket(item, f"downloadSyncNodeCount_{suffix}Bucket"),
            ))

    lines.extend([
        "",
        "### Download sync node timing",
        "",
        "| Scenario | Mode | Target | Node / role | Total ms med | Max node ms med | Count bucket |",
        "|---|---|---|---|---:|---:|---|",
    ])
    if node_rows:
        for item, suffix, total_us, max_us, count_bucket in node_rows:
            target = item["targetAlias"] or item["targetType"] or ""
            total_ms = "" if total_us is None else round(total_us / 1000.0, 3)
            max_ms = "" if max_us is None else round(max_us / 1000.0, 3)
            lines.append(
                f"| {item['scenario']} | {item['mode']} | {target} | "
                f"{suffix} | {total_ms} | {max_ms} | {count_bucket} |"
            )
    else:
        lines.append("| none |  |  |  |  |  |  |")

    album_phase_rows = []
    for item in download_groups:
        metrics = item.get("numericMetrics", {})
        for name, timing in metrics.items():
            if not name.startswith("downloadAlbumInfoPhaseMicros_"):
                continue
            suffix = name.removeprefix("downloadAlbumInfoPhaseMicros_")
            if suffix.startswith("Max_"):
                continue
            max_metric = metrics.get(
                f"downloadAlbumInfoPhaseMicrosMax_{suffix}", {}
            ).get("median")
            album_phase_rows.append((
                item,
                suffix,
                timing.get("median"),
                max_metric,
            ))

    lines.extend([
        "",
        "### Album info phase timing",
        "",
        "| Scenario | Mode | Target | Phase | Total ms med | Max phase ms med |",
        "|---|---|---|---|---:|---:|",
    ])
    if album_phase_rows:
        for item, suffix, total_us, max_us in album_phase_rows:
            target = item["targetAlias"] or item["targetType"] or ""
            total_ms = "" if total_us is None else round(total_us / 1000.0, 3)
            max_ms = "" if max_us is None else round(max_us / 1000.0, 3)
            lines.append(
                f"| {item['scenario']} | {item['mode']} | {target} | "
                f"{suffix} | {total_ms} | {max_ms} |"
            )
    else:
        lines.append("| none |  |  |  |  |  |")

    cache_groups = []
    for item in summary_groups:
        metrics = item["numericMetrics"]
        cache_metric_names = (
            "imageDownloadedFileHit",
            "imagePersistentCacheHit",
            "imageNetworkFetch",
            "imageOfflineMiss",
            "imageLoadCompleted",
            "imageLoadFailed",
            "imageLoadSynchronous",
        )
        if any(name in metrics for name in cache_metric_names):
            cache_groups.append(item)

    lines.extend([
        "",
        "## Image/cache diagnostics",
        "",
        "| Scenario | Mode | Target | Downloaded hit med | Persistent hit med | Network fetch med | Offline miss med | Loads med | Failed med | Sync med |",
        "|---|---|---|---:|---:|---:|---:|---:|---:|---:|",
    ])
    if cache_groups:
        for item in cache_groups:
            metrics = item["numericMetrics"]
            target = item["targetAlias"] or item["targetType"] or ""
            def med(name):
                return metrics.get(name, {}).get("median", "")
            lines.append(
                f"| {item['scenario']} | {item['mode']} | {target} | "
                f"{med('imageDownloadedFileHit')} | "
                f"{med('imagePersistentCacheHit')} | "
                f"{med('imageNetworkFetch')} | "
                f"{med('imageOfflineMiss')} | "
                f"{med('imageLoadCompleted')} | "
                f"{med('imageLoadFailed')} | "
                f"{med('imageLoadSynchronous')} |"
            )
    else:
        lines.append("| none |  |  |  |  |  |  |  |  |  |")

    playback_groups = [
        item for item in summary_groups
        if item.get("playbackSources")
    ]
    lines.extend([
        "",
        "## Playback source diagnostics",
        "",
        "| Scenario | Mode | Target | Source categories |",
        "|---|---|---|---|",
    ])
    if playback_groups:
        for item in playback_groups:
            target = item["targetAlias"] or item["targetType"] or ""
            categories = ", ".join(
                f"{name}:{count}"
                for name, count in sorted(item["playbackSources"].items())
            )
            lines.append(
                f"| {item['scenario']} | {item['mode']} | {target} | "
                f"{categories} |"
            )
    else:
        lines.append("| none |  |  |  |")

    api_groups = [
        item for item in summary_groups
        if item["scenario"].startswith("collection-page-")
    ]
    lines.extend([
        "",
        "## Direct API timing breakdown",
        "",
        "Worker non-HTTP time is an approximation: worker-isolate duration minus measured HTTP duration for the direct API run.",
        "",
        "| Scenario | Mode | Median total ms | HTTP ms med | Worker ms med | Approx non-HTTP ms med |",
        "|---|---|---:|---:|---:|---:|",
    ])
    for item in api_groups:
        metrics = item.get("numericMetrics") or {}
        http_us = metrics.get("httpDurationMicrosTotal", {}).get("median")
        worker_us = metrics.get("workerDurationMicrosTotal", {}).get("median")
        non_http_us = metrics.get("apiNonHttpMicrosApprox", {}).get("median")
        total_ms_text = (
            "" if item["medianMs"] is None else f"{item['medianMs']:.3f}"
        )
        http_ms_text = "" if http_us is None else round(http_us / 1000.0, 3)
        worker_ms_text = "" if worker_us is None else round(worker_us / 1000.0, 3)
        non_http_ms_text = (
            "" if non_http_us is None else round(non_http_us / 1000.0, 3)
        )
        lines.append(
            f"| {item['scenario']} | {item['mode']} | {total_ms_text} | "
            f"{http_ms_text} | {worker_ms_text} | {non_http_ms_text} |"
        )

    problem_groups = [
        item for item in summary_groups
        if any(name != "success" and count > 0 for name, count in item["results"].items())
    ]
    lines.extend([
        "",
        "## Non-successful runs",
        "",
        "| Scenario | Mode | Target | Results |",
        "|---|---|---|---|",
    ])
    if problem_groups:
        for item in problem_groups:
            target = item["targetAlias"] or item["targetType"] or ""
            results = ", ".join(
                f"{name}:{count}" for name, count in sorted(item["results"].items())
            )
            lines.append(
                f"| {item['scenario']} | {item['mode']} | {target} | {results} |"
            )
    else:
        lines.append("| none |  |  | all recorded runs successful |")

    slowest = sorted(
        [item for item in summary_groups if item["medianMs"] is not None],
        key=lambda item: item["medianMs"],
        reverse=True,
    )[:25]
    lines.extend([
        "",
        "## Slowest scenario groups",
        "",
        "| Scenario | Mode | Target | Median ms | p90 ms |",
        "|---|---|---|---:|---:|",
    ])
    for item in slowest:
        target = item["targetAlias"] or item["targetType"] or ""
        p90_value = "" if item["p90Ms"] is None else f"{item['p90Ms']:.3f}"
        lines.append(
            f"| {item['scenario']} | {item['mode']} | {target} | "
            f"{item['medianMs']:.3f} | {p90_value} |"
        )

    lines.extend([
        "",
        "## Event milestones",
        "",
        "Milestones below are measured from each scenario run start. Full details remain in the JSON summary.",
        "",
        "| Scenario | Mode | Target | Event | Median ms | p90 ms |",
        "|---|---|---|---|---:|---:|",
    ])
    for item in summary_groups:
        target = item["targetAlias"] or item["targetType"] or ""
        for event_name, event_values in item.get("eventMilestones", {}).items():
            if event_name in {"run-start", "run-end"}:
                continue
            lines.append(
                f"| {item['scenario']} | {item['mode']} | {target} | {event_name} | "
                f"{event_values['medianMsFromRunStart']:.3f} | "
                f"{event_values['p90MsFromRunStart']:.3f} |"
            )

    Path(args.md_out).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
