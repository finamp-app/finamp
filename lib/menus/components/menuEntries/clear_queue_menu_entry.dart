import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:window_manager/window_manager.dart';

class ClearQueueMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const ClearQueueMenuEntry({super.key, required this.baseItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return MenuEntry(
      icon: TablerIcons.clear_all,
      title: AppLocalizations.of(context)!.stopAndClearQueue,
      onTap: () async {
        if (context.mounted) Navigator.pop(context);
        await withRadioLock(() async {
          await queueService.stopAndClearQueue();
        });
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await WindowManager.instance.setTitle("Finamp");
        }
      },
    );
  }

  @override
  bool get isVisible => true;
}
