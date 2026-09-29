import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

class PerformanceBenchmarkTarget {
  const PerformanceBenchmarkTarget({required this.alias, required this.itemType, required this.itemId});

  final String alias;
  final String itemType;

  /// Device-local only. Never emitted in benchmark exports.
  final String itemId;

  Map<String, dynamic> toLocalJson() => {"alias": alias, "itemType": itemType, "itemId": itemId};

  factory PerformanceBenchmarkTarget.fromLocalJson(Map<String, dynamic> json) {
    return PerformanceBenchmarkTarget(
      alias: json["alias"] as String,
      itemType: json["itemType"] as String,
      itemId: json["itemId"] as String,
    );
  }
}

class PerformanceBenchmarkJumpCommand {
  PerformanceBenchmarkJumpCommand({required this.contentType, required this.letter});

  final String contentType;
  final String letter;
  final Completer<void> _completer = Completer<void>();

  Future<void> get completed => _completer.future;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) _completer.completeError(error, stackTrace);
  }
}

class PerformanceBenchmarkTabCommand {
  PerformanceBenchmarkTabCommand({required this.contentType, required this.refresh});

  final String contentType;
  final bool refresh;
  final Completer<void> _completer = Completer<void>();
  bool selected = false;
  String? selectedContentType;

  Future<void> get completed => _completer.future;

  void markSelected(String contentType) {
    selected = true;
    selectedContentType = contentType;
  }

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) _completer.completeError(error, stackTrace);
  }
}

class PerformanceBenchmarkDetailCommand {
  PerformanceBenchmarkDetailCommand({
    required this.targetAlias,
    required this.targetType,
    required this.itemId,
    required this.refresh,
  });

  final String targetAlias;
  final String targetType;
  final String itemId;
  final bool refresh;
  final Completer<void> _completer = Completer<void>();

  Future<void> get completed => _completer.future;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) _completer.completeError(error, stackTrace);
  }
}

class PerformanceBenchmarkPageCommand {
  PerformanceBenchmarkPageCommand({required this.contentType});

  final String contentType;
  final Completer<bool> _completer = Completer<bool>();

  Future<bool> get completed => _completer.future;

  void complete(bool loadedPage) {
    if (!_completer.isCompleted) _completer.complete(loadedPage);
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) _completer.completeError(error, stackTrace);
  }
}

class PerformanceBenchmarkSearchCommand {
  PerformanceBenchmarkSearchCommand({required this.contentType, required this.queryAlias, required this.query});

  final String contentType;
  final String queryAlias;

  /// Device-local benchmark input. Never emit this string.
  final String query;

  String? selectedContentType;
  final Completer<void> _completer = Completer<void>();

  Future<void> get completed => _completer.future;

  void markSelected(String contentType) {
    selectedContentType = contentType;
  }

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) _completer.completeError(error, stackTrace);
  }
}

class PerformanceBenchmarkEvent {
  const PerformanceBenchmarkEvent({required this.name, required this.elapsedMicros, this.values = const {}});

  final String name;
  final int elapsedMicros;
  final Map<String, Object?> values;

  Map<String, dynamic> toJson() => {
    "name": name,
    "elapsedMicros": elapsedMicros,
    if (values.isNotEmpty) "values": values,
  };
}

enum PerformanceBenchmarkResult { running, success, failed, timeout, unexpectedExit, cancelled }

class PerformanceBenchmarkRun {
  PerformanceBenchmarkRun({
    required this.id,
    required this.scenario,
    required this.variant,
    required this.mode,
    required this.stopwatch,
    required this.startedAt,
    this.targetAlias,
    this.targetType,
  });

  final String id;
  final String scenario;
  final String variant;
  final String mode;
  final String? targetAlias;
  final String? targetType;
  final Stopwatch stopwatch;
  final DateTime startedAt;
  final List<PerformanceBenchmarkEvent> events = [];
  final Map<String, Object?> metrics = {};
  bool finished = false;
  PerformanceBenchmarkResult result = PerformanceBenchmarkResult.running;
  String? lastStep;
  Map<String, Object?>? failure;

  void mark(String name, {Map<String, Object?> values = const {}}) {
    lastStep = name;
    events.add(PerformanceBenchmarkEvent(name: name, elapsedMicros: stopwatch.elapsedMicroseconds, values: values));
  }

  void setMetric(String name, Object? value) {
    metrics[name] = value;
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "scenario": scenario,
    "variant": variant,
    "mode": mode,
    if (targetAlias != null) "targetAlias": targetAlias,
    if (targetType != null) "targetType": targetType,
    "startedAt": startedAt.toUtc().toIso8601String(),
    "durationMicros": stopwatch.elapsedMicroseconds,
    "events": events.map((event) => event.toJson()).toList(),
    "metrics": metrics,
    "finished": finished,
    "result": result.name,
    if (lastStep != null) "lastStep": lastStep,
    if (failure != null) "failure": failure,
  };
}

/// Test-only performance recorder.
///
/// Timings use one monotonic [Stopwatch] per run. Target IDs are stored only in
/// a device-local Hive box and are deliberately excluded from exported data.
class PerformanceBenchmarkService {
  static const bool enabled = bool.fromEnvironment("FINAMP_PERFORMANCE_BENCHMARK", defaultValue: false);
  static const bool smoke = bool.fromEnvironment("FINAMP_BENCH_SMOKE", defaultValue: false);
  static const bool targetedDownloadBench100 = bool.fromEnvironment(
    "FINAMP_BENCH_DOWNLOAD_BENCH100_ONLY",
    defaultValue: false,
  );
  static const bool targetedDownloadBench1000 = bool.fromEnvironment(
    "FINAMP_BENCH_DOWNLOAD_BENCH1000_ONLY",
    defaultValue: false,
  );
  static const String variant = String.fromEnvironment("FINAMP_BENCH_VARIANT", defaultValue: "unknown");
  static const String suiteRunId = String.fromEnvironment("FINAMP_BENCH_RUN_ID", defaultValue: "manual");
  static const String searchQuery1 = String.fromEnvironment("FINAMP_BENCH_SEARCH_QUERY_1", defaultValue: "");
  static const String searchQuery2 = String.fromEnvironment("FINAMP_BENCH_SEARCH_QUERY_2", defaultValue: "");
  static const String searchQuery3 = String.fromEnvironment("FINAMP_BENCH_SEARCH_QUERY_3", defaultValue: "");

  static final _logger = Logger("PerformanceBenchmark");
  static const _boxName = "PerformanceBenchmark";
  static String get _targetKeyPrefix => "target:$suiteRunId:";
  static String get _runKeyPrefix => "run:$suiteRunId:";
  static String get _activeRunKey => "active-run:$suiteRunId";
  static const _cleanupRequiredKey = "cleanup-required";
  static String get _originalOfflineKey => "original-offline:$suiteRunId";
  static String get _hostStreamFileName => "finamp-benchmark-stream-$variant-$suiteRunId.jsonl";
  static String get _suiteStageFileName => "finamp-benchmark-stage-$variant-$suiteRunId.txt";

  static final PerformanceBenchmarkService instance = PerformanceBenchmarkService._();

  PerformanceBenchmarkService._();

