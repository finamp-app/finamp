import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/extensions/string.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:finamp/menus/components/overflow_menu_button.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/item_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../services/audio_service_helper.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/queue_service.dart';
import '../../services/theme_provider.dart';
import '../album_image.dart';
import '../print_duration.dart';
import 'downloaded_indicator.dart';

enum TrackListTileMenuItems {
  addToQueue,
  playNext,
  addToNextUp,
  addToPlaylist,
  removeFromPlaylist,
  instantMix,
  goToAlbum,
  addFavorite,
  removeFavorite,
  download,
  delete,
}

class TrackListTile extends ConsumerWidget {
  const TrackListTile({
    super.key,
    required this.item,

    /// Children that are related to this list tile, such as the other tracks in
    /// the album. This is used to give the audio service all the tracks for the
    /// item. If null, only this track will be given to the audio service.
    this.children,

    /// Index of the track in whatever parent this widget is in. Used to start
    /// the audio service at a certain index, such as when selecting the middle
    /// track in an album.  Will be -1 if we are offline and the track is not downloaded.
    this.index,
    this.parentItem,

    // if leading index number should be shown
    this.showIndex = false,
    // if leading album cover should be shown
    this.showCover = true,

    /// Whether we are in the tracks tab, as opposed to a playlist/album
    this.isTrack = false,
    this.onRemoveFromList,
    this.adaptiveAdditionalInfoSortBy,
    this.forceAlbumArtists = false,

    /// Whether this widget is being displayed in a playlist. If true, will show
    /// the remove from playlist button.
    this.isInPlaylist = false,
    this.isOnArtistScreen = false,
    this.isOnGenreScreen = false,
    this.isShownInSearchOrHistory = false,
    this.allowDismiss = true,
    this.highlightCurrentTrack = true,
    this.genreFilter,
    this.playbackProgress,
  });

  final BaseItemDto item;
  final List<BaseItemDto>? children;
  final int? index;
  final bool showIndex;
  final bool showCover;
  final bool isTrack;
  final BaseItemDto? parentItem;
  final VoidCallback? onRemoveFromList;
  final bool forceAlbumArtists;
  final SortBy? adaptiveAdditionalInfoSortBy;
  final bool isInPlaylist;
  final bool isOnArtistScreen;
  final bool isOnGenreScreen;
  final bool isShownInSearchOrHistory;
  final bool allowDismiss;
  final bool highlightCurrentTrack;
  final BaseItemDto? genreFilter;
  final double? playbackProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool playable;
    if (ref.watch(finampSettingsProvider.isOffline)) {
      playable = ref.watch(
        GetIt.instance<DownloadsService>()
            .stateProvider(DownloadStub.fromItem(type: DownloadItemType.track, item: item))
            .select((value) => value.value?.isComplete ?? false),
      );
    } else {
      playable = true;
    }

