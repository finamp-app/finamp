import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/SettingsScreen/subtitle_with_more_info_dialog.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finamp_models.dart';
import '../../services/finamp_settings_helper.dart';

class AutoOfflineSelector extends ConsumerWidget {
  const AutoOfflineSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AutoOfflineOption option = ref.watch(finampSettingsProvider.autoOffline);

    return ListTile(
      title: Text(AppLocalizations.of(context)!.autoOfflineSettingTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubtitleWithMoreInfoDialog(
            subtitle: AppLocalizations.of(context)!.autoOfflineSettingSubtitle,
            dialogTitle: AppLocalizations.of(context)!.autoOfflineSettingTitle,
            dialogContent: AppLocalizations.of(context)!.autoOfflineSettingDescription(
              AppLocalizations.of(context)!.autoOfflineOptionOff,
              AppLocalizations.of(context)!.autoOfflineOptionNetwork,
              AppLocalizations.of(context)!.autoOfflineOptionDisconnected,
              AppLocalizations.of(context)!.autoOfflineOptionUnreachable,
            ),
          ),
          FinampSettingsDropdown<AutoOfflineOption>(
            dropdownItems: AutoOfflineOption.values
                .map((e) => DropdownMenuEntry<AutoOfflineOption>(value: e, label: e.toLocalisedString(context)))
                .toList(),
            selectedValue: option,
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setAutoOffline(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
