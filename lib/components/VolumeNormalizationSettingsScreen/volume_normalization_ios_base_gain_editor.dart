import 'package:finamp/components/SettingsScreen/subtitle_with_more_info_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/finamp_settings_helper.dart';

class VolumeNormalizationIOSBaseGainEditor extends ConsumerStatefulWidget {
  const VolumeNormalizationIOSBaseGainEditor({super.key});

  @override
  ConsumerState<VolumeNormalizationIOSBaseGainEditor> createState() => _VolumeNormalizationIOSBaseGainEditorState();
}

class _VolumeNormalizationIOSBaseGainEditorState extends ConsumerState<VolumeNormalizationIOSBaseGainEditor> {
  final _controller = TextEditingController();

  @override
  void initState() {
    ref.listenManual(finampSettingsProvider.volumeNormalizationIOSBaseGain, (_, value) {
      var newText = value.toString();
      if (_controller.text != newText) _controller.text = newText;
    }, fireImmediately: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.volumeNormalizationIOSBaseGainEditorTitle),
      subtitle: SubtitleWithMoreInfoDialog(
        subtitle: AppLocalizations.of(context)!.volumeNormalizationIOSBaseGainEditorSubtitle,
        dialogTitle: AppLocalizations.of(context)!.volumeNormalizationIOSBaseGainEditorTitle,
        dialogContent: AppLocalizations.of(context)!.volumeNormalizationIOSBaseGainEditorDescription,
      ),
      trailing: SizedBox(
        width: 50 * MediaQuery.textScaleFactorOf(context),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (value) {
            final valueDouble = double.tryParse(value);

            if (valueDouble != null) {
              FinampSetters.setVolumeNormalizationIOSBaseGain(valueDouble);
            }
          },
        ),
      ),
    );
  }
}
