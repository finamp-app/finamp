import 'package:finamp/screens/active_downloads_screen.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finamp_models.dart';
import '../../services/process_artist.dart';
import '../album_image.dart';

class ActiveDownloadListTile extends ConsumerWidget {
  const ActiveDownloadListTile({
    super.key,
    required this.downloadTask,
    required this.showType,
    required this.downloadsService,
  });

  final DownloadsService downloadsService;
  final DownloadStub downloadTask;
  final bool showType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const kNetworkSpeedDecimals = 2;
    final itemDownloadProgress = ref.watch(downloadsService.progressProvider(downloadTask.isarId));

    return ListTile(
      leading: AlbumImage(item: downloadTask.baseItem),
      title: Text(downloadTask.name),

      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showType
                ? AppLocalizations.of(context)!.itemTypeSubtitle(downloadTask.baseItemType.name, "")
                : processArtist(downloadTask.baseItem?.albumArtist, context),
          ),
          if (itemDownloadProgress?.progress != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: DownloadsProgressLinearIndicator(
                    progressValue: itemDownloadProgress!.progress,
                    widthFactor: 3 / 4,
                  ),
                ),
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    // Prevents layout shifting when moving between
                    // progress states and data sizes
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text('999.${'9' * kNetworkSpeedDecimals} MB/s'), // adjust to your actual widest case
                    ),
                    Text(
                      downloadsService.getNetworkSpeedAsString(
                        networkSpeed: itemDownloadProgress.networkSpeed,
                        decimals: kNetworkSpeedDecimals,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
          if (itemDownloadProgress?.hasTimeRemaining ?? false)
            Text(
              '${AppLocalizations.of(context)!.downloadTimeRemaining}: ${itemDownloadProgress!.timeRemainingAsString}',
            ),
        ],
      ),
    );
  }
}
