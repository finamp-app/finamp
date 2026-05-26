import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';

import 'package:diacritic/diacritic.dart';

import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../AlbumScreen/track_list_tile.dart';
import '../first_page_progress_indicator.dart';
import '../global_snackbar.dart';
import '../new_page_progress_indicator.dart';
import 'alphabet_item_list.dart';
import 'item_collection_wrapper.dart';

// this is used to allow refreshing the music screen from other parts of the app, e.g. after deleting items from the server
final musicScreenRefreshStream = StreamController<void>.broadcast();

class MusicScreenTabView extends ConsumerStatefulWidget {
  const MusicScreenTabView({
    super.key,
    required this.tabContentType,
    this.searchTerm,
    required this.view,
    this.refresh,
    this.genreFilter,
    this.tabBarFiltered = false,
    this.sortByOverride,
    this.sortOrderOverride,
    this.isFavoriteOverride,
  });

  final TabContentType tabContentType;
  final String? searchTerm;
  final BaseItemDto? view;
  final MusicRefreshCallback? refresh;
  final BaseItemDto? genreFilter;
  final bool tabBarFiltered;
  final SortBy? sortByOverride;
  final SortOrder? sortOrderOverride;
  final bool? isFavoriteOverride;

  @override
  ConsumerState<MusicScreenTabView> createState() => _MusicScreenTabViewState();
}

