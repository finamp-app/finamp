import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../global_snackbar.dart';

const double downloadsOverviewCardLoadingHeight = 120;

class DownloadsOverview extends StatelessWidget {
  const DownloadsOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadsService = GetIt.instance<DownloadsService>();

    downloadsService.updateDownloadCounts();
    downloadsService.restartDownloads();
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (context.mounted) {
        downloadsService.updateDownloadCounts();
      } else {
        timer.cancel();
      }
    });

    // This is refreshed once every 4 seconds by above timer
    return StreamBuilder<Map<String, int>>(
      stream: downloadsService.downloadCountsStream,
      initialData: downloadsService.downloadCounts,
      builder: (context, countSnapshot) {
        // This is throttled to 10 per second in downloadsService constructor.
        return StreamBuilder<Map<DownloadItemState, int>>(
          stream: downloadsService.downloadStatusesStream,
          initialData: downloadsService.downloadStatuses,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final downloadCount =
                  (snapshot.data?[DownloadItemState.complete] ?? 0) +
                  (snapshot.data?[DownloadItemState.needsRedownloadComplete] ?? 0) +
                  (snapshot.data?[DownloadItemState.needsRedownload] ?? 0) +
                  (snapshot.data?[DownloadItemState.failed] ?? 0) +
                  (snapshot.data?[DownloadItemState.enqueued] ?? 0) +
                  (snapshot.data?[DownloadItemState.downloading] ?? 0);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AutoSizeText(
                                AppLocalizations.of(context)!.downloadCount(downloadCount),
                                style: const TextStyle(fontSize: 28),
                                maxLines: 1,
                              ),
                              Text(
                                AppLocalizations.of(context)!.downloadedCountUnified(
                                  countSnapshot.data?["track"] ?? -1,
                                  countSnapshot.data?["image"] ?? -1,
                                  countSnapshot.data?["sync"] ?? -1,
                                  countSnapshot.data?[repairStepTrackingName] ?? 0,
                                ),
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (downloadsService.serverMissingBlurhash)
                                Text(
                                  AppLocalizations.of(context)!.missingBlurhashWarning,
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 50),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.dlComplete(
                                  (snapshot.data?[DownloadItemState.complete] ?? -1) +
                                      (snapshot.data?[DownloadItemState.needsRedownloadComplete] ?? -1),
                                ),
                                style: const TextStyle(color: Colors.blue),
                              ),
                              Text(
                                AppLocalizations.of(context)!.dlFailed(
                                  (snapshot.data?[DownloadItemState.syncFailed] ?? 0) +
                                      (snapshot.data?[DownloadItemState.failed] ?? -1),
                                ),
                                style: const TextStyle(color: Colors.red),
                              ),
                              Text(
                                AppLocalizations.of(context)!
                                    .dlEnqueued(snapshot.data?[DownloadItemState.enqueued] ?? -1),
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Text(
                                AppLocalizations.of(context)!
                                    .dlRunning(snapshot.data?[DownloadItemState.downloading] ?? -1),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              GlobalSnackbar.error(snapshot.error);
              return const SizedBox(
                height: downloadsOverviewCardLoadingHeight,
                child: Card(child: Icon(Icons.error)),
              );
            } else {
              return const SizedBox(
                height: downloadsOverviewCardLoadingHeight,
                child: Card(child: Center(child: CircularProgressIndicator.adaptive())),
              );
            }
          },
        );
      },
    );
  }
}
