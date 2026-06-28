import 'dart:math' as math;

import 'package:finamp/components/AlbumScreen/album_screen_content.dart';
import 'package:finamp/components/curated_item_filter_row.dart';
import 'package:finamp/components/item_collections_sliver_list.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

class TracksSection extends ConsumerStatefulWidget {
  const TracksSection({
    super.key,
    required this.parent,
    this.tracks,
    this.childrenForQueue,
    required this.tracksText,
    this.seeAllCallbackFunction,
    this.genreFilter,
    this.includeFilterRow = false,
    this.customFilterOrder,
    this.selectedFilter,
    this.disabledFilters,
    this.onFilterSelected,
    this.isOnArtistScreen = false,
    this.isOnGenreScreen = false,
  });

  final BaseItemDto parent;
  final List<BaseItemDto>? tracks;
  final List<BaseItemDto>? childrenForQueue;
  final String tracksText;
  final VoidCallback? seeAllCallbackFunction;
  final BaseItemDto? genreFilter;
  final bool includeFilterRow;
  final List<CuratedItemSelectionType>? customFilterOrder;
  final CuratedItemSelectionType? selectedFilter;
  final List<CuratedItemSelectionType>? disabledFilters;
  final void Function(CuratedItemSelectionType type)? onFilterSelected;
  final bool isOnArtistScreen;
  final bool isOnGenreScreen;

  @override
  ConsumerState<TracksSection> createState() => _TracksSectionState();
}

class _TracksSectionState extends ConsumerState<TracksSection> {
  bool _showTracks = true;
  bool _isExpandable = true;
  bool _manuallyClosed = false;

  @override
  void initState() {
    super.initState();
    _evaluateTrackVisibility();
  }

  @override
  void didUpdateWidget(covariant TracksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _evaluateTrackVisibility();
  }

