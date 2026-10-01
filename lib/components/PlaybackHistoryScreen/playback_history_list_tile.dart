import 'dart:async';

import 'package:finamp/components/favorite_button.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:flutter/material.dart' hide ReorderableList;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/jellyfin_models.dart' as jellyfin_models;
import '../../services/process_artist.dart';
import '../../services/theme_provider.dart';
import '../album_image.dart';

class PlaybackHistoryListTile extends ConsumerStatefulWidget {
  const PlaybackHistoryListTile({
    super.key,
    required this.actualIndex,
    required this.item,
    required this.audioServiceHelper,
    required this.onTap,
  });

  final int actualIndex;
  final FinampHistoryItem item;
  final AudioServiceHelper audioServiceHelper;
  final void Function() onTap;

  @override
  ConsumerState<PlaybackHistoryListTile> createState() => _PlaybackHistoryListTileState();
}

class _PlaybackHistoryListTileState extends ConsumerState<PlaybackHistoryListTile> {
  @override
  Widget build(BuildContext context) {
    final baseItem = jellyfin_models.BaseItemDto.fromJson(
      widget.item.item.item.extras!["itemJson"] as Map<String, dynamic>,
    );

    void menuCallback() async {
      unawaited(Feedback.forLongPress(context));
      await showModalTrackMenu(context: context, item: baseItem);
    }

    return GestureDetector(
      onTapDown: (_) {
        // Begin precalculating theme for song menu
        ref.listenManual(finampThemeProvider(ThemeInfo(baseItem)), (_, _) {});
      },
      onLongPressStart: (details) => menuCallback(),
      onSecondaryTapDown: (details) => menuCallback(),
      child: Card(
        margin: const EdgeInsets.all(0.0),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: ListTile(
          visualDensity: VisualDensity.standard,
          minVerticalPadding: 0.0,
          horizontalTitleGap: 10.0,
          contentPadding: const EdgeInsets.only(right: 4.0),
          leading: AlbumImage(item: baseItem),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(0.0),
                child: Text(widget.item.item.item.title, overflow: TextOverflow.ellipsis),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  processArtist(widget.item.item.item.artist, context),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium!.color!,
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    overflow: TextOverflow.ellipsis,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // subtitle: Container(
          //   alignment: Alignment.centerLeft,
          //   height: 40.5, // has to be above a certain value to get rid of vertical padding
          //   child: Padding(
          //     padding: const EdgeInsets.only(bottom: 2.0),
          //     child: Text(
          //       processArtist(widget.item.item.item.artist, context),
          //       style: const TextStyle(
          //           color: Colors.white70,
          //           fontSize: 13,
          //           fontWeight: FontWeight.w300,
          //           overflow: TextOverflow.ellipsis),
          //       overflow: TextOverflow.ellipsis,
          //     ),
          //   ),
          // ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "${widget.item.item.item.duration?.inMinutes.toString()}:${((widget.item.item.item.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}",
                textAlign: TextAlign.end,
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              FavoriteButton(item: baseItem),
            ],
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
