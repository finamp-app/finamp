import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/components/PlayerScreen/player_buttons_more.dart';
import 'package:finamp/components/PlayerScreen/player_screen_album_image.dart';
import 'package:finamp/components/PlayerScreen/queue_button.dart';
import 'package:finamp/components/PlayerScreen/queue_list.dart';
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/screens/lyrics_screen.dart';
import 'package:finamp/services/current_album_image_provider.dart' as artwork;
import 'package:finamp/services/metadata_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/menus/output_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/current_track_metadata_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

final song = BaseItemDto(
  id: const BaseItemId('output-fixture-track'),
  name: 'Output fixture',
  type: 'Audio',
  userData: UserItemDataDto(playbackPositionTicks: 0, playCount: 0, isFavorite: false, played: false),
);

class FixtureQueue extends Fake implements QueueService {
  late final track = FinampQueueItem(
    item: MediaItem(
      id: song.id.toString(),
      title: song.name!,
      duration: const Duration(minutes: 3),
      extras: {'itemJson': song.toJson()},
    ),
    source: QueueItemSource.fromBaseItem(song),
  );
  late final info = FinampQueueInfo(
    id: 'fixture',
    previousTracks: [],
    currentTrack: track,
    nextUp: [],
    queue: [],
    source: track.source,
    saveState: SavedQueueState.init,
    sourceLibrary: null,
  );
  late final current = BehaviorSubject<FinampQueueItem?>.seeded(track);
  late final queue = BehaviorSubject<FinampQueueInfo?>.seeded(info);
  @override
  FinampQueueInfo getQueue() => info;
  @override
  BehaviorSubject<FinampQueueInfo?> getQueueStream() => queue;
  @override
  BehaviorSubject<FinampQueueItem?> getCurrentTrackStream() => current;
  @override
  List<FinampQueueItem> peekQueue({int? next, int previous = 0, bool current = false}) => [];
  @override
  FinampPlaybackOrder get playbackOrder => order.value;
  @override
  FinampLoopMode get loopMode => loop.value;
  @override
  double get playbackSpeed => speed.value;
  @override
  Future<void> skipByOffset(int offset) async {}
  final order = BehaviorSubject<FinampPlaybackOrder>.seeded(FinampPlaybackOrder.linear);
  final loop = BehaviorSubject<FinampLoopMode>.seeded(FinampLoopMode.none);
  final speed = BehaviorSubject<double>.seeded(1);
  @override
  FinampQueueItem? getCurrentTrack() => track;
  @override
  BehaviorSubject<FinampPlaybackOrder> getPlaybackOrderStream() => order;
  @override
  BehaviorSubject<FinampLoopMode> getLoopModeStream() => loop;
  @override
  BehaviorSubject<double> getPlaybackSpeedStream() => speed;
}

class FixtureAudio extends Fake implements MusicPlayerBackgroundTask {
  @override
  Future<List<FinampOutputRoute>> getRoutes() async => [];
  @override
  final ValueNotifier<SleepTimer?> timer = ValueNotifier<SleepTimer?>(null);
  @override
  final mediaItem = BehaviorSubject<MediaItem?>.seeded(null);
  @override
  final playbackState = BehaviorSubject<PlaybackState>.seeded(PlaybackState());
  @override
  final fadeState = BehaviorSubject<FadeState>.seeded(FadeState(fadeVolume: 1));
}

class FixtureUser extends Fake implements FinampUserHelper {
  @override
  FinampUser? get currentUser => null;
}

class FixtureDownloads extends Fake implements DownloadsService {
  @override
  bool? isFavorite(BaseItemDto item) => false;
  @override
  DownloadItemStatus getStatus(DownloadStub stub, int? recursive) => DownloadItemStatus.notNeeded;
  @override
  final statusProvider = Provider.family.autoDispose<DownloadItemStatus, (DownloadStub, int?)>(
    (ref, arguments) => DownloadItemStatus.notNeeded,
  );
}

class FixtureCache extends Fake implements BaseCacheManager {}

class FixtureAudioHelper extends Fake implements AudioServiceHelper {}

class FixtureApi extends Fake implements JellyfinApiHelper {}

class FixtureMetadata extends Fake implements MetadataProvider {
  FixtureMetadata({this.hasLyrics = true});
  @override
  final bool hasLyrics;
  @override
  BaseItemDto get item => song;
  @override
  LyricDto get lyrics => LyricDto(lyrics: [LyricLine(text: 'Fixture lyric')]);
  @override
  bool get qualifiesForPlaybackSpeedControl => false;
}

class RouteLog extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.remove(route);
}

