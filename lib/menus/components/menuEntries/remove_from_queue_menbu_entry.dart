import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../../extensions/localizations.dart';
import '../../../models/finamp_models.dart';
import '../../../services/queue_service.dart';
import 'menu_entry.dart';

class RemoveFromQueueMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final FinampQueueItem? queueItem;

  const RemoveFromQueueMenuEntry({super.key, this.queueItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Visibility(
      visible: queueItem != null,
      child: MenuEntry(
        icon: TablerIcons.playlist_x,
        title: context.l10n.removeFromQueue,
        onTap: () {
          Navigator.pop(context); // close menu
          GetIt.instance<QueueService>().removeQueueItem(queueItem!);
        },
      ),
    );
  }

  @override
  bool get isVisible => queueItem != null;
}