// We use AutomaticKeepAliveClientMixin so that the view keeps its position after the tab is changed.
// https://stackoverflow.com/questions/49439047/how-to-preserve-widget-states-in-flutter-when-navigating-using-bottomnavigation
class _MusicScreenTabViewState extends ConsumerState<MusicScreenTabView>
    with AutomaticKeepAliveClientMixin<MusicScreenTabView> {
  // tabs on the music screen should be kept alive
  @override
  bool get wantKeepAlive => true;

  static const _pageSize = 100;

  final PagingController<int, BaseItemDto> _pagingController = PagingController(
    firstPageKey: 0,
    invisibleItemsThreshold: 70,
  );

  Future<List<BaseItemDto>>? offlineSortedItems;

  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _isarDownloader = GetIt.instance<DownloadsService>();
  StreamSubscription<void>? _musicScreenRefreshStreamSubscription;
  StreamSubscription<void>? _downloadsRefreshStreamSubscription;

  late AutoScrollController controller;
  int _requestedPageKey = -1;
  String? letterToSearch;
  Timer? timer;
  int? refreshHash;
  int refreshCount = 0;
  int fullyLoadedRefresh = -1;

  // This function just lets us easily set stuff to the getItems call we want.
  Future<void> _getPage(int pageKey) async {
    // The jump-to-letter widget and main view scrolling may generate duplicate page
    // requests.  Only fetch page once in these cases.
    if (pageKey <= _requestedPageKey) {
      return;
    }
    _requestedPageKey = pageKey;
    var settings = FinampSettingsHelper.finampSettings;
    if (settings.isOffline) {
      return _getPageOffline();
    }
    int localRefreshCount = refreshCount;
    try {
      final sortOrder =
          (widget.sortOrderOverride ?? settings.tabSortOrder[widget.tabContentType])?.toString() ??
          SortOrder.ascending.toString();
      final sortBy = widget.sortByOverride ?? settings.tabSortBy[widget.tabContentType];
      final newItems = await _jellyfinApiHelper.getItems(
        // starting with Jellyfin 10.9, only automatically created playlists will have a specific library as parent. user-created playlists will not be returned anymore
        // this condition fixes this by not providing a parentId when fetching playlists
        parentItem: widget.tabContentType.itemType == BaseItemDtoType.playlist ? null : widget.view,
        includeItemTypes: widget.tabContentType.itemType.jellyfinName,

        // If we're on the tracks tab, sort by "Album,SortName". This is what the
        // Jellyfin web client does. If this isn't the case, sort by "SortName".
        // If widget.sortBy is set, it is used instead.
        sortBy:
            sortBy?.jellyfinName(widget.tabContentType) ??
            (widget.tabContentType == TabContentType.tracks ? "Album,SortName" : "SortName"),
        sortOrder: sortOrder,
        searchTerm: widget.searchTerm?.trim(),
        filters:
            (widget.isFavoriteOverride == true || (widget.isFavoriteOverride == null && settings.onlyShowFavorites))
            ? "IsFavorite"
            : null,
        // "filters" are not implemented in the Jellyfin API Endpoint for Genres
        // but the bool "isFavorite" is, so we use it instead (but don't set it
        // to "false", because then it will actually exclude all favorites)
        isFavorite:
            (widget.tabContentType.itemType == BaseItemDtoType.genre &&
                (widget.isFavoriteOverride == true ||
                    (widget.isFavoriteOverride == null && settings.onlyShowFavorites)))
            ? true
            : null,
        // Prevent arbitrarily stopping at size of library when using random order by always using a 0 offset.  The order
        // of items in random requests are independent, so some items may be duplicated and others may be shown multiple
        // times, making the library size limit arbitrary.  If the library size is < _pageSize, all items are fetched in
        // a single request and each item will be present exactly once, so loading will stop as normal.
        startIndex: sortBy == SortBy.random ? 0 : pageKey,
        limit: _pageSize,
        artistType: settings.defaultArtistType,
        genreFilter: widget.genreFilter,
      );

      // Skip appending page if a refresh triggered while processing
      if (localRefreshCount == refreshCount && mounted) {
        if (newItems!.length < _pageSize) {
          _pagingController.appendLastPage(newItems);
          fullyLoadedRefresh = localRefreshCount;
        } else {
          _pagingController.appendPage(newItems, pageKey + newItems.length);
        }
        var localLetterToSearch = letterToSearch;
        if (localLetterToSearch != null) {
          scrollToLetter(localLetterToSearch);
        }
      }
    } catch (e) {
      // Ignore errors when logging out
      if (GetIt.instance<FinampUserHelper>().currentUser != null) {
        GlobalSnackbar.error(e);
      }
    }
  }

  Future<void> _getPageOffline() async {
    var settings = FinampSettingsHelper.finampSettings;
    int localRefreshCount = refreshCount;
    var artistInfoForType = (settings.defaultArtistType == ArtistType.albumArtist)
        ? BaseItemDtoType.album
        : BaseItemDtoType.track;

    List<DownloadStub> offlineItems;
    if (widget.tabContentType == TabContentType.tracks) {
      // If we're on the tracks tab, just get all of the downloaded items
      // We should probably try to page this, at least if we are sorting by name
      offlineItems = await _isarDownloader.getAllTracks(
        nameFilter: widget.searchTerm,
        viewFilter: widget.view?.id,
        nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
        onlyFavorites:
            (widget.isFavoriteOverride == true || (widget.isFavoriteOverride == null && settings.onlyShowFavorites)) &&
            settings.trackOfflineFavorites,
        genreFilter: widget.genreFilter,
      );
    } else {
      offlineItems = await _isarDownloader.getAllCollections(
        nameFilter: widget.searchTerm,
        baseTypeFilter: widget.tabContentType.itemType,
        fullyDownloaded: settings.onlyShowFullyDownloaded,
        viewFilter: widget.tabContentType == TabContentType.albums ? widget.view?.id : null,
        childViewFilter:
            (widget.tabContentType != TabContentType.albums && widget.tabContentType != TabContentType.playlists)
            ? widget.view?.id
            : null,
        nullableViewFilters: widget.tabContentType == TabContentType.albums && settings.showDownloadsWithUnknownLibrary,
        onlyFavorites:
            (widget.isFavoriteOverride == true || (widget.isFavoriteOverride == null && settings.onlyShowFavorites)) &&
            settings.trackOfflineFavorites,
        infoForType: (widget.tabContentType == TabContentType.artists) ? artistInfoForType : null,
        genreFilter: widget.tabContentType == TabContentType.playlists ? null : widget.genreFilter,
      );
    }

    var items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
    var sortBy = widget.sortByOverride ?? settings.tabSortBy[widget.tabContentType];
    // PlayCount and Last Played are not representative in Offline Mode
    // so we disable it and overwrite it with the Sort Name if it was selected
    if (sortBy == SortBy.playCount || sortBy == SortBy.datePlayed) {
      sortBy = SortBy.sortName;
    }
    final sortOrder = widget.sortOrderOverride ?? settings.tabSortOrder[widget.tabContentType];
    items = sortItems(items, sortBy, sortOrder);

    // Playlists use different genreIds due to their cross-library functionality.
    // In Online Mode, the api still returns correct data, but in Offline Mode,
    // we only have genres with their "libraryId" but playlists with their
    // "cross-library-genreIds", so we won't get any results. Therefore,
    // we have to load all playlists and manually filter by genreName.
    if (items.isNotEmpty && widget.genreFilter != null && widget.tabContentType == TabContentType.playlists) {
      items = filterItemsByGenreName(items, widget.genreFilter!);
    }

    // Skip appending page if a refresh triggered while processing
    if (localRefreshCount == refreshCount && mounted) {
      _pagingController.appendLastPage(items);
      fullyLoadedRefresh = localRefreshCount;
      var localLetterToSearch = letterToSearch;
      if (localLetterToSearch != null) {
        scrollToLetter(localLetterToSearch);
      }
    }
  }

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _getPage(pageKey);
    });
    controller = AutoScrollController(
      suggestedRowHeight: 72,
      viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.paddingOf(context).bottom),
      axis: Axis.vertical,
    );
    _musicScreenRefreshStreamSubscription = musicScreenRefreshStream.stream.listen((_) {
      _refresh();
    });
    _downloadsRefreshStreamSubscription = _isarDownloader.offlineDeletesStream.listen((event) {
      _refresh();
    });
    updateRefreshHash();

    ref.listenManual(finampSettingsProvider, (_, __) {
      updateRefreshHash();
    });

    super.initState();
  }

  @override
  void didUpdateWidget(MusicScreenTabView oldWidget) {
    updateRefreshHash();
    super.didUpdateWidget(oldWidget);
  }

  // Scrolls the list to the first occurrence of the letter in the list
  // If clicked in the # element, it goes to the first or last one item, depending on sort order
  void scrollToLetter(String letter) async {
    if (letter.isEmpty) return;

    letterToSearch = letter;
    var codePointToScrollTo = letter.toLowerCase().codeUnitAt(0);

    if (letter == '#') {
      codePointToScrollTo = 0;
    }

    //TODO use binary search to improve performance for already loaded pages
    var itemList = _pagingController.itemList!;
    SortBy? tabSortBy = FinampSettingsHelper.finampSettings.tabSortBy[widget.tabContentType];
    bool reversed = FinampSettingsHelper.finampSettings.tabSortOrder[widget.tabContentType] == SortOrder.descending;

    String getSortName(BaseItemDto item) {
      if (tabSortBy == SortBy.albumArtist) {
        final artists = item.albumArtists;
        return removeDiacritics(artists?.sortedBy((e) => e.name ?? '').map((e) => e.name ?? '').join(", ") ?? item.albumArtist ?? "");
      }

      return removeDiacritics(item.nameForSorting ?? "");
    }

    var targetIndex = itemList.indexWhere((item) {
      final sortName = getSortName(item).toLowerCase();
      if (sortName.isEmpty) return false;
      final itemCodePoint = sortName.codeUnitAt(0);
      return reversed ? itemCodePoint <= codePointToScrollTo : itemCodePoint >= codePointToScrollTo;
    });

    if (targetIndex != -1) {
      final originalIndex = itemList.indexOf(itemList[targetIndex]);

      timer?.cancel();
      await controller.scrollToIndex(
        originalIndex,
        duration: _getAnimationDurationForOffsetToIndex(originalIndex),
        preferPosition: AutoScrollPosition.begin,
      );

      letterToSearch = null;
      return;
    }

    // No match found in the currently loaded items.
    // If all pages are loaded, fall back to the last element in the list.
    timer?.cancel();
    if (fullyLoadedRefresh == refreshCount) {
      if (itemList.isNotEmpty) {
        final lastIndex = itemList.indexOf(itemList.last);
        await controller.scrollToIndex(
          lastIndex,
          duration: _getAnimationDurationForOffsetToIndex(lastIndex),
          preferPosition: AutoScrollPosition.begin,
        );
      }
      letterToSearch = null;
    } else {
      // More pages available - request the next page and scroll to the bottom
      // to trigger loading. Retry will happen via letterToSearch being set.
      timer = Timer(const Duration(seconds: 8), () {
        // If page loading takes too long, cancel search and allow image loading.
        letterToSearch = null;
      });

      _pagingController.notifyPageRequestListeners(_pagingController.nextPageKey!);

      if (MediaQuery.disableAnimationsOf(context)) {
        controller.jumpTo(controller.position.maxScrollExtent);
      } else {
        await controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        );
      }
    }
  }

  Duration _getAnimationDurationForOffsetToIndex(int index) {
    final renderedIndices = controller.tagMap.keys;
    if (renderedIndices.isEmpty) return Duration(milliseconds: 200);
    final medianIndex = renderedIndices.elementAt(renderedIndices.length ~/ 2);

    final duration = Duration(milliseconds: ((medianIndex - index).abs() / 50 * 300).clamp(200, 7500).round());
    return duration;
  }

  @override
  void dispose() {
    _musicScreenRefreshStreamSubscription?.cancel();
    _downloadsRefreshStreamSubscription?.cancel();
    _pagingController.dispose();
    timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    refreshCount++;
    _requestedPageKey = -1;
    // This makes refreshing actually work in error cases
    _pagingController.value = const PagingState(nextPageKey: 0, itemList: []);
    _pagingController.refresh();
  }

  void updateRefreshHash() {
    final settings = FinampSettingsHelper.finampSettings;
    var newRefreshHash = Object.hash(
      widget.searchTerm,
      settings.onlyShowFavorites,
      widget.isFavoriteOverride,
      settings.tabSortBy[widget.tabContentType],
      widget.sortByOverride,
      settings.tabSortOrder[widget.tabContentType],
      widget.sortOrderOverride,
      settings.onlyShowFullyDownloaded,
      widget.view?.id,
      settings.isOffline,
      settings.tabOrder,
      settings.trackOfflineFavorites,
      widget.genreFilter?.id,
    );
    if (refreshHash == null) {
      refreshHash = newRefreshHash;
    } else if (refreshHash != newRefreshHash) {
      _refresh();
      refreshHash = newRefreshHash;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    widget.refresh?.callback = _refresh;

    final emptyListIndicator = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.emptyFilteredListTitle,
            style: TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (widget.genreFilter != null && widget.tabContentType != TabContentType.genres)
            Text(
              AppLocalizations.of(context)!.genreNoItems(widget.tabContentType.name),
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            )
          else ...[
            Text(
              AppLocalizations.of(context)!.emptyFilteredListSubtitle,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            CTAMedium(
              icon: TablerIcons.filter_x,
              text: AppLocalizations.of(context)!.resetFiltersButton,
              onPressed: () {
                FinampSetters.setOnlyShowFavorites(DefaultSettings.onlyShowFavorites);
                FinampSetters.setOnlyShowFullyDownloaded(DefaultSettings.onlyShowFullyDownloaded);
              },
            ),
          ],
        ],
      ),
    );
    var sortBy = widget.sortByOverride ?? ref.watch(finampSettingsProvider.tabSortBy(widget.tabContentType));
    var tabContent =
        ref.watch(finampSettingsProvider.contentViewType) == ContentViewType.list ||
            widget.tabContentType == TabContentType.tracks
        ? PagedListView<int, BaseItemDto>.separated(
            pagingController: _pagingController,
            scrollController: controller,
            physics: _DeferredLoadingAlwaysScrollableScrollPhysics(tabState: this),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            builderDelegate: PagedChildBuilderDelegate<BaseItemDto>(
              itemBuilder: (context, item, index) {
                // Use right padding inherited from fast scroller minus
                // built-in icon padding
                return Padding(
                  padding: EdgeInsets.only(right: max(0, MediaQuery.paddingOf(context).right - 20)),
                  child: CachedBuilder(
                    key: ValueKey(item.id),
                    cacheKey: (item.id, index),
                    builder: (context) {
                      return AutoScrollTag(
                        key: ValueKey(index),
                        controller: controller,
                        index: index,
                        child: widget.tabContentType == TabContentType.tracks
                            ? TrackListTile(
                                item: item,
                                isTrack: true,
                                index: index,
                                isShownInSearchOrHistory: widget.searchTerm != null,
                                // when the tabBar was filtered and we only have the tracks tab,
                                // we can allow Dismiss gestures in the track list
                                allowDismiss: widget.tabBarFiltered,
                                genreFilter: widget.genreFilter,
                                isOnGenreScreen: (widget.genreFilter != null) ? true : false,
                                parentItem: widget.genreFilter,
                                forceAlbumArtists: (sortBy == SortBy.albumArtist),
                                adaptiveAdditionalInfoSortBy: sortBy,
                                // since we can't re-create the current random sorting, we simply pass the pre-sorted tracks along
                                // only done in offline mode since online mode doesn't support playing the tab contents in order anyway
                                children: FinampSettingsHelper.finampSettings.isOffline && sortBy == SortBy.random
                                    ? _pagingController.itemList
                                    : null,
                              )
                            : ItemCollectionWrapper(
                                item: item,
                                isPlaylist: widget.tabContentType == TabContentType.playlists,
                                genreFilter: widget.genreFilter,
                                adaptiveAdditionalInfoSortBy: sortBy,
                                showFavoriteIconOnlyWhenFilterDisabled: true,
                              ),
                      );
                    },
                  ),
                );
              },
              firstPageProgressIndicatorBuilder: (_) => const FirstPageProgressIndicator(),
              newPageProgressIndicatorBuilder: (_) => const NewPageProgressIndicator(),
              noItemsFoundIndicatorBuilder: (_) => emptyListIndicator,
            ),
            separatorBuilder: (context, index) => const SizedBox.shrink(),
          )
        : PagedGridView(
            pagingController: _pagingController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            scrollController: controller,
            physics: _DeferredLoadingAlwaysScrollableScrollPhysics(tabState: this),
            builderDelegate: PagedChildBuilderDelegate<BaseItemDto>(
              itemBuilder: (context, item, index) {
                return CachedBuilder(
                  key: ValueKey(item.id),
                  cacheKey: (item.id, index),
                  builder: (context) {
                    return AutoScrollTag(
                      key: ValueKey(index),
                      controller: controller,
                      index: index,
                      child: ItemCollectionWrapper(
                        item: item,
                        isPlaylist: widget.tabContentType == TabContentType.playlists,
                        isGrid: true,
                        genreFilter: widget.genreFilter,
                      ),
                    );
                  },
                );
              },
              firstPageProgressIndicatorBuilder: (_) => const FirstPageProgressIndicator(),
              newPageProgressIndicatorBuilder: (_) => const NewPageProgressIndicator(),
              noItemsFoundIndicatorBuilder: (_) => emptyListIndicator,
            ),
            gridDelegate: FinampSettingsHelper.finampSettings.useFixedSizeGridTiles
                ? SliverGridDelegateWithFixedSizeTiles(
                    gridTileSize: FinampSettingsHelper.finampSettings.fixedGridTileSize.toDouble(),
                  )
                : SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.orientationOf(context) == Orientation.landscape
                        ? FinampSettingsHelper.finampSettings.contentGridViewCrossAxisCountLandscape
                        : FinampSettingsHelper.finampSettings.contentGridViewCrossAxisCountPortrait,
                  ),
          );

    var showFastScroller = ref.watch(finampSettingsProvider.showFastScroller);
    var tabSortBy = ref.watch(finampSettingsProvider.tabSortBy(widget.tabContentType));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child:
          showFastScroller &&
              (widget.sortByOverride == SortBy.sortName ||
                  widget.sortByOverride == SortBy.albumArtist ||
                  widget.sortByOverride == null && (tabSortBy == SortBy.sortName || tabSortBy == SortBy.albumArtist))
          ? AlphabetList(
              callback: scrollToLetter,
              scrollController: controller,
              sortOrder: (widget.sortOrderOverride != null)
                  ? widget.sortOrderOverride ?? SortOrder.ascending
                  : (ref.watch(finampSettingsProvider.tabSortOrder(widget.tabContentType)) ?? SortOrder.ascending),
              child: tabContent,
            )
          : tabContent,
    );
  }
}

