import 'dart:async';

import 'package:finamp/components/AlbumScreen/album_screen_content_flexible_space_bar.dart';
import 'package:finamp/components/AlbumScreen/download_button.dart';
import 'package:finamp/components/AlbumScreen/playlist_edit_button.dart';
import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/favorite_button.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/finamp_section_header.dart';
import 'package:finamp/components/padded_custom_scrollview.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/album_menu.dart';
import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:finamp/menus/components/overflow_menu_button.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/album_screen_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../models/music_models.dart';
import '../MusicScreen/sort_and_filter_row.dart';

typedef BaseItemDtoCallback = void Function(BaseItemDto item);

class AlbumScreenContent extends ConsumerStatefulWidget {
  const AlbumScreenContent({super.key, required this.parent, this.genreFilter});

  final BaseItemDto parent;
  final BaseItemDto? genreFilter;

  @override
  ConsumerState<AlbumScreenContent> createState() => _AlbumScreenContentState();
}

class _AlbumScreenContentState extends ConsumerState<AlbumScreenContent> {
  SortAndFilterController sortAndFilterController = SortAndFilterController.trackSettings(ContentType.inPlaylist);

  //bool get disableDownloads => sortAndFilterController.value.filters.isNotEmpty;

  StreamSubscription<void>? _listener;

  @override
  void initState() {
    if (widget.genreFilter != null) {
      sortAndFilterController.updateGenreFilter(widget.genreFilter);
    }
    _listener = musicScreenRefreshStream.stream.listen((_) {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _listener?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final downloadStub = DownloadStub.fromItem(type: DownloadItemType.collection, item: widget.parent);

    final parentIsPlaylist = BaseItemDtoType.fromItem(widget.parent) == BaseItemDtoType.playlist;

    final sortSetting = ref.watch(resolveSortProvider(sortAndFilterController));
    final disableDownloads = sortSetting.filters.isNotEmpty && parentIsPlaylist;

    final tracksAsync = parentIsPlaylist
        ? ref.watch(getSortedPlaylistTracksProvider(widget.parent, sortSetting))
        : ref.watch(getAlbumOrPlaylistTracksProvider(widget.parent));
    final (allTracks, playableTracks) = tracksAsync.valueOrNull ?? (null, null);
    final isLoading = allTracks == null;

    final displayChildren = allTracks ?? [];
    final queueChildren = playableTracks ?? [];

    void onDelete(BaseItemDto item) {
      // This is pretty inefficient (has to search through whole list) but
      // TracksSliverList gets passed some weird split version of children to
      // handle multi-disc albums and it's 00:35 so I can't be bothered to get
      // it to return an index
      setState(() {
        queueChildren.removeWhere((element) => element.id == item.id);
        displayChildren.removeWhere((element) => element.id == item.id);
      });
    }

    List<List<BaseItemDto>> childrenPerDisc = [];
    // if not in playlist, try splitting up tracks by disc numbers
    // if first track has a disc number, let's assume the rest has it too
    if (!parentIsPlaylist && displayChildren.isNotEmpty && displayChildren[0].parentIndexNumber != null) {
      int? lastDiscNumber;
      for (var child in displayChildren) {
        if (child.parentIndexNumber != null && child.parentIndexNumber != lastDiscNumber) {
          lastDiscNumber = child.parentIndexNumber;
          childrenPerDisc.add([]);
        }
        childrenPerDisc.last.add(child);
      }
    }

    return PaddedCustomScrollview(
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final maxActions = constraints.crossAxisExtent ~/ 48.0;
            final actions = [
              if (maxActions >= 9 &&
                  parentIsPlaylist &&
                  !ref.watch(finampSettingsProvider.isOffline) &&
                  ref.watch(canEditPlaylistProvider(widget.parent)))
                PlaylistEditButton(playlist: widget.parent),
              FavoriteButton(item: widget.parent, visualDensity: VisualDensity.standard),
              if (maxActions >= 8 && !isLoading)
                DownloadButton(
                  item: downloadStub,
                  children: displayChildren,
                  downloadDisabled: disableDownloads,
                  customTooltip: disableDownloads
                      ? AppLocalizations.of(context)!.downloadButtonDisabledGenreFilterTooltip
                      : null,
                ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  openItemMenu(context: context, item: widget.parent);
                },
              ),
            ];

            return SliverAppBar(
              title: (!parentIsPlaylist) ? Text(widget.parent.name ?? AppLocalizations.of(context)!.unknownName) : null,
              expandedHeight: kToolbarHeight + 125 + 18 + 100 + (parentIsPlaylist ? SortAndFilterRow.height + 10 : 0),
              // collapsedHeight: kToolbarHeight + 125 + 80,
              leading: FinampAppBarBackButton(),
              pinned: true,
              centerTitle: false,
              titleSpacing: 0,
              flexibleSpace: AlbumScreenContentFlexibleSpaceBar(
                parentItem: widget.parent,
                items: isLoading ? null : queueChildren,
                controller: sortAndFilterController,
              ),
              actions: actions,
            );
          },
        ),
        if (!isLoading &&
            displayChildren.length > 1 &&
            childrenPerDisc.length > 1) // show headers only for multi disc albums
          for (var childrenOfThisDisc in childrenPerDisc) ...[
            FinampSectionHeader(
              key: Key("${childrenOfThisDisc[0].id}-${childrenOfThisDisc[0].parentIndexNumber}"),
              title: AppLocalizations.of(context)!.discNumber(childrenOfThisDisc[0].parentIndexNumber!),
              actions: [
                IconButtonWithSemantics(
                  onPressed: () async => await GetIt.instance<QueueService>().startPlayback(
                    items: childrenOfThisDisc,
                    source: QueueItemSource.fromBaseItem(widget.parent),
                    order: FinampPlaybackOrder.linear,
                  ),
                  label: AppLocalizations.of(context)!.playButtonLabel,
                  icon: TablerIcons.player_play,
                ),
                IconButtonWithSemantics(
                  onPressed: () async => await GetIt.instance<QueueService>().startPlayback(
                    items: childrenOfThisDisc,
                    source: QueueItemSource.fromBaseItem(widget.parent),
                    order: FinampPlaybackOrder.shuffled,
                  ),
                  label: AppLocalizations.of(context)!.shuffleButtonLabel,
                  icon: TablerIcons.arrows_shuffle,
                ),
                OverflowMenuButton(
                  onPressed: () => showModalAlbumMenu(
                    context: context,
                    album: AlbumDisc(widget.parent, tracks: childrenOfThisDisc),
                  ),
                  label: AppLocalizations.of(context)!.moreActionsOnAlbumDisc,
                ),
              ],
              onTap: () => showModalAlbumMenu(
                context: context,
                album: AlbumDisc(widget.parent, tracks: childrenOfThisDisc),
              ),
              onDismiss: (followUpAction) => onConfirmPlayableDismiss(
                followUpAction: followUpAction,
                item: AlbumDisc(widget.parent, tracks: childrenOfThisDisc),
              ),
              sectionContentSliver: TracksSliverList(
                childrenForList: childrenOfThisDisc,
                childrenForQueue: queueChildren,
                parent: widget.parent,
                onRemoveFromList: onDelete,
                adaptiveAdditionalInfoSortBy: (parentIsPlaylist) ? sortSetting.sortBy : null,
                forceAlbumArtists: (parentIsPlaylist && sortSetting.sortBy == SortBy.albumArtist),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 16.0)),
          ]
        else if (!isLoading)
          TracksSliverList(
            childrenForList: displayChildren,
            childrenForQueue: queueChildren,
            parent: widget.parent,
            onRemoveFromList: onDelete,
            adaptiveAdditionalInfoSortBy: (parentIsPlaylist) ? sortSetting.sortBy : null,
            forceAlbumArtists: (parentIsPlaylist && sortSetting.sortBy == SortBy.albumArtist),
          )
        else
          SliverFillRemaining(child: Center(child: CircularProgressIndicator.adaptive())),
      ],
    );
  }
}

