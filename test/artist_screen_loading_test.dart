import 'dart:convert';

import 'package:finamp/components/ArtistScreen/artist_item_info.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/artist_content_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class ArtistRequest {
  ArtistRequest(this.artistType, this.limit, this.items, this.bytes);
  final ArtistType? artistType;
  final int? limit;
  final int items;
  final int bytes;
}

class RecordingArtistApi extends Fake implements JellyfinApiHelper {
  final requests = <ArtistRequest>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getItems) {
      final limit = invocation.namedArguments[#limit] as int?;
      final items = List.generate(
        limit ?? 10000,
        (index) => BaseItemDto(
          id: BaseItemId('track-$index'),
          type: 'Audio',
          name: 'Track $index',
          premiereDate: '2026-01-01T00:00:00Z',
          productionYear: 2026,
          artists: ['Test artist'],
          artistItems: [NameIdPair(id: const BaseItemId('artist'), name: 'Test artist')],
        ),
      );
      requests.add(
        ArtistRequest(
          invocation.namedArguments[#artistType] as ArtistType?,
          limit,
          items.length,
          utf8.encode(jsonEncode(items.map((item) => item.toJson()).toList())).length,
        ),
      );
      return Future<List<BaseItemDto>?>.value(items);
    }
    return super.noSuchMethod(invocation);
  }
}

class UnusedDownloads extends Fake implements DownloadsService {}

FinampSettings settings({
  bool offline = false,
  bool showTracks = true,
  CuratedItemSelectionType selection = CuratedItemSelectionType.latestReleases,
}) => FinampSettings(
  downloadLocations: [],
  downloadLocationsMap: {},
  tabSortBy: {},
  tabSortOrder: {},
  homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
  gridImageSize: 160,
  homeScreenImageSize: 160,
  deviceId: 'artist-loading-fixture',
  autoSwitchItemCurationType: false,
  artistCuratedItemSelectionType: selection,
  isOffline: offline,
  showArtistsTracksSection: showTracks,
);

final artist = BaseItemDto(id: const BaseItemId('artist'), name: 'Test artist', type: 'MusicArtist');

BaseItemDto track(int index) => BaseItemDto(
  id: BaseItemId('track-$index'),
  name: 'Track $index',
  type: 'Audio',
  premiereDate: '2026-01-${(index + 1).toString().padLeft(2, '0')}T00:00:00Z',
  dateCreated: '2026-01-${(index + 1).toString().padLeft(2, '0')}T00:00:00Z',
  userData: UserItemDataDto(
    playbackPositionTicks: 0,
    playCount: index + 1,
    isFavorite: true,
    played: true,
    lastPlayedDate: '2026-01-${(index + 1).toString().padLeft(2, '0')}T00:00:00Z',
  ),
);

class FixtureArtistApi extends Fake implements JellyfinApiHelper {
  final calls = <Invocation>[];
  int total = 10;
  bool countFails = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #getItemsWithTotalRecordCount) {
      if (countFails) return Future<QueryResult_BaseItemDto>.error(const FormatException('Invalid count response'));
      // Count metadata is deliberately independent of the returned item page.
      return Future.value(QueryResult_BaseItemDto(items: [], totalRecordCount: total, startIndex: 0));
    }
    if (invocation.memberName == #getItems) {
      final albumArtist = invocation.namedArguments[#artistType] == ArtistType.albumArtist;
      final items = [
        for (var i = 9; i >= 0; i--)
          if (!albumArtist || i.isOdd) track(i),
      ];
      final limit = invocation.namedArguments[#limit] as int?;
      return Future<List<BaseItemDto>?>.value(limit == null ? items : items.take(limit).toList());
    }
    return super.noSuchMethod(invocation);
  }
}

Future<ProviderContainer> fixtureContainer(FixtureArtistApi api, {FinampSettings? config}) async {
  GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
  GetIt.instance.registerSingleton<DownloadsService>(UnusedDownloads());
  final container = ProviderContainer(
    overrides: [finampSettingsProvider.overrideWith((ref) => Stream.value(config ?? settings()))],
  );
  addTearDown(container.dispose);
  await container.read(finampSettingsProvider.future);
  return container;
}