  static const Set<String> _privateDownloadCardinalityMetricPrefixes = {
    "downloadSyncNodeCount_",
    "downloadUpdateChildrenCount_",
    "downloadUpdateChildrenInserted_",
    "downloadUpdateChildrenLinkedExisting_",
    "downloadUpdateChildrenUnlinked_",
  };

  static const Set<String> _privateDownloadCardinalityMetrics = {
    "downloadMetadataCacheHit",
    "downloadMetadataCacheMiss",
    "downloadChildCacheHit",
    "downloadChildCacheMiss",
    "downloadAlbumViewLookupCount",
    "downloadAlbumViewViewsExamined",
    "downloadAlbumViewIdsScanned",
    "downloadMetadataBatchCount",
    "downloadMetadataBatchIdsTotal",
    "downloadMetadataBatchIdsMax",
    "downloadMetadataBatchMixedFields",
  };

  static String _cardinalityBucket(num value) {
    final count = value.toInt();
    if (count <= 0) return "0";
    if (count < 10) return "1-9";
    if (count < 50) return "10-49";
    if (count < 100) return "50-99";
    if (count < 500) return "100-499";
    if (count < 1000) return "500-999";
    if (count < 5000) return "1000-4999";
    if (count < 10000) return "5000-9999";
    return "10000+";
  }

  static Map<String, dynamic> _publicRunJsonMap(Map<String, dynamic> runJson) {
    final output = Map<String, dynamic>.from(runJson);
    final metrics = Map<String, dynamic>.from((output["metrics"] as Map?)?.cast<String, dynamic>() ?? const {});

    final keys = metrics.keys.toList();
    for (final key in keys) {
      final isPrivateCardinality =
          _privateDownloadCardinalityMetrics.contains(key) ||
          _privateDownloadCardinalityMetricPrefixes.any(key.startsWith);
      if (!isPrivateCardinality) continue;

      final value = metrics.remove(key);
      if (value is num) {
        metrics["${key}Bucket"] = _cardinalityBucket(value);
      }
    }

    output["metrics"] = metrics;
    return output;
  }

  static Map<String, dynamic> _publicRunJson(PerformanceBenchmarkRun run) => _publicRunJsonMap(run.toJson());

  Box<String>? _box;
  File? _hostStreamFile;
  final Stopwatch _processStopwatch = Stopwatch();
  static const MethodChannel _nativeLaunchTimingChannel = MethodChannel("finamp/benchmark_launch_timing");

  Timer? _heartbeatTimer;
  Future<void> _hostWriteChain = Future<void>.value();
  Future<void> _persistWriteChain = Future<void>.value();
  PerformanceBenchmarkRun? _activeRun;
  PerformanceBenchmarkTabCommand? _activeTabCommand;
  PerformanceBenchmarkDetailCommand? _activeDetailCommand;
  PerformanceBenchmarkSearchCommand? _activeSearchCommand;
  int _runSequence = 0;
  int _startupPendingTasks = 0;
  int _startupGeneration = 0;
  final StreamController<int> _startupTaskController = StreamController<int>.broadcast();
  int _networkRequestsInFlight = 0;
  int _httpRequestsInFlight = 0;
  int _networkGeneration = 0;
  final StreamController<int> _networkRequestController = StreamController<int>.broadcast();
  String? _httpFirstRequestRunId;
  String? _httpFirstResponseRunId;
  String? _playbackSourceRunId;
  bool _startupPlaylistMetadataWorkRan = false;
  bool? _startupPlaylistMetadataWorkSucceeded;
  int _startupNetworkRequestCount = 0;
  int _startupNetworkResponseBytes = 0;
  int _startupNetworkDurationMicros = 0;
  int _startupNetworkDurationMicrosMax = 0;
  int _startupWorkerOperationCount = 0;
  int _startupWorkerOperationFailed = 0;
  int _startupWorkerDurationMicros = 0;
  int _startupWorkerDurationMicrosMax = 0;

  bool _startupFrameCollectionOpen = true;
  int _startupFrameCount = 0;
  int _startupFramesOver16_7ms = 0;
  int _startupFramesOver33_3ms = 0;
  int _startupFramesOver50ms = 0;
  int _startupFrameBuildMicrosMax = 0;
  int _startupFrameRasterMicrosMax = 0;
  int _startupFrameTotalMicrosMax = 0;
  int _startupFrameBuildMicrosTotal = 0;
  int _startupFrameRasterMicrosTotal = 0;
  int _startupFrameTotalMicrosTotal = 0;

  int _startupImageLoadStarted = 0;
  int _startupImageLoadCompleted = 0;
  int _startupImageLoadFailed = 0;
  int _startupImageLoadSynchronous = 0;
  int _startupImageMaxConcurrentLoads = 0;
  int _imageLoadsInFlight = 0;
  int _imageLoadGeneration = 0;
  final StreamController<int> _imageLoadController = StreamController<int>.broadcast();
  int _uiActivityGeneration = 0;
  final StreamController<int> _uiActivityController = StreamController<int>.broadcast();
  final StreamController<PerformanceBenchmarkJumpCommand> _jumpController =
      StreamController<PerformanceBenchmarkJumpCommand>.broadcast();
  final StreamController<PerformanceBenchmarkTabCommand> _tabController =
      StreamController<PerformanceBenchmarkTabCommand>.broadcast();
  final StreamController<String> _eventNameController = StreamController<String>.broadcast();
  final StreamController<PerformanceBenchmarkPageCommand> _pageController =
      StreamController<PerformanceBenchmarkPageCommand>.broadcast();
  final StreamController<PerformanceBenchmarkSearchCommand> _searchController =
      StreamController<PerformanceBenchmarkSearchCommand>.broadcast();
  String? _startupSelectedContentType;
  final Completer<void> _startupScreenReady = Completer<void>();

  Stream<PerformanceBenchmarkJumpCommand> get jumpCommands => _jumpController.stream;
  Stream<PerformanceBenchmarkTabCommand> get tabCommands => _tabController.stream;
  Stream<PerformanceBenchmarkPageCommand> get pageCommands => _pageController.stream;
  Stream<PerformanceBenchmarkSearchCommand> get searchCommands => _searchController.stream;

  PerformanceBenchmarkRun? get activeRun => _activeRun;
  PerformanceBenchmarkTabCommand? get activeTabCommand => _activeTabCommand;
  PerformanceBenchmarkDetailCommand? get activeDetailCommand => _activeDetailCommand;
  PerformanceBenchmarkSearchCommand? get activeSearchCommand => _activeSearchCommand;
  bool get hasActiveRun => _activeRun != null;
  bool get startupPlaylistMetadataWorkRan => _startupPlaylistMetadataWorkRan;
  bool? get startupPlaylistMetadataWorkSucceeded => _startupPlaylistMetadataWorkSucceeded;

  void markStartupPlaylistMetadataWorkRan() {
    if (!enabled) return;
    _startupPlaylistMetadataWorkRan = true;
    diagnostic("startup-playlist-metadata-work-started");
  }

