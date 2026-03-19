import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../l10n/app_localizations.dart';
import '../global_snackbar.dart';

class FilterMenuButton extends ConsumerWidget {
  const FilterMenuButton({
    super.key,
    required this.tabType,
    this.filterOverride,
    this.updateFilterOverride,
    this.forPlaylistTracks = false,
  });

  final TabContentType tabType;
  final Set<ItemFilter>? filterOverride;
  final void Function(Set<ItemFilter> newFilters)? updateFilterOverride;
  final bool forPlaylistTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(
      filterOverride == null || updateFilterOverride != null,
      "If filterOverride is provided, updateFilterOverride must also be provided.",
    );

    final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
    final activeFilters =
        filterOverride ??
        {
          if (ref.watch(finampSettingsProvider.onlyShowFavorites)) ItemFilter(type: ItemFilterType.isFavorite),
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
      // TODO whats going on here?
      onPressed: () =>
          {} ??
          () {
            showMenu<ItemFilterType>(
              context: context,
              position: const RelativeRect.fromLTRB(0, 160, 0, 0),
              items: [
                for (final option in ItemFilterType.values)
                  PopupMenuItem(
                    value: option,
                    child: Builder(
                      builder: (context) {
                        final color =
                            switch (option) {
                              ItemFilterType.isFavorite => activeFilters.any(
                                (filter) => filter.type == ItemFilterType.isFavorite,
                              ),
                              ItemFilterType.isFullyDownloaded => activeFilters.any(
                                (filter) => filter.type == ItemFilterType.isFullyDownloaded,
                              ),
                              ItemFilterType.startsWithCharacter => activeFilters.any(
                                (filter) => filter.type == ItemFilterType.startsWithCharacter,
                              ),
                              ItemFilterType.genreFilter => throw UnimplementedError(),
                              ItemFilterType.searchTerm => throw UnimplementedError(),
                            }
                            ? Theme.of(context).colorScheme.secondary
                            : null;
                        return Opacity(
                          opacity:
                              (ref.watch(finampSettingsProvider.isOffline) &&
                                  option == ItemFilterType.isFullyDownloaded)
                              ? 0.3
                              : 1,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Icon(
                                    switch (option) {
                                      ItemFilterType.isFavorite =>
                                        activeFilters.any((filter) => filter.type == ItemFilterType.isFavorite)
                                            ? TablerIcons.heart_filled
                                            : TablerIcons.heart,
                                      ItemFilterType.isFullyDownloaded =>
                                        activeFilters.any((filter) => filter.type == ItemFilterType.isFullyDownloaded)
                                            ? TablerIcons.download
                                            : TablerIcons.download_off,
                                      ItemFilterType.startsWithCharacter => TablerIcons.sort_ascending,
                                      ItemFilterType.genreFilter => throw UnimplementedError(),
                                      ItemFilterType.searchTerm => throw UnimplementedError(),
                                    },
                                    size: 18,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text("${option.name}*", style: TextStyle(color: color)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ).then((value) {
              if (value != null) {
                if (filterOverride == null) {
                  switch (value) {
                    case ItemFilterType.isFavorite:
                      FinampSetters.setOnlyShowFavorites(
                        !activeFilters.any((filter) => filter.type == ItemFilterType.isFavorite),
                      );
                      break;
                    case ItemFilterType.isFullyDownloaded:
                      if (isOffline) {
                        FinampSetters.setOnlyShowFullyDownloaded(
                          !activeFilters.any((filter) => filter.type == ItemFilterType.isFullyDownloaded),
                        );
                      } else {
                        GlobalSnackbar.message((context) => AppLocalizations.of(context)!.notAvailableInOfflineMode);
                      }
                      break;
                    case ItemFilterType.startsWithCharacter:
                      //TODO implement
                      GlobalSnackbar.message((context) => "Not implemented yet*");
                      break;
                    case ItemFilterType.genreFilter:
                      throw UnimplementedError();
                    case ItemFilterType.searchTerm:
                      throw UnimplementedError();
                  }
                }
                if (filterOverride != null && updateFilterOverride != null) {
                  final newFilters = Set<ItemFilter>.from(activeFilters);
                  switch (value) {
                    case ItemFilterType.isFavorite:
                      final exists = newFilters.any((filter) => filter.type == ItemFilterType.isFavorite);
                      if (exists) {
                        newFilters.removeWhere((filter) => filter.type == ItemFilterType.isFavorite);
                      } else {
                        newFilters.add(ItemFilter(type: ItemFilterType.isFavorite));
                      }
                      break;
                    case ItemFilterType.isFullyDownloaded:
                      final exists = newFilters.any((filter) => filter.type == ItemFilterType.isFullyDownloaded);
                      if (exists) {
                        newFilters.removeWhere((filter) => filter.type == ItemFilterType.isFullyDownloaded);
                      } else {
                        newFilters.add(ItemFilter(type: ItemFilterType.isFullyDownloaded));
                      }
                      break;
                    case ItemFilterType.startsWithCharacter:
                      //TODO implement
                      break;
                    case ItemFilterType.genreFilter:
                      throw UnimplementedError();
                    case ItemFilterType.searchTerm:
                      throw UnimplementedError();
                  }
                  updateFilterOverride!(newFilters);
                }
              }
            });
          },
    );
  }
}
