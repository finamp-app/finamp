import 'package:finamp/components/AlbumScreen/download_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../components/confirmation_prompt_dialog.dart';

class LockDownloadMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final DownloadStub downloadStub;
  final String? warningMessage;

  const LockDownloadMenuEntry({super.key, required this.downloadStub, this.warningMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();

    final DownloadItemStatus? downloadStatus = ref.watch(downloadsService.statusProvider((downloadStub, null)));

    String? parentTooltip;
    if (downloadStatus?.isIncidental ?? false) {
      var parent = downloadsService.getFirstRequiringItem(downloadStub);
      if (parent != null) {
        var parentName = AppLocalizations.of(context)!.itemTypeSubtitle(parent.baseItemType.name, parent.name);
        parentTooltip = AppLocalizations.of(context)!.incidentalDownloadTooltip(parentName);
      }
    }

    return Visibility(
      visible: !ref.watch(finampSettingsProvider.isOffline) && (downloadStatus?.isIncidental ?? false),
      child: Tooltip(
        message: parentTooltip ?? "Widget shouldn't be visible",
        child: MenuEntry(
          icon: Icons.lock_outlined,
          title: AppLocalizations.of(context)!.lockDownload,
          onTap: () async {
            if (warningMessage != null) {
              final confirmed = await showDialog<bool?>(
                context: context,
                builder: (context) => ConfirmationPromptDialog(
                  promptText: warningMessage!,
                  confirmButtonText: AppLocalizations.of(context)!.addButtonLabel,
                ),
              );
              if ((confirmed ?? false) && context.mounted) {
                await DownloadDialog.show(context, downloadStub, null);
              }
            } else {
              await DownloadDialog.show(context, downloadStub, null);
            }
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  @override
  bool get isVisible =>
      GetIt.instance<DownloadsService>().getStatus(downloadStub, null).isIncidental &&
      !FinampSettingsHelper.finampSettings.isOffline;
}
