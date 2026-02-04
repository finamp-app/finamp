import 'dart:async';
import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../components/MusicScreen/artist_type_selection_row.dart';
import '../components/MusicScreen/music_screen_tab_view.dart';
import '../components/MusicScreen/sort_by_menu_button.dart';
import '../components/MusicScreen/sort_order_button.dart';
import '../components/global_snackbar.dart';
import '../components/now_playing_bar.dart';
import '../menus/music_screen_drawer.dart';
import '../models/finamp_models.dart';
import '../services/audio_service_helper.dart';
import '../services/finamp_settings_helper.dart';
import '../services/finamp_user_helper.dart';
import '../services/jellyfin_api_helper.dart';

final _musicScreenLogger = Logger("MusicScreen");

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({
    super.key,
    this.genreFilter,
    this.tabTypeFilter,
    this.sortByOverrideInit,
    this.sortOrderOverrideInit,
    this.isFavoriteOverrideInit,
  });

  static const routeName = "/music";

  // Optional parameters for genre and tab filtering
  final BaseItemDto? genreFilter;
  final TabContentType? tabTypeFilter;
  final SortBy? sortByOverrideInit;
  final SortOrder? sortOrderOverrideInit;
  final bool? isFavoriteOverrideInit;

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> with TickerProviderStateMixin {
  bool isSearching = false;
  TextEditingController textEditingController = TextEditingController();
  String? searchQuery;
  final Map<TabContentType, MusicRefreshCallback> refreshMap = {};
  SortBy? sortByOverride;
  SortOrder? sortOrderOverride;
  bool? isFavoriteOverride;

  TabController? _tabController;

  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

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

    final tabs = widget.tabTypeFilter != null
        ? [widget.tabTypeFilter!]
        : ref
              .watch(finampSettingsProvider.tabOrder)
              .where((e) => ref.watch(finampSettingsProvider.select((value) => value.value?.showTabs[e])) ?? false);

    _tabController = TabController(length: tabs.length, vsync: this, initialIndex: 0);

    _tabController!.addListener(_tabIndexCallback);
  }

  @override
  void initState() {
    super.initState();
    sortByOverride = widget.sortByOverrideInit;
    sortOrderOverride = widget.sortOrderOverrideInit;
    isFavoriteOverride = widget.isFavoriteOverrideInit;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  FloatingActionButton? getFloatingActionButton(List<TabContentType> sortedTabs) {
    // Show the floating action button only on the albums, artists, generes and tracks tab.
    if (_tabController!.index == sortedTabs.indexOf(TabContentType.tracks)) {
      return FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.shuffleAll,
        onPressed: () async {
          try {
            await _audioServiceHelper.shuffleAll(
              onlyShowFavorites:
                  (isFavoriteOverride == true ||
                  (isFavoriteOverride == null && ref.read(finampSettingsProvider.onlyShowFavorites))),
              genreFilter: widget.genreFilter,
            );
          } catch (e) {
            GlobalSnackbar.error(e);
          }
        },
        child: const Icon(TablerIcons.arrows_shuffle),
      );
    } else if ([
      TabContentType.artists,
      TabContentType.albums,
      TabContentType.genres,
    ].contains(sortedTabs.elementAt(_tabController!.index))) {
      return FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.startMix,
        onPressed: () async {
          try {
            switch (sortedTabs.elementAt(_tabController!.index)) {
              case TabContentType.artists:
                if (_jellyfinApiHelper.selectedMixArtists.isEmpty) {
                  GlobalSnackbar.message((scaffold) => AppLocalizations.of(context)!.startMixNoTracksArtist);
                } else {
                  await _audioServiceHelper.startInstantMixForArtists(_jellyfinApiHelper.selectedMixArtists);
                  _jellyfinApiHelper.clearArtistMixBuilderList();
                }
                break;
              case TabContentType.albums:
                if (_jellyfinApiHelper.selectedMixAlbums.isEmpty) {
                  GlobalSnackbar.message((scaffold) => AppLocalizations.of(context)!.startMixNoTracksAlbum);
                } else {
                  await _audioServiceHelper.startInstantMixForAlbums(_jellyfinApiHelper.selectedMixAlbums);
                }
                break;
              case TabContentType.genres:
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

  void refreshTab(TabContentType tabType) {
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
    final sortedTabs = widget.tabTypeFilter != null
        ? [widget.tabTypeFilter!]
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
      // TODO fallback to the home screen once implemented
      FinampSetters.setShowTabs(TabContentType.albums, true);
      // This widget should rebuild with an enabled tab on the next frame, just return empty for now.
      return SizedBox.shrink();
    }
    refreshMap[sortedTabs.elementAt(_tabController!.index)] = MusicRefreshCallback();

    Timer? debounce;

    return PopScope(
      canPop: !isSearching,
      onPopInvokedWithResult: (popped, result) {
        if (isSearching) {
          _stopSearching();
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          titleSpacing: 0, // The surrounding iconButtons provide enough padding
          title: isSearching
              ? TextField(
                  controller: textEditingController,
                  autocorrect: false, // avoid autocorrect
                  enableSuggestions: true, // keep suggestions which can be manually selected
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    if (debounce?.isActive ?? false) debounce!.cancel();
                    debounce = Timer(const Duration(milliseconds: 400), () {
                      setState(() {
                        searchQuery = value;
                      });
                    });
                  },
                  onSubmitted: (value) => setState(() {
                    searchQuery = value;
                  }),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: MaterialLocalizations.of(context).searchFieldLabel,
                  ),
                )
              : Text(
                  widget.tabTypeFilter?.toLocalisedString(context) ??
                      _finampUserHelper.currentUser?.currentView?.name ??
                      AppLocalizations.of(context)!.music,
                ),
          bottom: widget.genreFilter == null
              ? TabBar(
                  controller: _tabController,
                  tabs: sortedTabs
                      .map(
                        (tabType) => Tab(
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 50),
                            alignment: Alignment.center,
                            child: Text(tabType.toLocalisedString(context).toUpperCase()),
                          ),
                        ),
                      )
                      .toList(),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                )
              : PreferredSize(
                  preferredSize: const Size.fromHeight(36),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    width: double.infinity,
                    height: 36.0,
                    padding: EdgeInsets.only(left: 12, right: 12),
                    color: Theme.of(context).colorScheme.primary,
                    child: Text(
                      widget.genreFilter?.name ?? "",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          leading: isSearching
              ? BackButton(onPressed: () => _stopSearching())
              : (widget.genreFilter != null ? BackButton(onPressed: () => Navigator.of(context).pop()) : null),
          actions: isSearching
              ? [
                  GestureDetector(
                    onDoubleTap: () => _stopSearching(),
                    child: IconButton(
                      icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => setState(() {
                        textEditingController.clear();
                        searchQuery = null;
                      }),
                      tooltip: AppLocalizations.of(context)!.clear,
                    ),
                  ),
                ]
              : [
                  if (!Platform.isIOS && !Platform.isAndroid)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        refreshMap[sortedTabs.elementAt(_tabController!.index)]!();
                      },
                    ),
                  SortOrderButton(
                    tabType: sortedTabs.elementAt(_tabController!.index),
                    sortOrderOverride: sortOrderOverride,
                    onOverrideChanged: (newOrder) => setState(() {
                      sortOrderOverride = newOrder;
                    }),
                  ),
                  SortByMenuButton(
                    tabType: sortedTabs.elementAt(_tabController!.index),
                    sortByOverride: sortByOverride,
                    onOverrideChanged: (newSortBy) => setState(() {
                      sortByOverride = newSortBy;
                    }),
                  ),
                  if (ref.watch(finampSettingsProvider.isOffline) &&
                      sortedTabs.elementAt(_tabController!.index) != TabContentType.tracks)
                    IconButton(
                      icon: ref.watch(finampSettingsProvider.onlyShowFullyDownloaded)
                          ? const Icon(Icons.download)
                          : const Icon(Icons.download_outlined),
                      onPressed: ref.read(finampSettingsProvider.isOffline)
                          ? () => FinampSetters.setOnlyShowFullyDownloaded(
                              !ref.read(finampSettingsProvider.onlyShowFullyDownloaded),
                            )
                          : null,
                      tooltip: AppLocalizations.of(context)!.onlyShowFullyDownloaded,
                    ),
                  if (!ref.watch(finampSettingsProvider.isOffline) ||
                      ref.watch(finampSettingsProvider.trackOfflineFavorites))
                    IconButton(
                      icon:
                          (isFavoriteOverride == true ||
                              (isFavoriteOverride == null && ref.watch(finampSettingsProvider.onlyShowFavorites)))
                          ? const Icon(Icons.favorite)
                          : const Icon(Icons.favorite_outline),
                      onPressed: () {
                        if (isFavoriteOverride != null) {
                          setState(() {
                            isFavoriteOverride = !isFavoriteOverride!;
                          });
                        } else {
                          FinampSetters.setOnlyShowFavorites(!ref.watch(finampSettingsProvider.onlyShowFavorites));
                        }
                      },
                      tooltip: AppLocalizations.of(context)!.favorites,
                    ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => setState(() {
                      isSearching = true;
                    }),
                    tooltip: MaterialLocalizations.of(context).searchFieldLabel,
                  ),
                ],
        ),
        bottomNavigationBar: const NowPlayingBar(),
        drawerEnableOpenDragGesture: widget.genreFilter == null,
        drawer: widget.genreFilter == null ? const MusicScreenDrawer() : null,
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
                  : widget.tabTypeFilter != null
                  ? NeverScrollableScrollPhysics()
                  : AlwaysScrollableScrollPhysics(),
              dragStartBehavior: DragStartBehavior.down,
              children: sortedTabs.map((tabType) {
                return Column(
                  children: [
                    ArtistTypeSelectionRow(
                      tabType: tabType,
                      defaultArtistType: ref.watch(finampSettingsProvider.defaultArtistType),
                      refreshTab: refreshTab,
                    ),
                    Expanded(
                      child: MusicScreenTabView(
                        tabContentType: tabType,
                        searchTerm: searchQuery,
                        view: _finampUserHelper.currentUser?.currentView,
                        refresh: refreshMap[tabType],
                        genreFilter:
                            (widget.genreFilter != null &&
                                (tabType.itemType == BaseItemDtoType.track ||
                                    tabType.itemType == BaseItemDtoType.album ||
                                    tabType.itemType == BaseItemDtoType.artist ||
                                    tabType.itemType == BaseItemDtoType.playlist))
                            ? widget.genreFilter
                            : null,
                        tabBarFiltered: (widget.tabTypeFilter != null),
                        sortByOverride: sortByOverride,
                        sortOrderOverride: sortOrderOverride,
                        isFavoriteOverride: isFavoriteOverride,
                      ),
                    ),
                  ],
                );
              }).toList(),
            );

            if (Platform.isAndroid) {
              return TransparentRightSwipeDetector(
                action: () {
                  if (_tabController?.index == 0 && !ref.watch(finampSettingsProvider.disableGesture)) {
                    Scaffold.of(context).openDrawer();
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
