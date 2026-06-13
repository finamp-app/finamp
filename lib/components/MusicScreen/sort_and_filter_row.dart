import 'dart:io';

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

import '../../extensions/localizations.dart';

abstract class SortAndFilterController {
  SortAndFilterController._({required ContentType contentType, required SortAndFilterConfiguration startingConfig})
    : _notifier = ValueNotifier<_SortControllerState>(_SortControllerState(startingConfig, contentType));

  ContentType get _type => _notifier.value.type;
  SortAndFilterConfiguration get _config => _notifier.value.config;

  // We avoid directly exposing this notifier so we can always interject on offline/online resolve
  final ValueNotifier<_SortControllerState> _notifier;

  // updateGenreFilter is allowed on all sort controllers, even tracking ones, because the value is not propagated back to settings.
  void updateGenreFilter(BaseItemDto? genre) {
    final processedFilters = _config.filters.toSet();
    processedFilters.removeWhere((x) => x.type == ItemFilterType.genreFilter);
    if (genre != null) {
      processedFilters.add(ItemFilter(type: ItemFilterType.genreFilter, extras: genre));
    }
    _updateConfiguration(_config.copyWith(filters: processedFilters));
  }

  // Updating the whole configuration can only be done by the tracing controller via the filter menu, so that changes
  // are explicit and user initiated.  Static controllers expose this publicly for other widgets to use.
  void _updateConfiguration(SortAndFilterConfiguration newConfig) =>
      _notifier.value = _SortControllerState(newConfig, _type);

  SortAndFilterConfiguration _getValue(Ref ref);

  static ResolvedSortConfig resolveOffline(Ref ref, ContentType type, SortAndFilterConfiguration config) {
    // PlayCount and Last Played are not representative in Offline Mode
    // so we disable it and overwrite it with the Sort Name if it was selected
    if (ref.watch(finampSettingsProvider.isOffline) &&
        (config.sortBy == SortBy.playCount || config.sortBy == SortBy.datePlayed)) {
      if (type == ContentType.inPlaylist) {
        return ResolvedSortConfig._(config.copyWith(sortBy: SortBy.defaultOrder));
      } else {
        return ResolvedSortConfig._(config.copyWith(sortBy: SortBy.sortName));
      }
    } else {
      return ResolvedSortConfig._(config);
    }
  }

  ResolvedSortConfig resolveConfig() => GetIt.instance<ProviderContainer>().read(resolveSortProvider(this));

  factory SortAndFilterController.trackSettings(ContentType contentType) =>
      TrackingSortAndFilterController(contentType: contentType);

  factory SortAndFilterController({
    required ContentType contentType,
    required SortAndFilterConfiguration startingConfig,
    bool skipResolving,
  }) = StaticSortAndFilterController;
}

extension type const ResolvedSortConfig._(SortAndFilterConfiguration config) implements SortAndFilterConfiguration {
  ResolvedSortConfig copyWithSearch(String? searchQuery) {
    return ResolvedSortConfig._(config.copyWith(searchQuery: searchQuery));
  }

  ResolvedSortConfig copyWithGenre(BaseItemDto genre) {
    return ResolvedSortConfig._(config.copyWith(genreFilter: genre));
  }

  ResolvedSortConfig.skipResolving(this.config);

  static const defaultSort = ResolvedSortConfig._(
    SortAndFilterConfiguration(sortBy: SortBy.sortName, sortOrder: SortOrder.ascending, filters: {}),
  );

  static const defaultInAlbumSort = ResolvedSortConfig._(
    SortAndFilterConfiguration(sortBy: SortBy.defaultOrder, sortOrder: SortOrder.ascending, filters: {}),
  );
}

class _SortControllerState {
  const _SortControllerState(this.config, this.type);
  final SortAndFilterConfiguration config;
  final ContentType type;
}

class StaticSortAndFilterController extends SortAndFilterController {
  StaticSortAndFilterController({required super.contentType, required super.startingConfig, this.skipResolving = false})
    : super._();

  /// Skips all checks and returns the raw config when resolving.
  /// Useful if current constraints should be ignored, such as in settings.
  final bool skipResolving;

  void updateContentType(ContentType newType) => _notifier.value = _SortControllerState(_config, newType);

  void updateConfiguration(SortAndFilterConfiguration newConfig) => _updateConfiguration(newConfig);

