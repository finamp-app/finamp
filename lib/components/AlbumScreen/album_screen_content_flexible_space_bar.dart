import 'package:finamp/components/AlbumScreen/item_info.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finamp/components/AlbumScreen/item_info.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/models/jellyfin_models.dart';

enum AlbumMenuItems {
  addFavorite,
  removeFavorite,
  addToMixList,
  removeFromMixList,
  playNext,
  addToNextUp,
  shuffleNext,
  shuffleToNextUp,
  addToQueue,
  shuffleToQueue,
}

class AlbumScreenContentFlexibleSpaceBar extends ConsumerStatefulWidget {
  const AlbumScreenContentFlexibleSpaceBar({
    super.key,
    required this.parentItem,
    required this.items,
    this.genreFilter,
    this.updateGenreFilter,
  });

  final BaseItemDto parentItem;
  final List<BaseItemDto> items;
  final BaseItemDto? genreFilter;
  final void Function(BaseItemDto?)? updateGenreFilter;

  @override
  ConsumerState<AlbumScreenContentFlexibleSpaceBar> createState() => _AlbumScreenContentFlexibleSpaceBarState();
}

class _AlbumScreenContentFlexibleSpaceBarState extends ConsumerState<AlbumScreenContentFlexibleSpaceBar> {
  SortAndFilterController? sortAndFilterController;

  @override
  void initState() {
    super.initState();
    sortAndFilterController = SortAndFilterController(
      configuration: SortAndFilterConfiguration(
        sortBy: ref.read(finampSettingsProvider.playlistTracksSortBy),
        sortOrder: ref.read(finampSettingsProvider.playlistTracksSortOrder),
        filters: {},
      ),
      onConfigurationChanged: (newConfig) {
        setState(() {
          // Update the settings when the configuration changes
          FinampSetters.setPlaylistTracksSortBy(newConfig.sortBy);
          FinampSetters.setPlaylistTracksSortOrder(newConfig.sortOrder);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
    SortBy playlistSortBySetting = ref.watch(finampSettingsProvider.playlistTracksSortBy);
    SortOrder playlistSortOrderSetting = ref.watch(finampSettingsProvider.playlistTracksSortOrder);
    final playlistSortBy =
        (isOffline && (playlistSortBySetting == SortBy.datePlayed || playlistSortBySetting == SortBy.playCount))
        ? SortBy.defaultOrder
        : playlistSortBySetting;

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
                    SizedBox(height: 125, child: AlbumImage(item: widget.parentItem, tapToZoom: true)),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: ItemInfo(
                        item: widget.parentItem,
                        itemTracks: widget.items,
                        genreFilter: widget.genreFilter,
                        updateGenreFilter: widget.updateGenreFilter,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                PlaybackActionRow(
                  compactLayout: true,
                  item: widget.parentItem,
                  popContext: false,
                  genreFilter: widget.genreFilter,
                ),
                if (BaseItemDtoType.fromItem(widget.parentItem) == BaseItemDtoType.playlist) ...[
                  SizedBox(height: 10),
                  SortAndFilterRow(
                    tabType: TabContentType.tracks,
                    forPlaylistTracks: true,
                    refreshTab: (contentType) {
                      //nop, handled by providers on playlist screen
                    },
                    controller: sortAndFilterController,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
