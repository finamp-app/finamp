import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/menus/output_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Keeps output controls reachable when the player's bottom actions are hidden.
class OutputMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  const OutputMenuEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuEntry(
      icon: TablerIcons.device_speaker,
      title: AppLocalizations.of(context)!.outputMenuButtonTitle,
      onTap: () async {
        final navigator = Navigator.of(context);
        navigator.pop();
        // The entry's sheet is closing; use the surviving navigator's context.
        await showOutputMenu(context: navigator.context);
      },
    );
  }

  @override
  bool get isVisible => true;
}
