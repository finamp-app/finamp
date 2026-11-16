import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/music_screen_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

final playlistItem = BaseItemDto(
  id: const BaseItemId('test-playlist-1'),
  name: 'My Offline Playlist',
  type: 'Playlist',
);

final playlistStub = DownloadStub.fromItem(
  type: DownloadItemType.collection,
  item: playlistItem,
);

class FixtureDownloadsService extends Fake implements DownloadsService {
  final calls = <Invocation>[];
  List<DownloadStub> collections = [playlistStub];

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
  }) async {
    calls.add(
      Invocation.method(#getAllCollections, [], {
        #nameFilter: nameFilter,
        #includeItemTypes: includeItemTypes,
        #relatedTo: relatedTo,
        #fullyDownloaded: fullyDownloaded,
        #viewFilter: viewFilter,
        #childViewFilter: childViewFilter,
        #nullableViewFilters: nullableViewFilters,
        #onlyFavorites: onlyFavorites,
        #infoForType: infoForType,
        #artistType: artistType,
        #genreFilter: genreFilter,
      }),
    );
    // If viewFilter is provided and nullableViewFilters is false, collections without viewId are excluded
    if (viewFilter != null && !nullableViewFilters) {
      return [];
    }
    return collections;
  }
}

void main() {
  tearDown(() async => GetIt.instance.reset());

  test('offline playlists load even when currentView is null and do not apply library viewFilter', () async {
    final downloads = FixtureDownloadsService();
    GetIt.instance.registerSingleton<DownloadsService>(downloads);

    final settings = FinampSettings(
      downloadLocations: [],
      downloadLocationsMap: {},
      tabSortBy: {},
      tabSortOrder: {},
      homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
      gridImageSize: 160,
      homeScreenImageSize: 160,
      deviceId: 'test-device',
      isOffline: true,
      showDownloadsWithUnknownLibrary: false,
    );

    final container = ProviderContainer(
      overrides: [
        finampSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        FinampUserHelper.finampCurrentUserProvider.overrideWith((ref) => null),
      ],
    );
    GetIt.instance.registerSingleton<ProviderContainer>(container);
    addTearDown(container.dispose);
    await container.read(finampSettingsProvider.future);

    final request = MusicScreenPlayable(
      tab: ContentType.playlists,
      library: currentLibraryPlaceholder,
      source: const QueueItemSource.rawId(
        type: QueueItemSourceType.homeScreenSection,
        name: QueueItemSourceName(type: QueueItemSourceNameType.homeScreenSection),
        id: 'playlists',
      ),
      sortConfig: SortAndFilterConfiguration.defaultSort,
    );

    final items = await container.read(
      loadHomeSectionItemsProvider(request: request, startIndex: 0, limit: 10).future,
    );
    expect(items?.map((item) => item.name), ['My Offline Playlist']);
    expect(downloads.calls.single.namedArguments[#viewFilter], isNull);
    expect(downloads.calls.single.namedArguments[#childViewFilter], isNull);
  });
}
