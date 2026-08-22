import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/finamp_settings_helper.dart';

class BufferDurationListTile extends ConsumerStatefulWidget {
  const BufferDurationListTile({super.key});

  @override
  ConsumerState<BufferDurationListTile> createState() => _BufferDurationListTileState();
}

class _BufferDurationListTileState extends ConsumerState<BufferDurationListTile> {
  final _controller = TextEditingController();

  @override
  void initState() {
    ref.listenManual(finampSettingsProvider.bufferDurationSeconds, (_, value) {
      var newText = value.toString();
      if (_controller.text != newText) _controller.text = newText;
    }, fireImmediately: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.bufferDuration),
      subtitle: Text(AppLocalizations.of(context)!.bufferDurationSubtitle),
      trailing: SizedBox(
        width: MediaQuery.textScalerOf(context).scale(50),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final valueInt = int.tryParse(value);

            if (valueInt != null && !valueInt.isNegative) {
              FinampSetters.setBufferDuration(Duration(seconds: valueInt));
            }
          },
        ),
      ),
    );
  }
}
