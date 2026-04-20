import 'package:finamp/components/AlbumScreen/album_screen_content.dart';
import 'package:finamp/components/Buttons/cta_large.dart';
import 'package:finamp/components/MusicScreen/item_collection_wrapper.dart';
import 'package:finamp/main.dart' as app;
import 'package:finamp/menus/components/playbackActions/playback_actions.dart';
import 'package:finamp/screens/login_screen.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The ProviderContainer initialized by main().
  /// All tests should create and attach to descendants of this to avoid errors.
  ProviderContainer? container;
  Object? mainError;

  setUpAll(() async {
    try {
      // Login testing flag redirects file accesses to testing folder and clears it on startup.
      // Downloaded files are still left in original folder, but they shouldn't really affect testing.
      await app.main(integrationTesting: true, loginTesting: true);
    } catch (e) {
      mainError = e;
    }
  });

  // These integration tests all rely on the previous one working.  Not good practice, but whatever.
  group('Integration Tests', () {
    testWidgets('Verify app loads without errors', (tester) async {
      // Running main in setup instead of here to prevent all logging from being attributed
      // to this test in output.
      if (mainError != null) {
        throw mainError!;
      }

      // Save off initialized provider container so tests can create and attach descendants
      // TODO could we get errors from background tasks also attaching to this when they need persistence?
      // If we do, we could pass the container down main() instead of overwriting GetIt.
      container = GetIt.instance<ProviderContainer>();
      GetIt.instance.unregister<ProviderContainer>();
      GetIt.instance.registerSingleton(ProviderContainer(parent: container));

      // This makes the screen sized correctly when watching integration test.
      // I don't know why this works or is needed.
      await tester.pumpWidget(Container(color: Colors.white));
      await tester.pumpWidget(app.Finamp());

      await tester.pumpAndSettle();

      // Verify FinampApp loaded.
      expect(find.byType(LoginScreen), findsOneWidget);

      container = GetIt.instance<ProviderContainer>();
      GetIt.instance.unregister<ProviderContainer>();
      GetIt.instance.registerSingleton(ProviderContainer(parent: container));
    });
    testWidgets('Log in to demo server', (tester) async {
      GetIt.instance.unregister<ProviderContainer>();
      GetIt.instance.registerSingleton(ProviderContainer(parent: container));
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
    testWidgets('Start playing a track', (tester) async {
      GetIt.instance.unregister<ProviderContainer>();
      GetIt.instance.registerSingleton(ProviderContainer(parent: container));
      await tester.pumpWidget(app.Finamp());
      await tester.pump();
      FinampSetters.setAllowSplitScreen(false);

      final album = find.byType(ItemCollectionWrapper);
      await tester.waitFor(album);
      await tester.tap(album.first);

      final trackList = find.byType(TracksSliverList);
      await tester.waitFor(trackList);
      await tester.pumpAndSettle();

      final playButton = find.byType(PlayPlaybackAction);
      await tester.tap(playButton);
      await tester.pump();

      final playerScreen = find.byKey(Key("NowPlayingBar"));
      await tester.waitFor(playerScreen);
      await tester.pump();

      // Progress into song
      await Future<void>.delayed(Duration(seconds: 30));
      await tester.pump();
      final playerService = GetIt.instance<MusicPlayerBackgroundTask>();
      final playbackPosition = playerService.playbackPosition;

      // Verify track has been playing for 30 seconds as expected.
      expect(playbackPosition.inSeconds, inInclusiveRange(15, 40));
    });
    // TODO add test where we migrate from old settings data?
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
        await Future<void>.delayed(Duration(seconds: 1));
      }
    }
  }
}
