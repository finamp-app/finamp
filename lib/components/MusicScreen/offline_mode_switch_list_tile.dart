import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class OfflineModeSwitchListTile extends ConsumerWidget {
  const OfflineModeSwitchListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AutoOfflineOption automation = ref.watch(finampSettingsProvider.autoOffline);
    bool overrideActive = !ref.watch(finampSettingsProvider.autoOfflineListenerActive);
    bool reevaluating = ref.watch(autoOfflineStatusProvider) > 0;

    IconData getCurrentIcon() {
      if (automation == AutoOfflineOption.disabled) {
        return TablerIcons.cloud_off;
      } else if (overrideActive) {
        return TablerIcons.robot_off;
      } else if (reevaluating) {
        return Icons.sync_sharp;
      } else {
        return TablerIcons.robot;
      }
    }

    final isOffline = ref.watch(finampSettingsProvider.isOffline);

    void onChanged(bool value) {
      AutoOfflineOption automationStatus = FinampSettingsHelper.finampSettings.autoOffline;

      if (automationStatus != AutoOfflineOption.disabled) {
        // Pause Automation
        FinampSetters.setAutoOfflineListenerActive(false);
      }
      FinampSetters.setIsOffline(value);
      GetIt.instance<MusicPlayerBackgroundTask>().refreshPlaybackStateAndMediaNotification();
    }

    return ToggleableListTile(
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),
        child: Icon(getCurrentIcon(), size: 36.0),
      ),
      title: isOffline ? AppLocalizations.of(context)!.offlineMode : AppLocalizations.of(context)!.offlineMode,
      trailing: Switch.adaptive(
        value: isOffline,
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: -8.0),
      ),
      state: isOffline,
      onToggle: (bool currentState) async => onChanged(!currentState),
    );
  }
}
