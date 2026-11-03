import 'package:finamp/components/AlbumScreen/download_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/download_action_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../components/confirmation_prompt_dialog.dart';

class LockDownloadMenuEntry extends DownloadActionMenuEntry {
  final String? warningMessage;

  const LockDownloadMenuEntry({super.key, required super.downloadStub, this.warningMessage});

  @override
  bool isVisibleFor(DownloadItemStatus status, {required bool isOffline}) => !isOffline && status.isIncidental;

  @override
  Widget buildEntry(BuildContext context, WidgetRef ref, DownloadItemStatus status) {
    final downloadsService = GetIt.instance<DownloadsService>();

    String? parentTooltip;
    if (status.isIncidental) {
      var parent = downloadsService.getFirstRequiringItem(downloadStub);
      if (parent != null) {
        String parentName;
        if (parent.type == DownloadItemType.finampCollection) {
          switch (parent.finampCollection!.type) {
            case FinampCollectionType.collectionWithLibraryFilter:
              parentName = AppLocalizations.of(
                context,
              )!.itemTypeSubtitle(BaseItemDtoType.fromItem(parent.finampCollection!.item!).name, parent.name);
            case _:
              parentName = parent.name;
          }
        } else {
          parentName = AppLocalizations.of(context)!.itemTypeSubtitle(parent.baseItemType.name, parent.name);
        }
        parentTooltip = AppLocalizations.of(context)!.incidentalDownloadTooltip(parentName);
      }
    }

    return Tooltip(
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
    );
  }
}
