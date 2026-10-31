import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/artist_content_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

final artist = BaseItemDto(id: const BaseItemId('selected'), name: 'Guest', type: 'MusicArtist');
final album = BaseItemDto(id: const BaseItemId('shared-album'), name: 'Shared album', type: 'MusicAlbum');
const library = LibraryId('library');
const genre = BaseItemId('genre');

BaseItemDto song(String id, List<String>? credits, {bool favorite = false}) => BaseItemDto(
  id: BaseItemId(id),
  name: id,
  type: 'Audio',
  artistItems: credits?.map((id) => NameIdPair(id: BaseItemId(id), name: 'Guest')).toList(),
  userData: UserItemDataDto(playbackPositionTicks: 0, playCount: 0, isFavorite: favorite, played: false),
);

class FixtureDownloads extends Fake implements DownloadsService {
  List<BaseItemDto> tracks = [];
  final calls = <Invocation>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getCollectionTracks) {
      calls.add(invocation);
      final favorites = invocation.namedArguments[#onlyFavorites] == true;
      return Future.value(tracks.where((track) => !favorites || track.userData!.isFavorite).toList());
    }
    return super.noSuchMethod(invocation);
  }
}

class FixtureApi extends Fake implements JellyfinApiHelper {
  final calls = <Invocation>[];
  List<BaseItemDto> tracks = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getItems) {
      calls.add(invocation);
      return Future<List<BaseItemDto>?>.value(tracks);
    }
    return super.noSuchMethod(invocation);
  }
}

Future<ProviderContainer> fixture(FixtureDownloads downloads, FixtureApi api, {bool offline = true}) async {
  GetIt.instance.registerSingleton<DownloadsService>(downloads);
  GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
  final config = FinampSettings(
    downloadLocations: [],
    downloadLocationsMap: {},
    tabSortBy: {},
    tabSortOrder: {},
    homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
    gridImageSize: 160,
    homeScreenImageSize: 160,
    deviceId: 'offline-artist-test',
    isOffline: offline,
  );
  final container = ProviderContainer(
    overrides: [
      finampSettingsProvider.overrideWith((ref) => Stream.value(config)),
      getPerformingArtistAlbumsProvider(
        artist: artist,
        libraryFilter: library,
        genreFilter: genre,
      ).overrideWith((ref) async => [album]),
      getArtistAlbumsProvider(
        artist: artist,
        libraryFilter: library,
        genreFilter: genre,
      ).overrideWith((ref) async => [album]),
    ],
  );
  addTearDown(container.dispose);
  await container.read(finampSettingsProvider.future);
  return container;
}

void main() {
  tearDown(() async => GetIt.instance.reset());

  test('offline performing tracks match the selected artist ID, including feature credits', () async {
    final downloads = FixtureDownloads()
      ..tracks = [
        song('solo', ['selected']),
        song('feature', ['other', 'selected']),
        song('unrelated-same-name', ['other']),
        song('missing-credits', null),
        song('empty-credits', []),
      ];
    final api = FixtureApi();
    final container = await fixture(downloads, api);
    final tracks = await container.read(
      getPerformingArtistTracksProvider(artist: artist, libraryFilter: library, genreFilter: genre).future,
    );
    expect(tracks.map((track) => track.name), ['solo', 'feature']);
    expect(downloads.calls.single.positionalArguments.single, same(album));
    expect(downloads.calls.single.namedArguments[#playable], true);
    expect(api.calls, isEmpty);
  });

  test('offline favorites retain both the download filter and the artist filter', () async {
    final downloads = FixtureDownloads()
      ..tracks = [
        song('favorite-feature', ['other', 'selected'], favorite: true),
        song('nonfavorite', ['selected']),
        song('unrelated-favorite', ['other'], favorite: true),
      ];
    final container = await fixture(downloads, FixtureApi());
    final tracks = await container.read(
      getPerformingArtistTracksProvider(
        artist: artist,
        libraryFilter: library,
        genreFilter: genre,
        onlyFavorites: true,
      ).future,
    );
    expect(tracks.map((track) => track.name), ['favorite-feature']);
    expect(downloads.calls.single.namedArguments[#onlyFavorites], true);
  });

  test('album artist union keeps album tracks and removes duplicate performing tracks', () async {
    final downloads = FixtureDownloads()
      ..tracks = [
        song('credited', ['selected']),
        song('album-only', ['other']),
      ];
    final container = await fixture(downloads, FixtureApi());
    final tracks = await container.read(
      getArtistTracksProvider(artist: artist, libraryFilter: library, genreFilter: genre).future,
    );
    expect(tracks.map((track) => track.name), ['credited', 'album-only']);
  });

  test('online performing tracks still use the server artist and favorite filters', () async {
    final downloads = FixtureDownloads();
    final api = FixtureApi()
      ..tracks = [
        song('server-result', ['selected']),
      ];
    final container = await fixture(downloads, api, offline: false);
    final tracks = await container.read(
      getPerformingArtistTracksProvider(artist: artist, genreFilter: genre, onlyFavorites: true).future,
    );
    expect(tracks.map((track) => track.name), ['server-result']);
    expect(downloads.calls, isEmpty);
    expect(api.calls.single.namedArguments[#parentItem], same(artist));
    expect(api.calls.single.namedArguments[#artistType], ArtistType.artist);
    expect(api.calls.single.namedArguments[#genreFilter], genre);
    expect(api.calls.single.namedArguments[#isFavorite], true);
  });
}
