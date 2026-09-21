// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:tief_test_harness/tief_test_harness.dart';
import 'screens/home_screen_harness.dart' as h0;
import 'screens/player_screen_harness.dart' as h1;
import 'screens/splash_screen_harness.dart' as h2;

enum MainHarness {
  homeScreen,
  playerScreen,
  splashScreen;

  String get harnessName => switch (this) {
    MainHarness.homeScreen => 'Home Screen',
    MainHarness.playerScreen => 'Player Screen',
    MainHarness.splashScreen => 'Splash Screen',
  };

  static MainHarness fromHarnessName(String name) =>
      values.firstWhere(
        (harness) => harness.harnessName == name,
        orElse: () => throw ArgumentError.value(
          name,
          'name',
          'No MainHarness with this harness name.',
        ),
      );
}

class MainHarnessRegistry {
  const MainHarnessRegistry() : this._(null);
  const MainHarnessRegistry._(this._selected);

  final Set<MainHarness>? _selected;

  static const Map<MainHarness, Future<ScenarioHarness> Function()> _builders = {
    MainHarness.homeScreen: h0.buildHomeScreenHarness,
    MainHarness.playerScreen: h1.buildPlayerScreenHarness,
    MainHarness.splashScreen: h2.buildSplashScreenHarness,
  };

  /// Restricts a subsequent [build] to just [harnesses].
  MainHarnessRegistry only(Set<MainHarness> harnesses) =>
      MainHarnessRegistry._(harnesses);

  /// Restricts a subsequent [build] to just the harnesses named [names].
  MainHarnessRegistry onlyNamed(Set<String> names) =>
      only(names.map(MainHarness.fromHarnessName).toSet());

  /// Calls every selected builder and awaits the results, keyed by harness name.
  Future<Map<String, ScenarioHarness>> build() async {
    final selected = _selected == null
        ? _builders.entries
        : _builders.entries.where((entry) => _selected.contains(entry.key));

    final resolved = await Future.wait(
      selected.map((entry) async => MapEntry(entry.key.harnessName, await entry.value())),
    );

    return Map.fromEntries(resolved);
  }
}
