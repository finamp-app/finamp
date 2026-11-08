import 'package:finamp/components/HomeScreen/home_screen_content.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _section = HomeScreenSectionConfiguration(
  base: TabsHomeSection(libraryId: allLibraryPlaceholder, contentType: ContentType.playlists),
  sortConfig: SortAndFilterConfiguration.defaultSort,
);

final _staleOfflineSection = UnavailableHomeSectionPlayable(
  source: const QueueItemSource.rawId(
    type: QueueItemSourceType.homeScreenSection,
    name: QueueItemSourceName(type: QueueItemSourceNameType.homeScreenSection),
    id: 'test-home-section',
  ),
  section: _section,
);

void main() {
  testWidgets('keeps loading while a stale offline home section is replaced online', (tester) async {
    final settings = FinampSettings(
      downloadLocations: [],
      downloadLocationsMap: {},
      tabSortBy: {},
      tabSortOrder: {},
      homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
      gridImageSize: 160,
      homeScreenImageSize: 160,
      deviceId: 'home-section-transition-test',
      isOffline: false,
    );
    final container = ProviderContainer(
      overrides: [
        finampSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        resolveSectionProvider(_section).overrideWith((ref) async => _staleOfflineSection),
      ],
    );
    addTearDown(container.dispose);
    await container.read(finampSettingsProvider.future);
    await container.read(resolveSectionProvider(_section).future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HomeScreenSectionContent(sectionInfo: _section)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Not available in offline mode'), findsNothing);
  });
}
