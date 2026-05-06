import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/MusicScreen/item_card.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/audio_service_helper.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/music_screen_provider.dart';
import '../AlbumScreen/track_list_tile.dart';
import '../first_page_progress_indicator.dart';
import '../new_page_progress_indicator.dart';
import 'alphabet_item_list.dart';
import 'item_wrapper.dart';

// this is used to allow refreshing the music screen from other parts of the app, e.g. after deleting items from the server
final musicScreenRefreshStream = StreamController<void>.broadcast();

class MusicScreenTabView extends ConsumerStatefulWidget {
  const MusicScreenTabView({
    super.key,
    required this.tabContentType,
    required this.view,
    this.refresh,
    this.tabBarFiltered = false,
    required this.sortAndFilterConfiguration,
  });

  final TabContentType tabContentType;
  final BaseItemDto? view;
  final MusicRefreshCallback? refresh;

  final bool tabBarFiltered;
  final SortAndFilterConfiguration sortAndFilterConfiguration;

  BaseItemDto? get genreFilter =>
      sortAndFilterConfiguration.filters.firstWhereOrNull((x) => x.type == ItemFilterType.genreFilter)?.extraBaseItem;

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

  //final PagingController<int, BaseItemDto> _pagingController = PagingController(
  //  firstPageKey: 0,
  //  invisibleItemsThreshold: 70,
  //);

  Future<List<BaseItemDto>>? offlineSortedItems;

  final _isarDownloader = GetIt.instance<DownloadsService>();
  StreamSubscription<void>? _musicScreenRefreshStreamSubscription;
  StreamSubscription<void>? _downloadsRefreshStreamSubscription;

  late AutoScrollController controller;
  String? letterToSearch;

  Timer? timer;

  @override
  void initState() {
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

    super.initState();
  }

  // Scrolls the list to the first occurrence of the letter in the list
  // If clicked in the # element, it goes to the first or last one item, depending on sort order
  void scrollToLetter(String letter) async {
    if (letter.isEmpty) return;

    letterToSearch = letter;
    var codePointToScrollTo = letter.toLowerCase().codeUnitAt(0);

    // Max code point is lower case z to increase the chance of seeing a character
    // past the target but below the ignore point
    final maxCodePoint = 'z'.codeUnitAt(0);

    if (letter == '#') {
      codePointToScrollTo = 0;
    }

    //TODO use binary search to improve performance for already loaded pages
    final state = ref.read(pageControl);
    final itemList = state.items ?? [];
    SortBy? tabSortBy = FinampSettingsHelper.finampSettings.tabSortBy[widget.tabContentType];
    bool reversed = FinampSettingsHelper.finampSettings.tabSortOrder[widget.tabContentType] == SortOrder.descending;
    for (var i = 0; i < itemList.length; i++) {
      String sortName;
      switch (tabSortBy) {
        case SortBy.albumArtist:
          sortName = itemList[i].albumArtist ?? "";
          break;
        default:
          sortName = itemList[i].nameForSorting ?? "";
          break;
      }
      if (sortName.isEmpty) continue; // assume empty names are at the start
      int itemCodePoint = sortName.toLowerCase().codeUnitAt(0);
      if (itemCodePoint <= maxCodePoint) {
        final comparisonResult = itemCodePoint - codePointToScrollTo;
        if (comparisonResult == 0) {
          timer?.cancel();
          await controller.scrollToIndex(
            i,
            duration: _getAnimationDurationForOffsetToIndex(i),
            preferPosition: AutoScrollPosition.begin,
          );

          letterToSearch = null;
          return;
        } else if (reversed ? comparisonResult < 0 : comparisonResult > 0) {
          // If the letter is before the current item, there was no previous match (letter doesn't seem to exist in library)
          // scroll to the previous item instead
          timer?.cancel();
          await controller.scrollToIndex(
            (i - 1).clamp(0, itemList.length - 1),
            // duration: scrollDuration,
            duration: _getAnimationDurationForOffsetToIndex(i),
            preferPosition: AutoScrollPosition.middle,
          );

          letterToSearch = null;
          return;
        }
      }
    }

    timer?.cancel();
    if (!state.hasNextPage) {
      letterToSearch = null;
    } else {
      timer = Timer(const Duration(seconds: 8), () {
        // If page loading takes >5 seconds, cancel search and allow image loading.
        letterToSearch = null;
      });

      ref.read(pageControl.notifier).newPage();
    }
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
    //_pagingController.dispose();
    timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    // TODO this has ref.watch, does it explode?
    if (!context.mounted) return;
    ref.read(pageControl.notifier).refresh();
    // TODO test error cases?
  }

