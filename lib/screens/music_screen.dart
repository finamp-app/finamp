import 'dart:io';

import 'package:finamp/components/HomeScreen/finamp_music_screen_header.dart';
import 'package:finamp/components/HomeScreen/home_screen_content.dart';
import 'package:finamp/components/MusicScreen/artist_type_selection_row.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/music_screen_drawer.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../models/jellyfin_models.dart';

final _musicScreenLogger = Logger("MusicScreen");

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key, this.singleTabConfig, this.initialTab, this.hideArtistGenreFilters = false});

  /// The initial tab type to show. Can also be provided as an argument in a named route
  final ContentType? initialTab;
  final bool hideArtistGenreFilters;

  static const routeName = "/music";

  // Optional parameters for genre and tab filtering
  final HomeScreenSectionConfiguration? singleTabConfig;

  bool get showHeader => singleTabConfig == null;

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> with TickerProviderStateMixin {
  bool isSearching = false;
  TextEditingController textEditingController = TextEditingController();
  String? searchQuery;
  final Map<ContentType, MusicRefreshCallback> refreshMap = {};
  final Map<ContentType, SortAndFilterController> sortAndFilterControllerMap = {};

  TabController? _tabController;

  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  QueueItemSource get musicScreenSource => QueueItemSource.rawId(
    type: ref.watch(finampSettingsProvider.onlyShowFavorites)
        ? QueueItemSourceType.favorites
        : QueueItemSourceType.allTracks,
    name: QueueItemSourceName(
      type: ref.watch(finampSettingsProvider.onlyShowFavorites)
          ? QueueItemSourceNameType.yourLikes
          : QueueItemSourceNameType.shuffleAll,
    ),
    id: "shuffleAll",
  );

  void _stopSearching() {
    setState(() {
      textEditingController.clear();
      searchQuery = null;
      isSearching = false;
    });
  }

  void _tabIndexCallback() {
    // We have to rebuild, otherwise the Action Buttons
    // in the AppBar might not get the correct current tab
    setState(() {});
  }

  void _buildTabController() {
    _tabController?.removeListener(_tabIndexCallback);
    _tabController?.dispose();

    if (widget.singleTabConfig != null) {
      _tabController = TabController(length: 1, vsync: this, initialIndex: 0);
    } else {
      final tabs = ref
          .watch(finampSettingsProvider.tabOrder)
          .where((x) => x.isTab)
          .where((e) => ref.watch(finampSettingsProvider.select((value) => value.value?.showTabs[e])) ?? false);

      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: widget.initialTab == null ? 0 : tabs.toList().indexOf(widget.initialTab!),
      );
    }

    _tabController!.addListener(_tabIndexCallback);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  FloatingActionButton? getFloatingActionButton(List<ContentType> sortedTabs) {
    final currentTab = sortedTabs.elementAt(_tabController!.index);
    // Show the floating action button only on the albums, artists, generes and tracks tab.
    if (_tabController!.index == sortedTabs.indexOf(ContentType.tracks)) {
      return FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.shuffleAll,
        onPressed: () async {
          try {
            final config = sortAndFilterControllerMap[currentTab]!.resolveConfig();
            BaseItemDto? genreFilter;
            if (config.genreFilter != null) {
              genreFilter = await ref.read(itemByIdProvider(config.genreFilter!.id).future);
            }
            await _audioServiceHelper.shuffleAll(
              onlyShowFavorites: config.filters.any((filter) => filter.type == ItemFilterType.isFavorite),
              genreFilter: genreFilter,
            );
          } catch (e) {
            GlobalSnackbar.error(e);
          }
        },
        child: const Icon(TablerIcons.arrows_shuffle),
      );
    } else if ([ContentType.genericArtists, ContentType.albums, ContentType.genres].contains(currentTab)) {
      return FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.startMix,
        onPressed: () async {
          try {
            switch (currentTab) {
              // TODO should this distinguish between artist types somehow?
              case ContentType.genericArtists:
                if (_jellyfinApiHelper.selectedMixArtists.isEmpty) {
                  GlobalSnackbar.message((scaffold) => AppLocalizations.of(context)!.startMixNoTracksArtist);
                } else {
                  await _audioServiceHelper.startInstantMixForArtists(_jellyfinApiHelper.selectedMixArtists);
                  _jellyfinApiHelper.clearArtistMixBuilderList();
                }
                break;
              case ContentType.albums:
                if (_jellyfinApiHelper.selectedMixAlbums.isEmpty) {
                  GlobalSnackbar.message((scaffold) => AppLocalizations.of(context)!.startMixNoTracksAlbum);
                } else {
                  await _audioServiceHelper.startInstantMixForAlbums(_jellyfinApiHelper.selectedMixAlbums);
                }
                break;
              case ContentType.genres:
                if (_jellyfinApiHelper.selectedMixGenres.isEmpty) {
                  GlobalSnackbar.message((scaffold) => AppLocalizations.of(context)!.startMixNoTracksGenre);
                } else {
                  await _audioServiceHelper.startInstantMixForGenres(_jellyfinApiHelper.selectedMixGenres);
                }
                break;
              default:
            }
          } catch (e) {
            GlobalSnackbar.error(e);
          }
        },
        child: const Icon(TablerIcons.category_2),
      );
    } else {
      return null;
    }
  }

  void refreshTab(ContentType tabType) {
    refreshMap[tabType]?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      _buildTabController();
    }
    ref.watch(FinampUserHelper.finampCurrentUserProvider);
    // Get the filtered tab or the tabs from the user's tab order,
    // and filter them to only include enabled tabs
    final sortedTabs = widget.singleTabConfig != null
        ? [
            switch (widget.singleTabConfig!.base) {
              QueuesHomeSection() => ContentType.home,
              TabsHomeSection tabSection => tabSection.contentType,
              CollectionHomeSection() => ContentType.home,
            },
          ]
        : ref
              .watch(finampSettingsProvider.tabOrder)
              .where((e) => ref.watch(finampSettingsProvider.showTabs(e)) ?? false);

    if (sortedTabs.length != _tabController?.length) {
      _musicScreenLogger.info(
        "Rebuilding MusicScreen tab controller (${sortedTabs.length} != ${_tabController?.length})",
      );
      _buildTabController();
    }

    if (sortedTabs.isEmpty) {
      FinampSetters.setShowTabs(ContentType.home, true);
      // This widget should rebuild with an enabled tab on the next frame, just return empty for now.
      return SizedBox.shrink();
    }

    refreshMap[sortedTabs.elementAt(_tabController!.index)] = MusicRefreshCallback();

    return PopScope(
      canPop: !isSearching,
      onPopInvokedWithResult: (popped, result) {
        if (isSearching) {
          _stopSearching();
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: FinampMusicScreenHeader(
          singleTabConfig: widget.singleTabConfig,
          sortedTabs: sortedTabs.toList(),
          tabController: _tabController,
          onSearch: () => setState(() {
            isSearching = true;
            if (_tabController != null &&
                !_tabController!.indexIsChanging &&
                sortedTabs.elementAt(_tabController!.index) == ContentType.home) {
              // we can't search on the home tab yet
              _tabController!.index = sortedTabs.toList().indexWhere(
                (ContentType tabType) => tabType != ContentType.home,
              );
            }
          }),
          onStopSearch: _stopSearching,
          onUpdateSearchQuery: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          refreshTab: () => refreshTab(sortedTabs.elementAt(_tabController!.index)),
          textEditingController: textEditingController,
          isSearching: isSearching,
        ),
        bottomNavigationBar: NowPlayingBar(),
        drawerEnableOpenDragGesture: widget.showHeader,
        drawer: widget.showHeader ? const MusicScreenDrawer() : null,
        floatingActionButton: Padding(
          padding: EdgeInsets.only(right: ref.watch(finampSettingsProvider.showFastScroller) ? 24.0 : 8.0),
          child: getFloatingActionButton(sortedTabs.toList()),
        ),
        body: Builder(
          builder: (context) {
            final child = TabBarView(
              controller: _tabController,
              physics: ref.watch(finampSettingsProvider.disableGesture) || MediaQuery.disableAnimationsOf(context)
                  ? const NeverScrollableScrollPhysics()
                  : widget.singleTabConfig != null
                  ? NeverScrollableScrollPhysics()
                  : AlwaysScrollableScrollPhysics(),
              dragStartBehavior: DragStartBehavior.down,
              children: sortedTabs.map((tabType) {
                if (tabType == ContentType.home && widget.singleTabConfig == null) {
                  return HomeScreenContent(refresh: refreshMap[tabType]);
                }
                final contentTabType = tabType == ContentType.genericArtists
                    ? ref.watch(finampSettingsProvider.defaultArtistType).tabType
                    : tabType;
                sortAndFilterControllerMap[contentTabType] ??= widget.singleTabConfig != null
                    ? SortAndFilterController(
                        startingConfig: widget.singleTabConfig!.sortConfig,
                        contentType: contentTabType,
                      )
                    : SortAndFilterController.trackSettings(contentTabType);

                FinampDisplayable? displayable;
                if (widget.singleTabConfig != null) {
                  displayable = ref.watch(resolveSectionProvider(widget.singleTabConfig!)).value;
                  // TODO precache resolved sections?  Or remove baked in item somehow?  Or save items into home screen settings?
                  if (displayable == null) {
                    return SizedBox.shrink();
                  }
                  if (displayable is FinampSortable) {
                    displayable = displayable.copyWith(
                      ref
                          .watch(resolveSortProvider(sortAndFilterControllerMap[contentTabType]!))
                          .copyWithSearch(searchQuery),
                    );
                  }
                } else {
                  displayable = MusicScreenPlayable(
                    tab: contentTabType,
                    library: currentLibraryPlaceholder,
                    // TODO better queue source?
                    source: musicScreenSource,
                    sortConfig: ref
                        .watch(resolveSortProvider(sortAndFilterControllerMap[contentTabType]!))
                        .copyWithSearch(searchQuery),
                  );
                }

                return Column(
                  children: [
                    if (displayable is FinampSortable)
                      SortAndFilterRow(
                        tabType: contentTabType,
                        controller: sortAndFilterControllerMap[contentTabType]!,
                        hideArtistGenreFilters: widget.hideArtistGenreFilters,
                      ),
                    ArtistTypeSelectionRow(
                      tabType: tabType,
                      defaultArtistType: ref.watch(finampSettingsProvider.defaultArtistType),
                      refreshTab: refreshTab,
                    ),
                    Expanded(
                      // Prevent track highlight background from showing on header
                      child: Material(
                        child: MusicScreenTabView(
                          refresh: refreshMap[tabType],
                          allowTrackGestures: widget.singleTabConfig != null,
                          displayable: displayable,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            );

            if (Platform.isAndroid) {
              //FIXME this should only trigger if the home screen section lists are scrolled all the way to the left
              return TransparentRightSwipeDetector(
                action: () {
                  if (_tabController?.index == 0 && !ref.watch(finampSettingsProvider.disableGesture)) {
                    // Scaffold.of(context).openDrawer();
                    showFinampMainMenu(context: context);
                  }
                },
                child: child,
              );
            }

            return child;
          },
        ),
      ),
    );
  }
}

// This class causes a horizontal swipe to be processed even when another widget
// wins the GestureArena.
class _TransparentSwipeRecognizer extends HorizontalDragGestureRecognizer {
  _TransparentSwipeRecognizer({super.debugOwner, super.supportedDevices});

  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

// This class is a cut-down version of SimplifiedGestureDetector/GestureDetector,
// but using _TransparentSwipeRecognizer instead of HorizontalDragGestureRecognizer
// to allow both it and the TabBarView to process the same gestures.
class TransparentRightSwipeDetector extends StatefulWidget {
  const TransparentRightSwipeDetector({super.key, this.child, required this.action});

  final Widget? child;

  final void Function() action;

  @override
  State<TransparentRightSwipeDetector> createState() => _TransparentRightSwipeDetectorState();
}

class _TransparentRightSwipeDetectorState extends State<TransparentRightSwipeDetector> {
  @override
  Widget build(BuildContext context) {
    /// Device types that scrollables should accept drag gestures from by default.
    const Set<PointerDeviceKind> supportedDevices = <PointerDeviceKind>{
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
      // The VoiceAccess sends pointer events with unknown type when scrolling
      // scrollables.
      PointerDeviceKind.unknown,
    };
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    gestures[_TransparentSwipeRecognizer] = GestureRecognizerFactoryWithHandlers<_TransparentSwipeRecognizer>(
      () => _TransparentSwipeRecognizer(debugOwner: this, supportedDevices: supportedDevices),
      (_TransparentSwipeRecognizer instance) {
        instance
          ..onStart = _onHorizontalDragStart
          ..onUpdate = _onHorizontalDragUpdate
          ..onEnd = _onHorizontalDragEnd
          ..supportedDevices = supportedDevices;
      },
    );

    return RawGestureDetector(gestures: gestures, child: widget.child);
  }

  Offset? _initialSwipeOffset;

  void _onHorizontalDragStart(DragStartDetails details) {
    _initialSwipeOffset = details.globalPosition;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final finalOffset = details.globalPosition;
    final initialOffset = _initialSwipeOffset;
    if (initialOffset != null) {
      final horizontalOffset = initialOffset.dx - finalOffset.dx;
      final verticalOffset = initialOffset.dy - finalOffset.dy;
      // Only trigger if swipe angle primarily horizontal
      if (horizontalOffset < -100.0 && horizontalOffset.abs() > verticalOffset.abs() * 1.5) {
        _initialSwipeOffset = null;
        widget.action();
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _initialSwipeOffset = null;
  }
}
