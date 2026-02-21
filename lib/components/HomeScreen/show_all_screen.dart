import 'dart:async';
import 'dart:math';

import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart' show MusicRefreshCallback;
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/HomeScreen/home_screen_content.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/first_page_progress_indicator.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/new_page_progress_indicator.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/l10n/app_localizations.dart';

// this is used to allow refreshing the music screen from other parts of the app, e.g. after deleting items from the server
final musicScreenRefreshStream = StreamController<void>.broadcast();

class ShowAllScreen extends ConsumerStatefulWidget {
  const ShowAllScreen({super.key, this.refresh});

  final MusicRefreshCallback? refresh;

  static const routeName = "/show-all";

  @override
  ConsumerState<ShowAllScreen> createState() => _ShowAllScreenState();
}

// We use AutomaticKeepAliveClientMixin so that the view keeps its position after the tab is changed.
// https://stackoverflow.com/questions/49439047/how-to-preserve-widget-states-in-flutter-when-navigating-using-bottomnavigation
class _ShowAllScreenState extends ConsumerState<ShowAllScreen> with AutomaticKeepAliveClientMixin<ShowAllScreen> {
  // tabs on the music screen should be kept alive
  @override
  bool get wantKeepAlive => true;

  static const _pageSize = 100;

  final PagingController<int, BaseItemDto> _pagingController = PagingController(
    firstPageKey: 0,
    invisibleItemsThreshold: 70,
  );

  Future<List<BaseItemDto>>? offlineSortedItems;

  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsHelper = GetIt.instance<DownloadsService>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  StreamSubscription<void>? _musicScreenRefreshStreamSubscription;
  StreamSubscription<void>? _downloadsRefreshStreamSubscription;

  late AutoScrollController controller;
  int _requestedPageKey = -1;
  Timer? timer;
  int? refreshHash;
  int refreshCount = 0;
  int fullyLoadedRefresh = -1;

