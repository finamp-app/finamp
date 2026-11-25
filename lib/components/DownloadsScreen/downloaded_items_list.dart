import 'package:finamp/components/delete_prompts.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/redownload_menu_entry.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../album_image.dart';
import 'item_file_size.dart';

class DownloadedItemsTitle extends StatelessWidget {
  const DownloadedItemsTitle({super.key, required this.title, this.action});

  final String title;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 12, right: 16, bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}

class DownloadedItemsList extends ConsumerStatefulWidget {
  const DownloadedItemsList({super.key, required this.type});

  final DownloadsScreenCategory type;

  @override
  ConsumerState<DownloadedItemsList> createState() => _DownloadedItemTypeListState();
}

class _DownloadedItemTypeListState extends ConsumerState<DownloadedItemsList> {
  final _downloadsService = GetIt.instance<DownloadsService>();

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(_downloadsService.userDownloadedItemsProvider(widget.type));
    final isOffline = ref.watch(finampSettingsProvider.isOffline);
    return items.isNotEmpty
        ? SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              DownloadStub stub = items.elementAt(index);
              return ExpansionTile(
                key: PageStorageKey(stub.id),
                leading: (stub.type == DownloadItemType.finampCollection)
                    ? AlbumImage(item: stub.finampCollection?.item)
                    : AlbumImage(item: stub.baseItem),
                title: Text(stub.baseItem?.name ?? stub.name),
                subtitle: buildDownloadedItemSubtitle(context, stub),
                trailing: _DownloadedItemActionsMenu(
                  stub: stub,
                  canSync:
                      !(stub.baseItemType == BaseItemDtoType.album || stub.baseItemType == BaseItemDtoType.track) &&
                      !isOffline,
                  canRedownload: !isOffline,
                  canDelete: true,
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                shape: LinearBorder(),
                collapsedShape: LinearBorder(),
                children: [
                  if (stub.type == DownloadItemType.finampCollection || stub.baseItemType.hasChildren)
                    DownloadedChildrenList(parent: stub),
                ],
              );
            }, childCount: items.length),
          )
        : SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(AppLocalizations.of(context)!.noItemsDownloaded),
            ),
          );
  }
}

class DownloadedChildrenList extends ConsumerStatefulWidget {
  const DownloadedChildrenList({super.key, required this.parent});

  final DownloadStub parent;

  @override
  ConsumerState<DownloadedChildrenList> createState() => _DownloadedChildrenListState();
}

class _DownloadedChildrenListState extends ConsumerState<DownloadedChildrenList> {
  final _downloadsService = GetIt.instance<DownloadsService>();

  @override
  Widget build(BuildContext context) {
    var items = _downloadsService.getVisibleChildren(widget.parent);

    // If we're displaying an artist, we have to filter out tracks that are
    // children of albums we already have in the list
    if ((widget.parent.type == DownloadItemType.collection && widget.parent.baseItemType == BaseItemDtoType.artist) ||
        (widget.parent.type == DownloadItemType.finampCollection &&
            widget.parent.finampCollection!.type == FinampCollectionType.collectionWithLibraryFilter &&
            BaseItemDtoType.fromItem(widget.parent.finampCollection!.item!) == BaseItemDtoType.artist)) {
      // Collect album names
      final albumIds = <BaseItemId>{};
      for (var stub in items) {
        if (BaseItemDtoType.fromItem(stub.baseItem!) == BaseItemDtoType.album) {
          final albumId = stub.baseItem?.id;
          if (albumId != null) albumIds.add(albumId);
        }
      }
      // Filter out tracks with matching album id
      items = items.where((stub) {
        final type = BaseItemDtoType.fromItem(stub.baseItem!);
        if (type == BaseItemDtoType.track) {
          final albumId = stub.baseItem?.albumId;
          return !albumIds.contains(albumId);
        }
        return true;
      }).toList();
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          // TODO use a list builder here
          for (final stub in items)
            ListTile(
              title: Text(stub.baseItem?.name ?? stub.name),
              leading: AlbumImage(item: stub.baseItem),
              subtitle: ItemFileSize(stub: stub),
              trailing: _buildChildActions(stub),
            ),
        ],
      ),
    );
  }

  Widget? _buildChildActions(DownloadStub stub) {
    final status = ref.watch(_downloadsService.statusProvider((stub, null)));
    final canRedownload = status.isDownloaded && !ref.watch(finampSettingsProvider.isOffline);
    if (!canRedownload && !status.isRequired) {
      return null;
    }
    return _DownloadedItemActionsMenu(
      stub: stub,
      canSync: false,
      canRedownload: canRedownload,
      canDelete: status.isRequired,
    );
  }
}

enum _DownloadedItemAction { sync, redownload, delete }

class _DownloadedItemActionsMenu extends StatelessWidget {
  const _DownloadedItemActionsMenu({
    required this.stub,
    required this.canSync,
    required this.canRedownload,
    required this.canDelete,
  });

  final DownloadStub stub;
  final bool canSync;
  final bool canRedownload;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DownloadedItemAction>(
      icon: const Icon(TablerIcons.dots_vertical),
      onSelected: (action) {
        switch (action) {
          case _DownloadedItemAction.sync:
            GetIt.instance<DownloadsService>().resync(stub, null);
          case _DownloadedItemAction.redownload:
            startRedownload(context, stub);
          case _DownloadedItemAction.delete:
            askBeforeDeleteDownloadFromDevice(context, stub);
        }
      },
      itemBuilder: (context) => [
        if (canSync) _buildItem(_DownloadedItemAction.sync, Icons.sync, AppLocalizations.of(context)!.syncItem),
        if (canRedownload)
          _buildItem(
            _DownloadedItemAction.redownload,
            TablerIcons.replace,
            AppLocalizations.of(context)!.redownloadItem,
          ),
        if (canDelete)
          _buildItem(
            _DownloadedItemAction.delete,
            Icons.delete_outlined,
            AppLocalizations.of(context)!.deleteFromTargetConfirmButton("device"),
          ),
      ],
    );
  }

  PopupMenuItem<_DownloadedItemAction> _buildItem(_DownloadedItemAction action, IconData icon, String title) {
    return PopupMenuItem(
      value: action,
      child: ListTile(leading: Icon(icon), title: Text(title), contentPadding: EdgeInsets.zero),
    );
  }
}

Column buildDownloadedItemSubtitle(BuildContext context, DownloadStub stub) {
  String? libraryName;
  final isLegacyAllLibrariesDownload =
      stub.type == DownloadItemType.collection &&
      (BaseItemDtoType.fromItem(stub.baseItem!) == BaseItemDtoType.artist ||
          BaseItemDtoType.fromItem(stub.baseItem!) == BaseItemDtoType.genre);

  final isCollectionWithLibraryFilter =
      !isLegacyAllLibrariesDownload &&
      (stub.type == DownloadItemType.finampCollection &&
          stub.finampCollection?.type == FinampCollectionType.collectionWithLibraryFilter);

  final showLibraryName = isLegacyAllLibrariesDownload || isCollectionWithLibraryFilter;

  if (showLibraryName && isLegacyAllLibrariesDownload) {
    libraryName = AppLocalizations.of(context)!.allLibraries;
  } else if (showLibraryName) {
    libraryName = stub.finampCollection?.library?.name;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showLibraryName && libraryName != null)
        Text(
          libraryName,
          style: TextStyle(
            color: isLegacyAllLibrariesDownload ? Colors.orange : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ItemFileSize(stub: stub),
    ],
  );
}