Future<RouteLog> mount(
  WidgetTester tester, {
  bool playerMenu = true,
  bool hideBottomActions = true,
  bool disableGestures = true,
  bool artworkMenu = false,
  bool openMenu = true,
  bool legacyCaller = false,
  Size size = const Size(700, 1400),
  AsyncValue<MetadataProvider?>? metadata,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final audio = FixtureAudio();
  GetIt.instance.registerSingleton<MusicPlayerBackgroundTask>(audio);
  final queue = FixtureQueue();
  audio.mediaItem.add(queue.track.item);
  GetIt.instance.registerSingleton<QueueService>(queue);
  GetIt.instance.registerSingleton<FinampUserHelper>(FixtureUser());
  GetIt.instance.registerSingleton<DownloadsService>(FixtureDownloads());
  GetIt.instance.registerSingleton<AudioServiceHelper>(FixtureAudioHelper());
  GetIt.instance.registerSingleton<JellyfinApiHelper>(FixtureApi());
  final settings = FinampSettings(
    downloadLocations: [],
    downloadLocationsMap: {},
    tabSortBy: {},
    tabSortOrder: {},
    homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
    featureChipsConfiguration: const FinampFeatureChipsConfiguration(enabled: false, features: [], migrated: true),
    previousTracksPersistenceMode: PreviousTracksPersistenceMode.persistent,
    gridImageSize: 160,
    homeScreenImageSize: 160,
    deviceId: 'output-menu-test',
    isOffline: true,
    hidePlayerBottomActions: hideBottomActions,
    useCoverAsBackground: false,
    showLyricsScreenAlbumPrelude: false,
    enableVibration: false,
  );
  settings.disableGesture = disableGestures;
  await Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", settings);
  final container = ProviderContainer(
    overrides: [
      localThemeProvider.overrideWithValue(ColorScheme.fromSeed(seedColor: Colors.blue)),
      artwork.currentAlbumImageProvider.overrideWithValue(FinampImage.empty()),
      finampSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      currentTrackMetadataProvider.overrideWithValue(metadata ?? AsyncValue.data(FixtureMetadata())),
      currentTrackProvider.overrideWith((ref) => Stream.value(queue.track)),
      QueueService.queueProvider.overrideWithValue(queue.info),
      currentRadioAvailabilityStatusProvider.overrideWithValue(RadioModeAvailabilityStatus.disabled),
      radioStateProvider.overrideWithValue(null),
    ],
  );
  GetIt.instance.registerSingleton<ProviderContainer>(container);
  await container.read(finampSettingsProvider.future);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    audio.timer.dispose();
    await queue.current.close();
    await queue.queue.close();
    await queue.order.close();
    await queue.loop.close();
    await queue.speed.close();
    await audio.mediaItem.close();
    await audio.playbackState.close();
    await audio.fadeState.close();
    await GetIt.instance.reset();
  });
  final routeLog = RouteLog();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp(
          locale: const Locale('en'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [routeLog],
          routes: {PlayerScreen.routeName: (context) => const PlayerScreen(key: ValueKey('player'))},
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open fixture'),
                onPressed: () {
                  if (playerMenu && !legacyCaller) {
                    Navigator.of(context).pushNamed(PlayerScreen.routeName);
                  } else {
                    showModalTrackMenu(context: context, item: song, showPlaybackControls: legacyCaller);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open fixture'));
  await tester.pumpAndSettle();
  if (playerMenu && !legacyCaller && openMenu) {
    if (artworkMenu) {
      await tester.tap(find.byType(PlayerScreenAlbumImage), buttons: kSecondaryMouseButton);
    } else {
      await tester.tap(find.byType(PlayerButtonsMore));
    }
    await tester.pumpAndSettle();
  }
  return routeLog;
}

Finder menuTile(String title) =>
    find.descendant(of: find.byType(TrackMenu), matching: find.widgetWithText(ListTile, title));

Future<void> capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('EVIDENCE_DIR');
  if (directory.isEmpty) return;
  const stage = String.fromEnvironment('EVIDENCE_STAGE', defaultValue: 'after');
  await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile(Uri.file('$directory/$name-$stage.png')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StreamSubscription<Duration> positionSubscription;
  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_service.client.methods'),
      (call) async => <String, dynamic>{},
    );
    await AudioService.init(builder: BaseAudioHandler.new, cacheManager: FixtureCache());
    // audio_service retains its position timer after the last listener; create it
    // outside individual widget tests' fake clocks and share the subscription.
    positionSubscription = AudioService.position.listen((_) {});
    const font = String.fromEnvironment('EVIDENCE_FONT');
    if (font.isNotEmpty) {
      final bytes = ByteData.sublistView(File(font).readAsBytesSync());
      // The bottom sheet creates its own ThemeData, including Apple's font family.
      for (final family in ['Roboto', '.AppleSystemUIFont']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
      final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
      for (final family in manifest) {
        final loader = FontLoader(family['family'] as String);
        for (final asset in family['fonts'] as List<dynamic>) {
          loader.addFont(rootBundle.load(asset['asset'] as String));
        }
        await loader.load();
      }
    }
  });
  tearDownAll(() async {
    await positionSubscription.cancel();
    VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 500);
  });
  final nativeTarget = TargetPlatformVariant.only(Platform.isMacOS ? TargetPlatform.macOS : TargetPlatform.android);
  late Directory directory;
  setUp(() async {
    if (Platform.isMacOS) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async => null,
      );
    }
    directory = await Directory.systemTemp.createTemp('finamp-output-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(28)) {
      Hive.registerAdapters();
      Hive.registerAdapter(ThemeModeAdapter());
      Hive.registerAdapter(ColorAdapter());
      Hive.registerAdapter(LocaleAdapter());
    }
    await Hive.openBox<FinampSettings>('FinampSettings', bytes: Uint8List(0));
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final hidden in [false, true]) {
    for (final gestures in [false, true]) {
      for (final artwork in [false, true]) {
        testWidgets('player actions: hidden=$hidden disabled gestures=$gestures artwork=$artwork', (tester) async {
          await mount(tester, hideBottomActions: hidden, disableGestures: gestures, artworkMenu: artwork);
          for (final title in ['Output', 'Queue', 'Lyrics']) {
            expect(menuTile(title), hidden ? findsOneWidget : findsNothing);
          }
          if (hidden) {
            await tester.ensureVisible(menuTile('Lyrics'));
            await tester.pumpAndSettle();
            final tiles = tester
                .widgetList<ListTile>(find.descendant(of: find.byType(TrackMenu), matching: find.byType(ListTile)))
                .map((tile) => (tile.title as Text).data)
                .toList();
            expect(tiles.sublist(tiles.length - 3), ['Output', 'Queue', 'Lyrics']);
          }
        }, variant: nativeTarget);
      }
    }
  }
  for (final size in [const Size(1400, 700), const Size(480, 280)]) {
    for (final artwork in [false, true]) {
      testWidgets('adaptive player layout $size artwork=$artwork', (tester) async {
        await mount(tester, hideBottomActions: false, size: size, artworkMenu: artwork);
        final playerHasBottomActions = find.byType(QueueButton).evaluate().isNotEmpty;
        for (final title in ['Output', 'Queue', 'Lyrics']) {
          if (!playerHasBottomActions) {
            await tester.scrollUntilVisible(
              menuTile(title),
              100,
              scrollable: find.descendant(of: find.byType(TrackMenu), matching: find.byType(Scrollable)).first,
            );
          }
          expect(menuTile(title), playerHasBottomActions ? findsNothing : findsOneWidget);
        }
        if (size.height == 280) expect(playerHasBottomActions, isFalse);
      }, variant: nativeTarget);
    }
  }
  for (final state in ['loading', 'missing', 'error']) {
    testWidgets('lyrics stays reachable with $state metadata', (tester) async {
      final metadata = switch (state) {
        'loading' => const AsyncValue<MetadataProvider?>.loading(),
        'error' => AsyncValue<MetadataProvider?>.error(StateError('fixture'), StackTrace.empty),
        _ => AsyncValue<MetadataProvider?>.data(FixtureMetadata(hasLyrics: false)),
      };
      await mount(tester, metadata: metadata);
      await tester.ensureVisible(menuTile('Lyrics'));
      final tile = tester.widget<ListTile>(menuTile('Lyrics'));
      expect((tile.leading as Icon).icon, state == 'loading' ? TablerIcons.microphone_2 : TablerIcons.microphone_2_off);
      await tester.tap(menuTile('Lyrics'));
      await tester.pumpAndSettle();
      expect(find.byType(LyricsScreen), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(find.byType(LyricsScreen)))!;
      expect(
        find.text(switch (state) {
          'loading' => l10n.lyricsEmptyStateLoading,
          'missing' => l10n.lyricsEmptyStateNoLyrics,
          _ => l10n.lyricsEmptyStateFailed,
        }),
        findsOneWidget,
      );
    }, variant: nativeTarget);
  }
  for (final disabled in [false, true]) {
    testWidgets('lyrics queue swipe respects disabled gestures=$disabled', (tester) async {
      await mount(tester, disableGestures: disabled);
      await tester.ensureVisible(menuTile('Lyrics'));
      await tester.tap(menuTile('Lyrics'));
      await tester.pumpAndSettle();
      await tester.flingFrom(const Offset(690, 180), const Offset(0, -100), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(QueueList), disabled ? findsNothing : findsOneWidget);
    }, variant: nativeTarget);
  }
  testWidgets('lyrics menu keeps Output and Queue without opening duplicate lyrics routes', (tester) async {
    final log = await mount(tester);
    await tester.ensureVisible(menuTile('Lyrics'));
    await tester.tap(menuTile('Lyrics'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PlayerButtonsMore));
    await tester.pumpAndSettle();
    expect(menuTile('Output'), findsOneWidget);
    expect(menuTile('Queue'), findsOneWidget);
    expect(menuTile('Lyrics'), findsNothing);
    await tester.tap(menuTile('Output'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackMenu), findsNothing);
    expect(log.routes.map((route) => route.settings.name), [
      '/',
      PlayerScreen.routeName,
      LyricsScreen.routeName,
      outputMenuRouteName,
    ]);
    log.routes.last.navigator!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LyricsScreen), findsOneWidget);
    expect(log.routes.length, 3);
  }, variant: nativeTarget);
  if (const String.fromEnvironment('EVIDENCE_DIR').isNotEmpty) {
    for (final hidden in [false, true]) {
      testWidgets('capture player menu hidden=$hidden', (tester) async {
        await mount(tester, hideBottomActions: hidden);
        await capture(tester, hidden ? 'menu-hidden' : 'menu-visible');
      }, variant: nativeTarget);
    }
  }
  testWidgets('ordinary library track menus do not gain player actions', (tester) async {
    await mount(tester, playerMenu: false);
    for (final title in ['Output', 'Queue', 'Lyrics']) {
      expect(menuTile(title), findsNothing);
    }
  }, variant: nativeTarget);
  testWidgets('existing callers with playback controls retain their default menu', (tester) async {
    await mount(tester, legacyCaller: true);
    expect(menuTile('Output'), findsNothing);
    expect(menuTile('Queue'), findsNothing);
    expect(menuTile('Lyrics'), findsNothing);
  }, variant: nativeTarget);
  for (final title in ['Output', 'Queue', 'Lyrics']) {
    testWidgets('$title replaces the menu and Back returns directly to the player', (tester) async {
      final log = await mount(tester);
      await tester.ensureVisible(menuTile(title));
      await tester.tap(menuTile(title));
      await tester.pumpAndSettle();
      expect(find.byType(TrackMenu), findsNothing);
      expect(log.routes.map((route) => route.settings.name), [
        '/',
        PlayerScreen.routeName,
        switch (title) {
          'Queue' => QueueList.routeName,
          'Lyrics' => LyricsScreen.routeName,
          _ => '/output-menu',
        },
      ]);
      if (title == 'Output') {
        expect(find.byType(VolumeSlider), findsOneWidget);
        await capture(tester, 'output-opened');
      } else if (title == 'Queue') {
        expect(find.byType(QueueList), findsOneWidget);
        await capture(tester, 'queue-opened');
      } else {
        expect(find.byType(LyricsScreen), findsOneWidget);
        expect(find.text('Fixture lyric', findRichText: true), findsOneWidget);
        await capture(tester, 'lyrics-opened');
      }
      log.routes.last.navigator!.pop();
      await tester.pumpAndSettle();
      expect(log.routes.map((route) => route.settings.name), ['/', PlayerScreen.routeName]);
      expect(find.byType(PlayerButtonsMore), findsOneWidget);
    }, variant: nativeTarget);
  }
  for (final hidden in [false, true]) {
    for (final disabled in [false, true]) {
      testWidgets('player swipes respect settings: hidden=$hidden disabled=$disabled', (tester) async {
        final log = await mount(tester, hideBottomActions: hidden, disableGestures: disabled, openMenu: false);
        await tester.flingFrom(const Offset(350, 500), const Offset(0, -180), 1000);
        await tester.pumpAndSettle();
        expect(find.byType(QueueList), disabled ? findsNothing : findsOneWidget);
        if (!disabled) {
          log.routes.last.navigator!.pop();
          await tester.pumpAndSettle();
        }
        await tester.flingFrom(const Offset(650, 1350), const Offset(-180, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.byType(LyricsScreen), disabled ? findsNothing : findsOneWidget);
        if (!disabled) {
          log.routes.last.navigator!.pop();
          await tester.pumpAndSettle();
        }
        await tester.flingFrom(const Offset(350, 500), const Offset(0, 180), 1000);
        await tester.pumpAndSettle();
        expect(log.routes.length, disabled ? 2 : 1);
      }, variant: nativeTarget);
    }
  }
}
