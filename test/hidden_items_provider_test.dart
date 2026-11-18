import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/hidden_items.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';

FinampUser user(String id) => FinampUser(
  id: id,
  publicAddress: 'http://fixture',
  localAddress: 'http://fixture',
  preferLocalNetwork: false,
  isLocal: false,
  accessToken: 'token',
  serverId: 'server',
);

BaseItemDto item(String id, {String type = 'Audio', String? albumId, List<String>? tags}) => BaseItemDto(
  id: BaseItemId(id),
  name: id,
  type: type,
  albumId: albumId == null ? null : BaseItemId(albumId),
  tags: tags,
);

class FixtureApi extends Fake implements JellyfinApiHelper {
  List<BaseItemDto> tagged = [];
  bool fail = false;
  final requests = <({String? tags, String? includeItemTypes})>[];
  final serverChanges = <(BaseItemId, bool)>[];
  // When set, server changes wait for it, so tests can look at the app state mid-request.
  Completer<void>? pendingServerChange;

  @override
  Future<List<BaseItemDto>?> getItems({
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
    String? nameStartsWithOrGreater,
    String? nameLessThan,
    int? startIndex,
    int? limit,
  }) async {
    requests.add((tags: tags, includeItemTypes: includeItemTypes));
    if (fail) throw Exception('server unavailable');
    return tagged;
  }

  @override
  Future<void> setServerHidden(BaseItemId itemId, bool hidden) async {
    serverChanges.add((itemId, hidden));
    await pendingServerChange?.future;
  }
}

class FixtureUserHelper extends Fake implements FinampUserHelper {
  @override
  FinampUser? get currentUser => null;
}

class FixtureDownloads extends Fake implements DownloadsService {
  List<BaseItemDto> tracks = [];
  List<BaseItemDto> collections = [];

  DownloadStub stub(BaseItemDto item) => DownloadStub.fromItem(
    type: item.type == 'Audio' ? DownloadItemType.track : DownloadItemType.collection,
    item: item,
  );

  @override
  Future<List<DownloadStub>> getAllTracks({
    String? nameFilter,
    BaseItemDto? relatedTo,
    BaseItemId? viewFilter,
    bool nullableViewFilters = true,
    bool onlyFavorites = false,
    BaseItemId? genreFilter,
  }) async => tracks.map(stub).toList();

  @override
  Future<List<DownloadStub>> getAllCollections({
    String? nameFilter,
    List<BaseItemDtoType> includeItemTypes = const [],
    BaseItemDto? relatedTo,
    bool fullyDownloaded = false,
    BaseItemId? viewFilter,
    BaseItemId? childViewFilter,
    bool nullableViewFilters = true,
    bool onlyFavorites = false,
    BaseItemDtoType? infoForType,
    ArtistType? artistType,
    BaseItemId? genreFilter,
  }) async => collections.map(stub).toList();
}

