import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/VolumeNormalizationSettingsScreen/volume_normalization_ios_base_gain_editor.dart';
import '../components/VolumeNormalizationSettingsScreen/volume_normalization_mode_selector.dart';
import '../components/VolumeNormalizationSettingsScreen/volume_normalization_switch.dart';

class VolumeNormalizationSettingsScreen extends ConsumerWidget {
  const VolumeNormalizationSettingsScreen({super.key});
  static const routeName = "/settings/volume-normalization";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.volumeNormalizationSettingsTitle),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, () {
            FinampSettingsHelper.resetNormalizationSettings();
          }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          const VolumeNormalizationSwitch(),
          if (Platform.isAndroid) const UseAndroidGainEffectSwitch(),
          if (!Platform.isAndroid || !ref.watch(finampSettingsProvider.useAndroidGainEffect))
            const VolumeNormalizationIOSBaseGainEditor(),
          const VolumeNormalizationModeSelector(),
        ],
      ),
    );
  }
}

class UseAndroidGainEffectSwitch extends ConsumerWidget {
  const UseAndroidGainEffectSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.useAndroidGainEffectTitle),
      subtitle: Text(AppLocalizations.of(context)!.useAndroidGainEffectSubtitle),
      value: ref.watch(finampSettingsProvider.useAndroidGainEffect),
      onChanged: FinampSetters.setUseAndroidGainEffect,
    );
  }
}
