import 'dart:io';

import 'package:finamp/components/AlbumScreen/downloaded_indicator.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/favorite_button.dart';
import 'package:finamp/components/print_duration.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/generate_subtitle.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

/// ListTile content for CollectionItem. You probably shouldn't use this widget
/// directly, use CollectionItem instead.
class ItemCollectionListTile extends ConsumerWidget {
  const ItemCollectionListTile({
    super.key,
    required this.item,
    this.parentType,
    this.onTap,
    this.albumShowsYearAndDurationInstead = false,
    this.adaptiveAdditionalInfoSortBy,
    this.showFavoriteIconOnlyWhenFilterDisabled = false,
    this.highlightCurrentItem = true,
  });

  final BaseItemDto item;
  final ContentType? parentType;
  final void Function()? onTap;
  final bool albumShowsYearAndDurationInstead;
  final SortBy? adaptiveAdditionalInfoSortBy;
  final bool showFavoriteIconOnlyWhenFilterDisabled;
  final bool highlightCurrentItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final library = finampUserHelper.currentUser?.currentView;
    final itemType = BaseItemDtoType.fromItem(item);
    final isOnDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final subtitle = (itemType != BaseItemDtoType.album || !albumShowsYearAndDurationInstead)
        ? generateSubtitle(
            item: item,
            parentType: parentType,
            context: context,
            artistType: ref.watch(finampSettingsProvider.defaultArtistType),
          )
        : null;
    final itemDownloadStub = switch (itemType) {
      BaseItemDtoType.artist || BaseItemDtoType.genre => DownloadStub.fromFinampCollection(
        FinampCollection(type: FinampCollectionType.collectionWithLibraryFilter, library: library, item: item),
      ),
      BaseItemDtoType.track => DownloadStub.fromItem(type: DownloadItemType.track, item: item),
      _ => DownloadStub.fromItem(type: DownloadItemType.collection, item: item),
    };
    final downloadedIndicator = DownloadedIndicator(
      item: itemDownloadStub,
      size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 1,
    );
    final titleText = Text(item.name ?? AppLocalizations.of(context)!.unknownName, overflow: TextOverflow.ellipsis);
    final isCurrentlyPlaying = ref.watch(
      currentTrackProvider.select((queueItem) => queueItem.valueOrNull?.source.id == item.id.raw),
    );

    final sortIconMeta = {
      SortBy.runtime: (icon: TablerIcons.stopwatch, offset: isOnDesktop ? Offset(-1.5, 1.2) : Offset(-1.5, 0.5)),
      SortBy.dateCreated: (
        icon: TablerIcons.calendar_plus,
        offset: isOnDesktop ? Offset(-1.5, 1.0) : Offset(-1.5, 0.2),
      ),
    };

