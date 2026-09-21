import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tief_test_harness/tief_test_harness.dart';

import '../harness_creation.dart';

@RegisterHarness("main", name: "Splash Screen")
Future<ScenarioHarness> buildSplashScreenHarness() async {
  final harness = createHarness();

  harness.addScenario(Scenario(name: "Main"));

  harness.addScenario(
    Scenario(
      name: "Dark Mode",
      testCallback: (tester, binding) async {
        FinampSetters.setThemeMode(ThemeMode.dark);
        await tester.pumpAndSettle();
      },
    ),
  );

  return harness;
}
