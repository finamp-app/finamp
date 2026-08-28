import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/SettingsScreen/subtitle_with_more_info_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/metadata_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../extensions/localizations.dart';
import '../../../models/finamp_models.dart';
import '../../../services/finamp_settings_helper.dart';

class PlaybackSpeedControlVisibilityDropdownListTile extends ConsumerWidget {
  const PlaybackSpeedControlVisibilityDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.playbackSpeedControlSetting),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubtitleWithMoreInfoDialog(
            subtitle: AppLocalizations.of(context)!.playbackSpeedControlSettingSubtitle,
            dialogTitle: AppLocalizations.of(context)!.playbackSpeedControlSetting,
            dialogContent: AppLocalizations.of(context)!.playbackSpeedControlSettingDescription(
              MetadataProvider.speedControlLongTrackDuration.inMinutes,
              MetadataProvider.speedControlLongAlbumDuration.inHours,
              MetadataProvider.speedControlGenres.join(", "),
            ),
          ),
          FinampSettingsDropdown<PlaybackSpeedVisibility>(
            dropdownItems: PlaybackSpeedVisibility.values
                .map(
                  (e) => DropdownMenuEntry<PlaybackSpeedVisibility>(value: e, label: e.toLocalisedString(context.l10n)),
                )
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.playbackSpeedVisibility),
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setPlaybackSpeedVisibility(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
