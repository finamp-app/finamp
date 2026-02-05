import 'dart:math';

import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/HomeScreen/show_all_button.dart';
import 'package:finamp/components/HomeScreen/show_all_screen.dart';
import 'package:finamp/components/MusicScreen/item_card.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/components/Buttons/cta_large.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

part 'home_screen_content.g.dart';

final _homeScreenLogger = Logger("HomeScreen");
const homeScreenSectionItemLimit = 20;

class HomeScreenContent extends ConsumerStatefulWidget {
  const HomeScreenContent({super.key});

  @override
  ConsumerState<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<HomeScreenContent> {
  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FinampSettings? finampSettings = ref.watch(finampSettingsProvider).value;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(loadHomeSectionItemsProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 0,
                runSpacing: 8,
                direction: Axis.horizontal,
                alignment: WrapAlignment.spaceBetween,
                runAlignment: WrapAlignment.center,
                children: ref.watch(finampSettingsProvider.homeScreenConfiguration).actions.map((action) {
                  return CTALarge(
                    text: action.toLocalisedString(context),
                    icon: switch (action) {
                      FinampQuickAction.trackMix => TablerIcons.arrows_shuffle,
                      FinampQuickAction.recents => TablerIcons.calendar,
                      FinampQuickAction.surpriseMe => TablerIcons.radio,
                    },
                    vertical: true,
                    minWidth: 110,
                    onPressed: switch (action) {
                      FinampQuickAction.trackMix => () {
                        _audioServiceHelper.shuffleAll(onlyShowFavorites: finampSettings?.onlyShowFavorites ?? false);
                      },
                      FinampQuickAction.recents => () {
                        Navigator.pushNamed(context, QueueRestoreScreen.routeName);
                      },
                      FinampQuickAction.surpriseMe => () async {
                        //TODO handle offline mode (continuous radio not available, and offline request needed) - maybe just hide this?
                        // start continuous radio with a random track?
                        final randomTracks = await _jellyfinApiHelper.getItems(
                          parentItem: _finampUserHelper.currentUser?.currentView,
                          includeItemTypes: [BaseItemDtoType.track.jellyfinName].join(","),
                          limit: 1,
                          sortBy: "Random",
                        );
                        if (randomTracks != null && randomTracks.isNotEmpty) {
                          await GetIt.instance<QueueService>().startPlayback(
                            items: randomTracks,
                            source: QueueItemSource.fromBaseItem(randomTracks.first),
                            skipRadioCacheInvalidation: false,
                          );
                          FinampSetters.setRadioMode(RadioMode.continuous);
                          toggleRadio(true);
                        }
                      },
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              ...ref
                  .watch(finampSettingsProvider.homeScreenConfiguration)
                  .sections
                  .map((sectionInfo) => HomeScreenSection(sectionInfo: sectionInfo)),
              SizedBox(height: 60),
              ...[
                // monochrome icon
                FinampIcon(56, 56, overrideColor: TextTheme.of(context).bodySmall?.color?.withOpacity(0.4)),
                SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 200),
                    child: BalancedText(
                      "Built with ♥ by the Finamp contributors.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: TextTheme.of(context).bodySmall?.color?.withOpacity(0.6)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreenSection extends ConsumerWidget {
  const HomeScreenSection({super.key, required this.sectionInfo});

  final HomeScreenSectionConfiguration sectionInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        return Padding(
          // if we show text, it won't fill up all four lines (on average), so we have enough white space already
          padding: EdgeInsets.only(top: ref.watch(finampSettingsProvider.showTextOnGridView) ? 4.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SimpleGestureDetector(
                onTap: () {
                  //TODO Handle the tap event?
                  GlobalSnackbar.message((buildContext) {
                    return "This feature is not available yet.";
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      sectionInfo.itemId != null
                          ? ref.watch(itemByIdProvider(sectionInfo.itemId!)).valueOrNull?.name ??
                                sectionInfo.getTitle(context)
                          : sectionInfo.getTitle(context),
                      style: TextTheme.of(context).titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                        color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                      ),
                    ),
                    ShowAllButton(
                      onPressed: () {
                        if (sectionInfo.type == HomeScreenSectionType.tabView) {
                          Navigator.of(context).push(
                            MaterialPageRoute<MusicScreen>(
                              builder: (context) => MusicScreen(
                                showHeader: false,
                                tabTypeFilter: sectionInfo.contentType,
                                sortAndFilterConfigurationOverrideInit: sectionInfo.sortAndFilterConfiguration,
                              ),
                            ),
                          );
                        } else {
                          Navigator.pushNamed(context, ShowAllScreen.routeName, arguments: sectionInfo);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(flex: 0, child: HomeScreenSectionContent(sectionInfo: sectionInfo)),
            ],
          ),
        );
      },
    );
  }
}

class HomeScreenSectionContent extends ConsumerWidget {
  const HomeScreenSectionContent({super.key, required this.sectionInfo, this.interactive = true});

  final HomeScreenSectionConfiguration sectionInfo;
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //!!! remove the preset type to allow matching the provider content based just on its media properties
    final items = ref.watch(loadHomeSectionItemsProvider(sectionInfo: sectionInfo));
    final source = QueueItemSource.rawId(
      type: QueueItemSourceType.homeScreenSection,
      name: QueueItemSourceName(
        type: QueueItemSourceNameType.homeScreenSection,
        localizationParameter: sectionInfo.presetType?.name,
        pretranslatedName: sectionInfo.getTitle(context),
      ),
      id: sectionInfo.toLocalisedString(context),
    );
    return switch (items) {
      AsyncData(:final value) => switch (value) {
        null => _buildHorizontalSkeletonLoader(context),
        [] => const Center(child: Text("No items available.", maxLines: 1)),
        _ => SizedBox(
          height: calculateItemCollectionCardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: value.length,
            itemBuilder: (context, index) {
              final BaseItemDto item = value[index];
              return ItemWrapper(
                key: ValueKey(item.id),
                item: item,
                isGrid: true,
                interactive: interactive,
                source: source,
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8, height: 1),
          ),
        ),
        // _ => _buildHorizontalSkeletonLoader(),
      },
      AsyncError(:final error) => () {
        _homeScreenLogger.severe("Error loading items: $error");
        return Center(child: Text("Failed to load items.", maxLines: 1));
      }(),
      _ => _buildHorizontalSkeletonLoader(context),
    };
  }

  Widget _buildHorizontalSkeletonLoader(BuildContext context) {
    final skeletonBaseColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade300
        : Colors.grey.shade800;
    return SizedBox(
      height: calculateItemCollectionCardHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5, // Show 5 skeleton items
        itemBuilder: (context, index) {
          final cardWidth = calculateItemCollectionCardWidth(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: cardWidth,
                height: cardWidth,
                decoration: BoxDecoration(color: skeletonBaseColor, borderRadius: BorderRadius.circular(8)),
              ),
              SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Container(
                  width: cardWidth * Random().nextDouble().clamp(0.2, 0.9),
                  height: max(calculateTextHeight(style: TextTheme.of(context).bodySmall!, lines: 1) - 4, 0),
                  decoration: BoxDecoration(color: skeletonBaseColor, borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Container(
                  width: cardWidth * Random().nextDouble().clamp(0.2, 0.9),
                  height: max(calculateTextHeight(style: TextTheme.of(context).bodySmall!, lines: 1) - 4, 0),
                  decoration: BoxDecoration(color: skeletonBaseColor, borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
      ),
    );
  }
}

@Riverpod(keepAlive: true)
Future<List<BaseItemDto>?> loadHomeSectionItems(
  Ref ref, {
  required HomeScreenSectionConfiguration sectionInfo,
  int startIndex = 0,
  int limit = homeScreenSectionItemLimit,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final settings = FinampSettingsHelper.finampSettings;

  final Future<List<BaseItemDto>?> newItemsFuture;

  if (settings.isOffline) {
    newItemsFuture = loadHomeSectionItemsOffline(sectionInfo: sectionInfo, startIndex: startIndex, limit: limit);
    return newItemsFuture;
  }

  switch (sectionInfo.type) {
    case HomeScreenSectionType.tabView:
      newItemsFuture = jellyfinApiHelper.getItems(
        parentItem: sectionInfo.contentType == TabContentType.playlists
            ? null
            : finampUserHelper.currentUser?.currentView,
        includeItemTypes: [sectionInfo.contentType?.itemType?.jellyfinName].join(","),
        sortBy: sectionInfo.sortAndFilterConfiguration.sortBy.jellyfinName(null),
        sortOrder: sectionInfo.sortAndFilterConfiguration.sortOrder.toString(),
        filters: sectionInfo.sortAndFilterConfiguration.filters
            .map(
              (filter) => switch (filter.type) {
                ItemFilterType.isFavorite => "IsFavorite",
                ItemFilterType.isFullyDownloaded => null, // only applicable for offline mode
                // ItemFilterType.startsWithCharacter => "NameStartsWith: ${filter.value}",
                ItemFilterType.startsWithCharacter =>
                  null, //TODO properly handle the "NameStartsWith" filter in the API helper
              },
            )
            .nonNulls
            .join(","),
        startIndex: startIndex,
        limit: limit,
      );
      break;
    case HomeScreenSectionType.collection:
      final baseItem = await GetIt.instance<ProviderContainer>().read(itemByIdProvider(sectionInfo.itemId!).future);
      newItemsFuture = jellyfinApiHelper.getItems(
        parentItem: baseItem,
        recursive: false, //!!! prevent loading tracks and albums from inside the collection items
        sortBy: sectionInfo.sortAndFilterConfiguration.sortBy.jellyfinName(null),
        sortOrder: sectionInfo.sortAndFilterConfiguration.sortOrder.toString(),
        filters: sectionInfo.sortAndFilterConfiguration.filters
            .map(
              (filter) => switch (filter.type) {
                ItemFilterType.isFavorite => "IsFavorite",
                ItemFilterType.isFullyDownloaded => null, // only applicable for offline mode
                // ItemFilterType.startsWithCharacter => "NameStartsWith: ${filter.value}",
                ItemFilterType.startsWithCharacter =>
                  null, //TODO properly handle the "NameStartsWith" filter in the API helper
              },
            )
            .nonNulls
            .join(","),
        startIndex: startIndex,
        limit: limit,
      );
      break;
  }

  return await newItemsFuture;
}

Future<List<BaseItemDto>?> loadHomeSectionItemsOffline({
  required HomeScreenSectionConfiguration sectionInfo,
  int startIndex = 0,
  int limit = 10,
}) async {
  final FinampSettings settings = FinampSettingsHelper.finampSettings;
  final downloadsService = GetIt.instance<DownloadsService>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();

  List<DownloadStub> offlineItems;
  List<BaseItemDto> items;

  switch (sectionInfo.type) {
    // case HomeScreenSectionType.listenAgain:
    //   //FIXME this seems to also return metadata-only albums which don't have any downloaded children
    //   offlineItems = await downloadsService.getAllCollections(
    //     includeItemTypes: [BaseItemDtoType.album, BaseItemDtoType.playlist], //FIXME support allowing multiple types
    //     fullyDownloaded: settings.onlyShowFullyDownloaded,
    //     viewFilter: finampUserHelper.currentUser?.currentViewId,
    //     childViewFilter: null,
    //     nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
    //     onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
    //   );

    //   items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
    //   items = sortItems(items, SortBy.datePlayed, SortOrder.descending);
    //   break;

    // case HomeScreenSectionType.newlyAdded:
    //   offlineItems = await downloadsService.getAllCollections(
    //     includeItemTypes: [BaseItemDtoType.album, BaseItemDtoType.playlist], //FIXME support allowing multiple types
    //     fullyDownloaded: settings.onlyShowFullyDownloaded,
    //     viewFilter: finampUserHelper.currentUser?.currentViewId,
    //     childViewFilter: null,
    //     nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
    //     onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
    //   );
    //   items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
    //   items = sortItems(items, SortBy.dateCreated, SortOrder.descending);
    //   break;
    // case HomeScreenSectionType.favoriteArtists:
    //   offlineItems = await downloadsService.getAllCollections(
    //     includeItemTypes: [BaseItemDtoType.artist],
    //     fullyDownloaded: settings.onlyShowFullyDownloaded,
    //     viewFilter: finampUserHelper.currentUser?.currentViewId,
    //     childViewFilter: null,
    //     nullableViewFilters: false,
    //     onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
    //   );
    //   items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
    //   items = sortItems(items, SortBy.datePlayed, SortOrder.descending);
    //   break;
    case HomeScreenSectionType.tabView:
      //FIXME this seems to also return metadata-only albums which don't have any downloaded children
      if (sectionInfo.contentType == TabContentType.tracks) {
        // tracks are not stored as collections, so we need to get them differently
        offlineItems = await downloadsService.getAllTracks(
          viewFilter: finampUserHelper.currentUser?.currentViewId,
          nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
          onlyFavorites: sectionInfo.sortAndFilterConfiguration.filters.any(
            (filter) => filter.type == ItemFilterType.isFavorite,
          ),
        );
      } else {
        offlineItems = await downloadsService.getAllCollections(
          includeItemTypes: [
            sectionInfo.contentType?.itemType ?? BaseItemDtoType.album,
          ], //FIXME support allowing multiple types
          fullyDownloaded: settings.onlyShowFullyDownloaded,
          viewFilter: finampUserHelper.currentUser?.currentViewId,
          childViewFilter: null,
          nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
          onlyFavorites: sectionInfo.sortAndFilterConfiguration.filters.any(
            (filter) => filter.type == ItemFilterType.isFavorite,
          ),
        );
      }

      items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
      items = sortItems(items, SortBy.datePlayed, SortOrder.descending);
      break;
    case HomeScreenSectionType.collection:
      final baseItem = GetIt.instance<ProviderContainer>().read(itemByIdProvider(sectionInfo.itemId!)).valueOrNull;
      if (baseItem == null) {
        return [];
      }
      offlineItems = await downloadsService.getAllCollections(
        relatedTo: baseItem,
        fullyDownloaded: settings.onlyShowFullyDownloaded,
        //TODO collections are cross-library - should we really filter by library here?
        viewFilter: finampUserHelper.currentUser?.currentViewId,
        childViewFilter: null,
        nullableViewFilters: settings.showDownloadsWithUnknownLibrary,
        onlyFavorites: settings.onlyShowFavorites && settings.trackOfflineFavorites,
      );
      items = offlineItems.map((e) => e.baseItem).nonNulls.toList();
      break;
  }

  return items.take(limit).toList();
}
