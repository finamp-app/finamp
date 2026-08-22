import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../services/finamp_settings_helper.dart';

class PlayOnReconnectionDelayEditor extends StatefulWidget {
  const PlayOnReconnectionDelayEditor({super.key});

  @override
  State<PlayOnReconnectionDelayEditor> createState() => _PlayOnReconnectionDelayEditorState();
}

class _PlayOnReconnectionDelayEditorState extends State<PlayOnReconnectionDelayEditor> {
  final _controller = TextEditingController(
    text: FinampSettingsHelper.finampSettings.playOnReconnectionDelay.toString(),
  );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.playOnReconnectionDelay),
      subtitle: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: AppLocalizations.of(context)!.playOnReconnectionDelaySubtitle,
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
              FinampSetters.setPlayOnReconnectionDelay(valueInt);
            }
          },
        ),
      ),
    );
  }
}
