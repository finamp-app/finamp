import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/SettingsScreen/subtitle_with_more_info_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension LocalizedName on VolumeNormalizationMode {
  String toLocalizedString(BuildContext context) => _humanReadableLocalizedName(this, context);

  String _humanReadableLocalizedName(VolumeNormalizationMode themeMode, BuildContext context) {
    switch (themeMode) {
      case VolumeNormalizationMode.hybrid:
        return AppLocalizations.of(context)!.volumeNormalizationModeHybrid;
      case VolumeNormalizationMode.trackBased:
        return AppLocalizations.of(context)!.volumeNormalizationModeTrackBased;
      case VolumeNormalizationMode.albumBased:
        return AppLocalizations.of(context)!.volumeNormalizationModeAlbumBased;
      case VolumeNormalizationMode.albumOnly:
        return AppLocalizations.of(context)!.volumeNormalizationModeAlbumOnly;
    }
  }
}

class VolumeNormalizationModeSelector extends ConsumerWidget {
  const VolumeNormalizationModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeNormalizationMode = ref.watch(finampSettingsProvider.volumeNormalizationMode);
    return ListTile(
      title: Text(AppLocalizations.of(context)!.volumeNormalizationModeSelectorTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubtitleWithMoreInfoDialog(
            subtitle: AppLocalizations.of(context)!.volumeNormalizationModeSelectorSubtitle,
            dialogTitle: AppLocalizations.of(context)!.volumeNormalizationModeSelectorTitle,
            dialogContent: AppLocalizations.of(context)!.volumeNormalizationModeSelectorDescription,
          ),
          FinampSettingsDropdown<VolumeNormalizationMode>(
            dropdownItems: VolumeNormalizationMode.values
                .map((e) => DropdownMenuEntry<VolumeNormalizationMode>(value: e, label: e.toLocalizedString(context)))
                .toList(),
            selectedValue: volumeNormalizationMode,
            onSelected: FinampSetters.setVolumeNormalizationMode.ifNonNull,
          ),
        ],
      ),
    );
  }
}
