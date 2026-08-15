import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/SettingsScreen/finamp_settings_dropdown.dart';
import '../services/finamp_settings_helper.dart';

class AndroidAutoSettingsScreen extends StatelessWidget {
  const AndroidAutoSettingsScreen({super.key});
  static const routeName = "/settings/androidAuto";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.androidAutoSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: const [
          AndroidAutoBrowsingModeDropdown(),
        ],
      ),
    );
  }
}

class AndroidAutoBrowsingModeDropdown extends ConsumerWidget {
  const AndroidAutoBrowsingModeDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentMode = ref.watch(finampSettingsProvider.androidAutoBrowsingMode);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.androidAutoBrowsingModeLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.androidAutoBrowsingModeSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FinampSettingsDropdown<AndroidAutoBrowsingMode>(
            dropdownItems: [
              DropdownMenuEntry(
                value: AndroidAutoBrowsingMode.flat,
                label: l10n.androidAutoBrowsingModeFlat,
              ),
              DropdownMenuEntry(
                value: AndroidAutoBrowsingMode.letterFirst,
                label: l10n.androidAutoBrowsingModeLetterFirst,
              ),
            ],
            selectedValue: currentMode,
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setAndroidAutoBrowsingMode(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
