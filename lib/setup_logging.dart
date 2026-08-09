import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/services/censored_log.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'services/environment_metadata.dart';
import 'services/finamp_logs_helper.dart';

Future<void> setupLogging() async {
  GetIt.instance.registerSingleton(FinampLogsHelper());
  final finampLogsHelper = GetIt.instance<FinampLogsHelper>();
  await finampLogsHelper.openLog();

  // Hive isn't open yet, so keep everything for now. applyLogLevel picks up the
  // persisted verboseLogging toggle once settings are available.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((event) {
    // We don't want to print log messages from the Flutter logger since Flutter prints logs by itself
    if (kDebugMode && event.loggerName != "Flutter") {
      debugPrint("[${event.loggerName}/${event.level.name}] ${event.time}: ${event.message}");
    }
    if (kDebugMode && event.loggerName != "Flutter" && event.getStack != null) {
      debugPrintStack(stackTrace: event.getStack);
    }
    // Make sure asserts are extra visible when debugging
    if (kDebugMode && event.object is AssertionError) {
      GlobalSnackbar.message((_) => event.object.toString());
    }
    finampLogsHelper.addLog(event);
  });

  final startupLogger = Logger("Startup");

  // Create and store the Log instance for later use
  final metadata = await EnvironmentMetadata.create(
    fetchServerInfo:
        false, // we can't fetch server info yet, because the user helper isn't set up yet. it's also faster to skip this here
  );
  startupLogger.info("\n${metadata.pretty}");
}

/// Applies the persisted verboseLogging preference. Call once settings are
/// available, since [setupLogging] runs before the Hive box is open.
///
/// Debug builds keep everything. Release builds cap at INFO unless verbose
/// logging is enabled, so the FINE/FINER/FINEST trace doesn't run censoring and
/// a synchronous file write on the main isolate for every line in production.
void applyLogLevel() {
  final verbose = FinampSettingsHelper.finampSettings.verboseLogging;
  Logger.root.level = (kDebugMode || verbose) ? Level.ALL : Level.INFO;
}
