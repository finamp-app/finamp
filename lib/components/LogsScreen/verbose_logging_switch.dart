import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/setup_logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/finamp_settings_helper.dart';

/// Toggles verbose logging at runtime and re-applies the level immediately.
class VerboseLoggingSwitch extends ConsumerWidget {
  const VerboseLoggingSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.verboseLogging),
      subtitle: Text(AppLocalizations.of(context)!.verboseLoggingSubtitle),
      value: ref.watch(finampSettingsProvider.verboseLogging),
      onChanged: (value) {
        FinampSetters.setVerboseLogging(value);
        applyLogLevel();
      },
    );
  }
}
