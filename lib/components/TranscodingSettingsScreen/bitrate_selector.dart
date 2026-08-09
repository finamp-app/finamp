import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/finamp_settings_helper.dart';

class BitrateSelector extends ConsumerStatefulWidget {
  const BitrateSelector({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _BitrateSelectorState();
  }
}

class _BitrateSelectorState extends ConsumerState<BitrateSelector> {
  int currentBitrate = FinampSettingsHelper.finampSettings.transcodeBitrate;

  @override
  Widget build(BuildContext context) {
    bool enabled = ref.watch(finampSettingsProvider.transcodingStreamingFormat).codec != "flac";
    return Column(
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.bitrate),
          subtitle: Text(AppLocalizations.of(context)!.bitrateSubtitle),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              min: 64,
              max: 320,
              value: (currentBitrate / 1000).clamp(64, 320),
              divisions: 8,
              label: AppLocalizations.of(context)!.kiloBitsPerSecondLabel(currentBitrate ~/ 1000),
              onChanged: enabled
                  ? (value) {
                      setState(() {
                        currentBitrate = (value * 1000).toInt();
                      });
                    }
                  : null,
              onChangeEnd: (value) {
                FinampSetters.setTranscodeBitrate((value * 1000).toInt());
              },
              autofocus: false,
              focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
            ),
            Text(
              enabled
                  ? AppLocalizations.of(context)!.kiloBitsPerSecondLabel(currentBitrate ~/ 1000)
                  : AppLocalizations.of(context)!.losslessNoBitrate,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}
