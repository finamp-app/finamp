import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../services/finamp_settings_helper.dart';

class PlayerScreenMinimumCoverPaddingEditor extends StatefulWidget {
  const PlayerScreenMinimumCoverPaddingEditor({super.key});

  @override
  State<PlayerScreenMinimumCoverPaddingEditor> createState() => _PlayerScreenMinimumCoverPaddingEditorState();
}

class _PlayerScreenMinimumCoverPaddingEditorState extends State<PlayerScreenMinimumCoverPaddingEditor> {
  final _controller = TextEditingController(
    text: FinampSettingsHelper.finampSettings.playerScreenCoverMinimumPadding.toString(),
  );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.playerScreenMinimumCoverPaddingEditorTitle),
      subtitle: Text(AppLocalizations.of(context)!.playerScreenMinimumCoverPaddingEditorSubtitle),
      trailing: SizedBox(
        width: MediaQuery.textScalerOf(context).scale(50),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            final valueDouble = double.tryParse(value);

            if (valueDouble != null) {
              FinampSetters.setPlayerScreenCoverMinimumPadding(valueDouble);
            }
          },
        ),
      ),
    );
  }
}
