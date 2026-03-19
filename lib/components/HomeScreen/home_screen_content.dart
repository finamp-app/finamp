import 'dart:math';

import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/Buttons/cta_large.dart';
import 'package:finamp/components/Buttons/cta_small.dart';
import 'package:finamp/components/HomeScreen/show_all_button.dart';
import 'package:finamp/components/HomeScreen/show_all_screen.dart';
import 'package:finamp/components/MusicScreen/item_card.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/components/finamp_section_header.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/home_screen_settings_screen.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../../services/music_screen_provider.dart';

final _homeScreenLogger = Logger("HomeScreen");

class HomeScreenContent extends ConsumerStatefulWidget {
  const HomeScreenContent({super.key, this.refresh});

  final MusicRefreshCallback? refresh;

  @override
  ConsumerState<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<HomeScreenContent> {
  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();

  void _refresh() {
    var currentLibrary = ref.watch(
      FinampUserHelper.finampCurrentUserProvider.select((value) => value.valueOrNull?.currentView),
    );
    for (var section in ref.watch(finampSettingsProvider.homeScreenConfiguration).sections) {
      ref.invalidate(
        loadHomeSectionItemsProvider(
          sectionInfo: section,
          library: currentLibrary,
          startIndex: 0,
          limit: homeScreenSectionItemLimit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.refresh?.callback = _refresh;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(padding: const EdgeInsets.only(top: 16.0)),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = 600;
                // center action buttons
                final horizontalPadding = max(0, (constraints.crossAxisExtent - maxWidth) / 2);
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding + 14.0),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 0,
                      runSpacing: 8,
                      direction: Axis.horizontal,
                      alignment: WrapAlignment.spaceAround,
                      runAlignment: WrapAlignment.center,
                      children: ref.watch(finampSettingsProvider.homeScreenConfiguration).actions.map((action) {
                        return CTALarge(
                          text: action.toLocalisedString(context),
                          label: action.getDescription(context),
                          icon: switch (action) {
                            FinampQuickActions.trackMix => TablerIcons.arrows_shuffle,
                            FinampQuickActions.recents => TablerIcons.calendar,
                            FinampQuickActions.surpriseMe => TablerIcons.radio,
                          },
                          vertical: true,
                          minWidth: 110,
                          onPressed: switch (action) {
                            FinampQuickActions.trackMix => () {
                              _audioServiceHelper.shuffleAll(
                                onlyShowFavorites: ref.watch(finampSettingsProvider.onlyShowFavorites) ?? false,
                              );
                            },
                            FinampQuickActions.recents => () {
                              Navigator.pushNamed(context, QueueRestoreScreen.routeName);
                            },
                            FinampQuickActions.surpriseMe => () async {
                              await GetIt.instance<AudioServiceHelper>().startSurpriseMeMix();
                            },
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            SliverMainAxisGroup(
              slivers: ref
                  .watch(finampSettingsProvider.homeScreenConfiguration)
                  .sections
                  .map((sectionInfo) => HomeScreenSection(sectionInfo: sectionInfo))
                  .toList(),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 60)),
            ...[
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 200),
                    child: BalancedText(
                      "Looking for something else?",
                      textAlign: TextAlign.center,
                      style: TextTheme.of(context).bodySmall,
                    ),
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(top: 12)),
              SliverToBoxAdapter(
                child: Center(
                  child: CTASmall(
                    text: "Customize home screen",
                    icon: TablerIcons.settings,
                    onPressed: () => Navigator.pushNamed(context, HomeScreenSettingsScreen.routeName),
                  ),
                ),
              ),
            ],
            const SliverPadding(padding: EdgeInsets.only(top: 60)),
            ...[
              // monochrome icon
              SliverToBoxAdapter(
                child: FinampIcon(56, 56, overrideColor: TextTheme.of(context).bodySmall?.color?.withOpacity(0.4)),
              ),
              const SliverPadding(padding: EdgeInsets.only(top: 16)),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 200),
                    child: BalancedText(
                      "Built with ♥ by the Finamp contributors.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: TextTheme.of(context).bodySmall?.color?.withOpacity(0.6)),
                    ),
                  ),
                ),
              ),
            ],
            SliverPadding(padding: const EdgeInsets.only(bottom: 100.0)),
          ],
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
    var currentLibrary = ref.watch(
      FinampUserHelper.finampCurrentUserProvider.select((value) => value.valueOrNull?.currentView),
    );
    bool isOffline = ref.watch(finampSettingsProvider.isOffline);
    bool isDownloaded =
        sectionInfo.type !=
        HomeScreenSectionType
            .collection; //TODO implement once collection downloads or generic item sections are supported
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 8.0),
      sliver: FinampSectionHeader(
        key: Key(sectionInfo.toString()),
        title: sectionInfo.itemId != null
            ? ref.watch(itemByIdProvider(sectionInfo.itemId!)).valueOrNull?.name ?? sectionInfo.getTitle(context)
            : sectionInfo.getTitle(context),
        headerPadding: const EdgeInsets.only(left: 14.0, right: 8.0),
        contentPadding: EdgeInsets.zero,
        actions: (isOffline && !isDownloaded)
            ? []
            : [
                if (sectionInfo.type == HomeScreenSectionType.tabView &&
                    sectionInfo.contentType == TabContentType.tracks)
                //TODO use similar logic to [loadChildTracksFromShuffledGenreAlbums] for loading tracks from other tab types
                //TODO for collections, try to recursively load tracks directly, Jellyfin can do that
                ...[
                  IconButtonWithSemantics(
                    onPressed: () async {
                      final queueService = GetIt.instance<QueueService>();
                      final source = QueueItemSource.rawId(
                        type: QueueItemSourceType.homeScreenSection,
                        name: QueueItemSourceName(
                          type: QueueItemSourceNameType.homeScreenSection,
                          localizationParameter: sectionInfo.presetType?.name,
                          pretranslatedName: sectionInfo.getTitle(context),
                        ),
                        id: sectionInfo.toLocalisedString(context),
                      );
                      // only add loaded items at first, to ensure order (for random sections) is the same, and to improve responsiveness
                      final initialItems = await ref.read(
                        loadHomeSectionItemsProvider(
                          sectionInfo: sectionInfo,
                          library: currentLibrary,
                          startIndex: 0,
                          limit: homeScreenSectionItemLimit,
                        ).future,
                      );
                      await queueService.startPlayback(
                        items: initialItems ?? [],
                        source: source,
                        order: FinampPlaybackOrder.linear,
                      );
                      // append additional items in the background
                      final isRandomizedSection = sectionInfo.sortAndFilterConfiguration.sortBy == SortBy.random;
                      var items = (await ref.read(
                        loadHomeSectionItemsProvider(
                          sectionInfo: sectionInfo,
                          library: currentLibrary,
                          // skipping existing items in randomized sections isn't needed since the order will be different
                          startIndex: isRandomizedSection ? 0 : homeScreenSectionItemLimit,
                          limit: FinampSettingsHelper.finampSettings.trackShuffleItemCount,
                        ).future,
                      ));
                      if (isRandomizedSection) {
                        // filter duplicates for randomized sections
                        for (var existingTrack in initialItems ?? []) {
                          items?.removeWhere((item) => item.id == existingTrack.id);
                        }
                      }
                      await queueService.addToQueue(
                        // ensure we only add exactly [trackShuffleItemCount] items in total, since we fetched more tracks initially
                        items:
                            items
                                ?.take(
                                  FinampSettingsHelper.finampSettings.trackShuffleItemCount -
                                      (initialItems?.length ?? 0),
                                )
                                .toList() ??
                            [],
                      );
                    },
                    label: AppLocalizations.of(context)!.playButtonLabel,
                    icon: TablerIcons.player_play,
                  ),
                  IconButtonWithSemantics(
                    onPressed: () async {
                      final source = QueueItemSource.rawId(
                        type: QueueItemSourceType.homeScreenSection,
                        name: QueueItemSourceName(
                          type: QueueItemSourceNameType.homeScreenSection,
                          localizationParameter: sectionInfo.presetType?.name,
                          pretranslatedName: sectionInfo.getTitle(context),
                        ),
                        id: sectionInfo.toLocalisedString(context),
                      );
                      // no need to optimize item fetching here, since the order doesn't matter and the provider doesn't support "skipping" tracks, so all [trackShuffleItemCount] items will be loaded anyway
                      final items = await ref.read(
                        loadHomeSectionItemsProvider(
                          sectionInfo: sectionInfo,
                          library: currentLibrary,
                          startIndex: 0,
                          limit: FinampSettingsHelper.finampSettings.trackShuffleItemCount,
                        ).future,
                      );
                      await GetIt.instance<QueueService>().startPlayback(
                        items: items ?? [],
                        source: source,
                        order: FinampPlaybackOrder.shuffled,
                      );
                    },
                    label: AppLocalizations.of(context)!.shuffleButtonLabel,
                    icon: TablerIcons.arrows_shuffle,
                  ),
                ],
                ShowAllButton(
                  label: "Show All*",
                  onPressed: () {
                    if (sectionInfo.type == HomeScreenSectionType.tabView) {
                      Navigator.of(context).push(
                        MaterialPageRoute<MusicScreen>(
                          builder: (context) => MusicScreen(
                            showHeader: false,
                            tabTypeFilter: sectionInfo.contentType,
                            homeScreenSectionConfiguration: sectionInfo,
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
        onTap: () {
          if (sectionInfo.type == HomeScreenSectionType.tabView) {
            Navigator.of(context).push(
              MaterialPageRoute<MusicScreen>(
                builder: (context) => MusicScreen(
                  showHeader: false,
                  tabTypeFilter: sectionInfo.contentType,
                  homeScreenSectionConfiguration: sectionInfo,
                  sortAndFilterConfigurationOverrideInit: sectionInfo.sortAndFilterConfiguration,
                ),
              ),
            );
          } else {
            Navigator.pushNamed(context, ShowAllScreen.routeName, arguments: sectionInfo);
          }
        },
        onDismiss: (followUpAction) async {
          final source = QueueItemSource.rawId(
            type: QueueItemSourceType.homeScreenSection,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.homeScreenSection,
              localizationParameter: sectionInfo.presetType?.name,
              pretranslatedName: sectionInfo.getTitle(context),
            ),
            id: sectionInfo.toLocalisedString(context),
          );
          final items = await ref.read(
            loadHomeSectionItemsProvider(
              sectionInfo: sectionInfo,
              library: currentLibrary,
              startIndex: 0,
              limit: FinampSettingsHelper.finampSettings.trackShuffleItemCount,
            ).future,
          );
          return await onConfirmPlayableDismiss(followUpAction: followUpAction, source: source, tracks: items ?? []);
        },
        sectionContentSliver: SliverToBoxAdapter(child: HomeScreenSectionContent(sectionInfo: sectionInfo)),
      ),
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
    var currentLibrary = ref.watch(
      FinampUserHelper.finampCurrentUserProvider.select((value) => value.valueOrNull?.currentView),
    );
    bool isOffline = ref.watch(finampSettingsProvider.isOffline);
    bool isDownloaded =
        sectionInfo.type !=
        HomeScreenSectionType
            .collection; //TODO implement once collection downloads or generic item sections are supported
    final items = ref
        .watch(
          loadHomeSectionItemsProvider(
            sectionInfo: sectionInfo,
            library: currentLibrary,
            startIndex: 0,
            limit: homeScreenSectionItemLimit,
          ),
        )
        .unwrapPrevious();
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
        [] => const Center(child: Text("No items available.*", maxLines: 1)),
        _ =>
          (isOffline && !isDownloaded)
              ? const Center(child: Text("Section contents not downloaded.*", maxLines: 1))
              : SizedBox(
                  height: calculateItemCollectionCardHeight(
                    context,
                    sectionInfo.contentType?.itemType ?? BaseItemDtoType.album,
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: value.length + 1,
                    itemBuilder: (context, rawIndex) {
                      if (rawIndex == 0) {
                        return SizedBox(width: 4.0); // initial padding, + separator
                      }
                      final index = rawIndex - 1;
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
    final skeletonCount = 10;
    final skeletonBaseColor = Theme.brightnessOf(context) == Brightness.light
        ? Colors.grey.shade300
        : Colors.grey.shade800;
    return SizedBox(
      height: calculateItemCollectionCardHeight(context, sectionInfo.contentType?.itemType ?? BaseItemDtoType.album),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: skeletonCount + 1, // Show [skeletonCount] skeleton items
        itemBuilder: (context, index) {
          if (index == 0) {
            return SizedBox(width: 4.0); // initial padding, + separator
          }
          final cardWidth = calculateItemCollectionCardWidth(
            context,
            sectionInfo.contentType?.itemType ?? BaseItemDtoType.album,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepeatingAnimationBuilder<double>(
                animatable: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                repeatMode: RepeatMode.reverse,
                curve: Curves.easeInOut,
                builder: (BuildContext context, double opacity, Widget? child) {
                  return Stack(
                    children: [
                      Container(
                        width: cardWidth,
                        height: cardWidth,
                        decoration: BoxDecoration(color: skeletonBaseColor, borderRadius: BorderRadius.circular(8)),
                      ),
                      Opacity(
                        opacity: opacity * 0.7,
                        child: Container(
                          width: cardWidth,
                          height: cardWidth,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 3.0,
                              colors: [Colors.white.withOpacity(0.4), Colors.transparent],
                              stops: const [0.1, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (FinampSettingsHelper.finampSettings.showTextOnGridView) ...[
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
            ],
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
      ),
    );
  }
}
