import 'dart:async';

import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/HomeScreen/home_section_editor.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/home_screen_settings_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HomeScreenSectionConfiguration configuration(String? title) => HomeScreenSectionConfiguration(
  base: TabsHomeSection(libraryId: allLibraryPlaceholder, contentType: ContentType.playlists),
  sortConfig: SortAndFilterConfiguration.defaultSort,
  customSectionTitle: title,
);

Future<void> openEditor(
  WidgetTester tester, {
  String? title,
  ValueChanged<HomeScreenSectionConfiguration?>? onSaved,
}) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dragController = DraggableScrollableController();
  addTearDown(dragController.dispose);

  final container = ProviderContainer(
    overrides: [
      finampSettingsProvider.overrideWith(
        (ref) => Stream.value(
          FinampSettings(
            downloadLocations: [],
            downloadLocationsMap: {},
            tabSortBy: {},
            tabSortOrder: {},
            homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
            gridImageSize: 160,
            homeScreenImageSize: 160,
            deviceId: 'test-device',
          ),
        ),
      ),
      // Keep the preview loading without connecting to a Jellyfin server.
      for (final previewTitle in [null, 'Playlists', 'My Playlists', 'PlXaylists'])
        resolveSectionProvider(configuration(previewTitle)).overrideWith((ref) => Completer<Never>().future),
    ],
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<HomeScreenSectionConfiguration>(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: HomeScreenSectionConfigurationMenu(
                        initialState: configuration(title),
                        dragController: dragController,
                        childBuilder: (height, slivers) => CustomScrollView(slivers: slivers),
                      ),
                    ),
                  ),
                );
                onSaved?.call(result);
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder get titleField => find.byType(TextField).last;

CTAMedium saveButton(WidgetTester tester) => tester.widget<CTAMedium>(find.byType(CTAMedium));

void main() {
  testWidgets('typing a title immediately enables saving and updates the preview', (tester) async {
    await openEditor(tester);
    expect(saveButton(tester).disabled, isTrue);

    await tester.enterText(titleField, 'Playlists');
    await tester.pump();

    expect(saveButton(tester).disabled, isFalse);
    expect(find.descendant(of: find.byType(SectionPreview), matching: find.text('Playlists')), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(titleField))!;
    expect(find.text(l10n.customSectionTitleRequired), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing an existing title immediately disables saving', (tester) async {
    await openEditor(tester, title: 'Playlists');
    expect(saveButton(tester).disabled, isFalse);

    await tester.enterText(titleField, '');
    await tester.pump();

    expect(saveButton(tester).disabled, isTrue);
    final l10n = AppLocalizations.of(tester.element(titleField))!;
    expect(find.text(l10n.customSectionTitleRequired), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing in the middle retains selection and composing text', (tester) async {
    await openEditor(tester, title: 'Playlists');
    await tester.showKeyboard(titleField);
    const editingValue = TextEditingValue(
      text: 'PlXaylists',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 2, end: 3),
    );
    tester.testTextInput.updateEditingValue(editingValue);
    await tester.pump();

    expect(tester.widget<TextField>(titleField).controller!.value, editingValue);
    expect(saveButton(tester).disabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save returns the entered title and retains the section configuration', (tester) async {
    HomeScreenSectionConfiguration? saved;
    await openEditor(tester, onSaved: (value) => saved = value);
    await tester.enterText(titleField, 'My Playlists');
    await tester.pump();
    await tester.ensureVisible(find.byType(CTAMedium));
    await tester.tap(find.byType(CTAMedium));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(saved?.customSectionTitle, 'My Playlists');
    expect((saved!.base as TabsHomeSection).contentType, ContentType.playlists);
    expect((saved!.base as TabsHomeSection).libraryId, allLibraryPlaceholder);
    expect(saved!.sortConfig, SortAndFilterConfiguration.defaultSort);
    expect(tester.takeException(), isNull);
  });
}
