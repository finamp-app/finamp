import 'package:collection/collection.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/MusicScreen/filter_menu_button.dart';
import 'package:finamp/components/MusicScreen/sort_menu_button.dart';
import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class SortAndFilterRow extends ConsumerWidget {
  final TabContentType tabType;
  final void Function(TabContentType) refreshTab;
  final SortBy? sortByOverride;
  final void Function(SortBy?)? updateSortByOverride;
  final SortOrder? sortOrderOverride;
  final void Function(SortOrder?)? updateSortOrderOverride;
  final Set<ItemFilter>? filterOverride;
  final void Function(Set<ItemFilter>?)? updateFilterOverride;

  final bool forPlaylistTracks;

  const SortAndFilterRow({
    super.key,
    required this.tabType,
    required this.refreshTab,
    this.sortByOverride,
    this.updateSortByOverride,
    this.sortOrderOverride,
    this.updateSortOrderOverride,
    this.filterOverride,
    this.updateFilterOverride,
    this.forPlaylistTracks = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tabType != TabContentType.home) {
      return SafeArea(
        top: false,
        bottom: false,
        child: GestureDetector(
          onTap: () => showSortAndFilterMenu(
            context,
            tabType: tabType,
            forPlaylistTracks: forPlaylistTracks,
            sortByOverride: sortByOverride,
            updateSortByOverride: updateSortByOverride,
            sortOrderOverride: sortOrderOverride,
            updateSortOrderOverride: updateSortOrderOverride,
            filterOverride: filterOverride,
            updateFilterOverride: updateFilterOverride,
          ).then((_) => refreshTab(tabType)),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilterMenuButton(
                  tabType: tabType,
                  filterOverride: filterOverride,
                  updateFilterOverride: (newFilters) => updateFilterOverride?.call(newFilters),
                ),
                SortMenuButton(
                  tabType: tabType,
                  sortByOverride: sortByOverride,
                  onSortByOverrideChanged: (newSortBy) => updateSortByOverride?.call(newSortBy),
                  sortOrderOverride: sortOrderOverride,
                  updateSortOrderOverride: (newSortOrder) => updateSortOrderOverride?.call(newSortOrder),
                  forPlaylistTracks: forPlaylistTracks,
                ),
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
  required SortBy? sortByOverride,
  required void Function(SortBy?)? updateSortByOverride,
  required SortOrder? sortOrderOverride,
  required void Function(SortOrder?)? updateSortOrderOverride,
  required Set<ItemFilter>? filterOverride,
  required void Function(Set<ItemFilter>?)? updateFilterOverride,
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
        sortByOverride: sortByOverride,
        updateSortByOverride: updateSortByOverride,
        sortOrderOverride: sortOrderOverride,
        updateSortOrderOverride: updateSortOrderOverride,
        filterOverride: filterOverride,
        updateFilterOverride: updateFilterOverride,
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
    required this.sortByOverride,
    required this.updateSortByOverride,
    required this.sortOrderOverride,
    required this.updateSortOrderOverride,
    required this.filterOverride,
    required this.updateFilterOverride,
  });

  final ScrollBuilder childBuilder;
  final DraggableScrollableController dragController;

  final TabContentType tabType;
  final bool forPlaylistTracks;
  final SortBy? sortByOverride;
  final void Function(SortBy?)? updateSortByOverride;
  final SortOrder? sortOrderOverride;
  final void Function(SortOrder?)? updateSortOrderOverride;
  final Set<ItemFilter>? filterOverride;
  final void Function(Set<ItemFilter>?)? updateFilterOverride;

  @override
  ConsumerState<SortAndFilterMenu> createState() => _SortAndFilterMenuState();
}

class _SortAndFilterMenuState extends ConsumerState<SortAndFilterMenu> with TickerProviderStateMixin {
  double initialSheetExtent = 0.0;
  double inputStep = 0.9;
  double oldExtent = 0.0;

  @override
  void initState() {
    super.initState();

    initialSheetExtent = 0.85;
    oldExtent = initialSheetExtent;

    //TODO compile a SortAndFilterConfiguration based on the current values and overrides, and only update the actual settings on Apply
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
    final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
    final rawSortOptions = SortBy.defaultsFor(
      type: widget.tabType.itemType,
      includeDefaultOrder: widget.forPlaylistTracks,
    );
    final sortOptions = isOffline
        ? [
            ...rawSortOptions.where((s) => s != SortBy.playCount && s != SortBy.datePlayed),
            ...rawSortOptions.where((s) => s == SortBy.playCount || s == SortBy.datePlayed),
          ]
        : rawSortOptions;
    var selectedSortBy =
        (widget.sortByOverride ??
        (widget.forPlaylistTracks
            ? ref.watch(finampSettingsProvider.playlistTracksSortBy)
            : ref.watch(finampSettingsProvider.tabSortBy(widget.tabType))));
    var selectedSortOrder =
        (widget.sortOrderOverride ??
        (widget.forPlaylistTracks
            ? ref.watch(finampSettingsProvider.playlistTracksSortOrder)
            : ref.watch(finampSettingsProvider.tabSortOrder(widget.tabType))));
    // PlayCount and Last Played are not representative in Offline Mode
    // so we disable it and overwrite it with the Sort Name if it was selected
    if (isOffline && (selectedSortBy == SortBy.playCount || selectedSortBy == SortBy.datePlayed)) {
      selectedSortBy = widget.forPlaylistTracks ? SortBy.defaultOrder : SortBy.sortName;
    }

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
            selectedValue: selectedSortBy!,
            selectedIcon: selectedSortBy.getIcon(),
            onSelected: (sortBy) {
              if (sortBy != null) {
                FinampSetters.setTabSortBy(widget.tabType, sortBy);
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
            selectedValue: selectedSortOrder!,
            selectedIcon: selectedSortOrder.getIcon(),
            onSelected: (sortOrder) {
              if (sortOrder != null) {
                FinampSetters.setTabSortOrder(widget.tabType, sortOrder);
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
                    ItemFilterType.isFavorite =>
                      widget.filterOverride != null
                          ? widget.filterOverride!.any((filter) => filter.type == ItemFilterType.isFavorite)
                          : ref.watch(finampSettingsProvider.onlyShowFavorites),
                    ItemFilterType.isFullyDownloaded =>
                      widget.filterOverride != null
                          ? widget.filterOverride!.any((filter) => filter.type == ItemFilterType.isFullyDownloaded)
                          : ref.watch(finampSettingsProvider.onlyShowFullyDownloaded),
                    ItemFilterType.startsWithCharacter =>
                      widget.filterOverride != null
                          ? widget.filterOverride!.any((filter) => filter.type == ItemFilterType.startsWithCharacter)
                          : false,
                    ItemFilterType.genreFilter => throw UnimplementedError(),
                    ItemFilterType.searchTerm => throw UnimplementedError(),
                  },
                  onToggle: (currentState) async {
                    if (widget.filterOverride != null) {
                      final newFilters = Set<ItemFilter>.from(widget.filterOverride!);
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
                      if (widget.updateFilterOverride != null) {
                        widget.updateFilterOverride!(newFilters);
                      }
                    } else {
                      switch (option) {
                        case ItemFilterType.isFavorite:
                          FinampSetters.setOnlyShowFavorites(!ref.read(finampSettingsProvider.onlyShowFavorites));
                          break;
                        case ItemFilterType.isFullyDownloaded:
                          FinampSetters.setOnlyShowFullyDownloaded(
                            !ref.read(finampSettingsProvider.onlyShowFullyDownloaded),
                          );
                          break;
                        //TODO No global setting for this filter yet
                        case ItemFilterType.startsWithCharacter:
                        case ItemFilterType.genreFilter:
                        case ItemFilterType.searchTerm:
                          throw UnimplementedError();
                      }
                    }
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
