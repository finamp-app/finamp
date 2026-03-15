import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/gen/assets.gen.dart';
import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/screens/accessibility_settings_screen.dart';
import 'package:finamp/screens/album_settings_screen.dart';
import 'package:finamp/screens/artist_settings_screen.dart';
import 'package:finamp/screens/downloads_settings_screen.dart';
import 'package:finamp/screens/genre_settings_screen.dart';
import 'package:finamp/screens/interaction_settings_screen.dart';
import 'package:finamp/screens/login_screen.dart';
import 'package:finamp/screens/lyrics_settings_screen.dart';
import 'package:finamp/screens/network_settings_screen.dart';
import 'package:finamp/screens/playback_history_screen.dart';
import 'package:finamp/screens/playback_reporting_settings_screen.dart';
import 'package:finamp/screens/player_settings_screen.dart';
import 'package:finamp/screens/playlist_edit_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/android_auto_helper.dart';
import 'package:finamp/services/audio_service_smtc.dart';
import 'package:finamp/services/data_source_service.dart';
import 'package:finamp/services/dbus_manager.dart';
import 'package:finamp/services/discord_rpc.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/downloads_service_backend.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_logs_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/keep_screen_on_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:finamp/services/offline_listen_helper.dart';
import 'package:finamp/services/playback_history_service.dart';
import 'package:finamp/services/playon_service.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:finamp/services/ui_overlay_setter_observer.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_user_certificates_android/flutter_user_certificates_android.dart';
import 'package:gaimon/gaimon.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl_standalone.dart';
import 'package:isar/isar.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import 'components/Buttons/simple_button.dart';
import 'components/LogsScreen/copy_logs_button.dart';
import 'components/LogsScreen/share_logs_button.dart';
import 'components/PlayerScreen/player_split_screen_scaffold.dart';
import 'components/global_snackbar.dart';
import 'models/finamp_models.dart';
import 'models/migration_adapters.dart';
import 'models/theme_mode_adapter.dart';
import 'screens/active_downloads_screen.dart';
import 'screens/add_download_location_screen.dart';
import 'screens/album_screen.dart';
import 'screens/artist_screen.dart';
import 'screens/audio_service_settings_screen.dart';
import 'screens/customization_settings_screen.dart';
import 'screens/downloads_location_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/genre_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/layout_settings_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/music_screen.dart';
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tabs_settings_screen.dart';
import 'screens/transcoding_settings_screen.dart';
import 'screens/view_selector.dart';
import 'screens/volume_normalization_settings_screen.dart';
import 'services/audio_service_helper.dart';
import 'services/jellyfin_api_helper.dart';
import 'services/music_player_background_task.dart';
import 'setup_logging.dart';

final _mainLog = Logger("Main()");
late DateTime startTime;

final providerScopeKey = GlobalKey();

void main() async {
  // If the app has failed, this is set to true. If true, we don't attempt to run the main app since the error app has started.
  bool hasFailed = false;
  try {
    startTime = DateTime.now();
    await setupLogging();
    await _setupEdgeToEdgeOverlayStyle();
    _mainLog.info("Setup edge-to-edge overlay");
    await setupHive();
    _mainLog.info("Setup hive and isar");
    _migrateDownloadLocations();
    _migrateSortOptions();
    await _migrateThemeModeLocale();
    _mainLog.info("Completed applicable migrations");
    await _trustAndroidUserCerts();
    _mainLog.info("Trusted Android user certs");
    await _setupFinampUserHelper();
    _mainLog.info("Setup user helper");
    await _setupJellyfinApiData();
    _mainLog.info("setup jellyfin api");
    _setupOfflineListenLogHelper();
    _mainLog.info("Setup offline listen tracking");
    await _setupDownloadsHelper();
    _mainLog.info("Setup downloads service");
    await _setupProviders();
    _mainLog.info("Setup providers");
    await _setupOSIntegration();
    _mainLog.info("Setup os integrations");
    await _setupPlayOnService();
    _mainLog.info("Setup PlayOnService");
    await _setupPlaybackServices();
    _mainLog.info("Setup audio player");
    await _setupKeepScreenOnHelper();
    _mainLog.info("Setup KeepScreenOnHelper");
    await _setupDiscordRpc();
    _mainLog.info("Setup Discord RPC");
  } catch (error, trace) {
    hasFailed = true;
    Logger("ErrorApp").severe(error, null, trace);
    runApp(FinampErrorApp(error: error, trace: trace));
  }

  if (!hasFailed) {
    final flutterLogger = Logger("Flutter");

    FlutterError.onError = (FlutterErrorDetails details) {
      var error = details.exception;
      if (error is Error) {
        details = details.copyWith(stack: error.stackTrace ?? details.stack);
      }
      FlutterError.presentError(details);
      flutterLogger.severe(error, error, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      flutterLogger.severe(error, error, stack);
      // We have not handled printing to console, flutter should still do that.
      return false;
    };

    DartPluginRegistrant.ensureInitialized();

    await findSystemLocale();
    await initializeDateFormatting();
    unawaited(fetchSystemPalette());
    await initDBus();

    _mainLog.info("Launching main app");

    runApp(const Finamp());
  }
}

Future<void> _setupEdgeToEdgeOverlayStyle() async {
  if (Platform.isAndroid) {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent));
    final binding = WidgetsFlutterBinding.ensureInitialized();
    binding.addObserver(UIOverlaySetterObserver());
  } else if (Platform.isIOS) {
    // On iOS, the status bar will have black icons by default on the login
    // screen as it does not have an AppBar. To fix this, we set the
    // brightness to dark manually on startup.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark));
  }
}

