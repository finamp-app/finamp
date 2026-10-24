import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

/// Base for menu entries acting on the download of an item.
/// Subclasses decide when they are shown via [isVisibleFor]
/// and build their entry via [buildEntry].
abstract class DownloadActionMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final DownloadStub downloadStub;

  const DownloadActionMenuEntry({super.key, required this.downloadStub});

  DownloadActionMenuEntry.forItem({super.key, required BaseItemDto baseItem}) : downloadStub = stubForItem(baseItem);

  /// Gets the stub used to download the given item from its menu.
  static DownloadStub stubForItem(BaseItemDto baseItem) {
    final library = GetIt.instance<FinampUserHelper>().currentUser?.currentView;
    return switch (BaseItemDtoType.fromItem(baseItem)) {
      BaseItemDtoType.track => DownloadStub.fromItem(type: DownloadItemType.track, item: baseItem),
      BaseItemDtoType.artist || BaseItemDtoType.genre => DownloadStub.fromFinampCollection(
        FinampCollection(type: FinampCollectionType.collectionWithLibraryFilter, library: library, item: baseItem),
      ),
      _ => DownloadStub.fromItem(type: DownloadItemType.collection, item: baseItem),
    };
  }

  bool isVisibleFor(DownloadItemStatus status, {required bool isOffline});

  Widget buildEntry(BuildContext context, WidgetRef ref, DownloadItemStatus status);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();

    final DownloadItemStatus downloadStatus = ref.watch(downloadsService.statusProvider((downloadStub, null)));

    return Visibility(
      visible: isVisibleFor(downloadStatus, isOffline: ref.watch(finampSettingsProvider.isOffline)),
      child: buildEntry(context, ref, downloadStatus),
    );
  }

  @override
  bool get isVisible => isVisibleFor(
    GetIt.instance<DownloadsService>().getStatus(downloadStub, null),
    isOffline: FinampSettingsHelper.finampSettings.isOffline,
  );
}
