import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/hide_item_menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<HideScope>> pumpOptions(WidgetTester tester) async {
    final picked = <HideScope>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HideScopeOptions(onSelect: picked.add)),
        ),
      ),
    );
    return picked;
  }

  testWidgets('offers both scopes with their explanations', (tester) async {
    await pumpOptions(tester);
    expect(find.text('Only on this device'), findsOneWidget);
    expect(find.textContaining('Other devices and users still see it.', findRichText: true), findsOneWidget);
    expect(find.text('Everyone on this server'), findsOneWidget);
    expect(find.textContaining('Adds a "hidden" tag on the server', findRichText: true), findsOneWidget);
  });

  testWidgets('tapping an option picks that scope', (tester) async {
    final picked = await pumpOptions(tester);

    await tester.tap(find.text('Everyone on this server'));
    await tester.tap(find.text('Only on this device'));

    expect(picked, [HideScope.everyone, HideScope.thisDevice]);
  });
}