Future<void> _setupJellyfinApiData() async {
  GetIt.instance.registerSingleton(JellyfinApiHelper());
}

void _setupOfflineListenLogHelper() {
  GetIt.instance.registerSingleton(OfflineListenLogHelper());
}

Future<void> _setupDownloadsHelper() async {
  await Future.wait(
    FinampSettingsHelper.finampSettings.downloadLocationsMap.values.map((element) => element.updateCurrentPath()),
  );
  final fileDownloader = FileDownloader(persistentStorage: IsarPersistentStorage());
  await fileDownloader.ready;
  WidgetsFlutterBinding.ensureInitialized();
  // There is additional FileDownloader setup inside downloadsService constructor
  GetIt.instance.registerSingleton(DownloadsService());
  final downloadsService = GetIt.instance<DownloadsService>();

  if (!FinampSettingsHelper.finampSettings.hasCompletedDownloadsServiceMigration) {
    await downloadsService.migrateFromHive();
    FinampSetters.setHasCompletedDownloadsServiceMigration(true);
  } else {
    // Some users may have missed migration due to a bug in the flag setting and
    // are therefore missing an internal directory
    if (FinampSettingsHelper.finampSettings.downloadLocationsMap.values
        .where((element) => element.baseDirectory == DownloadLocationType.platformDefaultDirectory)
        .isEmpty) {
      _mainLog.info("Internal Storage download location is missing.  Recreating.");
      final downloadLocation = await DownloadLocation.create(
        name: DownloadLocation.internalStorageName,
        baseDirectory: DownloadLocationType.platformDefaultDirectory,
      );
      FinampSettingsHelper.addDownloadLocation(downloadLocation);
      // There may be old downloads present due to skipping the migration
      // Run a repair to make sure they all get cleaned up.
      unawaited(downloadsService.repairAllDownloads().then((value) => null, onError: GlobalSnackbar.error));
    }
  }

  await _migrateDownloadsFileOwner();

  await fileDownloader.configure(globalConfig: (Config.checkAvailableSpace, 1024));
  await fileDownloader.resumeFromBackground();
  await downloadsService.startQueues();

  if (!FinampSettingsHelper.finampSettings.hasDownloadedPlaylistInfo) {
    GetIt.instance<FinampUserHelper>().runUserHook(() async {
      await downloadsService.addDefaultPlaylistInfoDownload().catchError((Object e) {
        // log error without snackbar, we don't want users to be greeted with errors on first launch
        _mainLog.severe("Failed to download playlist metadata: $e");
      });
      FinampSetters.setHasDownloadedPlaylistInfo(true);
    });
  }
}

Future<void> _setupPlayOnService() async {
  final playOnService = PlayOnService();
  GetIt.instance.registerSingleton(playOnService);
  GetIt.instance<FinampUserHelper>().runUserHook(playOnService.initialize);
}

Future<void> _setupDiscordRpc() async {
  DiscordRpc.initialize();
}

Future<void> _setupKeepScreenOnHelper() async {
  GetIt.instance.registerSingleton(KeepScreenOnHelper());
}

