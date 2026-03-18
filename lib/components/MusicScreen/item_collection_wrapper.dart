import 'dart:async';

import 'package:finamp/components/MusicScreen/item_collection_card.dart';
import 'package:finamp/components/MusicScreen/item_collection_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/album_menu.dart';
import 'package:finamp/menus/artist_menu.dart';
import 'package:finamp/menus/genre_menu.dart';
import 'package:finamp/menus/playlist_menu.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/screens/genre_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

/// This widget is kind of a wrapper around ItemCollectionCard and ItemCollectionListTile.
/// It gets used for albums, artists, genres and playlists.
/// Depending on the values given, a list tile or a card will be returned. This
/// widget exists to handle the dropdown stuff and other stuff shared between
/// the two widgets.
class ItemCollectionWrapper extends ConsumerStatefulWidget {
  const ItemCollectionWrapper({
    super.key,
    required this.item,
    required this.isPlaylist,
    this.parentType,
    this.onTap,
    this.isGrid = false,
    this.genreFilter,
    this.albumShowsYearAndDurationInstead = false,
    this.adaptiveAdditionalInfoSortBy,
    this.showFavoriteIconOnlyWhenFilterDisabled = false,
  });

  /// The item to show in the widget.
  final BaseItemDto item;

  /// The parent type of the item. Used to change onTap functionality for stuff
  /// like artists.
  final String? parentType;

  /// Used to differentiate between albums and playlists, since they use the same internal logic and widgets
  final bool isPlaylist;

  /// A custom onTap can be provided to override the default value, which is to
  /// open the item's album/artist/genre/playlist screen.
  final void Function()? onTap;

  /// If specified, use cards instead of list tiles. Use this if you want to use
  /// this widget in a grid view.
  final bool isGrid;

  /// If a genre filter is specified, it will propagate down to for example the ArtistScreen,
  /// showing only tracks and albums of that artist that match the genre filter
  final BaseItemDto? genreFilter;

  // If this is true and the item is an album, the release year and album duration
  // will be shown as subtitle instead of the album artists
  final bool albumShowsYearAndDurationInstead;

  // If a SortBy is passed, the subtitle row in list view will display the matching
  // info (i.e. runtime or release date) before the actual default subtitle.
  final SortBy? adaptiveAdditionalInfoSortBy;

  // If this is true, the red favorite icon that marks your favorites will
  // only be shown when the favorite filter on the MusicScreen is disabled
  // We want to always display the favorite indicator icon on other screens
  // so this defaults to false.
  final bool showFavoriteIconOnlyWhenFilterDisabled;

  @override
  ConsumerState<ItemCollectionWrapper> createState() => _ItemCollectionWrapperState();
}

class _ItemCollectionWrapperState extends ConsumerState<ItemCollectionWrapper> {
  late BaseItemDto mutableItem;

  final finampUserHelper = GetIt.instance<FinampUserHelper>();

  late void Function() onTap;
  late AppLocalizations local;

  @override
  void initState() {
    super.initState();
    mutableItem = widget.item;

    // this is jank lol
    onTap =
        widget.onTap ??
        () {
          if (mutableItem.type == "MusicArtist") {
            final artistGenreFilter = ref.watch(finampSettingsProvider.genreFilterArtistScreens);
            Navigator.of(context).push(
              MaterialPageRoute<ArtistScreen>(
                builder: (_) =>
                    ArtistScreen(widgetArtist: mutableItem, genreFilter: artistGenreFilter ? widget.genreFilter : null),
              ),
            );
          } else if (mutableItem.type == "MusicGenre") {
            Navigator.of(context).pushNamed(GenreScreen.routeName, arguments: mutableItem);
          } else if (mutableItem.type == "Playlist") {
            final playlistGenreFilter = ref.watch(finampSettingsProvider.genreFilterPlaylists);
            Navigator.of(context).push(
              MaterialPageRoute<AlbumScreen>(
                builder: (_) =>
                    AlbumScreen(parent: mutableItem, genreFilter: playlistGenreFilter ? widget.genreFilter : null),
              ),
            );
          } else if (mutableItem.type == "AudioBook") {
            // AudioBook items are single audio files — play them directly.
            final queueService = GetIt.instance<QueueService>();
            queueService.startPlayback(
              items: [mutableItem],
              startingIndex: 0,
              order: FinampPlaybackOrder.linear,
              source: QueueItemSource.fromBaseItem(mutableItem),
            );
          } else {
            Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: mutableItem);
          }
        };
  }

  @override
  Widget build(BuildContext context) {
    local = AppLocalizations.of(context)!;

    return Padding(
      padding: widget.isGrid ? Theme.of(context).cardTheme.margin ?? const EdgeInsets.all(4.0) : EdgeInsets.zero,
      child: GestureDetector(
        onTapDown: (_) {
          // Begin precalculating theme for menu
          ref.listenManual(finampThemeProvider(ThemeInfo(widget.item)), (_, __) {});
        },
        onLongPressStart: (details) => openItemMenu(context: context, item: widget.item),
        onSecondaryTapDown: (details) => openItemMenu(context: context, item: widget.item),
        child: widget.isGrid
            ? ItemCollectionCard(item: mutableItem, onTap: onTap, parentType: widget.parentType)
            : ItemCollectionListTile(
                item: mutableItem,
                onTap: onTap,
                parentType: widget.parentType,
                albumShowsYearAndDurationInstead: widget.albumShowsYearAndDurationInstead,
                adaptiveAdditionalInfoSortBy: widget.adaptiveAdditionalInfoSortBy,
                showFavoriteIconOnlyWhenFilterDisabled: widget.showFavoriteIconOnlyWhenFilterDisabled,
              ),
      ),
    );
  }
}

void openItemMenu({
  required BuildContext context,
  required BaseItemDto item,
  FinampStorableQueueInfo? queueInfo,
}) async {
  unawaited(Feedback.forLongPress(context));

  switch (BaseItemDtoType.fromItem(item)) {
    case BaseItemDtoType.artist:
      await showModalArtistMenu(context: context, baseItem: item, queueInfo: queueInfo);
      break;
    case BaseItemDtoType.genre:
      await showModalGenreMenu(context: context, baseItem: item, queueInfo: queueInfo);
      break;
    case BaseItemDtoType.playlist:
      await showModalPlaylistMenu(context: context, baseItem: item, queueInfo: queueInfo);
      break;
    case BaseItemDtoType.track:
      await showModalTrackMenu(context: context, item: item, queueInfo: queueInfo);
      break;
    case BaseItemDtoType.album:
      await showModalAlbumMenu(context: context, item: item, queueInfo: queueInfo);
      break;
    default:
      // Do nothing for unsupported item types
      break;
  }
}