  MusicScreenContentProvider get pageControl => musicScreenContentProvider(
    MusicScreenRequest(filter: widget.sortAndFilterConfiguration, library: widget.view, tabType: widget.tabContentType),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    widget.refresh?.callback = _refresh;
    if (letterToSearch != null) {
      scrollToLetter(letterToSearch!);
    }

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
    final itemPadding = calculateItemCollectionCardWidth(ref).$2;
    var tabContent =
        ref.watch(finampSettingsProvider.contentViewType) == ContentViewType.list ||
            widget.tabContentType == TabContentType.tracks
        ? SafeArea(
            child: PagedListView<int, BaseItemDto>.separated(
              state: ref.watch(pageControl),
              fetchNextPage: () {
                ref.read(pageControl.notifier).newPage();
              },
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
                                  key: ValueKey(item.id),
                                  item: item,
                                  index: index,
                                  // when the tabBar was filtered and we only have the tracks tab,
                                  // we can allow Dismiss gestures in the track list
                                  allowDismiss: widget.tabBarFiltered,
                                  genreFilter: widget.genreFilter,
                                  isOnGenreScreen: (widget.genreFilter != null) ? true : false,
                                  parentItem: widget.genreFilter,
                                  forceAlbumArtists: (widget.sortAndFilterConfiguration.sortBy == SortBy.albumArtist),
                                  adaptiveAdditionalInfoSortBy: widget.sortAndFilterConfiguration.sortBy,
                                  // since we can't re-create the current random sorting, we simply pass the pre-sorted tracks along
                                  // only done in offline mode since online mode doesn't support playing the tab contents in order anyway
                                  fetchChildren: () async {
                                    if (FinampSettingsHelper.finampSettings.startInstantMixForIndividualTracks) {
                                      final audioServiceHelper = GetIt.instance<AudioServiceHelper>();
                                      await audioServiceHelper.startInstantMixForItem(item);
                                      return null;
                                    }
                                    return ref.read(pageControl.notifier).loadSlice(index);
                                  },
                                )
                              : ItemWrapper(
                                  key: ValueKey(item.id),
                                  item: item,
                                  genreFilter: widget.genreFilter,
                                  adaptiveAdditionalInfoSortBy: widget.sortAndFilterConfiguration.sortBy,
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
                //noMoreItemsIndicatorBuilder: (_) => SizedBox(height: MediaQuery.paddingOf(context).bottom),
                invisibleItemsThreshold: 70,
              ),
              separatorBuilder: (context, index) => const SizedBox.shrink(),
            ),
          )
        : PagedGridView(
            state: ref.watch(pageControl),
            fetchNextPage: () {
              ref.read(pageControl.notifier).newPage();
            },
            padding: EdgeInsets.only(
              top: itemPadding,
              bottom: itemPadding,
              left: MediaQuery.paddingOf(context).left + itemPadding,
              // Grid is automatically adding one itemPadding to the right of all elements
              right: MediaQuery.paddingOf(context).right,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            showNewPageProgressIndicatorAsGridChild: false,
            showNewPageErrorIndicatorAsGridChild: false,
            showNoMoreItemsIndicatorAsGridChild: false,
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
                      child: ItemWrapper(
                        key: ValueKey(item.id),
                        item: item,
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
              noMoreItemsIndicatorBuilder: (_) => SizedBox(height: MediaQuery.paddingOf(context).bottom),
              invisibleItemsThreshold: 70,
            ),
            gridDelegate: MusicScreenGridLayout(ref: ref, contentType: widget.tabContentType),
          );

    var showFastScroller = ref.watch(finampSettingsProvider.showFastScroller);
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child:
          showFastScroller &&
              (widget.sortAndFilterConfiguration.sortBy == SortBy.sortName ||
                  widget.sortAndFilterConfiguration.sortBy == SortBy.albumArtist)
          ? AlphabetList(
              callback: scrollToLetter,
              scrollController: controller,
              sortOrder: widget.sortAndFilterConfiguration.sortOrder,
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

class MusicScreenGridLayout extends SliverGridDelegate {
  MusicScreenGridLayout({required WidgetRef ref, required TabContentType contentType}) {
    final widthData = calculateItemCollectionCardWidth(ref);
    itemWidth = widthData.$1;
    itemPadding = widthData.$2;
    itemHeight = calculateItemCollectionCardHeight(
      ref: ref,
      sectionInfo: null,
      itemType: contentType.itemType ?? BaseItemDtoType.album,
    );
  }

  late final double itemWidth;
  late final double itemHeight;
  late final double itemPadding;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    int crossAxisCount = ((constraints.crossAxisExtent + itemPadding) / (itemWidth + itemPadding)).round();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = max(1, crossAxisCount);
    final double crossAxisSpacing = constraints.crossAxisExtent / crossAxisCount;
    // Adjust height for smaller than max album images
    final mainAxisSpacing = itemHeight - itemWidth + crossAxisSpacing;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: mainAxisSpacing,
      crossAxisStride: crossAxisSpacing,
      childMainAxisExtent: mainAxisSpacing - itemPadding,
      childCrossAxisExtent: crossAxisSpacing - itemPadding,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(MusicScreenGridLayout oldDelegate) {
    return oldDelegate.itemWidth != itemWidth ||
        oldDelegate.itemHeight != itemHeight ||
        oldDelegate.itemPadding != itemPadding;
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
