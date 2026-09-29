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
import 'package:finamp/services/performance_benchmark_service.dart';
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
  StreamSubscription<PerformanceBenchmarkJumpCommand>? _benchmarkJumpSubscription;
  StreamSubscription<PerformanceBenchmarkTabCommand>? _benchmarkTabSubscription;
  StreamSubscription<PerformanceBenchmarkPageCommand>? _benchmarkPageSubscription;
  PerformanceBenchmarkJumpCommand? _activeBenchmarkJump;
  Stopwatch? _benchmarkAlphabetPageWait;
  PerformanceBenchmarkPageCommand? _activeBenchmarkPage;
  int _benchmarkPageInitialCount = 0;
  bool _benchmarkPageFrameScheduled = false;
  PerformanceBenchmarkSearchCommand? _lastCompletedSearchCommand;
  bool _benchmarkSearchFrameScheduled = false;
  PerformanceBenchmarkTabCommand? _activeBenchmarkTab;
  bool _benchmarkTabDataMarked = false;
  bool _benchmarkTabFrameScheduled = false;
  bool _startupReadyReported = false;
  bool _startupReadyFrameScheduled = false;

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
    _benchmarkTabSubscription = PerformanceBenchmarkService.instance.tabCommands.listen(_activateBenchmarkTab);
    final pendingTabCommand = PerformanceBenchmarkService.instance.activeTabCommand;
    if (pendingTabCommand != null) {
      _activateBenchmarkTab(pendingTabCommand);
    }

    _benchmarkPageSubscription = PerformanceBenchmarkService.instance.pageCommands.listen((command) {
      if (widget.contentType?.name != command.contentType) return;
      if (_activeBenchmarkPage != null) {
        command.completeError(StateError("Another benchmark page command is already active"), StackTrace.current);
        return;
      }
      final state = ref.read(pageControl);
      if (!state.hasNextPage) {
        PerformanceBenchmarkService.instance.mark(
          "page-no-next-page",
          values: {"contentType": command.contentType, "loadedItems": state.items?.length ?? 0},
        );
        command.complete(false);
        return;
      }
      _activeBenchmarkPage = command;
      _recordBenchmarkSortConfiguration();
      _benchmarkPageInitialCount = state.items?.length ?? 0;
      _benchmarkPageFrameScheduled = false;
      PerformanceBenchmarkService.instance.mark(
        "page-load-start",
        values: {"contentType": command.contentType, "loadedItems": _benchmarkPageInitialCount},
      );
      ref.read(pageControl.notifier).newPage();
    });

    _benchmarkJumpSubscription = PerformanceBenchmarkService.instance.jumpCommands.listen((command) {
      if (widget.contentType?.name != command.contentType) return;
      if (_activeBenchmarkJump != null) {
        command.completeError(StateError("Another benchmark alphabet jump is already active"), StackTrace.current);
        return;
      }
      final sortBy = widget.sortConfig.sortBy;
      final fastScrollerAvailable = sortBy == SortBy.sortName || sortBy == SortBy.albumArtist;
      _recordBenchmarkSortConfiguration();
      if (!fastScrollerAvailable) {
        final error = StateError("Fast scroller is not available for the current sort configuration");
        PerformanceBenchmarkService.instance.mark(
          "alphabet-jump-unavailable",
          values: {
            "contentType": command.contentType,
            "letter": command.letter,
            "sortBy": sortBy?.name ?? "none",
            "sortOrder": widget.sortConfig.sortOrder?.name ?? "none",
          },
        );
        command.completeError(error, StackTrace.current);
        return;
      }

      _activeBenchmarkJump = command;
      final benchmark = PerformanceBenchmarkService.instance;
      benchmark.mark("alphabet-jump-start", values: {"contentType": command.contentType, "letter": command.letter});
      benchmark.metric("alphabetJumpPagesLoaded", 0);
      unawaited(scrollToLetter(command.letter));
    });

    super.initState();
  }

  void _recordBenchmarkSortConfiguration() {
    final benchmark = PerformanceBenchmarkService.instance;
    benchmark.metric("sortBy", widget.sortConfig.sortBy?.name ?? "none");
    benchmark.metric("sortOrder", widget.sortConfig.sortOrder?.name ?? "none");
  }

  bool _matchesBenchmarkTab(PerformanceBenchmarkTabCommand command) {
    final type = widget.contentType;
    if (type == null) return false;
    if (command.contentType == "artists") {
      return type == ContentType.albumArtists ||
          type == ContentType.performingArtists ||
          type == ContentType.genericArtists;
    }
    return type.name == command.contentType;
  }

  void _activateBenchmarkTab(PerformanceBenchmarkTabCommand command) {
    if (!_matchesBenchmarkTab(command)) return;
    if (_activeBenchmarkTab != null && !identical(_activeBenchmarkTab, command)) {
      command.completeError(StateError("Another benchmark tab command is already active"), StackTrace.current);
      return;
    }

    _activeBenchmarkTab = command;
    _recordBenchmarkSortConfiguration();
    _benchmarkTabDataMarked = false;
    _benchmarkTabFrameScheduled = false;
    if (command.refresh) {
      PerformanceBenchmarkService.instance.mark(
        "ui-tab-refresh-start",
        values: {"contentType": widget.contentType?.name},
      );
      ref.read(pageControl.notifier).refresh();
    } else {
      PerformanceBenchmarkService.instance.mark(
        "ui-tab-warm-state-reused",
        values: {"contentType": widget.contentType?.name, "loadedItems": ref.read(pageControl).items?.length ?? 0},
      );
    }
  }

  void _maybeReportStartupScreenReady(PagingState<int, FinampDisplayableOrPlayable> state) {
    if (!PerformanceBenchmarkService.enabled ||
        _startupReadyReported ||
        _startupReadyFrameScheduled ||
        state.isLoading) {
      return;
    }

    final contentType = widget.contentType?.name;
    final selected = PerformanceBenchmarkService.instance.startupSelectedContentType;
    if (contentType == null || selected != contentType) return;

    // A completed empty result is still a usable screen. Only an unresolved
    // first page (items == null while another page is expected) is not ready.
    if (state.items == null && state.hasNextPage) return;

    _startupReadyFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupReadyFrameScheduled = false;
      if (!mounted || _startupReadyReported) return;

      final current = ref.read(pageControl);
      if (current.isLoading || (current.items == null && current.hasNextPage)) {
        return;
      }

      _startupReadyReported = true;
      PerformanceBenchmarkService.instance.reportStartupScreenReady(contentType);
    });
  }

  void _maybeFailBenchmarkCommands(PagingState<int, FinampDisplayableOrPlayable> state) {
    final error = state.error;
    if (error == null || state.isLoading) return;

    final stackTrace = StackTrace.current;
    final benchmark = PerformanceBenchmarkService.instance;
    final contentType = widget.contentType?.name;

    final pageCommand = _activeBenchmarkPage;
    if (pageCommand != null) {
      benchmark.mark(
        "page-provider-error",
        values: {"contentType": pageCommand.contentType, "errorType": error.runtimeType.toString()},
      );
      pageCommand.completeError(error, stackTrace);
      _activeBenchmarkPage = null;
      _benchmarkPageFrameScheduled = false;
    }

    final jumpCommand = _activeBenchmarkJump;
    if (jumpCommand != null) {
      benchmark.mark(
        "alphabet-jump-provider-error",
        values: {
          "contentType": jumpCommand.contentType,
          "letter": jumpCommand.letter,
          "errorType": error.runtimeType.toString(),
        },
      );
      timer?.cancel();
      letterToSearch = null;
      jumpCommand.completeError(error, stackTrace);
      _activeBenchmarkJump = null;
    }

    final tabCommand = _activeBenchmarkTab;
    if (tabCommand != null && tabCommand.selected) {
      benchmark.mark(
        "ui-tab-provider-error",
        values: {"contentType": contentType, "errorType": error.runtimeType.toString()},
      );
      tabCommand.completeError(error, stackTrace);
      _activeBenchmarkTab = null;
      _benchmarkTabFrameScheduled = false;
    }

    final searchCommand = benchmark.activeSearchCommand;
    if (searchCommand != null && searchCommand.selectedContentType == contentType) {
      benchmark.mark(
        "search-provider-error",
        values: {
          "contentType": contentType,
          "queryAlias": searchCommand.queryAlias,
          "errorType": error.runtimeType.toString(),
        },
      );
      searchCommand.completeError(error, stackTrace);
      _benchmarkSearchFrameScheduled = false;
    }
  }

  void _maybeCompleteBenchmarkTab(PagingState<int, FinampDisplayableOrPlayable> state) {
    final command = _activeBenchmarkTab;
    if (command == null || !command.selected || state.isLoading || (state.items?.isEmpty ?? true)) {
      return;
    }

    final benchmark = PerformanceBenchmarkService.instance;
    if (!_benchmarkTabDataMarked) {
      _benchmarkTabDataMarked = true;
      benchmark.mark(
        "ui-tab-data-ready",
        values: {"contentType": widget.contentType?.name, "loadedItems": state.items?.length ?? 0},
      );
    }

    if (_benchmarkTabFrameScheduled) return;
    _benchmarkTabFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_activeBenchmarkTab, command)) return;
      final currentState = ref.read(pageControl);
      benchmark.mark(
        "ui-tab-first-rendered-content",
        values: {"contentType": widget.contentType?.name, "loadedItems": currentState.items?.length ?? 0},
      );
      command.complete();
      _activeBenchmarkTab = null;
      _benchmarkTabFrameScheduled = false;
    });
  }

  void _maybeCompleteBenchmarkPage(PagingState<int, FinampDisplayableOrPlayable> state) {
    final command = _activeBenchmarkPage;
    if (command == null || state.isLoading) return;

    final loadedItems = state.items?.length ?? 0;
    if (loadedItems <= _benchmarkPageInitialCount && state.hasNextPage) {
      return;
    }

    if (_benchmarkPageFrameScheduled) return;
    _benchmarkPageFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_activeBenchmarkPage, command)) return;
      final current = ref.read(pageControl);
      PerformanceBenchmarkService.instance.mark(
        "page-first-rendered-content",
        values: {
          "contentType": command.contentType,
          "loadedItems": current.items?.length ?? 0,
          "itemsAdded": (current.items?.length ?? 0) - _benchmarkPageInitialCount,
          "hasNextPage": current.hasNextPage,
        },
      );
      PerformanceBenchmarkService.instance.metric(
        "pageItemsAdded",
        (current.items?.length ?? 0) - _benchmarkPageInitialCount,
      );
      command.complete(true);
      _activeBenchmarkPage = null;
      _benchmarkPageFrameScheduled = false;
    });
  }

  void _maybeCompleteBenchmarkSearch(PagingState<int, FinampDisplayableOrPlayable> state) {
    final command = PerformanceBenchmarkService.instance.activeSearchCommand;
    if (command == null ||
        identical(_lastCompletedSearchCommand, command) ||
        command.selectedContentType != widget.contentType?.name ||
        state.isLoading) {
      return;
    }

    if (state.items == null && state.hasNextPage) return;

    final resultCount = state.items?.length ?? 0;
    final benchmark = PerformanceBenchmarkService.instance;
    _recordBenchmarkSortConfiguration();
    benchmark.mark(
      "search-data-ready",
      values: {"contentType": widget.contentType?.name, "queryAlias": command.queryAlias, "resultCount": resultCount},
    );
    benchmark.metric("searchResultCount", resultCount);

    if (_benchmarkSearchFrameScheduled) return;
    _benchmarkSearchFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(PerformanceBenchmarkService.instance.activeSearchCommand, command)) {
        _benchmarkSearchFrameScheduled = false;
        return;
      }
      final current = ref.read(pageControl);
      benchmark.mark(
        "search-first-rendered-content",
        values: {
          "contentType": widget.contentType?.name,
          "queryAlias": command.queryAlias,
          "resultCount": current.items?.length ?? 0,
        },
      );
      _lastCompletedSearchCommand = command;
      _benchmarkSearchFrameScheduled = false;
      command.complete();
    });
  }

  // Scrolls the list to the first occurrence of the letter in the list
  // If clicked in the # element, it goes to the first or last one item, depending on sort order
  Future<void> scrollToLetter(String letter) async {
    if (letter.isEmpty) return;

    final benchmark = PerformanceBenchmarkService.instance;
    final pageWait = _benchmarkAlphabetPageWait;
    if (pageWait != null) {
      pageWait.stop();
      benchmark.incrementMetric("alphabetPageWaitMicros", pageWait.elapsedMicroseconds);
      benchmark.mark("alphabet-jump-page-ready");
      _benchmarkAlphabetPageWait = null;
    }

    final localScan = Stopwatch()..start();
    letterToSearch = letter;
    var codePointToScrollTo = (widget.contentType == ContentType.tracks ? letter.toUpperCase() : letter.toLowerCase())
        .codeUnitAt(0);

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
              // TODO how does jellyfin sort handle this?  Do we match?
              sortName = removeDiacritics(sortName).toLowerCase();
              break;
            default:
              // Any modification throws us off from server sorting.  Assume sortName is already stripped and lowercase.
              sortName = baseItem.nameForSorting ?? "";
              break;
          }
        case FinampPlayable playable:
          sortName = playable.source.name.getLocalized(context.l10n);
        case LatestQueues queue:
        case UnavailableHomeSectionPlayable():
          // TODO: Handle this case.
          throw UnsupportedError("This shouldn't happen.");
      }
      sortName = removeDiacritics(sortName).toLowerCase();
      if (sortName.isEmpty) continue; // assume empty names are at the start
      int itemCodePoint = sortName.codeUnitAt(0);
      final comparisonResult = itemCodePoint - codePointToScrollTo;
      if (comparisonResult == 0) {
        localScan.stop();
        benchmark.incrementMetric("alphabetLocalScanMicros", localScan.elapsedMicroseconds);
        benchmark.mark("alphabet-jump-target-located");
        timer?.cancel();
        final targetScroll = Stopwatch()..start();
        await controller.scrollToIndex(
          i,
          duration: _getAnimationDurationForOffsetToIndex(i),
          preferPosition: AutoScrollPosition.begin,
        );
        targetScroll.stop();
        benchmark.incrementMetric("alphabetTargetScrollMicros", targetScroll.elapsedMicroseconds);
        benchmark.mark("alphabet-jump-target-rendered");

        letterToSearch = null;
        _completeBenchmarkJump();
        return;
      } else if (reversed ? comparisonResult < 0 : comparisonResult > 0) {
        // If the letter is before the current item, there was no previous match (letter doesn't seem to exist in library)
        // scroll to the previous item instead
        localScan.stop();
        benchmark.incrementMetric("alphabetLocalScanMicros", localScan.elapsedMicroseconds);
        benchmark.mark("alphabet-jump-target-located");
        timer?.cancel();
        final targetScroll = Stopwatch()..start();
        await controller.scrollToIndex(
          (i - 1).clamp(0, itemList.length - 1),
          // duration: scrollDuration,
          duration: _getAnimationDurationForOffsetToIndex(i),
          preferPosition: AutoScrollPosition.middle,
        );
        targetScroll.stop();
        benchmark.incrementMetric("alphabetTargetScrollMicros", targetScroll.elapsedMicroseconds);
        benchmark.mark("alphabet-jump-target-rendered");

        letterToSearch = null;
        _completeBenchmarkJump();
        return;
      }
    }

    localScan.stop();
    benchmark.incrementMetric("alphabetLocalScanMicros", localScan.elapsedMicroseconds);

    timer?.cancel();
    if (!state.hasNextPage) {
      letterToSearch = null;
      _completeBenchmarkJump();
    } else {
      // Normal interactive use gives up after eight seconds so deferred
      // image loading can resume. The benchmark must not do that: a slow page
      // is exactly what we are trying to measure, so keep the target letter
      // active until the real page arrives or the suite-level timeout fires.
      if (_activeBenchmarkJump == null) {
        timer = Timer(const Duration(seconds: 8), () {
          letterToSearch = null;
        });
      }

      benchmark.incrementMetric("alphabetJumpPagesLoaded");
      benchmark.mark("alphabet-jump-page-requested", values: {"loadedItems": itemList.length});
      _benchmarkAlphabetPageWait = Stopwatch()..start();
      ref.read(pageControl.notifier).newPage();
    }
    final pageEdgeScroll = Stopwatch()..start();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(controller.position.maxScrollExtent);
    } else {
      await controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    }
    pageEdgeScroll.stop();
    benchmark.incrementMetric("alphabetPageEdgeScrollMicros", pageEdgeScroll.elapsedMicroseconds);
  }

  Duration _getAnimationDurationForOffsetToIndex(int index) {
    final renderedIndices = controller.tagMap.keys;
    if (renderedIndices.isEmpty) return Duration(milliseconds: 200);
    final medianIndex = renderedIndices.elementAt(renderedIndices.length ~/ 2);

    final duration = Duration(milliseconds: ((medianIndex - index).abs() / 50 * 300).clamp(200, 7500).round());
    return duration;
  }

  void _completeBenchmarkJump() {
    final command = _activeBenchmarkJump;
    if (command == null) return;
    final state = ref.read(pageControl);
    PerformanceBenchmarkService.instance.mark(
      "alphabet-jump-complete",
      values: {"loadedItems": state.items?.length ?? 0},
    );
    command.complete();
    _activeBenchmarkJump = null;
  }

  @override
  void dispose() {
    _musicScreenRefreshStreamSubscription?.cancel();
    _downloadsRefreshStreamSubscription?.cancel();
    _benchmarkJumpSubscription?.cancel();
    _benchmarkTabSubscription?.cancel();
    _benchmarkPageSubscription?.cancel();
    _activeBenchmarkPage?.completeError(
      StateError("Music screen disposed during benchmark page measurement"),
      StackTrace.current,
    );
    _activeBenchmarkTab?.completeError(
      StateError("Music screen disposed during benchmark tab measurement"),
      StackTrace.current,
    );
    _activeBenchmarkJump?.completeError(
      StateError("Music screen disposed during benchmark alphabet jump"),
      StackTrace.current,
    );
    _benchmarkAlphabetPageWait?.stop();
    _benchmarkAlphabetPageWait = null;
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
    final benchmarkPageState = ref.watch(pageControl);
    _maybeFailBenchmarkCommands(benchmarkPageState);
    _maybeReportStartupScreenReady(benchmarkPageState);
    _maybeCompleteBenchmarkTab(benchmarkPageState);
    _maybeCompleteBenchmarkPage(benchmarkPageState);
    _maybeCompleteBenchmarkSearch(benchmarkPageState);
    if (letterToSearch != null) {
      scrollToLetter(letterToSearch!);
    }

    final Widget emptyListIndicator;
    if (widget.displayable is UnavailableHomeSectionPlayable) {
      emptyListIndicator = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        child: Text(
          AppLocalizations.of(context)!.notAvailableInOfflineMode,
          style: TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      );
    } else if (widget.displayable case FinampSortable sortable when sortable.sortConfig.filters.isNotEmpty) {
      emptyListIndicator = Padding(
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
    } else {
      emptyListIndicator = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        child: Text(
          AppLocalizations.of(context)!.emptyFilteredListTitle,
          style: TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      );
    }
    final itemPadding = calculateItemCollectionCardWidth(ref).$2;
    final useListMode = widget.contentType == null || widget.contentType == ContentType.tracks
        ? true
        : ref.watch(finampSettingsProvider.perTabContentViewType(widget.contentType!)) != ContentViewType.grid;
    var tabContent = useListMode
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
                            Track() => Consumer(
                              builder: (context, ref, _) {
                                return TrackListTile(
                                  key: ValueKey(item.item.id),
                                  item: item.item,
                                  index: index,
                                  // when the tabBar was filtered and we only have the tracks tab,
                                  // we can allow Dismiss gestures in the track list
                                  allowDismiss: widget.allowTrackGestures,
                                  parentItem: switch (true) {
                                    _ when widget.sortConfig.genreFilter != null =>
                                      ref.watch(itemByIdProvider(widget.sortConfig.genreFilter!.id)).value,
                                    _ when widget.sortConfig.artistFilter != null =>
                                      ref.watch(itemByIdProvider(widget.sortConfig.artistFilter!.id)).value,
                                    _ => null,
                                  },
                                  forceAlbumArtists: (widget.sortConfig.sortBy == SortBy.albumArtist),
                                  adaptiveAdditionalInfoSortBy: widget.sortConfig.sortBy,
                                  parentPlayable:
                                      ref.watch(finampSettingsProvider.startInstantMixForIndividualTracks) &&
                                          !ref.watch(finampSettingsProvider.isOffline)
                                      ? InstantMix(item.item)
                                      : widget.displayable is FinampPlayable
                                      ? (widget.displayable as FinampPlayable)
                                      : item,
                                );
                              },
                            ),
                            FinampPlayableDto() => ItemWrapper(
                              key: ValueKey(item.item.id),
                              item: item.item,
                              genreFilter: widget.sortConfig.genreFilter,
                              adaptiveAdditionalInfoSortBy: widget.sortConfig.sortBy,
                              showFavoriteIconOnlyWhenFilterDisabled: true,
                            ),
                            PlayableQueue() => QueueRestoreTile(info: item.queue),
                            LatestQueues() ||
                            PrecalculatedPlayable() ||
                            MusicScreenPlayable<FinampPlayableDto>() ||
                            UnavailableHomeSectionPlayable() => throw UnsupportedError("Unsupported type $item"),
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
              inGridMode: !useListMode,
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
