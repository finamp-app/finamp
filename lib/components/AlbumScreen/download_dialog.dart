import 'dart:async';

import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/finamp_user_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../global_snackbar.dart';

class DownloadDialog extends ConsumerStatefulWidget {
  const DownloadDialog._build({
    required this.item,
    required this.viewId,
    required this.downloadLocationId,
    required this.needsTranscode,
    required this.children,
    required this.trackCount,
  });

  final DownloadStub item;
  final BaseItemId viewId;
  final String? downloadLocationId;
  final bool needsTranscode;
  final List<BaseItemDto>? children;
  final int? trackCount;

  @override
  ConsumerState<DownloadDialog> createState() => _DownloadDialogState();

  /// Shows a download dialog box to the user.  A download location dropdown will be shown
  /// if there is more than one location.  A transcode setting dropdown will be shown
  /// if transcode downloads is set to ask.  If neither is needed, the
  /// download is initiated immediately with no dialog.
  static Future<void> show(BuildContext context, DownloadStub item, BaseItemId? viewId, {int? trackCount}) async {
    if (viewId == null) {
      final finampUserHelper = GetIt.instance<FinampUserHelper>();
      viewId = finampUserHelper.currentUser!.currentViewId;
    }
    bool needTranscode =
        FinampSettingsHelper.finampSettings.shouldTranscodeDownloads == TranscodeDownloadsSetting.ask &&
        (item.finampCollection?.type.hasAudio ?? true);
    String? downloadLocation = FinampSettingsHelper.finampSettings.defaultDownloadLocation;
    if (!FinampSettingsHelper.finampSettings.downloadLocationsMap.containsKey(downloadLocation)) {
      downloadLocation = null;
    }
    if (downloadLocation == null) {
      var locations = FinampSettingsHelper.finampSettings.downloadLocationsMap.values.where(
        (element) => element.baseDirectory != DownloadLocationType.internalDocuments,
      );
      if (locations.length == 1) {
        downloadLocation = locations.first.id;
      }
    }

    // If transcoding an album or playlist, fetch children for size calculation.
    // If trackCount was not supplied, fetch children to calculate for all types
    // where this can be determined in one query.
    JellyfinApiHelper jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    List<BaseItemDto>? children;
    if ((item.baseItemType == BaseItemDtoType.album || item.baseItemType == BaseItemDtoType.playlist) &&
        (needTranscode || trackCount == null)) {
      children = await jellyfinApiHelper.getItems(
        parentItem: item.baseItem!,
        includeItemTypes: BaseItemDtoType.track.jellyfinName,
        fields: "${jellyfinApiHelper.defaultFields},MediaSources,MediaStreams",
      );
      trackCount = children?.length;
    } else if ((item.baseItemType == BaseItemDtoType.artist || item.baseItemType == BaseItemDtoType.genre) &&
        trackCount == null) {
      // Only track children are expected by dialog, so do not save album children.
      List<BaseItemDto>? artistChildren = await jellyfinApiHelper.getItems(
        parentItem: item.baseItem!,
        includeItemTypes: BaseItemDtoType.album.jellyfinName,
      );
      trackCount = artistChildren?.fold<int>(0, (count, item) => count + (item.childCount ?? 0));
    } else if (item.baseItemType == BaseItemDtoType.track) {
      children = [await jellyfinApiHelper.getItemById(BaseItemId(item.id))];
      trackCount = 1;
    }

    if (!needTranscode &&
        downloadLocation != null &&
        (trackCount ?? 0) < FinampSettingsHelper.finampSettings.downloadSizeWarningCutoff) {
      final downloadsService = GetIt.instance<DownloadsService>();
      var profile = FinampSettingsHelper.finampSettings.shouldTranscodeDownloads == TranscodeDownloadsSetting.always
          ? FinampSettingsHelper.finampSettings.downloadTranscodingProfile
          : DownloadProfile(transcodeCodec: FinampTranscodingCodec.original);
      profile.downloadLocationId = downloadLocation;

      FinampSetters.setLastUsedDownloadLocationId(profile.downloadLocationId);
      GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.confirmDownloadStarted, isConfirmation: true);
      unawaited(
        downloadsService
            .addDownload(stub: item, viewId: viewId!, transcodeProfile: profile)
            // TODO only show the enqueued confirmation if the enqueuing took longer than ~10 seconds
            .then((value) => GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.downloadsQueued)),
      );
    } else {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => DownloadDialog._build(
          item: item,
          viewId: viewId!,
          downloadLocationId: downloadLocation,
          needsTranscode: needTranscode,
          children: children,
          trackCount: trackCount,
        ),
      );
    }
  }
}

class _DownloadDialogState extends ConsumerState<DownloadDialog> {
  DownloadLocation? selectedDownloadLocation;
  bool? transcode;

