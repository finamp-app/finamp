import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension LocalizedName on PreviousTracksPersistenceMode {
  String toLocalizedString(BuildContext context) => _humanReadableLocalizedName(this, context);

  String _humanReadableLocalizedName(PreviousTracksPersistenceMode themeMode, BuildContext context) {
    switch (themeMode) {
      case PreviousTracksPersistenceMode.persistent:
        return AppLocalizations.of(context)!.previousTracksPersistenceModePersistent;
      case PreviousTracksPersistenceMode.initiallyCollapsed:
        return AppLocalizations.of(context)!.previousTracksPersistenceModeCollapsed;
      case PreviousTracksPersistenceMode.initiallyExpanded:
        return AppLocalizations.of(context)!.previousTracksPersistenceModeExpanded;
    }
  }
}

class PreviousTracksPersistenceModeSelector extends ConsumerWidget {
  const PreviousTracksPersistenceModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previousTracksPersistenceMode = ref.watch(finampSettingsProvider.previousTracksPersistenceMode);
    return ListTile(
      title: Text(AppLocalizations.of(context)!.previousTracksPersistenceModeSelectorTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.previousTracksPersistenceModeSelectorSubtitle),
          FinampSettingsDropdown<PreviousTracksPersistenceMode>(
            dropdownItems: PreviousTracksPersistenceMode.values
                .map(
                  (e) =>
                      DropdownMenuEntry<PreviousTracksPersistenceMode>(value: e, label: e.toLocalizedString(context)),
                )
                .toList(),
            selectedValue: previousTracksPersistenceMode,
            onSelected: FinampSetters.setPreviousTracksPersistenceMode.ifNonNull,
          ),
        ],
      ),
    );
  }
}
