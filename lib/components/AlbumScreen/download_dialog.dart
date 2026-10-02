import 'dart:async';
import 'dart:math';

import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/color_schemes.g.dart';
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
      await showDialog(
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
  bool transcode = false;

  @override
  Widget build(BuildContext context) {
    assert(widget.children?.every((child) => BaseItemDtoType.fromItem(child) == BaseItemDtoType.track) ?? true);

    final l10n = AppLocalizations.of(context);

    const double kDialogMaxWidth = 720;
    final double dialogWidth = min(kDialogMaxWidth, MediaQuery.sizeOf(context).width * 0.9);

    // original file
    final originalProfile = DownloadProfile(transcodeCodec: FinampTranscodingCodec.original);
    final originalFileSize = widget.children?.map((e) => e.mediaSources?.first.size ?? 0).fold(0, (a, b) => a + b) ?? 0;
    final originalFileSizeFormatted = FileSize.getSize(originalFileSize, precision: PrecisionValue.None);

    final downloadFormats = widget.children!.map((e) => e.mediaSources?.first.mediaStreams.first.codec).toSet();
    final formatLabels = downloadFormats.whereType<String>().map((f) => f.toUpperCase()).toList()..sort();
    final formatsAsString = formatLabels.join(', ');

    // transcode
    final transcodeProfile = FinampSettingsHelper.finampSettings.downloadTranscodingProfile;
    final transcodedFileFormat = transcodeProfile.codec.name.toUpperCase();
    final transcodedFileSize =
        widget.children
            ?.map(
              (e) => e.mediaSources?.first.transcodedSize(
                FinampSettingsHelper.finampSettings.downloadTranscodingProfile.bitrateChannels,
              ),
            )
            .fold(0, (a, b) => a + (b ?? 0)) ??
        0;
    final transcodedFileSizeFormatted = FileSize.getSize(transcodedFileSize, precision: PrecisionValue.None);

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

    final preferredDownloadLocation = getFirstSelectedLocation();

    return AlertDialog(
      constraints: BoxConstraints(minWidth: dialogWidth),
      title: Text(AppLocalizations.of(context)!.addDownloads),
      content: Column(
        spacing: 16,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [Text(l10n!.downloadDialogFileSizeLabel), Text(originalFileSizeFormatted)],
          ),

          // Only show if there are multiple download locations
          // if (userSelectableDownloadLocations.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                DropdownMenu(
                  label: Text(l10n.downloadDialogDownloadLocationLabel),
                  initialSelection: preferredDownloadLocation,
                  onSelected: (value) => setState(() {
                    selectedDownloadLocation = value;
                  }),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: userSelectableDownloadLocations
                      .map(
                        (downloadLocation) =>
                            DropdownMenuEntry<DownloadLocation>(value: downloadLocation, label: downloadLocation.name),
                      )
                      .toList(),
                ),
                Text(l10n.downloadDialogPath(preferredDownloadLocation?.currentPath ?? '')),
              ],
            ),
          ),

          if (widget.needsTranscode)
            CheckboxListTile(
              title: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(l10n.downloadDialogTranscodeFilesTitle),
              ),
              value: transcode,
              visualDensity: VisualDensity.compact,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  if (transcode) ...[
                    _TranscodeLineItem(
                      label: l10n.downloadDialogFileSizeLabel,
                      originalValue: originalFileSizeFormatted,
                      transcodeValueCondition: (transcode && originalFileSize != transcodedFileSize),
                      transcodeValue: '~$transcodedFileSizeFormatted',
                    ),
                    _TranscodeLineItem(
                      label: l10n.downloadDialogFormatLabel,
                      originalValue: formatsAsString,
                      transcodeValueCondition: (transcode && formatsAsString != transcodedFileFormat),
                      transcodeValue: transcodedFileFormat,
                    ),
                    _TranscodeLineItem(
                      label: l10n.downloadDialogBitrateLabel,
                      originalValue: originalProfile.bitrateKbps,
                      transcodeValueCondition:
                          (transcode && originalProfile.bitrateKbps != transcodeProfile.bitrateKbps),
                      transcodeValue: transcodeProfile.bitrateKbps,
                    ),
                  ],
                ],
              ),
              onChanged: (value) => setState(() {
                transcode = value ?? false;
              }),
              contentPadding: EdgeInsets.zero,
            ),

          if ((widget.trackCount ?? 0) >= FinampSettingsHelper.finampSettings.downloadSizeWarningCutoff)
            Center(
              child: Text(
                AppLocalizations.of(context)!.largeDownloadWarning(widget.trackCount!),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Theme.of(context).colorScheme.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: (selectedDownloadLocation == null && widget.downloadLocationId == null)
              ? null
              : () async {
                  Navigator.of(context).pop();
                  final downloadsService = GetIt.instance<DownloadsService>();
                  var profile =
                      (widget.needsTranscode
                          ? transcode
                          : FinampSettingsHelper.finampSettings.shouldTranscodeDownloads ==
                                TranscodeDownloadsSetting.always)
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

class _TranscodeLineItem extends StatelessWidget {
  const _TranscodeLineItem({
    super.key,
    required this.label,
    required this.originalValue,
    required this.transcodeValueCondition,
    required this.transcodeValue,
  });

  final String label;
  final String originalValue;
  final bool transcodeValueCondition;
  final String transcodeValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Wrap(
          spacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(originalValue),
            if (transcodeValueCondition) ...[_TranscodeIcon(), Text(transcodeValue)],
          ],
        ),
      ],
    );
  }
}

class _TranscodeIcon extends StatelessWidget {
  const _TranscodeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.downloadDialogTranscodedIntoSemanticLabel,
      child: Icon(Icons.arrow_right),
    );
  }
}
