import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrossfadeDurationSlider extends ConsumerWidget {
  const CrossfadeDurationSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossfadeDuration = ref.watch(finampSettingsProvider.crossfadeDuration);
    final seconds = crossfadeDuration.inSeconds;

    return ListTile(
      title: Text(AppLocalizations.of(context)!.crossfadeDurationSettingTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.crossfadeDurationSettingSubtitle),
          Slider(
            min: 0,
            max: 15,
            divisions: 15,
            value: seconds.clamp(0, 15).toDouble(),
            label: seconds == 0
                ? AppLocalizations.of(context)!.crossfadeDurationSettingOff
                : AppLocalizations.of(context)!.crossfadeDurationSettingValue(seconds),
            onChanged: (value) {
              FinampSetters.setCrossfadeDuration(Duration(seconds: value.toInt()));
            },
          ),
        ],
      ),
    );
  }
}
