import 'package:finamp/components/PlayerScreen/player_split_screen_scaffold.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/screens/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('queueSplitScreenPop', () {
    tearDown(() {
      setUsingPlayerSplitScreenForTesting(false);
    });

    testWidgets('pops player route after one-frame delay when split screen is sustained', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: GlobalSnackbar.rawMaterialAppNavigatorKey,
          routes: {
            '/': (context) => const Scaffold(body: Text('Home')),
            PlayerScreen.routeName: (context) => const Scaffold(body: Text('Player')),
          },
        ),
      );

      // Navigate to PlayerScreen
      GlobalSnackbar.navigatorState!.pushNamed(PlayerScreen.routeName);
      await tester.pumpAndSettle();
      expect(find.text('Player'), findsOneWidget);

      // Enter split-screen
      setUsingPlayerSplitScreenForTesting(true);
      SplitScreenNavigatorObserver.queueSplitScreenPop();

      // On current frame (frame 1), pop has not executed yet
      await tester.pump();
      expect(find.text('Player'), findsOneWidget);

      // On frame 2, split screen is sustained, so the delayed pop executes
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Player'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('does not pop player route when split-screen was transient (reset before frame 2)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: GlobalSnackbar.rawMaterialAppNavigatorKey,
          routes: {
            '/': (context) => const Scaffold(body: Text('Home')),
            PlayerScreen.routeName: (context) => const Scaffold(body: Text('Player')),
          },
        ),
      );

      // Navigate to PlayerScreen
      GlobalSnackbar.navigatorState!.pushNamed(PlayerScreen.routeName);
      await tester.pumpAndSettle();
      expect(find.text('Player'), findsOneWidget);

      // Transient entry into split-screen on frame 1
      setUsingPlayerSplitScreenForTesting(true);
      SplitScreenNavigatorObserver.queueSplitScreenPop();
      await tester.pump();

      // Window returns to small before frame 2 (transient spike ended)
      setUsingPlayerSplitScreenForTesting(false);
      await tester.pump();
      await tester.pumpAndSettle();

      // PlayerScreen should NOT be popped
      expect(find.text('Player'), findsOneWidget);
    });
  });
}
