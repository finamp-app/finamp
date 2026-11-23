import 'package:finamp/components/redownload_action.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/download_action_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class RedownloadMenuEntry extends DownloadActionMenuEntry {
  RedownloadMenuEntry({super.key, required super.baseItem}) : super.forItem();

  @override
  bool isVisibleFor(DownloadItemStatus status, {required bool isOffline}) => !isOffline && status.isDownloaded;

  @override
  Widget buildEntry(BuildContext context, WidgetRef ref, DownloadItemStatus status) {
    return MenuEntry(
      icon: TablerIcons.reload,
      title: AppLocalizations.of(context)!.redownloadItem,
      onTap: () async {
        Navigator.pop(context);
        await startRedownload(downloadStub);
      },
    );
  }
}
