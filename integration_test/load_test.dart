import 'package:finamp/components/Buttons/cta_large.dart';
import 'package:finamp/main.dart' as app;
import 'package:finamp/screens/login_screen.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // These integration tests all rely on the previous one working.  Not good practice, but whatever.
  group('Integration Tests', () {
    testWidgets('Verify app loads without errors', (tester) async {
      // Login testing flag redirects file accesses to integration_test folder and clears it on startup.
      // Downloads are still left in original folder, but they shouldn't really affect testing.
      await tester.runAsync(() => app.main(integrationTesting: true, loginTesting: true));

      // This makes the screen sized correctly when watching integration test.
      // I don't know why this works or is needed.
      await tester.pumpWidget(Container(color: Colors.white));
      await tester.pumpWidget(app.Finamp());

      await tester.pumpAndSettle();

      // Verify FinampApp loaded.
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Login to demo server', (tester) async {
      await tester.pumpWidget(app.Finamp());
      await tester.pumpAndSettle();

      final startButton = find.byType(CTALarge);
      await tester.tap(startButton);
      await tester.pump();

      final urlEntry = find.byType(TextFormField);
      await tester.enterText(urlEntry, "https://demo.jellyfin.org/stable");

      final serverButton = find.text("Stable Demo");
      await tester.waitFor(serverButton);
      await tester.tap(serverButton);
      await tester.pump(Duration(seconds: 1));

      final customUserButton = find.text("Custom User");
      await tester.tap(customUserButton);
      await tester.pump(Duration(seconds: 1));

      final userTextField = find.byType(TextFormField).first;
      await tester.enterText(userTextField, "demo");
      final loginButton = find.text("Log In");
      await tester.tap(loginButton);

      final musicScreen = find.byType(MusicScreen);
      await tester.waitFor(musicScreen);
      await tester.pump(Duration(seconds: 1));

      // Verify Music screen loaded
      // TODO any other verifications beyond reaching this point?
      expect(find.byType(MusicScreen), findsOneWidget);
    });
  });
}

extension WaitForElement on WidgetTester {
  Future<void> waitFor(Finder finder, {int seconds = 20, bool realtime = true}) async {
    int i = 0;
    while (true) {
      await pump(Duration(seconds: 1));
      if (any(finder)) {
        return;
      }
      if (i >= seconds) {
        throw "$finder never found expected widget after $seconds seconds.";
      }
      i++;
      if (realtime) {
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }
}
