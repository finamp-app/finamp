import 'dart:async';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              final downloading = snapshot.data?[DownloadItemState.downloading] ?? 0;
              final downloadComplete = snapshot.data?[DownloadItemState.complete] ?? 0;
              final needsRedownloadComplete = snapshot.data?[DownloadItemState.needsRedownloadComplete] ?? 0;
              final needsRedownload = snapshot.data?[DownloadItemState.needsRedownload] ?? 0;
              final downloadFailed = snapshot.data?[DownloadItemState.failed] ?? 0;
              final downloadEnqueued = snapshot.data?[DownloadItemState.enqueued] ?? 0;
              final downloadSyncFailed = snapshot.data?[DownloadItemState.syncFailed] ?? 0;

              final totalDownloadCount =
                  downloading +
                  downloadComplete +
                  needsRedownloadComplete +
                  needsRedownload +
                  downloadFailed +
                  downloadEnqueued;

              final totalDownloadComplete = downloadComplete + needsRedownloadComplete;
              final totalDownloadFailed = downloadSyncFailed + downloadFailed;

              final trackCount = countSnapshot.data?["track"] ?? 0;
              final imageCount = countSnapshot.data?["image"] ?? 0;
              final nodesSyncing = countSnapshot.data?["sync"] ?? 0;

              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  spacing: 16,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 24,
                      children: [
                        _DownloadHeader(
                          totalDownloadCount: totalDownloadCount,
                          trackCount: trackCount,
                          imageCount: imageCount,
                        ),
                        _DownloadAndSyncProgressIndicator(
                          downloadsService: downloadsService,
                          nodesSyncing: nodesSyncing,
                          downloads: downloading,
                          downloadEnqueued: downloadEnqueued,
                        ),
                      ],
                    ),
                    _DownloadInfoSection(
                      totalDownloadComplete: totalDownloadComplete,
                      downloading: downloading,
                      downloadEnqueued: downloadEnqueued,
                      totalDownloadFailed: totalDownloadFailed,
                    ),
                    if (downloadsService.serverMissingBlurhash)
                      Text(
                        AppLocalizations.of(context)!.missingBlurhashWarning,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                  ],
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

class _DownloadInfoSection extends StatelessWidget {
  const _DownloadInfoSection({
    super.key,
    required this.totalDownloadComplete,
    required this.downloading,
    required this.downloadEnqueued,
    required this.totalDownloadFailed,
  });

  final int totalDownloadComplete;
  final int downloading;
  final int downloadEnqueued;
  final int totalDownloadFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _DownloadInfoChip(
          icon: Icons.check,
          amount: totalDownloadComplete,
          label: l10n.downloadChipCompleted(totalDownloadComplete),
          themeColor: Theme.of(context).colorScheme.primary,
        ),
        _DownloadInfoChip(
          icon: Icons.download,
          amount: downloading,
          label: l10n.downloadChipDownloading(downloading),
          themeColor: Theme.of(context).colorScheme.secondary,
        ),
        _DownloadInfoChip(
          icon: Icons.menu,
          amount: downloadEnqueued,
          label: l10n.downloadChipEnqueued(downloadEnqueued),
          themeColor: Theme.of(context).colorScheme.tertiary,
        ),
        _DownloadInfoChip(
          icon: Icons.error,
          amount: totalDownloadFailed,
          label: l10n.downloadChipFailed(totalDownloadFailed),
          themeColor: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}

class _DownloadHeader extends StatelessWidget {
  const _DownloadHeader({
    super.key,
    required this.totalDownloadCount,
    required this.trackCount,
    required this.imageCount,
  });

  final int totalDownloadCount;
  final int trackCount;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 8,
          children: [
            Text('$totalDownloadCount', style: TextStyle(fontSize: 56)),
            Icon(Icons.downloading, size: 48),
          ],
        ),

        Text(AppLocalizations.of(context)!.downloadedTracksAndImageCount(trackCount, imageCount)),
      ],
    );
  }
}

enum DownloadAndSyncState { presync, syncing, downloading, complete }

class _DownloadAndSyncProgressIndicator extends ConsumerStatefulWidget {
  const _DownloadAndSyncProgressIndicator({
    super.key,
    required this.nodesSyncing,
    required this.downloadEnqueued,
    required this.downloads,
    required this.downloadsService,
  });

  final int nodesSyncing;
  final int downloadEnqueued;
  final int downloads;
  final DownloadsService downloadsService;

  @override
  ConsumerState<_DownloadAndSyncProgressIndicator> createState() => _DownloadAndSyncProgressIndicatorState();
}

class _DownloadAndSyncProgressIndicatorState extends ConsumerState<_DownloadAndSyncProgressIndicator> {
  // Size of the current batch, captured once and held until the queue drains.
  int _batchTotal = 0;

  @override
  Widget build(BuildContext context) {
    final allDownloadsProgress = ref.watch(widget.downloadsService.allProgressProvider);
    final isSyncing = widget.downloadsService.syncBuffer.isRunning;
    final isDownloading = allDownloadsProgress.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

    final DownloadAndSyncState state;
    if (isSyncing) {
      state = widget.nodesSyncing == 0 ? DownloadAndSyncState.presync : DownloadAndSyncState.syncing;
    } else if (isDownloading) {
      state = DownloadAndSyncState.downloading;
    } else {
      state = DownloadAndSyncState.complete;
    }

    final remaining = widget.downloads + widget.downloadEnqueued;

    if (remaining > _batchTotal) {
      _batchTotal = remaining;
    }

    final completed = _batchTotal - remaining;
    final double progress = _batchTotal > 0 ? (completed / _batchTotal) : 1.0;
    final progressAsPercent = progress * 100;

    final statusText = switch (state) {
      DownloadAndSyncState.presync => l10n.downloadSyncStatusPresync,
      DownloadAndSyncState.syncing => l10n.downloadSyncStatusSyncing(widget.nodesSyncing),
      DownloadAndSyncState.downloading => l10n.downloadSyncStatusDownloading(progressAsPercent.toStringAsFixed(1)),
      DownloadAndSyncState.complete => l10n.downloadSyncStatusComplete,
    };

    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              SizedBox.square(
                dimension: 48,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, animatedValue, child) {
                    return CircularProgressIndicator(
                      strokeWidth: 8,
                      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                      strokeCap: StrokeCap.round,
                      value: switch (state) {
                        DownloadAndSyncState.downloading => animatedValue,
                        DownloadAndSyncState.complete => 1.0,
                        DownloadAndSyncState.presync => null,
                        DownloadAndSyncState.syncing => null,
                      },
                    );
                  },
                ),
              ),
              Text(statusText),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadInfoChip extends StatelessWidget {
  const _DownloadInfoChip({
    required this.amount,
    required this.label,
    required this.icon,
    required this.themeColor,
    super.key,
  });

  final int amount;
  final String label;
  final IconData icon;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    final hasAmount = amount > 0;

    return Chip(
      avatar: Icon(icon, color: themeColor),
      label: Text(label),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.circular(12),
        side: BorderSide(
          color: hasAmount ? themeColor : Theme.of(context).colorScheme.outline,
          width: hasAmount ? 2 : 1,
        ),
      ),
    );
  }
}