Future<void> setupHive() async {
  final dir = (Platform.isAndroid || Platform.isIOS)
      ? await getApplicationDocumentsDirectory()
      : await getApplicationSupportDirectory();

  // Use Hive.init instead of initFlutter to set correct default path.
  WidgetsFlutterBinding.ensureInitialized();
  Hive.init(dir.path);
  Hive.registerAdapters();
  Hive.registerAdapter(ThemeModeAdapter());
  Hive.registerAdapter(ColorAdapter());
  Hive.registerAdapter(LocaleAdapter());
  Hive.registerAdapter(FinampStorableQueueInfoMigrationAdapter());

  await Future.wait([
    Hive.openBox<FinampSettings>("FinampSettings", path: dir.path),
    Hive.openBox<FinampStorableQueueInfo>("Queues", path: dir.path),
    Hive.openBox<OfflineListen>("OfflineListens", path: dir.path),
    Hive.openBox<RawThemeResult>("CachedThemes", path: dir.path),
  ]);

  // If the settings box is empty, we add an initial settings value here.
  Box<FinampSettings> finampSettingsBox = Hive.box("FinampSettings");
  if (finampSettingsBox.isEmpty) {
    await finampSettingsBox.put("FinampSettings", await FinampSettings.create());
  }

  final compactFile = File(path_helper.join(dir.path, "$isarDatabaseName.isar.compact"));
  if (compactFile.existsSync()) {
    compactFile.deleteSync();
  }
  final isar = await Isar.open(
    [DownloadItemSchema, IsarTaskDataSchema, FinampUserSchema, DownloadedLyricsSchema],
    directory: dir.path,
    name: isarDatabaseName,
    compactOnLaunch: CompactCondition(minBytes: 5 * 1024 * 1024),
    relaxedDurability: true,
  );
  GetIt.instance.registerSingleton(isar);
}

Future<void> _setupProviders() async {
  var container = ProviderContainer(observers: [FinampProviderObserver()]);
  GetIt.instance.registerSingleton<ProviderContainer>(container);
  // Make sure that finampSettingsProvider always has a value available
  container.listen(finampSettingsProvider, (_, __) {});
  await container.read(finampSettingsProvider.future);

  await initImageCache();

  DataSourceService.create();
  AutoOffline.startWatching();

  unawaited(
    Stream<void>.periodic(Duration(seconds: 1)).forEach((_) {
      if (!SchedulerBinding.instance.framesEnabled) {
        (providerScopeKey.currentContext as InheritedElement?)?.build();
      }
    }),
  );
}

