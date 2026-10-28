import 'dart:io';

import 'package:finamp/components/LayoutSettingsScreen/track_artist_order_selector.dart';
import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/generate_subtitle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/artist_order_settings.dart';

BaseItemDto testSong() => BaseItemDto(
  id: const BaseItemId('song'),
  type: 'Audio',
  artists: ['B Guest', 'Z Lead', 'A Guest'],
  artistItems: [
    NameIdPair(id: const BaseItemId('a'), name: 'A Guest'),
    NameIdPair(id: const BaseItemId('z'), name: 'Z Lead'),
    NameIdPair(id: const BaseItemId('b'), name: 'B Guest'),
  ],
  albumArtists: [NameIdPair(id: const BaseItemId('z'), name: 'Z Lead')],
);

Future<void> showSettings(WidgetTester tester, {BaseItemDto? item, ValueChanged<BaseItemDto>? onArtistOpened}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(finampSettingsProvider.future);
  final song = item ?? testSong();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          ArtistScreen.routeName: (context) {
            onArtistOpened?.call(ModalRoute.settingsOf(context)!.arguments as BaseItemDto);
            return const Scaffold(body: Text('Artist destination'));
          },
        },
        home: Scaffold(
          body: ListView(
            children: [
              const TrackArtistOrderSelector(),
              ArtistChips(baseItem: song),
              Consumer(
                builder: (context, ref, _) => Text(
                  generateSubtitle(
                        context: context,
                        item: song,
                        trackArtistOrder: ref.watch(finampSettingsProvider.trackArtistOrder),
                      ) ??
                      '',
                  key: const ValueKey('track-subtitle'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String?> chipNames(WidgetTester tester) => tester
    .widgetList<ArtistChip>(find.byType(ArtistChip))
    .map((chip) => chip.artist?.name ?? chip.fallbackName)
    .toList();

Future<void> chooseOrder(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byType(DropdownMenu<TrackArtistOrder>));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownMenu<TrackArtistOrder>));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).hitTestable().last);
  await tester.pumpAndSettle();
}

void main() {
  late Directory directory;
  setUp(() async => directory = await setUpArtistOrderSettings(inMemory: true));
  tearDown(() => tearDownArtistOrderSettings(directory));

  testWidgets('default chips and track subtitle put the album artist before guests', (tester) async {
    await showSettings(tester);
    expect(chipNames(tester), ['Z Lead', 'A Guest', 'B Guest']);
    expect(tester.getTopLeft(find.text('Z Lead')).dx, lessThan(tester.getTopLeft(find.text('A Guest')).dx));
    expect(find.text('Z Lead, A Guest, B Guest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting each mode updates existing chips and subtitle and saves the choice', (tester) async {
    await showSettings(tester);
    for (final (label, order, expected) in [
      ('Metadata order', TrackArtistOrder.metadata, ['B Guest', 'Z Lead', 'A Guest']),
      ('Alphabetical', TrackArtistOrder.alphabetical, ['A Guest', 'B Guest', 'Z Lead']),
      ('First credited artist first', TrackArtistOrder.firstArtistFirst, ['B Guest', 'A Guest', 'Z Lead']),
      ('Album artists first', TrackArtistOrder.albumArtistsFirst, ['Z Lead', 'A Guest', 'B Guest']),
    ]) {
      await chooseOrder(tester, label);
      expect(chipNames(tester), expected);
      expect(find.text(expected.join(', ')), findsOneWidget);
      expect(FinampSettingsHelper.finampSettings.trackArtistOrder, order);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reordered chips still open their correct artist ID', (tester) async {
    BaseItemDto? opened;
    await showSettings(tester, onArtistOpened: (value) => opened = value);
    await tester.tap(find.text('Z Lead'));
    await tester.pumpAndSettle();
    expect(opened?.id, const BaseItemId('z'));
    expect(find.text('Artist destination'), findsOneWidget);
  });

  testWidgets('name-only credits are visible without an incorrect navigation target', (tester) async {
    await showSettings(tester, item: testSong()..artistItems = null);
    expect(chipNames(tester), ['Z Lead', 'A Guest', 'B Guest']);
    final links = tester.widgetList<InkWell>(
      find.descendant(of: find.byType(ArtistChips), matching: find.byType(InkWell)),
    );
    expect(links.every((link) => link.onTap == null), isTrue);
    expect(find.text('Z Lead, A Guest, B Guest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compilation album artists do not become song credits', (tester) async {
    await showSettings(
      tester,
      item: testSong()..albumArtists = [NameIdPair(id: const BaseItemId('various'), name: 'Various Artists')],
    );
    expect(chipNames(tester), ['B Guest', 'Z Lead', 'A Guest']);
    expect(find.text('Various Artists'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings fit a narrow screen with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await showSettings(tester);
    await chooseOrder(tester, 'Metadata order');
    expect(FinampSettingsHelper.finampSettings.trackArtistOrder, TrackArtistOrder.metadata);
    expect(tester.takeException(), isNull);
  });
}
