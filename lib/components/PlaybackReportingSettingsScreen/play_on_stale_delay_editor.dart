import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../services/finamp_settings_helper.dart';

class PlayOnStaleDelayEditor extends StatefulWidget {
  const PlayOnStaleDelayEditor({super.key});

  @override
  State<PlayOnStaleDelayEditor> createState() => _PlayOnStaleDelayEditorState();
}

class _PlayOnStaleDelayEditorState extends State<PlayOnStaleDelayEditor> {
  final _controller = TextEditingController(text: FinampSettingsHelper.finampSettings.playOnStaleDelay.toString());

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.playOnStaleDelay),
      subtitle: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: AppLocalizations.of(context)!.playOnStaleDelaySubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      trailing: SizedBox(
        width: MediaQuery.textScalerOf(context).scale(50),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final valueInt = int.tryParse(value);

            if (valueInt != null) {
              FinampSetters.setPlayOnStaleDelay(valueInt);
            }
          },
        ),
      ),
    );
  }
}
