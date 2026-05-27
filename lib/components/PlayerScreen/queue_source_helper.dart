import 'dart:async';

import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/screens/downloads_screen.dart';
import 'package:finamp/screens/genre_screen.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/services/album_screen_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

void navigateToSource(BuildContext context, QueueItemSource source) {
  switch (source.type) {
    case QueueItemSourceType.album:
    case QueueItemSourceType.nextUpAlbum:
    case QueueItemSourceType.albumMix:
      Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: source.item);
      break;
    case QueueItemSourceType.artist:
    case QueueItemSourceType.nextUpArtist:
    case QueueItemSourceType.artistMix:
      Navigator.of(context).pushNamed(ArtistScreen.routeName, arguments: source.item);
      break;
    case QueueItemSourceType.genre:
    case QueueItemSourceType.nextUpGenre:
    case QueueItemSourceType.genreMix:
      Navigator.of(context).pushNamed(GenreScreen.routeName, arguments: source.item);
      break;
    case QueueItemSourceType.playlist:
    case QueueItemSourceType.nextUpPlaylist:
      Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: source.item);
      break;
    case QueueItemSourceType.allTracks:
    case QueueItemSourceType.favorites:
      Navigator.of(context).pushNamed(MusicScreen.routeName, arguments: ContentType.tracks);
      break;
    case QueueItemSourceType.track:
    case QueueItemSourceType.trackMix:
      if (source.item != null) {
        showModalTrackMenu(context: context, item: source.item!);
      }
    case QueueItemSourceType.radio:
      final radioSource = GetIt.instance<QueueService>().getQueue().source;
      if (radioSource.item == null) {
        break;
      }
      switch (BaseItemDtoType.fromItem(radioSource.item!)) {
        case BaseItemDtoType.track:
          showModalTrackMenu(context: context, item: radioSource.item!);
          break;
        case BaseItemDtoType.album:
        case BaseItemDtoType.playlist:
          Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: radioSource.item);
          break;
        case BaseItemDtoType.artist:
          Navigator.of(context).pushNamed(ArtistScreen.routeName, arguments: radioSource.item);
          break;
        case BaseItemDtoType.genre:
          Navigator.of(context).pushNamed(GenreScreen.routeName, arguments: radioSource.item);
          break;
        case BaseItemDtoType.collection:
        //TODO implement collection screen
        case BaseItemDtoType.noItem:
        case BaseItemDtoType.library:
        case BaseItemDtoType.folder:
        case BaseItemDtoType.musicVideo:
        case BaseItemDtoType.audioBook:
        case BaseItemDtoType.tvEpisode:
        case BaseItemDtoType.video:
        case BaseItemDtoType.movie:
        case BaseItemDtoType.trailer:
        case BaseItemDtoType.unknown:
          break;
      }
      break;
    case QueueItemSourceType.homeScreenSection:
      final sectionInfo = FinampSettingsHelper.finampSettings.homeScreenConfiguration.sections.singleWhere(
        (section) => section.id == source.id,
      );
      Navigator.of(
        context,
      ).push(MaterialPageRoute<MusicScreen>(builder: (context) => MusicScreen(singleTabConfig: sectionInfo)));
      break;
    case QueueItemSourceType.downloads:
      Navigator.of(context).pushNamed(DownloadsScreen.routeName);
      break;
    case QueueItemSourceType.nextUp:
    case QueueItemSourceType.formerNextUp:
    case QueueItemSourceType.remoteClient:
    case QueueItemSourceType.unknown:
      break;
    case QueueItemSourceType.filteredList:
    case QueueItemSourceType.queue:
      FeedbackHelper.feedback(FeedbackType.warning);
      GlobalSnackbar.message((scaffold) => AppLocalizations.of(context)!.notImplementedYet);
  }
}

Future<bool> removeFromPlaylist(
  BuildContext context,
  BaseItemDto item,
  BaseItemDto parent,
  String playlistItemId, {
  required bool confirm,
}) async {
  bool isConfirmed = !confirm;
  if (confirm) {
    await showDialog(
      context: context,
      builder: (context) => ConfirmationPromptDialog(
        promptText: AppLocalizations.of(
          context,
        )!.removeFromPlaylistPrompt(item.name ?? "item", parent.name ?? "playlist"),
        confirmButtonText: AppLocalizations.of(context)!.removeFromPlaylistConfirm,
        onConfirmed: () {
          isConfirmed = true;
        },
      ),
    );
  }
  if (isConfirmed) {
    try {
      await GetIt.instance<JellyfinApiHelper>().removeItemsFromPlaylist(
        playlistId: parent.id,
        entryIds: [playlistItemId],
      );

      // re-sync playlist to delete removed item if not required anymore
      final downloadsService = GetIt.instance<DownloadsService>();
      unawaited(
        downloadsService.resync(
          DownloadStub.fromItem(type: DownloadItemType.collection, item: parent),
          null,
          keepSlow: true,
        ),
      );

      playlistRemovalsCache.add(parent.id.raw + playlistItemId);

      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.removedFromPlaylist, isConfirmation: true);
      return true;
    } catch (err) {
      GlobalSnackbar.error(err);
      return false;
    }
  }
  return false;
}

Future<bool> addItemsToPlaylist(BuildContext context, List<BaseItemDto> items, BaseItemDto parent) async {
  // Albums and playlists do not seem to add in the correct order, so manually fetch and add all children instead of
  // relying on server to do that.
  if (items.length == 1 &&
      [BaseItemDtoType.album, BaseItemDtoType.playlist].contains(BaseItemDtoType.fromItem(items.first))) {
    final children = await GetIt.instance<ProviderContainer>().read(
      getAlbumOrPlaylistTracksProvider(items.first).future,
    );
    items = children.$1;
  }

  //TODO request server to return the new playlist item id
  await GetIt.instance<JellyfinApiHelper>().addItemstoPlaylist(
    playlistId: parent.id,
    ids: items.map((item) {
      return item.id;
    }).toList(),
  );

  // re-sync playlist to download added item if needed
  final downloadsService = GetIt.instance<DownloadsService>();
  unawaited(
    downloadsService.resync(
      DownloadStub.fromItem(type: DownloadItemType.collection, item: parent),
      null,
      keepSlow: true,
    ),
  );

  GlobalSnackbar.message((scaffold) => AppLocalizations.of(context)!.confirmAddedToPlaylist, isConfirmation: true);
  return true;
}

// Removed playlist items will persist in queue with playlist source.  Store removed items
// to hide remove from playlist prompt on those items.
final Set<String> playlistRemovalsCache = {};

bool queueItemInPlaylist(FinampQueueItem? queueItem) {
  if (queueItem == null) {
    return false;
  }
  final baseItem = queueItem.baseItem;
  return [QueueItemSourceType.playlist, QueueItemSourceType.nextUpPlaylist].contains(queueItem.source.type) &&
      baseItem.playlistItemId != null &&
      !playlistRemovalsCache.contains(queueItem.source.id + (baseItem.playlistItemId ?? ""));
}