void main() {
  tearDown(() => GetIt.instance.reset());
  test('the artist top-five section never requests an entire discography', () async {
    final api = RecordingArtistApi();
    GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
    GetIt.instance.registerSingleton<DownloadsService>(UnusedDownloads());
    final container = ProviderContainer(
      overrides: [finampSettingsProvider.overrideWith((ref) => Stream.value(settings()))],
    );
    addTearDown(container.dispose);
    await container.read(finampSettingsProvider.future);
    final (tracks, _, _) = await container.read(
      getArtistTracksSectionProvider(
        artist: BaseItemDto(id: const BaseItemId('artist'), name: 'Test artist', type: 'MusicArtist'),
      ).future,
    );
    // This drives the real screen provider chain; only the HTTP boundary is fake.
    debugPrint(
      'Artist preview requests: ${api.requests.map((r) => '${r.artistType}: limit=${r.limit}, items=${r.items}').join('; ')}',
    );
    debugPrint('Synthetic serialized response bytes: ${api.requests.fold<int>(0, (sum, r) => sum + r.bytes)}');
    expect(tracks, hasLength(5));
    expect(api.requests, hasLength(2));
    expect(
      api.requests.every((request) => request.limit == 5),
      isTrue,
      reason: 'Rendering five tracks must not download the complete performing-artist discography',
    );
  });

  for (final selection in CuratedItemSelectionType.values) {
    test('bounded preview preserves ${selection.name} sorting and filters', () async {
      final api = FixtureArtistApi();
      final container = await fixtureContainer(api, config: settings(selection: selection));
      final (tracks, actualSelection, _) = await container.read(
        getArtistTracksSectionProvider(
          artist: artist,
          libraryFilter: BaseItemDto(id: const BaseItemId('library'), type: 'CollectionFolder'),
          genreFilter: const BaseItemId('genre'),
        ).future,
      );
      expect(actualSelection, selection);
      expect(tracks, hasLength(5));
      expect(tracks.map((item) => item.id).toSet(), hasLength(5));
      if (selection != CuratedItemSelectionType.random && selection != CuratedItemSelectionType.favorites) {
        expect(tracks.map((item) => item.id.raw), ['track-9', 'track-8', 'track-7', 'track-6', 'track-5']);
      }
      expect(api.calls, hasLength(2));
      for (final call in api.calls) {
        expect(call.namedArguments[#limit], 5);
        expect(call.namedArguments[#sortBy], selection.getSortBy().jellyfinName(ContentType.tracks));
        expect(call.namedArguments[#sortOrder], SortOrder.descending.name);
        expect(call.namedArguments[#libraryFilter], const BaseItemId('library'));
        expect(call.namedArguments[#genreFilter], const BaseItemId('genre'));
        expect(call.namedArguments[#isFavorite], selection == CuratedItemSelectionType.favorites ? true : null);
      }
    });
  }

  test('header and download counts use bounded metadata even with the preview disabled', () async {
    final api = FixtureArtistApi();
    final container = await fixtureContainer(api, config: settings(showTracks: false));
    final (tracks, _, _) = await container.read(getArtistTracksSectionProvider(artist: artist).future);
    expect(tracks, isEmpty);
    final counts = await container.read(
      getArtistTrackCountProvider(
        artist: artist,
        libraryFilter: const LibraryId('library'),
        genreFilter: const BaseItemId('genre'),
      ).future,
    );
    expect(counts, 10);
    expect(api.calls, hasLength(1));
    final call = api.calls.single;
    expect(call.memberName, #getItemsWithTotalRecordCount);
    expect(call.namedArguments[#limit], 1);
    expect(call.namedArguments[#fields], '');
    expect(call.namedArguments[#artistType], ArtistType.artist);
    expect(call.namedArguments[#includeItemTypes], 'Audio');
    expect(call.namedArguments[#libraryFilter], const BaseItemId('library'));
    expect(call.namedArguments[#genreFilter], const BaseItemId('genre'));
  });

  for (final total in [0, -1]) {
    test('count metadata handles $total without inventing a loaded zero', () async {
      final api = FixtureArtistApi()..total = total;
      final container = await fixtureContainer(api);
      final result = container.read(getArtistTrackCountProvider(artist: artist).future);
      if (total == 0) {
        expect(await result, 0);
      } else {
        await expectLater(result, throwsFormatException);
      }
    });
  }

  test('metadata errors do not trigger a full-discography fallback', () async {
    final api = FixtureArtistApi()..countFails = true;
    final container = await fixtureContainer(api);
    await expectLater(container.read(getArtistTrackCountProvider(artist: artist).future), throwsFormatException);
    expect(api.calls.map((call) => call.memberName), [#getItemsWithTotalRecordCount]);
  });

  test('playback still enumerates and deduplicates the complete discography on demand', () async {
    final api = FixtureArtistApi();
    final container = await fixtureContainer(api);
    await container.read(getArtistTrackCountProvider(artist: artist).future);
    expect(api.calls.where((call) => call.memberName == #getItems), isEmpty);
    final tracks = await container.read(getArtistTracksProvider(artist: artist, onlyFavorites: true).future);
    expect(tracks.map((item) => item.id).toSet(), hasLength(10));
    expect(tracks, hasLength(10));
    for (final call in api.calls.where((call) => call.memberName == #getItems)) {
      expect(call.namedArguments[#limit], isNull);
      expect(call.namedArguments[#isFavorite], true);
    }
  });

  test('offline counts reuse local providers without making a metadata request', () async {
    final api = FixtureArtistApi();
    GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
    final container = ProviderContainer(
      overrides: [
        finampSettingsProvider.overrideWith((ref) => Stream.value(settings(offline: true))),
        getArtistTracksProvider(artist: artist).overrideWith((ref) async => [track(0), track(1), track(2)]),
        getPerformingArtistTracksProvider(artist: artist).overrideWith((ref) async {
          throw StateError('The union is already available from the local artist tracks');
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(finampSettingsProvider.future);
    expect(await container.read(getArtistTrackCountProvider(artist: artist).future), 3);
    expect(api.calls, isEmpty);
  });

  for (final count in <int?>[null, 0, 7169]) {
    testWidgets('artist info renders count $count truthfully while keeping the album count', (tester) async {
      final container = ProviderContainer(
        overrides: [finampSettingsProvider.overrideWith((ref) => Stream.value(settings()))],
      );
      addTearDown(container.dispose);
      await container.read(finampSettingsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArtistItemInfo(
                item: artist,
                itemTracks: count == null ? const AsyncLoading<int>() : AsyncData(count),
                itemAlbums: 498,
                sortConfig: SortAndFilterConfiguration.defaultSort,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      if (count == null) expect(find.text('Loading…', findRichText: true), findsOneWidget);
      expect(find.text('498 Albums', findRichText: true), findsOneWidget);
      if (count != null) expect(find.text('$count Tracks', findRichText: true), findsOneWidget);
    });
  }

  testWidgets('artist info displays a count error without hiding the album count', (tester) async {
    final container = ProviderContainer(
      overrides: [finampSettingsProvider.overrideWith((ref) => Stream.value(settings()))],
    );
    addTearDown(container.dispose);
    await container.read(finampSettingsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArtistItemInfo(
              item: artist,
              itemTracks: AsyncError<int>(StateError('count failed'), StackTrace.current),
              itemAlbums: 498,
              sortConfig: SortAndFilterConfiguration.defaultSort,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final localization = AppLocalizations.of(tester.element(find.byType(ArtistItemInfo)))!;
    expect(find.text(localization.errorLoadingItems, findRichText: true), findsOneWidget);
    expect(find.text('498 Albums', findRichText: true), findsOneWidget);
  });
}