Future<void> _setupOSIntegration() async {
  // set up window manager on desktop, mainly to restrict minimum size
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final screenSize = FinampSettingsHelper.finampSettings.screenSize;
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: screenSize?.size ?? Size(1200, 800),
      center: screenSize == null,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      minimumSize: Size(400, 250),
    );
    unawaited(
      WindowManager.instance.waitUntilReadyToShow(windowOptions, () async {
        if (screenSize != null) {
          await windowManager.setPosition(screenSize.location);
        }
        GetIt.instance<ProviderContainer>().listen(brightnessProvider, fireImmediately: true, (_, brightness) {
          windowManager.setBrightness(brightness);
        });
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  // Load the album image from assets and save it to the documents directory for use in Android Auto
  final applicationSupportDirectory = await getApplicationSupportDirectory();
  final albumImageFile = File(
    path_helper.join(applicationSupportDirectory.absolute.path, Assets.images.albumWhite.path),
  );
  if (!(await albumImageFile.exists())) {
    final albumImageBytes = await rootBundle.load(Assets.images.albumWhite.path);
    final albumBuffer = albumImageBytes.buffer;
    await albumImageFile.create(recursive: true);
    await albumImageFile.writeAsBytes(
      albumBuffer.asUint8List(albumImageBytes.offsetInBytes, albumImageBytes.lengthInBytes),
    );
  }
}

Future<void> _setupPlaybackServices() async {
  if (Platform.isWindows) {
    AudioServiceSMTC.registerWith();
  }

  await MusicPlayerBackgroundTask.configureAudioSession();

  GetIt.instance.registerSingleton<AndroidAutoHelper>(AndroidAutoHelper());

  final audioHandler = await AudioService.init(
    builder: () => MusicPlayerBackgroundTask(),
    config: AudioServiceConfig(
      androidStopForegroundOnPause: FinampSettingsHelper.finampSettings.androidStopForegroundOnPause,
      androidNotificationChannelName: "Finamp",
      androidNotificationIcon: "mipmap/white",
      androidNotificationChannelId: "com.unicornsonlsd.finamp.audio",
      // notificationColor: TODO use the theme color for older versions of Android,
      // We will handle preloading artwork ourselves
      preloadArtwork: false,
      androidBrowsableRootExtras: <String, dynamic>{
        // support showing search button on Android Auto as well as alternative search results on the player screen after voice search
        "android.media.browse.SEARCH_SUPPORTED": true,
        // see https://developer.android.com/reference/androidx/media/utils/MediaConstants#DESCRIPTION_EXTRAS_VALUE_CONTENT_STYLE_GRID_ITEM()
        "android.media.browse.CONTENT_STYLE_BROWSABLE_HINT":
            FinampSettingsHelper.finampSettings.contentViewType == ContentViewType.list ? 1 : 2,
        "android.media.browse.CONTENT_STYLE_PLAYABLE_HINT":
            FinampSettingsHelper.finampSettings.contentViewType == ContentViewType.list ? 1 : 2,
      },
    ),
    cacheManager: StubImageCache(),
  );

  GetIt.instance.registerSingleton<MusicPlayerBackgroundTask>(audioHandler);
  var queueService = QueueService();
  GetIt.instance.registerSingleton(queueService);
  audioHandler.onQueueServiceAvailable(); // breaking circular dependency
  GetIt.instance.registerSingleton(PlaybackHistoryService());
  GetIt.instance.registerSingleton(AudioServiceHelper());

  // Begin to restore queue
  unawaited(queueService.performInitialQueueLoad().catchError((dynamic x) => GlobalSnackbar.error(x)));
}

/// Migrates the old DownloadLocations list to a map
void _migrateDownloadLocations() {
  final finampSettings = FinampSettingsHelper.finampSettings;

  // ignore: deprecated_member_use_from_same_package
  if (finampSettings.downloadLocations.isNotEmpty) {
    final Map<String, DownloadLocation> newMap = {};

    // ignore: deprecated_member_use_from_same_package
    for (var element in finampSettings.downloadLocations) {
      // Generate a UUID and set the ID field for the DownloadsLocation
      final id = const Uuid().v4();
      element.id = id;
      newMap[id] = element;
    }

    finampSettings.downloadLocationsMap = newMap;

    // ignore: deprecated_member_use_from_same_package
    finampSettings.downloadLocations = List.empty();

    FinampSettingsHelper.overwriteFinampSettings(finampSettings);
  }
}

/// Migrates the old SortBy/SortOrder to a map indexed by tab content type
void _migrateSortOptions() {
  final finampSettings = FinampSettingsHelper.finampSettings;

  var changed = false;

  if (finampSettings.tabSortBy.isEmpty) {
    for (var type in TabContentType.values) {
      // ignore: deprecated_member_use_from_same_package
      finampSettings.tabSortBy[type] = finampSettings.sortBy;
    }
    changed = true;
  }

  if (finampSettings.tabSortOrder.isEmpty) {
    for (var type in TabContentType.values) {
      // ignore: deprecated_member_use_from_same_package
      finampSettings.tabSortOrder[type] = finampSettings.sortOrder;
    }
    changed = true;
  }

  if (changed) {
    FinampSettingsHelper.overwriteFinampSettings(finampSettings);
  }
}

Future<void> _migrateDownloadsFileOwner() async {
  if (!Platform.isAndroid) {
    // Only Android needs this migration
    return;
  }
  if (!FinampSettingsHelper.finampSettings.hasCompletedDownloadsFileOwnerMigration) {
    var downloadsServiceChannel = MethodChannel("com.unicornsonlsd.finamp/downloads_service");
    var downloadLocations = FinampSettingsHelper.finampSettings.downloadLocationsMap;
    var downloadPaths = downloadLocations.values.map((e) => e.currentPath).toList();
    await downloadsServiceChannel.invokeMethod("fixDownloadsFileOwner", <String, dynamic>{
      'download_locations': downloadPaths,
    });
    FinampSetters.setHasCompletedDownloadsFileOwnerMigration(true);
  }
}

/// Migrates the old ThemeMode and Locale Hive box values to FinampSettings fields
Future<void> _migrateThemeModeLocale() async {
  if (!FinampSettingsHelper.finampSettings.hasCompletedThemeModeLocaleMigration) {
    Box<ThemeMode> oldThemeModeBox = await Hive.openBox<ThemeMode>("ThemeMode");
    Box<Locale?> oldLocaleBox = await Hive.openBox<Locale?>("Locale");

    var oldThemeMode = oldThemeModeBox.get("ThemeMode");
    var oldLocale = oldLocaleBox.get("Locale");

    FinampSetters.setThemeMode(oldThemeMode ?? ThemeMode.system);
    FinampSetters.setLocale(oldLocale);

    await oldThemeModeBox.deleteFromDisk();
    await oldLocaleBox.deleteFromDisk();

    FinampSetters.setHasCompletedThemeModeLocaleMigration(true);
  }
}

Future<void> _trustAndroidUserCerts() async {
  // Extend the default security context to trust Android user certificates.
  // This is a workaround for <https://github.com/dart-lang/sdk/issues/50435>.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterUserCertificatesAndroid().trustAndroidUserCertificates(SecurityContext.defaultContext);
  } catch (e) {
    Logger("AndroidCertTrust").severe("Failed to trust certificates: $e", e);
    GlobalSnackbar.error("Failed to trust user certificates: $e");
  }
}

Future<void> _setupFinampUserHelper() async {
  GetIt.instance.registerSingleton(FinampUserHelper());
  if (!FinampSettingsHelper.finampSettings.hasCompletedIsarUserMigration) {
    await GetIt.instance<FinampUserHelper>().migrateFromHive();
    FinampSetters.setHasCompletedIsarUserMigration(true);
  }
  await GetIt.instance<FinampUserHelper>().setAuthHeader();
}

class Finamp extends StatefulWidget {
  const Finamp({super.key});

  @override
  State<Finamp> createState() => _FinampState();
}

class _FinampState extends State<Finamp> with WindowListener {
  static final Logger windowManagerLogger = Logger("WindowManager");
  static final Logger linkHandlingLogger = Logger("LinkHandling");

  StreamSubscription<Uri>? _uriLinkSubscription;

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _uriLinkSubscription = AppLinks().uriLinkStream.listen((uri) async {
        linkHandlingLogger.info("Received link: $uri");
        var context = GlobalSnackbar.materialAppNavigatorKey.currentContext;
        if (context != null) {
          if (uri.host == "internal") {
            await Navigator.of(context).pushNamed(uri.path);
          }
        } else {
          linkHandlingLogger.warning("No context available to handle link");
        }
      });
    });

    // If the app is running on desktop, we add a listener to the window manager
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowManager.instance.addListener(this);
      // windowManager.setPreventClose(true); //!!! destroying the window manager instance doesn't seem to work on Windows release builds, the app just freezes instead
    }
  }

  @override
  Future<void> dispose() async {
    await DiscordRpc.stop().timeout(Duration(milliseconds: 500));
    await _uriLinkSubscription?.cancel();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowManager.instance.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      key: providerScopeKey,
      container: GetIt.instance<ProviderContainer>(),
      child: GestureDetector(
        onTap: () {
          // Never rebuild FinampApp context, it breaks ProviderScope
          FocusScopeNode currentFocus = FocusScope.of(context, createDependency: false);

          if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: FinampProviderBuilder(child: FinampApp()),
      ),
    );
  }

  @override
  void onWindowEvent(String eventName) async {
    if (eventName == "move" || eventName == "resize") return;

    windowManagerLogger.finer("[WindowManager] onWindowEvent: $eventName");

    if (eventName == "moved" || eventName == "resized") {
      FinampSetters.setScreenSize(ScreenSize.from(await windowManager.getSize(), await windowManager.getPosition()));
      windowManagerLogger.finer("Saved window size and position");
    }
  }

  @override
  void onWindowClose() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    // Destroy player on platforms using mediaKit.
    if (Platform.isWindows || Platform.isLinux) {
      await GetIt.instance<MusicPlayerBackgroundTask>().dispose();
      windowManagerLogger.info("Player disposed.");
    }
  }
}

