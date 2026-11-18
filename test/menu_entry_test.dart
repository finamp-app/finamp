import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEntry(WidgetTester tester, {required bool enabled, required VoidCallback onTap}) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MenuEntry(
              title: 'Unhide',
              icon: Icons.visibility,
              enabled: enabled,
              tooltip: 'Its album is hidden',
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping a disabled entry explains why instead of running it', (tester) async {
    var taps = 0;
    await pumpEntry(tester, enabled: false, onTap: () => taps++);

    await tester.tap(find.text('Unhide'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Its album is hidden'), findsOneWidget);
    expect(taps, 0);
  });

  testWidgets('tapping an enabled entry runs it', (tester) async {
    var taps = 0;
    await pumpEntry(tester, enabled: true, onTap: () => taps++);

    await tester.tap(find.text('Unhide'));
    await tester.pump();

    expect(taps, 1);
  });
}