void main() {
  late Directory directory;
  late FixtureApi api;
  late FixtureDownloads downloads;
  late ProviderContainer container;

  ProviderContainer containerFor(String userId) =>
      ProviderContainer(overrides: [FinampUserHelper.finampCurrentUserProvider.overrideWithValue(user(userId))]);

  Future<void> setOffline(bool offline) async {
    final box = Hive.box<FinampSettings>('FinampSettings');
    await box.put('FinampSettings', box.get('FinampSettings')!..isOffline = offline);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finamp-hidden-items-test-');
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
        deviceId: 'hidden-items-fixture',
      ),
    );
    await Hive.openBox<List<dynamic>>(hiddenItemsBoxName);
    api = FixtureApi();
    downloads = FixtureDownloads();
    GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
    GetIt.instance.registerSingleton<DownloadsService>(downloads);
    GetIt.instance.registerSingleton<FinampUserHelper>(FixtureUserHelper());
    container = containerFor('user-a');
  });

  tearDown(() async {
    container.dispose();
    await GetIt.instance.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('local hidden ids', () {
    test('hide and unhide persist for the current user only', () async {
      await container.read(localHiddenIdsProvider.notifier).hide(const BaseItemId('a'));
      await container.read(localHiddenIdsProvider.notifier).hide(const BaseItemId('b'));
      await container.read(localHiddenIdsProvider.notifier).unhide(const BaseItemId('a'));

      expect(container.read(localHiddenIdsProvider), {const BaseItemId('b')});
      expect(Hive.box<List<dynamic>>(hiddenItemsBoxName).get('user-a'), ['b']);

      final otherUser = containerFor('user-b');
      addTearDown(otherUser.dispose);
      expect(otherUser.read(localHiddenIdsProvider), isEmpty);
    });

    test('reload from storage', () async {
      await Hive.box<List<dynamic>>(hiddenItemsBoxName).put('user-a', ['x']);
      expect(containerFor('user-a').read(localHiddenIdsProvider), {const BaseItemId('x')});
    });

    test('survive resetting all settings', () async {
      await container.read(localHiddenIdsProvider.notifier).hide(const BaseItemId('a'));
      FinampSettingsHelper.resetAllSettings();
      expect(Hive.box<List<dynamic>>(hiddenItemsBoxName).get('user-a'), ['a']);
    });
  });

  group('server hidden ids', () {
    test('load tracks and albums with the hidden tag from the server', () async {
      api.tagged = [
        item('t1', tags: [hiddenTag]),
        item('al1', type: 'MusicAlbum', tags: [hiddenTag]),
      ];

      expect(await container.read(serverHiddenIdsProvider.future), {const BaseItemId('t1'), const BaseItemId('al1')});
      expect(api.requests.single, (tags: hiddenTag, includeItemTypes: 'Audio,MusicAlbum'));
    });

    test('load from downloaded items while offline', () async {
      await setOffline(true);
      downloads.tracks = [
        item('t1', tags: [hiddenTag]),
        item('t2'),
      ];
      downloads.collections = [
        item('al1', type: 'MusicAlbum', tags: ['Hidden']),
      ];

      expect(await container.read(serverHiddenIdsProvider.future), {const BaseItemId('t1'), const BaseItemId('al1')});
      expect(api.requests, isEmpty);
    });

    test('setHidden shows the change before the server answers', () async {
      api.tagged = [
        item('t1', tags: [hiddenTag]),
      ];
      await container.read(serverHiddenIdsProvider.future);
      api.pendingServerChange = Completer();

      final unhide = container.read(serverHiddenIdsProvider.notifier).setHidden(const BaseItemId('t1'), false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(serverHiddenIdsProvider).value, isEmpty);

      api.pendingServerChange!.complete();
      await unhide;
      expect(container.read(serverHiddenIdsProvider).value, isEmpty);
    });

    test('setHidden puts the change back when the server fails', () async {
      await container.read(serverHiddenIdsProvider.future);
      api.pendingServerChange = Completer();

      final hide = container.read(serverHiddenIdsProvider.notifier).setHidden(const BaseItemId('t1'), true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(serverHiddenIdsProvider).value, {const BaseItemId('t1')});

      api.pendingServerChange!.completeError(Exception('server unavailable'));
      await expectLater(hide, throwsException);
      expect(container.read(serverHiddenIdsProvider).value, isEmpty);
    });

    test('setHidden updates the server and the cached ids', () async {
      await container.read(serverHiddenIdsProvider.future);
      await container.read(serverHiddenIdsProvider.notifier).setHidden(const BaseItemId('t1'), true);
      expect(container.read(serverHiddenIdsProvider).value, {const BaseItemId('t1')});

      await container.read(serverHiddenIdsProvider.notifier).setHidden(const BaseItemId('t1'), false);
      expect(container.read(serverHiddenIdsProvider).value, isEmpty);
      expect(api.serverChanges, [(const BaseItemId('t1'), true), (const BaseItemId('t1'), false)]);
    });
  });

  group('hidden ids', () {
    test('merge local and server ids', () async {
      api.tagged = [
        item('al1', type: 'MusicAlbum', tags: [hiddenTag]),
      ];
      await container.read(serverHiddenIdsProvider.future);
      await container.read(localHiddenIdsProvider.notifier).hide(const BaseItemId('t1'));

      expect(container.read(hiddenIdsProvider), {const BaseItemId('t1'), const BaseItemId('al1')});
    });

    test('still return local hides when the server ids fail to load', () async {
      api.fail = true;
      await container.read(localHiddenIdsProvider.notifier).hide(const BaseItemId('t1'));
      await container.read(serverHiddenIdsProvider.future);

      expect(container.read(hiddenIdsProvider), {const BaseItemId('t1')});
    });

    test('hide a track whose album is hidden on the server', () async {
      api.tagged = [
        item('al1', type: 'MusicAlbum', tags: [hiddenTag]),
      ];
      await container.read(serverHiddenIdsProvider.future);

      expect(container.read(isHiddenProvider(item('t1', albumId: 'al1'))), isTrue);
      expect(container.read(isHiddenProvider(item('t2', albumId: 'al2'))), isFalse);
    });
  });
}
