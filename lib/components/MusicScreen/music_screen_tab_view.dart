import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:diacritic/diacritic.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/MusicScreen/item_card.dart';
import 'package:finamp/components/QueueRestoreScreen/queue_restore_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/music_screen_provider.dart';
import '../AlbumScreen/track_list_tile.dart';
import 'alphabet_item_list.dart';
import 'first_page_progress_indicator.dart';
import 'item_wrapper.dart';
import 'new_page_error_indicator.dart';
import 'new_page_progress_indicator.dart';

// this is used to allow refreshing the music screen from other parts of the app, e.g. after deleting items from the server
final musicScreenRefreshStream = StreamController<void>.broadcast();

class MusicScreenTabView extends ConsumerStatefulWidget {
  const MusicScreenTabView({super.key, required this.displayable, this.refresh, this.allowTrackGestures = false});

  // TODO does it even make sense to allow things this generic?  How much simplification would going from this to
  // moving everythign that isn't an actual music screen back out of here?
  final FinampDisplayable<FinampDisplayableOrPlayable> displayable;
  final MusicRefreshCallback? refresh;

  final bool allowTrackGestures;

  SortAndFilterConfiguration get sortConfig => displayable is FinampSortable
      ? (displayable as FinampSortable).sortConfig
      : displayable is FinampPlayableDto
      ? SortAndFilterConfiguration.defaultForItem((displayable as FinampPlayableDto).item)
      : SortAndFilterConfiguration.defaultSort;

  ContentType? get contentType => switch (displayable) {
    MusicScreenPlayable(tab: var tab) => tab,
    _ => null,
  };

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

    if (letter == '#') {
      codePointToScrollTo = 0;
    }

