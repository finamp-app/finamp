import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});
  static const routeName = "/settings/accessibility";
  @override
  ConsumerState<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends ConsumerState<AccessibilitySettingsScreen> {
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
        children: [
          UseHighContrastColorsToggle(),
          DisableGestureSelector(),
          DisableVibrationSelector(),
          TextScaleOverrideEnableSelector(),
          if (ref.watch(finampSettingsProvider.textScaleOverride) != null) TextScaleOverrideSelector(),
        ],
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

class TextScaleOverrideEnableSelector extends ConsumerWidget {
  const TextScaleOverrideEnableSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.enableTextScaleOverride),
      subtitle: Text(AppLocalizations.of(context)!.enableTextScaleOverrideSubtitle),
      value: ref.watch(finampSettingsProvider.textScaleOverride) != null,
      onChanged: (value) => FinampSetters.setTextScaleOverride(value ? 1.0 : null),
    );
  }
}

class TextScaleOverrideSelector extends ConsumerWidget {
  const TextScaleOverrideSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = "${(ref.watch(finampSettingsProvider.textScaleOverride)! * 100.0).toInt()}%";
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Slider(
            min: 0.8,
            max: 2.0,
            value: ref.watch(finampSettingsProvider.textScaleOverride)!.clamp(0.8, 2.0).toDouble(),
            label: label,
            onChanged: (value) => FinampSetters.setTextScaleOverride(value),
            autofocus: false,
            focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
          ),
        ],
      ),
    );
  }
}
