import 'package:flutter_test/flutter_test.dart';
import 'package:tief_test_harness/tief_test_harness.dart';

import '../helpers.dart';
import 'main_harness_test.th.dart';
import 'screenshot_manager_provider.dart';

class ScreenshotConfig {
  final String server;
  final String user;
  final String password;
  final Set<String> harnesses;

  ScreenshotConfig({required this.server, required this.user, required this.password, this.harnesses = const {}});

  ScreenshotConfig.fromEnvironment()
    : server = const String.fromEnvironment("JELLYFIN_SERVER", defaultValue: ""),
      user = const String.fromEnvironment("JELLYFIN_USER", defaultValue: ""),
      password = const String.fromEnvironment("JELLYFIN_PASSWORD", defaultValue: ""),
      harnesses = const String.fromEnvironment(
        "HARNESSES",
        defaultValue: "",
      ).split(",").where((e) => e.isNotEmpty).toSet();
}

late final ScreenshotConfig screenshotConfig;

@GenerateHarnessRegistry("main")
Future<void> main() async {
  screenshotConfig = ScreenshotConfig.fromEnvironment();

  final harnessRegistry = MainHarnessRegistry();

  final harnessNames = screenshotConfig.harnesses;
  if (harnessNames.isNotEmpty) {
    harnessRegistry.onlyNamed(harnessNames);
  }

  final harnesses = await harnessRegistry.build();

  final harnessRunner = HarnessRunner(
    harnesses: harnesses,
    appBuilder: ({required child, required locale, providerScopeBuilder}) => child,
  );

  await harnessRunner.run(
    setUp: (binding, ref) async {
      final (mainCompleted, mainErrors) = await initializeApp();

      if (!mainCompleted || mainErrors.isNotEmpty) throw Exception("Main did not complete without errors.");

      ref.read(screenshotManagerStateProvider.notifier).initialize("10.0.2.2", 3824);

      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    },
    tearDown: (binding, ref) async {
      ref.read(screenshotManagerStateProvider)!.dispose();
    },
  );
}
