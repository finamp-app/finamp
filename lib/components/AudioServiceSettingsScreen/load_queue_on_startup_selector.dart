import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/finamp_settings_helper.dart';

class LoadQueueOnStartupSelector extends ConsumerWidget {
  const LoadQueueOnStartupSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.autoloadLastQueueOnStartup),
      subtitle: Text(AppLocalizations.of(context)!.autoloadLastQueueOnStartupSubtitle),
      value: ref.watch(finampSettingsProvider.autoloadLastQueueOnStartup),
      onChanged: (value) => FinampSetters.setAutoloadLastQueueOnStartup(value),
    );
  }
}
