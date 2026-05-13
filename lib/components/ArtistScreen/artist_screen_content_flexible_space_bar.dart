import 'dart:async';

import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../album_image.dart';
import 'artist_item_info.dart';

enum ArtistMenuItems {
  playNext,
  addToNextUp,
  addToQueue,
  shuffleNext,
  shuffleToNextUp,
  shuffleToQueue,
  shuffleAlbums,
  shuffleAlbumsNext,
  shuffleAlbumsToNextUp,
  shuffleAlbumsToQueue,
}

class ArtistScreenContentFlexibleSpaceBar extends ConsumerWidget {
  const ArtistScreenContentFlexibleSpaceBar({
    super.key,
    required this.parentItem,
    required this.allTracks,
    required this.albumCount,
    required this.controller,
  });

  final BaseItemDto parentItem;
  final Future<List<BaseItemDto>?> allTracks;
  final int albumCount;
  final SortAndFilterController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FlexibleSpaceBar(
      background: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(height: 125, child: AlbumImage(item: parentItem, tapToZoom: true)),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: FutureBuilder(
                        future: allTracks,
                        builder: (context, snapshot) {
                          return ArtistItemInfo(
                            item: parentItem,
                            itemTracks: snapshot.data?.length ?? 0,
                            itemAlbums: albumCount,
                            updateGenreFilter: controller.updateGenreFilter,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (_, value, _) {
                    return Column(
                      children: [
                        PlaybackActionRow(
                          compactLayout: true,
                          item: PlayableBaseItem(item: parentItem, sortConfig: value),
                          popContext: false,
                        ),
                        if (value.filters.isNotEmpty) ...[
                          SizedBox(height: 10),
                          SortAndFilterRow.removeOnly(controller: controller),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
