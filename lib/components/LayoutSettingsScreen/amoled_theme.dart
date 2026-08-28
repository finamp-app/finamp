import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AmoledTheme extends ConsumerWidget {
  const AmoledTheme({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.amoledTheme),
      subtitle: Text(AppLocalizations.of(context)!.amoledThemeSubtitle),
      value: ref.watch(finampSettingsProvider.amoledTheme),
      onChanged: (value) => FinampSetters.setAmoledTheme(value),
    );
  }
}
