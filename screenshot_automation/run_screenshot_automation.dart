import "dart:async";
import "dart:convert";
import "dart:io";

import "package:args/args.dart";
import "package:yaml/yaml.dart";

void log(String message) {
  print("\x1B[32m[screenshot_automation]\x1B[0m $message");
}

Future<void> main(List<String> args) async {
  final parser = ArgParser(usageLineLength: 80);
  parser.addOption("j-server", abbr: "s", help: "The Jellyfin instance to use for screenshots.");
  parser.addOption("j-user", abbr: "u", help: "The Jellyfin user to use for screenshots.");
  parser.addOption("j-password", abbr: "p", help: "The Jellyfin password to use for screenshots.");
  parser.addMultiOption("harnesses", abbr: "H", help: "The harnesses to run screenshots for.");
  parser.addOption("playlist-id", abbr: "l", help: "The Jellyfin playlist ID to use for screenshots.");
  parser.addFlag("load-config", abbr: "c", help: "Load configuration from the config.yml file.");
  parser.addFlag("help", abbr: "h", hideNegatedUsage: true, help: "Display this help information.");

  final results = parser.parse(args);

  if (results["help"] as bool) {
    print("""\x1B[34mStart and run screenshot automation.\x1B[0m
This script includes running the screenshot server, emulator, and Flutter
integration tests for screenshots.

Usage:""");
    print(parser.usage);
    return;
  }

  String? server = results["j-server"] as String?;
  String? user = results["j-user"] as String?;
  String? password = results["j-password"] as String?;
  String? playlistId = results["playlist-id"] as String?;
  List<String>? harnesses = results["harnesses"] as List<String>?;

  if (results["load-config"] as bool) {
    log("Loading configuration from config.yml...");
    final config = File("screenshot_automation/config.yml").readAsStringSync();

    final yaml = loadYaml(config);
    server ??= yaml["server"] as String?;
    user ??= yaml["user"] as String?;
    password ??= yaml["password"] as String?;
    harnesses ??= (yaml["harnesses"] as List<dynamic>?)?.cast<String>();
    playlistId ??= yaml["playlistId"] as String?;
  }

  log("Starting emulator...");
  final emulatorProcess = await Process.start("emulator", ["@finampemu"]);

  log("Starting screenshot server...");
  final screenshotServerProcess = await Process.start("dart", ["run", "tief_screen:screenshot_server"]);

  ProcessSignal.sigint.watch().listen((signal) {
    log("Received SIGINT, terminating processes.");
    screenshotServerProcess.kill();
    emulatorProcess.kill();
    exit(-1);
  });

  final adbWaitForDeviceProcess = await Process.start("adb", ["wait-for-device"]);
  await adbWaitForDeviceProcess.exitCode;

  // We have to spin wait until the screenshot server and emulator are fully started before running the Flutter tests.
  while (true) {
    log("Waiting for screenshot server and emulator to be ready...");
    sleep(Duration(milliseconds: 500));

    final screenshotServerHealthy = await checkScreenshotServerHealth();
    final emulatorLoaded = await checkEmulatorLoaded();

    if (screenshotServerHealthy && emulatorLoaded) break;
  }

  log("Screenshot server and emulator are ready.");

  final flutterTestProcess = await Process.start("flutter", [
    "test",
    "integration_test/screenshots",
    "--dart-define",
    "JELLYFIN_SERVER=$server",
    "--dart-define",
    "JELLYFIN_USER=$user",
    "--dart-define",
    "JELLYFIN_PASSWORD=$password",
    "--dart-define",
    "JELLYFIN_PLAYLIST_ID=$playlistId",
    if (harnesses != null) ...["--dart-define", "HARNESS=${harnesses.join(",")}"],
  ]);
  await stdout.addStream(flutterTestProcess.stdout);
  await stderr.addStream(flutterTestProcess.stderr);

  ProcessSignal.sigint.watch().listen((signal) {
    log("Received SIGINT, terminating processes.");
    flutterTestProcess.kill();
    exit(-1);
  });

  final flutterTestExitCode = await flutterTestProcess.exitCode;
  log("Flutter test exited with code $flutterTestExitCode");

  log("Screenshot server and emulator processes are being terminated.");
  screenshotServerProcess.kill();
  log("Screenshot server process terminated.");
  emulatorProcess.kill();
  log("Emulator process terminated.");

  log("All processes terminatored. Screenshots saved at screenshots/");

  exit(flutterTestExitCode);
}

Future<bool> checkScreenshotServerHealth() async {
  final req = await HttpClient().get("localhost", 3824, "/health");
  final res = await req.close();

  return res.statusCode == 200;
}

Future<bool> checkEmulatorLoaded() async {
  final emulatorStatusProcess = await Process.start("adb", ["shell", "getprop", "sys.boot_completed"]);
  final emulatorStatusExitCode = await emulatorStatusProcess.stdout
      .transform(utf8.decoder)
      .join()
      .then((output) => int.tryParse(output.trim()) ?? -1);

  return emulatorStatusExitCode == 1;
}
