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
import 'package:finamp/services/hidden_items.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';

final library = BaseItemDto(id: const BaseItemId('library'), name: 'Music', type: 'CollectionFolder');

BaseItemDto track(String id) => BaseItemDto(id: BaseItemId(id), name: id, type: 'Audio');

class FixtureApi extends Fake implements JellyfinApiHelper {
  List<BaseItemDto> results = [];
  List<BaseItemId>? excluded;
  int? limit;

  @override
  Future<QueryResult_BaseItemDto> getItemsWithTotalRecordCount({
    BaseItemDto? parentItem,
    BaseItemId? libraryFilter,
    String? includeItemTypes,
    String? sortBy,
    String? sortOrder,
    String? searchTerm,
    List<BaseItemId>? itemIds,
    List<BaseItemId>? albumIds,
    List<BaseItemId>? excludeItemIds,
    String? tags,
    String? filters,
    String? fields,
    bool? recursive,
    ArtistType? artistType,
    BaseItemId? genreFilter,
    bool? isFavorite,
    String? nameStartsWith,
    String? nameLessThan,
    int? startIndex,
    int? limit,
  }) async {
    excluded = excludeItemIds;
    this.limit = limit;
    return QueryResult_BaseItemDto(
      items: results.take(limit ?? results.length).toList(),
      totalRecordCount: 1000,
      startIndex: 0,
    );
  }
}

class FixtureDownloads extends Fake implements DownloadsService {
  List<BaseItemDto> tracks = [];

  @override
  Future<List<DownloadStub>> getAllTracks({
    String? nameFilter,
    BaseItemDto? relatedTo,
    BaseItemId? viewFilter,
    bool nullableViewFilters = true,
    bool onlyFavorites = false,
    BaseItemId? genreFilter,
  }) async => tracks.map((item) => DownloadStub.fromItem(type: DownloadItemType.track, item: item)).toList();
}

class FixtureUserHelper extends Fake implements FinampUserHelper {}

class FixtureQueue extends Fake implements QueueService {}

void main() {
  late Directory directory;
  late FixtureApi api;
  late FixtureDownloads downloads;

  Future<void> setUpWith({required Set<BaseItemId> hidden, bool offline = false}) async {
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
        deviceId: 'hidden-shuffle-fixture',
        isOffline: offline,
        trackShuffleItemCount: 3,
      ),
    );
    final container = ProviderContainer(overrides: [hiddenIdsProvider.overrideWithValue(hidden)]);
    addTearDown(container.dispose);
    GetIt.instance
      ..registerSingleton<ProviderContainer>(container)
      ..registerSingleton<JellyfinApiHelper>(api)
      ..registerSingleton<DownloadsService>(downloads)
      ..registerSingleton<FinampUserHelper>(FixtureUserHelper())
      ..registerSingleton<QueueService>(FixtureQueue());
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finamp-hidden-shuffle-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(28)) {
      Hive.registerAdapters();
      Hive.registerAdapter(ThemeModeAdapter());
      Hive.registerAdapter(ColorAdapter());
      Hive.registerAdapter(LocaleAdapter());
    }
    api = FixtureApi();
    downloads = FixtureDownloads();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('online shuffle asks the server to leave out hidden items', () async {
    await setUpWith(hidden: {const BaseItemId('h1'), const BaseItemId('h2')});
    api.results = [track('a'), track('b'), track('c')];

    final (items, _) = (await AudioServiceHelper().getShuffleAllTracks(onlyShowFavorites: false, library: library))!;

    expect(api.excluded, unorderedEquals([const BaseItemId('h1'), const BaseItemId('h2')]));
    expect(api.limit, 3);
    expect(items.map((item) => item.id.raw), ['a', 'b', 'c']);
  });

  test('online shuffle over-fetches past the exclusion cap and trims to the requested count', () async {
    final hidden = {for (var i = 0; i < maxExcludedIds + 2; i++) BaseItemId('h$i')};
    await setUpWith(hidden: hidden);
    // the two hidden ids past the cap come back from the server and must be dropped
    api.results = [track('h${maxExcludedIds + 1}'), track('a'), track('h$maxExcludedIds'), track('b'), track('c')];

    final (items, _) = (await AudioServiceHelper().getShuffleAllTracks(onlyShowFavorites: false, library: library))!;

    expect(api.excluded, hasLength(maxExcludedIds));
    expect(api.limit, 5);
    expect(items.map((item) => item.id.raw), ['a', 'b', 'c']);
  });

  test('offline shuffle returns the full count without hidden tracks', () async {
    await setUpWith(hidden: {const BaseItemId('h1'), const BaseItemId('h2')}, offline: true);
    downloads.tracks = [
      track('h1'),
      track('a'),
      track('h2'),
      track('b'),
      track('c'),
      track('d'),
      track('e'),
      track('f'),
    ];

    final (items, total) = (await AudioServiceHelper().getShuffleAllTracks(
      onlyShowFavorites: false,
      library: library,
    ))!;

    expect(items, hasLength(3));
    expect(items.map((item) => item.id.raw), everyElement(isNot(startsWith('h'))));
    expect(total, 6);
  });
}
