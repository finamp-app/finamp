import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';

class DownloadLocationDeleteDialog extends StatelessWidget {
  const DownloadLocationDeleteDialog({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    var downloads = GetIt.instance<DownloadsService>().getDownloadsForLocation(id, false);
    if (downloads.isEmpty) {
      return AlertDialog(
        title: Text(context.l10n.areYouSure),
        content: Text(context.l10n.noDownloadsInLocation),
        actions: [
          TextButton(child: Text(context.l10n.genericCancel), onPressed: () => Navigator.of(context).pop()),
          TextButton(
            child: Text(context.l10n.deleteDownloadLocation),
            onPressed: () {
              var fileDownloads = GetIt.instance<DownloadsService>().getDownloadsForLocation(id, true);
              if (fileDownloads.isNotEmpty) {
                Navigator.of(context).pop();
                GlobalSnackbar.message(
                  (_) =>
                      "Could not delete download location - unexpected downloads found in location.  Try running a downloads repair.",
                );
              } else {
                FinampSettingsHelper.deleteDownloadLocation(id);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
    } else {
      return AlertDialog(
        title: Text(context.l10n.cannotDeleteLocation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.cannotDeleteLocationEplanation),
            ...downloads.map(
              (stub) => Text(AppLocalizations.of(context)!.itemTypeSubtitle(stub.baseItemType.name, stub.name)),
            ),
          ],
        ),
      );
    }
  }
}
