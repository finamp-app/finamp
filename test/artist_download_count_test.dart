import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:finamp/components/AlbumScreen/download_button.dart';
import 'package:finamp/components/AlbumScreen/download_dialog.dart';
import 'package:finamp/components/ArtistScreen/artist_screen_content.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';

import 'artist_screen_loading_test.dart' show settings;

final artist = BaseItemDto(
  id: const BaseItemId('artist'),
  name: 'Test artist',
  type: 'MusicArtist',
  userData: UserItemDataDto(playbackPositionTicks: 0, playCount: 0, isFavorite: false, played: false),
);

final library = BaseItemDto(id: const BaseItemId('library'), type: 'CollectionFolder', name: 'Music');
final ownAlbum = BaseItemDto(id: const BaseItemId('own-album'), name: 'Own album', type: 'MusicAlbum', childCount: 3);

class CountApi extends Fake implements JellyfinApiHelper {
  late Completer<QueryResult_BaseItemDto> count;
  final calls = <Invocation>[];
  List<BaseItemDto> albums = [ownAlbum];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #getItemsWithTotalRecordCount) return count.future;
    if (invocation.memberName == #getItems && invocation.namedArguments[#includeItemTypes] == 'MusicAlbum') {
      return Future<List<BaseItemDto>?>.value(albums);
    }
    return super.noSuchMethod(invocation);
  }
}

class DownloadStatusFixture extends Fake implements DownloadsService {
  final childCounts = <int?>[];
  DownloadItemStatus status = DownloadItemStatus.notNeeded;

  @override
  Stream<void> get offlineDeletesStream => const Stream.empty();

  @override
  late final statusProvider = Provider.family.autoDispose<DownloadItemStatus, (DownloadStub, int?)>((ref, args) {
    childCounts.add(args.$2);
    return status;
  });

  @override
  final stateProvider = StreamProvider.family.autoDispose<DownloadItemState?, DownloadStub>(
    (ref, stub) => Stream.value(null),
  );
}

class UserFixture extends Fake implements FinampUserHelper {
  @override
  final currentUser = FinampUser(
    id: 'fixture',
    publicAddress: 'http://fixture.invalid',
    localAddress: 'http://fixture.invalid',
    preferLocalNetwork: false,
    isLocal: false,
    accessToken: 'fixture',
    serverId: 'fixture',
    currentViewId: library.id,
    views: {library.id: library},
  );
}

class QueueFixture extends Fake implements QueueService {}

