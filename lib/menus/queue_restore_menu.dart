import 'dart:async';

import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/icon_and_text.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/restore_queue_menu_entry.dart';
import 'package:finamp/menus/components/menu_item_info_header.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../models/jellyfin_models.dart';

const Duration albumMenuDefaultAnimationDuration = Duration(milliseconds: 750);
const Curve albumMenuDefaultInCurve = Curves.easeOutCubic;
const Curve albumMenuDefaultOutCurve = Curves.easeInCubic;
const albumMenuRouteName = "/album-menu";

Future<void> showQueueRestoreMenu({required BuildContext context, required FinampStorableQueueInfo queueInfo}) async {
  if (queueInfo.source.wantsItem) {
    final item = await GetIt.instance<ProviderContainer>().read(
      itemByIdProvider(BaseItemId(queueInfo.source.id)).future,
    );
    if (item != null) {
      if (!context.mounted) return;
      return openItemMenu(context: context, item: item, queueInfo: queueInfo);
    }
  }

  final item = queueInfo.source.item;
  int remainingTracks = queueInfo.trackCount - queueInfo.previousTracks.length;

  final showPlayback = item is FinampPlayable;

  // Normal menu entries, excluding headers
  List<HideableMenuEntry> getMenuEntries(BuildContext context) {
    return [RestoreQueueMenuEntry(queueInfo: queueInfo)];
  }

  (double, List<Widget>) getMenuProperties(BuildContext context) {
    final menuEntries = getMenuEntries(context);
    final stackHeight = ThemedBottomSheet.calculateStackHeight(
      context: context,
      menuEntries: menuEntries,
      includePlaybackRow: showPlayback,
    );
    List<Widget> menu = [
      //TODO create custom MenuInfoHeader and MenuInfoSliverHeader for showing info for non-BaseItem things
      SliverPersistentHeader(
        delegate: GenericMenuInfoSliverHeader.condensedNoArtwork(
          child: Consumer(
            builder: (context, ref, child) {
              BaseItemDto? currentTrack = queueInfo.currentTrack == null
                  ? null
                  : ref.watch(itemByIdProvider(queueInfo.currentTrack!)).value;

              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    queueInfo.source.name.getLocalized(AppLocalizations.of(context)!),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.2,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    maxLines: 2,
                  ),
                  if (queueInfo.currentTrack != null && currentTrack?.name != null)
                    IconAndText(
                      iconData: TablerIcons.music,
                      textSpan: TextSpan(
                        text: AppLocalizations.of(context)!.queueRestoreSubtitle1(currentTrack!.name!),
                      ),
                    ),
                  Text(AppLocalizations.of(context)!.queueRestoreSubtitle2(queueInfo.trackCount, remainingTracks)),
                ],
              );
            },
          ),
        ),
        pinned: true,
      ),
      MenuMask(
        height: MenuItemInfoSliverHeader.condensedHeight,
        child: SliverPadding(
          padding: const EdgeInsets.only(left: 8.0),
          sliver: SliverList(delegate: SliverChildListDelegate(menuEntries)),
        ),
      ),
    ];

    return (stackHeight, menu);
  }

  if (!context.mounted) return;
  await showThemedBottomSheet(
    context: context,
    routeName: albumMenuRouteName,
    buildSlivers: (context) => getMenuProperties(context),
  );
}

class HomeDownloadInfo {
  HomeDownloadInfo({required this.stub, required this.warning});
  DownloadStub stub;
  String? warning;
}

HomeDownloadInfo? getHomeDownloadInfo(
  WidgetRef? ref,
  AppLocalizations l10n,
  HomeScreenSectionConfiguration section,
  BaseItemDto? item,
) {
  switch (section.base) {
    case TabsHomeSection tabSection:
      return switch (section.presetType) {
        HomeScreenSectionPresetType.favoriteTracks ||
        HomeScreenSectionPresetType.favoriteAlbums ||
        HomeScreenSectionPresetType.favoriteArtists ||
        HomeScreenSectionPresetType.favoritePlaylists ||
        HomeScreenSectionPresetType.favoriteGenres => HomeDownloadInfo(
          stub: DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.favorites)),
          warning: l10n.homeFavoritesDownloadWarning(tabSection.contentType.toLocalisedString(l10n)),
        ),
        HomeScreenSectionPresetType.recentlyAddedAlbums ||
        HomeScreenSectionPresetType.recentlyAddedTracks => HomeDownloadInfo(
          stub: DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.latest5Albums)),
          warning: l10n.homeRecentAlbumsDownloadWarning,
        ),
        _ => null,
      };
    // TODO put all playlist download somewhere?
    case CollectionHomeSection collectionSection:
      if (item == null) return null;
      final type = BaseItemDtoType.fromItem(item);
      if (type == BaseItemDtoType.collection) {
        // TODO implement collection downloads
        return null;
      } else if ([BaseItemDtoType.artist, BaseItemDtoType.genre].contains(type) &&
          collectionSection.libraryId != allLibraryPlaceholder) {
        final user =
            (ref?.watch(FinampUserHelper.finampCurrentUserProvider) ?? GetIt.instance<FinampUserHelper>().currentUser);
        final BaseItemDto? library;
        if (collectionSection.libraryId == currentLibraryPlaceholder) {
          library = user?.currentView;
        } else {
          library = user?.views[collectionSection.libraryId as BaseItemId];
        }
        if (library == null) {
          return null;
        }
        return HomeDownloadInfo(
          stub: DownloadStub.fromFinampCollection(
            FinampCollection(
              type: FinampCollectionType.collectionWithLibraryFilter,
              // TODO allow LibraryIds?
              library: library,
              item: item,
            ),
          ),
          warning: null,
        );
      } else {
        return HomeDownloadInfo(
          stub: DownloadStub.fromItem(
            type: type == BaseItemDtoType.track ? DownloadItemType.track : DownloadItemType.collection,
            item: item,
          ),
          warning: null,
        );
      }
    case QueuesHomeSection():
      return null;
  }
}
