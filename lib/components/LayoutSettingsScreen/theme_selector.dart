import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../extensions/localizations.dart';

extension LocalisedName on ThemeMode {
  String toLocalisedString(BuildContext context) => _humanReadableLocalisedName(this, context);

  String _humanReadableLocalisedName(ThemeMode themeMode, BuildContext context) {
    switch (themeMode) {
      case ThemeMode.system:
        return AppLocalizations.of(context)!.system;
      case ThemeMode.light:
        return AppLocalizations.of(context)!.light;
      case ThemeMode.dark:
        return AppLocalizations.of(context)!.dark;
    }
  }
}

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key, this.verbose = false});

  final bool verbose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(finampSettingsProvider.themeMode);
    return ListTile(
      title: Text(verbose ? context.l10n.themeSettingTitle : context.l10n.theme),
      subtitle: FinampSettingsDropdown<ThemeMode>(
        dropdownItems: ThemeMode.values
            .map(
              (e) => DropdownMenuEntry<ThemeMode>(
                value: e,
                label: e.toLocalisedString(context),
                leadingIcon: switch (e) {
                  ThemeMode.system => const Icon(TablerIcons.brightness_auto),
                  ThemeMode.light => const Icon(TablerIcons.brightness_2),
                  ThemeMode.dark => const Icon(TablerIcons.moon_stars),
                },
              ),
            )
            .toList(),
        selectedValue: themeMode,
        onSelected: (value) {
          if (value != null) {
            FinampSetters.setThemeMode(value);
          }
        },
      ),
    );
  }
}
