import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/screens/layout_settings_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});
  static const routeName = "/settings/accessibility";
  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.accessibility),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
            context,
            FinampSettingsHelper.resetAccessibilitySettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: const [UseHighContrastColorsToggle(), DisableGestureSelector(), DisableVibrationSelector()],
      ),
    );
  }
}

class UseHighContrastColorsToggle extends ConsumerWidget {
  const UseHighContrastColorsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.useHighContrastColorsTitle),
      subtitle: Text(AppLocalizations.of(context)!.useHighContrastColorsSubtitle),
      value: ref.watch(finampSettingsProvider.useHighContrastColors),
      onChanged: FinampSetters.setUseHighContrastColors,
    );
  }
}

class DisableGestureSelector extends ConsumerWidget {
  const DisableGestureSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.disableGesture),
      subtitle: Text(AppLocalizations.of(context)!.disableGestureSubtitle),
      value: ref.watch(finampSettingsProvider.disableGesture),
      onChanged: (value) => FinampSetters.setDisableGesture(value),
    );
  }
}

class DisableVibrationSelector extends ConsumerWidget {
  const DisableVibrationSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.enableVibration),
      subtitle: Text(AppLocalizations.of(context)!.enableVibrationSubtitle),
      value: ref.watch(finampSettingsProvider.enableVibration),
      onChanged: (value) => FinampSetters.setEnableVibration(value),
    );
  }
}
