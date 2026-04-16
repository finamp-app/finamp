import 'dart:io';

import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/finamp_user_helper.dart';

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
          // TODO add config edit screen.
          const DefaultTranscodeConfigDropdownListTile(),
          const CellularTranscodeConfigDropdownListTile(),
          const RemoteTranscodeConfigDropdownListTile(),
          // TODO add flac and incompatible settings once available
          Divider(),
          const TranscodeSwitch(),
          const ForcedTranscodeConfigDropdownListTile(),
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

class TranscodeSwitch extends ConsumerWidget {
  const TranscodeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.enableTranscoding),
      // TODO update text
      subtitle: Text(AppLocalizations.of(context)!.enableTranscodingSubtitle),
      value: ref.watch(finampSettingsProvider.forceTranscode),
      onChanged: FinampSetters.setForceTranscode,
    );
  }
}

class ForcedTranscodeConfigDropdownListTile extends ConsumerWidget {
  const ForcedTranscodeConfigDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO is it better if this forcibly overrides automatic mode, or just joins the automatic bitrate resolution?
    return ListTile(
      title: Text(AppLocalizations.of(context)!.forcedTranscodeConfigTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.forcedTranscodeConfigSubtitle),
          FinampSettingsDropdown<String>(
            dropdownItems: ref.watch(transcodeConfigDropdownProvider(AppLocalizations.of(context)!)),
            selectedValue: ref.watch(finampSettingsProvider.forcedTranscodeConfig),
            onSelected: FinampSetters.setForcedTranscodeConfig.ifNonNull,
          ),
        ],
      ),
    );
  }
}

class DefaultTranscodeConfigDropdownListTile extends ConsumerWidget {
  const DefaultTranscodeConfigDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.defaultTranscodeConfigTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.defaultTranscodeConfigSubtitle),
          FinampSettingsDropdown<String>(
            dropdownItems: ref.watch(transcodeConfigDropdownProvider(AppLocalizations.of(context)!)),
            selectedValue: ref.watch(finampSettingsProvider.defaultTranscodeConfig),
            onSelected: FinampSetters.setDefaultTranscodeConfig.ifNonNull,
          ),
        ],
      ),
    );
  }
}

class CellularTranscodeConfigDropdownListTile extends ConsumerWidget {
  const CellularTranscodeConfigDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.cellularTranscodeConfigTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.cellularTranscodeConfigSubtitle),
          FinampSettingsDropdown<String>(
            dropdownItems: ref.watch(transcodeConfigDropdownProvider(AppLocalizations.of(context)!)),
            selectedValue: ref.watch(finampSettingsProvider.cellularTranscodeConfig),
            onSelected: FinampSetters.setCellularTranscodeConfig.ifNonNull,
          ),
        ],
      ),
    );
  }
}

class RemoteTranscodeConfigDropdownListTile extends ConsumerWidget {
  const RemoteTranscodeConfigDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(FinampUserHelper.finampCurrentUserProvider).valueOrNull;
    bool enabled = user != null && user.preferLocalNetwork;

    return ListTile(
      title: Text(AppLocalizations.of(context)!.remoteTranscodeConfigTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enabled
                ? AppLocalizations.of(context)!.remoteTranscodeConfigSubtitle
                : AppLocalizations.of(context)!.remoteTranscodeConfigDisabledSubtitle,
          ),
          FinampSettingsDropdown<String>(
            enabled: enabled,
            dropdownItems: ref.watch(transcodeConfigDropdownProvider(AppLocalizations.of(context)!)),
            selectedValue: ref.watch(finampSettingsProvider.remoteTranscodeConfig),
            onSelected: FinampSetters.setRemoteTranscodeConfig.ifNonNull,
          ),
        ],
      ),
    );
  }
}

final transcodeConfigDropdownProvider = Provider.autoDispose.family((Ref ref, AppLocalizations localizations) {
  // Joining the IDs is the easiest way to get something with deep equality
  final configIds = ref.watch(
    finampSettingsProvider.select((x) => x.requireValue.streamingTranscodeConfigs.keys.join("|")),
  );
  return configIds
      .split("|")
      .map((e) {
        final config = ref.watch(finampSettingsProvider.streamingTranscodeConfigs(e))!;
        final name = config.localizeName(localizations);
        // TODO localize
        final format = "${config.format.codec}+${config.format.container}".toUpperCase();
        var bitrate = "";
        if (!config.format.lossless) {
          bitrate = " ${((config.bitrate ?? -1) / 1000).round()}kbps";
        }
        var details = "";
        if (config.format != FinampTranscodingStreamingFormat.original) {
          details = " ($format $bitrate)";
        }
        return DropdownMenuEntry(
          value: e,
          // TODO allow format localization?
          label: "$name$details",
        );
      })
      // Outputs will never be considered equal
      .toList();
});
