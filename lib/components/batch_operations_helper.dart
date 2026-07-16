import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import '../services/audio_service_helper.dart';
import '../services/downloads_helper.dart';
import '../services/finamp_settings_helper.dart';
import '../services/finamp_user_helper.dart';
import '../services/jellyfin_api_helper.dart';
import 'AlbumScreen/download_dialog.dart';
import 'confirmation_prompt_dialog.dart';
import 'error_snackbar.dart';
import 'song_selection_controller.dart';

/// Performs the batch equivalents of the per-song actions in [SongListTile]'s
/// context menu, over a list of selected songs.
///
/// The underlying helpers are already list-native for queue and playlist
/// operations, so those are a single call. Favourites are single-id at the API
/// layer, so they fan out with [Future.wait]. Downloads are grouped by their
/// parent album because [DownloadsHelper.addDownloads] is parent-centric.
class BatchOperationsHelper {
  static AudioServiceHelper get _audioServiceHelper =>
      GetIt.instance<AudioServiceHelper>();
  static JellyfinApiHelper get _jellyfinApiHelper =>
      GetIt.instance<JellyfinApiHelper>();
  static DownloadsHelper get _downloadsHelper =>
      GetIt.instance<DownloadsHelper>();
  static FinampUserHelper get _finampUserHelper =>
      GetIt.instance<FinampUserHelper>();

  static void _snackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> addToQueue(
      BuildContext context, List<BaseItemDto> items) async {
    if (items.isEmpty) return;
    try {
      await _audioServiceHelper.addQueueItems(items);
      if (!context.mounted) return;
      _snackbar(context, AppLocalizations.of(context)!.addedToQueue);
    } catch (e) {
      errorSnackbar(e, context);
    }
  }

  static Future<void> playNext(
      BuildContext context, List<BaseItemDto> items) async {
    if (items.isEmpty) return;
    try {
      await _audioServiceHelper.insertQueueItemsNext(items);
      if (!context.mounted) return;
      _snackbar(context, AppLocalizations.of(context)!.insertedIntoQueue);
    } catch (e) {
      errorSnackbar(e, context);
    }
  }

  static Future<void> playNow(
      BuildContext context, List<BaseItemDto> items) async {
    if (items.isEmpty) return;
    try {
      await _audioServiceHelper.replaceQueueWithItem(itemList: items);
      if (!context.mounted) return;
      _snackbar(context, AppLocalizations.of(context)!.queueReplaced);
    } catch (e) {
      errorSnackbar(e, context);
    }
  }

  /// Adds or removes favourites for [items]. The [BaseItemDto.userData] of each
  /// item is updated in place so the tiles reflect the new state after the
  /// controller notifies.
  static Future<void> setFavourites(
    BuildContext context,
    List<BaseItemDto> items, {
    required bool addToFavourites,
  }) async {
    if (items.isEmpty) return;
    try {
      await Future.wait(items.map((item) async {
        final newUserData = addToFavourites
            ? await _jellyfinApiHelper.addFavourite(item.id)
            : await _jellyfinApiHelper.removeFavourite(item.id);
        item.userData = newUserData;
      }));

      if (!context.mounted) return;
      _snackbar(
        context,
        addToFavourites
            ? AppLocalizations.of(context)!.addedItemsToFavourites(items.length)
            : AppLocalizations.of(context)!
                .removedItemsFromFavourites(items.length),
      );
    } catch (e) {
      errorSnackbar(e, context);
    }
  }

  static Future<void> instantMix(BuildContext context, BaseItemDto item) async {
    try {
      await _audioServiceHelper.startInstantMixForItem(item);
      if (!context.mounted) return;
      _snackbar(context, AppLocalizations.of(context)!.startingInstantMix);
    } catch (e) {
      errorSnackbar(e, context);
    }
  }