  @override
  SortAndFilterConfiguration _getValue(Ref ref) {
    _notifier.addListener(ref.invalidateSelf);
    ref.onDispose(() => _notifier.removeListener(ref.invalidateSelf));
    return _config;
  }
}

class TrackingSortAndFilterController extends SortAndFilterController {
  TrackingSortAndFilterController({required super.contentType})
    : super._(
        startingConfig: contentType == ContentType.inPlaylist
            ? ResolvedSortConfig.defaultInAlbumSort
            : ResolvedSortConfig.defaultSort,
      );

  @override
  void _updateConfiguration(SortAndFilterConfiguration newConfig) {
    super._updateConfiguration(newConfig);
    if (newConfig.sortBy != FinampSettingsHelper.finampSettings.tabSortBy[_type]) {
      FinampSetters.setTabSortBy(_type, newConfig.sortBy);
    }
    if (newConfig.sortOrder != FinampSettingsHelper.finampSettings.tabSortOrder[_type]) {
      FinampSetters.setTabSortOrder(_type, newConfig.sortOrder);
    }

    if (newConfig.filters.contains(ItemFilter(type: ItemFilterType.isFavorite)) !=
        FinampSettingsHelper.finampSettings.onlyShowFavorites) {
      FinampSetters.setOnlyShowFavorites(newConfig.filters.contains(ItemFilter(type: ItemFilterType.isFavorite)));
    }

    if (newConfig.filters.contains(ItemFilter(type: ItemFilterType.isFullyDownloaded)) !=
        FinampSettingsHelper.finampSettings.onlyShowFullyDownloaded) {
      FinampSetters.setOnlyShowFullyDownloaded(
        newConfig.filters.contains(ItemFilter(type: ItemFilterType.isFullyDownloaded)),
      );
    }
  }

  @override
  SortAndFilterConfiguration _getValue(Ref ref) {
    _notifier.addListener(ref.invalidateSelf);
    ref.onDispose(() => _notifier.removeListener(ref.invalidateSelf));
    return _config.copyWith(
      sortBy: ref.watch(finampSettingsProvider.tabSortBy(_type)),
      sortOrder: ref.watch(finampSettingsProvider.tabSortOrder(_type)),
      favoriteFilter: ref.watch(finampSettingsProvider.onlyShowFavorites),
      onlyShowFullyDownloadedFilter: ref.watch(finampSettingsProvider.onlyShowFullyDownloaded),
    );
  }
}

final resolveSortProvider = Provider.family((Ref ref, SortAndFilterController controller) {
  if (controller is StaticSortAndFilterController && controller.skipResolving) {
    return ResolvedSortConfig.skipResolving(controller._getValue(ref));
  }
  return SortAndFilterController.resolveOffline(ref, controller._type, controller._getValue(ref));
});

final _unresolvedSortProvider = Provider.family((Ref ref, SortAndFilterController controller) {
  return ResolvedSortConfig.skipResolving(controller._getValue(ref));
});

class SortAndFilterRow extends ConsumerWidget {
  final ContentType tabType;
  final SortAndFilterController controller;

  final bool removeOnly;
  final bool hideArtistGenreFilters;
  final bool hideLeadingIcon;

  static double get height => (Platform.isIOS || Platform.isAndroid) ? 30 : 26;

  const SortAndFilterRow({
    super.key,
    required this.tabType,
    required this.controller,
    this.hideArtistGenreFilters = false,
    this.hideLeadingIcon = false,
  }) : removeOnly = false;

  const SortAndFilterRow.removeOnly({
    super.key,
    required this.controller,
    this.hideArtistGenreFilters = false,
    this.hideLeadingIcon = false,
  }) : tabType = ContentType.tracks,
       removeOnly = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentConfig = ref.watch(resolveSortProvider(controller));
    final activeFilters = hideArtistGenreFilters
        ? currentConfig.filters.whereNot((x) => x.type.isArtistGenre)
        : currentConfig.filters;
    final int activeFilterCount = activeFilters.length;
    String statusText = context.l10n.activeFilterCount(activeFilterCount);

