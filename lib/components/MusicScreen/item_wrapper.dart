import 'dart:async';

import 'package:finamp/components/MusicScreen/item_card.dart';
import 'package:finamp/components/MusicScreen/item_collection_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/album_menu.dart';
import 'package:finamp/menus/artist_menu.dart';
import 'package:finamp/menus/genre_menu.dart';
import 'package:finamp/menus/playlist_menu.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/screens/genre_screen.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

/// This is a wrapper around ItemCollectionCard and ItemCollectionListTile.
/// It receives an item, and automatically handles displaying the item appropriately.
/// Depending on the values given, a list tile or a card will be returned.
class ItemWrapper extends ConsumerStatefulWidget {
  const ItemWrapper({
    super.key,
    required this.item,
    this.onTap,
    this.isGrid = false,
    this.genreFilter,
    this.albumShowsYearAndDurationInstead = false,
    this.adaptiveAdditionalInfoSortBy,
    this.showFavoriteIconOnlyWhenFilterDisabled = false,
    this.interactive = true,
    this.forceText = false,
    this.source,
  });

  /// The item to show in the widget.
  final BaseItemDto item;

  /// A custom onTap can be provided to override the default value, which is to
  /// open the item's album/artist/genre/playlist screen.
  final void Function()? onTap;

  /// If specified, use cards instead of list tiles. Use this if you want to use
  /// this widget in a grid view.
  final bool isGrid;

  /// Forces text to be shown in grid mode, even if showTextOnGridView is false
  final bool forceText;

  /// If a genre filter is specified, it will propagate down to for example the ArtistScreen,
  /// showing only tracks and albums of that artist that match the genre filter
  final BaseItemDto? genreFilter;

  /// If this is true and the item is an album, the release year and album duration
  /// will be shown as subtitle instead of the album artists
  final bool albumShowsYearAndDurationInstead;

  /// If a SortBy is passed, the subtitle row in list view will display the matching
  /// info (i.e. runtime or release date) before the actual default subtitle.
  final SortBy? adaptiveAdditionalInfoSortBy;

  /// If this is true, the red favorite icon that marks your favorites will
  /// only be shown when the favorite filter on the MusicScreen is disabled
  /// We want to always display the favorite indicator icon on other screens
  /// so this defaults to false.
  final bool showFavoriteIconOnlyWhenFilterDisabled;

  /// If this is false, the item will not be interactive (no onTap, no menu on long press)
  /// This is useful for read-only displays of items like previews
  final bool interactive;

  /// Used to pass a source if the context isn't enough to determine it
  final QueueItemSource? source;

  @override
  ConsumerState<ItemWrapper> createState() => _ItemCollectionWrapperState();
}

class _ItemCollectionWrapperState extends ConsumerState<ItemWrapper> {
  late BaseItemDto mutableItem;

  final finampUserHelper = GetIt.instance<FinampUserHelper>();

  late void Function() onTap;
  late AppLocalizations local;

  @override
  void initState() {
    super.initState();
    mutableItem = widget.item;

    onTap = widget.interactive
        ? widget.onTap ??
              () {
                FeedbackHelper.feedback(FeedbackType.selection);
                switch (BaseItemDtoType.fromItem(mutableItem)) {
                  case BaseItemDtoType.track:
                    showModalTrackMenu(context: context, item: mutableItem, source: widget.source);
                    break;
                  case BaseItemDtoType.artist:
                    Navigator.of(context).push(
                      MaterialPageRoute<ArtistScreen>(
                        builder: (_) => ArtistScreen(
                          widgetArtist: mutableItem,
                          genreFilter: (ref.watch(finampSettingsProvider.genreFilterArtistScreens))
                              ? widget.genreFilter
                              : null,
                        ),
                      ),
                    );
                    break;
                  case BaseItemDtoType.genre:
                    Navigator.of(context).pushNamed(GenreScreen.routeName, arguments: mutableItem);
                    break;
                  case BaseItemDtoType.playlist:
                    Navigator.of(context).push(
                      MaterialPageRoute<AlbumScreen>(
                        builder: (_) => AlbumScreen(
                          parent: mutableItem,
                          genreFilter: (ref.watch(finampSettingsProvider.genreFilterPlaylists))
                              ? widget.genreFilter
                              : null,
                        ),
                      ),
                    );
                    break;
                  default:
                    Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: mutableItem);
                    return;
                }
              }
        : () {};
  }

  @override
  Widget build(BuildContext context) {
    local = AppLocalizations.of(context)!;

    return GestureDetector(
      onTapDown: (_) {
        if (!widget.interactive) return;
        // Begin precalculating theme for menu
        ref.listenManual(finampThemeProvider(ThemeInfo(widget.item)), (_, __) {});
      },
      onLongPressStart: (details) => widget.interactive ? openItemMenu(context: context, item: widget.item) : null,
      onSecondaryTapDown: (details) => widget.interactive ? openItemMenu(context: context, item: widget.item) : null,
      child: widget.isGrid
          ? ItemCard(item: mutableItem, onTap: onTap, forceText: widget.forceText)
          : ItemCollectionListTile(
              item: mutableItem,
              onTap: onTap,
              albumShowsYearAndDurationInstead: widget.albumShowsYearAndDurationInstead,
              adaptiveAdditionalInfoSortBy: widget.adaptiveAdditionalInfoSortBy,
              showFavoriteIconOnlyWhenFilterDisabled: widget.showFavoriteIconOnlyWhenFilterDisabled,
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
      await showModalAlbumMenu(context: context, item: Album.fromItem(item), queueInfo: queueInfo);
      break;
    default:
      // Do nothing for unsupported item types
      break;
  }
}