class MusicRefreshCallback {
  void call() => callback?.call();
  void Function()? callback;
}

class SliverGridDelegateWithFixedSizeTiles extends SliverGridDelegate {
  SliverGridDelegateWithFixedSizeTiles({required this.gridTileSize});

  final double gridTileSize;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    int crossAxisCount = (constraints.crossAxisExtent / gridTileSize).floor();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = max(1, crossAxisCount);
    final double crossAxisSpacing = (constraints.crossAxisExtent / crossAxisCount);
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: gridTileSize,
      crossAxisStride: crossAxisSpacing,
      childMainAxisExtent: gridTileSize,
      childCrossAxisExtent: gridTileSize,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithFixedSizeTiles oldDelegate) {
    return oldDelegate.gridTileSize != gridTileSize;
  }
}

class _DeferredLoadingAlwaysScrollableScrollPhysics extends AlwaysScrollableScrollPhysics {
  const _DeferredLoadingAlwaysScrollableScrollPhysics({super.parent, required this.tabState});

  final _MusicScreenTabViewState tabState;

  @override
  _DeferredLoadingAlwaysScrollableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _DeferredLoadingAlwaysScrollableScrollPhysics(parent: buildParent(ancestor), tabState: tabState);
  }

  @override
  bool recommendDeferredLoading(double velocity, ScrollMetrics metrics, BuildContext context) {
    if (tabState.letterToSearch != null) {
      return true;
    }
    return super.recommendDeferredLoading(velocity, metrics, context);
  }
}