    Future<void> trackListTileOnTap(bool playable) async {
      final queueService = GetIt.instance<QueueService>();
      final audioServiceHelper = GetIt.instance<AudioServiceHelper>();

      if (!playable) return;
      if (children != null) {
        // start linear playback of album from the given index
        await queueService.startPlayback(
          items: children!,
          startingIndex: index,
          order: FinampPlaybackOrder.linear,
          source: QueueItemSource.rawId(
            type: isInPlaylist
                ? QueueItemSourceType.playlist
                : isOnArtistScreen
                ? QueueItemSourceType.artist
                : isOnGenreScreen
                ? QueueItemSourceType.genre
                : parentItem != null
                ? QueueItemSourceType.album
                : QueueItemSourceType.queue,
            name: parentItem != null
                ? QueueItemSourceName(
                    type: QueueItemSourceNameType.preTranslated,
                    pretranslatedName:
                        ((isInPlaylist || isOnArtistScreen || isOnGenreScreen) ? parentItem?.name : item.album) ??
                        AppLocalizations.of(context)!.placeholderSource,
                  )
                : QueueItemSourceName(type: QueueItemSourceNameType.queue),
            id: parentItem?.id.raw ?? "",
            item: parentItem,
            // we're playing from an album, so we should use the album's normalization gain.
            contextNormalizationGain: (isInPlaylist || isOnArtistScreen || isOnGenreScreen)
                ? null
                : parentItem?.normalizationGain,
          ),
        );
      } else {
        // TODO put in a real offline tracks implementation
        if (FinampSettingsHelper.finampSettings.isOffline) {
          final settings = FinampSettingsHelper.finampSettings;
          final downloadsService = GetIt.instance<DownloadsService>();
          final finampUserHelper = GetIt.instance<FinampUserHelper>();

          // get all downloaded tracks in order
          List<DownloadStub> offlineItems;
          // If we're on the tracks tab, just get all of the downloaded items
          offlineItems = await downloadsService.getAllTracks(
            // nameFilter: widget.searchTerm,
            viewFilter: finampUserHelper.currentUser?.currentView?.id,
            nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
            onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
            genreFilter: genreFilter,
          );

          var items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
          var sortBy = settings.tabSortBy[TabContentType.tracks];
          if ([SortBy.playCount, SortBy.datePlayed].contains(sortBy)) {
            sortBy = SortBy.sortName;
          }

          items = sortItems(items, sortBy, settings.tabSortOrder[TabContentType.tracks]);

          int startingIndex = isShownInSearchOrHistory
              ? items.indexWhere((element) => element.id == item.id)
              : index ?? 0;
          //!!! limit the amount of tracks to prevent freezing and crashing for many tracks
          if (items.length > QueueService.maxInitialQueueItems) {
            // take 10% of the maximum before the index, and the rest after the index
            final firstTrackIndex = startingIndex - (QueueService.maxInitialQueueItems ~/ 10);
            final lastTrackIndex =
                startingIndex + (QueueService.maxInitialQueueItems - (QueueService.maxInitialQueueItems ~/ 10));
            // update the initial index
            if (firstTrackIndex > 0) {
              startingIndex = startingIndex - firstTrackIndex;
            } else {
              startingIndex = startingIndex;
            }
            items = items.sublist(
              firstTrackIndex >= 0 ? firstTrackIndex : 0,
              lastTrackIndex <= items.length ? lastTrackIndex : items.length,
            );
          }

          await queueService.startPlayback(
            items: items,
            startingIndex: startingIndex,
            source: QueueItemSource(
              name: QueueItemSourceName(
                type: item.name != null ? QueueItemSourceNameType.mix : QueueItemSourceNameType.instantMix,
                localizationParameter: item.name ?? "",
              ),
              type: QueueItemSourceType.allTracks,
              id: item.id,
              item: item,
            ),
          );
        } else {
          if (FinampSettingsHelper.finampSettings.startInstantMixForIndividualTracks) {
            await audioServiceHelper.startInstantMixForItem(item);
          } else {
            await queueService.startPlayback(
              items: await loadChildTracks(item: item, genreFilter: genreFilter),
              source: QueueItemSource.fromBaseItem(item),
            );
          }
        }
      }
    }

    return TrackListItem(
      baseItem: item,
      parentItem: parentItem,
      listIndex: index,
      actualIndex: item.indexNumber,
      showArtists: (forceAlbumArtists || parentItem?.isArtist != true),
      forceAlbumArtists: forceAlbumArtists,
      adaptiveAdditionalInfoSortBy: adaptiveAdditionalInfoSortBy,
      isInPlaylist: isInPlaylist,
      highlightCurrentTrack: highlightCurrentTrack,
      onRemoveFromList: onRemoveFromList,
      onTap: trackListTileOnTap,
      confirmDismiss: (direction) => onConfirmPlayableDismiss(
        context: context,
        direction: direction,
        sourceItem: parentItem ?? item,
        tracks: [item],
      ),
      leftSwipeBackground: buildSwipeActionBackground(
        context: context,
        direction: DismissDirection.startToEnd,
        action: ref.watch(finampSettingsProvider.itemSwipeActionLeftToRight),
        iconSize: 40.0,
      ),
      rightSwipeBackground: buildSwipeActionBackground(
        context: context,
        direction: DismissDirection.endToStart,
        action: ref.watch(finampSettingsProvider.itemSwipeActionRightToLeft),
        iconSize: 40.0,
      ),
      playbackProgress: playbackProgress,
      features: [
        showIndex ? TrackListItemFeatures.parentIndex : null,
        showCover ? TrackListItemFeatures.cover : null,
        TrackListItemFeatures.duration,
        TrackListItemFeatures.addToPlaylistOrFavorite,
        playable && allowDismiss ? TrackListItemFeatures.swipeable : null,
      ].nonNulls.toList(),
    );
  }
}

IconData getSwipeActionIcon(ItemSwipeActions action) {
  switch (action) {
    case ItemSwipeActions.addToQueue:
      return TablerIcons.playlist;
    case ItemSwipeActions.playNext:
      return TablerIcons.corner_right_down;
    case ItemSwipeActions.addToNextUp:
    case ItemSwipeActions.nothing:
      return TablerIcons.corner_right_down_double;
  }
}

