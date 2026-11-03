import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/finamp_settings_helper.dart';

class FastScrollSelector extends ConsumerWidget {
  const FastScrollSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.showFastScroller),
      subtitle: Text(AppLocalizations.of(context)!.showFastScrollerSubtitle),
      value: ref.watch(finampSettingsProvider.showFastScroller),
      onChanged: (value) => FinampSetters.setShowFastScroller(value),
    );
  }
}
