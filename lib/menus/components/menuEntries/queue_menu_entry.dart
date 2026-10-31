import 'package:finamp/components/PlayerScreen/queue_list.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class QueueMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  const QueueMenuEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuEntry(
      icon: TablerIcons.playlist,
      title: AppLocalizations.of(context)!.queue,
      onTap: () async {
        final navigator = Navigator.of(context);
        navigator.pop();
        await showQueueBottomSheet(navigator.context, ref);
      },
    );
  }

  @override
  bool get isVisible => true;
}
