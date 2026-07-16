import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../models/jellyfin_models.dart';
import '../screens/add_to_playlist_screen.dart';
import '../screens/album_screen.dart';
import '../services/downloads_helper.dart';
import '../services/finamp_settings_helper.dart';
import '../services/jellyfin_api_helper.dart';
import 'batch_operations_helper.dart';
import 'error_snackbar.dart';
import 'song_selection_controller.dart';

enum _BatchMenuItem {
  playNext,
  download,
  deleteDownload,
  removeFromPlaylist,
  instantMix,
  goToAlbum,
}

/// A contextual bottom bar shown while in selection mode, offering the batch
/// equivalents of the per-song actions. Reads the [SongSelectionController]
/// from the surrounding subtree; renders nothing when not selecting.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SongSelectionController?>();
    if (controller == null || !controller.isSelecting) {
      return const SizedBox.shrink();
    }

    final items = controller.selectedItems;
    final hasSelection = items.isNotEmpty;
    final isOffline = FinampSettingsHelper.finampSettings.isOffline;
    final allFavourite =
        hasSelection && items.every((e) => e.userData?.isFavorite ?? false);

    return Material(
      color: Theme.of(context).colorScheme.surfaceVariant,
      elevation: 8.0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                tooltip: AppLocalizations.of(context)!.replaceQueue,
                onPressed: hasSelection
                    ? () async {
                        await BatchOperationsHelper.playNow(context, items);
                        controller.endSelection();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music),
                tooltip: AppLocalizations.of(context)!.addToQueue,
                onPressed: hasSelection
                    ? () async {
                        await BatchOperationsHelper.addToQueue(context, items);
                        controller.endSelection();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: AppLocalizations.of(context)!.addToPlaylistTitle,
                onPressed: hasSelection && !isOffline
                    ? () => _addToPlaylist(context, controller, items)
                    : null,
              ),
              IconButton(
                icon:
                    Icon(allFavourite ? Icons.favorite : Icons.favorite_border),
                tooltip: allFavourite
                    ? AppLocalizations.of(context)!.removeFavourite
                    : AppLocalizations.of(context)!.addFavourite,
                onPressed: hasSelection
                    ? () async {
                        await BatchOperationsHelper.setFavourites(
                          context,
                          items,
                          addToFavourites: !allFavourite,
                        );
                        controller.endSelection();
                      }
                    : null,
              ),
              PopupMenuButton<_BatchMenuItem>(
                enabled: hasSelection,
                icon: const Icon(Icons.more_vert),
                onSelected: (value) =>
                    _onMenuSelected(context, controller, items, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _BatchMenuItem.playNext,
                    child: ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(AppLocalizations.of(context)!.playNext),
                    ),
                  ),
                  PopupMenuItem(
                    value: _BatchMenuItem.download,
                    enabled: !isOffline,
                    child: ListTile(
                      leading: const Icon(Icons.file_download),
                      title: Text(AppLocalizations.of(context)!.download),
                      enabled: !isOffline,
                    ),
                  ),
                  PopupMenuItem(
                    value: _BatchMenuItem.deleteDownload,
                    child: ListTile(
                      leading: const Icon(Icons.delete),
                      title:
                          Text(AppLocalizations.of(context)!.deleteFromDevice),
                    ),
                  ),
                  if (controller.isPlaylist)
                    PopupMenuItem(
                      value: _BatchMenuItem.removeFromPlaylist,
                      enabled: !isOffline,
                      child: ListTile(
                        leading: const Icon(Icons.playlist_remove),
                        title: Text(AppLocalizations.of(context)!
                            .removeFromPlaylistTitle),
                        enabled: !isOffline,
                      ),
                    ),
                  if (items.length == 1) ...[
                    PopupMenuItem(
                      value: _BatchMenuItem.instantMix,
                      enabled: !isOffline,
                      child: ListTile(
                        leading: const Icon(Icons.explore),
                        title: Text(AppLocalizations.of(context)!.instantMix),
                        enabled: !isOffline,
                      ),
                    ),
                    PopupMenuItem(
                      value: _BatchMenuItem.goToAlbum,
                      child: ListTile(
                        leading: const Icon(Icons.album),
                        title: Text(AppLocalizations.of(context)!.goToAlbum),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToPlaylist(
    BuildContext context,
    SongSelectionController controller,
    List<BaseItemDto> items,
  ) async {
    await Navigator.of(context).pushNamed(
      AddToPlaylistScreen.routeName,
      arguments: items.map((e) => e.id).toList(),
    );
    controller.endSelection();
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    SongSelectionController controller,
    List<BaseItemDto> items,
    _BatchMenuItem value,
  ) async {
    switch (value) {
      case _BatchMenuItem.playNext:
        await BatchOperationsHelper.playNext(context, items);
        controller.endSelection();
        break;
      case _BatchMenuItem.download:
        // Keeps the selection if the download-location dialog is cancelled.
        if (await BatchOperationsHelper.download(context, items,
            parent: controller.parent)) {
          controller.endSelection();
        }
        break;
      case _BatchMenuItem.deleteDownload:
        // The confirmation dialog exits selection itself on confirm.
        BatchOperationsHelper.deleteDownloads(context, items,
            onDeleted: controller.endSelection);
        break;
      case _BatchMenuItem.removeFromPlaylist:
        await BatchOperationsHelper.removeFromPlaylist(context, controller);
        controller.endSelection();
        break;
      case _BatchMenuItem.instantMix:
        await BatchOperationsHelper.instantMix(context, items.first);
        controller.endSelection();
        break;
      case _BatchMenuItem.goToAlbum:
        await _goToAlbum(context, items.first);
        controller.endSelection();
        break;
    }
  }

  Future<void> _goToAlbum(BuildContext context, BaseItemDto item) async {
    if (item.parentId == null) return;
    late BaseItemDto album;
    if (FinampSettingsHelper.finampSettings.isOffline) {
      final downloadsHelper = GetIt.instance<DownloadsHelper>();
      final downloadedParent =
          downloadsHelper.getDownloadedParent(item.parentId!);
      if (downloadedParent == null) return;
      album = downloadedParent.item;
    } else {
      try {
        album = await GetIt.instance<JellyfinApiHelper>()
            .getItemById(item.parentId!);
      } catch (e) {
        if (context.mounted) errorSnackbar(e, context);
        return;
      }
    }

    if (!context.mounted) return;
    Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: album);
  }
}

/// Stacks the [SelectionActionBar] above [child] (typically the now playing
/// bar) so both can live in a Scaffold's `bottomNavigationBar`.
class SelectionAwareBottomBar extends StatelessWidget {
  const SelectionAwareBottomBar({Key? key, required this.child})
      : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SelectionActionBar(),
        child,
      ],
    );
  }
}