    Future<void> showMenu() => showSortAndFilterMenu(
      context,
      tabType: tabType,
      controller: controller,
      removeOnly: removeOnly,
      hideArtistGenreFilters: hideArtistGenreFilters,
    );

    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        onTap: showMenu,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final filerButtonWidth = 52.0;
                    final minimumMaxChipWidth = 125.0;
                    final chipSpacing = 2.0;
                    final maxChips = ((constraints.maxWidth - filerButtonWidth) / (minimumMaxChipWidth + chipSpacing))
                        .floor();
                    final showChips = hideLeadingIcon || (maxChips >= activeFilterCount && activeFilterCount > 0);
                    return Row(
                      spacing: chipSpacing,
                      children: [
                        hideLeadingIcon
                            ? SizedBox.shrink()
                            : SimpleButton(
                                icon: TablerIcons.filter,
                                showText: !showChips,
                                text: statusText,
                                fontWeight: activeFilterCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                iconColor: activeFilterCount > 0
                                    ? ColorScheme.of(context).primary
                                    : TextTheme.of(context).bodyMedium?.color?.withOpacity(0.7),
                                textColor: activeFilterCount > 0
                                    ? ColorScheme.of(context).primary
                                    : TextTheme.of(context).bodyMedium?.color?.withOpacity(0.7),
                                onPressed: showMenu,
                              ),
                        if (showChips)
                          ...activeFilters.map(
                            (filter) => ConstrainedBox(
                              constraints: BoxConstraints(
                                // Cap chip width to prevent unusually long ones from causing overflow.
                                // If showChips, this is guaranteed to be at least minimumMaxChipWidth
                                maxWidth: (constraints.maxWidth - filerButtonWidth) / activeFilterCount,
                              ),
                              child: SimpleButton(
                                text: filter.getName(context.l10n),
                                label: context.l10n.removeFilter,
                                icon: TablerIcons.x,
                                iconColor: TextTheme.of(context).bodyMedium?.color?.withOpacity(0.7),
                                backgroundColor: ColorScheme.of(context).primary.withOpacity(0.1),
                                onPressed: () => controller._updateConfiguration(
                                  currentConfig.copyWith(
                                    filters: currentConfig.filters.whereNot((x) => x.type == filter.type).toSet(),
                                  ),
                                ),
                                onPressedSecondary: showMenu,
                              ),
                            ),
                          ),
                        Spacer(),
                      ],
                    );
                  },
                ),
              ),
              if (!removeOnly)
                SimpleButton(
                  icon: currentConfig.sortOrder.getIcon(),
                  text: currentConfig.sortBy.toLocalisedString(context.l10n),
                  onPressed: showMenu,
                  onIconPressed: () => controller._updateConfiguration(
                    currentConfig.copyWith(
                      sortOrder: currentConfig.sortOrder == SortOrder.ascending
                          ? SortOrder.descending
                          : SortOrder.ascending,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSortAndFilterMenu(
  BuildContext context, {
  required ContentType tabType,
  required SortAndFilterController controller,
  bool removeOnly = false,
  bool hideArtistGenreFilters = false,
}) async {
  return await showThemedBottomSheet<void>(
    context: context,
    routeName: SortAndFilterMenu.routeName,
    buildWrapper: (_, _, childBuilder) {
      return SortAndFilterMenu(
        childBuilder: childBuilder,
        tabType: tabType,
        controller: controller,
        removeOnly: removeOnly,
        hideArtistGenreFilters: hideArtistGenreFilters,
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
    required this.controller,
    required this.removeOnly,
    required this.hideArtistGenreFilters,
  });

  final ScrollBuilder childBuilder;

  final ContentType tabType;
  final SortAndFilterController controller;
  final bool removeOnly;
  final bool hideArtistGenreFilters;

  @override
  ConsumerState<SortAndFilterMenu> createState() => _SortAndFilterMenuState();
}

mixin _SortAndFilterMenuEntriesMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const toggalableFilterTypes = [
    ItemFilterType.isFavorite,
    ItemFilterType.isFullyDownloaded,
    ItemFilterType.isUnplayed,
  ];

  SortAndFilterConfiguration get currentConfig;
  set currentConfig(SortAndFilterConfiguration value);

  ContentType get tabType;
  SortAndFilterController get controller;
  bool get removeOnly;
  bool get hideArtistGenreFilters;
  bool get applyChangesImmediately;

  Set<ItemFilter> get excessFilters => currentConfig.filters
      .whereNot((x) => toggalableFilterTypes.contains(x.type))
      .whereNot((x) => hideArtistGenreFilters && x.type.isArtistGenre)
      .toSet();

  bool get showOfflineSortWarning => ref.watch(finampSettingsProvider.isOffline) && currentConfig.sortBy.onlineOnly;

  void _updateCurrentConfig(SortAndFilterConfiguration newConfig) {
    setState(() {
      currentConfig = newConfig;
    });
    if (applyChangesImmediately) {
      controller._updateConfiguration(newConfig);
    }
  }

  // Normal sort & filter menu entries, excluding headers
  List<Widget> _getMenuEntries(BuildContext context) {
    final rawSortOptions = SortBy.defaultsFor(
      type: tabType.itemType,
      includeDefaultOrder: tabType == ContentType.inPlaylist,
    );
    final sortOptions = ref.watch(finampSettingsProvider.isOffline)
        ? [...rawSortOptions.whereNot((s) => s.onlineOnly), ...rawSortOptions.where((s) => s.onlineOnly)]
        : rawSortOptions;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(context.l10n.sortBy, style: Theme.of(context).textTheme.bodyMedium),
          ),
          FinampSettingsDropdown<SortBy>(
            dropdownItems: sortOptions
                .map(
                  (e) => DropdownMenuEntry<SortBy>(
                    value: e,
                    label: e.toLocalisedString(context.l10n),
                    leadingIcon: Icon(e.getIcon()),
                  ),
                )
                .toList(),
            selectedValue: currentConfig.sortBy,
            selectedIcon: currentConfig.sortBy.getIcon(),
            onSelected: (sortBy) {
              if (sortBy != null) {
                _updateCurrentConfig(currentConfig.copyWith(sortBy: sortBy));
              }
            },
          ),
          if (showOfflineSortWarning)
            ListTile(
              leading: Icon(TablerIcons.info_circle),
              title: Text(context.l10n.offlineSortFallback(currentConfig.sortBy.toLocalisedString(context.l10n))),
              contentPadding: EdgeInsets.zero,
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
            child: Text(context.l10n.sortOrder, style: Theme.of(context).textTheme.bodyMedium),
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
                _updateCurrentConfig(currentConfig.copyWith(sortOrder: sortOrder));
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
            child: Text(context.l10n.filters, style: Theme.of(context).textTheme.bodyMedium),
          ),
          ...ItemFilterType.values
              .where((x) => toggalableFilterTypes.contains(x))
              .map((option) => _makeFilterTile(option)),
          ...excessFilters.map((filter) => _makeExcessFilterTile(filter)),
        ],
      ),
    ];
  }

  List<Widget> _getRemoveOnlyMenuEntries(BuildContext context) {
    return [
      SizedBox(height: 20.0),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(context.l10n.filters, style: Theme.of(context).textTheme.bodyMedium),
          ),
          ...excessFilters.map((filter) => _makeExcessFilterTile(filter)),
        ],
      ),
    ];
  }

  Widget _makeFilterTile(ItemFilterType option) {
    return ToggleableListTile(
      title: ItemFilter(type: option).getName(context.l10n),
      leading: Padding(padding: const EdgeInsets.only(left: 16.0), child: Icon(option.icon)),
      trailing: SizedBox.shrink(),
      enabled: switch (option) {
        ItemFilterType.isFullyDownloaded => ref.watch(finampSettingsProvider.isOffline),
        _ => true,
      },
      state: switch (option) {
        ItemFilterType.isFavorite => currentConfig.filters.contains(ItemFilter(type: ItemFilterType.isFavorite)),
        ItemFilterType.isFullyDownloaded => currentConfig.filters.contains(
          ItemFilter(type: ItemFilterType.isFullyDownloaded),
        ),
        ItemFilterType.isUnplayed => currentConfig.filters.contains(ItemFilter(type: ItemFilterType.isUnplayed)),
        ItemFilterType.startsWithCharacter ||
        ItemFilterType.genreFilter ||
        ItemFilterType.searchTerm => throw UnsupportedError("Filter type $option should not be toggleable"),
      },
      onToggle: (currentState) async {
        final newFilters = Set<ItemFilter>.from(currentConfig.filters);
        if (currentState) {
          newFilters.removeWhere((filter) => filter.type == option);
        } else {
          switch (option) {
            case ItemFilterType.isFavorite:
              newFilters.add(ItemFilter(type: ItemFilterType.isFavorite));
            case ItemFilterType.isFullyDownloaded:
              newFilters.add(ItemFilter(type: ItemFilterType.isFullyDownloaded));
            case ItemFilterType.isUnplayed:
              newFilters.add(ItemFilter(type: ItemFilterType.isUnplayed));
            case ItemFilterType.startsWithCharacter:
            case ItemFilterType.genreFilter:
            case ItemFilterType.searchTerm:
              throw UnsupportedError("Filter type $option should not be toggleable");
          }
        }

        _updateCurrentConfig(currentConfig.copyWith(filters: newFilters));
      },
    );
  }

  Widget _makeExcessFilterTile(ItemFilter filter) {
    return ToggleableListTile(
      title: filter.getName(context.l10n),
      leading: Padding(padding: const EdgeInsets.only(left: 16.0), child: Icon(filter.type.icon)),
      trailing: Icon(TablerIcons.x),
      enabled: true,
      state: true,
      onToggle: (currentState) async {
        final newFilters = Set<ItemFilter>.from(currentConfig.filters);
        if (currentState) {
          newFilters.removeWhere((x) => x.type == filter.type);
        } else {
          throw UnsupportedError(
            "This tile is expected to be immediately removed once toggled off, so this shouldn't happen.",
          );
        }

        _updateCurrentConfig(currentConfig.copyWith(filters: newFilters));
      },
    );
  }
}

