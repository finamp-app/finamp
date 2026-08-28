import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finamp/components/AudioServiceSettingsScreen/buffer_duration_list_tile.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/AudioServiceSettingsScreen/loadQueueOnStartup_selector.dart';
import 'package:finamp/components/AudioServiceSettingsScreen/stop_foreground_selector.dart';
import 'package:finamp/components/AudioServiceSettingsScreen/track_shuffle_item_count_editor.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';

class AudioServiceSettingsScreen extends StatefulWidget {
  const AudioServiceSettingsScreen({super.key});
  static const routeName = "/settings/audioservice";
  @override
  State<AudioServiceSettingsScreen> createState() => _AudioServiceSettingsScreenState();
}

class _AudioServiceSettingsScreenState extends State<AudioServiceSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.audioService),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, () {
            setState(() {
              FinampSettingsHelper.resetAudioServiceSettings();
            });
          }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          if (Platform.isAndroid) const StopForegroundSelector(),
          if (Platform.isAndroid) const EnableDuckingOnInterruptionsToggle(),
          if (Platform.isAndroid) const ForceAudioOffloadingOnAndroidToggle(),
          const TrackShuffleItemCountEditor(),
          const AudioFadeInDurationListTile(),
          const AudioFadeOutDurationListTile(),
          if (Platform.isAndroid) const BufferSizeListTile(),
          const BufferDurationListTile(),
          const BufferDisableSizeConstraintsSelector(),
          const LoadQueueOnStartupSelector(),
          const AutoplayRestoredQueueToggle(),
          const AutoReloadQueueToggle(),
          const ClearQueueOnStopToggle(),
        ],
      ),
    );
  }
}

class BufferDisableSizeConstraintsSelector extends ConsumerWidget {
  const BufferDisableSizeConstraintsSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.bufferDisableSizeConstraintsTitle),
      subtitle: Text(AppLocalizations.of(context)!.bufferDisableSizeConstraintsSubtitle),
      value: ref.watch(finampSettingsProvider.bufferDisableSizeConstraints),
      onChanged: FinampSetters.setBufferDisableSizeConstraints,
    );
  }
}

class BufferSizeListTile extends ConsumerStatefulWidget {
  const BufferSizeListTile({super.key});

  @override
  ConsumerState<BufferSizeListTile> createState() => _BufferSizeListTileState();
}

class _BufferSizeListTileState extends ConsumerState<BufferSizeListTile> {
  final _controller = TextEditingController();

  @override
  void initState() {
    ref.listenManual(finampSettingsProvider.bufferSizeMegabytes, (_, value) {
      var newText = value.toString();
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }, fireImmediately: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.bufferSizeTitle),
      subtitle: Text(AppLocalizations.of(context)!.bufferSizeSubtitle),
      trailing: SizedBox(
        width: 50 * MediaQuery.textScaleFactorOf(context),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            var valueInt = int.tryParse(value);

            if (valueInt != null && !valueInt.isNegative) {
              // minimum buffer size is 60, if we go below that, the player will crash
              if (valueInt < 60) {
                _controller.text = "60";
                valueInt = 60;
              }
              FinampSetters.setBufferSizeMegabytes(valueInt);
            }
          },
        ),
      ),
    );
  }
}

class AudioFadeInDurationListTile extends ConsumerStatefulWidget {
  const AudioFadeInDurationListTile({super.key});

  @override
  ConsumerState<AudioFadeInDurationListTile> createState() => _AudioFadeInDurationListTileState();
}

class _AudioFadeInDurationListTileState extends ConsumerState<AudioFadeInDurationListTile> {
  final _controller = TextEditingController();

