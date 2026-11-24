import 'package:finamp/components/AlbumScreen/hidden_indicator.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';

BaseItemDto track(String id, {String? albumId}) =>
    BaseItemDto(id: BaseItemId(id), name: id, type: 'Audio', albumId: albumId == null ? null : BaseItemId(albumId));

final _testHiddenIds = StateProvider<Set<BaseItemId>>((ref) => {});

void main() {
  Future<ProviderContainer> pumpWidget(WidgetTester tester, Widget widget, {Set<String> hidden = const {}}) async {
    final container = ProviderContainer(
      overrides: [hiddenIdsProvider.overrideWith((ref) => ref.watch(_testHiddenIds))],
    );
    addTearDown(container.dispose);
    container.read(_testHiddenIds.notifier).state = hidden.map(BaseItemId.new).toSet();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: widget),
        ),
      ),
    );
    return container;
  }

  Future<ProviderContainer> pumpIndicator(WidgetTester tester, BaseItemDto item, {Set<String> hidden = const {}}) =>
      pumpWidget(tester, HiddenIndicator(item: item), hidden: hidden);

  Future<ProviderContainer> pumpOverlay(WidgetTester tester, BaseItemDto item, {Set<String> hidden = const {}}) =>
      pumpWidget(
        tester,
        SizedBox.square(
          dimension: 120,
          child: HiddenArtOverlay(
            item: item,
            child: const ColoredBox(key: Key('art'), color: Colors.blue),
          ),
        ),
        hidden: hidden,
      );

  final eyeOff = find.byIcon(TablerIcons.eye_off);

  testWidgets('shows the crossed-out eye on a hidden track', (tester) async {
    await pumpIndicator(tester, track('t1'), hidden: {'t1'});
    expect(eyeOff, findsOneWidget);
  });

  testWidgets('shows nothing on a track that is not hidden', (tester) async {
    await pumpIndicator(tester, track('t1'), hidden: {'t2'});
    expect(eyeOff, findsNothing);
  });

  testWidgets('shows on a track whose album is hidden', (tester) async {
    await pumpIndicator(tester, track('t1', albumId: 'a1'), hidden: {'a1'});
    expect(eyeOff, findsOneWidget);
  });

  testWidgets('labels the icon for screen readers', (tester) async {
    await pumpIndicator(tester, track('t1'), hidden: {'t1'});
    expect(find.bySemanticsLabel('Hidden'), findsOneWidget);
  });

  testWidgets('follows hides and unhides', (tester) async {
    final container = await pumpIndicator(tester, track('t1'));
    expect(eyeOff, findsNothing);

    container.read(_testHiddenIds.notifier).state = {BaseItemId('t1')};
    await tester.pump();
    expect(eyeOff, findsOneWidget);

    container.read(_testHiddenIds.notifier).state = {};
    await tester.pump();
    expect(eyeOff, findsNothing);
  });

  group('HiddenArtOverlay', () {
    final album = BaseItemDto(id: BaseItemId('a1'), name: 'a1', type: 'MusicAlbum');

    testWidgets('puts the crossed-out eye over hidden art and keeps the art', (tester) async {
      await pumpOverlay(tester, album, hidden: {'a1'});
      expect(eyeOff, findsOneWidget);
      expect(find.byKey(const Key('art')), findsOneWidget);
      expect(find.bySemanticsLabel('Hidden'), findsOneWidget);
    });

    testWidgets('leaves art that is not hidden untouched', (tester) async {
      await pumpOverlay(tester, album);
      expect(eyeOff, findsNothing);
      expect(find.byKey(const Key('art')), findsOneWidget);
    });

    testWidgets('scales the icon with the art', (tester) async {
      await pumpOverlay(tester, album, hidden: {'a1'});
      expect(tester.widget<Icon>(eyeOff).size, closeTo(120 * 0.35, 0.01));
    });

    testWidgets('follows hides and unhides', (tester) async {
      final container = await pumpOverlay(tester, album);
      container.read(_testHiddenIds.notifier).state = {BaseItemId('a1')};
      await tester.pump();
      expect(eyeOff, findsOneWidget);

      container.read(_testHiddenIds.notifier).state = {};
      await tester.pump();
      expect(eyeOff, findsNothing);
    });
  });
}
