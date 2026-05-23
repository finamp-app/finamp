import 'dart:io';

import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/TranscodingSettingsScreen/bitrate_selector.dart';
import 'package:finamp/components/TranscodingSettingsScreen/transcode_switch.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TranscodingSettingsScreen extends StatefulWidget {
  const TranscodingSettingsScreen({super.key});
  static const routeName = "/settings/transcoding";
  @override
  State<TranscodingSettingsScreen> createState() => _TranscodingSettingsScreenState();
}

class _TranscodingSettingsScreenState extends State<TranscodingSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.transcoding),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
            context,
            FinampSettingsHelper.resetTranscodingSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          const TranscodeSwitch(),
          const StreamingTranscodingFormatDropdownListTile(),
          const BitrateSelector(),
          Divider(),
          const DownloadTranscodeEnableDropdownListTile(),
          const DownloadTranscodeCodecDropdownListTile(),
          const DownloadBitrateSelector(),
          Divider(),
          const MultichannelHandlingSelector(),
        ],
      ),
    );
  }
}

class DownloadBitrateSelector extends ConsumerWidget {
  const DownloadBitrateSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcodeProfile = ref.watch(finampSettingsProvider.downloadTranscodingProfile);
    return Column(
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.downloadBitrate),
          subtitle: Text(AppLocalizations.of(context)!.downloadBitrateSubtitle),
        ),
        // We do all of this division/multiplication because Jellyfin wants us to specify bitrates in bits, not kilobits.
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              min: 64,
              max: 320,
              value: (transcodeProfile.stereoBitrate / 1000).clamp(64, 320),
              divisions: 8,
              label: transcodeProfile.bitrateKbps,
              onChanged: (value) => FinampSetters.setDownloadTranscodeBitrate((value * 1000).toInt()),
              autofocus: false,
              focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
            ),
            Text(transcodeProfile.bitrateKbps, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ],
    );
  }
}

class DownloadTranscodeEnableDropdownListTile extends ConsumerWidget {
  const DownloadTranscodeEnableDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.downloadTranscodeEnableTitle),
      subtitle: FinampSettingsDropdown<TranscodeDownloadsSetting>(
        dropdownItems: TranscodeDownloadsSetting.values
            .map(
              (e) => DropdownMenuEntry<TranscodeDownloadsSetting>(
                value: e,
                label: AppLocalizations.of(context)!.downloadTranscodeEnableOption(e.name),
              ),
            )
            .toList(),
        selectedValue: ref.watch(finampSettingsProvider.shouldTranscodeDownloads),
        onSelected: FinampSetters.setShouldTranscodeDownloads.ifNonNull,
      ),
    );
  }
}

class DownloadTranscodeCodecDropdownListTile extends ConsumerWidget {
  const DownloadTranscodeCodecDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.downloadTranscodeCodecTitle),
      subtitle: FinampSettingsDropdown<FinampTranscodingCodec>(
        dropdownItems: FinampTranscodingCodec.values
            .where((element) => !Platform.isIOS || element.iosCompatible)
            .where((element) => element != FinampTranscodingCodec.original)
            .map((e) => DropdownMenuEntry<FinampTranscodingCodec>(value: e, label: e.name.toUpperCase()))
            .toList(),
        selectedValue: ref.watch(finampSettingsProvider.downloadTranscodingProfile).codec,
        onSelected: FinampSetters.setDownloadTranscodingCodec.ifNonNull,
      ),
    );
  }
}

class StreamingTranscodingFormatDropdownListTile extends ConsumerWidget {
  const StreamingTranscodingFormatDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.transcodingStreamingFormatTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.transcodingStreamingFormatSubtitle),
          FinampSettingsDropdown<FinampTranscodingStreamingFormat>(
            dropdownItems: FinampTranscodingStreamingFormat.values
                .map(
                  (e) => DropdownMenuEntry<FinampTranscodingStreamingFormat>(
                    value: e,
                    label: "${e.codec}+${e.container}".toUpperCase(),
                  ),
                )
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.transcodingStreamingFormat),
            onSelected: FinampSetters.setTranscodingStreamingFormat.ifNonNull,
          ),
        ],
      ),
    );
  }
}

class MultichannelHandlingSelector extends ConsumerWidget {
  const MultichannelHandlingSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.multichannelHandlingTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.multichannelHandlingSubtitle),
          FinampSettingsDropdown<MultichannelHandlingSetting>(
            dropdownItems: MultichannelHandlingSetting.values
                .map(
                  (e) => DropdownMenuEntry<MultichannelHandlingSetting>(
                    value: e,
                    label: AppLocalizations.of(context)!.multichannelHandlingOption(e.name),
                  ),
                )
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.multichannelHandlingSetting),
            onSelected: FinampSetters.setMultichannelHandlingSetting.ifNonNull,
          ),
        ],
      ),
    );
  }
}
