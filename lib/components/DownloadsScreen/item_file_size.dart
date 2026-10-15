import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';

class ItemFileSize extends ConsumerWidget {
  const ItemFileSize({super.key, required this.stub});

  final DownloadStub stub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textFunction = ref.watch(downloadSizeTextProvider(stub)).value;
    final text = textFunction == null ? "" : textFunction(context);
    if (text.startsWith("!!!")) {
      return Text(text.substring(3), style: TextStyle(color: Colors.red));
    } else {
      return Text(text);
    }
  }
}

final downloadSizeTextProvider = FutureProvider.autoDispose.family((Ref ref, DownloadStub stub) async {
  final downloadsService = GetIt.instance<DownloadsService>();

  final item = await ref.watch(downloadsService.itemProvider(stub).future);

  switch (item?.state) {
    case DownloadItemState.notDownloaded:
      if (downloadsService.getStatus(item!, null) == DownloadItemStatus.notNeeded) {
        return (BuildContext context) => AppLocalizations.of(context)!.missingDownloadSize;
      } else {
        return (BuildContext context) => AppLocalizations.of(context)!.syncingDownloadSize;
      }
    case DownloadItemState.syncFailed:
      return (BuildContext context) => "!!!${AppLocalizations.of(context)!.syncingFailed}";
    case DownloadItemState.failed:
    case DownloadItemState.complete:
    case DownloadItemState.needsRedownloadComplete:
      if (item!.type == DownloadItemType.track) {
        String codec = "";
        String bitrate = "null";
        if (item.fileTranscodingProfile == null ||
            item.fileTranscodingProfile?.codec == FinampTranscodingCodec.original) {
          codec = item.baseItem?.mediaSources?[0].container ?? "";
        } else {
          codec = item.fileTranscodingProfile?.codec.name ?? "";
          bitrate = item.fileTranscodingProfile?.bitrateKbps ?? "null";
        }
        final fileSize = await downloadsService.getFileSize(item);
        // only show name if there is more than one location
        final locationName = FinampSettingsHelper.finampSettings.downloadLocationsMap.length > 1
            ? FinampSettingsHelper.finampSettings.downloadLocationsMap[item.fileDownloadLocation?.id]?.name
            : null;
        return (BuildContext context) =>
            AppLocalizations.of(context)!
                .downloadInfo(bitrate, codec.toUpperCase(), FileSize.getSize(fileSize), locationName ?? "null");
      } else {
        var profile = item.userTranscodingProfile ?? item.syncTranscodingProfile;
        //Suppress codec display on downloads without audio files
        if (!(item.finampCollection?.type.hasAudio ?? true)) {
          profile = null;
        }
        final codec = profile?.codec.name ?? FinampTranscodingCodec.original.name;
        final fileSize = await downloadsService.getFileSize(item);
        // only show name if there is more than one location
        final locationName = FinampSettingsHelper.finampSettings.downloadLocationsMap.length > 1
            ? FinampSettingsHelper.finampSettings.downloadLocationsMap[item.syncDownloadLocation?.id]?.name
            : null;
        return (BuildContext context) => AppLocalizations.of(context)!.collectionDownloadInfo(
          profile?.bitrateKbps ?? "null",
          codec.toUpperCase(),
          FileSize.getSize(fileSize),

          locationName ?? "null",
        );
      }
    case DownloadItemState.downloading:
    case DownloadItemState.enqueued:
    case DownloadItemState.needsRedownload:
      return (BuildContext context) => AppLocalizations.of(context)!.activeDownloadSize;
    case null:
      return (BuildContext context) => AppLocalizations.of(context)!.missingDownloadSize;
  }
});