  @override
  Widget build(BuildContext context) {
    assert(widget.children?.every((child) => BaseItemDtoType.fromItem(child) == BaseItemDtoType.track) ?? true);
    String originalDescription = "null";
    String transcodeDescription = "null";
    var transcodeProfile = FinampSettingsHelper.finampSettings.downloadTranscodingProfile;
    var originalProfile = DownloadProfile(transcodeCodec: FinampTranscodingCodec.original);

    if (widget.children != null) {
      final transcodedFileSize = widget.children!
          .map(
            (e) => e.mediaSources?.first.transcodedSize(
              FinampSettingsHelper.finampSettings.downloadTranscodingProfile.bitrateChannels,
            ),
          )
          .fold(0, (a, b) => a + (b ?? 0));

      transcodeDescription = FileSize.getSize(transcodedFileSize, precision: PrecisionValue.None);

      final originalFileSize = widget.children!.map((e) => e.mediaSources?.first.size ?? 0).fold(0, (a, b) => a + b);

      final originalFileSizeFormatted = FileSize.getSize(originalFileSize, precision: PrecisionValue.None);

      originalDescription = originalFileSizeFormatted;

      final formats = widget.children!.map((e) => e.mediaSources?.first.mediaStreams.first.codec).toSet();

      if (formats.length == 1 && formats.first != null) {
        originalDescription += " ${formats.first!.toUpperCase()}";
      }
    }

    DownloadLocation? getFirstSelectedLocation() {
      FinampSettings settings = FinampSettingsHelper.finampSettings;
      selectedDownloadLocation ??=
          settings.downloadLocationsMap[widget.downloadLocationId] ??
          settings.downloadLocationsMap[settings.lastUsedDownloadLocationId] ??
          FinampSettingsHelper.finampSettings.internalTrackDir;

      return selectedDownloadLocation;
    }

    final userSelectableDownloadLocations = FinampSettingsHelper.finampSettings.downloadLocationsMap.values.where(
      (element) => element.baseDirectory != DownloadLocationType.internalDocuments,
    );

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.addDownloads),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show if there are multiple download locations
          if (userSelectableDownloadLocations.length > 1)
            DropdownButton<DownloadLocation>(
              hint: Text(AppLocalizations.of(context)!.location),
              isExpanded: true,
              onChanged: (value) => setState(() {
                selectedDownloadLocation = value;
              }),
              value: getFirstSelectedLocation(),
              items: userSelectableDownloadLocations
                  .map(
                    (downloadLocation) =>
                        DropdownMenuItem<DownloadLocation>(value: downloadLocation, child: Text(downloadLocation.name)),
                  )
                  .toList(),
            ),
          if (widget.needsTranscode)
            DropdownButton<bool>(
              hint: Text(AppLocalizations.of(context)!.transcodeHint),
              isExpanded: true,
              onChanged: (value) => setState(() {
                transcode = value;
              }),
              value: transcode,
              items: [
                DropdownMenuItem<bool>(
                  value: true,
                  child: Text(
                    AppLocalizations.of(context)!.doTranscode(
                      transcodeProfile.bitrateKbps,
                      transcodeProfile.codec.name.toUpperCase(),
                      transcodeDescription,
                    ),
                  ),
                ),
                DropdownMenuItem<bool>(
                  value: false,
                  child: Text(AppLocalizations.of(context)!.dontTranscode(originalDescription)),
                ),
              ],
            ),
          if ((widget.trackCount ?? 0) >= FinampSettingsHelper.finampSettings.downloadSizeWarningCutoff)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
              child: Text(AppLocalizations.of(context)!.largeDownloadWarning(widget.trackCount!)),
            ),
        ],
      ),
      actions: [
        TextButton(
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed:
              (selectedDownloadLocation == null && widget.downloadLocationId == null) ||
                  (transcode == null && widget.needsTranscode)
              ? null
              : () async {
                  Navigator.of(context).pop();
                  final downloadsService = GetIt.instance<DownloadsService>();
                  var profile =
                      (widget.needsTranscode
                          ? transcode
                          : FinampSettingsHelper.finampSettings.shouldTranscodeDownloads ==
                                TranscodeDownloadsSetting.always)!
                      ? transcodeProfile
                      : originalProfile;
                  profile.downloadLocationId = selectedDownloadLocation?.id ?? widget.downloadLocationId;

                  // We've selected to download, so lets set this as the default for next time
                  FinampSetters.setLastUsedDownloadLocationId(profile.downloadLocationId);
                  await downloadsService
                      .addDownload(stub: widget.item, viewId: widget.viewId, transcodeProfile: profile)
                      .onError((error, stackTrace) => GlobalSnackbar.error(error));

                  GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.downloadsQueued);
                },
          child: Text(AppLocalizations.of(context)!.addButtonLabel),
        ),
      ],
    );
  }
}