  @override
  void initState() {
    ref.listenManual(finampSettingsProvider.audioFadeInDuration, (_, value) {
      var newText = value.inMilliseconds.toString();
      if (_controller.text != newText) _controller.text = newText;
    }, fireImmediately: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.audioFadeInDurationSettingTitle),
      subtitle: Text(AppLocalizations.of(context)!.audioFadeInDurationSettingSubtitle),
      trailing: SizedBox(
        width: 50 * MediaQuery.textScaleFactorOf(context),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final valueInt = int.tryParse(value);

            if (valueInt != null && !valueInt.isNegative) {
              FinampSetters.setAudioFadeInDuration(Duration(milliseconds: valueInt));
            }
          },
        ),
      ),
    );
  }
}

class AudioFadeOutDurationListTile extends ConsumerStatefulWidget {
  const AudioFadeOutDurationListTile({super.key});

  @override
  ConsumerState<AudioFadeOutDurationListTile> createState() => _AudioFadeOutDurationListTileState();
}

class _AudioFadeOutDurationListTileState extends ConsumerState<AudioFadeOutDurationListTile> {
  final _controller = TextEditingController();

  @override
  void initState() {
    ref.listenManual(finampSettingsProvider.audioFadeOutDuration, (_, value) {
      var newText = value.inMilliseconds.toString();
      if (_controller.text != newText) _controller.text = newText;
    }, fireImmediately: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.audioFadeOutDurationSettingTitle),
      subtitle: Text(AppLocalizations.of(context)!.audioFadeOutDurationSettingSubtitle),
      trailing: SizedBox(
        width: 50 * MediaQuery.textScaleFactorOf(context),
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final valueInt = int.tryParse(value);

            if (valueInt != null && !valueInt.isNegative) {
              FinampSetters.setAudioFadeOutDuration(Duration(milliseconds: valueInt));
            }
          },
        ),
      ),
    );
  }
}

class AutoReloadQueueToggle extends ConsumerWidget {
  const AutoReloadQueueToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.autoReloadQueueTitle),
      subtitle: Text(AppLocalizations.of(context)!.autoReloadQueueSubtitle),
      value: ref.watch(finampSettingsProvider.autoReloadQueue),
      onChanged: FinampSetters.setAutoReloadQueue,
    );
  }
}

class AutoplayRestoredQueueToggle extends ConsumerWidget {
  const AutoplayRestoredQueueToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.autoplayRestoredQueueTitle),
      subtitle: Text(AppLocalizations.of(context)!.autoplayRestoredQueueSubtitle),
      value: ref.watch(finampSettingsProvider.autoplayRestoredQueue),
      onChanged: FinampSetters.setAutoplayRestoredQueue,
    );
  }
}

class ClearQueueOnStopToggle extends ConsumerWidget {
  const ClearQueueOnStopToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.clearQueueOnStopEventTitle),
      subtitle: Text(AppLocalizations.of(context)!.clearQueueOnStopEventSubtitle),
      value: ref.watch(finampSettingsProvider.clearQueueOnStopEvent),
      onChanged: FinampSetters.setClearQueueOnStopEvent,
    );
  }
}

class EnableDuckingOnInterruptionsToggle extends ConsumerWidget {
  const EnableDuckingOnInterruptionsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.duckOnAudioInterruptionTitle),
      subtitle: Text(AppLocalizations.of(context)!.duckOnAudioInterruptionSubtitle),
      value: ref.watch(finampSettingsProvider.duckOnAudioInterruption),
      onChanged: (newValue) async {
        FinampSetters.setDuckOnAudioInterruption(newValue);
        await MusicPlayerBackgroundTask.configureAudioSession();
      },
    );
  }
}

class ForceAudioOffloadingOnAndroidToggle extends ConsumerWidget {
  const ForceAudioOffloadingOnAndroidToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.forceAudioOffloadingOnAndroidTitle),
      subtitle: Text(AppLocalizations.of(context)!.forceAudioOffloadingOnAndroidSubtitle),
      value: ref.watch(finampSettingsProvider.forceAudioOffloadingOnAndroid),
      onChanged: (newValue) async {
        FinampSetters.setForceAudioOffloadingOnAndroid(newValue);
      },
    );
  }
}
