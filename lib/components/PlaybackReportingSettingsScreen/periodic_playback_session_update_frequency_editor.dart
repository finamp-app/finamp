import 'package:finamp/components/SettingsScreen/subtitle_with_more_info_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../services/finamp_settings_helper.dart';

class PeriodicPlaybackSessionUpdateFrequencyEditor extends StatefulWidget {
  const PeriodicPlaybackSessionUpdateFrequencyEditor({super.key});

  @override
  State<PeriodicPlaybackSessionUpdateFrequencyEditor> createState() =>
      _PeriodicPlaybackSessionUpdateFrequencyEditorState();
}

class _PeriodicPlaybackSessionUpdateFrequencyEditorState extends State<PeriodicPlaybackSessionUpdateFrequencyEditor> {
  final _controller = TextEditingController(
    text: FinampSettingsHelper.finampSettings.periodicPlaybackSessionUpdateFrequencySeconds.toString(),
  );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.periodicPlaybackSessionUpdateFrequency),
      subtitle: SubtitleWithMoreInfoDialog(
        subtitle: AppLocalizations.of(context)!.periodicPlaybackSessionUpdateFrequencySubtitle,
        dialogTitle: AppLocalizations.of(context)!.periodicPlaybackSessionUpdateFrequency,
        dialogContent: AppLocalizations.of(context)!.periodicPlaybackSessionUpdateFrequencyDetails,
      ),
      trailing: SizedBox(
        width: 50 * MediaQuery.textScaleFactorOf(context),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final valueInt = int.tryParse(value);

            if (valueInt != null) {
              FinampSetters.setPeriodicPlaybackSessionUpdateFrequencySeconds(valueInt);
            }
          },
        ),
      ),
    );
  }
}