List<BaseItemDto> sortItems(List<BaseItemDto> itemsToSort, SortBy? sortBy, SortOrder? sortOrder) {
  if (sortBy == SortBy.random) {
    itemsToSort.shuffle();
  } else {
    itemsToSort.sort((a, b) {
      switch (sortBy ?? SortBy.sortName) {
        case SortBy.sortName:
          if (a.nameForSorting == null || b.nameForSorting == null) {
            // Returning 0 is the same as both being the same
            return 0;
          } else {
            return a.nameForSorting!.compareTo(b.nameForSorting!);
          }
        case SortBy.album:
          if (a.album == null || b.album == null) {
            return 0;
          } else {
            return a.album!.compareTo(b.album!);
          }
        case SortBy.albumArtist:
          if (a.albumArtist == null || b.albumArtist == null) {
            return 0;
          } else {
            return a.albumArtist!.compareTo(b.albumArtist!);
          }
        case SortBy.artist:
          if (a.artists == null || b.artists == null) {
            return 0;
          } else {
            return a.artists!.sortedBy((e) => e).join(", ").compareTo(b.artists!.sortedBy((e) => e).join(", "));
          }
        case SortBy.communityRating:
          if (a.communityRating == null || b.communityRating == null) {
            return 0;
          } else {
            return a.communityRating!.compareTo(b.communityRating!);
          }
        case SortBy.criticRating:
          if (a.criticRating == null || b.criticRating == null) {
            return 0;
          } else {
            return a.criticRating!.compareTo(b.criticRating!);
          }
        case SortBy.datePlayed:
          final dateA = a.userData?.lastPlayedDate == null
              ? null
              : DateTime.tryParse(a.userData!.lastPlayedDate!.trim());
          final dateB = b.userData?.lastPlayedDate == null
              ? null
              : DateTime.tryParse(b.userData!.lastPlayedDate!.trim());
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        case SortBy.dateCreated:
          final dateA = a.dateCreated == null ? null : DateTime.tryParse(a.dateCreated!.trim());
          final dateB = b.dateCreated == null ? null : DateTime.tryParse(b.dateCreated!.trim());
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        case SortBy.premiereDate:
          final dateA = a.premiereDate == null ? null : DateTime.tryParse(a.premiereDate!.trim());
          final dateB = b.premiereDate == null ? null : DateTime.tryParse(b.premiereDate!.trim());
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return -1;
          if (dateB == null) return 1;
          return dateA.compareTo(dateB);
        case SortBy.playCount:
          if (a.userData?.playCount == null || b.userData?.playCount == null) {
            return 0;
          } else {
            return a.userData!.playCount.compareTo(b.userData!.playCount);
          }
        case SortBy.runtime:
          if (a.runTimeTicks == null || b.runTimeTicks == null) {
            return 0;
          } else {
            return a.runTimeTicks!.compareTo(b.runTimeTicks!);
          }
        // SortBy.random is handled outside this switch as per-comparison logic does not produce a good shuffle
        default:
          throw UnimplementedError("Unimplemented offline sort mode $sortBy");
      }
    });
  }

  return sortOrder == SortOrder.descending ? itemsToSort.reversed.toList() : itemsToSort;
}

