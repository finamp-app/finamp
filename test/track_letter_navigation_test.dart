import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/MusicScreen/alphabet_item_list.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/music_screen_provider.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:rxdart/rxdart.dart';

final library = BaseItemDto(id: const BaseItemId('library'), type: 'CollectionFolder', name: 'Fixture Music');

class FixtureUser extends Fake implements FinampUserHelper {
  @override
  final currentUser = FinampUser(
    id: 'fixture-user',
    publicAddress: 'http://fixture.invalid',
    localAddress: 'http://fixture.invalid',
    preferLocalNetwork: false,
    isLocal: false,
    accessToken: 'not-a-real-token',
    serverId: 'fixture-server',
    currentViewId: const BaseItemId('library'),
    views: {const BaseItemId('library'): library},
  );
}

class FixtureDownloads extends Fake implements DownloadsService {
  @override
  final stateProvider = StreamProvider.family.autoDispose<DownloadItemState?, DownloadStub>(
    (ref, stub) => Stream.value(DownloadItemState.complete),
  );
  @override
  Stream<void> get offlineDeletesStream => const Stream.empty();
  @override
  final statusProvider = Provider.family.autoDispose<DownloadItemStatus, (DownloadStub, int?)>(
    (ref, args) => DownloadItemStatus.notNeeded,
  );
}

class FixtureQueue extends Fake implements QueueService {}

class FixtureAudio extends Fake implements MusicPlayerBackgroundTask {
  @override
  final mediaItem = BehaviorSubject<MediaItem?>.seeded(null);
  @override
  final playbackState = BehaviorSubject<PlaybackState>.seeded(PlaybackState());
  @override
  final fadeState = BehaviorSubject<FadeState>.seeded(FadeState(fadeVolume: 1.0));
}

class LoadedRows extends PagedContent {
  LoadedRows(this.rows, {this.nextRows});
  final List<FinampDisplayableOrPlayable>? nextRows;
  int pageRequests = 0;
  final List<FinampDisplayableOrPlayable> rows;
  @override
  PagingState<int, FinampDisplayableOrPlayable> build(FinampDisplayable<FinampDisplayableOrPlayable> request) =>
      PagingState(pages: [rows], keys: [0], isLoading: false, hasNextPage: nextRows != null);
  @override
  void newPage({int pageSize = musicScreenPageSize}) {
    if (nextRows == null || pageRequests++ > 0) throw StateError('Unexpected page request');
    state = PagingState(pages: [rows, nextRows!], keys: [0, rows.length], isLoading: false, hasNextPage: false);
  }
}

List<Track> tracks({String target = 'Midnight', bool albumArtists = false, int targetIndex = 40}) => [
  for (var index = 0; index < targetIndex + 80; index++)
    Track.fromItem(
      BaseItemDto(
        id: BaseItemId('track-$index'),
        type: 'Audio',
        name: albumArtists
            ? 'Song $index'
            : index < 5
            ? '01 Numbers $index'
            : index < targetIndex
            ? 'Aurora $index'
            : index < targetIndex + 40
            ? '$target $index'
            : 'Zebra $index',
        // Audio sorting uses the title, even when SortName contains a track number.
        sortName: index.toString().padLeft(3, '0'),
        albumArtists: [
          NameIdPair(
            id: const BaseItemId('credit'),
            name: index < targetIndex
                ? 'Aurora'
                : index < targetIndex + 40
                ? target
                : 'Zebra',
          ),
        ],
        artists: ['Fixture Artist'],
        userData: UserItemDataDto(playbackPositionTicks: 0, playCount: 0, isFavorite: false, played: false),
        runTimeTicks: 40_000_000,
      ),
    ),
];

