import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../models/finamp_models.dart';
import '../services/finamp_settings_helper.dart';
import '../services/audio_service_helper.dart';
import '../services/finamp_user_helper.dart';
import '../components/MusicScreen/music_screen_tab_view.dart';
import '../components/MusicScreen/music_screen_drawer.dart';
import '../components/MusicScreen/sort_by_menu_button.dart';
import '../components/MusicScreen/sort_order_button.dart';
import '../components/now_playing_bar.dart';
import '../components/selection_action_bar.dart';
import '../components/selection_app_bar.dart';
import '../components/song_selection_controller.dart';
import '../components/error_snackbar.dart';
import '../services/jellyfin_api_helper.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({Key? key}) : super(key: key);

  static const routeName = "/music";

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with TickerProviderStateMixin {
  bool isSearching = false;
  bool _showShuffleFab = false;
  TextEditingController textEditingController = TextEditingController();
  String? searchQuery;
  final _musicScreenLogger = Logger("MusicScreen");

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
    var tabKey = FinampSettingsHelper.finampSettings.showTabs.entries
        .where((element) => element.value)
        .elementAt(_tabController!.index)
        .key;
    if (_tabController != null &&
        (tabKey == TabContentType.songs ||
            tabKey == TabContentType.artists ||
            tabKey == TabContentType.albums)) {
      setState(() {
        _showShuffleFab = true;
      });
    } else {
      if (_showShuffleFab) {
        setState(() {
          _showShuffleFab = false;
        });
      }
    }
  }

  void _buildTabController() {
    _tabController?.removeListener(_tabIndexCallback);

    _tabController = TabController(
      length: FinampSettingsHelper.finampSettings.showTabs.entries
          .where((element) => element.value)
          .length,
      vsync: this,
    );

    _tabController!.addListener(_tabIndexCallback);
  }

  @override
  void initState() {
    super.initState();
    _buildTabController();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  FloatingActionButton? getFloatingActionButton() {
    var tabList = FinampSettingsHelper.finampSettings.showTabs.entries
        .where((element) => element.value)
        .map((e) => e.key)
        .toList();

    // Show the floating action button only on the albums, artists and songs tab.
    if (_tabController!.index == tabList.indexOf(TabContentType.songs)) {
      return FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.shuffleAll,
        onPressed: () async {
          try {
            await _audioServiceHelper
                .shuffleAll(FinampSettingsHelper.finampSettings.isFavourite);
          } catch (e) {
            errorSnackbar(e, context);
          }
        },
        child: const Icon(Icons.shuffle),
      );
    } else if (_tabController!.index ==
        tabList.indexOf(TabContentType.artists)) {
      return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.startMix,
          onPressed: () async {
            try {
              if (_jellyfinApiHelper.selectedMixArtistsIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.startMixNoSongsArtist)));
              } else {
                await _audioServiceHelper.startInstantMixForArtists(
                    _jellyfinApiHelper.selectedMixArtistsIds);
              }
            } catch (e) {
              errorSnackbar(e, context);
            }
          },
          child: const Icon(Icons.explore));
    } else if (_tabController!.index ==
        tabList.indexOf(TabContentType.albums)) {
      return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.startMix,
          onPressed: () async {
            try {
              if (_jellyfinApiHelper.selectedMixAlbumIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.startMixNoSongsAlbum)));
              } else {
                await _audioServiceHelper.startInstantMixForAlbums(
                    _jellyfinApiHelper.selectedMixAlbumIds);
              }
            } catch (e) {
              errorSnackbar(e, context);
            }
          },
          child: const Icon(Icons.explore));
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SongSelectionController(),
      child: ValueListenableBuilder<Box<FinampUser>>(
        valueListenable: _finampUserHelper.finampUsersListenable,
        builder: (context, value, _) {
          return ValueListenableBuilder<Box<FinampSettings>>(
            valueListenable: FinampSettingsHelper.finampSettingsListener,
            builder: (context, value, _) {
              final finampSettings = value.get("FinampSettings");
              final selection = context.watch<SongSelectionController>();

              // Get the tabs from the user's tab order, and filter them to only
              // include enabled tabs
              final tabs = finampSettings!.tabOrder.where((e) =>
                  FinampSettingsHelper.finampSettings.showTabs[e] ?? false);

              if (tabs.length != _tabController?.length) {
                _musicScreenLogger.info(
                    "Rebuilding MusicScreen tab controller (${tabs.length} != ${_tabController?.length})");
                _buildTabController();
              }

              return WillPopScope(
                onWillPop: () async {
                  if (selection.isSelecting) {
                    selection.endSelection();
                    return false;
                  }
                  if (isSearching) {
                    _stopSearching();
                    return false;
                  }
                  return true;
                },
                child: Scaffold(
                  appBar: selection.isSelecting
                      ? SelectionAppBar(controller: selection)
                      : AppBar(
                          title: isSearching
                              ? TextField(
                                  controller: textEditingController,
                                  autofocus: true,
                                  onChanged: (value) => setState(() {
                                    searchQuery = value;
                                  }),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: MaterialLocalizations.of(context)
                                        .searchFieldLabel,
                                  ),
                                )
                              : Text(_finampUserHelper
                                      .currentUser?.currentView?.name ??
                                  AppLocalizations.of(context)!.music),
                          bottom: TabBar(
                            controller: _tabController,
                            tabs: tabs
                                .map((tabType) => Tab(
                                      text: tabType
                                          .toLocalisedString(context)
                                          .toUpperCase(),
                                    ))
                                .toList(),
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                          ),
                          leading: isSearching
                              ? BackButton(
                                  onPressed: () => _stopSearching(),
                                )
                              : null,
                          actions: isSearching
                              ? [
                                  IconButton(
                                    icon: Icon(
                                      Icons.cancel,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    onPressed: () => setState(() {
                                      textEditingController.clear();
                                      searchQuery = null;
                                    }),
                                    tooltip:
                                        AppLocalizations.of(context)!.clear,
                                  )
                                ]
                              : [
                                  SortOrderButton(
                                    tabs.elementAt(_tabController!.index),
                                  ),
                                  SortByMenuButton(
                                    tabs.elementAt(_tabController!.index),
                                  ),
                                  IconButton(
                                    icon: finampSettings.isFavourite
                                        ? const Icon(Icons.favorite)
                                        : const Icon(Icons.favorite_outline),
                                    onPressed: finampSettings.isOffline
                                        ? null
                                        : () =>
                                            FinampSettingsHelper.setIsFavourite(
                                                !finampSettings.isFavourite),
                                    tooltip: AppLocalizations.of(context)!
                                        .favourites,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () => setState(() {
                                      isSearching = true;
                                    }),
                                    tooltip: MaterialLocalizations.of(context)
                                        .searchFieldLabel,
                                  ),
                                ],
                        ),
                  bottomNavigationBar:
                      const SelectionAwareBottomBar(child: NowPlayingBar()),
                  drawer: const MusicScreenDrawer(),
                  floatingActionButton: selection.isSelecting
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: getFloatingActionButton(),
                        ),
                  body: TabBarView(
                    controller: _tabController,
                    physics: selection.isSelecting
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    children: tabs
                        .map((tabType) => MusicScreenTabView(
                              tabContentType: tabType,
                              searchTerm: searchQuery,
                              isFavourite: finampSettings.isFavourite,
                              sortBy: finampSettings.getTabSortBy(tabType),
                              sortOrder: finampSettings.getSortOrder(tabType),
                              view: _finampUserHelper.currentUser?.currentView,
                            ))
                        .toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