  void _evaluateTrackVisibility() {
    final hasTracks = widget.tracks != null && widget.tracks!.isNotEmpty;
    final hasQueue = widget.childrenForQueue != null;

    if ((hasTracks && hasQueue) || widget.includeFilterRow) {
      if (!_showTracks || !_isExpandable) {
        setState(() {
          if (!_manuallyClosed) {
            _showTracks = true;
          }
          _isExpandable = true;
        });
      }
    } else {
      if (_showTracks || _isExpandable) {
        setState(() {
          _showTracks = false;
          _isExpandable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String emptyText = loc!.emptyFilteredListTitle;
    final itemType = BaseItemDtoType.fromItem(widget.parent);
    final isFavorites = widget.selectedFilter == CuratedItemSelectionType.favorites;
    final isPlayed =
        widget.selectedFilter == CuratedItemSelectionType.mostPlayed ||
        widget.selectedFilter == CuratedItemSelectionType.recentlyPlayed;

    String itemTypeKey = 'other';

    if (itemType == BaseItemDtoType.artist) {
      itemTypeKey = (widget.genreFilter != null) ? 'artistGenreFilter' : 'artist';
    } else if (itemType == BaseItemDtoType.genre) {
      itemTypeKey = 'genre';
    }
    if (isFavorites) {
      emptyText = loc.curatedItemsNoFavorites(itemTypeKey);
    } else if (isPlayed) {
      emptyText = loc.curatedItemsNotListenedYet(itemTypeKey);
    } else {
      emptyText = loc.emptyFilteredListTitle;
    }

    return SliverStickyHeader(
      header: Container(
        padding: EdgeInsets.fromLTRB(6, widget.parent.type == "MusicGenre" ? 12 : 0, 6, 0),
        color: Theme.of(context).colorScheme.surface,
        child: GestureDetector(
          onTap: () {
            if (_isExpandable) {
              setState(() {
                _manuallyClosed = _showTracks;
                _showTracks = !_showTracks;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isExpandable)
                        Transform.rotate(
                          angle: _showTracks ? 0 : -math.pi / 2,
                          child: const Icon(Icons.arrow_drop_down, size: 24),
                        ),
                      if (_isExpandable) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.tracksText,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.seeAllCallbackFunction != null)
                  GestureDetector(
                    onTap: widget.seeAllCallbackFunction,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.seeAll,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      sliver: _showTracks
          ? SliverMainAxisGroup(
              slivers: [
                if (widget.includeFilterRow)
                  buildCuratedItemFilterRow(
                    ref: ref,
                    parent: widget.parent,
                    filterListFor: BaseItemDtoType.track,
                    customFilterOrder: widget.customFilterOrder,
                    selectedFilter: widget.selectedFilter,
                    disabledFilters: widget.disabledFilters,
                    onFilterSelected: widget.onFilterSelected,
                  ),
                if (widget.tracks != null && widget.tracks!.isNotEmpty)
                  TracksSliverList(
                    childrenForList: widget.tracks!,
                    childrenForQueue: widget.childrenForQueue!,
                    adaptiveAdditionalInfoSortBy: widget.selectedFilter?.getSortBy(),
                    parent: widget.parent,
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                      child: Center(
                        child: Text(
                          emptyText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: (widget.parent.type != "MusicGenre") ? 14 : 0)),
              ],
            )
          : SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class CollectionsSection extends ConsumerStatefulWidget {
  const CollectionsSection({
    super.key,
    required this.parent,
    required this.itemsText,
    this.items,
    this.albumsShowYearAndDurationInstead = false,
    this.seeAllCallbackFunction,
    this.genreFilter,
    this.includeFilterRowFor,
    this.customFilterOrder,
    this.selectedFilter,
    this.disabledFilters,
    this.onFilterSelected,
  });

  final BaseItemDto parent;
  final String itemsText;
  final List<BaseItemDto>? items;
  final bool albumsShowYearAndDurationInstead;
  final VoidCallback? seeAllCallbackFunction;
  final BaseItemDto? genreFilter;
  final BaseItemDtoType? includeFilterRowFor;
  final List<CuratedItemSelectionType>? customFilterOrder;
  final CuratedItemSelectionType? selectedFilter;
  final List<CuratedItemSelectionType>? disabledFilters;
  final void Function(CuratedItemSelectionType type)? onFilterSelected;

  @override
  ConsumerState<CollectionsSection> createState() => _ItemsSectionState();
}

class _ItemsSectionState extends ConsumerState<CollectionsSection> {
  bool _showItems = true;
  bool _isExpandable = true;
  bool _manuallyClosed = false;

  @override
  void initState() {
    super.initState();
    _evaluateAlbumVisibility();
  }

  @override
  void didUpdateWidget(covariant CollectionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _evaluateAlbumVisibility();
  }

  void _evaluateAlbumVisibility() {
    final hasItems = widget.items != null && widget.items!.isNotEmpty;

    if (hasItems || widget.includeFilterRowFor != null) {
      if (!_showItems || !_isExpandable) {
        setState(() {
          if (!_manuallyClosed) {
            _showItems = true;
          }
          _isExpandable = true;
        });
      }
    } else {
      if (_showItems || _isExpandable) {
        setState(() {
          _showItems = false;
          _isExpandable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String emptyText = loc!.emptyFilteredListTitle;
    final itemType = BaseItemDtoType.fromItem(widget.parent);
    final isFavorites = widget.selectedFilter == CuratedItemSelectionType.favorites;
    final isPlayed =
        widget.selectedFilter == CuratedItemSelectionType.mostPlayed ||
        widget.selectedFilter == CuratedItemSelectionType.recentlyPlayed;

    String itemTypeKey = 'other';

    if (itemType == BaseItemDtoType.artist) {
      itemTypeKey = (widget.genreFilter != null) ? 'artistGenreFilter' : 'artist';
    } else if (itemType == BaseItemDtoType.genre) {
      itemTypeKey = 'genre';
    }
    if (isFavorites) {
      emptyText = loc.curatedItemsNoFavorites(itemTypeKey);
    } else if (isPlayed) {
      emptyText = loc.curatedItemsNotListenedYet(itemTypeKey);
    } else {
      emptyText = loc.emptyFilteredListTitle;
    }

    return SliverStickyHeader(
      header: Container(
        padding: EdgeInsets.fromLTRB(6, widget.parent.type == "MusicGenre" ? 12 : 0, 6, 0),
        color: Theme.of(context).colorScheme.surface,
        child: GestureDetector(
          onTap: () {
            if (_isExpandable) {
              setState(() {
                _manuallyClosed = _showItems;
                _showItems = !_showItems;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isExpandable)
                        Transform.rotate(
                          angle: _showItems ? 0 : -math.pi / 2,
                          child: const Icon(Icons.arrow_drop_down, size: 24),
                        ),
                      if (_isExpandable) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.itemsText,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                // "See All"
                if (widget.seeAllCallbackFunction != null)
                  GestureDetector(
                    onTap: widget.seeAllCallbackFunction,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.seeAll,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      sliver: _showItems
          ? SliverMainAxisGroup(
              slivers: [
                if (widget.includeFilterRowFor != null)
                  buildCuratedItemFilterRow(
                    ref: ref,
                    parent: widget.parent,
                    filterListFor: widget.includeFilterRowFor!,
                    customFilterOrder: widget.customFilterOrder,
                    selectedFilter: widget.selectedFilter,
                    disabledFilters: widget.disabledFilters,
                    onFilterSelected: widget.onFilterSelected,
                  ),
                if (widget.items != null && widget.items!.isNotEmpty)
                  CollectionsSliverList(
                    childrenForList: widget.items!,
                    parent: widget.parent,
                    genreFilter: widget.genreFilter,
                    albumShowsYearAndDurationInstead: widget.albumsShowYearAndDurationInstead,
                    adaptiveAdditionalInfoSortBy: widget.selectedFilter?.getSortBy(),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                      child: Center(
                        child: Text(
                          emptyText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: (widget.parent.type != "MusicGenre") ? 14 : 0)),
              ],
            )
          : const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