  void reportStartupPlaylistMetadataWorkResult({required bool success, String? errorType}) {
    if (!enabled) return;
    _startupPlaylistMetadataWorkSucceeded = success;
    diagnostic(
      success ? "startup-playlist-metadata-work-complete" : "startup-playlist-metadata-work-failed",
      values: {"success": success, if (errorType != null) "errorType": errorType},
    );
  }

  void reportStartupNetworkSummary({required String phase}) {
    if (!enabled) return;
    diagnostic(
      "startup-network-summary",
      values: {
        "phase": phase,
        "requestCount": _startupNetworkRequestCount,
        "responseBytes": _startupNetworkResponseBytes,
        "durationMicrosTotal": _startupNetworkDurationMicros,
        "durationMicrosMax": _startupNetworkDurationMicrosMax,
        "workerOperationCount": _startupWorkerOperationCount,
        "workerOperationFailed": _startupWorkerOperationFailed,
        "workerDurationMicrosTotal": _startupWorkerDurationMicros,
        "workerDurationMicrosMax": _startupWorkerDurationMicrosMax,
      },
    );
  }

  String? get startupSelectedContentType => _startupSelectedContentType;

  void setStartupSelectedContentType(String contentType) {
    if (!enabled || _startupSelectedContentType != null) return;
    _startupSelectedContentType = contentType;
    diagnostic("startup-selected-content-type", values: {"contentType": contentType});
  }

  void reportStartupScreenReady(String contentType) {
    if (!enabled || _startupScreenReady.isCompleted || _startupSelectedContentType != contentType) {
      return;
    }

    _startupScreenReady.complete();
    unawaited(reportStartupMilestone("startup-screen-first-rendered-content", values: {"contentType": contentType}));
  }

  Future<void> waitForStartupScreenReady({Duration timeout = const Duration(minutes: 3)}) async {
    if (!enabled) return;
    if (_startupScreenReady.isCompleted) return;
    await _startupScreenReady.future.timeout(timeout);
  }

