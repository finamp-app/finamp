import 'dart:async';

import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/extensions/localizations.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/download_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/edit_home_section_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/lock_download_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/menus/components/menu_item_info_header.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../models/jellyfin_models.dart';
import '../services/music_providers.dart';

const Duration albumMenuDefaultAnimationDuration = Duration(milliseconds: 750);
const Curve albumMenuDefaultInCurve = Curves.easeOutCubic;
const Curve albumMenuDefaultOutCurve = Curves.easeInCubic;
const albumMenuRouteName = "/album-menu";

Future<void> showModalHomeSectionMenu({
  required BuildContext context,
  required HomeScreenSectionConfiguration section,
}) async {
  final item = await GetIt.instance<ProviderContainer>().read(resolveSectionProvider(section).future);

  final showPlayback = item is FinampPlayable;

  // Normal menu entries, excluding headers
  List<HideableMenuEntry> getMenuEntries(BuildContext context) {
    final downloadInfo = getHomeDownloadInfo(null, context.l10n, section, item.maybeItem);
    return [
      EditHomeSectionMenuEntry(section: section),
      if (downloadInfo != null)
        DownloadMenuEntry(downloadStub: downloadInfo.stub, warningMessage: downloadInfo.warning),
      if (downloadInfo != null)
        LockDownloadMenuEntry(downloadStub: downloadInfo.stub, warningMessage: downloadInfo.warning),
    ];
  }

  (double, List<Widget>) getMenuProperties(BuildContext context) {
    final menuEntries = getMenuEntries(context);
    final stackHeight = ThemedBottomSheet.calculateStackHeight(
      context: context,
      menuEntries: menuEntries,
      includePlaybackRow: showPlayback,
    );
    List<Widget> menu = [
      SliverPersistentHeader(delegate: MenuItemInfoSliverHeader.condensed(item: item), pinned: true),
      if (showPlayback)
        MenuMask(
          height: MenuItemInfoSliverHeader.condensedHeight,
          child: SliverToBoxAdapter(child: PlaybackActionRow(item: item as FinampPlayable)),
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
      if (tabSection.contentType == ContentType.playlists) {
        return HomeDownloadInfo(
          stub: DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.allPlaylists)),
          warning: section.sortConfig.filters.isEmpty ? null : l10n.homeAllPlaylistsWarning,
        );
      }
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
              // TODO allow LibraryIds instead of fetching full baseitemDtos?
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