class TracksSliverList extends ConsumerStatefulWidget {
  const TracksSliverList({
    super.key,
    required this.childrenForList,
    required this.childrenForQueue,
    required this.parent,
    this.onRemoveFromList,
    this.forceAlbumArtists = false,
    this.adaptiveAdditionalInfoSortBy,
  });

  final List<BaseItemDto> childrenForList;
  final List<BaseItemDto> childrenForQueue;
  // TODO switch this to a playable
  final BaseItemDto parent;
  final BaseItemDtoCallback? onRemoveFromList;
  final bool forceAlbumArtists;
  final SortBy? adaptiveAdditionalInfoSortBy;

  @override
  ConsumerState<TracksSliverList> createState() => _TracksSliverListState();
}

class _TracksSliverListState extends ConsumerState<TracksSliverList> {
  final GlobalKey<SliverAnimatedListState> sliverListKey = GlobalKey<SliverAnimatedListState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.childrenForList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
            child: Text(
              AppLocalizations.of(context)!.emptyAlbum,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SliverFixedExtentList(
      itemExtent: TrackListItemTile.defaultTileHeight + TrackListItemTile.defaultTitleGap,
      // return SliverList(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        // When user selects track from disc other than first, index number is
        // incorrect and track with the same index on first disc is played instead.
        // Adding this offset ensures playback starts for nth track on correct disc.
        final indexOffset = widget.childrenForQueue.indexWhere(
          (element) => element.id == widget.childrenForList[index].id,
        );

        final BaseItemDto item = widget.childrenForList[index];

        BaseItemDto removeItem() {
          late BaseItemDto item;

          setState(() {
            item = widget.childrenForList.removeAt(index);
          });

          return item;
        }

        return TrackListTile(
          key: ValueKey(item.id),
          item: item,
          index: indexOffset,
          showIndex: item.albumId == widget.parent.id,
          showCover: item.albumId != widget.parent.id || ref.watch(finampSettingsProvider.showCoversOnAlbumScreen),
          parentItem: widget.parent,
          onRemoveFromList: () {
            final item = removeItem();
            if (widget.onRemoveFromList != null) {
              widget.onRemoveFromList!(item);
            }
          },
          forceAlbumArtists: widget.forceAlbumArtists,
          adaptiveAdditionalInfoSortBy: widget.adaptiveAdditionalInfoSortBy,
          // TODO should we be passing and leveraging a proper parent playable?
          parentPlayable: PrecalculatedPlayable(
            source: QueueItemSource.fromBaseItem(widget.parent),
            tracks: widget.childrenForQueue,
          ),
        );
      }, childCount: widget.childrenForList.length),
    );
  }
}
