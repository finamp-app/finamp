import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../models/jellyfin_models.dart';

Future<void> askBeforeDeleteDownloadFromDevice(BuildContext context, DownloadStub stub, {VoidCallback? refresh}) async {
  String type = stub.baseItemType.name;
  await showDialog<void>(
    context: context,
    builder: (context) => ConfirmationPromptDialog(
      promptText: AppLocalizations.of(context)!.deleteFromTargetDialogText("", "device", type),
      confirmButtonText: AppLocalizations.of(context)!.deleteFromTargetConfirmButton("device"),
      onConfirmed: () async {
        try {
          await GetIt.instance<DownloadsService>().deleteDownload(stub: stub);
          GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.itemDeletedSnackbar("device", type));

          if (context.mounted && FinampSettingsHelper.finampSettings.isOffline) {
            Navigator.of(context).popUntil((route) {
              return route.settings.name !=
                      null // unnamed dialog
                      &&
                  route.settings.name != AlbumScreen.routeName; // albums screen
            });
          }
        } catch (err) {
          GlobalSnackbar.error(err);
        } finally {
          refresh != null ? refresh() : null;
        }
      },
      centerText: true,
    ),
  );
}

Future<void> askBeforeDeleteFromServerAndDevice(
  BuildContext context,
  DownloadStub stub, {
  VoidCallback? refresh,
  bool popIt = false,
}) async {
  DownloadItemStatus status = GetIt.instance<DownloadsService>().getStatus(stub, null);
  String type = stub.baseItemType.name;

  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();

  final deleteType = status.toDeleteType();

  await showDialog<void>(
    context: context,
    builder: (_) => ConfirmationPromptDialog(
      promptText: AppLocalizations.of(context)!.deleteFromTargetDialogText(deleteType.textForm, "server", type),
      confirmButtonText: AppLocalizations.of(context)!.deleteFromTargetConfirmButton("server"),
      onConfirmed: () async {
        try {
          await jellyfinApiHelper.deleteItem(BaseItemId(stub.id));
          GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.itemDeletedSnackbar("server", type));

          if (status.isRequired) {
            await downloadsService.deleteDownload(stub: stub);
            GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.itemDeletedSnackbar("device", type));
          }

          if (context.mounted) {
            if (popIt) {
              Navigator.of(context).popUntil((route) {
                return route.settings.name !=
                        null // unnamed dialog
                        &&
                    route.settings.name != AlbumScreen.routeName; // albums screen
              });
            }
          }
        } catch (err) {
          GlobalSnackbar.error(err);
        } finally {
          refresh != null ? refresh() : null;
        }
      },
      centerText: true,
    ),
  );
}
