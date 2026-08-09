import 'dart:math';

import 'package:finamp/components/AlbumScreen/preset_chip.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/print_duration.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/progress_state_stream.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import '../extensions/localizations.dart';

enum _MenuPage { minutes, tracks, currentTrack }

class SleepTimerMenu extends StatefulWidget {
  const SleepTimerMenu({super.key, required this.iconColor, this.scrollFunction, this.onStartTimer, this.onSizeChange});

  final Color iconColor;
  final void Function()? scrollFunction;
  final void Function()? onStartTimer;
  final void Function(double)? onSizeChange;

  static const double durationTypeMenuHeight = 265;
  static const double tracksTypeMenuHeight = 220;
  static const double afterCurrentTrackTypeMenuHeight = 140;

  @override
  State<SleepTimerMenu> createState() => _SleepTimerMenuState();
}

class _SleepTimerMenuState extends State<SleepTimerMenu> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _trackController = TextEditingController();

  late SleepTimer newSleepTimer;
  late bool finishTrack;

  _MenuPage selectedMode = _MenuPage.minutes;

  @override
  void initState() {
    super.initState();
    var oldTimer = FinampSettingsHelper.finampSettings.sleepTimer;
    newSleepTimer = SleepTimer(
      oldTimer?.secondsLength ?? DefaultSettings.sleepTimerDurationSeconds,
      oldTimer?.tracksLength ?? 0,
    );
    finishTrack = (oldTimer?.tracksLength ?? 0) > 0;
    selectedMode = switch (newSleepTimer) {
      SleepTimer(secondsLength: > 0) => _MenuPage.minutes,
      SleepTimer(tracksLength: 1) => _MenuPage.currentTrack,
      _ => _MenuPage.tracks,
    };
    _updateControllers();
  }

  void _updateControllers() {
    // Update duration controller (in minutes)
    _durationController.text = (newSleepTimer.secondsLength / 60).round().toString();
    // Update track controller
    _trackController.text = newSleepTimer.tracksLength.toString();
  }

  @override
  void dispose() {
    _durationController.dispose();
    _trackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chipLabels = [
      AppLocalizations.of(context)!.minutes,
      AppLocalizations.of(context)!.tracks,
      AppLocalizations.of(context)!.sleepTimerAfterCurrentTrack,
    ];
    final List<double> menuHeights = [
      SleepTimerMenu.durationTypeMenuHeight,
      SleepTimerMenu.tracksTypeMenuHeight,
      SleepTimerMenu.afterCurrentTrackTypeMenuHeight,
    ];

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: widget.iconColor.withOpacity(0.1)),
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Chips row styled like SpeedMenu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_MenuPage.values.length, (int i) {
                  bool active = selectedMode.index == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        textStyle: TextStyle(
                          backgroundColor: Colors.transparent,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        ),
                        foregroundColor: active
                            ? Colors.white
                            : Theme.of(context).textTheme.bodySmall?.color ?? Colors.white,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(active ? 0.6 : 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        minimumSize: Size(42, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      ),
                      onPressed: () {
                        setState(() {
                          selectedMode = _MenuPage.values[i];
                          switch (selectedMode) {
                            case _MenuPage.minutes:
                              newSleepTimer.tracksLength = 0;
                              newSleepTimer.secondsLength = DefaultSettings.sleepTimerDurationSeconds;
                            case _MenuPage.tracks:
                              newSleepTimer.tracksLength = 5; // Default to 5 tracks
                              newSleepTimer.secondsLength = 0;
                            case _MenuPage.currentTrack:
                              newSleepTimer.tracksLength = 1;
                              newSleepTimer.secondsLength = 0;
                          }
                          widget.onSizeChange?.call(menuHeights[i]);
                          _updateControllers();
                        });
                      },
                      child: Text(chipLabels[i]),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            if (selectedMode == _MenuPage.minutes) ...[
              // Duration Preset Chips and Slider with +/- buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: PresetChips(
                  key: ValueKey("minutesChips"),
                  type: PresetTypes.speed, // Reuse for duration
                  mainColour: widget.iconColor,
                  values: [5, 10, 15, 20, 30, 45, 60, 90, 120],
                  activeValue: (newSleepTimer.secondsLength / 60).clamp(1, 999).toDouble(),
                  onPresetSelected: (val) {
                    setState(() {
                      newSleepTimer.secondsLength = (val).round() * 60;
                      _updateControllers();
                    });
                  },
                  chipWidth: 52,
                  chipHeight: 42,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(TablerIcons.minus, color: widget.iconColor),
                      onPressed: () {
                        final current = (newSleepTimer.secondsLength / 60).round();
                        if (current > 1) {
                          setState(() {
                            newSleepTimer.secondsLength = max(1, current - 1) * 60;
                            _updateControllers();
                          });
                        }
                      },
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      padding: EdgeInsets.zero,
                      tooltip: '-',
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 24 / 2.0),
                          trackHeight: 24.0,
                          inactiveTrackColor: widget.iconColor.withOpacity(0.3),
                          activeTrackColor: widget.iconColor.withOpacity(0.6),
                          showValueIndicator: ShowValueIndicator.always,
                          valueIndicatorColor: Color.lerp(Theme.of(context).cardColor, widget.iconColor, 0.6),
                          valueIndicatorTextStyle: Theme.of(context).textTheme.labelLarge,
                          valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
                          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
                          activeTickMarkColor: widget.iconColor.withOpacity(0.9),
                          overlayShape: SliderComponentShape.noOverlay, // get rid of padding
                        ),
                        child: ExcludeSemantics(
                          child: Slider(
                            min: 1,
                            max: 120,
                            divisions: 119,
                            value: (newSleepTimer.secondsLength / 60).clamp(1, 120).toDouble(),
                            onChanged: (val) {
                              setState(() {
                                newSleepTimer.secondsLength = (val).round() * 60;
                                _updateControllers();
                              });
                            },
                            label: context.l10n.timerMinutes((newSleepTimer.secondsLength / 60).round()),
                            autofocus: false,
                            focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(TablerIcons.plus, color: widget.iconColor),
                      onPressed: () {
                        final current = (newSleepTimer.secondsLength / 60).round();
                        if (current < 120) {
                          setState(() {
                            newSleepTimer.secondsLength = min(120, current + 1) * 60;
                            _updateControllers();
                          });
                        }
                      },
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      padding: EdgeInsets.zero,
                      tooltip: AppLocalizations.of(context)!.playbackSpeedIncreaseLabel,
                    ),
                    SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      height: 28,
                      child: Center(
                        child: TextFormField(
                          controller: _durationController,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: widget.iconColor.withOpacity(0.08),
                          ),
                          keyboardType: TextInputType.number,
                          onFieldSubmitted: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= 120) {
                              setState(() {
                                newSleepTimer.secondsLength = parsed * 60;
                                _updateControllers();
                              });
                            }
                          },
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= 120) {
                              setState(() {
                                newSleepTimer.secondsLength = parsed * 60;
                                _updateControllers();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            finishTrack = !finishTrack;
                            newSleepTimer.tracksLength = finishTrack ? 1 : 0;
                          });
                        },
                        child: IntrinsicWidth(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  AppLocalizations.of(context)!.sleepTimerFinishLastTrack,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              Checkbox.adaptive(
                                value: finishTrack,
                                onChanged: (val) {
                                  setState(() {
                                    finishTrack = val ?? false;
                                    newSleepTimer.tracksLength = finishTrack ? 1 : 0;
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (selectedMode == _MenuPage.tracks) ...[
              // Track count Preset Chips and Slider with +/- buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: PresetChips(
                  key: ValueKey("tracksChips"),
                  type: PresetTypes.speed, // Reuse for tracks
                  mainColour: widget.iconColor,
                  values: [1, 2, 3, 5, 10, 15, 20],
                  activeValue: newSleepTimer.tracksLength.toDouble(),
                  onPresetSelected: (val) {
                    setState(() {
                      newSleepTimer.tracksLength = (val).round();
                      _updateControllers();
                    });
                  },
                  chipWidth: 52,
                  chipHeight: 42,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(TablerIcons.minus, color: widget.iconColor),
                      onPressed: () {
                        final current = newSleepTimer.tracksLength;
                        if (current > 1) {
                          setState(() {
                            newSleepTimer.tracksLength = max(1, current - 1);
                            _updateControllers();
                          });
                        }
                      },
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      padding: EdgeInsets.zero,
                      tooltip: AppLocalizations.of(context)!.playbackSpeedDecreaseLabel,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 24 / 2.0),
                          trackHeight: 24.0,
                          inactiveTrackColor: widget.iconColor.withOpacity(0.3),
                          activeTrackColor: widget.iconColor.withOpacity(0.6),
                          showValueIndicator: ShowValueIndicator.always,
                          valueIndicatorColor: Color.lerp(Theme.of(context).cardColor, widget.iconColor, 0.6),
                          valueIndicatorTextStyle: Theme.of(context).textTheme.labelLarge,
                          valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
                          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
                          activeTickMarkColor: widget.iconColor.withOpacity(0.9),
                          overlayShape: SliderComponentShape.noOverlay, // get rid of padding
                        ),
                        child: ExcludeSemantics(
                          child: Slider(
                            min: 0,
                            max: 20,
                            value: newSleepTimer.tracksLength.clamp(0, 20).toDouble(),
                            onChanged: (val) {
                              setState(() {
                                newSleepTimer.tracksLength = val.round();
                                _updateControllers();
                              });
                            },
                            label: context.l10n.timerTracks(newSleepTimer.tracksLength),
                            autofocus: false,
                            focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(TablerIcons.plus, color: widget.iconColor),
                      onPressed: () {
                        final current = newSleepTimer.tracksLength;
                        if (current < 20) {
                          setState(() {
                            newSleepTimer.tracksLength = min(20, current + 1);
                            _updateControllers();
                          });
                        }
                      },
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      padding: EdgeInsets.zero,
                      tooltip: '+',
                    ),
                    SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      height: 28,
                      child: Center(
                        child: TextFormField(
                          controller: _trackController,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: widget.iconColor.withOpacity(0.08),
                          ),
                          keyboardType: TextInputType.number,
                          onFieldSubmitted: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= 20) {
                              setState(() {
                                newSleepTimer.tracksLength = parsed;
                                _updateControllers();
                              });
                            }
                          },
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= 20) {
                              setState(() {
                                newSleepTimer.tracksLength = parsed;
                                _updateControllers();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Projected duration
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: StreamBuilder<(ProgressState?, FinampQueueInfo?)>(
                stream: Rx.combineLatest2<ProgressState, FinampQueueInfo?, (ProgressState?, FinampQueueInfo?)>(
                  progressStateStream,
                  GetIt.instance<QueueService>().getQueueStream(),
                  (a, b) => (a, b),
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final progressState = snapshot.data!.$1!;
                    final queueInfo = snapshot.data!.$2!;
                    final currentTrackRemainingDuration = (progressState.mediaItem!.duration! - progressState.position);
                    final queueRemainingDuration = queueInfo.remainingDuration;
                    Duration remaining;
                    switch (selectedMode) {
                      case _MenuPage.minutes:
                        int? finalTrackIndex = queueInfo.getTrackIndexAfter(
                          newSleepTimer.totalDuration - currentTrackRemainingDuration,
                        );
                        Duration? durationOfFinalTrack;
                        Duration? durationUntilFinalTrack;
                        Duration? durationUntilEndOfFinalTrack;
                        if (finalTrackIndex != null) {
                          durationOfFinalTrack = queueInfo.fullQueue[finalTrackIndex - 1].item.duration!;
                          durationUntilFinalTrack = newSleepTimer.totalDuration < currentTrackRemainingDuration
                              ? Duration.zero
                              : currentTrackRemainingDuration +
                                    queueInfo.getDurationUntil(finalTrackIndex - queueInfo.currentTrackIndex);
                          durationUntilEndOfFinalTrack = newSleepTimer.totalDuration < currentTrackRemainingDuration
                              ? currentTrackRemainingDuration
                              : durationUntilFinalTrack + durationOfFinalTrack;
                        }
                        remaining = finishTrack
                            ? Duration(
                                milliseconds: min(
                                  durationUntilEndOfFinalTrack?.inMilliseconds ??
                                      (queueRemainingDuration + currentTrackRemainingDuration).inMilliseconds,
                                  (queueRemainingDuration + currentTrackRemainingDuration).inMilliseconds,
                                ),
                              )
                            : Duration(
                                milliseconds: min(
                                  newSleepTimer.totalDuration.inMilliseconds,
                                  (queueRemainingDuration + currentTrackRemainingDuration).inMilliseconds,
                                ),
                              );
                      case _MenuPage.tracks:
                        remaining =
                            currentTrackRemainingDuration + queueInfo.getDurationUntil(newSleepTimer.tracksLength);
                      case _MenuPage.currentTrack:
                        remaining = currentTrackRemainingDuration + queueInfo.getDurationUntil(1);
                    }
                    remaining = remaining * (1 / GetIt.instance<MusicPlayerBackgroundTask>().speed);
                    final remainText = printDuration(remaining, leadingZeroes: false);
                    final remainingLabelFullHours = (remaining.inHours);
                    final remainingLabelFullMinutes = (remaining.inMinutes) % 60;
                    final remainingLabelSeconds = (remaining.inSeconds) % 60;
                    final remainingLabelString =
                        "${remainingLabelFullHours > 0 ? "$remainingLabelFullHours ${AppLocalizations.of(context)!.hours} " : ""}${remainingLabelFullMinutes > 0 ? "$remainingLabelFullMinutes ${AppLocalizations.of(context)!.minutes} " : ""}$remainingLabelSeconds ${AppLocalizations.of(context)!.seconds}";
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0, right: 8.0),
                      child: Text(
                        AppLocalizations.of(context)!.sleepTimerProjectedDuration(remainText),
                        semanticsLabel: AppLocalizations.of(context)!.sleepTimerProjectedDuration(remainingLabelString),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            // Start Timer button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SimpleButton(
                text: AppLocalizations.of(context)!.sleepTimerStartTimer,
                icon: TablerIcons.hourglass_high,
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    GetIt.instance<MusicPlayerBackgroundTask>().startSleepTimer(newSleepTimer);
                    FinampSetters.setSleepTimer(newSleepTimer);
                    widget.onStartTimer?.call();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
