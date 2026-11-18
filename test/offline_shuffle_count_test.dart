import 'dart:io';
import 'dart:typed_data';

import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';

final library = BaseItemDto(id: const BaseItemId('library'), name: 'Music', type: 'CollectionFolder');

class FixtureDownloads extends Fake implements DownloadsService {
  int trackCount = 0;

  @override
  Future<List<DownloadStub>> getAllTracks({
    String? nameFilter,
    BaseItemDto? relatedTo,
    BaseItemId? viewFilter,
    bool nullableViewFilters = true,
    bool onlyFavorites = false,
    BaseItemId? genreFilter,
  }) async => [
    for (var i = 0; i < trackCount; i++)
      DownloadStub.fromItem(
        type: DownloadItemType.track,
        item: BaseItemDto(id: BaseItemId('$i'), name: '$i', type: 'Audio'),
      ),
  ];
}

class FixtureApi extends Fake implements JellyfinApiHelper {}

class FixtureUserHelper extends Fake implements FinampUserHelper {}

class FixtureQueue extends Fake implements QueueService {}

void main() {
  const shuffleCount = 3;
  late Directory directory;
  late FixtureDownloads downloads;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finamp-offline-shuffle-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(28)) {
      Hive.registerAdapters();
      Hive.registerAdapter(ThemeModeAdapter());
      Hive.registerAdapter(ColorAdapter());
      Hive.registerAdapter(LocaleAdapter());
    }
    final settingsBox = await Hive.openBox<FinampSettings>('FinampSettings', bytes: Uint8List(0));
    await settingsBox.put(
      'FinampSettings',
      FinampSettings(
        downloadLocations: [],
        downloadLocationsMap: {},
        tabSortBy: {},
        tabSortOrder: {},
        homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
        gridImageSize: 160,
        homeScreenImageSize: 160,
        deviceId: 'offline-shuffle-fixture',
        isOffline: true,
        trackShuffleItemCount: shuffleCount,
      ),
    );
    downloads = FixtureDownloads();
    final container = ProviderContainer(overrides: [hiddenIdsProvider.overrideWithValue({})]);
    addTearDown(container.dispose);
    GetIt.instance
      ..registerSingleton<ProviderContainer>(container)
      ..registerSingleton<DownloadsService>(downloads)
      ..registerSingleton<JellyfinApiHelper>(FixtureApi())
      ..registerSingleton<FinampUserHelper>(FixtureUserHelper())
      ..registerSingleton<QueueService>(FixtureQueue());
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<(List<BaseItemDto>, int)> shuffle(int downloadedTracks) async {
    downloads.trackCount = downloadedTracks;
    return (await AudioServiceHelper().getShuffleAllTracks(onlyShowFavorites: false, library: library))!;
  }

  test('returns every download when there are fewer than the shuffle count', () async {
    final (items, total) = await shuffle(shuffleCount - 1);
    expect(items, hasLength(shuffleCount - 1));
    expect(total, shuffleCount - 1);
  });

  test('returns the shuffle count when downloads match it exactly', () async {
    final (items, _) = await shuffle(shuffleCount);
    expect(items, hasLength(shuffleCount));
  });

  test('returns the shuffle count when there is exactly one extra download', () async {
    final (items, total) = await shuffle(shuffleCount + 1);
    expect(items, hasLength(shuffleCount));
    expect(total, shuffleCount + 1);
  });

  test('returns the shuffle count when there are many more downloads', () async {
    final (items, _) = await shuffle(shuffleCount + 10);
    expect(items, hasLength(shuffleCount));
  });
}
