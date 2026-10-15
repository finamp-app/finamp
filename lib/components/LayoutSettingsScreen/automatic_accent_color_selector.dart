import 'dart:async';
import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutomaticAccentColorSelector extends ConsumerWidget {
  const AutomaticAccentColorSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sysColor = ref.watch(finampSettingsProvider.systemAccentColor);
    final supportsSystemTheme = Platform.isAndroid || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    // Safe to assume that the System does not have Color Theme Support
    if (!supportsSystemTheme) return SizedBox.shrink();

    return ListTile(
      title: Text(AppLocalizations.of(context)!.systemAccentColor),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: EdgeInsets.only(right: 2),
            decoration: BoxDecoration(color: sysColor ?? Colors.transparent, borderRadius: BorderRadius.circular(16)),
          ),
          SizedBox(width: 16),
          Switch.adaptive(
            value: ref.watch(finampSettingsProvider.useSystemAccentColor),
            onChanged: (value) {
              FinampSetters.setUseSystemAccentColor(value);
              unawaited(fetchSystemPalette());
            },
          ),
        ],
      ),
    );
  }
}