Future<bool> onConfirmPlayableDismiss({
  required BuildContext context,
  required DismissDirection direction,
  required PlayableItem sourceItem,
  required List<BaseItemDto> tracks,
}) async {
  var followUpAction = (direction == DismissDirection.startToEnd)
      ? FinampSettingsHelper.finampSettings.itemSwipeActionLeftToRight
      : FinampSettingsHelper.finampSettings.itemSwipeActionRightToLeft;

  final queueService = GetIt.instance<QueueService>();

  final sourceItemType = switch (sourceItem) {
    AlbumDisc() => "disc",
    BaseItemDto() => BaseItemDtoType.fromPlayableItem(sourceItem).name,
  };

  switch (followUpAction) {
    case ItemSwipeActions.addToNextUp:
      unawaited(
        queueService.addToNextUp(
          items: tracks,
          source: QueueItemSource.rawId(
            type: QueueItemSourceType.nextUp,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.preTranslated,
              pretranslatedName: AppLocalizations.of(context)!.queue,
            ),
            id: BaseItemDto.fromPlayableItem(sourceItem).id.raw,
            item: BaseItemDto.fromPlayableItem(sourceItem),
          ),
        ),
      );
      GlobalSnackbar.message(
        (scaffold) => AppLocalizations.of(scaffold)!.confirmAddToNextUp(sourceItemType),
        isConfirmation: true,
      );
      break;
    case ItemSwipeActions.playNext:
      unawaited(
        queueService.addNext(
          items: tracks,
          source: QueueItemSource.rawId(
            type: QueueItemSourceType.nextUp,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.preTranslated,
              pretranslatedName: AppLocalizations.of(context)!.queue,
            ),
            id: BaseItemDto.fromPlayableItem(sourceItem).id.raw,
            item: BaseItemDto.fromPlayableItem(sourceItem),
          ),
        ),
      );
      GlobalSnackbar.message(
        (scaffold) => AppLocalizations.of(scaffold)!.confirmPlayNext(sourceItemType),
        isConfirmation: true,
      );
      break;
    case ItemSwipeActions.addToQueue:
      unawaited(
        queueService.addToQueue(
          items: tracks,
          source: QueueItemSource.rawId(
            type: QueueItemSourceType.queue,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.preTranslated,
              pretranslatedName: AppLocalizations.of(context)!.queue,
            ),
            id: BaseItemDto.fromPlayableItem(sourceItem).id.raw,
            item: BaseItemDto.fromPlayableItem(sourceItem),
          ),
        ),
      );
      GlobalSnackbar.message(
        (scaffold) => AppLocalizations.of(scaffold)!.confirmAddToQueue(sourceItemType),
        isConfirmation: true,
      );
      break;
    case ItemSwipeActions.nothing:
      break;
  }

  return false;
}

Widget buildSwipeActionBackground({
  required BuildContext context,
  required DismissDirection direction,
  required ItemSwipeActions action,
  double? iconSize,
}) {
  final icon = getSwipeActionIcon(action);
  final label = action.toLocalisedString(context);

  final children = [
    Icon(icon, color: Theme.of(context).colorScheme.secondary, size: iconSize ?? 28.0),
    const SizedBox(width: 4.0),
    Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
    Spacer(),
  ];

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    child: Row(children: direction == DismissDirection.startToEnd ? children : children.reversed.toList()),
  );
}

DismissDirection getAllowedDismissDirection({required bool swipeLeftEnabled, required bool swipeRightEnabled}) {
  return (swipeLeftEnabled && swipeRightEnabled)
      ? DismissDirection.horizontal
      : swipeLeftEnabled
      ? DismissDirection.startToEnd
      : swipeRightEnabled
      ? DismissDirection.endToStart
      : DismissDirection.none;
}

class QueueListTile extends StatelessWidget {
  final BaseItemDto item;
  final FinampQueueItem queueItem;
  final BaseItemDto? parentItem;
  final int? listIndex;
  final bool isCurrentTrack;
  final bool isInPlaylist;
  final bool allowReorder;
  final bool highlightCurrentTrack;

  final void Function(bool playable) onTap;
  final VoidCallback? onRemoveFromList;

  static const double height = 70.0;

