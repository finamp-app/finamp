import 'dart:io';
import 'package:finamp/components/HomeScreen/finamp_music_screen_header.dart';
import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/screens/quick_settings_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';

class BannerUser extends Fake implements FinampUserHelper {
  @override
  FinampUser? get currentUser => null;
}

class BannerApi extends Fake implements JellyfinApiHelper {}

Future<void> mount(WidgetTester tester, ColorScheme scheme) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  final container = ProviderContainer(overrides: [isDownloadingOrSyncingPollingProvider.overrideWithValue(false)]);
  addTearDown(container.dispose);
  await container.read(finampSettingsProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {QuickSettingsScreen.routeName: (_) => const Scaffold(body: Text('Quick settings destination'))},
        home: DefaultTabController(
          length: 1,
          child: Scaffold(
            body: Builder(
              builder: (context) => FinampMusicScreenHeader(
                sortedTabs: const [ContentType.albums],
                tabController: DefaultTabController.of(context),
                textEditingController: controller,
                isSearching: false,
                refreshTab: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    GetIt.instance.registerSingleton<FinampUserHelper>(BannerUser());
    GetIt.instance.registerSingleton<JellyfinApiHelper>(BannerApi());
    directory = await Directory.systemTemp.createTemp('finamp-banner-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(28)) {
      Hive.registerAdapters();
      Hive.registerAdapter(ThemeModeAdapter());
      Hive.registerAdapter(ColorAdapter());
      Hive.registerAdapter(LocaleAdapter());
    }
    await Hive.openBox<FinampSettings>('FinampSettings', bytes: Uint8List(0));
    final settings = FinampSettings(
      downloadLocations: [],
      downloadLocationsMap: {},
      tabSortBy: {},
      tabSortOrder: {},
      gridImageSize: 160,
      homeScreenImageSize: 160,
      deviceId: 'banner-test',
      isOffline: true,
      enableVibration: false,
      homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
    );
    await Hive.box<FinampSettings>('FinampSettings').put('FinampSettings', settings);
  });
  tearDown(() async {
    await GetIt.instance.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final brightness in Brightness.values) {
    for (final seed in [Colors.blue, const Color(0xff152e85), Colors.orange]) {
      testWidgets('banner remains readable for $brightness / $seed', (tester) async {
        final scheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );
        await mount(tester, scheme);
        final banner = find.text('Check out some commonly changed settings!');
        expect(banner, findsOneWidget);
        final rich = tester.widget<RichText>(find.descendant(of: banner, matching: find.byType(RichText)));
        final foreground = rich.text.style!.color!;
        final background = tester
            .widget<Material>(find.ancestor(of: banner, matching: find.byType(Material)).first)
            .color!;
        final luminances = [foreground.computeLuminance(), background.computeLuminance()]..sort();
        expect((luminances.last + 0.05) / (luminances.first + 0.05), greaterThanOrEqualTo(4.5));
        expect(foreground, scheme.onPrimaryContainer);
      });
    }
  }
  testWidgets('dismissal hides the banner and persists across remount', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    await mount(tester, scheme);
    await tester.tap(find.widgetWithIcon(IconButton, TablerIcons.x));
    await tester.pumpAndSettle();
    expect(FinampSettingsHelper.finampSettings.showQuickActionsBanner, isFalse);
    expect(find.text('Check out some commonly changed settings!'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, scheme);
    expect(find.text('Check out some commonly changed settings!'), findsNothing);
  });
  testWidgets('tapping banner opens Quick Settings and persists dismissal', (tester) async {
    await mount(tester, ColorScheme.fromSeed(seedColor: Colors.blue));
    await tester.tap(find.text('Check out some commonly changed settings!'));
    await tester.pumpAndSettle();
    expect(find.text('Quick settings destination'), findsOneWidget);
    expect(FinampSettingsHelper.finampSettings.showQuickActionsBanner, isFalse);
  });
}
