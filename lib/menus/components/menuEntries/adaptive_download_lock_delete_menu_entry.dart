import 'package:finamp/menus/components/menuEntries/delete_from_device_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/download_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/lock_download_menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'menu_entry.dart';

class AdaptiveDownloadLockDeleteMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const AdaptiveDownloadLockDeleteMenuEntry({super.key, required this.baseItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();

    final DownloadStub downloadStub = _getStub(ref);

    final DownloadItemStatus? downloadStatus = ref.watch(downloadsService.statusProvider((downloadStub, null)));

    if (!ref.watch(finampSettingsProvider.isOffline) && downloadStatus == DownloadItemStatus.notNeeded) {
      return DownloadMenuEntry(downloadStub: downloadStub);
    } else if (downloadStatus?.isRequired ?? false) {
      return DeleteFromDeviceMenuEntry(downloadStub: downloadStub);
    } else if (!ref.watch(finampSettingsProvider.isOffline) && (downloadStatus?.isIncidental ?? false)) {
      return LockDownloadMenuEntry(downloadStub: downloadStub);
    } else {
      return SizedBox.shrink();
    }
  }

  DownloadStub _getStub(WidgetRef? ref) {
    final library =
        ref?.watch(FinampUserHelper.currentLibraryProvider) ??
        GetIt.instance<FinampUserHelper>().currentUser?.currentLibraryId;
    return switch (BaseItemDtoType.fromItem(baseItem)) {
      BaseItemDtoType.track => DownloadStub.fromItem(type: DownloadItemType.track, item: baseItem),
      BaseItemDtoType.artist ||
      BaseItemDtoType.genre => DownloadStub.libraryFilteredItem(item: baseItem, library: library),
      _ => DownloadStub.fromItem(type: DownloadItemType.collection, item: baseItem),
    };
  }

  @override
  bool get isVisible {
    final DownloadItemStatus downloadStatus = GetIt.instance<DownloadsService>().getStatus(_getStub(null), null);

    return downloadStatus.isRequired || !FinampSettingsHelper.finampSettings.isOffline;
  }
}
