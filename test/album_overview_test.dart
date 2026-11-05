import 'package:finamp/components/AlbumScreen/album_overview.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

const albumId = BaseItemId('album-with-notes');

class AlbumApi extends Fake implements JellyfinApiHelper {
  int calls = 0;

  @override
  Future<BaseItemDto> getItemById(BaseItemId id) async {
    calls++;
    return BaseItemDto(id: id, name: 'Example album', type: 'MusicAlbum', overview: 'Server notes');
  }
}

class AlbumDownloads extends Fake implements DownloadsService {
  @override
  Future<DownloadStub?> getCollectionInfo({BaseItemDto? item, BaseItemId? id}) async => DownloadStub.fromItem(
    type: DownloadItemType.collection,
    item: BaseItemDto(id: id!, name: 'Example album', type: 'MusicAlbum', overview: 'Offline notes'),
  );
}

FinampSettings settings(bool offline) => FinampSettings(
  downloadLocations: [],
  downloadLocationsMap: {},
  tabSortBy: {},
  tabSortOrder: {},
  homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
  gridImageSize: 160,
  homeScreenImageSize: 160,
  deviceId: 'album-notes-test',
  isOffline: offline,
);

Future<void> showAlbum(WidgetTester tester, String? overview) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itemByIdProvider(albumId).overrideWith(
          (ref) async => BaseItemDto(id: albumId, name: 'Example album', type: 'MusicAlbum', overview: overview),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AlbumOverview(albumId: albumId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets('opens a readable album description supplied by the server', (tester) async {
    await showAlbum(tester, 'A sample credit.\nA second paragraph.');

    await tester.tap(find.text('Album information'));
    await tester.pumpAndSettle();

    expect(find.text('A sample credit.\nA second paragraph.'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('does not show an empty album information action', (tester) async {
    await showAlbum(tester, '  \n  ');
    expect(find.text('Album information'), findsNothing);
  });

  testWidgets('long album information remains scrollable on a small screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final description = List.generate(80, (index) => 'Note ${index + 1}').join('\n');
    await showAlbum(tester, description);
    await tester.tap(find.text('Album information'));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Scrollable)).first;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed request does not break the album screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [itemByIdProvider(albumId).overrideWith((ref) => Future.error(StateError('offline')))],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AlbumOverview(albumId: albumId)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Album information'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final offline in [false, true]) {
    testWidgets('uses ${offline ? 'downloaded' : 'server'} album details in the corresponding mode', (tester) async {
      final api = AlbumApi();
      GetIt.instance.registerSingleton<JellyfinApiHelper>(api);
      GetIt.instance.registerSingleton<DownloadsService>(AlbumDownloads());
      final container = ProviderContainer(
        overrides: [finampSettingsProvider.overrideWith((ref) => Stream.value(settings(offline)))],
      );
      await container.read(finampSettingsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AlbumOverview(albumId: albumId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Album information'));
      await tester.pumpAndSettle();

      expect(find.text(offline ? 'Offline notes' : 'Server notes'), findsOneWidget);
      expect(api.calls, offline ? 0 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });
  }
}
