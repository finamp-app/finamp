import 'dart:async';
import 'dart:io';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/screens/genre_screen.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/keep_screen_on_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:finamp/services/performance_benchmark_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';

/// Automated entry point for the test-only performance benchmark branch.
///
/// This first phase intentionally uses deterministic API-backed operations so a
/// benchmark run starts automatically after authentication. UI navigation,
/// playback and download phases are layered on top of the same recorder.
class PerformanceBenchmarkSuiteRunner {
  static final PerformanceBenchmarkSuiteRunner instance = PerformanceBenchmarkSuiteRunner._();

  PerformanceBenchmarkSuiteRunner._();

  static const _benchmarkTargets = <String, int>{
    "bench-10": 10,
    "bench-100": 100,
    "bench-1000": 1000,
    "bench-10000": 10000,
  };

  bool _armed = false;
  bool _running = false;

  bool get _smoke => PerformanceBenchmarkService.smoke;
  int get _startupRepeatCount => _smoke ? 1 : 3;

  static const _mainStageOrder = <String>[
    "main-running",
    "main-targets-done",
    "main-network-done",
    "main-api-done",
    "main-ui-done",
    "main-paging-done",
    "main-search-done",
    "main-alphabet-done",
    "main-details-done",
    "main-drilldown-done",
    "main-playback-done",
    "main-download-bench10-done",
    "main-download-bench100-done",
    "main-download-bench1000-done",
    "main-download-done",
    "main-queue-restore-done",
    "main-image-cache-done",
  ];

  bool _stageAtOrAfter(String? current, String target) {
    final currentIndex = _mainStageOrder.indexOf(current ?? "main-running");
    final targetIndex = _mainStageOrder.indexOf(target);
    return currentIndex >= 0 && targetIndex >= 0 && currentIndex >= targetIndex;
  }

  static const _postStageOrder = <String>[
    "post-restart-running",
    "post-api-done",
    "post-ui-done",
    "post-detail-done",
    "post-metadata-done",
  ];

  bool _postStageAtOrAfter(String? current, String target) {
    final currentIndex = _postStageOrder.indexOf(current ?? "post-restart-running");
    final targetIndex = _postStageOrder.indexOf(target);
    return currentIndex >= 0 && targetIndex >= 0 && currentIndex >= targetIndex;
  }

  void arm() {
    if (!PerformanceBenchmarkService.enabled || _armed) return;
    _armed = true;
    unawaited(_armAsync());
  }

