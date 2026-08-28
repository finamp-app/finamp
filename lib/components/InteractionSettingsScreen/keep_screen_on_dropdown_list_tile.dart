import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../services/finamp_settings_helper.dart';

class KeepScreenOnDropdownListTile extends ConsumerWidget {
  const KeepScreenOnDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.keepScreenOn),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.keepScreenOnSubtitle),
          FinampSettingsDropdown<KeepScreenOnOption>(
            dropdownItems: KeepScreenOnOption.values
                .map((e) => DropdownMenuEntry<KeepScreenOnOption>(value: e, label: e.toLocalisedString(context.l10n)))
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.keepScreenOnOption),
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setKeepScreenOnOption(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