void main() {
  late Directory directory;
  late CountApi api;
  late DownloadStatusFixture downloads;
  late ProviderContainer scope;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('finamp-artist-count-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(28)) {
      Hive.registerAdapters();
      Hive.registerAdapter(ThemeModeAdapter());
      Hive.registerAdapter(ColorAdapter());
      Hive.registerAdapter(LocaleAdapter());
    }
    final box = await Hive.openBox<FinampSettings>('FinampSettings', bytes: Uint8List(0));
    final config = settings(showTracks: false)
      ..artistItemSectionsOrder = []
      ..downloadSizeWarningCutoff = 4;
    config.downloadLocationsMap['fixture'] = DownloadLocation(
      name: 'Fixture storage',
      relativePath: null,
      id: 'fixture',
      baseDirectory: DownloadLocationType.internalSupport,
    );
    config.defaultDownloadLocation = 'fixture';
    await box.put('FinampSettings', config);
    api = CountApi();
    downloads = DownloadStatusFixture();
    GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
    GetIt.instance.registerSingleton<DownloadsService>(downloads);
    GetIt.instance.registerSingleton<FinampUserHelper>(UserFixture());
    GetIt.instance.registerSingleton<QueueService>(QueueFixture());
  });

  tearDown(() async {
    scope.dispose();
    await GetIt.instance.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    api.count = Completer<QueryResult_BaseItemDto>();
    scope = ProviderContainer(overrides: [QueueService.queueProvider.overrideWithValue(null)]);
    await scope.read(finampSettingsProvider.future);
    GetIt.instance.registerSingleton<ProviderContainer>(scope);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          // ignore: deprecated_member_use
          scaffoldMessengerKey: GlobalSnackbar.rawMaterialAppScaffoldKey,
          // ignore: deprecated_member_use
          navigatorKey: GlobalSnackbar.rawMaterialAppNavigatorKey,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArtistScreenContent(parent: artist, library: library),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pending count keeps the metadata row and page, then updates without moving the album row', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Loading…', findRichText: true), findsOneWidget);
    expect(find.byType(DownloadButton), findsOneWidget);
    expect(downloads.childCounts.last, isNull);
    expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).downloadDisabled, isFalse);
    final albumRow = find.text('1 Album', findRichText: true);
    final position = tester.getTopLeft(albumRow);
    api.count.complete(QueryResult_BaseItemDto(items: [], totalRecordCount: 4, startIndex: 0));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('4 Tracks', findRichText: true), findsOneWidget);
    expect(tester.getTopLeft(albumRow), position);
    // Three own-album tracks and one guest track: the direct links include
    // the album AND all four tracks. The warning counts four unique tracks.
    expect(downloads.childCounts.last, 5);
    final button = tester.widget<DownloadButton>(find.byType(DownloadButton));
    expect(await button.getDownloadSizeTrackCount!(), 4);
    expect(button.downloadDisabled, isFalse);
    await tester.tap(find.byIcon(TablerIcons.download));
    await tester.pumpAndSettle();
    expect(tester.widget<DownloadDialog>(find.byType(DownloadDialog)).trackCount, 4);
    expect(api.calls.where((call) => call.memberName == #getItems), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed count keeps the metadata row and does not invent a child count', (tester) async {
    await mount(tester);
    final position = tester.getTopLeft(find.text('1 Album', findRichText: true));
    api.count.completeError(const FormatException('Missing count'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Error loading items.', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(tester.getTopLeft(find.text('1 Album', findRichText: true)), position);
    expect(downloads.childCounts.last, isNull);
    expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).downloadDisabled, isFalse);
    expect(find.text('0 Tracks', findRichText: true), findsNothing);
    await tester.tap(find.byIcon(TablerIcons.download));
    await tester.pumpAndSettle();
    expect(find.byType(DownloadDialog), findsNothing);
    expect(api.calls.where((call) => call.memberName == #getItems), hasLength(2));
    api.count = Completer<QueryResult_BaseItemDto>();
    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    api.count.complete(QueryResult_BaseItemDto(items: [], totalRecordCount: 4, startIndex: 0));
    await tester.pumpAndSettle();
    expect(find.text('4 Tracks', findRichText: true), findsOneWidget);
    expect(downloads.childCounts.last, 5);
    expect(api.calls.where((call) => call.memberName == #getItemsWithTotalRecordCount), hasLength(2));
  });

  testWidgets('a download clicked while counting waits for the same bounded result', (tester) async {
    await mount(tester);
    await tester.tap(find.byIcon(TablerIcons.download));
    await tester.pumpAndSettle();
    expect(find.byType(DownloadDialog), findsNothing);
    api.count.complete(QueryResult_BaseItemDto(items: [], totalRecordCount: 4, startIndex: 0));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.widget<DownloadDialog>(find.byType(DownloadDialog)).trackCount, 4);
    expect(api.calls.where((call) => call.memberName == #getItemsWithTotalRecordCount), hasLength(1));
    expect(api.calls.where((call) => call.memberName == #getItems), hasLength(2));
  });

  testWidgets('an unknown count leaves removal controls available for existing downloads', (tester) async {
    downloads.status = DownloadItemStatus.required;
    await mount(tester);
    expect(find.byIcon(TablerIcons.trash), findsOneWidget);
    expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).downloadDisabled, isFalse);
    expect(downloads.childCounts.last, isNull);
  });

  testWidgets('an artist with only guest appearances still supplies track links and the warning count', (tester) async {
    api.albums = [];
    await mount(tester);
    api.count.complete(QueryResult_BaseItemDto(items: [], totalRecordCount: 4, startIndex: 0));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(downloads.childCounts.last, 4);
    await tester.tap(find.byIcon(TablerIcons.download));
    await tester.pumpAndSettle();
    expect(tester.widget<DownloadDialog>(find.byType(DownloadDialog)).trackCount, 4);
    expect(api.calls.where((call) => call.memberName == #getItems), hasLength(2));
  });

  testWidgets('album downloads retain the existing child-list warning fallback', (tester) async {
    await mount(tester);
    FinampSettingsHelper.finampSettings.shouldTranscodeDownloads = TranscodeDownloadsSetting.never;
    final tracks = List.generate(4, (i) => BaseItemDto(id: BaseItemId('track-$i'), type: 'Audio'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DownloadButton(
              item: DownloadStub.fromItem(type: DownloadItemType.collection, item: ownAlbum),
              children: tracks,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerIcons.download));
    await tester.pumpAndSettle();
    expect(tester.widget<DownloadDialog>(find.byType(DownloadDialog)).trackCount, 4);
  });
}
