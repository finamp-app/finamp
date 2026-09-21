import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';
import 'package:tief_test_harness/tief_test_harness.dart';
import 'package:finamp/main.dart' as app;

import 'screenshot_manager_provider.dart';

ScenarioHarness createHarness() {
  return ScenarioHarness(
    appContent: app.Finamp(integrationTesting: true),
    beforeAll: (binding, ref, harnessName) async {
      // We need to hide the system chrome during integration tests to avoid UI interference.
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    },
    beforeEach: (tester, binding, ref, harnessName, scenarioName) async {
      FinampSetters.setThemeMode(ThemeMode.light);
      await GetIt.instance<QueueService>().stopAndClearQueue();

      final isar = GetIt.instance<Isar>();
      await isar.writeTxn(() async {
        await isar.finampUsers.clear();
      });

      await tester.pumpAndSettle();
    },
    afterEach: (tester, binding, ref, harnessName, scenarioName) async {
      await ref.read(screenshotManagerStateProvider)?.pumpAndScreenshot(scenarioName, tester, binding);
    },
    afterAll: (binding, ref, harnessName) async {
      await ref.read(screenshotManagerStateProvider)?.uploadScreenshots(harnessName);
      ref.read(screenshotManagerStateProvider)?.clear();
    },
  );
}
