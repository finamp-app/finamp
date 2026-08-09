import 'package:finamp/components/delete_prompts.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 12, right: 16, bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            if (action != null) action!,
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((!(stub.baseItemType == BaseItemDtoType.album || stub.baseItemType == BaseItemDtoType.track)) &&
                        !ref.watch(finampSettingsProvider.isOffline))
                      IconButton(
                        icon: const Icon(Icons.sync),
                        onPressed: () {
                          _downloadsService.resync(stub, null);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => askBeforeDeleteDownloadFromDevice(context, stub),
                    ),
                  ],
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
              trailing: ref.watch(_downloadsService.statusProvider((stub, null))).isRequired
                  ? IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => askBeforeDeleteDownloadFromDevice(context, stub),
                    )
                  : null,
            ),
        ],
      ),
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
