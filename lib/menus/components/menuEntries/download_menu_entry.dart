import 'package:finamp/components/AlbumScreen/download_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/download_action_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../components/confirmation_prompt_dialog.dart';

class DownloadMenuEntry extends DownloadActionMenuEntry {
  final String? warningMessage;

  const DownloadMenuEntry({super.key, required super.downloadStub, this.warningMessage});

  @override
  bool isVisibleFor(DownloadItemStatus status, {required bool isOffline}) =>
      !isOffline && status == DownloadItemStatus.notNeeded;

  @override
  Widget buildEntry(BuildContext context, WidgetRef ref, DownloadItemStatus status) {
    return MenuEntry(
      icon: TablerIcons.download,
      title: AppLocalizations.of(context)!.downloadItem,
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
    );
  }
}
