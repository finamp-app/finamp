import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/extensions/color_extensions.dart';
import 'package:finamp/extensions/string.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccentColorSelector extends ConsumerWidget {
  const AccentColorSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useSystemAccent = ref.watch(finampSettingsProvider.useSystemAccentColor);
    final color = ref.watch(finampSettingsProvider.accentColor);
    final isSet = color != null;

    return ListTile(
      enabled: !useSystemAccent,
      subtitle: useSystemAccent ? Text(AppLocalizations.of(context)!.systemAccentColorHasPriorityInfo) : null,
      title: Text(AppLocalizations.of(context)!.accentColor),
      trailing: GestureDetector(
        onTap: useSystemAccent
            ? null
            : () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) {
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                      child: SingleChildScrollView(child: const AccentColorPopup()),
                    );
                  },
                );
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              color?.toHex() ?? AppLocalizations.of(context)!.defaultWord,
              style: TextStyle(
                // fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 16),
            Container(
              width: 56,
              height: 32,
              margin: EdgeInsets.fromLTRB(0, 0, 2, 0),
              decoration: BoxDecoration(
                color: color ?? Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSet ? Colors.transparent : Theme.of(context).colorScheme.outline, width: 2),
              ),
              child: !isSet ? Icon(Icons.color_lens_outlined, size: 24) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class AccentColorPopup extends ConsumerStatefulWidget {
  const AccentColorPopup({super.key});

  @override
  ConsumerState<AccentColorPopup> createState() => _AccentColorPopupState();
}

class _AccentColorPopupState extends ConsumerState<AccentColorPopup> {
  Color? previewColor = FinampSettingsHelper.finampSettings.accentColor;
  bool amoledTheme = FinampSettingsHelper.finampSettings.amoledTheme;
  late final controller = TextEditingController(text: previewColor?.toHex());

  void updatePreview(String value) => setState(() {
    previewColor = value.toColorOrNull();
  });

  void changeColor(Color color) => setState(() {
    previewColor = color;
    controller.text = color.toHex();
  });

  @override
  Widget build(BuildContext context) {
    final previewTheme = Theme.of(
      context,
    ).withColorScheme(getColorScheme(previewColor, ref.watch(brightnessProvider), amoledTheme));

    return Theme(
      data: previewTheme,
      child: Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.viewPaddingOf(context).bottom + 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          color: previewTheme.colorScheme.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: previewTheme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Center(
              child: Text(
                AppLocalizations.of(context)!.accentColorTitle,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge!.color!,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    filled: true,
                    labelText: AppLocalizations.of(context)!.colorCode,
                    hintText: AppLocalizations.of(context)!.colorCodeHint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                  onChanged: updatePreview,
                ),
                ColorPicker(
                  onColorChanged: changeColor,
                  color: previewColor ?? Theme.of(context).colorScheme.primary,
                  pickersEnabled: {
                    ColorPickerType.wheel: true,
                    ColorPickerType.primary: false,
                    ColorPickerType.accent: false,
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        FinampSetters.setAccentColor(null);
                        Navigator.pop(context);
                      },
                      child: Text(AppLocalizations.of(context)!.useDefaultButton),
                    ),
                    FilledButton(
                      onPressed: previewColor == null
                          ? null
                          : () {
                              final color = controller.text.toColorOrNull();
                              if (color != null) {
                                FinampSetters.setAccentColor(color);
                                Navigator.pop(context);
                              }
                            },
                      child: Text(AppLocalizations.of(context)!.save),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