class FinampApp extends ConsumerWidget {
  const FinampApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useSystemTheme = ref.watch(finampSettingsProvider.useSystemAccentColor);
    // System Accent has priority over custom Accent
    Color? accentColor = ref.watch(
      useSystemTheme ? finampSettingsProvider.systemAccentColor : finampSettingsProvider.accentColor,
    );
    final themeMode = ref.watch(finampSettingsProvider.themeMode);
    final locale = ref.watch(finampSettingsProvider.locale);
    final transitionBuilder = MediaQuery.disableAnimationsOf(context)
        ? PageTransitionsTheme(
            // Disable page transitions on all platforms if [disableAnimations] is true, otherwise use default transitions
            builders: TargetPlatform.values.fold(
              <TargetPlatform, PageTransitionsBuilder>{},
              (previousValue, element) => previousValue..[element] = const NoTransitionPageTransitionsBuilder(),
            ),
          )
        : null;
    return MaterialApp(
      title: "Finamp",
      routes: {
        SplashScreen.routeName: (context) => const SplashScreen(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        ViewSelector.routeName: (context) => const ViewSelector(),
        MusicScreen.routeName: (context) => const MusicScreen(),
        AlbumScreen.routeName: (context) => const AlbumScreen(),
        ArtistScreen.routeName: (context) => const ArtistScreen(),
        GenreScreen.routeName: (context) => const GenreScreen(),
        PlayerScreen.routeName: (context) => const PlayerScreen(key: ValueKey(PlayerScreen.routeName)),
        DownloadsScreen.routeName: (context) => const DownloadsScreen(),
        ActiveDownloadsScreen.routeName: (context) => const ActiveDownloadsScreen(),
        PlaybackHistoryScreen.routeName: (context) => const PlaybackHistoryScreen(),
        LogsScreen.routeName: (context) => const LogsScreen(),
        QueueRestoreScreen.routeName: (context) => const QueueRestoreScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        TranscodingSettingsScreen.routeName: (context) => const TranscodingSettingsScreen(),
        DownloadsLocationScreen.routeName: (context) => const DownloadsLocationScreen(),
        DownloadsSettingsScreen.routeName: (context) => const DownloadsSettingsScreen(),
        AddDownloadLocationScreen.routeName: (context) => const AddDownloadLocationScreen(),
        PlaybackReportingSettingsScreen.routeName: (context) => const PlaybackReportingSettingsScreen(),
        AudioServiceSettingsScreen.routeName: (context) => const AudioServiceSettingsScreen(),
        VolumeNormalizationSettingsScreen.routeName: (context) => const VolumeNormalizationSettingsScreen(),
        InteractionSettingsScreen.routeName: (context) => const InteractionSettingsScreen(),
        TabsSettingsScreen.routeName: (context) => const TabsSettingsScreen(),
        LayoutSettingsScreen.routeName: (context) => const LayoutSettingsScreen(),
        CustomizationSettingsScreen.routeName: (context) => const CustomizationSettingsScreen(),
        PlayerSettingsScreen.routeName: (context) => const PlayerSettingsScreen(),
        LyricsSettingsScreen.routeName: (context) => const LyricsSettingsScreen(),
        LanguageSelectionScreen.routeName: (context) => const LanguageSelectionScreen(),
        AlbumSettingsScreen.routeName: (context) => const AlbumSettingsScreen(),
        ArtistSettingsScreen.routeName: (context) => const ArtistSettingsScreen(),
        GenreSettingsScreen.routeName: (context) => const GenreSettingsScreen(),
        NetworkSettingsScreen.routeName: (context) => const NetworkSettingsScreen(),
        AccessibilitySettingsScreen.routeName: (context) => const AccessibilitySettingsScreen(),
        PlaylistEditScreen.routeName: (context) =>
            PlaylistEditScreen(playlist: ModalRoute.settingsOf(context)!.arguments as BaseItemDto),
      },
      initialRoute: SplashScreen.routeName,
      navigatorObservers: [SplitScreenNavigatorObserver(), KeepScreenOnObserver()],
      builder: (BuildContext context, Widget? widget) {
        return GlobalShortcutManager(child: buildPlayerSplitScreenScaffold(context, widget));
      },
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: getColorScheme(accentColor, Brightness.light),
        appBarTheme: const AppBarThemeData(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          //TODO get rid of floating action buttons and re-enable the floating behavior and insetPadding
          // behavior: SnackBarBehavior.floating,
          elevation: 10.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
          // insetPadding: EdgeInsets.symmetric(
          //   horizontal: 12.0,
          //   vertical: 0.0,
          // ),
          dismissDirection: DismissDirection.horizontal,
        ),
        pageTransitionsTheme: transitionBuilder,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: getColorScheme(accentColor, Brightness.dark),
        snackBarTheme: const SnackBarThemeData(
          //TODO get rid of floating action buttons and re-enable the floating behavior and insetPadding
          // behavior: SnackBarBehavior.floating,
          elevation: 10.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
          // insetPadding: EdgeInsets.symmetric(
          //   horizontal: 12.0,
          //   vertical: 0.0,
          // ),
          dismissDirection: DismissDirection.horizontal,
        ),
        pageTransitionsTheme: transitionBuilder,
      ),
      scrollBehavior: FinampScrollBehavior(),
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // We awkwardly put English as the first supported locale so
      // that basicLocaleListResolution falls back to it instead of
      // the first language in supportedLocales (Arabic as of writing)
      localeListResolutionCallback: (locales, supportedLocales) =>
          basicLocaleListResolution(locales, [const Locale("en")].followedBy(supportedLocales)),
      locale: locale,
      scaffoldMessengerKey: GlobalSnackbar.materialAppScaffoldKey,
      navigatorKey: GlobalSnackbar.materialAppNavigatorKey,
    );
  }
}

