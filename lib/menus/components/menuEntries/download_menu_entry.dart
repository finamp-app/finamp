import 'package:finamp/components/AlbumScreen/download_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class DownloadMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final DownloadStub downloadStub;

  const DownloadMenuEntry({super.key, required this.downloadStub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();

    final DownloadItemStatus? downloadStatus = ref.watch(downloadsService.statusProvider((downloadStub, null)));

    return Visibility(
      visible:
          !ref.watch(finampSettingsProvider.isOffline) &&
          downloadStatus == DownloadItemStatus.notNeeded &&
          !ref.watch(finampSettingsProvider.enableChildMode),
      child: MenuEntry(
        icon: TablerIcons.download,
        title: AppLocalizations.of(context)!.downloadItem,
        onTap: () async {
          await DownloadDialog.show(context, downloadStub, null);
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  bool get isVisible =>
      GetIt.instance<DownloadsService>().getStatus(downloadStub, null) == DownloadItemStatus.notNeeded &&
      !FinampSettingsHelper.finampSettings.isOffline &&
      !FinampSettingsHelper.finampSettings.enableChildMode;
}
