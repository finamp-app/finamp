import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/localizations.dart';
import '../models/finamp_models.dart';
import '../services/finamp_settings_helper.dart';

Widget buildCuratedItemFilterRow({
  required WidgetRef ref,
  required BaseItemDto parent,
  required BaseItemDtoType filterListFor,
  List<CuratedItemSelectionType>? customFilterOrder,
  CuratedItemSelectionType? selectedFilter,
  List<CuratedItemSelectionType>? disabledFilters,
  void Function(CuratedItemSelectionType type)? onFilterSelected,
}) {
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
  final filterOrder = _getAvailableSelectionTypes(filterListFor, customFilterOrder);
  final currentSelectedFilter = (selectedFilter != null) ? selectedFilter : filterOrder.first;
  List<CuratedItemSelectionType> disabledFiltersList = disabledFilters ?? [];
  if (isOffline && !disabledFiltersList.contains(CuratedItemSelectionType.mostPlayed)) {
    disabledFiltersList = List.from(disabledFiltersList)
      ..addAll([CuratedItemSelectionType.mostPlayed, CuratedItemSelectionType.recentlyPlayed]);
  }

  return SliverToBoxAdapter(
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: IntrinsicWidth(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: filterOrder.asMap().entries.expand((entry) {
                    final int index = entry.key;
                    final type = entry.value;
                    final bool isSelected = (currentSelectedFilter == type);
                    final colorScheme = Theme.of(context).colorScheme;
                    double leftPadding = index == 0 ? 8.0 : 0.0;
                    double rightPadding = index == CuratedItemSelectionType.values.length - 1 ? 8.0 : 6.0;
                    final String? tooltipMessage =
                        (isOffline &&
                            (type == CuratedItemSelectionType.mostPlayed ||
                                type == CuratedItemSelectionType.recentlyPlayed))
                        ? AppLocalizations.of(context)!.notAvailableInOfflineMode
                        : (disabledFiltersList.contains(type)
                              ? (type == CuratedItemSelectionType.favorites
                                    ? AppLocalizations.of(context)!.curatedItemsNoFavorites('other')
                                    : AppLocalizations.of(context)!.curatedItemsNotListenedYet('other'))
                              : null);
                    final chip = FilterChip(
                      label: Text(type.toLocalisedString(context.l10n)),
                      onSelected: disabledFiltersList.contains(type)
                          ? null
                          : (_) {
                              if (onFilterSelected != null) {
                                onFilterSelected(type);
                              }
                            },
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: colorScheme.primary,
                      backgroundColor: colorScheme.surface,
                      labelStyle: TextStyle(color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface),
                      shape: const StadiumBorder(),
                    );

                    return [
                      Padding(
                        padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
                        child: tooltipMessage != null ? Tooltip(message: tooltipMessage, child: chip) : chip,
                      ),
                    ];
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

List<CuratedItemSelectionType> _getAvailableSelectionTypes(
  BaseItemDtoType filterListFor,
  List<CuratedItemSelectionType>? customFilterOrder,
) {
  var filteredList = customFilterOrder ?? CuratedItemSelectionType.values;

  switch (filterListFor) {
    case BaseItemDtoType.album:
      return filteredList
          .where(
            (type) => type != CuratedItemSelectionType.mostPlayed && type != CuratedItemSelectionType.recentlyPlayed,
          )
          .toList();
    case BaseItemDtoType.artist:
      return filteredList
          .where(
            (type) =>
                type != CuratedItemSelectionType.mostPlayed &&
                type != CuratedItemSelectionType.recentlyPlayed &&
                type != CuratedItemSelectionType.latestReleases,
          )
          .toList();
    default:
      return filteredList;
  }
}

CuratedItemSelectionType getFallbackFilterOption({
  required bool isOffline,
  required CuratedItemSelectionType currentType,
  required BaseItemDtoType filterListFor,
  List<CuratedItemSelectionType>? customFilterOrder,
  Set<CuratedItemSelectionType>? disabledFilters,
}) {
  final filterOrder = customFilterOrder ?? CuratedItemSelectionType.values;
  final filteredFilterOrder = _getAvailableSelectionTypes(
    filterListFor,
    filterOrder.where((type) => !(disabledFilters?.contains(type) ?? false)).toList(),
  );
  var fallbackOption = CuratedItemSelectionType.random;

  final index = filteredFilterOrder.indexOf(currentType);

  if (index != -1 &&
      index + 1 < filteredFilterOrder.length &&
      (!isOffline ||
          (filteredFilterOrder[index + 1] != CuratedItemSelectionType.mostPlayed &&
              filteredFilterOrder[index + 1] != CuratedItemSelectionType.recentlyPlayed))) {
    // Use the filter after favorites
    fallbackOption = filteredFilterOrder[index + 1];
  } else {
    // Use the first one that is not favorites (or most played in offline)
    fallbackOption = filteredFilterOrder.firstWhere(
      (type) =>
          type != currentType &&
          (!isOffline ||
              (type != CuratedItemSelectionType.mostPlayed && type != CuratedItemSelectionType.recentlyPlayed)),
      orElse: () => CuratedItemSelectionType.random,
    );
  }

  return fallbackOption;
}

CuratedItemSelectionType handleOfflineFallbackOption({
  required bool isOffline,
  required CuratedItemSelectionType currentFilter,
  required BaseItemDtoType filterListFor,
  List<CuratedItemSelectionType>? customFilterOrder,
}) {
  final filterOrder = customFilterOrder ?? CuratedItemSelectionType.values;
  final filteredFilterOrder = _getAvailableSelectionTypes(filterListFor, filterOrder);
  var newFilter = currentFilter;

  if (isOffline &&
      (currentFilter == CuratedItemSelectionType.mostPlayed ||
          currentFilter == CuratedItemSelectionType.recentlyPlayed)) {
    final index = filteredFilterOrder.indexOf(currentFilter);
    if (index != -1 &&
        index + 1 < filteredFilterOrder.length &&
        filteredFilterOrder[index + 1] != CuratedItemSelectionType.mostPlayed &&
        filteredFilterOrder[index + 1] != CuratedItemSelectionType.recentlyPlayed) {
      // Use the filter after the currentFilter
      newFilter = filteredFilterOrder[index + 1];
    } else {
      // Use the first one that is not mostPlayed
      newFilter = filteredFilterOrder.firstWhere(
        (type) => type != CuratedItemSelectionType.mostPlayed && type != CuratedItemSelectionType.recentlyPlayed,
        orElse: () => CuratedItemSelectionType.random,
      );
    }
  }

  return newFilter;
}

bool sendEmptyItemSelectionTypeMessage({
  required BuildContext context,
  CuratedItemSelectionType? typeSelected,
  BaseItemDtoType? messageFor,
  bool hasGenreFilter = false,
}) {
  String? message;
  String? locMessageFor;

  if (typeSelected == null) {
    return false;
  }

  if (messageFor == BaseItemDtoType.artist) {
    locMessageFor = (hasGenreFilter) ? "artistGenreFilter" : "artist";
  } else if (messageFor == BaseItemDtoType.genre) {
    locMessageFor = "genre";
  }

  switch (typeSelected) {
    case CuratedItemSelectionType.favorites:
      message = AppLocalizations.of(context)!.curatedItemsNoFavorites(locMessageFor ?? 'other');
      break;
    case CuratedItemSelectionType.mostPlayed:
    case CuratedItemSelectionType.recentlyPlayed:
      message = AppLocalizations.of(context)!.curatedItemsNotListenedYet(locMessageFor ?? 'other');
      break;
    default:
      break;
  }

  if (message != null) {
    GlobalSnackbar.message((context) => message!);
  }
  return true;
}