  const QueueListTile({
    super.key,
    required this.item,
    required this.queueItem,
    required this.listIndex,
    required this.onTap,
    required this.isCurrentTrack,
    required this.isInPlaylist,
    required this.allowReorder,
    this.highlightCurrentTrack = false,
    this.parentItem,
    this.onRemoveFromList,
  });

  @override
  Widget build(BuildContext context) {
    return TrackListItem(
      baseItem: item,
      queueItem: queueItem,
      parentItem: parentItem,
      listIndex: listIndex,
      actualIndex: item.indexNumber,
      isInPlaylist: isInPlaylist,
      highlightCurrentTrack: highlightCurrentTrack,
      onRemoveFromList: onRemoveFromList,
      // This must be in ListTile instead of parent GestureDetector to
      // enable hover color changes
      onTap: onTap,
      confirmDismiss: (DismissDirection direction) async {
        FeedbackHelper.feedback(FeedbackType.heavy);
        onRemoveFromList?.call();
        return true;
      },
      features: [
        TrackListItemFeatures.cover,
        TrackListItemFeatures.duration,
        TrackListItemFeatures.addToPlaylistOrFavorite,
        TrackListItemFeatures.swipeable,
        allowReorder ? TrackListItemFeatures.dragHandle : null,
      ].nonNulls.toList(),
    );
  }
}

class EditListTile extends StatelessWidget {
  final BaseItemDto item;
  final int? listIndex;
  final bool restoreInsteadOfRemove;

  final void Function(bool playable) onTap;
  final VoidCallback? onRemoveOrRestore;

  const EditListTile({
    super.key,
    required this.item,
    required this.listIndex,
    required this.onTap,
    this.restoreInsteadOfRemove = false,
    this.onRemoveOrRestore,
  });

  @override
  Widget build(BuildContext context) {
    return TrackListItem(
      baseItem: item,
      listIndex: listIndex,
      actualIndex: item.indexNumber,
      isInPlaylist: false,
      highlightCurrentTrack: false,
      onRemoveFromList: onRemoveOrRestore,
      onTap: onTap,
      confirmDismiss: (DismissDirection direction) async {
        FeedbackHelper.feedback(FeedbackType.heavy);
        onRemoveOrRestore?.call();
        return true;
      },
      features: [
        restoreInsteadOfRemove ? null : TrackListItemFeatures.listIndex,
        TrackListItemFeatures.cover,
        TrackListItemFeatures.dragHandle,
        TrackListItemFeatures.fullyDraggable,
        TrackListItemFeatures.swipeable,
        restoreInsteadOfRemove ? TrackListItemFeatures.restoreButton : TrackListItemFeatures.removeFromListButton,
      ].nonNulls.toList(),
    );
  }
}

class TrackListItem extends ConsumerWidget {
  final BaseItemDto baseItem;
  final BaseItemDto? parentItem;
  final FinampQueueItem? queueItem;
  final int? listIndex;
  final int? actualIndex;
  final bool showArtists;
  final bool forceAlbumArtists;
  final SortBy? adaptiveAdditionalInfoSortBy;
  final bool isInPlaylist;
  final bool highlightCurrentTrack;
  final Widget leftSwipeBackground;
  final Widget rightSwipeBackground;
  final List<TrackListItemFeatures> features;

  final void Function(bool playable) onTap;
  final Future<bool> Function(DismissDirection direction) confirmDismiss;
  final VoidCallback? onRemoveFromList;
  final double? playbackProgress;

  const TrackListItem({
    super.key,
    required this.baseItem,
    required this.listIndex,
    required this.actualIndex,
    required this.onTap,
    required this.confirmDismiss,
    required this.features,
    this.parentItem,
    this.queueItem,
    this.isInPlaylist = false,
    this.showArtists = true,
    this.forceAlbumArtists = false,
    this.adaptiveAdditionalInfoSortBy,
    this.highlightCurrentTrack = true,
    this.onRemoveFromList,
    this.leftSwipeBackground = const SizedBox.shrink(),
    this.rightSwipeBackground = const SizedBox.shrink(),
    this.playbackProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool playable;
    if (ref.watch(finampSettingsProvider.isOffline)) {
      playable = ref.watch(
        GetIt.instance<DownloadsService>()
            .stateProvider(DownloadStub.fromItem(type: DownloadItemType.track, item: baseItem))
            .select((value) => value.value?.isComplete ?? false),
      );
    } else {
      playable = true;
    }

    final bool showAlbum = baseItem.albumId != parentItem?.id;

    final isCurrentlyPlaying = ref.watch(
      currentTrackProvider.select((queueItem) => queueItem.valueOrNull?.baseItemId == baseItem.id),
    );

    var listCard = Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 6.0),
      child: TrackListItemTile(
        baseItem: baseItem,
        queueItem: queueItem,
        listIndex: listIndex,
        actualIndex: actualIndex,
        showArtists: showArtists,
        forceAlbumArtists: forceAlbumArtists,
        showAlbum: showAlbum,
        adaptiveAdditionalInfoSortBy: adaptiveAdditionalInfoSortBy,
        isCurrentTrack: isCurrentlyPlaying,
        highlightCurrentTrack: highlightCurrentTrack,
        onTap: () => onTap(playable),
        playbackProgress: playbackProgress,
        onRemoveFromList: onRemoveFromList,
        features: features,
      ),
    );

