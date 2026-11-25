import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/services/data_source_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';

FinampQueueInfo queueInfo({
  required int trackCount,
  required int undownloadedTracks,
  bool currentTrackUndownloaded = false,
}) {
  const source = QueueItemSource.rawId(
    type: QueueItemSourceType.unknown,
    name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: 'Fixture'),
    id: 'fixture-source',
  );
  assert(!currentTrackUndownloaded || (trackCount > 0 && undownloadedTracks > 0));
  final queueUndownloadedTracks = undownloadedTracks - (currentTrackUndownloaded ? 1 : 0);
  final queue = List.generate(
    trackCount - (currentTrackUndownloaded ? 1 : 0),
    (index) => FinampQueueItem(
      item: MediaItem(
        id: 'fixture-$index',
        title: 'Fixture $index',
        extras: {'android.media.extra.DOWNLOAD_STATUS': index < queueUndownloadedTracks ? 0 : 2},
      ),
      source: source,
    ),
  );
  return FinampQueueInfo(
    id: 'fixture-queue',
    previousTracks: [],
    currentTrack: currentTrackUndownloaded
        ? FinampQueueItem(
            item: const MediaItem(
              id: 'fixture-current',
              title: 'Current fixture',
              extras: {'android.media.extra.DOWNLOAD_STATUS': 0},
            ),
            source: source,
          )
        : null,
    nextUp: [],
    queue: queue,
    source: source,
    saveState: SavedQueueState.init,
    sourceLibrary: null,
  );
}

void main() {
  late Directory directory;
  late FinampSettings settings;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finamp-data-source-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(28)) {
      Hive.registerAdapters();
      Hive.registerAdapter(ThemeModeAdapter());
      Hive.registerAdapter(ColorAdapter());
      Hive.registerAdapter(LocaleAdapter());
    }
    final box = await Hive.openBox<FinampSettings>('FinampSettings', bytes: Uint8List(0));
    settings = FinampSettings(
      downloadLocations: [],
      downloadLocationsMap: {},
      tabSortBy: {},
      tabSortOrder: {},
      homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
      gridImageSize: 160,
      homeScreenImageSize: 160,
      deviceId: 'data-source-fixture',
    );
    await box.put('FinampSettings', settings);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('decideNetworkQueueReloadAction', () {
    test('does nothing when returning online', () {
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toOnline, queueInfo(trackCount: 10, undownloadedTracks: 10)),
        NetworkQueueReloadAction.none,
      );
    });

    test('does nothing for an empty queue', () {
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toOffline, queueInfo(trackCount: 0, undownloadedTracks: 0)),
        NetworkQueueReloadAction.none,
      );
    });

    test('shows the distinct loss-limit prompt above the configured limit', () {
      settings
        ..autoReloadQueue = true
        ..autoReloadQueueMaxDroppedTracksPercentage = 30;
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toOffline, queueInfo(trackCount: 10, undownloadedTracks: 4)),
        NetworkQueueReloadAction.manualLossLimitExceeded,
      );
    });

    test('reloads automatically for a loss equal to the configured limit', () {
      settings
        ..autoReloadQueue = true
        ..autoReloadQueueMaxDroppedTracksPercentage = 30;
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toOffline, queueInfo(trackCount: 10, undownloadedTracks: 3)),
        NetworkQueueReloadAction.automatic,
      );
    });

    test('shows a manual prompt when an offline reload would interrupt the current streamed track', () {
      settings
        ..autoReloadQueue = true
        ..autoReloadQueueMaxDroppedTracksPercentage = 100;
      expect(
        decideNetworkQueueReloadAction(
          SourceChangeType.toOffline,
          queueInfo(trackCount: 10, undownloadedTracks: 1, currentTrackUndownloaded: true),
        ),
        NetworkQueueReloadAction.manualCurrentTrackNotDownloaded,
      );
    });

    test('still reloads automatically when only a non-current track is missing within the limit', () {
      settings
        ..autoReloadQueue = true
        ..autoReloadQueueMaxDroppedTracksPercentage = 30;
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toOffline, queueInfo(trackCount: 10, undownloadedTracks: 1)),
        NetworkQueueReloadAction.automatic,
      );
    });

    test('supports the strict and always-reload endpoints without rounding', () {
      settings
        ..autoReloadQueue = true
        ..autoReloadQueueMaxDroppedTracksPercentage = 0;
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toOffline, queueInfo(trackCount: 10, undownloadedTracks: 1)),
        NetworkQueueReloadAction.manualLossLimitExceeded,
      );

      settings.autoReloadQueueMaxDroppedTracksPercentage = 100;
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toOffline, queueInfo(trackCount: 10, undownloadedTracks: 10)),
        NetworkQueueReloadAction.automatic,
      );
    });

    test('keeps the existing manual prompt when automatic reload is disabled', () {
      settings.autoReloadQueue = false;
      expect(
        decideNetworkQueueReloadAction(SourceChangeType.toRemoteUrl, queueInfo(trackCount: 10, undownloadedTracks: 1)),
        NetworkQueueReloadAction.manualPrompt,
      );
    });
  });
}