  /// Removes [controller]'s selected songs from the playlist they belong to.
  /// Only valid when [SongSelectionController.isPlaylist] is true.
  static Future<void> removeFromPlaylist(
    BuildContext context,
    SongSelectionController controller,
  ) async {
    final parent = controller.parent;
    if (parent == null) return;

    final items = controller.selectedItems
        .where((e) => e.playlistItemId != null)
        .toList();
    if (items.isEmpty) return;

    try {
      await _jellyfinApiHelper.removeItemsFromPlaylist(
        playlistId: parent.id,
        entryIds: items.map((e) => e.playlistItemId!).toList(),
      );

      if (!context.mounted) return;
      controller.onItemsRemoved?.call(items);
      controller.removeFromSelection(items);
      _snackbar(context, AppLocalizations.of(context)!.removedFromPlaylist);
    } catch (e) {
      errorSnackbar(e, context);
    }
  }

  /// Downloads [items]. When a single [parent] (album/playlist) is supplied
  /// (album/playlist screen) it is used directly; otherwise the songs are
  /// grouped by their album, which is resolved from the server, since
  /// [DownloadsHelper.addDownloads] downloads under a single parent.
  /// Returns true if a download was started (so the caller can leave selection
  /// mode), false if it was cancelled or nothing could be downloaded.
  static Future<bool> download(
    BuildContext context,
    List<BaseItemDto> items, {
    BaseItemDto? parent,
  }) async {
    if (items.isEmpty) return false;
    if (FinampSettingsHelper.finampSettings.isOffline) return false;

    final viewId = _finampUserHelper.currentUser?.currentViewId;
    if (viewId == null) return false;

    late final List<BaseItemDto> parents;
    late final List<List<BaseItemDto>> groupedItems;

    if (parent != null) {
      parents = [parent];
      groupedItems = [items];
    } else {
      final Map<String, List<BaseItemDto>> byAlbum = {};
      for (final item in items) {
        final albumId = item.albumId ?? item.parentId;
        if (albumId == null) continue;
        byAlbum.putIfAbsent(albumId, () => []).add(item);
      }

      final resolvedParents = <BaseItemDto>[];
      final resolvedItems = <List<BaseItemDto>>[];
      var failedAlbums = 0;
      for (final entry in byAlbum.entries) {
        try {
          resolvedParents.add(await _jellyfinApiHelper.getItemById(entry.key));
          resolvedItems.add(entry.value);
        } catch (_) {
          failedAlbums++;
        }
      }
      // Report all resolution failures once instead of one snackbar per album.
      if (failedAlbums > 0 && context.mounted) {
        errorSnackbar(
            "Could not load $failedAlbums album(s) to download.", context);
      }
      parents = resolvedParents;
      groupedItems = resolvedItems;
    }

    if (parents.isEmpty || !context.mounted) return false;

    final downloadLocation = await showDialog<DownloadLocation>(
      context: context,
      builder: (context) => DownloadDialog(
        parents: parents,
        items: groupedItems,
        viewId: viewId,
      ),
    );

    if (downloadLocation == null || !context.mounted) return false;

    await checkedAddDownloads(
      context,
      downloadLocation: downloadLocation,
      parents: parents,
      items: groupedItems,
      viewId: viewId,
    );
    return true;
  }

  /// Deletes the downloads for [items] after a confirmation prompt. Passes
  /// `deletedFor: null` so only the songs' downloads are removed, not any
  /// parent album. [onDeleted] is called after a successful deletion (used to
  /// leave selection mode).
  static void deleteDownloads(
    BuildContext context,
    List<BaseItemDto> items, {
    VoidCallback? onDeleted,
  }) {
    if (items.isEmpty) return;

    // Capture messenger/strings from the (persistent) caller context, since the
    // dialog's own context is deactivated once it pops.
    final messenger = ScaffoldMessenger.of(context);
    final localisations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmationPromptDialog(
        promptText: localisations.deleteSelectedDownloadsPrompt(items.length),
        confirmButtonText: localisations.deleteDownloadsConfirmButtonText,
        abortButtonText: localisations.deleteDownloadsAbortButtonText,
        onConfirmed: () async {
          try {
            await _downloadsHelper.deleteParentAndChildDownloads(
              jellyfinItemIds: items.map((e) => e.id).toList(),
              deletedFor: null,
            );
            messenger.showSnackBar(
                SnackBar(content: Text(localisations.downloadsDeleted)));
            onDeleted?.call();
          } catch (e) {
            if (context.mounted) errorSnackbar(e, context);
          }
        },
        onAborted: () {},
      ),
    );
  }
}