    var listItem = playable ? listCard : Opacity(opacity: 0.5, child: listCard);

    var unthemedItem = Builder(
      builder: (context) {
        // Use potentially themed context in menu callback
        void menuCallback() async {
          if (playable && !features.contains(TrackListItemFeatures.fullyDraggable)) {
            FeedbackHelper.feedback(FeedbackType.selection);
            await showModalTrackMenu(
              context: context,
              item: baseItem,
              isInPlaylist: isInPlaylist,
              parentItem: parentItem,
              onRemoveFromList: onRemoveFromList,
              confirmPlaylistRemoval: false,
              queueItem: queueItem,
            );
          }
        }

        return GestureDetector(
          onTapDown: (_) {
            // Begin precalculating theme for song menu
            ref.listenManual(finampThemeProvider(ThemeInfo(baseItem)), (_, __) {});
          },
          onLongPressStart: features.contains(TrackListItemFeatures.fullyDraggable)
              ? null
              : (details) => menuCallback(),
          onSecondaryTapDown: features.contains(TrackListItemFeatures.fullyDraggable)
              ? null
              : (details) => menuCallback(),
          child: features.contains(TrackListItemFeatures.swipeable) && !ref.watch(finampSettingsProvider.disableGesture)
              ? Dismissible(
                  key: Key(listIndex.toString()),
                  direction: getAllowedDismissDirection(
                    swipeLeftEnabled:
                        ref.watch(finampSettingsProvider.itemSwipeActionLeftToRight) != ItemSwipeActions.nothing,
                    swipeRightEnabled:
                        ref.watch(finampSettingsProvider.itemSwipeActionRightToLeft) != ItemSwipeActions.nothing,
                  ),
                  dismissThresholds: const {DismissDirection.startToEnd: 0.65, DismissDirection.endToStart: 0.65},
                  // no background, dismissing really dismisses here
                  confirmDismiss: confirmDismiss,
                  background: leftSwipeBackground,
                  secondaryBackground: rightSwipeBackground,
                  child: listItem,
                )
              : listItem,
        );
      },
    );

    final fullTile = isCurrentlyPlaying && highlightCurrentTrack
        ? PlayerScreenTheme(
            themeTransitionDuration: const Duration(milliseconds: 500),
            themeOverride: (imageTheme) {
              return imageTheme.copyWith(
                colorScheme: imageTheme.colorScheme.copyWith(
                  surfaceContainer: imageTheme.colorScheme.primary.withOpacity(
                    imageTheme.brightness == Brightness.dark ? 0.35 : 0.3,
                  ),
                ),
                textTheme: imageTheme.textTheme.copyWith(
                  bodyLarge: imageTheme.textTheme.bodyLarge?.copyWith(
                    color: Color.alphaBlend(
                      (imageTheme.colorScheme.secondary.withOpacity(
                        imageTheme.brightness == Brightness.light ? 0.5 : 0.1,
                      )),
                      imageTheme.textTheme.bodyLarge?.color ??
                          (imageTheme.brightness == Brightness.light ? Colors.black : Colors.white),
                    ),
                  ),
                ),
              );
            },
            child: unthemedItem,
          )
        : unthemedItem;
    return features.contains(TrackListItemFeatures.fullyDraggable)
        ? ((Platform.isLinux || Platform.isMacOS || Platform.isWindows)
              ? ReorderableDragStartListener(index: listIndex ?? 0, child: fullTile)
              : ReorderableDelayedDragStartListener(index: listIndex ?? 0, child: fullTile))
        : fullTile;
  }
}

enum TrackListItemFeatures {
  listIndex,
  parentIndex,
  cover,
  duration,
  addToPlaylistOrFavorite,
  dragHandle,
  fullyDraggable,
  swipeable,
  removeFromListButton,
  restoreButton,
}