class FinampErrorApp extends StatelessWidget {
  const FinampErrorApp({super.key, required this.error, this.trace});

  final dynamic error;
  final StackTrace? trace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Finamp",
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(brightness: Brightness.light, colorScheme: lightColorScheme),
      darkTheme: ThemeData(brightness: Brightness.dark, colorScheme: darkColorScheme),
      supportedLocales: AppLocalizations.supportedLocales,
      home: ErrorScreen(error: error, trace: trace),
      scaffoldMessengerKey: GlobalSnackbar.materialAppScaffoldKey,
      navigatorKey: GlobalSnackbar.materialAppNavigatorKey,
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, this.error, this.trace});

  final dynamic error;
  final StackTrace? trace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(tag: "finamp_logo", child: SvgPicture.asset('images/finamp_cropped.svg', width: 75, height: 75)),
              const SizedBox(height: 16.0),
              Text.rich(
                TextSpan(
                  text: AppLocalizations.of(context)!.startupErrorTitle,
                  style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(
                      text: "\n\n${error.toString()}",
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: "monospace",
                        color: Colors.red,
                      ),
                    ),
                    if (kDebugMode)
                      WidgetSpan(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8.0,
                            children: [
                              SimpleButton(
                                text: 'Delete FinampSettings',
                                icon: Icons.delete,
                                onPressed: () async {
                                  final dir = (Platform.isAndroid || Platform.isIOS)
                                      ? await getApplicationDocumentsDirectory()
                                      : await getApplicationSupportDirectory();

                                  await Hive.deleteBoxFromDisk("FinampSettings", path: dir.path);
                                  Gaimon.success();
                                },
                              ),
                              SimpleButton(
                                text: 'Delete Stored Queues',
                                icon: Icons.delete,
                                onPressed: () async {
                                  final dir = (Platform.isAndroid || Platform.isIOS)
                                      ? await getApplicationDocumentsDirectory()
                                      : await getApplicationSupportDirectory();

                                  await Hive.deleteBoxFromDisk("Queues", path: dir.path);
                                  Gaimon.success();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    TextSpan(
                      text: "\n\n${AppLocalizations.of(context)!.startupErrorCallToAction}",
                      style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: "\n\n${AppLocalizations.of(context)!.startupErrorWorkaround}",
                      style: const TextStyle(fontSize: 10.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CTAMedium(
                    text: AppLocalizations.of(context)!.exportLogs,
                    icon: TablerIcons.file_download,
                    onPressed: () async {
                      final finampLogsHelper = GetIt.instance<FinampLogsHelper>();
                      await finampLogsHelper.exportLogs();
                    },
                  ),
                ],
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [ShareLogsButton(), CopyLogsButton()]),
              SizedBox(height: 10.0),
              if (trace != null)
                Text.rich(
                  TextSpan(
                    text: trace.toString(),
                    style: const TextStyle(fontSize: 10.0, fontFamily: "monospace"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Show scrollbars on all vertically scrolling widgets by default
class FinampScrollBehavior extends MaterialScrollBehavior {
  const FinampScrollBehavior({this.interactive, this.scrollbars = true});

  // If interactive is null, platform default will be used
  final bool? interactive;
  final bool scrollbars;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (!scrollbars) {
      return child;
    }
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        assert(details.controller != null);
        return Scrollbar(controller: details.controller, interactive: interactive, child: child);
    }
  }
}

class NoTransitionPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition that doesn't animate anything.
  const NoTransitionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double>? secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class FinampProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    GlobalSnackbar.error(error);
  }
}