// This function helps to sort artist tracks in order they appear in the album list
// There are scenarios where cached provider-data might return a shuffled resultset, I guess,
// so this function should definitely sort all artist tracks always the same
List<BaseItemDto> sortArtistTracks(List<BaseItemDto> items) {
  int _compareNullable<T extends Comparable>(T? a, T? b, {bool nullsFirst = false}) {
    if (a == null && b == null) return 0;
    if (a == null) return nullsFirst ? -1 : 1;
    if (b == null) return nullsFirst ? 1 : -1;
    return a.compareTo(b);
  }

  int _compareAlbum(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    final numRegex = RegExp(r'^(\d+)');
    final matchA = numRegex.firstMatch(a);
    final matchB = numRegex.firstMatch(b);

    if (matchA != null && matchB != null) {
      final numA = int.tryParse(matchA.group(1)!);
      final numB = int.tryParse(matchB.group(1)!);
      if (numA != null && numB != null) {
        final cmp = numA.compareTo(numB);
        if (cmp != 0) return cmp;
      }
    }
    // fallback to normal string comparison
    return a.compareTo(b);
  }

  items.sort((a, b) {
    // 1. PremiereDate
    final dateA = a.premiereDate == null ? null : DateTime.tryParse(a.premiereDate!.trim());
    final dateB = b.premiereDate == null ? null : DateTime.tryParse(b.premiereDate!.trim());
    final dateCompare = _compareNullable<DateTime>(dateA, dateB, nullsFirst: true);
    if (dateCompare != 0) return dateCompare;
    // 2. Album (numbers first)
    final albumCompare = _compareAlbum(a.album, b.album);
    if (albumCompare != 0) return albumCompare;
    // 3. ParentIndexNumber
    final parentIndexCompare = _compareNullable<int>(a.parentIndexNumber, b.parentIndexNumber);
    if (parentIndexCompare != 0) return parentIndexCompare;
    // 4. IndexNumber
    final indexCompare = _compareNullable<int>(a.indexNumber, b.indexNumber);
    if (indexCompare != 0) return indexCompare;
    // 5. SortName
    return _compareNullable<String>(a.sortName, b.sortName);
  });

  return items;
}

List<BaseItemDto> filterItemsByGenreName(List<BaseItemDto> items, BaseItemDto genreFilter) {
  if (genreFilter.name == null) return [];

  return items.where((item) {
    final assignedGenres = item.genreItems;
    if (assignedGenres == null) return false;

    return assignedGenres.any((genre) => genre.name == genreFilter.name);
  }).toList();
}

class CachedBuilder<T> extends StatefulWidget {
  const CachedBuilder({required this.builder, required this.cacheKey, super.key});

  final Widget Function(BuildContext context) builder;
  final T cacheKey;

  @override
  State<CachedBuilder<T>> createState() => _CachedBuilderState<T>();
}

class _CachedBuilderState<T> extends State<CachedBuilder<T>> {
  Widget? child;

  @override
  void didUpdateWidget(covariant CachedBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cacheKey != oldWidget.cacheKey) {
      child = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    child ??= widget.builder(context);
    return child!;
  }
}