    WidgetSpan? buildAdditionalInfoIcon(SortBy? sortBy) {
      if (sortBy == null) return null;
      final meta = sortIconMeta[sortBy];
      if (meta == null) return null;

      final textTheme = Theme.of(context).textTheme.bodyMedium!;
      final color = textTheme.color!.withOpacity(0.7);

      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Transform.translate(
            offset: meta.offset,
            child: Icon(meta.icon, size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 1, color: color),
          ),
        ),
      );
    }

    ContentType? associatedTabContentType;
    try {
      associatedTabContentType = ContentType.fromItemType(itemType.jellyfinName ?? "Collection");
    } on FormatException {
      associatedTabContentType = null;
    }

    final tileAdditionalInfoSetting = associatedTabContentType != null
        ? ref.watch(finampSettingsProvider.tileAdditionalInfoType(associatedTabContentType))
        : null;
    final tileAdditionalInfoType = (associatedTabContentType == ContentType.albums && albumShowsYearAndDurationInstead)
        ? TileAdditionalInfoType.none
        : (tileAdditionalInfoSetting ?? TileAdditionalInfoType.adaptive);

    SortBy? additionalInfoSortBy = switch (tileAdditionalInfoType) {
      TileAdditionalInfoType.dateReleased => SortBy.premiereDate,
      TileAdditionalInfoType.dateAdded => SortBy.dateCreated,
      TileAdditionalInfoType.duration => SortBy.runtime,
      TileAdditionalInfoType.none => null,
      _ => adaptiveAdditionalInfoSortBy,
    };

    final additionalInfoIcon = buildAdditionalInfoIcon(additionalInfoSortBy);

    final additionalInfo = (() {
      final l10n = AppLocalizations.of(context)!;
      if ((itemType == BaseItemDtoType.album && albumShowsYearAndDurationInstead) ||
          additionalInfoSortBy == SortBy.premiereDate) {
        return TextSpan(
          text: ReleaseDateHelper.autoFormat(item) ?? l10n.noReleaseDate,
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
        );
      }
      switch (additionalInfoSortBy) {
        case SortBy.runtime:
          return TextSpan(
            text: printDuration(item.runTimeTicksDuration()),
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
          );
        case SortBy.dateCreated:
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: RelativeDateTimeTextFromString(
              dateString: item.dateCreated,
              fallback: l10n.noDateAdded,
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
              disableTextScaling: true,
            ),
          );
        default:
          return null;
      }
    })();

    final showSubtitle =
        (subtitle != null ||
        (itemType == BaseItemDtoType.album && albumShowsYearAndDurationInstead) ||
        (additionalInfo != null) ||
        downloadedIndicator.isVisible(ref) ||
        item.isExplicit);
    final subtitleText = Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            child: Transform.translate(
              offset: isOnDesktop ? Offset(-3, 1.3) : Offset(-3, 0.4),
              child: downloadedIndicator,
            ),
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
          ),
          if (item.isExplicit)
            WidgetSpan(
              child: Padding(
                padding: const EdgeInsets.only(right: 2.0),
                child: Transform.translate(
                  offset: isOnDesktop ? Offset(-1.5, 3.3) : Offset(-1.5, 1.7),
                  child: Icon(TablerIcons.explicit, size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 3),
                ),
              ),
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
            ),
          if (downloadedIndicator.isVisible(ref))
            WidgetSpan(child: SizedBox(width: (additionalInfo != null) ? 5.0 : 2.0)),
          if (additionalInfo != null) ...[
            if (additionalInfoIcon != null) additionalInfoIcon,
            additionalInfo,
            TextSpan(
              text: (itemType == BaseItemDtoType.album && albumShowsYearAndDurationInstead)
                  ? " · ${printDuration(item.runTimeTicksDuration())}"
                  : (subtitle != null)
                  ? " · $subtitle"
                  : null,
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          ] else ...[
            TextSpan(
              text: subtitle,
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          ],
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );

    final unthemedListTile = Builder(
      // get updated context after the theme is applied
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(left: 6.0, right: 6.0),
          child: ListTile(
            textColor: Theme.of(context).textTheme.bodyLarge?.color,
            contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: !showSubtitle ? 8.0 : 0.0),
            onTap: onTap,
            leading: AlbumImage(item: item),
            title: titleText,
            subtitle: (showSubtitle) ? subtitleText : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if ((itemType == BaseItemDtoType.artist
                        ? jellyfinApiHelper.selectedMixArtists
                        : (itemType == BaseItemDtoType.genre)
                        ? jellyfinApiHelper.selectedMixGenres
                        : jellyfinApiHelper.selectedMixAlbums)
                    .contains(item))
                  const Icon(Icons.explore),
                FavoriteButton(
                  item: item,
                  onlyIfFav: true,
                  showFavoriteIconOnlyWhenFilterDisabled: showFavoriteIconOnlyWhenFilterDisabled,
                ),
              ],
            ),
          ),
        );
      },
    );

    return isCurrentlyPlaying && highlightCurrentItem
        ? ItemTheme(
            item: item,
            themeTransitionDuration: const Duration(milliseconds: 500),
            themeOverride: (imageTheme) {
              return imageTheme.copyWith(
                colorScheme: imageTheme.colorScheme.copyWith(
                  surfaceContainer: imageTheme.colorScheme.primary.withOpacity(
                    imageTheme.brightness == Brightness.dark ? 0.35 : 0.3,
                  ),
                ),
                textTheme: imageTheme.textTheme.copyWith(
                  bodyLarge: imageTheme.textTheme.bodyLarge?.copyWith(
                    color: Color.alphaBlend(
                      (imageTheme.colorScheme.secondary.withOpacity(
                        imageTheme.brightness == Brightness.light ? 0.5 : 0.1,
                      )),
                      imageTheme.textTheme.bodyLarge?.color ??
                          (imageTheme.brightness == Brightness.light ? Colors.black : Colors.white),
                    ),
                  ),
                ),
              );
            },
            child: unthemedListTile,
          )
        : unthemedListTile;
  }
}
