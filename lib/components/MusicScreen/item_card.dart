import 'dart:async';

import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/QueueRestoreScreen/queue_restore_tile.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/generate_subtitle.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

const double _itemCollectionCardCoverSize = 110;
const double _itemCollectionCardSpacing = 6;
const double _queuesSectionWidth = 160;
const double _queuesSectionHeight = 84;

/// Card content for items. You probably shouldn't use this widget directly,
/// use ItemWrapper instead.
class ItemCard extends ConsumerWidget {
  const ItemCard({super.key, required this.item, this.parentType, this.onTap});

  final BaseItemDto item;
  final TabContentType? parentType;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: _itemCollectionCardCoverSize),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: AlbumImage.defaultBorderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1, // Square aspect ratio for album art
            child: Card(
              margin: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: AlbumImage.defaultBorderRadius,
                child: Stack(
                  children: [
                    AlbumImage(item: item),
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
          ),
          if (ref.watch(finampSettingsProvider.showTextOnGridView)) ...[
            const SizedBox(height: _itemCollectionCardSpacing, width: 1),
            _ItemCollectionCardText(item: item, parentType: parentType),
          ],
        ],
      ),
    );
  }
}

class _ItemCollectionCardText extends ConsumerWidget {
  const _ItemCollectionCardText({required this.item, required this.parentType});

  final BaseItemDto item;
  final TabContentType? parentType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = generateSubtitle(
      context: context,
      item: item,
      parentType: parentType,
      artistType: ref.watch(finampSettingsProvider.defaultArtistType),
    );

    return SizedBox(
      height: calculateTextHeight(
        style: TextTheme.of(context).bodySmall!,
        lines: calculateItemCollectionTextLines(BaseItemDtoType.fromItem(item)),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Wrap(
          // Runs must be horizontal to constrain child width.  Use large
          // spacing to force subtitle to wrap to next run
          spacing: 1000,
          children: [
            Text(
              item.name ?? "Unknown Name",
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall,
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
    final queueService = GetIt.instance<QueueService>();
    int remainingTracks = info.trackCount - info.previousTracks.length;

    BaseItemDto? track = ref.watch(trackProvider(info.currentTrack)).value;

    QueueItemSource source = info.source;
    if (source.wantsItem) {
      // BaseItemId uses String equals, the linter is mistaken.
      // ignore: provider_parameters
      final sourceItem = ref.watch(trackProvider(BaseItemId(source.id))).value;
      if (sourceItem != null) {
        source = source.withItem(sourceItem);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: SizedBox(
        width: _queuesSectionWidth,
        // height: _queuesSectionHeight,
        child: GestureDetector(
          // TODO add right click handler
          onSecondaryTap: () => {
            if (source.item != null) {openItemMenu(context: context, item: source.item!, queueInfo: info)},
          },
          onLongPress: () => {
            if (source.item != null) {openItemMenu(context: context, item: source.item!, queueInfo: info)},
          },
          onTap: () {
            queueService.archiveSavedQueue();
            unawaited(queueService.loadSavedQueue(info).catchError(GlobalSnackbar.error));
            Navigator.of(context).popUntil((route) => route.isFirst && !route.willHandlePopInternally);
          },
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
                  source.name.getLocalized(context),
                  style: TextTheme.of(context).bodySmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
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
double calculateItemCollectionCardWidth(BuildContext context, BaseItemDtoType itemType) {
  return _itemCollectionCardCoverSize;
}

int calculateItemCollectionTextLines(BaseItemDtoType itemType) {
  switch (itemType) {
    case BaseItemDtoType.artist:
    case BaseItemDtoType.track:
      return 2;
    case BaseItemDtoType.album:
    case BaseItemDtoType.playlist:
    case BaseItemDtoType.genre:
    case _:
      return 3;
  }
}

double calculateItemCollectionCardHeight({
  required BuildContext context,
  required HomeScreenSectionConfiguration? sectionInfo,
  required BaseItemDtoType? itemType,
}) {
  assert(
    (sectionInfo == null && itemType != null) || (sectionInfo != null && itemType == null),
    "Exactly one of sectionInfo or itemType must be provided",
  );
  final actualItemType = itemType ?? sectionInfo?.contentType?.itemType ?? BaseItemDtoType.album;
  return switch (sectionInfo?.type) {
    HomeScreenSectionType.queues => _queuesSectionHeight,
    _ =>
      _itemCollectionCardCoverSize +
          (GetIt.instance<ProviderContainer>().read(finampSettingsProvider.showTextOnGridView)
              ? _itemCollectionCardSpacing
              : 0) +
          calculateTextHeight(
            style: TextTheme.of(context).bodySmall!,
            lines: calculateItemCollectionTextLines(actualItemType),
          ),
  };
}

double calculateTextHeight({required TextStyle style, required int lines}) {
  return (GetIt.instance<ProviderContainer>().read(finampSettingsProvider.showTextOnGridView)
      ? (style.height ?? 1.0) * (style.fontSize ?? 16) * lines
      : 0);
}