class _SortAndFilterMenuState extends ConsumerState<SortAndFilterMenu>
    with _SortAndFilterMenuEntriesMixin<SortAndFilterMenu> {
  late SortAndFilterConfiguration currentConfig;

  @override
  ContentType get tabType => widget.tabType;

  @override
  SortAndFilterController get controller => widget.controller;

  @override
  bool get removeOnly => widget.removeOnly;

  @override
  bool get hideArtistGenreFilters => widget.hideArtistGenreFilters;

  @override
  bool get applyChangesImmediately => false;

  @override
  void initState() {
    super.initState();

    currentConfig = ref.read(_unresolvedSortProvider(widget.controller));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> menuEntries = [
      ...(widget.removeOnly ? _getRemoveOnlyMenuEntries(context) : _getMenuEntries(context)),
      SizedBox(height: 32.0),
      CTAMedium(
        text: context.l10n.apply,
        icon: TablerIcons.check,
        onPressed: () {
          controller._updateConfiguration(currentConfig);
          Navigator.of(context).pop();
        },
      ),
    ];

    // Actual height was 490, bump to 520 for extra bottom padding and wiggle room on element sizes
    final stackHeight = 520.0 + 56.0 * excessFilters.length + (showOfflineSortWarning ? 60.0 : 0.0);

    return widget.childBuilder(stackHeight, menu(context, menuEntries));
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
            children: [
              Text(
                widget.removeOnly ? context.l10n.removeFilters : context.l10n.sortFilter,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        sliver: MenuMask(
          height: MenuMaskHeight(32.0),
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList.list(children: menuEntries),
          ),
        ),
      ),
    ];
  }
}

