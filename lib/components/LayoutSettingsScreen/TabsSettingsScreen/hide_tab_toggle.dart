import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../extensions/localizations.dart';
import '../../../models/finamp_models.dart';
import '../../../services/finamp_settings_helper.dart';

class HideTabToggle extends ConsumerWidget {
  const HideTabToggle({super.key, required this.index, required this.tabContentType});

  final ContentType tabContentType;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableDelayedDragStartListener(
      index: index,
      child: SwitchListTile.adaptive(
        title: Text(tabContentType.toLocalisedString(context.l10n)),
        secondary: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
        value: ref.watch(finampSettingsProvider.showTabs(tabContentType)) ?? false,
        onChanged: (value) => FinampSetters.setShowTabs(tabContentType, value),
      ),
    );
  }
}