  Future<void> _armAsync() async {
    final recorder = PerformanceBenchmarkService.instance;
    recorder.startHeartbeat();
    GetIt.instance<KeepScreenOnHelper>().setPerformanceBenchmarkOverride(true);
    final stage = await recorder.getSuiteStage();

    if (PerformanceBenchmarkService.targetedDownloadBench100 || PerformanceBenchmarkService.targetedDownloadBench1000) {
      final String targetAlias = PerformanceBenchmarkService.targetedDownloadBench1000 ? "bench-1000" : "bench-100";
      recorder.diagnostic("suite-targeted-mode", values: {"target": targetAlias, "scope": "download-diagnostics"});
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runTargetedDownloadDiagnostics());
      });
      if (GetIt.instance<FinampUserHelper>().currentUser == null) {
        recorder.diagnostic("suite-waiting-for-login");
      }
      return;
    }

    recorder.diagnostic(
      "suite-armed",
      values: {
        "variant": PerformanceBenchmarkService.variant,
        "suiteRunId": PerformanceBenchmarkService.suiteRunId,
        "stage": stage ?? "fresh",
        "smoke": _smoke,
      },
    );
    recorder.diagnostic(
      "runtime-environment",
      values: {
        "operatingSystem": Platform.operatingSystem,
        "operatingSystemVersion": Platform.operatingSystemVersion,
        "dartVersion": Platform.version,
        "processorCount": Platform.numberOfProcessors,
        "variant": PerformanceBenchmarkService.variant,
      },
    );

    if (stage == null) {
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_prepareFreshSuiteState());
      });
      if (GetIt.instance<FinampUserHelper>().currentUser == null) {
        recorder.diagnostic("suite-waiting-for-login");
      }
      return;
    }

    if (stage == "realistic-startup-prepared") {
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_prepareColdProcessRun());
      });
      return;
    }

    if (stage.startsWith("offline-bench1000-")) {
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runOfflineBench1000PostRestart());
      });
      return;
    }

    if (stage.startsWith("startup-repeat-") && stage.endsWith("-running")) {
      final repeat = int.tryParse(stage.replaceFirst("startup-repeat-", "").replaceFirst("-running", ""));
      if (repeat == null || repeat < 1 || repeat > _startupRepeatCount) {
        recorder.diagnostic("suite-error", values: {"phase": "startup-repeat-routing", "stage": stage});
        GetIt.instance<KeepScreenOnHelper>().setPerformanceBenchmarkOverride(false);
        recorder.stopHeartbeat();
        await recorder.flushHostStream();
        return;
      }
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runPersistentStartupRepeat(repeat));
      });
      return;
    }

    if (stage == "cold-start-prepared") {
      await recorder.setSuiteStage("main-running");
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runAfterAuthentication());
      });
      return;
    }

    if (stage == "awaiting-host-restart") {
      await recorder.setSuiteStage("post-restart-running");
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runPostRestartPhase());
      });
      return;
    }

    if (stage == "complete") {
      recorder.diagnostic("suite-already-complete");
      GetIt.instance<KeepScreenOnHelper>().setPerformanceBenchmarkOverride(false);
      recorder.stopHeartbeat();
      return;
    }

    // A main-* stage means a previous process ended unexpectedly after
    // one or more durable phase checkpoints. Recovery records the interrupted
    // active run in main(); the suite resumes at the first unfinished phase.
    if (stage.startsWith("post-")) {
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runPostRestartPhase());
      });
    } else if (stage.startsWith("main-") || stage == "main-running") {
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runAfterAuthentication());
      });
    } else {
      await recorder.setSuiteStage("main-running");
      GetIt.instance<FinampUserHelper>().runUserHook(() {
        unawaited(_runAfterAuthentication());
      });
    }
  }

  Future<void> _waitForStartupReady({
    required String phase,
    Duration startupTaskTimeout = const Duration(hours: 3),
    Duration screenTimeout = const Duration(minutes: 15),
    Duration imageTimeout = const Duration(minutes: 15),
    Duration networkTimeout = const Duration(minutes: 30),
  }) async {
    final recorder = PerformanceBenchmarkService.instance;
    await recorder.waitForStartupQuiescence(quietPeriod: const Duration(seconds: 3), timeout: startupTaskTimeout);
    await recorder.waitForStartupScreenReady(timeout: screenTimeout);
    await recorder.waitForImageQuiescence(quietPeriod: const Duration(seconds: 1), timeout: imageTimeout);
    await recorder.waitForNetworkQuiescence(quietPeriod: const Duration(seconds: 3), timeout: networkTimeout);
    recorder.reportStartupFrameSummary(phase);
    recorder.reportStartupNetworkSummary(phase: phase);
    await recorder.reportStartupPhaseResult(phase);
    recorder.diagnostic(
      "startup-fully-ready",
      values: {
        "phase": phase,
        "processElapsedMs": recorder.processElapsedMs,
        "startupTaskTimeoutSeconds": startupTaskTimeout.inSeconds,
        "screenTimeoutSeconds": screenTimeout.inSeconds,
        "imageTimeoutSeconds": imageTimeout.inSeconds,
        "networkTimeoutSeconds": networkTimeout.inSeconds,
      },
    );
  }

  Future<Box<FinampSettings>> _benchmarkSettingsBox() async {
    if (!Hive.isBoxOpen("FinampSettings")) {
      PerformanceBenchmarkService.instance.diagnostic("benchmark-settings-box-reopen");
      await Hive.openBox<FinampSettings>("FinampSettings");
    }
    return Hive.box<FinampSettings>("FinampSettings");
  }

  Future<bool> _benchmarkOfflineState() async {
    final box = await _benchmarkSettingsBox();
    final settings = box.get("FinampSettings");
    if (settings == null) {
      throw StateError("Benchmark FinampSettings entry is unavailable");
    }
    return settings.isOffline;
  }

  Future<void> _setBenchmarkOfflineState(bool offline) async {
    final box = await _benchmarkSettingsBox();
    final settings = box.get("FinampSettings");
    if (settings == null) {
      throw StateError("Benchmark FinampSettings entry is unavailable");
    }
    settings.isOffline = offline;
    await box.put("FinampSettings", settings);
    await box.flush();
    PerformanceBenchmarkService.instance.diagnostic("benchmark-offline-state-persisted", values: {"offline": offline});
  }

  Future<void> _ensureSuiteOnlineBaseline() async {
    final recorder = PerformanceBenchmarkService.instance;
    var originalOffline = await recorder.getOriginalOfflineState();
    if (originalOffline == null) {
      originalOffline = await _benchmarkOfflineState();
      await recorder.saveOriginalOfflineState(originalOffline);
      recorder.diagnostic("suite-original-offline-state-saved", values: {"offline": originalOffline});
    }

    if (await _benchmarkOfflineState()) {
      await _setBenchmarkOfflineState(false);
      await recorder.waitForNetworkQuiescence(
        quietPeriod: const Duration(milliseconds: 750),
        timeout: const Duration(minutes: 5),
      );
      recorder.diagnostic("suite-online-baseline-forced", values: {"originalOffline": originalOffline});
    }
  }

  Future<void> _restoreSuiteOriginalOfflineState({bool clearSavedState = true}) async {
    final recorder = PerformanceBenchmarkService.instance;
    final originalOffline = await recorder.getOriginalOfflineState();
    if (originalOffline == null) return;

    if (await _benchmarkOfflineState() != originalOffline) {
      await _setBenchmarkOfflineState(originalOffline);
    }
    recorder.diagnostic("suite-original-offline-state-restored", values: {"offline": originalOffline});
    if (clearSavedState) {
      await recorder.clearOriginalOfflineState();
    }
  }

  Future<void> _bestEffortTerminalCleanupAndRestore() async {
    final recorder = PerformanceBenchmarkService.instance;
    GetIt.instance<KeepScreenOnHelper>().setPerformanceBenchmarkOverride(false);

    try {
      await _recoverPendingDownloadCleanup();
    } catch (error) {
      recorder.diagnostic("terminal-cleanup-failed", values: {"errorType": error.runtimeType.toString()});
    }

    try {
      await _restoreSuiteOriginalOfflineState();
    } catch (error) {
      recorder.diagnostic("terminal-offline-state-restore-failed", values: {"errorType": error.runtimeType.toString()});
    }
  }

  Future<void> _clearPreviousBenchmarkArtifacts() async {
    final recorder = PerformanceBenchmarkService.instance;
    final downloads = GetIt.instance<DownloadsService>();
    final api = GetIt.instance<JellyfinApiHelper>();

    recorder.diagnostic("suite-preconditioning-artifact-cleanup-start");

    // The benchmark app is isolated from the user's normal Finamp install.
    // Remove any queue snapshot left by a previous interrupted benchmark run so
    // realistic startup is not accidentally measuring old benchmark state.
    await GetIt.instance<QueueService>().clearPerformanceBenchmarkQueueState();

    const aliases = <String, int>{"bench-10": 10, "bench-100": 100, "bench-1000": 1000};
    final remaining = aliases.keys.toSet();
    const pageSize = 200;
    var startIndex = 0;

    while (remaining.isNotEmpty) {
      final page = await api.getItemsWithTotalRecordCount(
        includeItemTypes: "Playlist",
        recursive: true,
        startIndex: startIndex,
        limit: pageSize,
      );
      final items = page.items ?? const <BaseItemDto>[];

      for (final item in items) {
        final normalized = item.name?.trim().toLowerCase();
        if (normalized == null) continue;

        String? matchedAlias;
        for (final alias in remaining) {
          if (normalized == alias || normalized == "$alias [smart]") {
            matchedAlias = alias;
            break;
          }
        }
        if (matchedAlias == null) continue;

        final stub = DownloadStub.fromItem(type: DownloadItemType.collection, item: item);
        final expectedTracks = aliases[matchedAlias]!;
        final status = downloads.getStatus(stub, expectedTracks);
        final progress = downloads.getPerformanceBenchmarkCollectionProgress(stub);
        final graphTracks = progress["totalTracks"] ?? 0;
        if (status.isDownloaded || graphTracks > 0) {
          recorder.diagnostic(
            "suite-preconditioning-old-download-found",
            values: {
              "targetAlias": matchedAlias,
              "expectedTracks": expectedTracks,
              "graphTracksPresent": graphTracks,
              "wasComplete": status.isDownloaded,
            },
          );
          await downloads.deleteDownload(stub: stub);
          await downloads.waitForPerformanceBenchmarkCleanup(stub: stub, timeout: const Duration(minutes: 30));
        }
        remaining.remove(matchedAlias);
      }

      if (items.length < pageSize) break;
      startIndex += items.length;
    }

    // Do not wait for global download-system idle here. A previous
    // interrupted benchmark can have stale all-playlists-metadata work queued,
    // and the fresh preconditioning process intentionally suppresses normal
    // queue restart. Waiting globally before deleting that metadata creates a
    // deadlock: the stale task cannot drain and its cleanup has not run yet.
    recorder.diagnostic(
      "suite-preconditioning-artifact-cleanup-complete",
      values: {"unresolvedBenchmarkAliases": remaining.length},
    );
  }

  Future<void> _prepareFreshSuiteState() async {
    if (_running) return;
    _running = true;

    final recorder = PerformanceBenchmarkService.instance;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _ensureSuiteOnlineBaseline();

      // Let normal startup and queue restoration settle before mutating
      // benchmark-owned state. Otherwise a stale persisted queue could be
      // restored concurrently with preconditioning cleanup.
      await _waitForStartupReady(
        phase: "suite-preconditioning",
        startupTaskTimeout: const Duration(minutes: 30),
        networkTimeout: const Duration(minutes: 30),
      );

      // Recover stale benchmark cleanup only after the startup queues/services
      // are quiescent, then remove any artifacts left by earlier benchmark runs.
      await _recoverPendingDownloadCleanup();
      await _clearPreviousBenchmarkArtifacts();

      final downloads = GetIt.instance<DownloadsService>();
      final metadataStub = DownloadStub.fromFinampCollection(
        FinampCollection(type: FinampCollectionType.allPlaylistsMetadata),
      );

      recorder.diagnostic(
        "suite-preconditioning-metadata-cleanup-start",
        values: downloads.getPerformanceBenchmarkQueueState(),
      );
      // Deleting a missing target is harmless; deleting an old or partial
      // target makes the next process exercise the real first-run workload.
      // This cleanup must happen before waiting for global idle because stale
      // metadata work may itself be the reason the global system is not idle.
      await downloads.deleteDownload(stub: metadataStub);
      await downloads.waitForPerformanceBenchmarkCleanup(stub: metadataStub, timeout: const Duration(minutes: 30));
      recorder.diagnostic(
        "suite-preconditioning-global-download-idle-wait-start",
        values: downloads.getPerformanceBenchmarkQueueState(),
      );
      await downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
        stableFor: const Duration(seconds: 5),
        timeout: const Duration(minutes: 30),
      );
      recorder.diagnostic(
        "suite-preconditioning-metadata-cleanup-complete",
        values: downloads.getPerformanceBenchmarkQueueState(),
      );

      await _settleUi(schedulerCooldown: Duration.zero);
      await clearPerformanceBenchmarkImageCache();

      await recorder.setSuiteStage("realistic-startup-prepared");
      recorder.diagnostic(
        "host-restart-requested",
        values: {"reason": "fresh-suite-preconditioned", "nextStage": "realistic-startup-prepared"},
      );
      await recorder.flushHostStream();
    } catch (error) {
      await _bestEffortTerminalCleanupAndRestore();
      recorder.diagnostic(
        "suite-error",
        values: {"phase": "suite-preconditioning", "errorType": error.runtimeType.toString()},
      );
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
    } finally {
      _running = false;
    }
  }

  Future<void> _prepareColdProcessRun() async {
    if (_running) return;
    _running = true;

    final recorder = PerformanceBenchmarkService.instance;
    try {
      await WidgetsBinding.instance.endOfFrame;

      // This process exists specifically to measure Finamp's real first-start
      // playlist metadata workload. A cleanup marker here is current-suite
      // ownership, not stale state; do not delete it while startup is running.
      await _waitForStartupReady(phase: "realistic-first-startup");
      if (!recorder.startupPlaylistMetadataWorkRan || recorder.startupPlaylistMetadataWorkSucceeded != true) {
        throw StateError("Realistic first-start playlist metadata workload did not complete successfully");
      }

      final downloads = GetIt.instance<DownloadsService>();
      final metadataStub = DownloadStub.fromFinampCollection(
        FinampCollection(type: FinampCollectionType.allPlaylistsMetadata),
      );
      recorder.diagnostic(
        "startup-playlist-metadata-cleanup-start",
        values: {"startupWorkObserved": recorder.startupPlaylistMetadataWorkRan},
      );
      await downloads.deleteDownload(stub: metadataStub);
      await downloads.waitForPerformanceBenchmarkCleanup(stub: metadataStub, timeout: const Duration(minutes: 30));
      await downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
        stableFor: const Duration(seconds: 5),
        timeout: const Duration(minutes: 30),
      );
      await recorder.setDownloadCleanupRequired(targetAlias: "all-playlists-metadata", required: false);
      recorder.diagnostic("startup-playlist-metadata-cleanup-complete");

      // Prepare a reproducible cold image-cache process while preserving auth,
      // settings and download configuration in the isolated benchmark app.
      await _settleUi(schedulerCooldown: Duration.zero);
      await clearPerformanceBenchmarkImageCache();

      // Keep the realistic first-process startup records in the same host
      // stream. The next process is still a true cold process, but its phase is
      // separated by the durable stage and restart diagnostics.
      await recorder.setSuiteStage("cold-start-prepared");
      recorder.diagnostic(
        "host-restart-requested",
        values: {"reason": "cold-process-prepared", "nextStage": "main-running"},
      );
      await recorder.flushHostStream();
    } catch (error) {
      await _bestEffortTerminalCleanupAndRestore();
      recorder.diagnostic(
        "suite-error",
        values: {"phase": "cold-process-preparation", "errorType": error.runtimeType.toString()},
      );
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
    } finally {
      _running = false;
    }
  }

  Future<void> _runPersistentStartupRepeat(int repeat) async {
    if (_running) return;
    _running = true;

    final recorder = PerformanceBenchmarkService.instance;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _recoverPendingDownloadCleanup();

      final phase = "persistent-cache-startup-repeat-$repeat";
      await _waitForStartupReady(phase: phase);
      recorder.diagnostic(
        "startup-repeat-complete",
        values: {"repeat": repeat, "phase": phase, "processElapsedMs": recorder.processElapsedMs},
      );

      if (repeat < _startupRepeatCount) {
        final nextRepeat = repeat + 1;
        final nextStage = "startup-repeat-$nextRepeat-running";
        await recorder.setSuiteStage(nextStage);
        recorder.diagnostic(
          "host-restart-requested",
          values: {"reason": "persistent-cache-startup-repeat", "nextStage": nextStage, "repeat": nextRepeat},
        );
      } else {
        await recorder.setSuiteStage("awaiting-host-restart");
        recorder.diagnostic(
          "host-restart-requested",
          values: {"reason": "persistent-cache-startup-repeats-complete", "nextStage": "post-restart-cache"},
        );
      }

      await recorder.flushHostStream();
    } catch (error) {
      await _bestEffortTerminalCleanupAndRestore();
      recorder.diagnostic(
        "suite-error",
        values: {"phase": "persistent-cache-startup-repeat-$repeat", "errorType": error.runtimeType.toString()},
      );
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
    } finally {
      _running = false;
    }
  }

  Future<void> _verifySuiteTerminalState() async {
    final recorder = PerformanceBenchmarkService.instance;

    if (recorder.activeRun != null) {
      throw StateError("Suite cannot complete with an active benchmark run");
    }
    if (await recorder.getDownloadCleanupRequirement() != null) {
      throw StateError("Suite cannot complete while benchmark download cleanup is pending");
    }
    if (await recorder.getOriginalOfflineState() != null) {
      throw StateError("Suite cannot complete before the original offline state is restored");
    }

    final stage = await recorder.getSuiteStage();
    if (stage != "post-metadata-done") {
      throw StateError("Suite reached terminal verification from an unexpected stage");
    }

    recorder.diagnostic("suite-terminal-state-verified", values: {"stage": stage});
    await recorder.flushHostStream();
  }

  Future<void> _runPostRestartPhase() async {
    if (_running) return;
    _running = true;

    final recorder = PerformanceBenchmarkService.instance;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _recoverPendingDownloadCleanup();
      recorder.diagnostic("post-restart-phase-start");

      await _waitForStartupReady(phase: "post-restart");
      recorder.diagnostic("post-restart-startup-quiescent");

      var stage = await recorder.getSuiteStage();

      if (!_postStageAtOrAfter(stage, "post-api-done")) {
        await _runCollectionFirstPageBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "post-restart-api-cache"});
        await recorder.setSuiteStage("post-api-done");
        stage = "post-api-done";
      }

      if (!_postStageAtOrAfter(stage, "post-ui-done")) {
        final tabs = _smoke
            ? const <String>["albums", "tracks"]
            : const <String>["home", "albums", "artists", "playlists", "tracks", "genres"];
        for (final tab in tabs) {
          await _runUiTabBaseline(tab, mode: "post-restart-refreshed", round: 1);
          await _settleUi(schedulerCooldown: const Duration(seconds: 2));
          await _runUiTabBaseline(tab, mode: "post-restart-warm", round: 1);
          await _settleUi(schedulerCooldown: const Duration(seconds: 2));
        }
        recorder.diagnostic("suite-phase-complete", values: {"phase": "post-restart-ui-cache"});
        await recorder.setSuiteStage("post-ui-done");
        stage = "post-ui-done";
      }

      if (!_postStageAtOrAfter(stage, "post-detail-done")) {
        final aliases = _smoke
            ? const <String>["detail-album", "bench-10"]
            : const <String>["detail-album", "detail-artist", "detail-genre", "bench-100"];
        for (final alias in aliases) {
          final detailType = alias == "detail-album"
              ? "album"
              : alias == "detail-artist"
              ? "artist"
              : alias == "detail-genre"
              ? "genre"
              : "playlist";
          await _runDetailBaseline(
            targetAlias: alias,
            detailType: detailType,
            mode: "post-restart-refreshed",
            refresh: true,
          );
          await _settleUi();
          await _runDetailBaseline(
            targetAlias: alias,
            detailType: detailType,
            mode: "post-restart-warm",
            refresh: false,
          );
          await _settleUi();
        }
        recorder.diagnostic("suite-phase-complete", values: {"phase": "post-restart-detail-cache"});
        await recorder.setSuiteStage("post-detail-done");
        stage = "post-detail-done";
      }

      if (!_postStageAtOrAfter(stage, "post-metadata-done")) {
        await _runOneTimePlaylistMetadataBaseline();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "one-time-playlist-metadata-sync"});
        await recorder.setSuiteStage("post-metadata-done");
      }

      await _restoreSuiteOriginalOfflineState();
      await _verifySuiteTerminalState();
      await recorder.setSuiteStage("complete");
      recorder.diagnostic("suite-complete", values: {"phase": _smoke ? "smoke" : "full-baseline"});
      GetIt.instance<KeepScreenOnHelper>().setPerformanceBenchmarkOverride(false);
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
    } catch (error) {
      await _bestEffortTerminalCleanupAndRestore();
      recorder.diagnostic("suite-error", values: {"phase": "post-restart", "errorType": error.runtimeType.toString()});
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
    } finally {
      _running = false;
    }
  }

  Future<void> _runAfterAuthentication() async {
    if (_running) return;
    _running = true;

    final recorder = PerformanceBenchmarkService.instance;
    try {
      if (await _recoverCompletedBench1000BeforeOfflineRestart()) {
        return;
      }
      await _recoverPendingDownloadCleanup();

      // Keep benchmark work out of the authentication transition itself,
      // then wait for Finamp's known asynchronous startup jobs to finish.
      await WidgetsBinding.instance.endOfFrame;
      recorder.diagnostic("suite-authenticated");
      await _waitForStartupReady(phase: "main-cold-process");
      recorder.diagnostic("startup-baseline-complete");

      var stage = await recorder.getSuiteStage();

      if (!_stageAtOrAfter(stage, "main-targets-done")) {
        final targetsReady = await _discoverAndValidateTargets();
        if (!targetsReady) {
          await _bestEffortTerminalCleanupAndRestore();
          recorder.diagnostic("suite-blocked", values: {"reason": "benchmark-target-validation"});
          recorder.stopHeartbeat();
          await recorder.flushHostStream();
          return;
        }
        await recorder.setSuiteStage("main-targets-done");
        stage = "main-targets-done";
      }

      if (!_stageAtOrAfter(stage, "main-network-done")) {
        await _runNetworkTargetBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "network-target-probes"});
        await recorder.setSuiteStage("main-network-done");
        stage = "main-network-done";
      }

      if (!_stageAtOrAfter(stage, "main-api-done")) {
        await _runCollectionFirstPageBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "authenticated-api-baseline"});
        await recorder.setSuiteStage("main-api-done");
        stage = "main-api-done";
      }

      if (!_stageAtOrAfter(stage, "main-ui-done")) {
        await _runUiTabBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "ui-tab-baseline"});
        await recorder.setSuiteStage("main-ui-done");
        stage = "main-ui-done";
      }

      if (!_stageAtOrAfter(stage, "main-paging-done")) {
        await _runPagingBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "deep-paging"});
        await recorder.setSuiteStage("main-paging-done");
        stage = "main-paging-done";
      }

      if (!_stageAtOrAfter(stage, "main-search-done")) {
        await _runSearchBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "search"});
        await recorder.setSuiteStage("main-search-done");
        stage = "main-search-done";
      }

      if (!_stageAtOrAfter(stage, "main-alphabet-done")) {
        await _runAlphabetBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "alphabet-fast-scroller"});
        await recorder.setSuiteStage("main-alphabet-done");
        stage = "main-alphabet-done";
      }

      if (!_stageAtOrAfter(stage, "main-details-done")) {
        await _runDetailBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "detail-screens"});
        await recorder.setSuiteStage("main-details-done");
        stage = "main-details-done";
      }

      if (!_stageAtOrAfter(stage, "main-drilldown-done")) {
        await _runSearchDrilldownBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "artist-album-track-drilldown"});
        await recorder.setSuiteStage("main-drilldown-done");
        stage = "main-drilldown-done";
      }

      if (!_stageAtOrAfter(stage, "main-playback-done")) {
        await _runPlaybackBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "queue-playback"});
        await recorder.setSuiteStage("main-playback-done");
        stage = "main-playback-done";
      }

      if (!_stageAtOrAfter(stage, "main-download-done")) {
        stage = await _runDownloadAndOfflineBaselines(stage);
        final persistedStage = await recorder.getSuiteStage();
        if (persistedStage?.startsWith("offline-bench1000-") ?? false) {
          // The host will terminate this process after seeing the restart
          // request. Do not overwrite the durable offline continuation stage.
          return;
        }
        recorder.diagnostic("suite-phase-complete", values: {"phase": "download-offline"});
        await recorder.setSuiteStage("main-download-done");
        stage = "main-download-done";
      }

      if (!_stageAtOrAfter(stage, "main-queue-restore-done")) {
        await _runLargeQueueRestoreBaseline();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "large-queue-restore"});
        await recorder.setSuiteStage("main-queue-restore-done");
        stage = "main-queue-restore-done";
      }

      if (!_stageAtOrAfter(stage, "main-image-cache-done")) {
        await _runImageCacheBaselines();
        recorder.diagnostic("suite-phase-complete", values: {"phase": "image-cache"});
        await recorder.setSuiteStage("main-image-cache-done");
      }

      await recorder.setSuiteStage("startup-repeat-1-running");
      recorder.diagnostic(
        "host-restart-requested",
        values: {
          "reason": "begin-persistent-cache-startup-repeats",
          "nextStage": "startup-repeat-1-running",
          "repeat": 1,
        },
      );
      await recorder.flushHostStream();
    } catch (error) {
      await _bestEffortTerminalCleanupAndRestore();
      recorder.diagnostic("suite-error", values: {"errorType": error.runtimeType.toString()});
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
    } finally {
      _running = false;
    }
  }

  Future<bool> _recoverCompletedBench1000BeforeOfflineRestart() async {
    if (_smoke) return false;

    final recorder = PerformanceBenchmarkService.instance;
    final stage = await recorder.getSuiteStage();
    if (stage != "main-download-bench100-done") return false;

    final requirement = await recorder.getDownloadCleanupRequirement();
    if (requirement == null || requirement["targetAlias"] != "bench-1000") {
      return false;
    }

    final target = await recorder.getTarget("bench-1000");
    if (target == null) return false;

    final container = GetIt.instance<ProviderContainer>();
    final item = await container.read(itemByIdProvider(BaseItemId(target.itemId)).future);
    if (item == null) return false;

    final downloads = GetIt.instance<DownloadsService>();
    final stub = DownloadStub.fromItem(type: DownloadItemType.collection, item: item);
    final progress = downloads.getPerformanceBenchmarkCollectionProgress(stub);
    final completeTracks = progress["completeTracks"] ?? 0;
    final totalTracks = progress["totalTracks"] ?? 0;
    final failedTracks = progress["failedTracks"] ?? 0;
    final activeTracks = progress["activeTracks"] ?? 0;
    if (totalTracks != 1000 ||
        completeTracks != 1000 ||
        failedTracks != 0 ||
        activeTracks != 0 ||
        !downloads.getStatus(stub, 1000).isDownloaded) {
      return false;
    }

    recorder.diagnostic(
      "bench1000-offline-transition-recovery-start",
      values: {"completeTracks": completeTracks, "failedTracks": failedTracks},
    );
    await _setBenchmarkOfflineState(true);
    await recorder.setSuiteStage("offline-bench1000-running");
    recorder.diagnostic(
      "offline-mode-forced",
      values: {"targetAlias": "bench-1000", "processRestart": true, "recoveredAfterInterruptedTransition": true},
    );
    recorder.diagnostic(
      "host-restart-requested",
      values: {"reason": "recover-offline-bench1000-transition", "nextStage": "offline-bench1000-running"},
    );
    await recorder.flushHostStream();
    return true;
  }

  Future<void> _recoverPendingDownloadCleanup({bool skipCurrentSuiteOwned = false}) async {
    final recorder = PerformanceBenchmarkService.instance;
    final requirement = await recorder.getDownloadCleanupRequirement();
    if (requirement == null) return;

    final ownerSuiteRunId = requirement["ownerSuiteRunId"] as String?;
    if (skipCurrentSuiteOwned && ownerSuiteRunId == PerformanceBenchmarkService.suiteRunId) {
      recorder.diagnostic("download-cleanup-recovery-deferred", values: {"reason": "current-suite-startup-work"});
      return;
    }

    final alias = requirement["targetAlias"] as String?;
    if (alias == null || alias.isEmpty) {
      await recorder.setDownloadCleanupRequired(targetAlias: "", required: false);
      return;
    }

    recorder.diagnostic("download-cleanup-recovery-start", values: {"targetAlias": alias});

    final previousOffline = await _benchmarkOfflineState();
    try {
      // Cleanup must be online so queued deletes can finish. This is a
      // temporary operational state only; restore the exact prior value below.
      if (previousOffline) {
        await _setBenchmarkOfflineState(false);
        await recorder.waitForNetworkQuiescence(
          quietPeriod: const Duration(milliseconds: 750),
          timeout: const Duration(minutes: 5),
        );
      }

      final storedItemId = requirement["targetItemId"] as String?;
      final storedItemType = requirement["targetItemType"] as String?;
      final target = storedItemId != null
          ? PerformanceBenchmarkTarget(alias: alias, itemType: storedItemType ?? "", itemId: storedItemId)
          : await recorder.getTarget(alias) ?? await recorder.getLegacyTargetForCleanup(alias);
      if (target == null) {
        recorder.diagnostic("download-cleanup-recovery-target-missing", values: {"targetAlias": alias});
        await recorder.setDownloadCleanupRequired(targetAlias: alias, required: false);
        return;
      }

      final downloads = GetIt.instance<DownloadsService>();
      final DownloadStub stub;

      if ((target.itemType == "finampCollection" || storedItemType == DownloadItemType.finampCollection.name) &&
          alias == "all-playlists-metadata") {
        stub = DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.allPlaylistsMetadata));
      } else {
        final container = GetIt.instance<ProviderContainer>();
        final item = await container.read(itemByIdProvider(BaseItemId(target.itemId)).future);
        if (item == null) {
          throw StateError("Benchmark cleanup target could not be resolved");
        }
        stub = DownloadStub.fromItem(type: DownloadItemType.collection, item: item);
      }

      await downloads.deleteDownload(stub: stub);
      await downloads.waitForPerformanceBenchmarkCleanup(stub: stub, timeout: const Duration(minutes: 10));
      await downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
        stableFor: const Duration(seconds: 2),
        timeout: const Duration(minutes: 10),
      );
      await recorder.setDownloadCleanupRequired(targetAlias: alias, required: false);

      recorder.diagnostic("download-cleanup-recovery-complete", values: {"targetAlias": alias});
    } finally {
      final currentOffline = await _benchmarkOfflineState();
      if (currentOffline != previousOffline) {
        await _setBenchmarkOfflineState(previousOffline);
        recorder.diagnostic("download-cleanup-recovery-offline-restored", values: {"offline": previousOffline});
      }
    }
  }

  Future<bool> _discoverAndValidateTargets({Map<String, int>? targets}) async {
    final api = GetIt.instance<JellyfinApiHelper>();
    final recorder = PerformanceBenchmarkService.instance;
    var allValid = true;

    for (final targetEntry in (targets ?? _benchmarkTargets).entries) {
      final alias = targetEntry.key;
      final expectedCount = targetEntry.value;

      await recorder.startRun(
        scenario: "benchmark-target-validation",
        variant: PerformanceBenchmarkService.variant,
        mode: "online",
        targetAlias: alias,
        targetType: "Playlist",
      );

      try {
        final normalizedAlias = alias.trim().toLowerCase();

        final matches = await recorder.runStep(
          name: "playlist-discovery",
          operation: () async {
            const pageSize = 200;
            var startIndex = 0;
            final matches = <BaseItemDto>[];

            while (true) {
              final page = await api.getItemsWithTotalRecordCount(
                includeItemTypes: "Playlist",
                recursive: true,
                startIndex: startIndex,
                limit: pageSize,
              );
              final items = page.items ?? const <BaseItemDto>[];
              matches.addAll(
                items.where((item) {
                  final normalizedName = item.name?.trim().toLowerCase();
                  return normalizedName == normalizedAlias || normalizedName == "$normalizedAlias [smart]";
                }),
              );

              if (items.length < pageSize) break;
              startIndex += items.length;
            }

            return matches;
          },
        );

        recorder.metric("matchingPlaylists", matches.length);
        if (matches.length != 1) {
          recorder.metric("valid", false);
          recorder.metric("expectedTrackCount", expectedCount);
          await recorder.finishRun();
          allValid = false;
          continue;
        }

        final playlist = matches.single;
        await recorder.saveTarget(alias: alias, itemType: "Playlist", itemId: playlist.id.raw);

        final children = await recorder.runStep(
          name: "playlist-track-resolution",
          timeout: const Duration(minutes: 5),
          operation: () => api.getItems(parentItem: playlist, includeItemTypes: "Audio", recursive: true),
        );

        if (alias == "bench-100" && children != null && children.isNotEmpty) {
          final deterministicChildren = [...children]..sort((a, b) => a.id.raw.compareTo(b.id.raw));
          final track = deterministicChildren.first;
          await recorder.saveTarget(alias: "detail-track", itemType: "Audio", itemId: track.id.raw);

          BaseItemId? albumId;
          BaseItemId? artistId;
          BaseItemId? genreId;
          for (final candidate in deterministicChildren) {
            albumId ??= candidate.albumId;
            if (artistId == null && (candidate.albumArtists?.isNotEmpty ?? false)) {
              artistId = candidate.albumArtists!.first.id;
            }
            if (artistId == null && (candidate.artistItems?.isNotEmpty ?? false)) {
              artistId = candidate.artistItems!.first.id;
            }
            if (genreId == null && (candidate.genreItems?.isNotEmpty ?? false)) {
              genreId = candidate.genreItems!.first.id;
            }
            if (albumId != null && artistId != null && genreId != null) break;
          }

          if (albumId != null) {
            await recorder.saveTarget(alias: "detail-album", itemType: "MusicAlbum", itemId: albumId.raw);
          }
          if (artistId != null) {
            await recorder.saveTarget(alias: "detail-artist", itemType: "MusicArtist", itemId: artistId.raw);
          }
          if (genreId != null) {
            await recorder.saveTarget(alias: "detail-genre", itemType: "MusicGenre", itemId: genreId.raw);
          }
        }

        final actualCount = children?.length ?? 0;
        final valid = actualCount == expectedCount;
        recorder.metric("expectedTrackCount", expectedCount);
        recorder.metric("resolvedTrackCount", actualCount);
        recorder.metric("valid", valid);
        await recorder.finishRun();

        if (!valid) allValid = false;
      } catch (_) {
        // runStep persists the failed/timeout run before rethrowing.
        allValid = false;
      }
    }

    return allValid;
  }

  Future<void> _runUiTabBaselines() async {
    final recorder = PerformanceBenchmarkService.instance;

    final rounds = _smoke
        ? const <List<String>>[
            ["home", "albums", "artists", "playlists", "tracks", "genres"],
          ]
        : const <List<String>>[
            ["home", "albums", "artists", "playlists", "tracks", "genres"],
            ["genres", "tracks", "playlists", "artists", "albums", "home"],
            ["playlists", "home", "albums", "genres", "artists", "tracks"],
          ];

    // Fixed delays are only stabilization boundaries and are deliberately
    // outside measured runs. "refreshed-view" means provider refresh inside
    // one running process; true cold-process measurements require relaunch.
    recorder.diagnostic("ui-stabilization-start", values: {"seconds": 3, "afterStartupQuiescence": true});
    await Future<void>.delayed(const Duration(seconds: 3));
    recorder.diagnostic("ui-stabilization-complete");

    for (var round = 0; round < rounds.length; round++) {
      recorder.diagnostic("ui-round-start", values: {"round": round + 1});

      for (final tab in rounds[round]) {
        await _runUiTabBaseline(tab, mode: "refreshed-view", round: round + 1);

        await _uiCooldown(recorder, tab);

        await _runUiTabBaseline(tab, mode: "warm-view", round: round + 1);

        await _uiCooldown(recorder, tab);
      }

      recorder.diagnostic("ui-round-complete", values: {"round": round + 1});
    }
  }

  Future<void> _waitForUiQuiescence({
    Duration quietPeriod = const Duration(milliseconds: 200),
    Duration timeout = const Duration(minutes: 15),
  }) async {
    // UI commands already complete only after their semantic provider state is
    // ready and a rendered frame has been observed. This barrier measures the
    // separate background tail: network/worker and image activity must all be
    // idle at the same time and remain generation-stable for one short guard
    // window. It avoids the old serial network/image/network 3 x 750 ms floor.
    await PerformanceBenchmarkService.instance.waitForUiActivityQuiescence(quietPeriod: quietPeriod, timeout: timeout);
  }

  Future<void> _settleUi({
    Duration quietPeriod = const Duration(milliseconds: 200),
    Duration schedulerCooldown = const Duration(seconds: 1),
  }) async {
    await _waitForUiQuiescence(quietPeriod: quietPeriod, timeout: const Duration(minutes: 15));
    if (schedulerCooldown > Duration.zero) {
      await Future<void>.delayed(schedulerCooldown);
    }
  }

  Future<void> _uiCooldown(PerformanceBenchmarkService recorder, String tab) async {
    recorder.diagnostic("ui-tab-cooldown-start", values: {"contentType": tab, "seconds": 5});
    await _settleUi(quietPeriod: const Duration(milliseconds: 750), schedulerCooldown: const Duration(seconds: 5));
    recorder.diagnostic("ui-tab-cooldown-complete", values: {"contentType": tab});
  }

  Future<void> _runUiTabBaseline(
    String tab, {
    required String mode,
    required int round,
    bool allowPendingDownloadCleanup = false,
  }) async {
    final recorder = PerformanceBenchmarkService.instance;

    await recorder.startRun(
      scenario: "ui-tab-first-rendered-content-$tab",
      variant: PerformanceBenchmarkService.variant,
      mode: mode,
      targetType: tab,
      allowPendingDownloadCleanup: allowPendingDownloadCleanup,
    );
    recorder.metric("round", round);

    try {
      await recorder.runStep(
        name: "ui-tab-open",
        timeout: const Duration(minutes: 10),
        operation: () => recorder.requestUiTab(
          contentType: tab,
          refresh: mode.contains("refreshed"),
          timeout: const Duration(minutes: 9, seconds: 30),
        ),
      );
      await recorder.runStep(
        name: "wait-ui-quiescent",
        timeout: const Duration(minutes: 16),
        operation: _waitForUiQuiescence,
      );
      await recorder.finishRun();
    } catch (_) {
      // runStep persists the failed/timeout run before rethrowing.
    }
  }

  Future<void> _runSearchBaselines() async {
    final recorder = PerformanceBenchmarkService.instance;
    final api = GetIt.instance<JellyfinApiHelper>();

    final configuredQueries = <(String, String, bool)>[
      ("query-1", PerformanceBenchmarkService.searchQuery1, true),
      if (!_smoke) ...[
        ("query-2", PerformanceBenchmarkService.searchQuery2, true),
        ("query-3", PerformanceBenchmarkService.searchQuery3, true),
        ("broad-1", "m", false),
      ],
    ];
    for (final (alias, query, _) in configuredQueries) {
      if (query.trim().isEmpty) {
        throw StateError("Benchmark search query $alias is not configured");
      }
    }

    const tabs = <String>["artists", "albums", "tracks"];

    for (final (queryAlias, artistQuery, deriveTargetChain) in configuredQueries) {
      // The user-provided private query names an artist. Album and track search
      // must use real album/track names rather than reusing the artist name.
      // Those derived strings remain device-local and are never exported.
      final tabQueries = <String, String>{
        "artists": artistQuery,
        if (!deriveTargetChain) ...{"albums": artistQuery, "tracks": artistQuery},
      };

      final artistResult = await api.getItemsWithTotalRecordCount(
        includeItemTypes: "MusicArtist",
        searchTerm: artistQuery,
        recursive: true,
        limit: 25,
      );
      final artistMatches = (artistResult.items ?? const <BaseItemDto>[])
          .where((item) => item.name?.trim().toLowerCase() == artistQuery.trim().toLowerCase())
          .toList();

      recorder.diagnostic(
        "search-target-discovery",
        values: {"queryAlias": queryAlias, "artistMatches": artistMatches.length},
      );

      if (deriveTargetChain) {
        if (artistMatches.length != 1) {
          throw StateError("Benchmark private artist query did not resolve uniquely");
        }

        final artist = artistMatches.single;
        await recorder.saveTarget(alias: "$queryAlias-artist", itemType: "MusicArtist", itemId: artist.id.raw);

        final albums = await api.getItems(
          parentItem: artist,
          includeItemTypes: "MusicAlbum",
          recursive: true,
          artistType: ArtistType.albumArtist,
          sortBy: "SortName",
          sortOrder: "Ascending",
        );
        if (albums == null || albums.isEmpty) {
          throw StateError("Benchmark artist has no album available for derived search");
        }

        final album = albums.first;
        final albumQuery = album.name?.trim();
        if (albumQuery == null || albumQuery.isEmpty) {
          throw StateError("Benchmark derived album has no searchable name");
        }
        tabQueries["albums"] = albumQuery;
        await recorder.saveTarget(alias: "$queryAlias-album", itemType: "MusicAlbum", itemId: album.id.raw);

        final tracks = await api.getItems(
          parentItem: album,
          includeItemTypes: "Audio",
          recursive: true,
          sortBy: "ParentIndexNumber,IndexNumber,SortName",
          sortOrder: "Ascending",
        );
        if (tracks == null || tracks.isEmpty) {
          throw StateError("Benchmark derived album has no track available for search");
        }

        final track = tracks.first;
        final trackQuery = track.name?.trim();
        if (trackQuery == null || trackQuery.isEmpty) {
          throw StateError("Benchmark derived track has no searchable name");
        }
        tabQueries["tracks"] = trackQuery;
        await recorder.saveTarget(alias: "$queryAlias-track", itemType: "Audio", itemId: track.id.raw);

        recorder.diagnostic(
          "search-derived-query-chain-ready",
          values: {
            "queryAlias": queryAlias,
            "artistQueryLength": artistQuery.length,
            "albumQueryLength": albumQuery.length,
            "trackQueryLength": trackQuery.length,
          },
        );
      }

      for (final tab in tabs) {
        final query = tabQueries[tab];
        if (query == null || query.isEmpty) {
          throw StateError("Benchmark search query for $queryAlias/$tab is unavailable");
        }
        final resultAlias = deriveTargetChain ? "$queryAlias-$tab" : queryAlias;
        String? resolvedSearchTab;

        // Return to the unfiltered list first. This is outside the measured run
        // and prevents the previous query from becoming hidden setup work.
        await recorder.requestSearch(
          contentType: tab,
          queryAlias: "clear",
          query: "",
          timeout: const Duration(minutes: 10),
        );
        await _settleUi();

        await recorder.startRun(
          scenario: "ui-search-$tab",
          variant: PerformanceBenchmarkService.variant,
          mode: "query-first",
          targetAlias: resultAlias,
          targetType: tab,
        );
        try {
          recorder.metric("queryLength", query.length);
          resolvedSearchTab = await recorder.runStep(
            name: "search",
            timeout: const Duration(minutes: 10),
            operation: () => recorder.requestSearch(
              contentType: tab,
              queryAlias: resultAlias,
              query: query,
              timeout: const Duration(minutes: 9, seconds: 30),
            ),
          );
          await recorder.runStep(
            name: "wait-ui-quiescent",
            timeout: const Duration(minutes: 16),
            operation: _waitForUiQuiescence,
          );
          await recorder.finishRun();
        } catch (_) {
          // runStep persists failures/timeouts.
        }

        await _settleUi(schedulerCooldown: const Duration(seconds: 1));

        await recorder.startRun(
          scenario: "ui-search-$tab",
          variant: PerformanceBenchmarkService.variant,
          mode: "query-warm",
          targetAlias: resultAlias,
          targetType: tab,
        );
        try {
          recorder.metric("queryLength", query.length);
          resolvedSearchTab = await recorder.runStep(
            name: "search",
            timeout: const Duration(minutes: 5),
            operation: () => recorder.requestSearch(
              contentType: tab,
              queryAlias: resultAlias,
              query: query,
              timeout: const Duration(minutes: 4, seconds: 30),
            ),
          );
          await recorder.runStep(
            name: "wait-ui-quiescent",
            timeout: const Duration(minutes: 16),
            operation: _waitForUiQuiescence,
          );
          await recorder.finishRun();
        } catch (_) {
          // runStep persists failures/timeouts.
        }

        if (queryAlias == "broad-1" && resolvedSearchTab != null) {
          for (var page = 2; page <= 6; page++) {
            await recorder.startRun(
              scenario: "ui-search-next-page-$tab",
              variant: PerformanceBenchmarkService.variant,
              mode: "broad-query-sequential",
              targetAlias: queryAlias,
              targetType: resolvedSearchTab,
            );
            recorder.metric("requestedPageOrdinal", page);

            var loadedPage = false;
            try {
              loadedPage = await recorder.runStep(
                name: "next-search-page",
                timeout: const Duration(minutes: 10),
                operation: () => recorder.requestNextPage(
                  contentType: resolvedSearchTab!,
                  timeout: const Duration(minutes: 9, seconds: 30),
                ),
              );
              if (loadedPage) {
                await recorder.runStep(
                  name: "wait-ui-quiescent",
                  timeout: const Duration(minutes: 16),
                  operation: _waitForUiQuiescence,
                );
              }
              await recorder.finishRun();
            } catch (_) {
              // runStep persists failures/timeouts.
            }

            if (!loadedPage) break;
            await _settleUi(schedulerCooldown: const Duration(seconds: 1));
          }
        }

        await _settleUi(schedulerCooldown: const Duration(seconds: 2));
      }
    }

    // Restore normal browsing before the next phase.
    await recorder.requestSearch(
      contentType: "tracks",
      queryAlias: "clear",
      query: "",
      timeout: const Duration(minutes: 10),
    );
    await _settleUi(schedulerCooldown: const Duration(seconds: 2));
  }

  Future<void> _runPagingBaselines() async {
    final recorder = PerformanceBenchmarkService.instance;
    const tabs = <String>["artists", "albums", "tracks", "playlists", "genres"];

    for (final requestedTab in tabs) {
      final resolvedTab = await recorder.requestUiTab(
        contentType: requestedTab,
        refresh: true,
        timeout: const Duration(minutes: 10),
      );
      await _settleUi(schedulerCooldown: const Duration(seconds: 2));

      final lastPage = _smoke ? 3 : 11;
      for (var page = 2; page <= lastPage; page++) {
        await recorder.startRun(
          scenario: "ui-next-page-$requestedTab",
          variant: PerformanceBenchmarkService.variant,
          mode: "online-sequential",
          targetType: resolvedTab,
        );
        recorder.metric("requestedPageOrdinal", page);

        var loadedPage = false;
        try {
          loadedPage = await recorder.runStep(
            name: "next-page",
            timeout: const Duration(minutes: 10),
            operation: () =>
                recorder.requestNextPage(contentType: resolvedTab, timeout: const Duration(minutes: 9, seconds: 30)),
          );
          if (loadedPage) {
            await recorder.runStep(
              name: "wait-ui-quiescent",
              timeout: const Duration(minutes: 16),
              operation: _waitForUiQuiescence,
            );
          }
          await recorder.finishRun();
        } catch (_) {
          // runStep persists failures/timeouts.
        }

        if (!loadedPage) break;
        await _settleUi();
      }

      await _settleUi(schedulerCooldown: const Duration(seconds: 2));
    }
  }

  Future<void> _runLargeQueueRestoreBaseline() async {
    final recorder = PerformanceBenchmarkService.instance;
    final queueService = GetIt.instance<QueueService>();

    final expectedAlias = _smoke ? "bench-10" : "bench-1000";
    final expectedTracks = _smoke ? 10 : 1000;
    final alreadyRestored = queueService.getQueue().trackCount;
    recorder.diagnostic(
      "queue-restore-benchmark-start",
      values: {
        "alreadyRestoredTracks": alreadyRestored,
        "targetAlias": expectedAlias,
        "expectedTracks": expectedTracks,
      },
    );

    if (alreadyRestored > 0) {
      await recorder.startRun(
        scenario: "persisted-queue-restore-verification",
        variant: PerformanceBenchmarkService.variant,
        mode: "startup-autoload",
        targetAlias: expectedAlias,
        targetType: "queue",
      );
      recorder.metric("expectedQueueLength", expectedTracks);
      recorder.metric("restoredQueueLength", alreadyRestored);
      if (alreadyRestored == expectedTracks) {
        await recorder.finishRun();
      } else {
        await recorder.failActiveRun(
          result: PerformanceBenchmarkResult.failed,
          error: StateError("Startup queue restore produced an unexpected track count"),
          stackTrace: StackTrace.current,
          step: "verify-startup-queue-restore",
        );
      }
    }

    if (alreadyRestored != expectedTracks) {
      if (alreadyRestored > 0) {
        await queueService.stopAndClearQueue();
        await recorder.waitForNetworkQuiescence(
          quietPeriod: const Duration(milliseconds: 750),
          timeout: const Duration(minutes: 5),
        );
        recorder.diagnostic("queue-restore-partial-autoload-cleared", values: {"partialTrackCount": alreadyRestored});
      }

      await recorder.startRun(
        scenario: "persisted-queue-restore",
        variant: PerformanceBenchmarkService.variant,
        mode: alreadyRestored == 0 ? "explicit-after-restart" : "explicit-after-partial-autoload",
        targetAlias: expectedAlias,
        targetType: "queue",
      );
      try {
        final restored = await recorder.runStep(
          name: "restore-persisted-queue",
          timeout: const Duration(minutes: 20),
          operation: queueService.restorePerformanceBenchmarkPersistedQueue,
        );
        recorder.metric("expectedQueueLength", expectedTracks);
        recorder.metric("restoredQueueLength", restored);
        if (restored != expectedTracks) {
          throw StateError("Persisted benchmark queue restored an unexpected track count");
        }
        await recorder.finishRun();
      } catch (error, stackTrace) {
        if (recorder.activeRun != null) {
          await recorder.failActiveRun(
            result: PerformanceBenchmarkResult.failed,
            error: error,
            stackTrace: stackTrace,
            step: "restore-persisted-queue",
          );
        }
      }
    }

    await queueService.clearPerformanceBenchmarkQueueState();
    await _settleUi(schedulerCooldown: const Duration(seconds: 1));
    recorder.diagnostic("queue-restore-benchmark-clean");
  }

  Future<void> _runImageCacheBaselines() async {
    final recorder = PerformanceBenchmarkService.instance;

    await _settleUi(schedulerCooldown: Duration.zero);
    await clearPerformanceBenchmarkImageCache();

    await _runUiTabBaseline("albums", mode: "image-cache-cold-refreshed", round: 1);
    await _settleUi(schedulerCooldown: const Duration(seconds: 2));
    await _runUiTabBaseline("albums", mode: "image-cache-warm-view", round: 1);
    await _settleUi(schedulerCooldown: const Duration(seconds: 2));

    // The detail experiment needs its own guaranteed cold image state. The
    // albums list above may already have rendered the deterministic target.
    await clearPerformanceBenchmarkImageCache();

    await _runDetailBaseline(
      targetAlias: "detail-album",
      detailType: "album",
      mode: "image-cache-cold-detail",
      refresh: true,
    );
    await _settleUi(schedulerCooldown: const Duration(seconds: 2));
    await _runDetailBaseline(
      targetAlias: "detail-album",
      detailType: "album",
      mode: "image-cache-warm-detail",
      refresh: false,
    );

    recorder.diagnostic("image-cache-baseline-complete");
    await recorder.waitForNetworkQuiescence(
      quietPeriod: const Duration(seconds: 3),
      timeout: const Duration(minutes: 3),
    );
  }

  Future<void> _runTargetedDownloadDiagnostics() async {
    if (_running) return;
    _running = true;

    final recorder = PerformanceBenchmarkService.instance;
    final bool bench1000 = PerformanceBenchmarkService.targetedDownloadBench1000;
    final String targetAlias = bench1000 ? "bench-1000" : "bench-100";
    final int expectedTracks = bench1000 ? 1000 : 100;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _ensureSuiteOnlineBaseline();
      await _recoverPendingDownloadCleanup();

      // The normal startup download queue is suppressed while a benchmark run
      // has no suite stage. This keeps unrelated persisted/metadata work out of
      // the targeted measurement instead of waiting for or mixing it into the
      // bench-100 sync graph.
      await recorder.waitForStartupScreenReady(timeout: const Duration(minutes: 15));
      await recorder.waitForNetworkQuiescence(
        quietPeriod: const Duration(seconds: 2),
        timeout: const Duration(minutes: 10),
      );

      final targetReady = await _discoverAndValidateTargets(targets: <String, int>{targetAlias: expectedTracks});
      if (!targetReady) {
        recorder.diagnostic("suite-blocked", values: {"reason": "target-validation", "targetAlias": targetAlias});
        return;
      }

      final completed = await _runDownloadLifecycle(targetAlias, expectedTracks, diagnosticsOnly: true);
      if (!completed) {
        throw StateError("Targeted $targetAlias download did not complete");
      }

      recorder.diagnostic("targeted-download-complete", values: {"targetAlias": targetAlias});
    } catch (error) {
      await _bestEffortTerminalCleanupAndRestore();
      recorder.diagnostic(
        "suite-error",
        values: {"phase": "targeted-download", "errorType": error.runtimeType.toString()},
      );
    } finally {
      await _restoreSuiteOriginalOfflineState();
      GetIt.instance<KeepScreenOnHelper>().setPerformanceBenchmarkOverride(false);
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
      _running = false;
    }
  }

  Future<String> _runDownloadAndOfflineBaselines(String? currentStage) async {
    final recorder = PerformanceBenchmarkService.instance;
    var stage = currentStage ?? "main-playback-done";

    final entries = _smoke
        ? const <(String, int, String)>[("bench-10", 10, "main-download-bench10-done")]
        : const <(String, int, String)>[
            ("bench-10", 10, "main-download-bench10-done"),
            ("bench-100", 100, "main-download-bench100-done"),
            ("bench-1000", 1000, "main-download-bench1000-done"),
          ];

    for (final entry in entries) {
      final (alias, expectedTracks, completedStage) = entry;
      if (_stageAtOrAfter(stage, completedStage)) {
        continue;
      }

      try {
        final completed = await _runDownloadLifecycle(alias, expectedTracks);
        if (!completed) {
          return stage;
        }
      } catch (error) {
        recorder.diagnostic(
          "download-target-phase-error",
          values: {"targetAlias": alias, "errorType": error.runtimeType.toString()},
        );
        // A sub-run may fail explicitly and still return normally. Reaching
        // this catch means harness/lifecycle work failed outside that measured
        // run, so cleanup first and then abort without writing a done stage.
        await _recoverPendingDownloadCleanup();
        rethrow;
      }

      await recorder.setSuiteStage(completedStage);
      stage = completedStage;
      await Future<void>.delayed(const Duration(seconds: 5));
    }

    return stage;
  }

  Future<bool> _runDownloadLifecycle(String targetAlias, int expectedTracks, {bool diagnosticsOnly = false}) async {
    final recorder = PerformanceBenchmarkService.instance;
    final downloads = GetIt.instance<DownloadsService>();
    final container = GetIt.instance<ProviderContainer>();
    final target = await recorder.getTarget(targetAlias);
    if (target == null) {
      recorder.diagnostic("download-target-missing", values: {"targetAlias": targetAlias});
      await _recordUnavailableTargetRun(
        scenario: "download-lifecycle",
        mode: "online-download",
        targetAlias: targetAlias,
        targetType: "playlist",
        step: "target-missing",
      );
      return true;
    }

    final item = await container.read(itemByIdProvider(BaseItemId(target.itemId)).future);
    if (item == null) {
      recorder.diagnostic("download-target-unresolvable", values: {"targetAlias": targetAlias});
      await _recordUnavailableTargetRun(
        scenario: "download-lifecycle",
        mode: "online-download",
        targetAlias: targetAlias,
        targetType: "playlist",
        step: "target-unresolvable",
      );
      return true;
    }

    final stub = DownloadStub.fromItem(type: DownloadItemType.collection, item: item);

    // The benchmark owns these three downloads in its isolated app bundle.
    // Always start from a verified clean state.
    final existingStatus = downloads.getStatus(stub, expectedTracks);
    if (existingStatus.isDownloaded) {
      await downloads.deleteDownload(stub: stub);
      await downloads.waitForPerformanceBenchmarkCleanup(stub: stub, timeout: const Duration(minutes: 10));
    }

    final internalLocation = FinampSettingsHelper.finampSettings.internalTrackDir;
    final profile = DownloadProfile(
      transcodeCodec: FinampTranscodingCodec.original,
      downloadLocationId: internalLocation.id,
    );

    await recorder.startRun(
      scenario: "download-lifecycle",
      variant: PerformanceBenchmarkService.variant,
      mode: "online-download",
      targetAlias: targetAlias,
      targetType: "playlist",
    );

    try {
      recorder.metric("expectedTrackCount", expectedTracks);
      recorder.metric("downloadMaxConcurrentTransfers", FinampSettingsHelper.finampSettings.maxConcurrentDownloads);
      recorder.metric("downloadSyncWorkers", FinampSettingsHelper.finampSettings.downloadWorkers);
      recorder.metric("downloadUsesOriginalCodec", true);
      // Arm these before planning because transfers can begin while the sync
      // graph is still being expanded. Large collections can legitimately spend
      // far longer than a few minutes in planning, so the event futures must not
      // expire independently while that work is still in progress.
      const downloadLifecycleEventTimeout = Duration(hours: 3);
      final firstTransfer = recorder.waitForEvent(
        "download-first-transfer-start",
        timeout: downloadLifecycleEventTimeout,
      );
      final firstTrack = recorder.waitForEvent("download-first-track-complete", timeout: downloadLifecycleEventTimeout);
      unawaited(firstTransfer.then<void>((_) {}, onError: (_) {}));
      unawaited(firstTrack.then<void>((_) {}, onError: (_) {}));

      await recorder.runStep(
        name: "download-plan-and-enqueue",
        timeout: const Duration(hours: 2),
        operation: () => downloads.addDownload(stub: stub, transcodeProfile: profile),
      );

      await recorder.runStep(
        name: "wait-first-transfer",
        timeout: downloadLifecycleEventTimeout,
        operation: () => firstTransfer,
      );
      await recorder.runStep(
        name: "wait-first-track-complete",
        timeout: downloadLifecycleEventTimeout,
        operation: () => firstTrack,
      );
      await recorder.runStep(
        name: "wait-full-download",
        timeout: const Duration(hours: 2),
        operation: () => _waitForDownloadComplete(downloads, stub, expectedTracks, targetAlias),
      );
      await recorder.runStep(
        name: "wait-download-system-idle",
        timeout: const Duration(minutes: 30),
        operation: () => downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
          stableFor: const Duration(seconds: 5),
          timeout: const Duration(minutes: 25),
        ),
      );
      recorder.mark("download-all-transfers-settled");

      final bytes = await recorder.runStep(
        name: "measure-downloaded-bytes",
        timeout: const Duration(minutes: 5),
        operation: () => downloads.getFileSize(stub),
      );
      recorder.metric("downloadedBytes", bytes);
      recorder.metric("resolvedTrackCount", expectedTracks);

      final run = recorder.activeRun;
      if (run != null) {
        int? transferStartMicros;
        int? transferCompleteMicros;
        for (final event in run.events) {
          if (event.name == "download-first-transfer-start") {
            transferStartMicros ??= event.elapsedMicros;
          } else if (event.name == "download-all-transfers-settled") {
            transferCompleteMicros = event.elapsedMicros;
          }
        }
        if (transferStartMicros != null &&
            transferCompleteMicros != null &&
            transferCompleteMicros > transferStartMicros) {
          final transferMicros = transferCompleteMicros - transferStartMicros;
          recorder.metric("downloadTransferMicros", transferMicros);
          recorder.metric("downloadBytesPerSecond", bytes * 1000000.0 / transferMicros);
        }
      }

      await recorder.finishRun();
    } catch (_) {
      rethrow;
    }

    if (diagnosticsOnly) {
      await _cleanupDownloadedBenchmarkTarget(targetAlias: targetAlias, stub: stub, downloads: downloads);
      return true;
    }

    await recorder.startRun(
      scenario: "filesystem-read-reference",
      variant: PerformanceBenchmarkService.variant,
      mode: "sequential-local-read",
      targetAlias: targetAlias,
      targetType: "downloaded-files",
      allowPendingDownloadCleanup: true,
    );
    try {
      final read = await recorder.runStep(
        name: "sequential-read",
        timeout: const Duration(hours: 1),
        operation: () => downloads.readPerformanceBenchmarkFiles(stub),
      );
      final fileCount = read["fileCount"] ?? 0;
      final readBytes = read["bytes"] ?? 0;
      final durationMicros = read["durationMicros"] ?? 0;
      recorder.metric("filesystemFileCount", fileCount);
      recorder.metric("filesystemBytesRead", readBytes);
      recorder.metric("filesystemReadMicros", durationMicros);
      if (durationMicros > 0) {
        recorder.metric("filesystemBytesPerSecond", readBytes * 1000000.0 / durationMicros);
      }
      await recorder.finishRun();
    } catch (error, stackTrace) {
      if (recorder.activeRun != null) {
        await recorder.failActiveRun(
          result: PerformanceBenchmarkResult.failed,
          error: error,
          stackTrace: stackTrace,
          step: "sequential-read",
        );
      }
    }

    if (targetAlias == "bench-100") {
      await recorder.startRun(
        scenario: "download-resync",
        variant: PerformanceBenchmarkService.variant,
        mode: "force-full-sync",
        targetAlias: targetAlias,
        targetType: "playlist",
        allowPendingDownloadCleanup: true,
      );
      try {
        await recorder.runStep(
          name: "resync",
          timeout: const Duration(minutes: 30),
          operation: () => downloads.resync(stub, null, forceSync: true),
        );
        await recorder.runStep(
          name: "wait-download-system-idle",
          timeout: const Duration(minutes: 30),
          operation: () => downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
            stableFor: const Duration(seconds: 5),
            timeout: const Duration(minutes: 25),
          ),
        );
        await recorder.runStep(
          name: "verify-resync-complete",
          timeout: const Duration(minutes: 10),
          operation: () => downloads.waitForPerformanceBenchmarkDownload(
            stub: stub,
            expectedTracks: 100,
            timeout: const Duration(minutes: 9),
          ),
        );
        await recorder.finishRun();
      } catch (error, stackTrace) {
        if (recorder.activeRun != null) {
          await recorder.failActiveRun(
            result: PerformanceBenchmarkResult.failed,
            error: error,
            stackTrace: stackTrace,
            step: "download-resync",
          );
        }
      }

      await recorder.startRun(
        scenario: "download-repair",
        variant: PerformanceBenchmarkService.variant,
        mode: "full-repair",
        targetAlias: targetAlias,
        targetType: "downloads",
        allowPendingDownloadCleanup: true,
      );
      try {
        await recorder.runStep(
          name: "repair-all-downloads",
          timeout: const Duration(hours: 1),
          operation: downloads.repairAllDownloads,
        );
        await recorder.runStep(
          name: "wait-download-system-idle",
          timeout: const Duration(minutes: 30),
          operation: () => downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
            stableFor: const Duration(seconds: 5),
            timeout: const Duration(minutes: 25),
          ),
        );
        await recorder.runStep(
          name: "verify-repair-complete",
          timeout: const Duration(minutes: 10),
          operation: () => downloads.waitForPerformanceBenchmarkDownload(
            stub: stub,
            expectedTracks: 100,
            timeout: const Duration(minutes: 9),
          ),
        );
        await recorder.finishRun();
      } catch (error, stackTrace) {
        if (recorder.activeRun != null) {
          await recorder.failActiveRun(
            result: PerformanceBenchmarkResult.failed,
            error: error,
            stackTrace: stackTrace,
            step: "download-repair",
          );
        }
      }
    }

    final onlineTracks = await GetIt.instance<JellyfinApiHelper>().getItems(
      parentItem: item,
      includeItemTypes: "Audio",
      recursive: true,
      limit: 1,
    );
    final privateOfflineSearchQuery = (onlineTracks?.isNotEmpty ?? false) ? onlineTracks!.first.name : null;

    final previousOffline = await _benchmarkOfflineState();

    if (targetAlias == "bench-1000") {
      await _setBenchmarkOfflineState(true);
      await recorder.setSuiteStage("offline-bench1000-running");
      recorder.diagnostic("offline-mode-forced", values: {"targetAlias": targetAlias, "processRestart": true});
      recorder.diagnostic(
        "host-restart-requested",
        values: {"reason": "offline-bench1000-cold-process", "nextStage": "offline-bench1000-running"},
      );
      await recorder.flushHostStream();
      return false;
    }

    try {
      await _setBenchmarkOfflineState(true);
      recorder.diagnostic("offline-mode-forced", values: {"targetAlias": targetAlias, "processRestart": false});
      await _settleUi();

      await _runOfflineDownloadedScenarios(
        targetAlias: targetAlias,
        item: item,
        privateOfflineSearchQuery: privateOfflineSearchQuery,
        coldProcess: false,
      );
    } finally {
      await _setBenchmarkOfflineState(previousOffline);
      recorder.diagnostic(
        "offline-mode-restored",
        values: {"targetAlias": targetAlias, "restoredOffline": previousOffline},
      );
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (_smoke && targetAlias == "bench-10") {
      final persistedQueueCount = await GetIt.instance<QueueService>().persistPerformanceBenchmarkQueue();
      recorder.diagnostic(
        "smoke-queue-persisted",
        values: {"targetAlias": targetAlias, "trackCount": persistedQueueCount},
      );
      final preservedTracks = await GetIt.instance<QueueService>()
          .clearActiveQueuePreservingPerformanceBenchmarkSnapshot();
      if (preservedTracks != persistedQueueCount) {
        throw StateError("Smoke queue snapshot changed while preparing explicit restore");
      }
    }

    await _cleanupDownloadedBenchmarkTarget(targetAlias: targetAlias, stub: stub, downloads: downloads);

    return true;
  }

  Future<void> _runOfflineDownloadedScenarios({
    required String targetAlias,
    required BaseItemDto item,
    required String? privateOfflineSearchQuery,
    required bool coldProcess,
  }) async {
    final recorder = PerformanceBenchmarkService.instance;
    final refreshedMode = coldProcess ? "local-downloaded-cold-process-refreshed" : "local-downloaded-refreshed";
    final warmMode = coldProcess ? "local-downloaded-cold-process-warm" : "local-downloaded-warm";
    final firstMode = coldProcess ? "local-downloaded-cold-process" : "local-downloaded-first";

    await _runUiTabBaseline("tracks", mode: refreshedMode, round: 1, allowPendingDownloadCleanup: true);
    await _settleUi();
    await _runUiTabBaseline("tracks", mode: warmMode, round: 1, allowPendingDownloadCleanup: true);
    await _settleUi();

    final offlineTracksTab = await recorder.requestUiTab(
      contentType: "tracks",
      refresh: true,
      timeout: const Duration(minutes: 10),
    );
    await _settleUi();

    final offlineLastPage = _smoke ? 2 : 4;
    for (var page = 2; page <= offlineLastPage; page++) {
      await recorder.startRun(
        scenario: "offline-next-page-tracks",
        variant: PerformanceBenchmarkService.variant,
        mode: coldProcess ? "local-downloaded-cold-process" : "local-downloaded",
        targetAlias: targetAlias,
        targetType: offlineTracksTab,
        allowPendingDownloadCleanup: true,
      );
      recorder.metric("requestedPageOrdinal", page);
      var loadedPage = false;
      try {
        loadedPage = await recorder.runStep(
          name: "next-page",
          timeout: const Duration(minutes: 10),
          operation: () =>
              recorder.requestNextPage(contentType: offlineTracksTab, timeout: const Duration(minutes: 9, seconds: 30)),
        );
        if (loadedPage) {
          await recorder.runStep(
            name: "wait-ui-quiescent",
            timeout: const Duration(minutes: 16),
            operation: _waitForUiQuiescence,
          );
        }
        await recorder.finishRun();
      } catch (_) {
        // runStep persists failures/timeouts.
      }
      if (!loadedPage) break;
      await _settleUi();
    }

    // Exercise the exact same real fast-scroller path while Finamp is
    // forced offline. This exposes local metadata/list scaling separately from
    // server paging and makes the online/offline comparison symmetric.
    final offlineAlphabetTab = await recorder.requestUiTab(
      contentType: "tracks",
      refresh: true,
      timeout: const Duration(minutes: 10),
    );
    await _settleUi();

    final offlineLetters = _smoke ? const <String>["A", "Z"] : const <String>["#", "A", "G", "M", "Z"];
    for (final letter in offlineLetters) {
      await recorder.startRun(
        scenario: "offline-alphabet-jump-tracks-$letter",
        variant: PerformanceBenchmarkService.variant,
        mode: coldProcess
            ? "local-downloaded-cold-process-refreshed-sequential"
            : "local-downloaded-refreshed-sequential",
        targetAlias: targetAlias,
        targetType: offlineAlphabetTab,
        allowPendingDownloadCleanup: true,
      );
      try {
        recorder.metric("letter", letter);
        await recorder.runStep(
          name: "alphabet-jump",
          timeout: const Duration(minutes: 30),
          operation: () => recorder.requestAlphabetJump(
            contentType: offlineAlphabetTab,
            letter: letter,
            timeout: const Duration(minutes: 29, seconds: 30),
          ),
        );
        await recorder.runStep(
          name: "wait-ui-quiescent",
          timeout: const Duration(minutes: 16),
          operation: _waitForUiQuiescence,
        );
        await recorder.finishRun();
      } catch (_) {
        // runStep persists failures/timeouts.
      }
      await _settleUi(schedulerCooldown: const Duration(seconds: 1));
    }

    for (final letter in offlineLetters) {
      await recorder.startRun(
        scenario: "offline-alphabet-jump-tracks-$letter",
        variant: PerformanceBenchmarkService.variant,
        mode: coldProcess ? "local-downloaded-cold-process-warm-loaded" : "local-downloaded-warm-loaded",
        targetAlias: targetAlias,
        targetType: offlineAlphabetTab,
        allowPendingDownloadCleanup: true,
      );
      try {
        recorder.metric("letter", letter);
        await recorder.runStep(
          name: "alphabet-jump",
          timeout: const Duration(minutes: 5),
          operation: () => recorder.requestAlphabetJump(
            contentType: offlineAlphabetTab,
            letter: letter,
            timeout: const Duration(minutes: 4, seconds: 30),
          ),
        );
        await recorder.runStep(
          name: "wait-ui-quiescent",
          timeout: const Duration(minutes: 16),
          operation: _waitForUiQuiescence,
        );
        await recorder.finishRun();
      } catch (_) {
        // runStep persists failures/timeouts.
      }
      await _settleUi(schedulerCooldown: const Duration(milliseconds: 750));
    }

    if (privateOfflineSearchQuery != null && privateOfflineSearchQuery.trim().isNotEmpty) {
      await recorder.startRun(
        scenario: "offline-search-tracks",
        variant: PerformanceBenchmarkService.variant,
        mode: firstMode,
        targetAlias: targetAlias,
        targetType: "tracks",
        allowPendingDownloadCleanup: true,
      );
      try {
        await recorder.runStep(
          name: "search",
          timeout: const Duration(minutes: 10),
          operation: () => recorder.requestSearch(
            contentType: "tracks",
            queryAlias: "download-target-track",
            query: privateOfflineSearchQuery,
            timeout: const Duration(minutes: 9, seconds: 30),
          ),
        );
        await recorder.runStep(
          name: "wait-ui-quiescent",
          timeout: const Duration(minutes: 16),
          operation: _waitForUiQuiescence,
        );
        await recorder.finishRun();
      } catch (_) {
        // runStep persists failures/timeouts.
      }

      await _settleUi();
      await recorder.startRun(
        scenario: "offline-search-tracks",
        variant: PerformanceBenchmarkService.variant,
        mode: warmMode,
        targetAlias: targetAlias,
        targetType: "tracks",
        allowPendingDownloadCleanup: true,
      );
      try {
        await recorder.runStep(
          name: "search",
          timeout: const Duration(minutes: 5),
          operation: () => recorder.requestSearch(
            contentType: "tracks",
            queryAlias: "download-target-track",
            query: privateOfflineSearchQuery,
            timeout: const Duration(minutes: 4, seconds: 30),
          ),
        );
        await recorder.runStep(
          name: "wait-ui-quiescent",
          timeout: const Duration(minutes: 16),
          operation: _waitForUiQuiescence,
        );
        await recorder.finishRun();
      } catch (_) {
        // runStep persists failures/timeouts.
      }

      await recorder.requestSearch(
        contentType: "tracks",
        queryAlias: "clear",
        query: "",
        timeout: const Duration(minutes: 10),
      );
      await _settleUi();
    }

    await _runDetailBaseline(
      targetAlias: targetAlias,
      detailType: "playlist",
      mode: refreshedMode,
      refresh: true,
      allowPendingDownloadCleanup: true,
    );
    await _settleUi();
    await _runDetailBaseline(
      targetAlias: targetAlias,
      detailType: "playlist",
      mode: warmMode,
      refresh: false,
      allowPendingDownloadCleanup: true,
    );
    await _settleUi();

    await _runPlaybackBaseline(
      targetAlias: targetAlias,
      playableType: "playlist",
      mode: firstMode,
      allowPendingDownloadCleanup: true,
    );
    await GetIt.instance<MusicPlayerBackgroundTask>().pause(disableFade: true);
    await Future<void>.delayed(const Duration(seconds: 1));

    await _runPlaybackBaseline(
      targetAlias: targetAlias,
      playableType: "playlist",
      mode: warmMode,
      allowPendingDownloadCleanup: true,
    );
    await GetIt.instance<MusicPlayerBackgroundTask>().pause(disableFade: true);
  }

  Future<void> _cleanupDownloadedBenchmarkTarget({
    required String targetAlias,
    required DownloadStub stub,
    required DownloadsService downloads,
  }) async {
    final recorder = PerformanceBenchmarkService.instance;
    await recorder.startRun(
      scenario: "download-cleanup",
      variant: PerformanceBenchmarkService.variant,
      mode: "cleanup",
      targetAlias: targetAlias,
      targetType: "playlist",
      allowPendingDownloadCleanup: true,
    );
    try {
      await recorder.runStep(
        name: "delete-download",
        timeout: const Duration(minutes: 30),
        operation: () => downloads.deleteDownload(stub: stub),
      );
      await recorder.runStep(
        name: "verify-download-removed",
        timeout: const Duration(minutes: 10),
        operation: () => downloads.waitForPerformanceBenchmarkCleanup(stub: stub, timeout: const Duration(minutes: 9)),
      );
      await recorder.runStep(
        name: "cleanup-download-system-idle",
        timeout: const Duration(minutes: 15),
        operation: () => downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
          stableFor: const Duration(seconds: 3),
          timeout: const Duration(minutes: 14),
        ),
      );
      final remainingBytes = await downloads.getFileSize(stub);
      recorder.metric("remainingDownloadedBytes", remainingBytes);
      if (remainingBytes != 0) {
        throw StateError("Benchmark download cleanup left local bytes");
      }
      await recorder.setDownloadCleanupRequired(targetAlias: targetAlias, required: false);
      await recorder.finishRun();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _runOfflineBench1000PostRestart() async {
    if (_running) return;
    _running = true;

    final recorder = PerformanceBenchmarkService.instance;
    const targetAlias = "bench-1000";

    try {
      var stage = await recorder.getSuiteStage() ?? "offline-bench1000-running";

      final target = await recorder.getTarget(targetAlias);
      if (target == null) {
        throw StateError("Offline benchmark target is unavailable");
      }

      final container = GetIt.instance<ProviderContainer>();
      final downloads = GetIt.instance<DownloadsService>();

      // The benchmark-owned download may intentionally survive this process
      // restart. Do not invoke generic pending-download cleanup until all
      // offline cold-process scenarios have completed.
      if (stage == "offline-bench1000-running") {
        await _setBenchmarkOfflineState(true);

        await WidgetsBinding.instance.endOfFrame;
        await _waitForStartupReady(phase: "offline-bench1000-cold-process");

        final item = await container.read(itemByIdProvider(BaseItemId(target.itemId)).future);
        if (item == null) {
          throw StateError("Offline benchmark item is unavailable");
        }

        final stub = DownloadStub.fromItem(type: DownloadItemType.collection, item: item);
        if (!downloads.getStatus(stub, 1000).isDownloaded) {
          throw StateError("Offline benchmark download is incomplete after process restart");
        }

        final tracks = await downloads.getCollectionTracks(item, playable: true);
        final privateOfflineSearchQuery = tracks.isNotEmpty ? tracks.first.name : null;

        await _runOfflineDownloadedScenarios(
          targetAlias: targetAlias,
          item: item,
          privateOfflineSearchQuery: privateOfflineSearchQuery,
          coldProcess: true,
        );

        final persistedQueueCount = await GetIt.instance<QueueService>().persistPerformanceBenchmarkQueue();
        recorder.diagnostic(
          "offline-large-queue-persisted",
          values: {"targetAlias": targetAlias, "trackCount": persistedQueueCount},
        );

        await recorder.setSuiteStage("offline-bench1000-cleanup");
        stage = "offline-bench1000-cleanup";
      }

      if (stage == "offline-bench1000-cleanup") {
        await _setBenchmarkOfflineState(false);
        recorder.diagnostic(
          "offline-mode-restored",
          values: {
            "targetAlias": targetAlias,
            "restoredOffline": false,
            "afterProcessRestart": true,
            "scope": "suite-online-baseline",
          },
        );

        final item = await container.read(itemByIdProvider(BaseItemId(target.itemId)).future);
        if (item == null) {
          throw StateError("Benchmark target could not be resolved for cleanup");
        }
        final stub = DownloadStub.fromItem(type: DownloadItemType.collection, item: item);

        await _cleanupDownloadedBenchmarkTarget(targetAlias: targetAlias, stub: stub, downloads: downloads);
        await recorder.setSuiteStage("main-download-bench1000-done");
        await recorder.setSuiteStage("main-download-done");
        recorder.diagnostic(
          "host-restart-requested",
          values: {"reason": "return-online-after-offline-cold-process", "nextStage": "main-download-done"},
        );
        await recorder.flushHostStream();
      }
    } catch (error) {
      await _bestEffortTerminalCleanupAndRestore();
      recorder.diagnostic(
        "suite-error",
        values: {"phase": "offline-bench1000-cold-process", "errorType": error.runtimeType.toString()},
      );
      recorder.stopHeartbeat();
      await recorder.flushHostStream();
    } finally {
      _running = false;
    }
  }

  Future<void> _waitForDownloadComplete(
    DownloadsService downloads,
    DownloadStub stub,
    int expectedTracks,
    String targetAlias,
  ) async {
    final recorder = PerformanceBenchmarkService.instance;
    final progress = await downloads.waitForPerformanceBenchmarkDownload(
      stub: stub,
      expectedTracks: expectedTracks,
      timeout: const Duration(hours: 2),
    );
    recorder.diagnostic(
      "download-progress-final",
      values: {
        "targetAlias": targetAlias,
        "expectedTracks": expectedTracks,
        "totalTracks": progress["totalTracks"] ?? 0,
        "completeTracks": progress["completeTracks"] ?? 0,
        "failedTracks": progress["failedTracks"] ?? 0,
      },
    );
  }

  Future<void> _runSearchDrilldownBaselines() async {
    final queryAliases = _smoke ? const <String>["query-1"] : const <String>["query-1", "query-2", "query-3"];
    for (final queryAlias in queryAliases) {
      await _runSearchDrilldown(queryAlias);
      await _settleUi(schedulerCooldown: const Duration(seconds: 4));
    }
  }

  Future<void> _runSearchDrilldown(String queryAlias) async {
    final recorder = PerformanceBenchmarkService.instance;
    final artistTarget = await recorder.getTarget("$queryAlias-artist");
    final albumTarget = await recorder.getTarget("$queryAlias-album");
    final trackTarget = await recorder.getTarget("$queryAlias-track");

    if (artistTarget == null || albumTarget == null || trackTarget == null) {
      recorder.diagnostic("search-drilldown-target-missing", values: {"queryAlias": queryAlias});
      await _recordUnavailableTargetRun(
        scenario: "artist-album-track-drilldown",
        mode: "online-sequential",
        targetAlias: queryAlias,
        targetType: "artist-album-track",
        step: "target-missing",
      );
      return;
    }

    final container = GetIt.instance<ProviderContainer>();
    final artist = await container.read(itemByIdProvider(BaseItemId(artistTarget.itemId)).future);
    final album = await container.read(itemByIdProvider(BaseItemId(albumTarget.itemId)).future);
    final track = await container.read(itemByIdProvider(BaseItemId(trackTarget.itemId)).future);
    if (artist == null || album == null || track == null) {
      recorder.diagnostic("search-drilldown-target-unresolvable", values: {"queryAlias": queryAlias});
      await _recordUnavailableTargetRun(
        scenario: "artist-album-track-drilldown",
        mode: "online-sequential",
        targetAlias: queryAlias,
        targetType: "artist-album-track",
        step: "target-unresolvable",
      );
      return;
    }

    final navigator = GlobalSnackbar.navigatorState;
    if (navigator == null) {
      recorder.diagnostic("search-drilldown-navigator-missing", values: {"queryAlias": queryAlias});
      await _recordUnavailableTargetRun(
        scenario: "artist-album-track-drilldown",
        mode: "online-sequential",
        targetAlias: queryAlias,
        targetType: "artist-album-track",
        step: "navigator-missing",
      );
      return;
    }

    await recorder.startRun(
      scenario: "artist-album-track-drilldown",
      variant: PerformanceBenchmarkService.variant,
      mode: "online-sequential",
      targetAlias: queryAlias,
      targetType: "artist-album-track",
    );

    try {
      await recorder.runStep(
        name: "artist-open",
        timeout: const Duration(minutes: 15),
        operation: () => recorder.requestDetail(
          targetAlias: "$queryAlias-artist",
          targetType: "artist",
          itemId: artistTarget.itemId,
          refresh: true,
          timeout: const Duration(minutes: 14, seconds: 30),
          open: () {
            navigator.push(MaterialPageRoute<ArtistScreen>(builder: (_) => ArtistScreen(widgetArtist: artist)));
          },
        ),
      );
      recorder.mark("drilldown-artist-ready", values: {"queryAlias": queryAlias});
      await _waitForUiQuiescence();

      await recorder.runStep(
        name: "album-open",
        timeout: const Duration(minutes: 15),
        operation: () => recorder.requestDetail(
          targetAlias: "$queryAlias-album",
          targetType: "album",
          itemId: albumTarget.itemId,
          refresh: true,
          timeout: const Duration(minutes: 14, seconds: 30),
          open: () {
            navigator.push(MaterialPageRoute<AlbumScreen>(builder: (_) => AlbumScreen(parent: album)));
          },
        ),
      );
      recorder.mark("drilldown-album-ready", values: {"queryAlias": queryAlias});
      await _waitForUiQuiescence();

      final playable = Track.fromItem(track);
      final slice = await recorder.runStep(
        name: "track-playable-slice",
        timeout: const Duration(minutes: 5),
        operation: () => container.read(getPlayableSliceProvider(item: playable, startingOffset: 0).future),
      );

      final readyFuture = recorder.waitForEvent("player-processing-ready", timeout: const Duration(minutes: 3));
      final playingFuture = recorder.waitForEvent("player-playing", timeout: const Duration(minutes: 3));
      final usefulBufferFuture = recorder.waitForEvent(
        "player-useful-buffer-ready",
        timeout: const Duration(minutes: 3),
      );
      final firstPositionFuture = recorder.waitForEvent(
        "player-first-position-advance",
        timeout: const Duration(minutes: 3),
      );
      unawaited(readyFuture.then<void>((_) {}, onError: (_) {}));
      unawaited(playingFuture.then<void>((_) {}, onError: (_) {}));
      unawaited(usefulBufferFuture.then<void>((_) {}, onError: (_) {}));
      unawaited(firstPositionFuture.then<void>((_) {}, onError: (_) {}));

      await recorder.runStep(
        name: "track-start",
        timeout: const Duration(minutes: 10),
        operation: () => GetIt.instance<QueueService>().startSlicePlayback(slice),
      );
      await recorder.runStep(name: "track-ready", timeout: const Duration(minutes: 3), operation: () => readyFuture);
      await recorder.runStep(
        name: "track-playing",
        timeout: const Duration(minutes: 3),
        operation: () => playingFuture,
      );
      await recorder.runStep(
        name: "track-useful-buffer",
        timeout: const Duration(minutes: 3),
        operation: () => usefulBufferFuture,
      );
      await recorder.runStep(
        name: "track-first-position",
        timeout: const Duration(minutes: 3),
        operation: () => firstPositionFuture,
      );
      recorder.mark("drilldown-track-playing", values: {"queryAlias": queryAlias});
      await recorder.finishRun();
    } catch (error, stackTrace) {
      if (recorder.activeRun != null) {
        await recorder.failActiveRun(
          result: PerformanceBenchmarkResult.failed,
          error: error,
          stackTrace: stackTrace,
          step: "artist-album-track-drilldown",
        );
      }
    } finally {
      await GetIt.instance<MusicPlayerBackgroundTask>().pause(disableFade: true);
      while (navigator.canPop()) {
        navigator.pop();
        await WidgetsBinding.instance.endOfFrame;
      }
    }
  }

  Future<void> _recordUnavailableTargetRun({
    required String scenario,
    required String mode,
    required String targetAlias,
    required String targetType,
    required String step,
    bool allowPendingDownloadCleanup = false,
  }) async {
    final recorder = PerformanceBenchmarkService.instance;
    await recorder.startRun(
      scenario: scenario,
      variant: PerformanceBenchmarkService.variant,
      mode: mode,
      targetAlias: targetAlias,
      targetType: targetType,
      allowPendingDownloadCleanup: allowPendingDownloadCleanup,
    );
    await recorder.failActiveRun(
      result: PerformanceBenchmarkResult.failed,
      error: StateError("Benchmark target is unavailable"),
      stackTrace: StackTrace.current,
      step: step,
    );
  }

  Future<void> _runPlaybackBaselines() async {
    final targets = _smoke
        ? const <(String, String)>[("detail-track", "track"), ("bench-10", "playlist")]
        : const <(String, String)>[
            ("detail-track", "track"),
            ("detail-album", "album"),
            ("detail-artist", "artist"),
            ("detail-genre", "genre"),
            ("query-1-track", "track"),
            ("query-1-album", "album"),
            ("query-1-artist", "artist"),
            ("query-2-track", "track"),
            ("query-2-album", "album"),
            ("query-2-artist", "artist"),
            ("query-3-track", "track"),
            ("query-3-album", "album"),
            ("query-3-artist", "artist"),
            ("bench-10", "playlist"),
            ("bench-100", "playlist"),
            ("bench-1000", "playlist"),
            ("bench-10000", "playlist"),
          ];

    for (final entry in targets) {
      final (alias, type) = entry;
      await _runPlaybackBaseline(targetAlias: alias, playableType: type, mode: "online-first");
      await GetIt.instance<MusicPlayerBackgroundTask>().pause(disableFade: true);
      await _settleUi(schedulerCooldown: const Duration(seconds: 2));
      await _runPlaybackBaseline(targetAlias: alias, playableType: type, mode: "online-warm");
      await GetIt.instance<MusicPlayerBackgroundTask>().pause(disableFade: true);
      await _settleUi(schedulerCooldown: const Duration(seconds: 2));

      if (type == "playlist" && (alias == "bench-1000" || alias == "bench-10000")) {
        await _runQueueMemoryRecoveryBaseline(alias);
      }
    }
  }

  Future<void> _runQueueMemoryRecoveryBaseline(String targetAlias) async {
    final recorder = PerformanceBenchmarkService.instance;
    final queueService = GetIt.instance<QueueService>();

    await recorder.startRun(
      scenario: "queue-memory-recovery",
      variant: PerformanceBenchmarkService.variant,
      mode: "clear-after-warm-playback",
      targetAlias: targetAlias,
      targetType: "queue",
    );
    try {
      final rssBefore = ProcessInfo.currentRss;
      recorder.metric("rssBeforeQueueClearBytes", rssBefore);
      recorder.metric("queueLengthBeforeClear", queueService.getQueue().trackCount);

      await recorder.runStep(
        name: "clear-queue",
        timeout: const Duration(minutes: 10),
        operation: queueService.stopAndClearQueue,
      );
      await recorder.runStep(
        name: "wait-ui-quiescent",
        timeout: const Duration(minutes: 16),
        operation: _waitForUiQuiescence,
      );

      final rssAfter = ProcessInfo.currentRss;
      recorder.metric("rssAfterQueueClearBytes", rssAfter);
      recorder.metric("rssRecoveredAfterQueueClearBytes", rssBefore - rssAfter);
      await recorder.finishRun();
    } catch (_) {
      // runStep persists failures/timeouts.
    }
  }

  Future<void> _runPlaybackBaseline({
    required String targetAlias,
    required String playableType,
    required String mode,
    bool allowPendingDownloadCleanup = false,
  }) async {
    final recorder = PerformanceBenchmarkService.instance;
    final target = await recorder.getTarget(targetAlias);
    if (target == null) {
      recorder.diagnostic("playback-target-missing", values: {"targetAlias": targetAlias, "targetType": playableType});
      await _recordUnavailableTargetRun(
        scenario: "playback-startup-$playableType",
        mode: mode,
        targetAlias: targetAlias,
        targetType: playableType,
        step: "target-missing",
        allowPendingDownloadCleanup: allowPendingDownloadCleanup,
      );
      return;
    }

    final container = GetIt.instance<ProviderContainer>();
    final item = await container.read(itemByIdProvider(BaseItemId(target.itemId)).future);
    if (item == null) {
      recorder.diagnostic(
        "playback-target-unresolvable",
        values: {"targetAlias": targetAlias, "targetType": playableType},
      );
      await _recordUnavailableTargetRun(
        scenario: "playback-startup-$playableType",
        mode: mode,
        targetAlias: targetAlias,
        targetType: playableType,
        step: "target-unresolvable",
        allowPendingDownloadCleanup: allowPendingDownloadCleanup,
      );
      return;
    }

    final FinampPlayable playable = switch (playableType) {
      "track" => Track.fromItem(item),
      "album" => Album.fromItem(item),
      "artist" => Artist.fromItem(item),
      "genre" => Genre.fromItem(item),
      "playlist" => Playlist.fromItem(item),
      _ => throw UnsupportedError("Unsupported playback type $playableType"),
    };

    final isVeryLargePlaylist = playableType == "playlist" && targetAlias == "bench-10000";
    final sliceTimeout = isVeryLargePlaylist ? const Duration(minutes: 15) : const Duration(minutes: 5);
    final queueStartTimeout = isVeryLargePlaylist ? const Duration(minutes: 30) : const Duration(minutes: 10);
    final playerStateTimeout = isVeryLargePlaylist ? const Duration(minutes: 5) : const Duration(minutes: 3);

    await recorder.startRun(
      scenario: "playback-startup-$playableType",
      variant: PerformanceBenchmarkService.variant,
      mode: mode,
      targetAlias: targetAlias,
      targetType: playableType,
      allowPendingDownloadCleanup: allowPendingDownloadCleanup,
    );

    try {
      final slice = await recorder.runStep(
        name: "playable-slice-provider",
        timeout: sliceTimeout,
        operation: () => container.read(getPlayableSliceProvider(item: playable, startingOffset: 0).future),
      );

      // Subscribe immediately before the action that can emit these events.
      // Attach a secondary error consumer so an earlier queue failure does not
      // leave an unobserved timeout behind.
      final readyFuture = recorder.waitForEvent("player-processing-ready", timeout: playerStateTimeout);
      final playingFuture = recorder.waitForEvent("player-playing", timeout: playerStateTimeout);
      final usefulBufferFuture = recorder.waitForEvent("player-useful-buffer-ready", timeout: playerStateTimeout);
      final firstPositionFuture = recorder.waitForEvent("player-first-position-advance", timeout: playerStateTimeout);
      unawaited(readyFuture.then<void>((_) {}, onError: (_) {}));
      unawaited(playingFuture.then<void>((_) {}, onError: (_) {}));
      unawaited(usefulBufferFuture.then<void>((_) {}, onError: (_) {}));
      unawaited(firstPositionFuture.then<void>((_) {}, onError: (_) {}));

      await recorder.runStep(
        name: "queue-and-player-start",
        timeout: queueStartTimeout,
        operation: () => GetIt.instance<QueueService>().startSlicePlayback(slice),
      );

      await recorder.runStep(name: "wait-player-ready", timeout: playerStateTimeout, operation: () => readyFuture);
      await recorder.runStep(name: "wait-player-playing", timeout: playerStateTimeout, operation: () => playingFuture);
      await recorder.runStep(
        name: "wait-useful-buffer",
        timeout: playerStateTimeout,
        operation: () => usefulBufferFuture,
      );
      await recorder.runStep(
        name: "wait-first-position",
        timeout: playerStateTimeout,
        operation: () => firstPositionFuture,
      );
      await recorder.runStep(
        name: "wait-ui-quiescent",
        timeout: const Duration(minutes: 16),
        operation: _waitForUiQuiescence,
      );

      await recorder.finishRun();
    } catch (_) {
      // runStep persists failures/timeouts.
    }
  }

  Future<void> _runDetailBaselines() async {
    final aliases = _smoke
        ? const <(String, String)>[
            ("detail-album", "album"),
            ("detail-artist", "artist"),
            ("detail-genre", "genre"),
            ("query-1-artist", "artist"),
            ("query-1-album", "album"),
            ("bench-10", "playlist"),
          ]
        : const <(String, String)>[
            ("detail-album", "album"),
            ("detail-artist", "artist"),
            ("detail-genre", "genre"),
            ("query-1-artist", "artist"),
            ("query-1-album", "album"),
            ("query-2-artist", "artist"),
            ("query-2-album", "album"),
            ("query-3-artist", "artist"),
            ("query-3-album", "album"),
            ("bench-10", "playlist"),
            ("bench-100", "playlist"),
            ("bench-1000", "playlist"),
            ("bench-10000", "playlist"),
          ];

    for (final entry in aliases) {
      final (alias, detailType) = entry;
      await _runDetailBaseline(targetAlias: alias, detailType: detailType, mode: "refreshed-detail", refresh: true);
      await _settleUi(schedulerCooldown: const Duration(seconds: 2));
      await _runDetailBaseline(targetAlias: alias, detailType: detailType, mode: "warm-detail", refresh: false);
      await _settleUi(schedulerCooldown: const Duration(seconds: 2));
    }
  }

  Future<void> _runDetailBaseline({
    required String targetAlias,
    required String detailType,
    required String mode,
    required bool refresh,
    bool allowPendingDownloadCleanup = false,
  }) async {
    final recorder = PerformanceBenchmarkService.instance;
    final target = await recorder.getTarget(targetAlias);
    if (target == null) {
      recorder.diagnostic("detail-target-missing", values: {"targetAlias": targetAlias, "targetType": detailType});
      await _recordUnavailableTargetRun(
        scenario: "detail-first-rendered-content-$detailType",
        mode: mode,
        targetAlias: targetAlias,
        targetType: detailType,
        step: "target-missing",
        allowPendingDownloadCleanup: allowPendingDownloadCleanup,
      );
      return;
    }

    final container = GetIt.instance<ProviderContainer>();
    final item = await container.read(itemByIdProvider(BaseItemId(target.itemId)).future);
    if (item == null) {
      recorder.diagnostic("detail-target-unresolvable", values: {"targetAlias": targetAlias, "targetType": detailType});
      await _recordUnavailableTargetRun(
        scenario: "detail-first-rendered-content-$detailType",
        mode: mode,
        targetAlias: targetAlias,
        targetType: detailType,
        step: "target-unresolvable",
        allowPendingDownloadCleanup: allowPendingDownloadCleanup,
      );
      return;
    }

    await recorder.startRun(
      scenario: "detail-first-rendered-content-$detailType",
      variant: PerformanceBenchmarkService.variant,
      mode: mode,
      targetAlias: targetAlias,
      targetType: detailType,
      allowPendingDownloadCleanup: allowPendingDownloadCleanup,
    );

    try {
      final navigator = GlobalSnackbar.navigatorState;
      if (navigator == null) {
        throw StateError("Navigator is not available for detail benchmark");
      }

      await recorder.runStep(
        name: "detail-open",
        timeout: const Duration(minutes: 15),
        operation: () => recorder.requestDetail(
          targetAlias: targetAlias,
          targetType: detailType,
          itemId: target.itemId,
          refresh: refresh,
          timeout: const Duration(minutes: 14, seconds: 30),
          open: () {
            if (detailType == "artist") {
              navigator.push(MaterialPageRoute<ArtistScreen>(builder: (_) => ArtistScreen(widgetArtist: item)));
            } else if (detailType == "genre") {
              navigator.push(MaterialPageRoute<GenreScreen>(builder: (_) => GenreScreen(widgetGenre: item)));
            } else if (detailType == "album" || detailType == "playlist") {
              navigator.push(MaterialPageRoute<AlbumScreen>(builder: (_) => AlbumScreen(parent: item)));
            } else {
              throw UnsupportedError("Unsupported benchmark detail type");
            }
          },
        ),
      );
      await recorder.runStep(
        name: "wait-ui-quiescent",
        timeout: const Duration(minutes: 16),
        operation: _waitForUiQuiescence,
      );
      await recorder.finishRun();

      if (navigator.canPop()) {
        navigator.pop();
        await WidgetsBinding.instance.endOfFrame;
      }
    } catch (error, stackTrace) {
      if (PerformanceBenchmarkService.instance.activeRun != null) {
        await recorder.failActiveRun(
          result: PerformanceBenchmarkResult.failed,
          error: error,
          stackTrace: stackTrace,
          step: "detail-open",
        );
      }
      final navigator = GlobalSnackbar.navigatorState;
      if (navigator?.canPop() ?? false) {
        navigator!.pop();
        await WidgetsBinding.instance.endOfFrame;
      }
    }
  }

  Future<void> _runAlphabetBaselines() async {
    final recorder = PerformanceBenchmarkService.instance;

    const tabs = <String>["tracks", "artists", "albums"];
    final letters = _smoke ? const <String>["A", "Z"] : const <String>["#", "A", "G", "M", "Z"];

    for (final requestedTab in tabs) {
      // Album and artist grids get an isolated cold distant-jump measurement.
      // This specifically catches regressions where jumping directly from the
      // first page to the end of a large collection progressively materializes
      // every preceding page.
      if (requestedTab == "artists" || requestedTab == "albums") {
        final resolvedDirectTab = await recorder.requestUiTab(
          contentType: requestedTab,
          refresh: true,
          timeout: const Duration(minutes: 10),
        );
        await _settleUi(schedulerCooldown: const Duration(seconds: 2));

        await recorder.startRun(
          scenario: "alphabet-direct-z-$requestedTab",
          variant: PerformanceBenchmarkService.variant,
          mode: "fresh-direct",
          targetType: resolvedDirectTab,
        );
        try {
          recorder.metric("letter", "Z");
          await recorder.runStep(
            name: "alphabet-jump",
            timeout: const Duration(minutes: 30),
            operation: () => recorder.requestAlphabetJump(
              contentType: resolvedDirectTab,
              letter: "Z",
              timeout: const Duration(minutes: 29, seconds: 30),
            ),
          );
          await recorder.runStep(
            name: "wait-ui-quiescent",
            timeout: const Duration(minutes: 16),
            operation: _waitForUiQuiescence,
          );
          await recorder.finishRun();
        } catch (_) {
          // runStep finalized the failed run.
        }
        await _settleUi(schedulerCooldown: const Duration(seconds: 2));
      }

      // Refresh once outside the measured jump runs. The first sequence then
      // exercises the real incremental loading path from a fresh first page.
      final resolvedTab = await recorder.requestUiTab(
        contentType: requestedTab,
        refresh: true,
        timeout: const Duration(minutes: 10),
      );
      await _settleUi(schedulerCooldown: const Duration(seconds: 2));

      for (final letter in letters) {
        await recorder.startRun(
          scenario: "alphabet-jump-$requestedTab-$letter",
          variant: PerformanceBenchmarkService.variant,
          mode: "refreshed-sequential",
          targetType: resolvedTab,
        );
        try {
          recorder.metric("letter", letter);
          await recorder.runStep(
            name: "alphabet-jump",
            timeout: const Duration(minutes: 30),
            operation: () => recorder.requestAlphabetJump(
              contentType: resolvedTab,
              letter: letter,
              timeout: const Duration(minutes: 29, seconds: 30),
            ),
          );
          await recorder.runStep(
            name: "wait-ui-quiescent",
            timeout: const Duration(minutes: 16),
            operation: _waitForUiQuiescence,
          );
          await recorder.finishRun();
        } catch (_) {
          // runStep finalized the failed run.
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      // At this point jumping towards Z has loaded the expensive path. Repeat
      // the same sequence without a provider refresh to expose pure warm-list
      // scrolling and already-loaded-page behaviour.
      for (final letter in letters) {
        await recorder.startRun(
          scenario: "alphabet-jump-$requestedTab-$letter",
          variant: PerformanceBenchmarkService.variant,
          mode: "warm-loaded",
          targetType: resolvedTab,
        );
        try {
          recorder.metric("letter", letter);
          await recorder.runStep(
            name: "alphabet-jump",
            timeout: const Duration(minutes: 5),
            operation: () => recorder.requestAlphabetJump(
              contentType: resolvedTab,
              letter: letter,
              timeout: const Duration(minutes: 4, seconds: 30),
            ),
          );
          await recorder.runStep(
            name: "wait-ui-quiescent",
            timeout: const Duration(minutes: 16),
            operation: _waitForUiQuiescence,
          );
          await recorder.finishRun();
        } catch (_) {
          // runStep finalized the failed run.
        }
        await _settleUi(schedulerCooldown: const Duration(milliseconds: 750));
      }

      await _settleUi(schedulerCooldown: const Duration(seconds: 2));
    }
  }

  Future<void> _runOneTimePlaylistMetadataBaseline() async {
    final recorder = PerformanceBenchmarkService.instance;
    final downloads = GetIt.instance<DownloadsService>();
    final stub = DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.allPlaylistsMetadata));
    const targetAlias = "all-playlists-metadata";

    await recorder.saveTarget(alias: targetAlias, itemType: "finampCollection", itemId: stub.id);

    if (downloads.getStatus(stub, null).isDownloaded) {
      await downloads.deleteDownload(stub: stub);
      await downloads.waitForPerformanceBenchmarkCleanup(stub: stub, timeout: const Duration(minutes: 20));
    }

    await recorder.startRun(
      scenario: "one-time-playlist-metadata-download",
      variant: PerformanceBenchmarkService.variant,
      mode: "isolated-first-run",
      targetAlias: targetAlias,
      targetType: "playlist-metadata",
    );

    try {
      await recorder.runStep(
        name: "metadata-sync-plan-and-enqueue",
        timeout: const Duration(minutes: 30),
        operation: downloads.addDefaultPlaylistInfoDownload,
      );
      await recorder.runStep(
        name: "metadata-transfer-until-idle",
        timeout: const Duration(hours: 3),
        operation: () => downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
          stableFor: const Duration(seconds: 5),
          timeout: const Duration(hours: 2, minutes: 55),
        ),
      );
      await recorder.finishRun();
    } catch (_) {
      rethrow;
    }

    await recorder.startRun(
      scenario: "one-time-playlist-metadata-cleanup",
      variant: PerformanceBenchmarkService.variant,
      mode: "cleanup",
      targetAlias: targetAlias,
      targetType: "playlist-metadata",
      allowPendingDownloadCleanup: true,
    );
    try {
      await recorder.runStep(
        name: "metadata-delete",
        timeout: const Duration(minutes: 30),
        operation: () => downloads.deleteDownload(stub: stub),
      );
      await recorder.runStep(
        name: "metadata-cleanup-verify",
        timeout: const Duration(minutes: 30),
        operation: () => downloads.waitForPerformanceBenchmarkCleanup(stub: stub, timeout: const Duration(minutes: 25)),
      );
      await recorder.runStep(
        name: "metadata-cleanup-idle",
        timeout: const Duration(minutes: 30),
        operation: () => downloads.waitForPerformanceBenchmarkDownloadSystemIdle(
          stableFor: const Duration(seconds: 5),
          timeout: const Duration(minutes: 25),
        ),
      );
      await recorder.setDownloadCleanupRequired(targetAlias: "", required: false);
      await recorder.finishRun();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _runNetworkTargetBaselines() async {
    final recorder = PerformanceBenchmarkService.instance;
    final api = GetIt.instance<JellyfinApiHelper>();
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user == null) {
      await _recordUnavailableTargetRun(
        scenario: "network-target-probe",
        mode: "online",
        targetAlias: "active",
        targetType: "network",
        step: "user-missing",
      );
      return;
    }

    final localUri = Uri.tryParse(user.localAddress);
    final localConfigured = localUri != null && localUri.host.isNotEmpty && localUri.host != "0.0.0.0";

    final roundCount = _smoke ? 1 : 3;
    for (var round = 1; round <= roundCount; round++) {
      for (final target in const <String>["public", "local", "active"]) {
        if (target == "local" && !localConfigured) {
          recorder.diagnostic(
            "network-target-probe-skipped",
            values: {"target": "local", "reason": "not-configured", "round": round},
          );
          continue;
        }

        await recorder.startRun(
          scenario: "network-target-probe",
          variant: PerformanceBenchmarkService.variant,
          mode: "online",
          targetAlias: target,
          targetType: "network",
        );
        recorder.metric("round", round);

        try {
          final success = await recorder.runStep(
            name: "ping",
            timeout: const Duration(seconds: 10),
            operation: () => switch (target) {
              "public" => api.pingPublicServer(),
              "local" => api.pingLocalServer(),
              "active" => api.pingActiveServer(),
              _ => throw StateError("Unsupported network target"),
            },
          );
          recorder.metric("success", success);
          if (!success) {
            await recorder.failActiveRun(
              result: PerformanceBenchmarkResult.failed,
              error: StateError("Network target probe failed"),
              stackTrace: StackTrace.current,
              step: "ping",
            );
          } else {
            await recorder.finishRun();
          }
        } catch (error, stackTrace) {
          if (recorder.activeRun != null) {
            await recorder.failActiveRun(
              result: PerformanceBenchmarkResult.failed,
              error: error,
              stackTrace: stackTrace,
              step: "ping",
            );
          }
        }

        await recorder.waitForNetworkQuiescence(
          quietPeriod: const Duration(milliseconds: 750),
          timeout: const Duration(seconds: 30),
        );
      }
      await _settleUi(schedulerCooldown: const Duration(seconds: 1));
    }
  }

  Future<void> _runCollectionFirstPageBaselines() async {
    final api = GetIt.instance<JellyfinApiHelper>();
    final recorder = PerformanceBenchmarkService.instance;

    final rounds = _smoke
        ? const <List<(String, String, ArtistType?)>>[
            [
              ("artists-performing", "MusicArtist", ArtistType.artist),
              ("artists-album", "MusicArtist", ArtistType.albumArtist),
              ("albums", "MusicAlbum", null),
              ("tracks", "Audio", null),
              ("playlists", "Playlist", null),
              ("genres", "MusicGenre", null),
            ],
          ]
        : const <List<(String, String, ArtistType?)>>[
            [
              ("artists-performing", "MusicArtist", ArtistType.artist),
              ("artists-album", "MusicArtist", ArtistType.albumArtist),
              ("albums", "MusicAlbum", null),
              ("tracks", "Audio", null),
              ("playlists", "Playlist", null),
              ("genres", "MusicGenre", null),
            ],
            [
              ("genres", "MusicGenre", null),
              ("playlists", "Playlist", null),
              ("tracks", "Audio", null),
              ("albums", "MusicAlbum", null),
              ("artists-album", "MusicArtist", ArtistType.albumArtist),
              ("artists-performing", "MusicArtist", ArtistType.artist),
            ],
            [
              ("tracks", "Audio", null),
              ("artists-album", "MusicArtist", ArtistType.albumArtist),
              ("genres", "MusicGenre", null),
              ("artists-performing", "MusicArtist", ArtistType.artist),
              ("albums", "MusicAlbum", null),
              ("playlists", "Playlist", null),
            ],
          ];

    for (var round = 0; round < rounds.length; round++) {
      recorder.diagnostic("api-reference-round-start", values: {"round": round + 1});

      for (final collection in rounds[round]) {
        final (scenarioName, itemType, artistType) = collection;

        final requests = _smoke
            ? const <(int, String)>[(25, "size-25"), (100, "size-100-first"), (100, "size-100-warm")]
            : const <(int, String)>[
                (25, "size-25"),
                (100, "size-100-first"),
                (100, "size-100-warm"),
                (500, "size-500"),
              ];
        for (final request in requests) {
          final (limit, mode) = request;
          await recorder.startRun(
            scenario: "collection-page-$scenarioName",
            variant: PerformanceBenchmarkService.variant,
            mode: mode,
            targetType: itemType,
          );

          try {
            recorder.metric("round", round + 1);
            recorder.metric("requestedPageSize", limit);
            final result = await recorder.runStep(
              name: "request",
              timeout: const Duration(minutes: 10),
              operation: () => api.getItemsWithTotalRecordCount(
                includeItemTypes: itemType,
                artistType: artistType,
                recursive: true,
                startIndex: 0,
                limit: limit,
              ),
            );

            recorder.metric("pageSize", result.items?.length ?? 0);
            // Never export totalRecordCount: it would reveal private library
            // cardinality. Page-size scaling is sufficient for this baseline.
            await recorder.finishRun();
          } catch (_) {
            // runStep already finalized the failed/timeout run.
          }

          await recorder.waitForNetworkQuiescence(
            quietPeriod: const Duration(milliseconds: 500),
            timeout: const Duration(minutes: 10),
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      if (!_smoke) {
        final fieldVariants = round.isEven
            ? const <(String, String?)>[("default-fields", null), ("minimal-fields", "SortName")]
            : const <(String, String?)>[("minimal-fields", "SortName"), ("default-fields", null)];

        for (final (mode, fields) in fieldVariants) {
          await recorder.startRun(
            scenario: "collection-page-tracks-field-reference",
            variant: PerformanceBenchmarkService.variant,
            mode: mode,
            targetType: "Audio",
          );
          try {
            recorder.metric("round", round + 1);
            recorder.metric("requestedPageSize", 100);
            recorder.metric("usesDefaultFields", fields == null);
            final result = await recorder.runStep(
              name: "request",
              timeout: const Duration(minutes: 10),
              operation: () => api.getItemsWithTotalRecordCount(
                includeItemTypes: "Audio",
                recursive: true,
                startIndex: 0,
                limit: 100,
                fields: fields,
              ),
            );
            recorder.metric("pageSize", result.items?.length ?? 0);
            await recorder.finishRun();
          } catch (_) {
            // runStep already finalized the failed/timeout run.
          }

          await recorder.waitForNetworkQuiescence(
            quietPeriod: const Duration(milliseconds: 200),
            timeout: const Duration(minutes: 10),
          );
        }
      }

      recorder.diagnostic("api-reference-round-complete", values: {"round": round + 1});
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}
