import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finamp_models.dart';
import 'download_location_delete_dialog.dart';

class DownloadLocationListTile extends ConsumerWidget {
  const DownloadLocationListTile({super.key, required this.downloadLocation});

  final DownloadLocation downloadLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isDefault = ref.watch(
      finampSettingsProvider.select((value) => value.value?.defaultDownloadLocation == downloadLocation.id),
    );

    return ListTile(
      title: Text(downloadLocation.name),
      subtitle: Text(downloadLocation.currentPath),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isDefault ? Icons.star : Icons.star_outline),
            onPressed: () {
              FinampSetters.setDefaultDownloadLocation(isDefault ? null : downloadLocation.id);
            },
            tooltip: AppLocalizations.of(context)!.defaultDownloadLocationButton,
          ),
          if (downloadLocation.baseDirectory.needsPath)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => DownloadLocationDeleteDialog(id: downloadLocation.id),
              ),
            ),
        ],
      ),
    );
  }
}
