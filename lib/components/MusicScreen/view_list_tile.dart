import 'package:collection/collection.dart';
import 'package:finamp/components/AlbumScreen/download_button.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/finamp_user_helper.dart';

class ViewListTile extends ConsumerWidget {
  const ViewListTile({super.key, required this.view});

  final LibraryId view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();

    final currentViewId = ref.watch(FinampUserHelper.currentUserProvider.select((value) => value?.currentLibraryId));
    final viewItem = ref.watch(
      FinampUserHelper.currentUserProvider.select(
        (value) => value?.views.values.firstWhereOrNull((x) => x.id.raw == view.raw),
      ),
    );
    assert(viewItem != null || view == allLibraryPlaceholder);
    final name = switch (view) {
      allLibraryPlaceholder => context.l10n.allLibraries,
      _ => viewItem?.name,
    };

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: name, selected: currentViewId == view),
      container: true,
      child: ToggleableListTile(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: Icon(
            view == allLibraryPlaceholder ? TablerIcons.blend_mode : getViewIcon(viewItem?.collectionType),
            color: currentViewId == view ? Theme.of(context).colorScheme.primary : null,
            size: 20.0,
          ),
        ),
        title: name ?? context.l10n.unknownName,
        titleStyle: TextStyle(fontSize: 14.0),
        trailing: viewItem == null
            ? SizedBox.shrink()
            : DownloadButton(
                isLibrary: true,
                item: DownloadStub.fromItem(item: viewItem, type: DownloadItemType.collection),
              ),
        condensed: true,
        state: currentViewId == view,
        onToggle: (bool currentState) async {
          finampUserHelper.setCurrentUserCurrentViewId(view);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          // update state first to give visual feedback, then close menu
          if (!context.mounted) return;
          Navigator.of(context).pop();
          //await Navigator.of(context).maybePop();
        },
        lowContrast: true,
      ),
    );
  }
}

IconData getViewIcon(String? collectionType) {
  switch (collectionType) {
    case "movies":
      return Icons.movie;
    case "tvshows":
      return Icons.tv;
    case "music":
      return Icons.music_note;
    case "games":
      return Icons.games;
    case "books":
      return Icons.book;
    case "musicvideos":
      return Icons.music_video;
    case "homevideos":
      return Icons.videocam;
    case "livetv":
      return Icons.live_tv;
    case "channels":
      return Icons.settings_remote;
    case "playlists":
      return TablerIcons.playlist;
    default:
      return Icons.warning;
  }
}