class TrackListItemTile extends ConsumerWidget {
  const TrackListItemTile({
    super.key,
    required this.baseItem,
    required this.isCurrentTrack,
    required this.onTap,
    required this.actualIndex,
    required this.features,
    this.queueItem,
    this.listIndex,
    this.showArtists = true,
    this.forceAlbumArtists = false,
    this.showAlbum = true,
    this.adaptiveAdditionalInfoSortBy,
    this.highlightCurrentTrack = true,
    this.playbackProgress,
    this.onRemoveFromList,
  });

  final BaseItemDto baseItem;
  final FinampQueueItem? queueItem;
  final bool isCurrentTrack;
  final int? listIndex;
  final int? actualIndex;
  final bool showArtists;
  final bool forceAlbumArtists;
  final bool showAlbum;
  final List<TrackListItemFeatures> features;
  final SortBy? adaptiveAdditionalInfoSortBy;
  final bool highlightCurrentTrack;
  final void Function() onTap;
  final double? playbackProgress;
  final void Function()? onRemoveFromList;

  static const double defaultTileHeight = 60.0;
  static const double defaultTitleGap = 10.0;
  static const double albumCoverCornerRadius = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightTrack = isCurrentTrack && highlightCurrentTrack;
    final isOnDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final tileAdditionalInfoType =
        ref.watch(finampSettingsProvider.tileAdditionalInfoType(TabContentType.tracks)) ??
        TileAdditionalInfoType.adaptive;

    bool showPlayCount = tileAdditionalInfoType == TileAdditionalInfoType.playCount;
    bool showReleaseDate = tileAdditionalInfoType == TileAdditionalInfoType.dateReleased;
    bool showDateAdded = tileAdditionalInfoType == TileAdditionalInfoType.dateAdded;
    bool showDateLastPlayed = tileAdditionalInfoType == TileAdditionalInfoType.dateLastPlayed;

    if (tileAdditionalInfoType == TileAdditionalInfoType.adaptive) {
      showPlayCount = showPlayCount || adaptiveAdditionalInfoSortBy == SortBy.playCount;
      showReleaseDate = showReleaseDate || adaptiveAdditionalInfoSortBy == SortBy.premiereDate;
      showDateAdded = showDateAdded || adaptiveAdditionalInfoSortBy == SortBy.dateCreated;
      showDateLastPlayed = showDateLastPlayed || adaptiveAdditionalInfoSortBy == SortBy.datePlayed;
    }

    if (showPlayCount || showDateLastPlayed) {
      if (ref.watch(finampSettingsProvider.isOffline)) {
        showPlayCount = false;
        showDateLastPlayed = false;
      }
    }

    final bool secondRowNeeded =
        showArtists || showAlbum || showPlayCount || showReleaseDate || showDateAdded || showDateLastPlayed;

    final durationLabelFullHours = (baseItem.runTimeTicksDuration()?.inHours ?? 0);
    final durationLabelFullMinutes = (baseItem.runTimeTicksDuration()?.inMinutes ?? 0) % 60;
    final durationLabelSeconds = (baseItem.runTimeTicksDuration()?.inSeconds ?? 0) % 60;
    final durationLabelString =
        "${durationLabelFullHours > 0 ? "$durationLabelFullHours ${AppLocalizations.of(context)!.hours} " : ""}${durationLabelFullMinutes > 0 ? "$durationLabelFullMinutes ${AppLocalizations.of(context)!.minutes} " : ""}$durationLabelSeconds ${AppLocalizations.of(context)!.seconds}";

    final String artistsString;
    if (forceAlbumArtists || (baseItem.artists?.isEmpty ?? true)) {
      artistsString =
          baseItem.albumArtists?.sortedBy((e) => e.name ?? '').map((e) => e.name).joinNonNull(", ") ??
          AppLocalizations.of(context)!.unknownArtist;
    } else {
      artistsString =
          baseItem.artists?.sortedBy((e) => e).joinNonNull(", ") ?? AppLocalizations.of(context)!.unknownArtist;
    }
    final downloadedIndicator = DownloadedIndicator(
      item: DownloadStub.fromItem(item: baseItem, type: DownloadItemType.track),
      size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 1,
    );
    final isRadioTrack = queueItem?.source.type == QueueItemSourceType.radio;
    final addSpaceAfterSpecialIcons =
        (downloadedIndicator.isVisible(ref) || (baseItem.hasLyrics ?? false) || isRadioTrack) &&
        (showDateAdded || showDateLastPlayed);

