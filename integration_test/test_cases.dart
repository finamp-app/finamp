import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:finamp/components/AlbumScreen/album_screen_content.dart';
import 'package:finamp/components/Buttons/cta_large.dart';
import 'package:finamp/components/LoginScreen/login_server_selection_page.dart';
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
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The ProviderContainer initialized by main().
  /// All tests should create and attach to descendants of this to avoid errors.
  ProviderContainer? container;
  List<FlutterErrorDetails>? mainErrors = [];
  bool mainCompleted = false;

  setUpAll(() async {
    // Disable audio output on windows and linux due to missing driver in CI
    if (Platform.isWindows || Platform.isLinux) {
      JustAudioMediaKit.nullBackend = true;
    }

    // If main throws an error, the future runZoneGuarded returns will never complete, so do not await it.
    //Instead, we will simply check that main has completed with no errors after a 30 second timeout.  This also
    // allows some errors thrown by the background services to be caught before the following tests start.
    unawaited(
      runZonedGuarded(
        () async {
          // Login testing flag redirects file accesses to testing folder and clears it on startup.
          // Download base directories are not redirected, so loginTesting flag should be avoided on mobile.
          // Note that this means mobile integration test runs will require manual file clearing outside of CI
          await app.main(integrationTesting: true, loginTesting: !(Platform.isAndroid || Platform.isIOS));
          mainCompleted = true;
        },
        (e, stack) {
          // Linux throws DBusServiceUnknownException due to dbus service org.freedesktop.UPower
          // missing in CI.  Ignore.
          if (e is DBusServiceUnknownException) return;

          if (mainErrors != null) {
            mainErrors!.add(FlutterErrorDetails(exception: e, stack: stack));
          } else {
            debugPrint("Received background error after completion of main()");
            debugPrint("Error: $e");
            debugPrintStack(stackTrace: stack);
            // If main has already completed, the app's core functionality is working, so we allow the tests to complete
            // without rethrowing the error.
          }
        },
      ),
    );

    await Future<void>.delayed(Duration(seconds: 30));
  });

  // These integration tests all rely on the previous one working.  Not good practice, but whatever.
  group('Integration Tests', () {
    testWidgets('Verify app loads without errors', (tester) async {
      // Running main in setup instead of here to prevent all logging from being attributed
      // to this test in output.
      for (var error in mainErrors!) {
        debugPrint("Error thrown in main: ${error.exception}");
        if (error.stack != null) {
          debugPrintStack(stackTrace: error.stack!);
        }
      }

      expect(mainErrors!.length, equals(0));
      expect(mainCompleted, equals(true));

      mainErrors = null;

      // The testing harness tries to clear out all the async code between tests, and runs all the cases in individual
      // async contexts as part of this. I believe the expectation is that background services and realtime tasks will
      // all be replaced with mockups, for more consistent and self-contained tests. But this code doesn't do that and
      // has real persistent background services, so I've had errors occasionally showing up in earlier tests occasionally,
      // and a bunch of strange issues with providers were occurring. Giving each test its own child ProviderContainer
      // which inherits the global persistent providers from the original one set up in main seems to have solved those, but it's
      // all still a bit mysterious.
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

      final serverButton = find.byWidgetPredicate(
        (x) => x is JellyfinServerSelectionWidget && (x.baseUrl?.contains("demo.jellyfin.org") ?? false),
      );
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

      // Verify login is complete and Music screen loaded
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
