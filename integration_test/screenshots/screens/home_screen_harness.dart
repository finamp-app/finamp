import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tief_test_harness/tief_test_harness.dart';

import '../harness_creation.dart';
import '../jellyfin_helpers.dart';

@RegisterHarness("main", name: "Home Screen")
Future<ScenarioHarness> buildHomeScreenHarness() async {
  final harness = createHarness();

  harness.addScenario(
    Scenario(
      name: "Main",
      testCallback: (tester, binding) async {
        await loginToJellyfin(tester);

        FinampSetters.setShowQuickActionsBanner(false);
      },
    ),
  );

  return harness;
}