Future<AlphabetList> mount(
  WidgetTester tester,
  List<Track> rows, {
  bool offline = false,
  bool descending = false,
  bool albumArtists = false,
  LoadedRows? pager,
}) async {
  tester.view.physicalSize = const Size(390, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final audio = FixtureAudio();
  GetIt.instance.registerSingleton<MusicPlayerBackgroundTask>(audio);
  GetIt.instance.registerSingleton<DownloadsService>(FixtureDownloads());
  GetIt.instance.registerSingleton<FinampUserHelper>(FixtureUser());
  addTearDown(() async {
    await audio.mediaItem.close();
    await audio.playbackState.close();
    await audio.fadeState.close();
    await GetIt.instance.reset();
  });
  final settings = FinampSettings(
    downloadLocations: [],
    downloadLocationsMap: {},
    tabSortBy: {},
    tabSortOrder: {},
    homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
    gridImageSize: 160,
    homeScreenImageSize: 160,
    deviceId: 'letter-jump-test',
    isOffline: offline,
  );
  final root = ProviderContainer(
    overrides: [
      finampSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      currentTrackProvider.overrideWith((ref) => Stream.value(null)),
      QueueService.queueProvider.overrideWithValue(null),
    ],
  );
  addTearDown(root.dispose);
  await root.read(finampSettingsProvider.future);
  GetIt.instance.registerSingleton<ProviderContainer>(root);
  final sort = ResolvedSortConfig.skipResolving(
    SortAndFilterConfiguration(
      sortBy: albumArtists ? SortBy.albumArtist : SortBy.sortName,
      sortOrder: descending ? SortOrder.descending : SortOrder.ascending,
      filters: {},
    ),
  );
  final request = MusicScreenPlayable<Track>(
    tab: ContentType.tracks,
    library: allLibraryPlaceholder,
    source: QueueItemSource.fromBaseItem(library),
    sortConfig: sort,
  );
  final scope = ProviderContainer(
    parent: root,
    overrides: [pagedContentProvider(request).overrideWith(() => pager ?? LoadedRows(rows))],
  );
  addTearDown(scope.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MusicScreenTabView(displayable: request)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return tester.widget<AlphabetList>(find.byType(AlphabetList));
}

Future<void> expectJump(WidgetTester tester, AlphabetList alphabet, String letter, Track target) async {
  final before = alphabet.scrollController.offset;
  alphabet.callback(letter);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(alphabet.scrollController.offset, greaterThan(before + 500));
  final tile = find.byWidgetPredicate((widget) => widget is TrackListTile && widget.item.id == target.item.id);
  expect(tile, findsOneWidget);
  final rect = tester.getRect(tile);
  expect(rect.top, inInclusiveRange(-1, 80));
  expect(rect.bottom, lessThan(500));
}

void main() {
  testWidgets('Tracks M jump reaches the first M title beyond the numeric and A rows', (tester) async {
    final rows = tracks();
    final alphabet = await mount(tester, rows);
    alphabet.callback('');
    await tester.pumpAndSettle();
    expect(alphabet.scrollController.offset, 0);
    await expectJump(tester, alphabet, 'M', rows[40]);
    alphabet.callback('#');
    await tester.pumpAndSettle();
    expect(alphabet.scrollController.offset, closeTo(0, 1));
    alphabet.callback('L');
    await tester.pumpAndSettle();
    final fallback = find.byWidgetPredicate((widget) => widget is TrackListTile && widget.item.id == rows[39].item.id);
    expect(fallback, findsOneWidget);
    expect(tester.getRect(fallback).center.dy, inInclusiveRange(150, 350));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('mixed-case and accented titles use the selected ASCII letter', (tester) async {
    final rows = tracks(target: 'Écho');
    final alphabet = await mount(tester, rows);
    await expectJump(tester, alphabet, 'E', rows[40]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('offline Tracks use the same letter comparison', (tester) async {
    final rows = tracks(target: 'mIDNIGHT');
    final alphabet = await mount(tester, rows, offline: true);
    await expectJump(tester, alphabet, 'M', rows[40]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('descending Tracks reach the first matching M in descending data', (tester) async {
    final rows = tracks().reversed.toList();
    final alphabet = await mount(tester, rows, descending: true);
    await expectJump(tester, alphabet, 'M', rows[40]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('Tracks sorted by album artist jump using album credits', (tester) async {
    final rows = tracks(albumArtists: true);
    final alphabet = await mount(tester, rows, albumArtists: true);
    await expectJump(tester, alphabet, 'M', rows[40]);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('an unloaded target resumes the jump after the next page arrives', (tester) async {
    final rows = tracks(targetIndex: 140);
    final pager = LoadedRows(rows.take(120).toList(), nextRows: rows.skip(120).toList());
    final alphabet = await mount(tester, rows, pager: pager);
    expect(pager.pageRequests, 0);
    await expectJump(tester, alphabet, 'M', rows[140]);
    expect(pager.pageRequests, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
