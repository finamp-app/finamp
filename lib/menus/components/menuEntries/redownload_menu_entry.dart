import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/download_action_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class RedownloadMenuEntry extends DownloadActionMenuEntry {
  RedownloadMenuEntry({super.key, required super.baseItem}) : super.forItem();

  @override
  bool isVisibleFor(DownloadItemStatus status, {required bool isOffline}) => !isOffline && status.isDownloaded;

  @override
  Widget buildEntry(BuildContext context, WidgetRef ref, DownloadItemStatus status) {
    return MenuEntry(
      icon: Icons.sync,
      title: AppLocalizations.of(context)!.redownloadItem,
      onTap: () async {
        final viewId = GetIt.instance<FinampUserHelper>().currentUser?.currentViewId;
        Navigator.pop(context);
        GlobalSnackbar.message((context) => AppLocalizations.of(context)!.redownloadQueued, isConfirmation: true);
        try {
          await GetIt.instance<DownloadsService>().redownload(downloadStub, viewId);
        } catch (e) {
          GlobalSnackbar.error(e);
        }
      },
    );
  }
}
