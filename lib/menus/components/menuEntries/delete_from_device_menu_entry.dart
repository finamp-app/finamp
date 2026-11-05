import 'package:finamp/components/delete_prompts.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/download_action_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeleteFromDeviceMenuEntry extends DownloadActionMenuEntry {
  const DeleteFromDeviceMenuEntry({super.key, required super.downloadStub});

  @override
  bool isVisibleFor(DownloadItemStatus status, {required bool isOffline}) => status.isRequired;

  @override
  Widget buildEntry(BuildContext context, WidgetRef ref, DownloadItemStatus status) {
    return MenuEntry(
      icon: Icons.delete_outlined,
      title: AppLocalizations.of(context)!.deleteFromTargetConfirmButton("device"),
      onTap: () async {
        await askBeforeDeleteDownloadFromDevice(context, downloadStub);
      },
    );
  }
}
