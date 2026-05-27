import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/finamp_settings_helper.dart';

class OfflineModeStatusLabel extends ConsumerWidget {
  const OfflineModeStatusLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AutoOfflineOption automation = ref.watch(finampSettingsProvider.autoOffline);

    if (automation == AutoOfflineOption.disabled) {
      return SizedBox.shrink();
    }
    bool override = !ref.watch(finampSettingsProvider.autoOfflineListenerActive);
    if (!override) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
          tileColor: ColorScheme.of(context).tertiary.withOpacity(0.2),
          autofocus: false,
          title: Text(AppLocalizations.of(context)!.automaticOfflineModeOverrideActiveTitle),
          subtitle: Text(AppLocalizations.of(context)!.automaticOfflineModeOverrideActiveSubtitle),
          onTap: () {
            FinampSetters.setAutoOfflineListenerActive(true);
          },
        ),
      ),
    );
  }
}
