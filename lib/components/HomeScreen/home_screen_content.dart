import 'dart:math';
import 'dart:ui';

import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/AlbumScreen/download_button.dart';
import 'package:finamp/components/Buttons/cta_small.dart';
import 'package:finamp/components/HomeScreen/home_screen_quick_action_button.dart';
import 'package:finamp/components/HomeScreen/show_all_button.dart';
import 'package:finamp/components/MusicScreen/item_card.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/finamp_section_header.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:finamp/menus/home_section_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/screens/home_screen_settings_screen.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_screen_provider.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/quick_actions_service.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:logging/logging.dart';

import '../../extensions/localizations.dart';
import '../../services/music_providers.dart';

final _homeScreenLogger = Logger("HomeScreen");

class HomeScreenContent extends ConsumerStatefulWidget {
  const HomeScreenContent({super.key, this.refresh});

  final MusicRefreshCallback? refresh;

  @override
  ConsumerState<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<HomeScreenContent>
    with AutomaticKeepAliveClientMixin<HomeScreenContent> {
  // tabs on the music screen should be kept alive
  @override
  bool get wantKeepAlive => true;

  void _refresh() async {
    for (var section in ref.watch(finampSettingsProvider.homeScreenConfiguration).sections) {
      final displayable = await ref.watch(resolveSectionProvider(section).future);
      ref.read(pagedContentProvider(displayable).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    widget.refresh?.callback = _refresh;
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: CustomScrollView(
        slivers: [
          if (ref.watch(finampSettingsProvider.homeScreenConfiguration).actions.isNotEmpty)
            SliverPadding(padding: const EdgeInsets.only(top: 16.0)),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = isDesktop ? 800.0 : 600.0;
              final viewPadding = MediaQuery.paddingOf(context);
              final usableWidth = constraints.crossAxisExtent - viewPadding.left - viewPadding.right;
              // center action buttons
              // Mandatory padding should be enough to clear scrollbar
              final horizontalPadding = max(0, (usableWidth - maxWidth) / 2) + 14.0;
              final configuredQuickActions = ref.watch(finampSettingsProvider.homeScreenConfiguration).actions;
              return SliverPadding(
                padding: EdgeInsets.only(
                  left: horizontalPadding + viewPadding.left,
                  right: horizontalPadding + viewPadding.right,
                ),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: isDesktop ? 4.0 : 0,
                    runSpacing: 8,
                    direction: Axis.horizontal,
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: configuredQuickActions.indexed.map((indexedAction) {
                      final (index, action) = indexedAction;
                      //!!! custom adaptive grid
                      // calculate button width based on available space and number of actions per row
                      final double quickActionsWidth = min(
                        usableWidth - horizontalPadding - horizontalPadding,
                        maxWidth,
                      );
                      double verticalButtonWidth = (quickActionsWidth / 3) - 2 * (5.0);
                      double horizontalButtonWidth = (quickActionsWidth / 2) - 1 * (8.0);
                      double singleButtonWidth = quickActionsWidth;
                      double buttonWidth;
                      // always fill each row completely
                      if (configuredQuickActions.length == 1) {
                        buttonWidth = singleButtonWidth;
                      } else if (configuredQuickActions.length % 3 == 0) {
                        buttonWidth = verticalButtonWidth;
                      } else if (configuredQuickActions.length == 4) {
                        buttonWidth = horizontalButtonWidth;
                      } else if ((configuredQuickActions.length % 3 == 1 &&
                              configuredQuickActions.length - index <= 4) ||
                          (configuredQuickActions.length % 3 == 2 && configuredQuickActions.length - index < 3)) {
                        buttonWidth = horizontalButtonWidth;
                      } else {
                        buttonWidth = verticalButtonWidth;
                      }
                      return HomeScreenQuickActionButton(
                        width: buttonWidth,
                        text: action.getTitle(context.l10n),
                        label: action.action.getDescription(context),
                        icon: action.action.getIcon(),
                        vertical: buttonWidth == verticalButtonWidth,
                        onPressed: () async => QuickActionsService.handleAction(action, context),
                        onSecondaryPressed: () => editQuickAction(context, index),
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
          const SliverPadding(padding: EdgeInsets.only(top: 30)),
          ...[
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 200),
                  child: BalancedText(
                    context.l10n.lookingForSomethingElse,
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
                  text: context.l10n.customizeHomeScreen,
                  icon: TablerIcons.settings,
                  onPressed: () => Navigator.pushNamed(context, HomeScreenSettingsScreen.routeName),
                ),
              ),
            ),
          ],
          /*const SliverPadding(padding: EdgeInsets.only(top: 60)),
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
                    context.l10n.builtWithByTheFinampContributors,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: TextTheme.of(context).bodySmall?.color?.withOpacity(0.6)),
                  ),
                ),
              ),
            ),
          ],*/
          SliverSafeArea(top: false, sliver: SliverPadding(padding: const EdgeInsets.only(bottom: 40.0))),
        ],
      ),
    );
  }
}

class HomeScreenSection extends ConsumerWidget {
  const HomeScreenSection({super.key, required this.sectionInfo});

  final HomeScreenSectionConfiguration sectionInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionDisplayable = ref.watch(resolveSectionProvider(sectionInfo)).value;

    final viewPadding = MediaQuery.paddingOf(context);
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 8.0),
      sliver: FinampSectionHeader(
        sticky: false,
        key: Key(sectionInfo.toString()),
        title: sectionInfo.getTitle(context.l10n),
        headerPadding: EdgeInsets.only(left: viewPadding.left + 14.0, right: viewPadding.right + 20.0),
        contentPadding: EdgeInsets.zero,
        actions: [
          if (sectionDisplayable is FinampPlayable) ...[
            IconButtonWithSemantics(
              onPressed: () async {
                final queueService = GetIt.instance<QueueService>();
                final playable = sectionDisplayable as FinampPlayable;
                // TODO restore gradual queue buildup?
                await queueService.startPlayback(
                  items: (await ref.read(getPlayerSliceProvider(item: playable, startingOffset: 0).future)).items,
                  source: playable.source,
                  order: FinampPlaybackOrder.linear,
                );

                /*
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
                            startIndex: 0,
                            limit: homeScreenSectionItemLimit,
                          ).future,
                        );
                        await queueService.startPlayback(
                          items: initialItems ?? [],
                          source: source,
                          order: FinampPlaybackOrder.linear,
                        );
                        var items = (await ref.read(
                          loadHomeSectionItemsProvider(
                            sectionInfo: sectionInfo,
                            // skipping existing items in randomized sections isn't needed since the order will be different
                            startIndex: homeScreenSectionItemLimit,
                            limit: FinampSettingsHelper.finampSettings.trackShuffleItemCount,
                          ).future,
                        ));
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
                        );*/
              },
              label: AppLocalizations.of(context)!.playButtonLabel,
              icon: TablerIcons.player_play,
            ),
            IconButtonWithSemantics(
              onPressed: sectionInfo.sortConfig.sortBy == SortBy.random
                  ? null
                  : () async {
                      final queueService = GetIt.instance<QueueService>();
                      final playable = sectionDisplayable as FinampPlayable;
                      // TODO better shuffling?  need to think about shuffle all versus shuffle first
                      // TODO restore gradual queue buildup?
                      await queueService.startPlayback(
                        items: (await ref.read(getPlayerSliceProvider(item: playable, startingOffset: 0).future)).items,
                        source: playable.source,
                        order: FinampPlaybackOrder.shuffled,
                      );
                    },
              label: sectionInfo.sortConfig.sortBy == SortBy.random
                  ? context.l10n.alreadyRandomized
                  : context.l10n.shuffleButtonLabel,
              icon: TablerIcons.arrows_shuffle,
            ),
          ],
          // bind function result to downloadInfo and proceed if not null
          if (getHomeDownloadInfo(ref, context.l10n, sectionInfo, sectionDisplayable?.maybeItem) case var downloadInfo?)
            DownloadButton(
              item: downloadInfo.stub,
              allowServerDelete: false,
              warningMessage: downloadInfo.warning,
              downloadOnly: true,
            ),
          ShowAllButton(
            label: context.l10n.showAll,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute<MusicScreen>(builder: (context) => MusicScreen(singleTabConfig: sectionInfo)));
            },
          ),
        ],
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<MusicScreen>(builder: (context) => MusicScreen(singleTabConfig: sectionInfo)));
        },
        onSecondaryTap: () => showModalHomeSectionMenu(context: context, section: sectionInfo),
        onDismiss: null,
        sectionContentSliver: SliverToBoxAdapter(
          /* child: ShaderMask(
            shaderCallback: (bounds) {
              final leftFade = 9.0 / bounds.width;
              final rightFade = 20.0 / bounds.width;
              final leftOffset = 5.0 / bounds.width;
              final rightOffset = 20.0 / bounds.width;
              return LinearGradient(
                colors: [
                  Color.fromARGB(0, 255, 255, 255),
                  Color.fromARGB(0, 255, 255, 255),
                  Color.fromARGB(255, 255, 255, 255),
                  Color.fromARGB(255, 255, 255, 255),
                  Color.fromARGB(0, 255, 255, 255),
                  Color.fromARGB(0, 255, 255, 255),
                ],
                stops: [0.0, leftOffset, leftOffset + leftFade, 1.0 - rightOffset - rightFade, 1.0 - rightOffset, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            child: HomeScreenSectionContent(sectionInfo: sectionInfo),
          ) */
          child: HomeScreenSectionContent(sectionInfo: sectionInfo),
        ),
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
    bool isOffline = ref.watch(finampSettingsProvider.isOffline);

    final asyncDisplayable = ref.watch(resolveSectionProvider(sectionInfo));
    if (asyncDisplayable.isLoading) {
      return _buildHorizontalSkeletonLoader(ref);
    } else if (asyncDisplayable.hasError) {
      _homeScreenLogger.severe("Error resolving library: ${asyncDisplayable.error}", asyncDisplayable.error);
      return Center(child: Text(context.l10n.failedToLoadSection, maxLines: 1));
    } else if (asyncDisplayable.value == null) {
      return isOffline
          ? Center(child: Text(context.l10n.sectionContentsNotDownloaded, maxLines: 1))
          : Center(child: Text(context.l10n.failedToLoadSectionMissingItem, maxLines: 1));
    }
    final displayable = asyncDisplayable.value!;
    if (displayable is FinampSortable && (displayable as FinampSortable).sortConfig != sectionInfo.sortConfig) {
      assert(isOffline);
      return Center(child: Text(context.l10n.notAvailableInOfflineMode, maxLines: 1));
    }

    final pageState = ref.watch(pagedContentProvider(displayable));
    final items = pageState.items;
    if (items == null) {
      if (pageState.isLoading) {
        return _buildHorizontalSkeletonLoader(ref);
      } else if (pageState.error != null) {
        _homeScreenLogger.severe("Error loading items: ${pageState.error}", pageState.error);
        return Center(child: Text(context.l10n.errorLoadingItems, maxLines: 1));
      } else {
        ref.read(pagedContentProvider(displayable).notifier).fetchHomeScreenItems();
        return _buildHorizontalSkeletonLoader(ref);
      }
    } else if (items.isEmpty) {
      return isOffline
          ? Center(child: Text(context.l10n.sectionContentsNotDownloaded, maxLines: 1))
          : Center(child: Text(context.l10n.noItemsAvailable, maxLines: 1));
    } else {
      return SizedBox(
        height: calculateItemCollectionCardHeight(ref: ref, sectionInfo: sectionInfo, itemType: null),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
          child: ListView.separated(
            addAutomaticKeepAlives: true,
            scrollDirection: Axis.horizontal,
            itemCount: items.length + 2,
            itemBuilder: (context, rawIndex) {
              if (rawIndex == 0) {
                return SizedBox(width: 4.0); // initial padding, + separator
              } else if (rawIndex == items.length + 1) {
                // Add extra right padding if we have hit the end of list and there are no more items available
                if (items.length < homeScreenSectionItemLimit) {
                  return SizedBox(width: 40);
                } else {
                  return SizedBox(width: 0);
                }
              }
              final index = rawIndex - 1;
              switch (items[index]) {
                case FinampPlayableDto item:
                  return ItemWrapper(
                    key: ValueKey(item.item.id),
                    item: item.item,
                    isGrid: true,
                    forceText: true,
                    interactive: interactive,
                    source: displayable.source,
                  );
                case PlayableQueue queue:
                  return HomeScreenQueueTile(key: ValueKey(queue.queue.creation), info: queue.queue);
                case LatestQueues():
                case PrecalculatedPlayable():
                case MusicScreenPlayable<FinampPlayableDto>():
                  throw UnsupportedError("Unexpected item ${items[index]} in home screen section");
              }
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8, height: 1),
          ),
        ),
      );
    }
  }

  Widget _buildHorizontalSkeletonLoader(WidgetRef ref) {
    final skeletonCount = 10;
    final skeletonBaseColor = Theme.brightnessOf(ref.context) == Brightness.light
        ? Colors.grey.shade300
        : Colors.grey.shade800;
    final skeletonOverlay = Theme.brightnessOf(ref.context) == Brightness.light
        ? Colors.grey.shade400
        : Colors.grey.shade700;
    return SizedBox(
      height: calculateItemCollectionCardHeight(ref: ref, sectionInfo: sectionInfo, itemType: null),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: skeletonCount + 1, // Show [skeletonCount] skeleton items
        itemBuilder: (context, index) {
          if (index == 0) {
            return SizedBox(width: 4.0); // initial padding, + separator
          }
          final double cardWidth;
          final double cardHeight;
          final bool showText;
          if (sectionInfo.base is QueuesHomeSection) {
            cardWidth = queuesHomeSectionWidth;
            cardHeight = queuesHomeSectionHeight;
            showText = false;
          } else {
            cardWidth = calculateItemCollectionCardWidth(ref).$1;
            cardHeight = calculateItemCollectionCardWidth(ref).$1;
            showText = true;
          }
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
                        height: cardHeight,
                        decoration: BoxDecoration(color: skeletonBaseColor, borderRadius: BorderRadius.circular(8)),
                      ),
                      Opacity(
                        opacity: opacity * 0.7,
                        child: Container(
                          width: cardWidth,
                          height: cardHeight,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 3.0,
                              colors: [skeletonOverlay, Colors.transparent],
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
              if (showText) ...[
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
