import 'package:collection/collection.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
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
import 'package:get_it/get_it.dart';

class SortAndFilterController extends ValueNotifier<SortAndFilterConfiguration> {
  SortAndFilterController({required SortAndFilterConfiguration configuration})
    : _settingsListener = null,
      super(configuration);

  // tabType null indicates this is a playlist, not a music screen tab
  // dispose() must be called if this constructor is used.
  SortAndFilterController.trackSettings({required TabContentType? tabType})
    : super(GetIt.instance<ProviderContainer>().read(sortAndFilterConfigFromSettingsProvider(tabType))) {
    _tabType = tabType;
    _settingsListener = GetIt.instance<ProviderContainer>().listen(
      sortAndFilterConfigFromSettingsProvider(tabType),
      (_, newValue) => updateConfiguration(newValue),
    );
    addListener(_updateSettings);
  }

  late final ProviderSubscription<SortAndFilterConfiguration>? _settingsListener;
  late final TabContentType? _tabType;

  SortAndFilterConfiguration get configuration => value;

  void _updateSettings() {
    if (_settingsListener != null) {
      if (_tabType == null) {
        if (value.sortBy != FinampSettingsHelper.finampSettings.playlistTracksSortBy) {
          FinampSetters.setPlaylistTracksSortBy(value.sortBy);
        }
        if (value.sortOrder != FinampSettingsHelper.finampSettings.playlistTracksSortOrder) {
          FinampSetters.setPlaylistTracksSortOrder(value.sortOrder);
        }
      } else {
        if (value.sortBy != FinampSettingsHelper.finampSettings.tabSortBy[_tabType]) {
          FinampSetters.setTabSortBy(_tabType, value.sortBy);
        }
        if (value.sortOrder != FinampSettingsHelper.finampSettings.tabSortOrder[_tabType]) {
          FinampSetters.setTabSortOrder(_tabType, value.sortOrder);
        }
      }

      if (value.filters.contains(ItemFilter(type: ItemFilterType.isFavorite)) !=
          FinampSettingsHelper.finampSettings.onlyShowFavorites) {
        FinampSetters.setOnlyShowFavorites(value.filters.contains(ItemFilter(type: ItemFilterType.isFavorite)));
      }

      if (value.filters.contains(ItemFilter(type: ItemFilterType.isFullyDownloaded)) !=
          FinampSettingsHelper.finampSettings.onlyShowFullyDownloaded) {
        FinampSetters.setOnlyShowFullyDownloaded(
          value.filters.contains(ItemFilter(type: ItemFilterType.isFullyDownloaded)),
        );
      }
    }
  }

  @override
  void dispose() {
    _settingsListener?.close();
    super.dispose();
  }

  void updateConfiguration(SortAndFilterConfiguration newConfig) {
    value = newConfig;
  }

  // TODO should reactive resolving be built into this controller somehow?  Or is letting consumers handle reactivity fine?
}

final sortAndFilterConfigFromSettingsProvider = Provider.family((Ref ref, TabContentType? tabType) {
  var sortBy = tabType == null
      ? ref.watch(finampSettingsProvider.playlistTracksSortBy)
      : ref.watch(finampSettingsProvider.tabSortBy(tabType));
  var sortOrder = tabType == null
      ? ref.watch(finampSettingsProvider.playlistTracksSortOrder)
      : ref.watch(finampSettingsProvider.tabSortOrder(tabType));
  final filters = {
    if (ref.watch(finampSettingsProvider.onlyShowFavorites)) ItemFilter(type: ItemFilterType.isFavorite),
    if (ref.watch(finampSettingsProvider.onlyShowFullyDownloaded)) ItemFilter(type: ItemFilterType.isFullyDownloaded),
  };

  return SortAndFilterConfiguration(
    sortBy: sortBy ?? SortBy.defaultOrder,
    sortOrder: sortOrder ?? SortOrder.ascending,
    filters: filters,
  );
});

class SortAndFilterRow extends ConsumerWidget {
  final TabContentType tabType;
  final SortAndFilterController controller;

