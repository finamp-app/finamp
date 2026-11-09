import 'package:collection/collection.dart';
import 'package:finamp/menus/components/menuEntries/delete_from_device_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/download_action_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/download_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/lock_download_menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows whichever of the download, delete and lock entries applies to the item.
class AdaptiveDownloadLockDeleteMenuEntry extends DownloadActionMenuEntry {
  AdaptiveDownloadLockDeleteMenuEntry({super.key, required super.baseItem}) : super.forItem();

  List<DownloadActionMenuEntry> get _candidates => [
    DownloadMenuEntry(downloadStub: downloadStub),
    DeleteFromDeviceMenuEntry(downloadStub: downloadStub),
    LockDownloadMenuEntry(downloadStub: downloadStub),
  ];

  @override
  bool isVisibleFor(DownloadItemStatus status, {required bool isOffline}) =>
      _candidates.any((e) => e.isVisibleFor(status, isOffline: isOffline));

  @override
  Widget buildEntry(BuildContext context, WidgetRef ref, DownloadItemStatus status) {
    final isOffline = ref.watch(finampSettingsProvider.isOffline);
    return _candidates.firstWhereOrNull((e) => e.isVisibleFor(status, isOffline: isOffline)) ?? const SizedBox.shrink();
  }
}
