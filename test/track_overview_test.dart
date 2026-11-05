import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/track_overview_menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

const trackId = BaseItemId('track-with-notes');

class OfflineTrackApi extends Fake implements JellyfinApiHelper {}

class OfflineTrackDownloads extends Fake implements DownloadsService {
  @override
  Future<DownloadStub?> getCollectionInfo({BaseItemDto? item, BaseItemId? id}) async => null;

  @override
  Future<DownloadStub?> getTrackInfo({BaseItemDto? item, BaseItemId? id}) async => DownloadStub.fromItem(
    type: DownloadItemType.track,
    item: BaseItemDto(id: id!, name: 'Example track', type: 'Audio', overview: 'Saved sample credit'),
  );
}

Future<void> openTrackInformation(WidgetTester tester, Future<BaseItemDto?> Function() load) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [itemByIdProvider(trackId).overrideWith((ref) => load())],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: TrackOverviewMenuEntry(itemId: trackId)),
      ),
    ),
  );
  expect(find.byIcon(TablerIcons.info_circle), findsOneWidget);
  await tester.tap(find.text('Track information'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => GetIt.instance.reset());
  testWidgets('opens the server-provided track description separately from lyrics', (tester) async {
    await openTrackInformation(
      tester,
      () async => BaseItemDto(id: trackId, type: 'Audio', overview: 'Beat by A. Sample credit: B.'),
    );
    expect(find.text('Beat by A. Sample credit: B.'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('explains when the track has no information', (tester) async {
    await openTrackInformation(tester, () async => BaseItemDto(id: trackId, type: 'Audio'));
    expect(find.text('No information available.'), findsOneWidget);
  });

  testWidgets('reports a failed metadata request', (tester) async {
    await openTrackInformation(tester, () => Future.error(StateError('unavailable')));
    expect(find.text('Could not load information.'), findsOneWidget);
  });

  testWidgets('reads saved track information while offline', (tester) async {
    GetIt.instance.registerSingleton<JellyfinApiHelper>(OfflineTrackApi());
    GetIt.instance.registerSingleton<DownloadsService>(OfflineTrackDownloads());
    final settings = FinampSettings(
      downloadLocations: [],
      downloadLocationsMap: {},
      tabSortBy: {},
      tabSortOrder: {},
      homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
      gridImageSize: 160,
      homeScreenImageSize: 160,
      deviceId: 'offline-notes-test',
      isOffline: true,
    );
    final container = ProviderContainer(
      overrides: [finampSettingsProvider.overrideWith((ref) => Stream.value(settings))],
    );
    await container.read(finampSettingsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TrackOverviewMenuEntry(itemId: trackId)),
        ),
      ),
    );
    await tester.tap(find.text('Track information'));
    await tester.pumpAndSettle();
    expect(find.text('Saved sample credit'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
}