    //TODO use binary search to improve performance for already loaded pages
    final state = ref.read(pageControl);
    final itemList = state.items ?? [];
    SortBy? tabSortBy = widget.sortConfig.sortBy;
    bool reversed = widget.sortConfig.sortOrder == SortOrder.descending;
    for (var i = 0; i < itemList.length; i++) {
      String sortName;
      switch (itemList[i]) {
        case FinampPlayableDto(item: var baseItem):
          switch (tabSortBy) {
            case SortBy.albumArtist:
              sortName =
                  baseItem.albumArtists?.sortedBy((e) => e.name ?? '').map((e) => e.name ?? '').join(", ") ??
                  baseItem.albumArtist ??
                  "";
              break;
            default:
              sortName = baseItem.nameForSorting ?? "";
              break;
          }
        case FinampPlayable playable:
          sortName = playable.source.name.getLocalized(context.l10n);
        case LatestQueues queue:
          // TODO: Handle this case.
          throw UnsupportedError("This shouldn't happen.");
      }
      sortName = removeDiacritics(sortName).toLowerCase();
      if (sortName.isEmpty) continue; // assume empty names are at the start
      int itemCodePoint = sortName.codeUnitAt(0);
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

    timer?.cancel();
    if (!state.hasNextPage) {
      letterToSearch = null;
    } else {
      timer = Timer(const Duration(seconds: 8), () {
        // If page loading takes too long, cancel search and allow image loading.
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

  void _retry() {
    if (!context.mounted) return;
    ref.read(pageControl.notifier).retry();
  }

  PagedContentProvider get pageControl => pagedContentProvider(widget.displayable);

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
          if (widget.sortConfig.genreFilter != null && widget.contentType != ContentType.genres)
            Text(
              AppLocalizations.of(context)!.genreNoItems(widget.contentType?.name ?? ""),
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
            widget.contentType == ContentType.tracks ||
            widget.contentType == null
        ? SafeArea(
            top: false,
            bottom: false,
            child: PagedListView<int, FinampDisplayableOrPlayable>.separated(
              state: ref.watch(pageControl),
              fetchNextPage: () {
                ref.read(pageControl.notifier).newPage();
              },
              scrollController: controller,
              physics: _DeferredLoadingAlwaysScrollableScrollPhysics(tabState: this),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              builderDelegate: PagedChildBuilderDelegate<FinampDisplayableOrPlayable>(
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
                          child: switch (item) {
                            Track() => TrackListTile(
                              key: ValueKey(item.item.id),
                              item: item.item,
                              index: index,
                              // when the tabBar was filtered and we only have the tracks tab,
                              // we can allow Dismiss gestures in the track list
                              allowDismiss: widget.allowTrackGestures,
                              parentItem: widget.sortConfig.genreFilter != null
                                  ? ref.watch(itemByIdProvider(widget.sortConfig.genreFilter!.id)).value
                                  : null,
                              forceAlbumArtists: (widget.sortConfig.sortBy == SortBy.albumArtist),
                              adaptiveAdditionalInfoSortBy: widget.sortConfig.sortBy,
                              parentPlayable: ref.watch(finampSettingsProvider.startInstantMixForIndividualTracks)
                                  ? InstantMix(item.item)
                                  : widget.displayable is FinampPlayable
                                  ? (widget.displayable as FinampPlayable)
                                  : item,
                            ),
                            FinampPlayableDto() => ItemWrapper(
                              key: ValueKey(item.item.id),
                              item: item.item,
                              genreFilter: widget.sortConfig.genreFilter,
                              adaptiveAdditionalInfoSortBy: widget.sortConfig.sortBy,
                              showFavoriteIconOnlyWhenFilterDisabled: true,
                            ),
                            PlayableQueue() => QueueRestoreTile(info: item.queue),
                            LatestQueues() || PrecalculatedPlayable() || MusicScreenPlayable<FinampPlayableDto>() =>
                              throw UnsupportedError("Unsupported type $item"),
                          },
                        );
                      },
                    ),
                  );
                },
                firstPageProgressIndicatorBuilder: (_) => const FirstPageProgressIndicator(),
                newPageProgressIndicatorBuilder: (_) => const NewPageProgressIndicator(),
                noItemsFoundIndicatorBuilder: (_) => emptyListIndicator,
                newPageErrorIndicatorBuilder: (_) => NewPageErrorIndicator(onTap: _retry),
                firstPageErrorIndicatorBuilder: (_) => FirstPageErrorIndicator(onTap: _retry),
                noMoreItemsIndicatorBuilder: (_) => SizedBox(height: TrackListItemTile.defaultTileHeight / 2),
                invisibleItemsThreshold: 70,
              ),
              separatorBuilder: (context, index) => const SizedBox.shrink(),
            ),
          )
        : PagedGridView<int, FinampDisplayableOrPlayable>(
            // If we made it here, we must be in a non-track music screen, so pageControl should only return FinampPlayableItem
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
            builderDelegate: PagedChildBuilderDelegate<FinampDisplayableOrPlayable>(
              itemBuilder: (context, item, index) {
                // We only allow grid mode for FinampDisplayable<FinampPlayableItem>
                final baseItem = (item as FinampPlayableDto).item;
                return CachedBuilder(
                  key: ValueKey(baseItem.id),
                  cacheKey: (baseItem.id, index),
                  builder: (context) {
                    return AutoScrollTag(
                      key: ValueKey(index),
                      controller: controller,
                      index: index,
                      child: ItemWrapper(
                        key: ValueKey(baseItem.id),
                        item: baseItem,
                        isGrid: true,
                        genreFilter: widget.sortConfig.genreFilter,
                      ),
                    );
                  },
                );
              },
              firstPageProgressIndicatorBuilder: (_) => const FirstPageProgressIndicator(),
              newPageProgressIndicatorBuilder: (_) => const NewPageProgressIndicator(),
              noItemsFoundIndicatorBuilder: (_) => emptyListIndicator,
              noMoreItemsIndicatorBuilder: (_) => SizedBox(
                height: MediaQuery.paddingOf(context).bottom + ref.watch(finampSettingsProvider.gridImageSize) / 2,
              ),
              newPageErrorIndicatorBuilder: (_) => NewPageErrorIndicator(onTap: _retry),
              firstPageErrorIndicatorBuilder: (_) => FirstPageErrorIndicator(onTap: _retry),
              invisibleItemsThreshold: 70,
            ),
            gridDelegate: MusicScreenGridLayout(ref: ref, contentType: widget.contentType!),
          );

    var showFastScroller = ref.watch(finampSettingsProvider.showFastScroller);
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child:
          showFastScroller &&
              (widget.sortConfig.sortBy == SortBy.sortName || widget.sortConfig.sortBy == SortBy.albumArtist)
          ? AlphabetList(
              callback: scrollToLetter,
              scrollController: controller,
              sortOrder: widget.sortConfig.sortOrder,
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
  MusicScreenGridLayout({required WidgetRef ref, required ContentType contentType}) {
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
