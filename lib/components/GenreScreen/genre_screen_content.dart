import 'dart:async';

import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/GenreScreen/genre_count_column.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/curated_item_filter_row.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/services/genre_screen_provider.dart';
import 'package:finamp/components/curated_item_sections.dart';
import 'package:finamp/components/favorite_button.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/genre_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../AlbumScreen/download_button.dart';
import '../MusicScreen/sort_and_filter_row.dart';
import '../padded_custom_scrollview.dart';

class GenreScreenContent extends ConsumerStatefulWidget {
  const GenreScreenContent({super.key, required this.parent, this.library});

  final BaseItemDto parent;
  final BaseItemDto? library;

  @override
  ConsumerState<GenreScreenContent> createState() => _GenreScreenContentState();
}

class _GenreScreenContentState extends ConsumerState<GenreScreenContent> {
  JellyfinApiHelper jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  StreamSubscription<void>? _refreshStream;
  final Set<CuratedItemSelectionType> _disabledTrackFilters = {};
  final Set<CuratedItemSelectionType> _disabledAlbumFilters = {};
  final Set<CuratedItemSelectionType> _disabledArtistFilters = {};
  CuratedItemSelectionType? clickedCuratedItemSelectionTypeTracks;
  CuratedItemSelectionType? clickedCuratedItemSelectionTypeAlbums;
  CuratedItemSelectionType? clickedCuratedItemSelectionTypeArtists;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _refreshStream?.cancel();
    super.dispose();
  }

  void openSeeAll(ContentType tabContentType, {bool doOverride = true, CuratedItemSelectionType? itemSelectionType}) {
    bool isFavoriteOverride = false;
    SortBy? sortByOverride;
    SortOrder? sortOrderOverride;

    if (doOverride && ref.read(finampSettingsProvider.genreListsInheritSorting) && itemSelectionType != null) {
      switch (itemSelectionType) {
        case CuratedItemSelectionType.mostPlayed:
          sortByOverride = itemSelectionType.getSortBy();
          sortOrderOverride = SortOrder.descending;
          isFavoriteOverride = false;
        case CuratedItemSelectionType.favorites:
          sortByOverride = SortBy.random;
          sortOrderOverride = SortOrder.ascending;
          isFavoriteOverride = true;
        case CuratedItemSelectionType.random:
          sortByOverride = itemSelectionType.getSortBy();
          sortOrderOverride = SortOrder.ascending;
          isFavoriteOverride = false;
        case CuratedItemSelectionType.latestReleases:
          sortByOverride = itemSelectionType.getSortBy();
          sortOrderOverride = SortOrder.descending;
          isFavoriteOverride = false;
        case CuratedItemSelectionType.recentlyAdded:
          sortByOverride = itemSelectionType.getSortBy();
          sortOrderOverride = SortOrder.descending;
          isFavoriteOverride = false;
        case CuratedItemSelectionType.recentlyPlayed:
          sortByOverride = itemSelectionType.getSortBy();
          sortOrderOverride = SortOrder.descending;
          isFavoriteOverride = false;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<MusicScreen>(
        builder: (context) => MusicScreen(
          singleTabConfig: HomeScreenSectionConfiguration(
            base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: tabContentType),
            customSectionTitle: widget.parent.name,
            sortConfig: SortAndFilterController.trackSettings(tabContentType).resolveConfig().copyWith(
              sortBy: sortByOverride,
              sortOrder: sortOrderOverride,
              favoriteFilter: isFavoriteOverride ? true : null,
              genreFilter: widget.parent,
            ),
          ),
          hideGenreFilters: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final library = finampUserHelper.currentUser?.currentView;
    final loc = AppLocalizations.of(context)!;
    final genreCuratedItemSectionFilterOrder = ref.watch(finampSettingsProvider.genreItemSectionFilterChipOrder);
    final genreItemSectionsOrder = ref.watch(finampSettingsProvider.genreItemSectionsOrder);
    final bool autoSwitchItemCurationTypeEnabled = ref.watch(finampSettingsProvider.autoSwitchItemCurationType);

    /// There are individual fetch methods for each section on the genre screen. They all are handled
    /// by a single entry point provider "genreCuratedItemsProvider". This provider returns multiple values:
    /// the items themselves, the total count of all items of that specific type within this genre as well as
    /// the current ItemCurationType and a disabledFilterList. The genreCuratedItemsProvider uses a method
    /// in curated_items_filter_row.dart to get the next available filter as a fallback option in case that
    /// the current filter would return an empty result and auto-switching is enabled. It then re-tries
    /// with that next filter. The filters that would've returned an empty result get returned in the
    /// disabledFilters set, so we can pass them on to the UI to show them as disabled.
    final tracksAsync = ref.watch(genreCuratedItemsProvider(widget.parent, BaseItemDtoType.track, widget.library));
    final albumsAsync = ref.watch(genreCuratedItemsProvider(widget.parent, BaseItemDtoType.album, widget.library));
    final artistsAsync = ref.watch(genreCuratedItemsProvider(widget.parent, BaseItemDtoType.artist, widget.library));

    final (tracks, trackCount, genreCuratedItemSelectionTypeTracks, newDisabledTrackFilters) =
        tracksAsync.valueOrNull ?? (null, null, null, null);
    final (albums, albumCount, genreCuratedItemSelectionTypeAlbums, newDisabledAlbumFilters) =
        albumsAsync.valueOrNull ?? (null, null, null, null);
    final (artists, artistCount, genreCuratedItemSelectionTypeArtists, newDisabledArtistFilters) =
        artistsAsync.valueOrNull ?? (null, null, null, null);

    final isLoading = tracks == null || albums == null || artists == null;

    /// We add the new disabled filters to a local set, which we actually use. That's because otherwise,
    /// we would re-enable deactivated filters once the user selects a different filter that's available.
    /// But we want to keep disabled filters disabled until either a pull-refresh happens
    /// or the screen gets accessed again freshly.
    if (newDisabledTrackFilters != null) {
      _disabledTrackFilters.addAll(newDisabledTrackFilters);
    }
    if (newDisabledAlbumFilters != null) {
      _disabledAlbumFilters.addAll(newDisabledAlbumFilters);
    }
    if (newDisabledArtistFilters != null) {
      _disabledArtistFilters.addAll(newDisabledArtistFilters);
    }

    /// The currently active filter either has items (now) or the user has disabled auto-switching,
    /// so we can remove it from our disabled Set in case it was there before and show it as enabled.
    _disabledTrackFilters.remove(genreCuratedItemSelectionTypeTracks);
    _disabledAlbumFilters.remove(genreCuratedItemSelectionTypeAlbums);
    _disabledArtistFilters.remove(genreCuratedItemSelectionTypeArtists);

    /// In case the user selects an option that has no items and auto-switch is enabled,
    /// we want to show a snackbar message in addition to disabling the filter.
    if (autoSwitchItemCurationTypeEnabled &&
        clickedCuratedItemSelectionTypeTracks != null &&
        _disabledTrackFilters.contains(clickedCuratedItemSelectionTypeTracks)) {
      sendEmptyItemSelectionTypeMessage(
        context: context,
        typeSelected: clickedCuratedItemSelectionTypeTracks,
        messageFor: BaseItemDtoType.genre,
      );
      // When we've sent the message, we should reset the clicked value
      // so that we don't send it again on next state refresh
      clickedCuratedItemSelectionTypeTracks = null;
    }
    if (autoSwitchItemCurationTypeEnabled &&
        clickedCuratedItemSelectionTypeAlbums != null &&
        _disabledAlbumFilters.contains(clickedCuratedItemSelectionTypeAlbums)) {
      sendEmptyItemSelectionTypeMessage(
        context: context,
        typeSelected: clickedCuratedItemSelectionTypeAlbums,
        messageFor: BaseItemDtoType.genre,
      );
      clickedCuratedItemSelectionTypeAlbums = null;
    }
    if (autoSwitchItemCurationTypeEnabled &&
        clickedCuratedItemSelectionTypeArtists != null &&
        _disabledArtistFilters.contains(clickedCuratedItemSelectionTypeArtists)) {
      sendEmptyItemSelectionTypeMessage(
        context: context,
        typeSelected: clickedCuratedItemSelectionTypeArtists,
        messageFor: BaseItemDtoType.genre,
      );
      clickedCuratedItemSelectionTypeArtists = null;
    }

    final countsTextColor = IconTheme.of(context).color;
    final countsSubtitleColor = IconTheme.of(context).color!.withOpacity(0.6);
    final countsBorderColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.2);
    final countsBackgroundColor = Theme.of(context).colorScheme.surface;

    return PaddedCustomScrollview(
      slivers: <Widget>[
        SliverAppBar(
          title: Text(widget.parent.name ?? AppLocalizations.of(context)!.unknownName),
          pinned: true,
          centerTitle: false,
          leading: FinampAppBarBackButton(),
          actions: [
            FavoriteButton(item: widget.parent),
            if (!isLoading)
              DownloadButton(
                item: DownloadStub.fromFinampCollection(
                  FinampCollection(
                    type: FinampCollectionType.collectionWithLibraryFilter,
                    library: library,
                    item: widget.parent,
                  ),
                ),
                childrenCount: albumCount,
              ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                openItemMenu(context: context, item: widget.parent);
              },
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8, left: 10, right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: buildCountColumn(
                      count: albumCount,
                      label: AppLocalizations.of(context)!.albums,
                      onTap: () {
                        openSeeAll(ContentType.albums, doOverride: false);
                      },
                      textColor: countsTextColor,
                      subtitleColor: countsSubtitleColor,
                      borderColor: countsBorderColor,
                      backgroundColor: countsBackgroundColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: buildCountColumn(
                      count: trackCount,
                      label: AppLocalizations.of(context)!.tracks,
                      onTap: () {
                        openSeeAll(ContentType.tracks, doOverride: false);
                      },
                      textColor: countsTextColor,
                      subtitleColor: countsSubtitleColor,
                      borderColor: countsBorderColor,
                      backgroundColor: countsBackgroundColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: buildCountColumn(
                      count: artistCount,
                      label: ref
                          .watch(finampSettingsProvider.defaultArtistType)
                          .tabType
                          .toLocalisedString(context.l10n),
                      onTap: () {
                        openSeeAll(ref.watch(finampSettingsProvider.defaultArtistType).tabType, doOverride: false);
                      },
                      textColor: countsTextColor,
                      subtitleColor: countsSubtitleColor,
                      borderColor: countsBorderColor,
                      backgroundColor: countsBackgroundColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverToBoxAdapter(
          child: PlaybackActionRow(
            compactLayout: true,
            item: Genre.fromItem(widget.parent),
            popContext: false,
            trackCount: trackCount,
          ),
        ),
        if (!isLoading)
          ...genreItemSectionsOrder.map((type) {
            switch (type) {
              case GenreItemSections.tracks:
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  sliver: TracksSection(
                    parent: widget.parent,
                    tracks: tracks,
                    childrenForQueue: tracks,
                    lazyAddMoreTracksToQueue: true,
                    tracksText: (genreCuratedItemSelectionTypeTracks != null)
                        ? genreCuratedItemSelectionTypeTracks.toLocalisedSectionTitle(context, BaseItemDtoType.track)
                        : loc.tracks,
                    isOnGenreScreen: true,
                    seeAllCallbackFunction: () =>
                        openSeeAll(ContentType.tracks, itemSelectionType: genreCuratedItemSelectionTypeTracks),
                    includeFilterRow: true,
                    customFilterOrder: genreCuratedItemSectionFilterOrder,
                    selectedFilter: genreCuratedItemSelectionTypeTracks,
                    disabledFilters: _disabledTrackFilters.toList(),
                    onFilterSelected: (type) {
                      // We store the clicked type locally in addition to changing the setting,
                      // because we don't know if the provider might auto-switch to something else
                      // because of an empty result-list, but we want to show a message in that case.
                      clickedCuratedItemSelectionTypeTracks = type;
                      FinampSetters.setGenreCuratedItemSelectionTypeTracks(type);
                    },
                  ),
                );
              case GenreItemSections.albums:
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  sliver: CollectionsSection(
                    parent: widget.parent,
                    itemsText: (genreCuratedItemSelectionTypeAlbums != null)
                        ? genreCuratedItemSelectionTypeAlbums.toLocalisedSectionTitle(context, BaseItemDtoType.album)
                        : loc.albums,
                    items: albums,
                    seeAllCallbackFunction: () =>
                        openSeeAll(ContentType.albums, itemSelectionType: genreCuratedItemSelectionTypeAlbums),
                    includeFilterRowFor: BaseItemDtoType.album,
                    customFilterOrder: genreCuratedItemSectionFilterOrder,
                    selectedFilter: genreCuratedItemSelectionTypeAlbums,
                    disabledFilters: _disabledAlbumFilters.toList(),
                    onFilterSelected: (type) {
                      clickedCuratedItemSelectionTypeAlbums = type;
                      FinampSetters.setGenreCuratedItemSelectionTypeAlbums(type);
                    },
                  ),
                );
              case GenreItemSections.artists:
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  sliver: CollectionsSection(
                    parent: widget.parent,
                    itemsText: (genreCuratedItemSelectionTypeArtists != null)
                        ? genreCuratedItemSelectionTypeArtists.toLocalisedSectionTitle(context, BaseItemDtoType.artist)
                        : loc.artists,
                    items: artists,
                    // TODO should there be an album artist option?
                    seeAllCallbackFunction: () => openSeeAll(
                      ContentType.performingArtists,
                      itemSelectionType: genreCuratedItemSelectionTypeArtists,
                    ),
                    genreFilter: widget.parent,
                    includeFilterRowFor: BaseItemDtoType.artist,
                    customFilterOrder: genreCuratedItemSectionFilterOrder,
                    selectedFilter: genreCuratedItemSelectionTypeArtists,
                    disabledFilters: _disabledArtistFilters.toList(),
                    onFilterSelected: (type) {
                      clickedCuratedItemSelectionTypeArtists = type;
                      FinampSetters.setGenreCuratedItemSelectionTypeArtists(type);
                    },
                  ),
                );
            }
          }),
        if (!isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SimpleButton(
                      text: AppLocalizations.of(context)!.browsePlaylists.toUpperCase(),
                      textColor: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      icon: Icons.chevron_right,
                      iconPosition: IconPosition.end,
                      onPressed: () => openSeeAll(ContentType.playlists, doOverride: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
      ],
    );
  }
}