  Future<double?> nativeLaunchElapsedMs() async {
    if (!enabled || !Platform.isIOS) return null;
    try {
      final value = await _nativeLaunchTimingChannel.invokeMethod<double>("elapsedMilliseconds");
      return value;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> reportStartupMilestone(String name, {Map<String, Object?> values = const {}}) async {
    if (!enabled) return;
    final nativeElapsed = await nativeLaunchElapsedMs();
    final dartElapsed = processElapsedMs;
    diagnostic(
      name,
      values: {
        ...values,
        "processElapsedMs": dartElapsed,
        if (nativeElapsed != null) ...{
          "nativeLaunchElapsedMs": nativeElapsed,
          "nativeToDartMainMs": (nativeElapsed - dartElapsed).clamp(0.0, double.infinity),
        },
      },
    );
  }

  void startProcessStopwatch() {
    if (!enabled) return;
    _processStopwatch
      ..reset()
      ..start();
  }

  double get processElapsedMs => _processStopwatch.elapsedMicroseconds / 1000.0;

  void startHeartbeat() {
    if (!enabled || _heartbeatTimer != null) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final run = _activeRun;
      diagnostic(
        "benchmark-heartbeat",
        values: {
          "activeRun": run != null,
          if (run != null) "scenario": run.scenario,
          if (run?.lastStep != null) "lastStep": run!.lastStep,
        },
      );
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<File> _suiteStageFile() async {
    final directory = (Platform.isAndroid || Platform.isIOS)
        ? await getApplicationDocumentsDirectory()
        : await getApplicationSupportDirectory();
    return File(path_helper.join(directory.path, _suiteStageFileName));
  }

  Future<String?> getSuiteStage() async {
    final file = await _suiteStageFile();
    if (!await file.exists()) return null;
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> setSuiteStage(String stage) async {
    final file = await _suiteStageFile();
    await file.writeAsString(stage, flush: true);
    diagnostic("suite-stage", values: {"stage": stage});
  }

  Future<Box<String>> _getBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) return existing;

    final directory = (Platform.isAndroid || Platform.isIOS)
        ? await getApplicationDocumentsDirectory()
        : await getApplicationSupportDirectory();

    return _box = await Hive.openBox<String>(_boxName, path: directory.path);
  }

  Future<void> saveTarget({required String alias, required String itemType, required String itemId}) async {
    final box = await _getBox();
    final target = PerformanceBenchmarkTarget(alias: alias, itemType: itemType, itemId: itemId);
    await box.put("$_targetKeyPrefix$alias", jsonEncode(target.toLocalJson()));
  }

  Future<PerformanceBenchmarkTarget?> getTarget(String alias) async {
    final box = await _getBox();
    final encoded = box.get("$_targetKeyPrefix$alias");
    if (encoded == null) return null;

    return PerformanceBenchmarkTarget.fromLocalJson(jsonDecode(encoded) as Map<String, dynamic>);
  }

  /// Transitional fallback for a cleanup marker written by an older
  /// benchmark build before targets were namespaced by suite run id.
  Future<PerformanceBenchmarkTarget?> getLegacyTargetForCleanup(String alias) async {
    final box = await _getBox();
    final encoded = box.get("target:$alias");
    if (encoded == null) return null;
    return PerformanceBenchmarkTarget.fromLocalJson(jsonDecode(encoded) as Map<String, dynamic>);
  }

  Future<List<PerformanceBenchmarkTarget>> getTargets() async {
    final box = await _getBox();
    return box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_targetKeyPrefix))
        .map(box.get)
        .whereType<String>()
        .map((encoded) => PerformanceBenchmarkTarget.fromLocalJson(jsonDecode(encoded) as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> recoverInterruptedRun() async {
    final box = await _getBox();
    final encoded = box.get(_activeRunKey);
    if (encoded == null) return null;

    final recovered = jsonDecode(encoded) as Map<String, dynamic>;
    if (recovered["finished"] == true) {
      await box.delete(_activeRunKey);
      return null;
    }

    recovered["finished"] = true;
    recovered["result"] = PerformanceBenchmarkResult.unexpectedExit.name;
    recovered["recoveredAt"] = DateTime.now().toUtc().toIso8601String();
    recovered["failure"] = {"type": "unexpected-exit", "lastStep": recovered["lastStep"]};

    final id = recovered["id"] as String;
    await box.put("$_runKeyPrefix$id", jsonEncode(recovered));
    await box.delete(_activeRunKey);
    _emitHostRecord("run-recovered", {"run": _publicRunJsonMap(recovered)});
    _logger.warning(
      "BENCH RUN $id recovered as unexpected-exit "
      "lastStep=${recovered["lastStep"]}",
    );
    return recovered;
  }

  Future<PerformanceBenchmarkRun> startRun({
    required String scenario,
    required String variant,
    required String mode,
    String? targetAlias,
    String? targetType,
    bool allowPendingDownloadCleanup = false,
  }) async {
    if (_activeRun != null) {
      throw StateError("A benchmark run is already active");
    }
    if (!allowPendingDownloadCleanup && await getDownloadCleanupRequirement() != null) {
      throw StateError("A benchmark download still requires cleanup before another run can start");
    }

    final now = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final run = PerformanceBenchmarkRun(
      id: "${now.toUtc().millisecondsSinceEpoch}-${++_runSequence}",
      scenario: scenario,
      variant: variant,
      mode: mode,
      targetAlias: targetAlias,
      targetType: targetType,
      stopwatch: stopwatch,
      startedAt: now,
    );
    run.setMetric("rssStartBytes", ProcessInfo.currentRss);
    run.setMetric("maxRssBytesAtStart", ProcessInfo.maxRss);
    run.mark("run-start");
    _activeRun = run;
    await _persistActiveRun();
    _logger.info(
      "BENCH RUN ${run.id} scenario=${run.scenario} "
      "variant=${run.variant} mode=${run.mode}",
    );
    _emitHostRecord("run-start", {"run": run.toJson()});
    return run;
  }

  void mark(String name, {Map<String, Object?> values = const {}}) {
    final run = _activeRun;
    if (run == null) return;
    run.mark(name, values: values);
    _eventNameController.add(name);
    _emitHostRecord("event", {
      "runId": run.id,
      "scenario": run.scenario,
      "variant": run.variant,
      "mode": run.mode,
      "event": run.events.last.toJson(),
    });
    unawaited(_persistActiveRun());
  }

  void metric(String name, Object? value) {
    final run = _activeRun;
    if (run == null) return;
    run.setMetric(name, value);
    _emitHostRecord("metric", {
      "runId": run.id,
      "scenario": run.scenario,
      "variant": run.variant,
      "mode": run.mode,
      "name": name,
      "value": value,
    });
    unawaited(_persistActiveRun());
  }

  void incrementMetricBuffered(String name, [int amount = 1]) {
    final run = _activeRun;
    if (run == null) return;
    final current = run.metrics[name];
    run.setMetric(name, (current is int ? current : 0) + amount);
  }

  void maxMetricBuffered(String name, num value) {
    final run = _activeRun;
    if (run == null) return;
    final current = run.metrics[name];
    if (current is! num || value > current) {
      run.setMetric(name, value);
    }
  }

  void reportPlaybackSourceSelected({
    required String source,
    String? serverTarget,
    required bool transcoded,
    required bool offline,
  }) {
    if (!enabled) return;
    final run = _activeRun;
    final isPlaybackRun =
        run != null && (run.scenario.startsWith("playback-startup-") || run.scenario == "artist-album-track-drilldown");
    if (!isPlaybackRun ||
        !run!.events.any((event) => event.name == "playback-action-received") ||
        _playbackSourceRunId == run.id) {
      return;
    }
    _playbackSourceRunId = run.id;

    mark(
      "playback-source-selected",
      values: {
        "source": source,
        if (serverTarget != null) "serverTarget": serverTarget,
        "transcoded": transcoded,
        "offline": offline,
      },
    );
    metric("playbackSourceLocalFile", source == "downloaded-file");
    metric("playbackSourceServer", source == "server");
    metric("playbackSourceTranscoded", transcoded);
    metric("playbackSourceOffline", offline);
  }

  void recordFrameTimings(List<FrameTiming> timings) {
    final run = _activeRun;

    for (final timing in timings) {
      final buildMicros = timing.buildDuration.inMicroseconds;
      final rasterMicros = timing.rasterDuration.inMicroseconds;
      final totalMicros = timing.totalSpan.inMicroseconds;

      if (_startupFrameCollectionOpen) {
        _startupFrameCount++;
        _startupFrameBuildMicrosTotal += buildMicros;
        _startupFrameRasterMicrosTotal += rasterMicros;
        _startupFrameTotalMicrosTotal += totalMicros;
        if (buildMicros > _startupFrameBuildMicrosMax) {
          _startupFrameBuildMicrosMax = buildMicros;
        }
        if (rasterMicros > _startupFrameRasterMicrosMax) {
          _startupFrameRasterMicrosMax = rasterMicros;
        }
        if (totalMicros > _startupFrameTotalMicrosMax) {
          _startupFrameTotalMicrosMax = totalMicros;
        }
        if (totalMicros > 16667) _startupFramesOver16_7ms++;
        if (totalMicros > 33333) _startupFramesOver33_3ms++;
        if (totalMicros > 50000) _startupFramesOver50ms++;
      }

      if (run == null) continue;
      incrementMetricBuffered("frameCount");
      incrementMetricBuffered("frameBuildMicrosTotal", buildMicros);
      incrementMetricBuffered("frameRasterMicrosTotal", rasterMicros);
      incrementMetricBuffered("frameTotalMicrosTotal", totalMicros);
      maxMetricBuffered("frameBuildMicrosMax", buildMicros);
      maxMetricBuffered("frameRasterMicrosMax", rasterMicros);
      maxMetricBuffered("frameTotalMicrosMax", totalMicros);

      if (totalMicros > 16667) {
        incrementMetricBuffered("framesOver16_7ms");
      }
      if (totalMicros > 33333) {
        incrementMetricBuffered("framesOver33_3ms");
      }
      if (totalMicros > 50000) {
        incrementMetricBuffered("framesOver50ms");
      }
    }
  }

  Future<void> reportStartupPhaseResult(String phase) async {
    if (!enabled) return;
    final nativeElapsed = await nativeLaunchElapsedMs();
    diagnostic(
      "startup-phase-result",
      values: {
        "phase": phase,
        "fullyReadyMs": processElapsedMs,
        if (nativeElapsed != null) ...{
          "nativeFullyReadyMs": nativeElapsed,
          "nativeToDartMainMs": (nativeElapsed - processElapsedMs).clamp(0.0, double.infinity),
        },
        "requestCount": _startupNetworkRequestCount,
        "responseBytes": _startupNetworkResponseBytes,
        "httpDurationMicrosTotal": _startupNetworkDurationMicros,
        "httpDurationMicrosMax": _startupNetworkDurationMicrosMax,
        "workerOperationCount": _startupWorkerOperationCount,
        "workerOperationFailed": _startupWorkerOperationFailed,
        "workerDurationMicrosTotal": _startupWorkerDurationMicros,
        "workerDurationMicrosMax": _startupWorkerDurationMicrosMax,
        "frameCount": _startupFrameCount,
        "framesOver16_7ms": _startupFramesOver16_7ms,
        "framesOver33_3ms": _startupFramesOver33_3ms,
        "framesOver50ms": _startupFramesOver50ms,
        "frameMicrosMax": _startupFrameTotalMicrosMax,
        "imageLoadStarted": _startupImageLoadStarted,
        "imageLoadCompleted": _startupImageLoadCompleted,
        "imageLoadFailed": _startupImageLoadFailed,
        "imageMaxConcurrentLoads": _startupImageMaxConcurrentLoads,
        "rssBytes": ProcessInfo.currentRss,
        "maxRssBytes": ProcessInfo.maxRss,
      },
    );
  }

  void reportStartupFrameSummary(String phase) {
    if (!enabled || !_startupFrameCollectionOpen) return;
    _startupFrameCollectionOpen = false;
    diagnostic(
      "startup-frame-summary",
      values: {
        "phase": phase,
        "frameCount": _startupFrameCount,
        "framesOver16_7ms": _startupFramesOver16_7ms,
        "framesOver33_3ms": _startupFramesOver33_3ms,
        "framesOver50ms": _startupFramesOver50ms,
        "buildMicrosTotal": _startupFrameBuildMicrosTotal,
        "rasterMicrosTotal": _startupFrameRasterMicrosTotal,
        "frameMicrosTotal": _startupFrameTotalMicrosTotal,
        "buildMicrosMax": _startupFrameBuildMicrosMax,
        "rasterMicrosMax": _startupFrameRasterMicrosMax,
        "frameMicrosMax": _startupFrameTotalMicrosMax,
        "imageLoadStarted": _startupImageLoadStarted,
        "imageLoadCompleted": _startupImageLoadCompleted,
        "imageLoadFailed": _startupImageLoadFailed,
        "imageLoadSynchronous": _startupImageLoadSynchronous,
        "imageMaxConcurrentLoads": _startupImageMaxConcurrentLoads,
        "rssBytes": ProcessInfo.currentRss,
        "maxRssBytes": ProcessInfo.maxRss,
        "processElapsedMs": processElapsedMs,
      },
    );
  }

  void incrementMetric(String name, [int amount = 1]) {
    final run = _activeRun;
    if (run == null) return;
    final current = run.metrics[name];
    final value = (current is int ? current : 0) + amount;
    run.setMetric(name, value);
    _emitHostRecord("metric", {
      "runId": run.id,
      "scenario": run.scenario,
      "variant": run.variant,
      "mode": run.mode,
      "name": name,
      "value": value,
    });
    unawaited(_persistActiveRun());
  }

  Future<T> runStartupTask<T>(String taskName, Future<T> Function() operation) async {
    if (!enabled) return operation();

    _startupPendingTasks++;
    _startupGeneration++;
    _startupTaskController.add(_startupPendingTasks);
    diagnostic("startup-task-start", values: {"task": taskName, "pendingTasks": _startupPendingTasks});

    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      _startupPendingTasks--;
      _startupGeneration++;
      _startupTaskController.add(_startupPendingTasks);
      diagnostic(
        "startup-task-complete",
        values: {
          "task": taskName,
          "pendingTasks": _startupPendingTasks,
          "durationMs": stopwatch.elapsedMicroseconds / 1000.0,
        },
      );
    }
  }

  void _uiActivityChanged() {
    _uiActivityGeneration++;
    _uiActivityController.add(_uiActivityGeneration);
  }

  void imageLoadStarted() {
    if (!enabled) return;
    _uiActivityChanged();
    _imageLoadsInFlight++;
    if (_startupFrameCollectionOpen) {
      _startupImageLoadStarted++;
      if (_imageLoadsInFlight > _startupImageMaxConcurrentLoads) {
        _startupImageMaxConcurrentLoads = _imageLoadsInFlight;
      }
    }
    _imageLoadGeneration++;
    _imageLoadController.add(_imageLoadsInFlight);
    incrementMetricBuffered("imageLoadStarted");
    maxMetricBuffered("imageMaxConcurrentLoads", _imageLoadsInFlight);
  }

  void imageLoadCompleted({bool failed = false, bool synchronous = false}) {
    if (!enabled) return;
    if (_startupFrameCollectionOpen) {
      if (failed) {
        _startupImageLoadFailed++;
      } else {
        _startupImageLoadCompleted++;
      }
      if (synchronous) {
        _startupImageLoadSynchronous++;
      }
    }
    if (_imageLoadsInFlight > 0) {
      _imageLoadsInFlight--;
    }
    _imageLoadGeneration++;
    _imageLoadController.add(_imageLoadsInFlight);
    _uiActivityChanged();
    incrementMetricBuffered(failed ? "imageLoadFailed" : "imageLoadCompleted");
    if (synchronous) {
      incrementMetricBuffered("imageLoadSynchronous");
    }
  }

  Future<void> waitForImageQuiescence({
    Duration quietPeriod = const Duration(milliseconds: 500),
    Duration timeout = const Duration(minutes: 15),
  }) async {
    if (!enabled) return;

    final overall = Stopwatch()..start();
    while (overall.elapsed < timeout) {
      if (_imageLoadsInFlight != 0) {
        await _imageLoadController.stream.firstWhere((pending) => pending == 0).timeout(timeout - overall.elapsed);
      }

      final generationAtZero = _imageLoadGeneration;
      await Future<void>.delayed(quietPeriod);
      if (_imageLoadsInFlight == 0 && _imageLoadGeneration == generationAtZero) {
        mark("image-loads-quiescent", values: {"waitDurationMs": overall.elapsedMicroseconds / 1000.0});
        return;
      }
    }

    throw TimeoutException("Image loads did not become quiescent", timeout);
  }

  void workerOperationStarted() {
    if (!enabled) return;
    _startupWorkerOperationCount++;
    _networkRequestsInFlight++;
    _networkGeneration++;
    _networkRequestController.add(_networkRequestsInFlight);
    _uiActivityChanged();
    incrementMetricBuffered("workerOperationCount");
    maxMetricBuffered("networkMaxConcurrentIncludingWorker", _networkRequestsInFlight);
  }

  void workerOperationCompleted({required int durationMicros, required bool failed}) {
    if (!enabled) return;
    _startupWorkerDurationMicros += durationMicros;
    if (durationMicros > _startupWorkerDurationMicrosMax) {
      _startupWorkerDurationMicrosMax = durationMicros;
    }
    if (failed) {
      _startupWorkerOperationFailed++;
    }
    incrementMetricBuffered("workerDurationMicrosTotal", durationMicros);
    maxMetricBuffered("workerDurationMicrosMax", durationMicros);
    if (failed) {
      incrementMetricBuffered("workerOperationFailed");
    }
    if (_networkRequestsInFlight > 0) {
      _networkRequestsInFlight--;
    }
    _networkGeneration++;
    _networkRequestController.add(_networkRequestsInFlight);
    _uiActivityChanged();
  }

  void networkRequestStarted() {
    if (!enabled) return;
    _startupNetworkRequestCount++;
    _networkRequestsInFlight++;
    _httpRequestsInFlight++;
    _networkGeneration++;
    _networkRequestController.add(_networkRequestsInFlight);
    _uiActivityChanged();
    incrementMetricBuffered("httpRequestCount");
    maxMetricBuffered("httpMaxConcurrentRequests", _httpRequestsInFlight);

    final run = _activeRun;
    if (run != null && _httpFirstRequestRunId != run.id) {
      _httpFirstRequestRunId = run.id;
      _httpFirstResponseRunId = null;
      mark("http-first-request-start", values: {"inFlight": _httpRequestsInFlight});
    }
  }

  void networkRequestCompleted({int? responseBytes, int? durationMicros, int? statusCode}) {
    if (!enabled) return;
    if (responseBytes != null && responseBytes >= 0) {
      _startupNetworkResponseBytes += responseBytes;
      incrementMetricBuffered("httpResponseBytes", responseBytes);
      incrementMetricBuffered("httpResponsesWithKnownBytes");
    } else {
      incrementMetricBuffered("httpResponsesUnknownBytes");
    }
    if (durationMicros != null && durationMicros >= 0) {
      _startupNetworkDurationMicros += durationMicros;
      if (durationMicros > _startupNetworkDurationMicrosMax) {
        _startupNetworkDurationMicrosMax = durationMicros;
      }
      incrementMetricBuffered("httpDurationMicrosTotal", durationMicros);
      maxMetricBuffered("httpDurationMicrosMax", durationMicros);
      incrementMetricBuffered("httpResponsesTimed");
    }
    if (statusCode != null) {
      final statusClass = statusCode ~/ 100;
      if (statusClass >= 1 && statusClass <= 5) {
        incrementMetricBuffered("httpStatus${statusClass}xx");
      } else {
        incrementMetricBuffered("httpStatusOther");
      }
    }

    final run = _activeRun;
    if (run != null && _httpFirstRequestRunId == run.id && _httpFirstResponseRunId != run.id) {
      _httpFirstResponseRunId = run.id;
      mark(
        "http-first-response-complete",
        values: {
          "responseBytesKnown": responseBytes != null,
          if (durationMicros != null) "durationMicros": durationMicros,
          if (statusCode != null) "statusClass": statusCode ~/ 100,
        },
      );
    }

    if (_httpRequestsInFlight > 0) {
      _httpRequestsInFlight--;
    }
    if (_networkRequestsInFlight > 0) {
      _networkRequestsInFlight--;
    }
    _networkGeneration++;
    _networkRequestController.add(_networkRequestsInFlight);
    _uiActivityChanged();
  }

  Future<void> waitForUiActivityQuiescence({
    Duration quietPeriod = const Duration(milliseconds: 200),
    Duration timeout = const Duration(minutes: 15),
  }) async {
    if (!enabled) return;

    final overall = Stopwatch()..start();
    diagnostic(
      "ui-quiescence-wait-start",
      values: {
        "networkInFlight": _networkRequestsInFlight,
        "imageLoadsInFlight": _imageLoadsInFlight,
        "quietPeriodMs": quietPeriod.inMilliseconds,
      },
    );

    while (overall.elapsed < timeout) {
      final remaining = timeout - overall.elapsed;
      if (_networkRequestsInFlight != 0 || _imageLoadsInFlight != 0) {
        final becameIdle = Completer<void>();
        late final StreamSubscription<int> subscription;
        subscription = _uiActivityController.stream.listen((_) {
          if (_networkRequestsInFlight == 0 && _imageLoadsInFlight == 0 && !becameIdle.isCompleted) {
            becameIdle.complete();
          }
        });
        if (_networkRequestsInFlight == 0 && _imageLoadsInFlight == 0 && !becameIdle.isCompleted) {
          becameIdle.complete();
        }
        try {
          await becameIdle.future.timeout(remaining);
        } finally {
          await subscription.cancel();
        }
        continue;
      }

      final settled = Completer<bool>();
      late final StreamSubscription<int> subscription;
      subscription = _uiActivityController.stream.listen((_) {
        if (!settled.isCompleted) settled.complete(false);
      });
      final generationAtIdle = _uiActivityGeneration;
      if (_networkRequestsInFlight != 0 || _imageLoadsInFlight != 0) {
        await subscription.cancel();
        continue;
      }

      final timer = Timer(quietPeriod, () {
        if (!settled.isCompleted) settled.complete(true);
      });
      bool stayedIdle;
      try {
        stayedIdle = await settled.future.timeout(remaining);
      } finally {
        timer.cancel();
        await subscription.cancel();
      }

      if (stayedIdle &&
          _networkRequestsInFlight == 0 &&
          _imageLoadsInFlight == 0 &&
          _uiActivityGeneration == generationAtIdle) {
        overall.stop();
        mark(
          "ui-fully-quiescent",
          values: {"waitDurationMs": overall.elapsedMicroseconds / 1000.0, "quietPeriodMs": quietPeriod.inMilliseconds},
        );
        metric("uiQuiescenceWaitMicros", overall.elapsedMicroseconds);
        return;
      }
    }

    throw TimeoutException("UI activity did not become quiescent", timeout);
  }

  Future<void> waitForNetworkQuiescence({
    Duration quietPeriod = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (!enabled) return;

    final overall = Stopwatch()..start();
    diagnostic(
      "network-quiescence-wait-start",
      values: {"inFlight": _networkRequestsInFlight, "quietPeriodMs": quietPeriod.inMilliseconds},
    );

    while (overall.elapsed < timeout) {
      if (_networkRequestsInFlight != 0) {
        await _networkRequestController.stream.firstWhere((pending) => pending == 0).timeout(timeout - overall.elapsed);
      }

      final generationAtZero = _networkGeneration;
      await Future<void>.delayed(quietPeriod);
      if (_networkRequestsInFlight == 0 && _networkGeneration == generationAtZero) {
        overall.stop();
        diagnostic(
          "network-quiescent",
          values: {"waitDurationMs": overall.elapsedMicroseconds / 1000.0, "processElapsedMs": processElapsedMs},
        );
        return;
      }
    }

    throw TimeoutException("Network activity did not become quiescent", timeout);
  }

  Future<void> waitForStartupQuiescence({
    Duration quietPeriod = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (!enabled) return;

    final overall = Stopwatch()..start();
    diagnostic(
      "startup-quiescence-wait-start",
      values: {"pendingTasks": _startupPendingTasks, "quietPeriodMs": quietPeriod.inMilliseconds},
    );

    while (overall.elapsed < timeout) {
      if (_startupPendingTasks != 0) {
        await _startupTaskController.stream.firstWhere((pending) => pending == 0).timeout(timeout - overall.elapsed);
      }

      final generationAtZero = _startupGeneration;
      await Future<void>.delayed(quietPeriod);

      if (_startupPendingTasks == 0 && _startupGeneration == generationAtZero) {
        overall.stop();
        diagnostic(
          "startup-quiescent",
          values: {"waitDurationMs": overall.elapsedMicroseconds / 1000.0, "processElapsedMs": processElapsedMs},
        );
        return;
      }
    }

    throw TimeoutException("Startup tasks did not become quiescent", timeout);
  }

  Future<void> waitForEvent(String name, {Duration timeout = const Duration(seconds: 60)}) {
    return _eventNameController.stream.firstWhere((eventName) => eventName == name).timeout(timeout);
  }

  Future<String> requestUiTab({
    required String contentType,
    required bool refresh,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    if (_activeTabCommand != null) {
      throw StateError("Another benchmark UI tab command is already active");
    }
    final command = PerformanceBenchmarkTabCommand(contentType: contentType, refresh: refresh);
    _activeTabCommand = command;
    mark("ui-tab-requested", values: {"contentType": contentType, "refresh": refresh});
    _tabController.add(command);
    try {
      await command.completed.timeout(timeout);
      final selectedContentType = command.selectedContentType;
      if (selectedContentType == null) {
        throw StateError("Benchmark tab completed without selected content type");
      }
      return selectedContentType;
    } finally {
      if (identical(_activeTabCommand, command)) {
        _activeTabCommand = null;
      }
    }
  }

  Future<void> requestDetail({
    required String targetAlias,
    required String targetType,
    required String itemId,
    required bool refresh,
    required void Function() open,
    Duration timeout = const Duration(minutes: 15),
  }) async {
    if (_activeDetailCommand != null) {
      throw StateError("Another benchmark detail command is already active");
    }
    final command = PerformanceBenchmarkDetailCommand(
      targetAlias: targetAlias,
      targetType: targetType,
      itemId: itemId,
      refresh: refresh,
    );
    _activeDetailCommand = command;
    mark("detail-open-requested", values: {"targetAlias": targetAlias, "targetType": targetType, "refresh": refresh});
    open();
    try {
      await command.completed.timeout(timeout);
    } finally {
      if (identical(_activeDetailCommand, command)) {
        _activeDetailCommand = null;
      }
    }
  }

  Future<String> requestSearch({
    required String contentType,
    required String queryAlias,
    required String query,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    if (_activeSearchCommand != null) {
      throw StateError("Another benchmark search command is already active");
    }

    final command = PerformanceBenchmarkSearchCommand(contentType: contentType, queryAlias: queryAlias, query: query);
    _activeSearchCommand = command;
    mark(
      "search-requested",
      values: {"contentType": contentType, "queryAlias": queryAlias, "queryLength": query.length},
    );
    _searchController.add(command);

    try {
      await command.completed.timeout(timeout);
      final selected = command.selectedContentType;
      if (selected == null) {
        throw StateError("Search completed without selected content type");
      }
      return selected;
    } finally {
      if (identical(_activeSearchCommand, command)) {
        _activeSearchCommand = null;
      }
    }
  }

  Future<bool> requestNextPage({required String contentType, Duration timeout = const Duration(minutes: 10)}) async {
    final command = PerformanceBenchmarkPageCommand(contentType: contentType);
    mark("page-requested", values: {"contentType": contentType});
    _pageController.add(command);
    return command.completed.timeout(timeout);
  }

  Future<void> requestAlphabetJump({
    required String contentType,
    required String letter,
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final command = PerformanceBenchmarkJumpCommand(contentType: contentType, letter: letter);
    mark("alphabet-jump-requested", values: {"contentType": contentType, "letter": letter});
    _jumpController.add(command);
    await command.completed.timeout(timeout);
  }

  Future<void> _persistActiveRun() {
    final run = _activeRun;
    if (run == null) return Future<void>.value();

    // Snapshot synchronously, then serialize writes in scheduling order.
    // This prevents an older asynchronous Hive write from completing after a
    // newer checkpoint and replacing it with stale recovery state.
    final encoded = jsonEncode(run.toJson());
    _persistWriteChain = _persistWriteChain.then((_) async {
      final box = await _getBox();
      await box.put(_activeRunKey, encoded);
    });
    return _persistWriteChain;
  }

  Future<void> _flushActiveRunPersistence() async {
    await _persistWriteChain;
  }

  void diagnostic(String name, {Map<String, Object?> values = const {}}) {
    if (!enabled) return;

    Map<String, Object?> outputValues = values;
    if (name == "suite-phase-complete" || name == "suite-complete") {
      outputValues = {
        ...values,
        "rssBytes": ProcessInfo.currentRss,
        "maxRssBytes": ProcessInfo.maxRss,
        "processElapsedMs": processElapsedMs,
      };
    }

    _emitHostRecord("diagnostic", {"name": name, if (outputValues.isNotEmpty) "values": outputValues});
  }

  static const Set<String> _privateCardinalityExportKeys = {
    "alphabetJumpPagesLoaded",
    "loadedItems",
    "itemsAdded",
    "pageItemsAdded",
    "pageSize",
    "playlistItemsSeen",
    "playlistPagesFetched",
  };

  static const Set<String> _privateCardinalityEventNames = {"alphabet-jump-page-requested"};

  Object? _sanitizeHostExportValue(Object? value) {
    if (value is Map<Object?, Object?>) {
      final sanitized = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_privateCardinalityExportKeys.contains(key)) {
          continue;
        }
        sanitized[key] = _sanitizeHostExportValue(entry.value);
      }
      return sanitized;
    }
    if (value is Iterable<Object?>) {
      final sanitized = <Object?>[];
      for (final item in value) {
        if (item is Map<Object?, Object?> && _privateCardinalityEventNames.contains(item["name"])) {
          continue;
        }
        sanitized.add(_sanitizeHostExportValue(item));
      }
      return sanitized;
    }
    return value;
  }

  void _emitHostRecord(String type, Map<String, Object?> payload) {
    // Some counters are needed locally to decide when paging/scroller work has
    // really completed, but exporting them can reveal the exact cardinality of
    // a private library once a list reaches its end. Keep them device-local in
    // the in-memory/Hive run state and remove them from every host-facing
    // record, including the final nested run JSON.
    if (type == "metric" && _privateCardinalityExportKeys.contains(payload["name"])) {
      return;
    }
    if (type == "event") {
      final event = payload["event"];
      if (event is Map<Object?, Object?> && _privateCardinalityEventNames.contains(event["name"])) {
        return;
      }
    }
    final sanitizedPayload = _sanitizeHostExportValue(payload) as Map<String, Object?>;
    final record = <String, Object?>{
      "type": type,
      "emittedAt": DateTime.now().toUtc().toIso8601String(),
      ...sanitizedPayload,
    };
    final encoded = jsonEncode(record);
    // Intentionally machine-readable for the macOS host-side benchmark collector.
    // Do not include media names, item ids, URLs, tokens or user identifiers.
    // ignore: avoid_print
    print("BENCH_JSON $encoded");
    if (enabled) {
      _hostWriteChain = _hostWriteChain.then((_) => _appendHostRecord(encoded));
    }
  }

  Future<void> _appendHostRecord(String encoded) async {
    final file = _hostStreamFile ??= File(
      path_helper.join((await getApplicationDocumentsDirectory()).path, _hostStreamFileName),
    );
    await file.writeAsString("$encoded\n", mode: FileMode.append, flush: true);
  }

  Future<void> resetHostStream() async {
    if (!enabled) return;
    _hostWriteChain = _hostWriteChain.then((_) async {
      final file = _hostStreamFile ??= File(
        path_helper.join((await getApplicationDocumentsDirectory()).path, _hostStreamFileName),
      );
      if (await file.exists()) {
        await file.delete();
      }
    });
    await _hostWriteChain;
  }

  Future<void> flushHostStream() async {
    await _hostWriteChain;
  }

  Future<T> runStep<T>({
    required String name,
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    mark("$name-start");
    try {
      final result = await operation().timeout(timeout);
      mark("$name-end");
      return result;
    } on TimeoutException catch (error, stackTrace) {
      await failActiveRun(result: PerformanceBenchmarkResult.timeout, error: error, stackTrace: stackTrace, step: name);
      rethrow;
    } catch (error, stackTrace) {
      await failActiveRun(result: PerformanceBenchmarkResult.failed, error: error, stackTrace: stackTrace, step: name);
      rethrow;
    }
  }

  Future<void> recordCrash(Object error, StackTrace stackTrace, {required String source}) async {
    final run = _activeRun;
    if (run == null) return;

    // Benchmark exports are deliberately stricter than normal Finamp logs.
    // Exception messages and stack traces can contain media names, item ids,
    // server URLs or local user paths, so never place them in BENCH_JSON.
    run.failure = {
      "type": "dart-error",
      "source": source,
      "errorType": error.runtimeType.toString(),
      "lastStep": run.lastStep,
    };
    run.mark("uncaught-error", values: {"source": source, "errorType": error.runtimeType.toString()});
    await _persistActiveRun();
  }

  Future<void> failActiveRun({
    required PerformanceBenchmarkResult result,
    required Object error,
    required StackTrace stackTrace,
    String? step,
  }) async {
    final run = _activeRun;
    if (run == null) return;

    run.result = result;
    run.failure = {"type": result.name, "errorType": error.runtimeType.toString(), "lastStep": step ?? run.lastStep};
    final rssEnd = ProcessInfo.currentRss;
    run.setMetric("rssEndBytes", rssEnd);
    run.setMetric("maxRssBytesAtEnd", ProcessInfo.maxRss);
    final rssStart = run.metrics["rssStartBytes"];
    if (rssStart is int) {
      run.setMetric("rssDeltaBytes", rssEnd - rssStart);
    }
    run.mark("run-failed", values: {"result": result.name, "errorType": error.runtimeType.toString()});
    run.stopwatch.stop();
    run.finished = true;
    _activeRun = null;

    await _flushActiveRunPersistence();
    final box = await _getBox();
    await box.put("$_runKeyPrefix${run.id}", jsonEncode(run.toJson()));
    await box.delete(_activeRunKey);
    _emitHostRecord("run-end", {"run": _publicRunJson(run)});
  }

  Future<void> saveOriginalOfflineState(bool value) async {
    final box = await _getBox();
    await box.put(_originalOfflineKey, jsonEncode(value));
  }

  Future<bool?> getOriginalOfflineState() async {
    final box = await _getBox();
    final encoded = box.get(_originalOfflineKey);
    if (encoded == null) return null;
    return jsonDecode(encoded) as bool;
  }

  Future<void> clearOriginalOfflineState() async {
    final box = await _getBox();
    await box.delete(_originalOfflineKey);
  }

  Future<void> setDownloadCleanupRequired({
    required String targetAlias,
    String? targetItemId,
    String? targetItemType,
    bool required = true,
  }) async {
    final box = await _getBox();
    if (required) {
      final target = targetItemId == null ? await getTarget(targetAlias) : null;
      final resolvedItemId = targetItemId ?? target?.itemId;
      final resolvedItemType = targetItemType ?? target?.itemType;
      await box.put(
        _cleanupRequiredKey,
        jsonEncode({
          "targetAlias": targetAlias,
          "ownerSuiteRunId": suiteRunId,
          if (resolvedItemId != null) "targetItemId": resolvedItemId,
          if (resolvedItemType != null) "targetItemType": resolvedItemType,
          "createdAt": DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } else {
      await box.delete(_cleanupRequiredKey);
    }
  }

  Future<Map<String, dynamic>?> getDownloadCleanupRequirement() async {
    final box = await _getBox();
    final encoded = box.get(_cleanupRequiredKey);
    return encoded == null ? null : jsonDecode(encoded) as Map<String, dynamic>;
  }

  Future<bool> isDownloadCleanupTarget(String itemId) async {
    final requirement = await getDownloadCleanupRequirement();
    if (requirement == null) return false;

    final storedItemId = requirement["targetItemId"] as String?;
    if (storedItemId != null) {
      return storedItemId == itemId;
    }

    final alias = requirement["targetAlias"] as String?;
    if (alias == null) return false;
    final target = await getTarget(alias) ?? await getLegacyTargetForCleanup(alias);
    return target?.itemId == itemId;
  }

  Future<void> markDownloadCleanupStarted() async {
    mark("download-cleanup-start");
    await _persistActiveRun();
  }

  Future<void> markDownloadCleanupCompleted() async {
    mark("download-cleanup-complete");
    await setDownloadCleanupRequired(targetAlias: "", required: false);
    await _persistActiveRun();
  }

  Future<PerformanceBenchmarkRun> finishRun({Map<String, Object?> metrics = const {}}) async {
    final run = _activeRun;
    if (run == null) {
      throw StateError("No benchmark run is active");
    }

    for (final entry in metrics.entries) {
      run.setMetric(entry.key, entry.value);
    }
    final rssEnd = ProcessInfo.currentRss;
    run.setMetric("rssEndBytes", rssEnd);
    run.setMetric("maxRssBytesAtEnd", ProcessInfo.maxRss);
    final rssStart = run.metrics["rssStartBytes"];
    if (rssStart is int) {
      run.setMetric("rssDeltaBytes", rssEnd - rssStart);
    }
    run.mark("run-end");
    run.stopwatch.stop();
    run.finished = true;
    run.result = run.failure == null ? PerformanceBenchmarkResult.success : PerformanceBenchmarkResult.failed;
    _activeRun = null;

    await _flushActiveRunPersistence();
    final box = await _getBox();
    await box.put("$_runKeyPrefix${run.id}", jsonEncode(run.toJson()));
    await box.delete(_activeRunKey);
    _emitHostRecord("run-end", {"run": _publicRunJson(run)});
    return run;
  }

  Future<void> cancelRun() async {
    final run = _activeRun;
    if (run == null) return;
    run.mark("run-cancelled");
    final rssEnd = ProcessInfo.currentRss;
    run.setMetric("rssEndBytes", rssEnd);
    run.setMetric("maxRssBytesAtEnd", ProcessInfo.maxRss);
    final rssStart = run.metrics["rssStartBytes"];
    if (rssStart is int) {
      run.setMetric("rssDeltaBytes", rssEnd - rssStart);
    }
    run.stopwatch.stop();
    run.finished = true;
    run.result = PerformanceBenchmarkResult.cancelled;
    _activeRun = null;
    await _flushActiveRunPersistence();
    final box = await _getBox();
    await box.put("$_runKeyPrefix${run.id}", jsonEncode(run.toJson()));
    await box.delete(_activeRunKey);
    _emitHostRecord("run-end", {"run": _publicRunJson(run)});
  }

  Future<List<Map<String, dynamic>>> getRuns() async {
    final box = await _getBox();
    final runs = box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_runKeyPrefix))
        .map(box.get)
        .whereType<String>()
        .map((encoded) => jsonDecode(encoded) as Map<String, dynamic>)
        .toList();

    runs.sort((a, b) => (a["startedAt"] as String).compareTo(b["startedAt"] as String));
    return runs;
  }

  Future<void> clearRuns() async {
    final box = await _getBox();
    await box.deleteAll(box.keys.whereType<String>().where((key) => key.startsWith(_runKeyPrefix)));
  }

  Future<void> clearTargets() async {
    final box = await _getBox();
    await box.deleteAll(box.keys.whereType<String>().where((key) => key.startsWith(_targetKeyPrefix)));
  }

  Future<Uint8List> exportBytes() async {
    final runs = (await getRuns()).map(_publicRunJsonMap).toList(growable: false);
    final export = {"schemaVersion": 2, "generatedAt": DateTime.now().toUtc().toIso8601String(), "runs": runs};
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent("  ").convert(export)));
  }

  Future<void> export() async {
    final fileName =
        "finamp-performance-benchmark-${DateTime.now().toIso8601String().replaceAll(RegExp(r'[/?<>:*|.\\"]'), "-")}.json";

    await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: (await getApplicationDocumentsDirectory()).path + path_helper.separator,
      bytes: await exportBytes(),
    );
  }
}