    final showPlaybackProgress = !highlightCurrentTrack && playbackProgress != null && playbackProgress! < 0.99;

    final tileLead = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (features.contains(TrackListItemFeatures.listIndex) ||
            (features.contains(TrackListItemFeatures.parentIndex) && actualIndex != null))
          Padding(
            padding: features.contains(TrackListItemFeatures.cover)
                ? EdgeInsets.only(
                    left:
                        features.contains(TrackListItemFeatures.listIndex) ||
                            features.contains(TrackListItemFeatures.parentIndex)
                        ? 0.0
                        : 2.0,
                    right: 8.0,
                  )
                : const EdgeInsets.only(left: 6.0, right: 0.0),
            child: Container(
              constraints: const BoxConstraints(minWidth: 22.0),
              child: Text(
                features.contains(TrackListItemFeatures.listIndex)
                    ? ((listIndex ?? 0) + 1).toString()
                    : actualIndex.toString(),
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (features.contains(TrackListItemFeatures.cover))
          AlbumImage(item: baseItem, borderRadius: BorderRadius.circular(albumCoverCornerRadius)),
      ],
    );
    final tileTitle = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: defaultTileHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            fit: FlexFit.loose,
            flex: 3,
            child: Text(
              baseItem.name ?? AppLocalizations.of(context)!.unknownName,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            flex: 2,
            child: Text.rich(
              overflow: TextOverflow.clip,
              softWrap: false,
              maxLines: 1,
              TextSpan(
                children: [
                  if (isRadioTrack)
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: Transform.translate(
                          offset: isOnDesktop ? Offset(-1.5, 1.7) : Offset(-1.5, 0.4),
                          child: Icon(TablerIcons.radio, size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 1),
                        ),
                      ),
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                    ),
                  WidgetSpan(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2.0),
                      child: Transform.translate(
                        offset: isOnDesktop ? Offset(-1.5, 1.7) : Offset(-1.5, 0.4),
                        child: downloadedIndicator,
                      ),
                    ),
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                  ),
                  if (downloadedIndicator.isVisible(ref) && (baseItem.hasLyrics == null || baseItem.hasLyrics == false))
                    const WidgetSpan(child: SizedBox(width: 4.5)),
                  if (baseItem.hasLyrics ?? false)
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: Transform.translate(
                          offset: isOnDesktop ? Offset(-1.5, 1.7) : Offset(-1.5, 0.4),
                          child: Icon(
                            TablerIcons.microphone_2,
                            size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 1,
                          ),
                        ),
                      ),
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                    ),
                  if (baseItem.isExplicit)
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: Transform.translate(
                          offset: isOnDesktop ? Offset(-1.5, 3.3) : Offset(-1.5, 1.7),
                          child: Icon(
                            TablerIcons.explicit,
                            size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 3,
                          ),
                        ),
                      ),
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                    ),
                  if (addSpaceAfterSpecialIcons) const WidgetSpan(child: SizedBox(width: 5)),
                  if (showPlayCount)
                    TextSpan(
                      text: AppLocalizations.of(context)!.playCountValue(baseItem.userData?.playCount ?? 0),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  if (showPlayCount) const WidgetSpan(child: SizedBox(width: 10.0)),
                  if (showDateLastPlayed)
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: Transform.translate(
                          offset: isOnDesktop ? Offset(-1.5, 1.8) : Offset(-1.5, 0.3),
                          child: Icon(TablerIcons.clock, size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 1),
                        ),
                      ),
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                    ),
                  if (showDateLastPlayed)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: RelativeDateTimeTextFromString(
                        dateString: baseItem.userData?.lastPlayedDate,
                        fallback: AppLocalizations.of(context)!.noDateLastPlayed,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        disableTextScaling: true,
                      ),
                    ),
                  if (showDateLastPlayed) const WidgetSpan(child: SizedBox(width: 10.0)),
                  if (showReleaseDate)
                    TextSpan(
                      text: (ReleaseDateHelper.autoFormat(baseItem) ?? AppLocalizations.of(context)!.noReleaseDate),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  if (showReleaseDate) const WidgetSpan(child: SizedBox(width: 10.0)),
                  if (showDateAdded)
                    WidgetSpan(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Transform.translate(
                          offset: isOnDesktop ? Offset(-1.5, 1.28) : Offset(-1.5, 0),
                          child: Icon(
                            TablerIcons.calendar_plus,
                            size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 1,
                            color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                          ),
                        ),
                      ),
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                    ),
                  if (showDateAdded)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: RelativeDateTimeTextFromString(
                        dateString: baseItem.dateCreated,
                        fallback: AppLocalizations.of(context)!.noDateAdded,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        disableTextScaling: true,
                      ),
                    ),
                  if (showDateAdded) const WidgetSpan(child: SizedBox(width: 10.0)),
                  if (showArtists)
                    TextSpan(
                      text: artistsString,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (!secondRowNeeded)
                    // show the artist anyway if nothing else is shown
                    TextSpan(
                      text: artistsString,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  if (showArtists) const WidgetSpan(child: SizedBox(width: 10.0)),
                  if (showAlbum)
                    TextSpan(
                      text: baseItem.album,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final listTile = OverflowBuilder(
      hasOverflowed: (BoxConstraints constraints) => constraints.maxWidth > 750,
      builder: (context, showOverflowMenu) {
        return ListTile(
          visualDensity: const VisualDensity(horizontal: 0.0, vertical: 0.5),
          minVerticalPadding: 0.0,
          horizontalTitleGap: defaultTitleGap,
          contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(albumCoverCornerRadius)),
          tileColor: highlightTrack ? Theme.of(context).colorScheme.surfaceContainer : Colors.transparent,
          leading: tileLead,
          title: tileTitle,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (features.contains(TrackListItemFeatures.duration))
                  Text(
                    printDuration(baseItem.runTimeTicksDuration(), leadingZeroes: false),
                    semanticsLabel: durationLabelString,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                if (features.contains(TrackListItemFeatures.addToPlaylistOrFavorite))
                  Semantics(
                    excludeSemantics: true,
                    child: AddToPlaylistButton(
                      item: baseItem,
                      size: 24,
                      visualDensity: const VisualDensity(horizontal: -4),
                    ),
                  ),
                if (features.contains(TrackListItemFeatures.removeFromListButton))
                  IconButton(
                    visualDensity: VisualDensity(horizontal: -4),
                    icon: Icon(
                      TablerIcons.x,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                      size: 24.0,
                      weight: 1.5,
                    ),
                    tooltip: AppLocalizations.of(context)!.removeFromPlaylistTooltip,
                    onPressed: () {
                      FeedbackHelper.feedback(FeedbackType.heavy);
                      onRemoveFromList?.call();
                    },
                  ),
                if (features.contains(TrackListItemFeatures.restoreButton))
                  IconButton(
                    visualDensity: VisualDensity(horizontal: -4),
                    icon: Icon(
                      TablerIcons.arrow_back_up,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                      size: 24.0,
                      weight: 1.5,
                    ),
                    tooltip: AppLocalizations.of(context)!.restoreTrack,
                    onPressed: () {
                      FeedbackHelper.feedback(FeedbackType.heavy);
                      onRemoveFromList?.call();
                    },
                  ),
                if (showOverflowMenu)
                  OverflowMenuButton(
                    onPressed: () => showModalTrackMenu(context: context, item: baseItem, queueItem: queueItem),
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    label: AppLocalizations.of(context)!.menuButtonLabel,
                  ),
                if (features.contains(TrackListItemFeatures.dragHandle))
                  ReorderableDragStartListener(
                    index:
                        listIndex ??
                        0, // will briefly use 0 as index, but should resolve quickly enough for user not to notice
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: IconButtonWithSemantics(
                        visualDensity: VisualDensity(horizontal: -4),
                        icon: TablerIcons.menu_order,
                        onPressed: null,
                        label: AppLocalizations.of(context)!.dragToReorder,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          onTap: onTap,
        );
      },
    );

    return showPlaybackProgress
        ? Stack(
            children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.only(left: defaultTileHeight),
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: playbackProgress,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.1),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(albumCoverCornerRadius)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              listTile,
            ],
          )
        : listTile;
  }
}

class OverflowBuilder extends StatelessWidget {
  const OverflowBuilder({super.key, required this.hasOverflowed, required this.builder});

  final bool Function(BoxConstraints constraints) hasOverflowed;
  final Widget Function(BuildContext context, bool hasOverflowed) builder;

  @override
  Widget build(BuildContext context) {
    Widget? child;
    bool? overflowState;
    return LayoutBuilder(
      builder: (context, constraints) {
        bool newOverflow = hasOverflowed(constraints);
        if (overflowState != newOverflow || child == null) {
          child = builder(context, newOverflow);
          overflowState = newOverflow;
        }
        return child!;
      },
    );
  }
}