  final bool forPlaylistTracks;

  const SortAndFilterRow({super.key, required this.tabType, required this.controller, this.forPlaylistTracks = false});

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
            controller: controller,
          ),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final activeFilters = value.filters;
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
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final config = value.resolve(
                      isOffline: ref.watch(finampSettingsProvider.isOffline),
                      inPlaylist: forPlaylistTracks,
                    );
                    return SimpleButton(
                      // TODO the way that values ascend as you go down the page but we show an up arrow is confusing.
                      // Is there a way to resolve this in a more intuitive manner?  What do other programs do?
                      icon: config.sortOrder == SortOrder.ascending
                          ? TablerIcons.sort_ascending
                          : TablerIcons.sort_descending,
                      text: config.sortBy.toLocalisedString(context),
                      onPressed: () => controller.updateConfiguration(
                        controller.value.copyWith(
                          sortOrder: config.sortOrder == SortOrder.ascending
                              ? SortOrder.descending
                              : SortOrder.ascending,
                        ),
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
  required SortAndFilterController controller,
}) async {
  return await showThemedBottomSheet<void>(
    context: context,
    routeName: SortAndFilterMenu.routeName,
    buildWrapper: (_, _, childBuilder) {
      return SortAndFilterMenu(
        childBuilder: childBuilder,
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
    required this.tabType,
    required this.forPlaylistTracks,
    required this.controller,
  });

  final ScrollBuilder childBuilder;

  final TabContentType tabType;
  final bool forPlaylistTracks;
  final SortAndFilterController controller;

  @override
  ConsumerState<SortAndFilterMenu> createState() => _SortAndFilterMenuState();
}

class _SortAndFilterMenuState extends ConsumerState<SortAndFilterMenu> with TickerProviderStateMixin {
  late SortAndFilterConfiguration currentConfig;

  @override
  void initState() {
    super.initState();

    // TODO actually explain what the real current selection is and why we're not using it somewhere?
    currentConfig = widget.controller.configuration.resolve(
      isOffline: FinampSettingsHelper.finampSettings.isOffline,
      inPlaylist: widget.forPlaylistTracks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuEntries = _getMenuEntries(context);
    // Actual height was 490, bump to 520 for extra bottom padding and wiggle room on element sizes
    final stackHeight = 520.0;

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
            child: Text("Sort By*", style: Theme.of(context).textTheme.bodyMedium),
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
            child: Text("Order*", style: Theme.of(context).textTheme.bodyMedium),
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
              .whereNot(
                (x) => [
                  ItemFilterType.startsWithCharacter,
                  ItemFilterType.genreFilter,
                  ItemFilterType.searchTerm,
                ].contains(x),
              )
              .map(
                (option) => ToggleableListTile(
                  title: option.name,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Icon(switch (option) {
                      ItemFilterType.isFavorite => TablerIcons.heart,
                      ItemFilterType.isFullyDownloaded => TablerIcons.download,
                      ItemFilterType.startsWithCharacter => TablerIcons.sort_ascending,
                      ItemFilterType.genreFilter => TablerIcons.tag,
                      ItemFilterType.searchTerm => TablerIcons.list_search,
                      ItemFilterType.isUnplayed => TablerIcons.headphones_off,
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
                    ItemFilterType.startsWithCharacter => throw UnimplementedError(),
                    ItemFilterType.genreFilter => throw UnimplementedError(),
                    ItemFilterType.searchTerm => throw UnimplementedError(),
                    ItemFilterType.isUnplayed => currentConfig.filters.contains(
                      ItemFilter(type: ItemFilterType.isUnplayed),
                    ),
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
                          throw UnimplementedError();
                        case ItemFilterType.genreFilter:
                          throw UnimplementedError();
                        case ItemFilterType.searchTerm:
                          throw UnimplementedError();
                        case ItemFilterType.isUnplayed:
                          newFilters.add(ItemFilter(type: ItemFilterType.isUnplayed));
                          break;
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
          widget.controller.updateConfiguration(currentConfig);
          Navigator.of(context).pop();
        },
      ),
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
