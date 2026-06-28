import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';
import '../../models/music_models.dart';
import '../../services/playback_history_service.dart';
import '../padded_custom_scrollview.dart';

class PlaybackHistoryList extends StatelessWidget {
  const PlaybackHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final playbackHistoryService = GetIt.instance<PlaybackHistoryService>();
    List<MapEntry<DateTime, List<FinampHistoryItem>>> groupedHistory;

    return StreamBuilder<List<FinampHistoryItem>>(
      stream: playbackHistoryService.historyStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          groupedHistory = playbackHistoryService.getHistoryGroupedDynamically();

          return PaddedCustomScrollview(
            // use nested SliverList.builder()s to show history items grouped by date
            slivers: groupedHistory.indexed.map((indexedGroup) {
              final groupIndex = indexedGroup.$1;
              final group = indexedGroup.$2;
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final actualIndex = group.value.length - index - 1;

                  final historyItem = TrackListTile(
                    key: ValueKey(group.value[actualIndex].item.id),
                    index: actualIndex,
                    item: group.value[actualIndex].item.baseItem,
                    highlightCurrentTrack: groupIndex == 0 && index == 0, // only highlight first track
                    playbackProgress: group.value[actualIndex].playPercentage,
                    // TODO better queue source
                    parentPlayable: PrecalculatedPlayable(
                      source: QueueItemSource.rawId(
                        type: QueueItemSourceType.unknown,
                        name: QueueItemSourceName(
                          type: QueueItemSourceNameType.preTranslated,
                          pretranslatedName: context.l10n.playbackHistory,
                        ),
                        id: "playback-history",
                      ),
                      tracks: group.value.map((x) => x.item.baseItem).toList().reversed.toList(),
                    ),
                  );

                  return index == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 4.0),
                              child: RelativeDateTimeText(
                                dateTime: group.key,
                                style: const TextStyle(fontSize: 16.0),
                                includeStaticDateTime: true,
                              ),
                            ),
                            historyItem,
                          ],
                        )
                      : historyItem;
                }, childCount: group.value.length),
              );
            }).toList(),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
