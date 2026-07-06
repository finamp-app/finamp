import 'package:finamp/components/album_image.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/queue_restore_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/generate_subtitle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../extensions/localizations.dart';
import '../../services/item_by_id_provider.dart';

const double _itemCollectionCardTextSpacing = 6;
const double queuesHomeSectionWidth = 160;
const double queuesHomeSectionHeight = 84;

/// Card content for items. You probably shouldn't use this widget directly,
/// use ItemWrapper instead.
class ItemCard extends ConsumerWidget {
  const ItemCard({super.key, required this.item, this.onTap, this.forHomeScreen = false});

  final BaseItemDto item;
  final void Function()? onTap;
  final bool forHomeScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showText = forHomeScreen || ref.watch(finampSettingsProvider.showTextOnGridView);
    final hasImage = !(item.blurHash == null && item.imageId == null);
    return Container(
      constraints: BoxConstraints(maxWidth: calculateItemCollectionCardWidth(ref, forHomeScreen: forHomeScreen).$1),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: AlbumImage.defaultBorderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1, // Square aspect ratio for album art
            child: ClipRRect(
              borderRadius: AlbumImage.defaultBorderRadius,
              child: Stack(
                children: [
                  if (!hasImage && !showText)
                    // handle tiles with no image when text is disabled by showing a fallback text instead of the image
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      color: Theme.brightnessOf(context) == Brightness.dark
                          ? ColorScheme.of(context).primary.withOpacity(0.08)
                          : Color.alphaBlend(
                              ColorScheme.of(context).primary.withOpacity(0.1),
                              Colors.white,
                            ).withOpacity(1.0),
                      child: Align(
                        alignment: Alignment.center,
                        child: _ItemCollectionCardText(item: item, onImage: true),
                      ),
                    )
                  else
                    AlbumImage(
                      item: item,
                      sizePreset: ref.watch(
                        forHomeScreen
                            ? finampSettingsProvider.homeScreenImageSize
                            : finampSettingsProvider.gridImageSize,
                      ),
                    ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: onTap),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showText) ...[
            const SizedBox(height: _itemCollectionCardTextSpacing, width: 1),
            _ItemCollectionCardText(item: item, onImage: false),
          ],
        ],
      ),
    );
  }
}

class _ItemCollectionCardText extends ConsumerWidget {
  const _ItemCollectionCardText({required this.item, required this.onImage});

  final BaseItemDto item;
  final bool onImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = generateSubtitle(
      context: context,
      item: item,
      artistType: ref.watch(finampSettingsProvider.defaultArtistType),
    );

    return SizedBox(
      height: calculateTextHeight(
        style: TextTheme.of(context).bodySmall!,
        lines: calculateItemCollectionTextLines(BaseItemDtoType.fromItem(item)),
        scaling: MediaQuery.textScalerOf(context),
      ),
      child: Align(
        alignment: onImage ? Alignment.center : Alignment.topLeft,
        child: Wrap(
          // Runs must be horizontal to constrain child width.  Use large
          // spacing to force subtitle to wrap to next run
          spacing: 1000,
          alignment: onImage ? WrapAlignment.center : WrapAlignment.start,
          children: [
            Text(
              item.name ?? context.l10n.unknownName,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w500),
              textAlign: onImage ? TextAlign.center : TextAlign.left,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: onImage ? TextAlign.center : TextAlign.left,
              ),
          ],
        ),
      ),
    );
  }
}

class HomeScreenQueueTile extends ConsumerWidget {
  const HomeScreenQueueTile({super.key, required this.info});

  final FinampStorableQueueInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int remainingTracks = info.trackCount - info.previousTracks.length;

    BaseItemDto? track = info.currentTrack == null ? null : ref.watch(itemByIdProvider(info.currentTrack!)).valueOrNull;

