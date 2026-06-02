import 'dart:async';

import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/queue_restore_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';
import '../MusicScreen/item_wrapper.dart';

class QueueRestoreTile extends ConsumerWidget {
  const QueueRestoreTile({super.key, required this.info});

  final FinampStorableQueueInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();
    int remainingTracks = info.trackCount - info.previousTracks.length;

    BaseItemDto? track = info.currentTrack == null ? null : ref.watch(itemByIdProvider(info.currentTrack!)).valueOrNull;

    QueueItemSource source = info.source;
    if (source.wantsItem) {
      // BaseItemId uses String equals, the linter is mistaken.
      // ignore: provider_parameters
      final sourceItem = ref.watch(itemByIdProvider(BaseItemId(source.id))).value;
      if (sourceItem != null) {
        source = source.withItem(sourceItem);
      }
    }

    return ListTileTheme(
      // Do not pad between components.  leading/trailing widgets will handle spacing.
      horizontalTitleGap: 0,
      // Shrink trailing padding from 24 to 16
      contentPadding: const EdgeInsetsDirectional.only(start: 16.0, end: 16.0),
      child: ListTile(
        // Prevent undersized album images on desktop
        visualDensity: VisualDensity.standard,
        title: Text(source.name.getLocalized(context.l10n)),
        titleAlignment: ListTileTitleAlignment.center,
        leading: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: AlbumImage(item: track),
        ),
        isThreeLine: true,
        //dense: true,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.queueRestoreTitle(DateTime.fromMillisecondsSinceEpoch(info.creation)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ...((track?.name == null)
                ? <Text>[]
                : [
                    // exclude subtitle line 1 if track name is null
                    Text(
                      AppLocalizations.of(context)!.queueRestoreSubtitle1(track!.name!),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            Text(
              AppLocalizations.of(context)!.queueRestoreSubtitle2(info.trackCount, remainingTracks),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        // TODO add right click handler
        onTap: () => showQueueRestoreMenu(context: context, queueInfo: info),
        onLongPress: () => showQueueRestoreMenu(context: context, queueInfo: info),
        trailing: IconButton(
          icon: const Icon(TablerIcons.restore),
          onPressed: () {
            queueService.archiveSavedQueue();
            unawaited(queueService.loadSavedQueue(info).catchError(GlobalSnackbar.error));
            Navigator.of(context).popUntil((route) => route.isFirst && !route.willHandlePopInternally);
          },
        ),
      ),
    );
  }
}
