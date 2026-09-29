#!/usr/bin/env python3
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    tool_dir = Path(__file__).resolve().parent
    summarizer = tool_dir / "summarize_performance_benchmark.py"

    records = [
        {
            "type": "run-end",
            "run": {
                "scenario": "alphabet-jump-tracks-Z",
                "mode": "refreshed-sequential",
                "targetType": "tracks",
                "targetAlias": None,
                "durationMicros": 1_250_000,
                "result": "success",
                "metrics": {
                    "alphabetJumpPagesLoaded": 47,
                    "playlistItemsSeen": 123,
                    "playlistPagesFetched": 4,
                    "loadedItems": 183,
                    "itemsAdded": 83,
                    "pageItemsAdded": 100,
                    "pageSize": 83,
                    "rssDeltaBytes": 123456,
                },
                "events": [
                    {
                        "name": "alphabet-jump-page-requested",
                        "elapsedMicros": 500_000,
                        "values": {},
                    },
                    {
                        "name": "safe-milestone",
                        "elapsedMicros": 750_000,
                        "values": {},
                    },
                    {
                        "name": "playback-source-selected",
                        "elapsedMicros": 800_000,
                        "values": {
                            "source": "server",
                            "serverTarget": "public",
                            "transcoded": False,
                            "offline": False,
                        },
                    },
                ],
            },
        },
        {
            "type": "run-end",
            "run": {
                "scenario": "download-lifecycle-bench100",
                "mode": "fresh",
                "targetType": "playlist",
                "targetAlias": "bench100",
                "durationMicros": 12_000_000,
                "result": "success",
                "metrics": {
                    "downloadMetadataBatchCountBucket": "10-49",
                    "downloadMetadataBatchIdsTotalBucket": "100-499",
                    "downloadMetadataBatchCollectMicros": 2_500_000,
                    "downloadMetadataBatchRequestMicros": 6_000_000,
                    "downloadMetadataCacheHitBucket": "100-499",
                    "downloadMetadataCacheMissBucket": "50-99",
                    "downloadChildCacheHitBucket": "10-49",
                    "downloadChildCacheMissBucket": "1-9",
                    "downloadAlbumViewLookupMicros": 300_000,
                    "downloadAlbumViewIdsScannedBucket": "1000-4999",
                    "downloadUpdateChildrenMicros_required": 400_000,
                    "downloadUpdateChildrenMicros_info": 200_000,
                    "downloadMetadataBatchMixedFieldsBucket": "0",
                    "downloadSyncNodeCount_track_requiredBucket": "50-99",
                    "downloadSyncNodeMicros_track_required": 5_000_000,
                    "downloadSyncNodeMicrosMax_track_required": 250_000,
                },
                "events": [],
            },
        },
        {
            "type": "diagnostic",
            "name": "runtime-environment",
            "emittedAt": "2026-09-23T11:59:58Z",
            "values": {
                "operatingSystem": "ios",
                "operatingSystemVersion": "test-ios",
                "dartVersion": "test-dart",
                "processorCount": 6,
                "variant": "deadbeef1234",
            },
        },
        {
            "type": "diagnostic",
            "name": "startup-main-init-complete",
            "emittedAt": "2026-09-23T11:59:59Z",
            "values": {
                "processElapsedMs": 100.0,
                "nativeLaunchElapsedMs": 150.0,
                "nativeToDartMainMs": 50.0,
            },
        },
        {
            "type": "diagnostic",
            "name": "startup-image-cache-index-loaded",
            "emittedAt": "2026-09-23T12:00:00Z",
            "values": {
                "persistentEntryCount": 4321,
                "mappedPlayerEntries": 321,
            },
        },
        {
            "type": "diagnostic",
            "name": "startup-phase-result",
            "emittedAt": "2026-09-23T12:00:01Z",
            "values": {
                "phase": "persistent-cache-startup-repeat-1",
                "fullyReadyMs": 1100.0,
                "nativeFullyReadyMs": 1150.0,
                "nativeToDartMainMs": 50.0,
                "requestCount": 1,
                "responseBytes": 1000,
                "httpDurationMicrosTotal": 100000,
                "httpDurationMicrosMax": 50000,
                "workerOperationCount": 1,
                "workerOperationFailed": 0,
                "workerDurationMicrosTotal": 120000,
                "workerDurationMicrosMax": 60000,
                "frameCount": 11,
                "framesOver16_7ms": 1,
                "framesOver33_3ms": 0,
                "framesOver50ms": 0,
                "frameMicrosMax": 11000,
                "imageLoadStarted": 10,
                "imageLoadCompleted": 10,
                "imageLoadFailed": 0,
                "imageMaxConcurrentLoads": 1,
                "rssBytes": 101000000,
                "maxRssBytes": 121000000,
            },
        },
        {
            "type": "diagnostic",
            "name": "startup-phase-result",
            "emittedAt": "2026-09-23T12:00:02Z",
            "values": {
                "phase": "persistent-cache-startup-repeat-2",
                "fullyReadyMs": 1200.0,
                "nativeFullyReadyMs": 1250.0,
                "nativeToDartMainMs": 50.0,
                "requestCount": 2,
                "responseBytes": 2000,
                "httpDurationMicrosTotal": 200000,
                "httpDurationMicrosMax": 100000,
                "workerOperationCount": 2,
                "workerOperationFailed": 0,
                "workerDurationMicrosTotal": 240000,
                "workerDurationMicrosMax": 120000,
                "frameCount": 12,
                "framesOver16_7ms": 2,
                "framesOver33_3ms": 0,
                "framesOver50ms": 0,
                "frameMicrosMax": 12000,
                "imageLoadStarted": 20,
                "imageLoadCompleted": 20,
                "imageLoadFailed": 0,
                "imageMaxConcurrentLoads": 2,
                "rssBytes": 102000000,
                "maxRssBytes": 122000000,
            },
        },
        {
            "type": "diagnostic",
            "name": "startup-phase-result",
            "emittedAt": "2026-09-23T12:00:03Z",
            "values": {
                "phase": "persistent-cache-startup-repeat-3",
                "fullyReadyMs": 1300.0,
                "nativeFullyReadyMs": 1350.0,
                "nativeToDartMainMs": 50.0,
                "requestCount": 3,
                "responseBytes": 3000,
                "httpDurationMicrosTotal": 300000,
                "httpDurationMicrosMax": 150000,
                "workerOperationCount": 3,
                "workerOperationFailed": 0,
                "workerDurationMicrosTotal": 360000,
                "workerDurationMicrosMax": 180000,
                "frameCount": 13,
                "framesOver16_7ms": 3,
                "framesOver33_3ms": 0,
                "framesOver50ms": 0,
                "frameMicrosMax": 13000,
                "imageLoadStarted": 30,
                "imageLoadCompleted": 30,
                "imageLoadFailed": 0,
                "imageMaxConcurrentLoads": 3,
                "rssBytes": 103000000,
                "maxRssBytes": 123000000,
            },
        },
        {
            "type": "diagnostic",
            "name": "suite-phase-complete",
            "emittedAt": "2026-09-23T12:00:01Z",
            "values": {
                "phase": "synthetic",
                "rssBytes": 1000000,
                "maxRssBytes": 2000000,
                "processElapsedMs": 123.0,
            },
        },
    ]

    with tempfile.TemporaryDirectory() as temp:
        temp_dir = Path(temp)
        jsonl = temp_dir / "input.jsonl"
        json_out = temp_dir / "summary.json"
        md_out = temp_dir / "summary.md"

        jsonl.write_text(
            "".join(json.dumps(record) + "\n" for record in records),
            encoding="utf-8",
        )

        subprocess.run(
            [
                sys.executable,
                str(summarizer),
                str(jsonl),
                "--json-out",
                str(json_out),
                "--md-out",
                str(md_out),
            ],
            check=True,
        )

        summary = json.loads(json_out.read_text(encoding="utf-8"))
        group = summary["groups"][0]
        metrics = group["numericMetrics"]

        assert "alphabetJumpPagesLoaded" not in metrics
        assert "playlistItemsSeen" not in metrics
        assert "playlistPagesFetched" not in metrics
        assert "loadedItems" not in metrics
        assert "itemsAdded" not in metrics
        assert "pageItemsAdded" not in metrics
        assert "pageSize" not in metrics
        event_milestones = group["eventMilestones"]
        assert "alphabet-jump-page-requested" not in event_milestones
        assert "safe-milestone" in event_milestones
        assert group["playbackSources"] == {"server/public": 1}
        assert summary["source"] == "input.jsonl"

        download_group = next(
            item
            for item in summary["groups"]
            if item["scenario"] == "download-lifecycle-bench100"
        )
        assert download_group["categoricalMetrics"][
            "downloadMetadataBatchCountBucket"
        ] == {"10-49": 1}
        assert download_group["numericMetrics"][
            "downloadMetadataBatchRequestMicros"
        ]["median"] == 6_000_000

        environments = summary["runtimeEnvironments"]
        assert len(environments) == 1
        assert environments[0]["operatingSystem"] == "ios"
        assert environments[0]["variant"] == "deadbeef1234"

        startup_groups = summary["startupPhaseGroups"]
        persistent = next(
            item
            for item in startup_groups
            if item["phase"] == "persistent-cache-startup"
        )
        assert persistent["runs"] == 3
        assert persistent["fullyReadyMedianMs"] == 1200.0
        assert persistent["fullyReadyP90Ms"] == 1300.0
        assert persistent["nativeFullyReadyMedianMs"] == 1250.0
        assert persistent["nativeToDartMainMedianMs"] == 50.0

        image_cache = summary["startupImageCache"][0]
        assert image_cache["persistentEntryBucket"] == "1000-4999"
        assert image_cache["mappedPlayerEntryBucket"] == "100-999"
        assert "persistentEntryCount" not in image_cache
        assert "mappedPlayerEntries" not in image_cache

        markdown = md_out.read_text(encoding="utf-8")
        assert "4321" not in markdown
        assert "321" not in markdown
        assert "playlistItemsSeen" not in markdown
        assert "playlistPagesFetched" not in markdown
        assert "1000-4999" in markdown
        assert "100-999" in markdown
        assert "persistent-cache-startup" in markdown
        assert "Native -> Dart main" in markdown
        assert "deadbeef1234" in markdown
        assert "## Download sync diagnostics" in markdown
        assert "download-lifecycle-bench100" in markdown
        assert "10-49" in markdown
        assert "track_required" in markdown

    print("performance benchmark summary self-test passed")


if __name__ == "__main__":
    main()