    QueueItemSource source = info.source;
    if (source.wantsItem) {
      // BaseItemId uses String equals, the linter is mistaken.
      // ignore: provider_parameters
      final sourceItem = ref.watch(itemByIdProvider(BaseItemId(source.id))).valueOrNull;
      if (sourceItem != null) {
        source = source.withItem(sourceItem);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: SizedBox(
        width: queuesHomeSectionWidth,
        // height: _queuesSectionHeight,
        child: GestureDetector(
          onSecondaryTap: () => showQueueRestoreMenu(context: context, queueInfo: info),
          onLongPress: () => showQueueRestoreMenu(context: context, queueInfo: info),
          onTap: () => showQueueRestoreMenu(context: context, queueInfo: info),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.brightnessOf(context) == Brightness.dark
                  ? ColorScheme.of(context).primary.withOpacity(0.08)
                  : Color.alphaBlend(ColorScheme.of(context).primary.withOpacity(0.1), Colors.white).withOpacity(1.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              spacing: 0.0,
              children: [
                Text(
                  source.name.getLocalized(context.l10n),
                  style: TextTheme.of(context).bodySmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                RelativeDateTimeText(
                  dateTime: DateTime.fromMillisecondsSinceEpoch(info.creation),
                  style: const TextStyle(fontSize: 11.0),
                  includeStaticDateTime: true,
                ),
                Text(
                  AppLocalizations.of(context)!.queueRestoreSubtitle2(info.trackCount, remainingTracks),
                  style: TextTheme.of(context).bodySmall!.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (track?.name != null)
                  // exclude subtitle line 1 if track name is null
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.queueRestoreSubtitle1("${track!.name!} - ${track.artists!.join(", ")}"),
                    style: TextTheme.of(context).bodySmall!.copyWith(fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// This might calculate the width base on the device width in the future, or something similar
(double, double) calculateItemCollectionCardWidth(WidgetRef ref, {bool forHomeScreen = false}) {
  final target = ref
      .watch(forHomeScreen ? finampSettingsProvider.homeScreenImageSize : finampSettingsProvider.gridImageSize)
      .toDouble();
  final padding = ((target - 30) / 17.0).clamp(1.0, 10.0);
  return (target - padding, padding);
}

int calculateItemCollectionTextLines(BaseItemDtoType itemType) {
  switch (itemType) {
    case BaseItemDtoType.artist:
    case BaseItemDtoType.genre:
    case BaseItemDtoType.playlist:
      return 2;
    case BaseItemDtoType.track:
    case BaseItemDtoType.album:
    case _:
      return 3;
  }
}

double calculateItemCollectionCardHeight({
  required WidgetRef ref,
  required HomeScreenSectionConfiguration? sectionInfo,
  required BaseItemDtoType? itemType,
  bool forHomeScreen = false,
}) {
  assert(
    (sectionInfo == null && itemType != null) || (sectionInfo != null && itemType == null),
    "Exactly one of sectionInfo or itemType must be provided",
  );
  final BaseItemDtoType resolvedItemType;
  switch (sectionInfo?.base) {
    case QueuesHomeSection():
      return queuesHomeSectionHeight * MediaQuery.textScalerOf(ref.context).scale(16.0) / 16.0;
    case null:
      resolvedItemType = itemType!;
    case TabsHomeSection base:
      resolvedItemType = base.contentType.itemType!;
    case CollectionHomeSection base:
      // Fallback to albums children as the tallest type
      resolvedItemType = base.contentType.itemType ?? BaseItemDtoType.album;
  }
  return calculateItemCollectionCardWidth(ref, forHomeScreen: forHomeScreen).$1 +
      (ref.watch(finampSettingsProvider.showTextOnGridView) || sectionInfo != null
          ? _itemCollectionCardTextSpacing +
                calculateTextHeight(
                  style: TextTheme.of(ref.context).bodySmall!,
                  lines: calculateItemCollectionTextLines(resolvedItemType),
                  scaling: MediaQuery.textScalerOf(ref.context),
                )
          : 0);
}

double calculateTextHeight({required TextStyle style, required int lines, required TextScaler scaling}) {
  return (style.height ?? 1.0) * scaling.scale(style.fontSize ?? 16) * lines;
}
