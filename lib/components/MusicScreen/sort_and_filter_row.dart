import 'package:collection/collection.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class SortAndFilterController extends ValueNotifier<SortAndFilterConfiguration> {
  SortAndFilterController({required SortAndFilterConfiguration configuration, this.onConfigurationChanged})
    : super(configuration);

  final void Function(SortAndFilterConfiguration)? onConfigurationChanged;

  SortAndFilterConfiguration get configuration => value;

  void updateConfiguration(SortAndFilterConfiguration newConfig) {
    value = newConfig;
    notifyListeners();
    if (onConfigurationChanged != null) {
      onConfigurationChanged!(newConfig);
    }
  }
}

class SortAndFilterRow extends ConsumerWidget {
  final TabContentType tabType;
  final void Function(TabContentType) refreshTab;
  final SortAndFilterController? controller;

  final bool forPlaylistTracks;

  const SortAndFilterRow({
    super.key,
    required this.tabType,
    required this.refreshTab,
    this.controller,
    this.forPlaylistTracks = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    controller?.addListener(() => refreshTab(tabType));
    if (tabType != TabContentType.home) {
      return SafeArea(
        top: false,
        bottom: false,
        child: GestureDetector(
          onTap: () => showSortAndFilterMenu(
            context,
            tabType: tabType,
            forPlaylistTracks: forPlaylistTracks,
            controller: controller,
          ),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) {
                    final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
                    final activeFilters =
                        controller?.configuration.filters ??
                        {
                          if (ref.watch(finampSettingsProvider.onlyShowFavorites))
                            ItemFilter(type: ItemFilterType.isFavorite),
                          if (ref.watch(finampSettingsProvider.onlyShowFullyDownloaded))
                            ItemFilter(type: ItemFilterType.isFullyDownloaded),
                        };
                    final int activeFilterCount = activeFilters.length;
                    String statusText = activeFilterCount == 0
                        ? "No Filter Active*"
                        : "$activeFilterCount ${activeFilterCount == 1 ? "Filter" : "Filters"} Active*";
                    return SimpleButton(
                      icon: TablerIcons.filter,
                      text: statusText,
                      fontWeight: activeFilterCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      iconColor: activeFilterCount > 0
                          ? ColorScheme.of(context).primary
                          : TextTheme.of(context).bodyMedium?.color?.withOpacity(0.7),
                      textColor: activeFilterCount > 0
                          ? ColorScheme.of(context).primary
                          : TextTheme.of(context).bodyMedium?.color?.withOpacity(0.7),
                      onPressed: () => showSortAndFilterMenu(
                        context,
                        tabType: tabType,
                        forPlaylistTracks: forPlaylistTracks,
                        controller: controller,
                      ),
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
                    var selectedSortBy =
                        (controller?.configuration.sortBy ??
                        (forPlaylistTracks
                            ? ref.watch(finampSettingsProvider.playlistTracksSortBy)
                            : ref.watch(finampSettingsProvider.tabSortBy(tabType))));
                    var selectedSortOrder =
                        (controller?.configuration.sortOrder ??
                        (forPlaylistTracks
                            ? ref.watch(finampSettingsProvider.playlistTracksSortOrder)
                            : ref.watch(finampSettingsProvider.tabSortOrder(tabType))));
                    // PlayCount and Last Played are not representative in Offline Mode
                    // so we disable it and overwrite it with the Sort Name if it was selected
                    if (isOffline && (selectedSortBy == SortBy.playCount || selectedSortBy == SortBy.datePlayed)) {
                      selectedSortBy = forPlaylistTracks ? SortBy.defaultOrder : SortBy.sortName;
                    }
                    return SimpleButton(
                      icon: selectedSortOrder == SortOrder.ascending
                          ? TablerIcons.sort_ascending
                          : TablerIcons.sort_descending,
                      text: selectedSortBy?.toLocalisedString(context) ?? AppLocalizations.of(context)!.sortBy,
                      onPressed: () => showSortAndFilterMenu(
                        context,
                        tabType: tabType,
                        forPlaylistTracks: forPlaylistTracks,
                        controller: controller,
                      ),
                    );
                  },
                ),
                // FilterMenuButton(
                //   tabType: tabType,
                //   filterOverride: filterOverride,
                //   updateFilterOverride: (newFilters) => updateFilterOverride?.call(newFilters),
                // ),
                // SortMenuButton(
                //   tabType: tabType,
                //   sortByOverride: sortByOverride,
                //   onSortByOverrideChanged: (newSortBy) => updateSortByOverride?.call(newSortBy),
                //   sortOrderOverride: sortOrderOverride,
                //   updateSortOrderOverride: (newSortOrder) => updateSortOrderOverride?.call(newSortOrder),
                //   forPlaylistTracks: forPlaylistTracks,
                // ),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }
}

Future<void> showSortAndFilterMenu(
  BuildContext context, {
  required TabContentType tabType,
  required bool forPlaylistTracks,
  required SortAndFilterController? controller,
}) async {
  return await showThemedBottomSheet<void>(
    context: context,
    routeName: SortAndFilterMenu.routeName,
    minDraggableHeight: 0.85,
    buildWrapper: (context, dragController, childBuilder) {
      return SortAndFilterMenu(
        childBuilder: childBuilder,
        dragController: dragController,
        tabType: tabType,
        forPlaylistTracks: forPlaylistTracks,
        controller: controller,
      );
    },
  );
}

const Duration sortAndFilterMenuDefaultAnimationDuration = Duration(milliseconds: 500);
const Curve sortAndFilterMenuDefaultInCurve = Curves.easeOutCubic;
const Curve sortAndFilterMenuDefaultOutCurve = Curves.easeInCubic;

class SortAndFilterMenu extends ConsumerStatefulWidget {
  static const routeName = "/sort-and-filter-menu";

  const SortAndFilterMenu({
    super.key,
    required this.childBuilder,
    required this.dragController,
    required this.tabType,
    required this.forPlaylistTracks,
    required this.controller,
  });

  final ScrollBuilder childBuilder;
  final DraggableScrollableController dragController;

  final TabContentType tabType;
  final bool forPlaylistTracks;
  final SortAndFilterController? controller;

  @override
  ConsumerState<SortAndFilterMenu> createState() => _SortAndFilterMenuState();
}

class _SortAndFilterMenuState extends ConsumerState<SortAndFilterMenu> with TickerProviderStateMixin {
  double initialSheetExtent = 0.0;
  double inputStep = 0.9;
  double oldExtent = 0.0;

  late SortAndFilterConfiguration currentConfig;

  @override
  void initState() {
    super.initState();

    initialSheetExtent = 0.85;
    oldExtent = initialSheetExtent;

    if (widget.controller != null) {
      currentConfig = widget.controller!.configuration;
    } else {
      final bool isOffline = FinampSettingsHelper.finampSettings.isOffline;
      var selectedSortBy =
          (widget.controller?.configuration.sortBy ??
          (widget.forPlaylistTracks
              ? FinampSettingsHelper.finampSettings.playlistTracksSortBy
              : FinampSettingsHelper.finampSettings.tabSortBy[widget.tabType]));
      var selectedSortOrder =
          (widget.controller?.configuration.sortOrder ??
          (widget.forPlaylistTracks
              ? FinampSettingsHelper.finampSettings.playlistTracksSortOrder
              : FinampSettingsHelper.finampSettings.tabSortOrder[widget.tabType]));
      // PlayCount and Last Played are not representative in Offline Mode
      // so we disable it and overwrite it with the Sort Name if it was selected
      if (isOffline && (selectedSortBy == SortBy.playCount || selectedSortBy == SortBy.datePlayed)) {
        selectedSortBy = widget.forPlaylistTracks ? SortBy.defaultOrder : SortBy.sortName;
      }

      currentConfig = SortAndFilterConfiguration(
        sortBy: selectedSortBy ?? SortBy.defaultOrder,
        sortOrder: selectedSortOrder ?? SortOrder.ascending,
        filters: {
          if (FinampSettingsHelper.finampSettings.onlyShowFavorites) ItemFilter(type: ItemFilterType.isFavorite),
          if (FinampSettingsHelper.finampSettings.onlyShowFullyDownloaded)
            ItemFilter(type: ItemFilterType.isFullyDownloaded),
        }.toSet(),
      );
    }
  }

  void scrollToExtent(DraggableScrollableController scrollController, double? percentage) {
    var currentSize = scrollController.size;
    if ((percentage != null && currentSize < percentage) || scrollController.size == inputStep) {
      if (MediaQuery.disableAnimationsOf(context)) {
        scrollController.jumpTo(percentage ?? oldExtent);
      } else {
        scrollController.animateTo(
          percentage ?? oldExtent,
          duration: sortAndFilterMenuDefaultAnimationDuration,
          curve: sortAndFilterMenuDefaultInCurve,
        );
      }
    }
    oldExtent = currentSize;
  }

  @override
  Widget build(BuildContext context) {
    final menuEntries = _getMenuEntries(context);
    final stackHeight = 40.0;

    return widget.childBuilder(stackHeight, menu(context, menuEntries));
  }

  // Normal track menu entries, excluding headers
  List<Widget> _getMenuEntries(BuildContext context) {
    final rawSortOptions = SortBy.defaultsFor(
      type: widget.tabType.itemType,
      includeDefaultOrder: widget.forPlaylistTracks,
    );
    final sortOptions = ref.watch(finampSettingsProvider.isOffline)
        ? [
            ...rawSortOptions.where((s) => s != SortBy.playCount && s != SortBy.datePlayed),
            ...rawSortOptions.where((s) => s == SortBy.playCount || s == SortBy.datePlayed),
          ]
        : rawSortOptions;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text("Section Type*", style: Theme.of(context).textTheme.bodyMedium),
          ),
          FinampSettingsDropdown<SortBy>(
            dropdownItems: sortOptions
                .map(
                  (e) => DropdownMenuEntry<SortBy>(
                    value: e,
                    label: e.toLocalisedString(context),
                    leadingIcon: Icon(e.getIcon()),
                  ),
                )
                .toList(),
            selectedValue: currentConfig.sortBy,
            selectedIcon: currentConfig.sortBy.getIcon(),
            onSelected: (sortBy) {
              if (sortBy != null) {
                currentConfig = currentConfig.copyWith(sortBy: sortBy);
              }
            },
          ),
        ],
      ),
      SizedBox(height: 20.0),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text("Section Type*", style: Theme.of(context).textTheme.bodyMedium),
          ),
          FinampSettingsDropdown<SortOrder>(
            dropdownItems: SortOrder.values
                .map(
                  (e) => DropdownMenuEntry<SortOrder>(
                    value: e,
                    label: e.toLocalisedString(context),
                    leadingIcon: Icon(e.getIcon()),
                  ),
                )
                .toList(),
            selectedValue: currentConfig.sortOrder,
            selectedIcon: currentConfig.sortOrder.getIcon(),
            onSelected: (sortOrder) {
              if (sortOrder != null) {
                currentConfig = currentConfig.copyWith(sortOrder: sortOrder);
              }
            },
          ),
        ],
      ),
      SizedBox(height: 20.0),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text("Filters*", style: Theme.of(context).textTheme.bodyMedium),
          ),
          ...ItemFilterType.values
              .whereNot((x) => [ItemFilterType.genreFilter, ItemFilterType.searchTerm].contains(x))
              .map(
                (option) => ToggleableListTile(
                  title: option.name,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Icon(switch (option) {
                      ItemFilterType.isFavorite => TablerIcons.heart,
                      ItemFilterType.isFullyDownloaded => TablerIcons.download,
                      ItemFilterType.startsWithCharacter => TablerIcons.sort_ascending,
                      ItemFilterType.genreFilter => throw UnimplementedError(),
                      ItemFilterType.searchTerm => throw UnimplementedError(),
                    }),
                  ),
                  trailing: SizedBox.shrink(),
                  enabled: switch (option) {
                    ItemFilterType.isFullyDownloaded => ref.watch(finampSettingsProvider.isOffline),
                    _ => true,
                  },
                  state: switch (option) {
                    ItemFilterType.isFavorite => currentConfig.filters.contains(
                      ItemFilter(type: ItemFilterType.isFavorite),
                    ),
                    ItemFilterType.isFullyDownloaded => currentConfig.filters.contains(
                      ItemFilter(type: ItemFilterType.isFullyDownloaded),
                    ),
                    ItemFilterType.startsWithCharacter => currentConfig.filters.contains(
                      ItemFilter(type: ItemFilterType.startsWithCharacter, extras: "A"),
                    ),
                    ItemFilterType.genreFilter => throw UnimplementedError(),
                    ItemFilterType.searchTerm => throw UnimplementedError(),
                  },
                  onToggle: (currentState) async {
                    final newFilters = Set<ItemFilter>.from(currentConfig.filters);
                    if (currentState) {
                      newFilters.removeWhere((filter) => filter.type == option);
                    } else {
                      switch (option) {
                        case ItemFilterType.isFavorite:
                          newFilters.add(ItemFilter(type: ItemFilterType.isFavorite));
                          break;
                        case ItemFilterType.isFullyDownloaded:
                          newFilters.add(ItemFilter(type: ItemFilterType.isFullyDownloaded));
                          break;
                        case ItemFilterType.startsWithCharacter:
                          newFilters.add(ItemFilter(type: ItemFilterType.startsWithCharacter, extras: "A"));
                          break;
                        case ItemFilterType.genreFilter:
                          throw UnimplementedError();
                        case ItemFilterType.searchTerm:
                          throw UnimplementedError();
                      }
                    }
                    setState(() {
                      currentConfig = currentConfig.copyWith(filters: newFilters);
                    });
                  },
                ),
              ),
        ],
      ),
      SizedBox(height: 32.0),
      CTAMedium(
        text: "Apply*",
        icon: TablerIcons.check,
        onPressed: () {
          if (widget.controller != null) {
            widget.controller!.updateConfiguration(currentConfig);
          } else {
            if (widget.forPlaylistTracks) {
              if (currentConfig.sortBy != FinampSettingsHelper.finampSettings.playlistTracksSortBy) {
                FinampSetters.setPlaylistTracksSortBy(currentConfig.sortBy);
              }
              if (currentConfig.sortOrder != FinampSettingsHelper.finampSettings.playlistTracksSortOrder) {
                FinampSetters.setPlaylistTracksSortOrder(currentConfig.sortOrder);
              }
            } else {
              if (currentConfig.sortBy != FinampSettingsHelper.finampSettings.tabSortBy[widget.tabType]) {
                FinampSetters.setTabSortBy(widget.tabType, currentConfig.sortBy);
              }
              if (currentConfig.sortOrder != FinampSettingsHelper.finampSettings.tabSortOrder[widget.tabType]) {
                FinampSetters.setTabSortOrder(widget.tabType, currentConfig.sortOrder);
              }
            }

            if (currentConfig.filters.contains(ItemFilter(type: ItemFilterType.isFavorite)) !=
                FinampSettingsHelper.finampSettings.onlyShowFavorites) {
              FinampSetters.setOnlyShowFavorites(
                currentConfig.filters.contains(ItemFilter(type: ItemFilterType.isFavorite)),
              );
            }

            if (currentConfig.filters.contains(ItemFilter(type: ItemFilterType.isFullyDownloaded)) !=
                FinampSettingsHelper.finampSettings.onlyShowFullyDownloaded) {
              FinampSetters.setOnlyShowFullyDownloaded(
                currentConfig.filters.contains(ItemFilter(type: ItemFilterType.isFullyDownloaded)),
              );
            }

            //TODO implement other filters
          }
          Navigator.of(context).pop();
        },
      ),
      SizedBox(height: 200.0),
    ];
  }

  // All track menu slivers, including headers
  List<Widget> menu(BuildContext context, List<Widget> menuEntries) {
    return [
      SliverStickyHeader(
        header: Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2.0,
            children: [Text("Sort & Filter*", style: Theme.of(context).textTheme.titleMedium)],
          ),
        ),
        sliver: MenuMask(
          height: MenuMaskHeight(32.0),
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList.list(children: _getMenuEntries(context)),
          ),
        ),
      ),
    ];
  }
}