  late HomeScreenSectionConfiguration sectionInfo;
  late List<BaseItemDto> prefetchedItems;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sectionInfo = ModalRoute.of(context)!.settings.arguments as HomeScreenSectionConfiguration;
    var currentLibrary = ref.watch(
      FinampUserHelper.finampCurrentUserProvider.select((value) => value.valueOrNull?.currentView),
    );
    final itemsProviderInstance = loadHomeSectionItemsProvider(
      sectionInfo: sectionInfo,
      library: currentLibrary,
      startIndex: 0,
      limit: homeScreenSectionItemLimit,
    );
    final prefetchedItems = ref.exists(itemsProviderInstance) ? ref.read(itemsProviderInstance).value : null;
    if (prefetchedItems != null && _pagingController.nextPageKey != null) {
      if (prefetchedItems.length < homeScreenSectionItemLimit) {
        _pagingController.appendLastPage(prefetchedItems);
      } else {
        _pagingController.appendPage(prefetchedItems, prefetchedItems.length);
      }
    }
  }

  // This function just lets us easily set stuff to the getItems call we want.
  Future<void> _getPage(int pageKey) async {
    // The jump-to-letter widget and main view scrolling may generate duplicate page
    // requests.  Only fetch page once in these cases.
    if (pageKey <= _requestedPageKey) {
      return;
    }
    _requestedPageKey = pageKey;
    int localRefreshCount = refreshCount;
    try {
      var currentLibrary = ref.watch(
        FinampUserHelper.finampCurrentUserProvider.select((value) => value.valueOrNull?.currentView),
      );
      final newItems = await ref.watch(
        loadHomeSectionItemsProvider(
          sectionInfo: sectionInfo,
          library: currentLibrary,
          startIndex: pageKey,
          limit: _pageSize,
        ).future,
      );
      if (newItems == null) {
        return;
      }
      // Skip appending page if a refresh triggered while processing
      if (localRefreshCount == refreshCount && mounted) {
        if (newItems!.length < _pageSize) {
          _pagingController.appendLastPage(newItems);
          fullyLoadedRefresh = localRefreshCount;
        } else {
          _pagingController.appendPage(newItems, pageKey + newItems.length);
        }
      }
    } catch (e) {
      // Ignore errors when logging out
      if (GetIt.instance<FinampUserHelper>().currentUser != null) {
        GlobalSnackbar.error(e);
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
      viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
      axis: Axis.vertical,
    );
    _musicScreenRefreshStreamSubscription = musicScreenRefreshStream.stream.listen((_) {
      _refresh();
    });
    _downloadsRefreshStreamSubscription = downloadsHelper.offlineDeletesStream.listen((event) {
      _refresh();
    });
    super.initState();
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
    _requestedPageKey = 0;
    // This makes refreshing actually work in error cases
    _pagingController.value = PagingState(nextPageKey: 0, itemList: []);
    _pagingController.refresh();
    didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    widget.refresh?.callback = _refresh;

    // If the searchTerm argument is different to lastSearch, the user has changed their search input.
    // This makes albumViewFuture search again so that results with the search are shown.
    // This also means we don't redo a search unless we actually need to.
    FinampSettings? settings = ref.watch(finampSettingsProvider).value;
    var newRefreshHash = Object.hash(
      settings?.onlyShowFavorites,
      settings?.onlyShowFullyDownloaded,
      settings?.isOffline,
      settings?.trackOfflineFavorites,
    );
    if (refreshHash == null) {
      refreshHash = newRefreshHash;
    } else if (refreshHash != newRefreshHash) {
      _refresh();
      refreshHash = newRefreshHash;
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
      ),
    );

    var content = PagedListView<int, BaseItemDto>.separated(
      pagingController: _pagingController,
      scrollController: controller,
      physics: _DeferredLoadingAlwaysScrollableScrollPhysics(tabState: this),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      builderDelegate: PagedChildBuilderDelegate<BaseItemDto>(
        itemBuilder: (context, item, index) {
          final source = QueueItemSource.rawId(
            type: QueueItemSourceType.homeScreenSection,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.homeScreenSection,
              localizationParameter: sectionInfo.presetType?.name,
              pretranslatedName: sectionInfo.getTitle(context),
            ),
            id: sectionInfo.toLocalisedString(context),
          );
          return AutoScrollTag(
            key: ValueKey(index),
            controller: controller,
            index: index,
            child: BaseItemDtoType.fromItem(item) == BaseItemDtoType.track
                ? TrackListTile(
                    key: ValueKey(item.id),
                    item: item,
                    index: index,
                    // when the tabBar was filtered and we only have the tracks tab,
                    // we can allow Dismiss gestures in the track list
                    parentItem: sectionInfo.itemId != null
                        ? ref.watch(itemByIdProvider(sectionInfo.itemId!)).value
                        : null,
                    source: source,
                    // since we can't re-create the current random sorting, we simply pass the pre-sorted tracks along
                    // only done in offline mode since online mode doesn't support playing the tab contents in order anyway
                    children: _pagingController.itemList,
                  )
                : ItemWrapper(item: item, source: source, isGrid: false),
          );
        },
        firstPageProgressIndicatorBuilder: (_) => const FirstPageProgressIndicator(),
        newPageProgressIndicatorBuilder: (_) => const NewPageProgressIndicator(),
        noItemsFoundIndicatorBuilder: (_) => emptyListIndicator,
      ),
      separatorBuilder: (context, index) => const SizedBox.shrink(),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          // this is needed to ensure the player screen stays in full screen mode WITHOUT having contrast issues in the status bar
          systemNavigationBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        ),
        elevation: 0,
        scrolledUnderElevation: 0.0, // disable tint/shadow when content is scrolled under the app bar
        centerTitle: true,
        toolbarHeight: 53,
        title: Text(
          sectionInfo.itemId != null
              ? ref.watch(itemByIdProvider(sectionInfo.itemId!)).valueOrNull?.name ?? sectionInfo.getTitle(context)
              : sectionInfo.getTitle(context),
        ),
        leading: FinampAppBarBackButton(),
        actions: [],
      ),
      body: RefreshIndicator(onRefresh: () async => _refresh(), child: content),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
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

  final _ShowAllScreenState tabState;

  @override
  _DeferredLoadingAlwaysScrollableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _DeferredLoadingAlwaysScrollableScrollPhysics(parent: buildParent(ancestor), tabState: tabState);
  }

  @override
  bool recommendDeferredLoading(double velocity, ScrollMetrics metrics, BuildContext context) {
    return super.recommendDeferredLoading(velocity, metrics, context);
  }
}
