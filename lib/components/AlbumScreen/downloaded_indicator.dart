import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../global_snackbar.dart';

class DownloadedIndicator extends ConsumerWidget {
  const DownloadedIndicator({super.key, required this.item, this.size});

  final DownloadStub item;
  final double? size;

  bool isVisible(WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();
    return ref.watch(
      downloadsService
          .stateProvider(item)
          .select(
            (status) => switch (status) {
              AsyncData(:final value) => switch (value) {
                null || DownloadItemState.notDownloaded => false,
                _ => true,
              },
              _ => false,
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsService = GetIt.instance<DownloadsService>();
    AsyncValue<DownloadItemState?> status = ref.watch(downloadsService.stateProvider(item));
    if (status.hasValue) {
      switch (status.valueOrNull) {
        case null:
        case DownloadItemState.notDownloaded:
          return const SizedBox.shrink();
        case DownloadItemState.enqueued:
        case DownloadItemState.downloading:
        case DownloadItemState.needsRedownload:
          return Icon(
            TablerIcons.cloud_download,
            color: Theme.of(context).textTheme.bodyMedium!.color?.withValues(alpha: 0.75),
            size: size,
          );
        case DownloadItemState.failed:
        case DownloadItemState.syncFailed:
          return Icon(TablerIcons.download_off, color: Colors.red, size: size);
        case DownloadItemState.complete:
        case DownloadItemState.needsRedownloadComplete:
          return Icon(TablerIcons.device_sd_card, size: size);
      }
    } else if (status.hasError) {
      GlobalSnackbar.error(status.error);
      return const SizedBox.shrink();
    } else {
      return const SizedBox.shrink();
    }
  }
}
