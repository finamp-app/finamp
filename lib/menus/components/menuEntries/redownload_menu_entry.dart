import 'dart:async';

import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/download_action_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

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
        if (await startRedownload(context, downloadStub) && context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }
}

/// Items larger than this ask for confirmation before being redownloaded.
const _redownloadConfirmationThresholdBytes = 500 * 1024 * 1024;

/// Starts a redownload of the given item, asking for confirmation first if its files are large.
/// Returns whether the redownload was started.
Future<bool> startRedownload(BuildContext context, DownloadStub stub) async {
  final size = await GetIt.instance<DownloadsService>().getFileSize(stub);
  if (size > _redownloadConfirmationThresholdBytes) {
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationPromptDialog(
        promptText: AppLocalizations.of(context)!.redownloadConfirmation(FileSize.getSize(size)),
        confirmButtonText: AppLocalizations.of(context)!.redownloadItem,
        centerText: true,
      ),
    );
    if (confirmed != true) return false;
  }
  unawaited(_redownload(stub));
  return true;
}

/// Redownloads the given item and informs the user about the result.
Future<void> _redownload(DownloadStub stub) async {
  final viewId = GetIt.instance<FinampUserHelper>().currentUser?.currentViewId;
  GlobalSnackbar.message((context) => AppLocalizations.of(context)!.redownloadQueued, isConfirmation: true);
  try {
    await GetIt.instance<DownloadsService>().redownload(stub, viewId);
  } catch (e) {
    GlobalSnackbar.error(e);
  }
}
