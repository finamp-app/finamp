import 'dart:async';

import 'package:collection/collection.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/screens/genre_screen.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../models/jellyfin_models.dart';

final _borderRadius = BorderRadius.circular(4);

class GenreIconAndText extends StatelessWidget {
  const GenreIconAndText({super.key, required this.parent, this.sortConfig, this.sortConfigController});

  final BaseItemDto parent;
  final SortAndFilterConfiguration? sortConfig;
  final SortAndFilterController? sortConfigController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<NameLongIdPair> genres = parent.genreItems ?? [];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Icon(
            TablerIcons.color_swatch,
            color: theme.iconTheme.color?.withOpacity(theme.brightness == Brightness.light ? 0.38 : 0.5),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: genres.isNotEmpty
                ? GenreChips(
                    parentType: BaseItemDtoType.fromItem(parent),
                    genres: genres,
                    backgroundColor: IconTheme.of(context).color!.withOpacity(0.1),
                    sortConfig: sortConfig,
                    sortConfigController: sortConfigController,
                  )
                : Text(AppLocalizations.of(context)!.noGenres),
          ),
        ],
      ),
    );
  }
}

class GenreChips extends ConsumerWidget {
  const GenreChips({
    super.key,
    required this.parentType,
    required this.genres,
    this.sortConfig,
    this.backgroundColor,
    this.color,
    this.sortConfigController,
  });

  final BaseItemDtoType parentType;
  final List<NameLongIdPair> genres;
  final Color? backgroundColor;
  final Color? color;
  final SortAndFilterConfiguration? sortConfig;
  final SortAndFilterController? sortConfigController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGenreFilter = sortConfig?.filters.firstWhereOrNull(
      (filter) => filter.type == ItemFilterType.genreFilter,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (activeGenreFilter != null)
              ActiveFilterChip(
                filter: activeGenreFilter,
                onRemove: () => sortConfigController!.updateGenreFilter(null),
                showPlainName: true,
              ),
            ...genres.where((g) => g.id != activeGenreFilter?.extraBaseItem.id).map((genre) {
              return GenreChip(
                key: ValueKey(genre.id),
                backgroundColor: backgroundColor,
                color: color,
                parentType: parentType,
                genre: genre,
                sortConfigController: sortConfigController,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.genre,
    required this.parentType,
    this.backgroundColor,
    this.color,
    this.sortConfigController,
  });

  final NameLongIdPair genre;
  final BaseItemDtoType parentType;
  final Color? backgroundColor;
  final Color? color;
  final SortAndFilterController? sortConfigController;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 10),
      child: _GenreChipContent(
        genre: genre,
        parentType: parentType,
        color: color,
        backgroundColor: backgroundColor,
        updateGenreFilter: sortConfigController?.updateGenreFilter,
      ),
    );
  }
}

class _GenreChipContent extends ConsumerWidget {
  const _GenreChipContent({
    required this.genre,
    required this.parentType,
    this.backgroundColor,
    this.color,
    this.updateGenreFilter,
  });

  final NameLongIdPair genre;
  final BaseItemDtoType parentType;
  final Color? backgroundColor;
  final Color? color;
  final void Function(BaseItemDto?)? updateGenreFilter;

  Future<void> _handleGenreTap(BuildContext context, WidgetRef ref, {bool alternativeAction = false}) async {
    final isOffline = ref.watch(finampSettingsProvider.isOffline);
    final applyFilterOnGenreChipTap = ref.watch(finampSettingsProvider.applyFilterOnGenreChipTap);
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final isarDownloader = GetIt.instance<DownloadsService>();

    bool applyGenreFilter = alternativeAction ? !applyFilterOnGenreChipTap : applyFilterOnGenreChipTap;

    if (applyGenreFilter && parentType == BaseItemDtoType.album) {
      applyGenreFilter = false;
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.genreFilterNotAvailableForAlbums);
    }

    BaseItemDto? genreItem;
    if (parentType == BaseItemDtoType.playlist && genre.name != null) {
      // Playlists use different BaseItemIds for their genreItems,
      // so we have to get the gneres BaseItemDto in a different way.
      genreItem = await getPlaylistGenreBaseItemDto(genre.name!, isOffline);
    } else if (isOffline) {
      genreItem = (await isarDownloader.getCollectionInfo(id: genre.id!))?.baseItem;
    } else {
      genreItem = await jellyfinApiHelper.getItemById(genre.id!);
    }

    if (genreItem != null) {
      if (applyGenreFilter && updateGenreFilter != null) {
        updateGenreFilter!(genreItem);
        if (!alternativeAction) {
          GlobalSnackbar.message(
            (context) => AppLocalizations.of(context)!.applyFilterOnGenreChipTapPrompt,
            action: (context) {
              return SnackBarAction(
                label: AppLocalizations.of(context)!.applyFilterOnGenreChipTapPromptButton,
                onPressed: () {
                  updateGenreFilter!(null);
                  unawaited(Navigator.of(context).pushNamed(GenreScreen.routeName, arguments: genreItem));
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              );
            },
          );
        }
      } else {
        unawaited(Navigator.of(context).pushNamed(GenreScreen.routeName, arguments: genreItem));
      }
    } else {
      GlobalSnackbar.message(
        (context) => AppLocalizations.of(context)!.genreNotFound((isOffline) ? "offline" : "other"),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genreName = genre.name ?? "";

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: genreName, button: true),
      excludeSemantics: true,
      container: true,
      child: Material(
        color: backgroundColor ?? Colors.white.withOpacity(0.1),
        borderRadius: _borderRadius,
        child: InkWell(
          borderRadius: _borderRadius,
          onTap: () => _handleGenreTap(context, ref),
          onLongPress: () => _handleGenreTap(context, ref, alternativeAction: true),
          onSecondaryTap: () => _handleGenreTap(context, ref, alternativeAction: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(
              genreName,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(color: color ?? Theme.of(context).textTheme.bodySmall!.color ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// Playlists use different BaseItemIds for their genreItems.
// In Online Mode, the API returns the same data for both ids.
// However, in offline mode, we only have the non-playlist id of a genre.
// Additionally, the genreFilter on both modes won't work with the
// playlist-only-genreId, so we have to get the BaseItemDto by name instead of id.
// That should work, too, because genreNames are distinct.
Future<BaseItemDto?> getPlaylistGenreBaseItemDto(String genreName, bool isOffline) async {
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  List<BaseItemDto> genreItems;

  if (isOffline) {
    final isarDownloader = GetIt.instance<DownloadsService>();
    final genreItemDownloadStubs = await isarDownloader.getAllCollections(
      nameFilter: genreName,
      includeItemTypes: [BaseItemDtoType.genre],
    );
    genreItems = genreItemDownloadStubs.map((e) => e.baseItem).nonNulls.toList();
  } else {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    genreItems =
        await jellyfinApiHelper.getItems(
          parentItem: finampUserHelper.currentUser?.currentView,
          includeItemTypes: BaseItemDtoType.genre.jellyfinName,
          searchTerm: genreName.trim(),
        ) ??
        [];
  }

  for (final item in genreItems) {
    if (item.name != null && item.name!.trim().toLowerCase() == genreName.trim().toLowerCase()) {
      return item;
    }
  }

  return null;
}
