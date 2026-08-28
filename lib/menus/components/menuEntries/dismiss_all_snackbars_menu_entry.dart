import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class DismissAllSnackbarsMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  const DismissAllSnackbarsMenuEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Visibility(
      visible: true,
      child: MenuEntry(
        enabled: true,
        icon: TablerIcons.clear_all,
        title: AppLocalizations.of(context)!.snackbarOptionsMenuClearAllButton,
        onTap: () {
          GlobalSnackbar.dismissAllSnackbars();
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  @override
  bool get isVisible => true;
}
