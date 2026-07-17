import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../l10n/app_localizations.dart';
import '../../menus/playlist_actions_menu.dart';
import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../models/music_slices.dart';
import '../../services/favorite_provider.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/queue_service.dart';
import '../../services/track_selection_provider.dart';
import '../global_snackbar.dart';

/// Close (X) button that leaves selection mode.
Widget trackSelectionCloseButton(String scope) {
  return Consumer(
    builder: (context, ref, _) => IconButton(
      icon: const Icon(Icons.close),
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: () => ref.read(trackSelectionProvider(scope).notifier).endSelection(),
    ),
  );
}

/// "N selected" title.
Widget trackSelectionTitle(String scope) {
  return Consumer(
    builder: (context, ref, _) {
      final count = ref.watch(trackSelectionProvider(scope).select((s) => s.count));
      return Text(AppLocalizations.of(context)!.itemsSelected(count));
    },
  );
}

/// Select-all / deselect-all action for the selection app bar, evaluated against
/// [allTracks] (the surface's full list).
List<Widget> trackSelectionAppBarActions(String scope, List<BaseItemDto> allTracks) {
  return [
    Consumer(
      builder: (context, ref, _) {
        final allSelected = ref.watch(trackSelectionProvider(scope).select((s) => s.allSelected(allTracks)));
        return IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? AppLocalizations.of(context)!.deselectAll : AppLocalizations.of(context)!.selectAll,
          onPressed: allTracks.isEmpty
              ? null
              : () {
                  final notifier = ref.read(trackSelectionProvider(scope).notifier);
                  if (allSelected) {
                    notifier.deselectAll();
                  } else {
                    notifier.selectAll(allTracks);
                  }
                },
        );
      },
    ),
  ];
}

enum _BatchAction { addToNextUp }

/// A contextual bottom bar shown while a track list is in selection mode,
/// offering the batch equivalents of the per-track actions. Renders nothing
/// when not selecting. Meant to sit above the now playing bar.
class TrackSelectionActionBar extends ConsumerWidget {
  const TrackSelectionActionBar({super.key, required this.scope, required this.parent});

  final String scope;
  final BaseItemDto parent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackSelectionProvider(scope));
    if (!state.isSelecting) return const SizedBox.shrink();

    final items = state.selectedItems;
    final hasSelection = items.isNotEmpty;
    final isOffline = ref.watch(finampSettingsProvider.isOffline);
    final isPlaylist = BaseItemDtoType.fromItem(parent) == BaseItemDtoType.playlist;
    final allFavourite = hasSelection && items.every((e) => e.userData?.isFavorite ?? false);

    final source = QueueItemSource.fromBaseItem(parent);
    final queueService = GetIt.instance<QueueService>();

    void exitSelection() => ref.read(trackSelectionProvider(scope).notifier).endSelection();

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
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
                tooltip: AppLocalizations.of(context)!.playButtonLabel,
                onPressed: hasSelection
                    ? () async {
                        await queueService.startPlayback(
                          items: items,
                          source: source,
                          order: FinampPlaybackOrder.linear,
                        );
                        exitSelection();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music),
                tooltip: AppLocalizations.of(context)!.addToQueue,
                onPressed: hasSelection
                    ? () async {
                        await queueService.addToQueue(PlayableSlice.simple(items, source));
                        GlobalSnackbar.message(
                          (scaffold) => AppLocalizations.of(scaffold)!.confirmAddToQueue("track"),
                          isConfirmation: true,
                        );
                        exitSelection();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.playlist_play),
                tooltip: AppLocalizations.of(context)!.playNext,
                onPressed: hasSelection
                    ? () async {
                        await queueService.addNext(PlayableSlice.simple(items, source));
                        GlobalSnackbar.message(
                          (scaffold) => AppLocalizations.of(scaffold)!.confirmPlayNext("track"),
                          isConfirmation: true,
                        );
                        exitSelection();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: AppLocalizations.of(context)!.addToPlaylistTooltip,
                onPressed: hasSelection && !isOffline
                    ? () async {
                        await showPlaylistActionsMenu(
                          context: context,
                          items: items,
                          parentPlaylist: isPlaylist ? parent : null,
                        );
                        exitSelection();
                      }
                    : null,
              ),
              IconButton(
                icon: Icon(allFavourite ? Icons.favorite : Icons.favorite_border),
                tooltip: allFavourite
                    ? AppLocalizations.of(context)!.removeFavorite
                    : AppLocalizations.of(context)!.addFavorite,
                onPressed: hasSelection
                    ? () {
                        final target = !allFavourite;
                        for (final item in items) {
                          ref.read(isFavoriteProvider(item).notifier).updateFavorite(target);
                        }
                        exitSelection();
                      }
                    : null,
              ),
              PopupMenuButton<_BatchAction>(
                enabled: hasSelection,
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  switch (value) {
                    case _BatchAction.addToNextUp:
                      await queueService.addToNextUp(PlayableSlice.simple(items, source));
                      GlobalSnackbar.message(
                        (scaffold) => AppLocalizations.of(scaffold)!.confirmAddToNextUp("track"),
                        isConfirmation: true,
                      );
                      exitSelection();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _BatchAction.addToNextUp,
                    child: ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(AppLocalizations.of(context)!.addToNextUp),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stacks the [TrackSelectionActionBar] above [child] (the now playing bar).
class TrackSelectionAwareBottomBar extends StatelessWidget {
  const TrackSelectionAwareBottomBar({super.key, required this.scope, required this.parent, required this.child});

  final String scope;
  final BaseItemDto parent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrackSelectionActionBar(scope: scope, parent: parent),
        child,
      ],
    );
  }
}