class SortAndFilterEmbeddedMenu extends ConsumerStatefulWidget {
  const SortAndFilterEmbeddedMenu({
    super.key,
    required this.tabType,
    required this.controller,
    required this.removeOnly,
    required this.hideArtistGenreFilters,
  });

  final ContentType tabType;
  final SortAndFilterController controller;
  final bool removeOnly;
  final bool hideArtistGenreFilters;

  @override
  ConsumerState<SortAndFilterEmbeddedMenu> createState() => _SortAndFilterEmbeddedMenuState();
}

class _SortAndFilterEmbeddedMenuState extends ConsumerState<SortAndFilterEmbeddedMenu>
    with _SortAndFilterMenuEntriesMixin<SortAndFilterEmbeddedMenu> {
  late SortAndFilterConfiguration currentConfig;

  @override
  ContentType get tabType => widget.tabType;

  @override
  SortAndFilterController get controller => widget.controller;

  @override
  bool get removeOnly => widget.removeOnly;

  @override
  bool get hideArtistGenreFilters => widget.hideArtistGenreFilters;

  @override
  bool get applyChangesImmediately => true;

  @override
  void initState() {
    super.initState();

    currentConfig = ref.read(_unresolvedSortProvider(widget.controller));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> menuEntries;
    if (widget.removeOnly) {
      menuEntries = _getRemoveOnlyMenuEntries(context);
    } else {
      menuEntries = _getMenuEntries(context);
    }

    return Column(children: menuEntries);
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
            children: [
              Text(
                widget.removeOnly ? context.l10n.removeFilters : context.l10n.sortFilter,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        sliver: MenuMask(
          height: MenuMaskHeight(32.0),
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList.list(children: menuEntries),
          ),
        ),
      ),
    ];
  }
}
