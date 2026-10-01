import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:finamp/components/AlbumScreen/preset_chip.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

final _queueService = GetIt.instance<QueueService>();
final presets = [0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5];
const speedSliderMin = 0.35;
const speedSliderMax = 2.50;
const speedSliderStep = 0.05;
const speedButtonStep = 0.05;

class SpeedSlider extends StatefulWidget {
  const SpeedSlider({super.key, required this.iconColor, required this.saveSpeedInput});

  final Color iconColor;
  final Function saveSpeedInput;

  @override
  State<SpeedSlider> createState() => _SpeedSliderState();
}

class _SpeedSliderState extends State<SpeedSlider> {
  double? _dragValue;
  Timer? _debouncer;

  @override
  void dispose() {
    _debouncer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 24 / 2.0),
        trackHeight: 24.0,
        inactiveTrackColor: widget.iconColor.withValues(alpha: 0.3),
        activeTrackColor: FinampSettingsHelper.finampSettings.playbackSpeed > speedSliderMax
            ? widget.iconColor.withValues(alpha: 0.4)
            : widget.iconColor.withValues(alpha: 0.6),
        showValueIndicator: ShowValueIndicator.onDrag,
        valueIndicatorColor: Color.lerp(Theme.of(context).cardColor, widget.iconColor, 0.6),
        valueIndicatorTextStyle: Theme.of(context).textTheme.labelLarge,
        valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
        activeTickMarkColor: widget.iconColor.withValues(alpha: 0.9),
        overlayShape: SliderComponentShape.noOverlay, // get rid of padding
      ),
      child: ExcludeSemantics(
        child: Slider(
          min: speedSliderMin,
          max: speedSliderMax,
          value:
              _dragValue ??
              clampDouble(FinampSettingsHelper.finampSettings.playbackSpeed, speedSliderMin, speedSliderMax),
          // divisions: ((speedSliderMax - speedSliderMin) / speedSliderStep / 2).round(),
          onChanged: (value) {
            value = ((value / speedSliderStep).round() * speedSliderStep);
            if (_dragValue != value) {
              setState(() {
                _dragValue = value;
              });
              FeedbackHelper.feedback(FeedbackType.heavy);
              _debouncer?.cancel();
              _debouncer = Timer(const Duration(milliseconds: 150), () {
                widget.saveSpeedInput(value);
              });
            }
          },
          onChangeStart: (value) {
            value = (value / speedSliderStep).round() * speedSliderStep;
            setState(() {
              _dragValue = value;
            });
          },
          onChangeEnd: (value) {
            _dragValue = null;
            value = (value / speedSliderStep).round() * speedSliderStep;
            widget.saveSpeedInput(value);
            FeedbackHelper.feedback(FeedbackType.selection);
          },
          label: (_dragValue ?? FinampSettingsHelper.finampSettings.playbackSpeed).toStringAsFixed(2),
          autofocus: false,
          focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
        ),
      ),
    );
  }
}

class SpeedMenu extends StatefulWidget {
  const SpeedMenu({super.key, required this.iconColor, this.scrollFunction});

  final Color iconColor;
  final VoidCallback? scrollFunction;

  @override
  State<SpeedMenu> createState() => _SpeedMenuState();
}

class _SpeedMenuState extends State<SpeedMenu> {
  final _textController = TextEditingController(text: FinampSettingsHelper.finampSettings.playbackSpeed.toString());

  InputDecoration inputFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: widget.iconColor.withValues(alpha: 0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      label: Center(child: Text(AppLocalizations.of(context)!.speed)),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      constraints: const BoxConstraints(maxWidth: 82, maxHeight: 40),
      isDense: true,
      border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16)),
    );
  }

  void saveSpeedInput(double value) {
    final valueDouble = (min(max(value, 0), 5) * 100).roundToDouble() / 100;

    _queueService.playbackSpeed = valueDouble;
    setState(() {});

    refreshInputText();
  }

  void savePitch(double value) {
    final valueDouble = (min(max(value, 0), 5) * 100).roundToDouble() / 100;

    setState(() {
      _queueService.playbackPitch = valueDouble;
    });
  }

  void updatePitchSyncing(bool value) {
    if (value) {
      FinampSetters.setSyncPlaybackSpeedAndPitch(value);
      savePitch(_queueService.playbackSpeed);
    } else {
      savePitch(1.0);
    }
    FinampSetters.setSyncPlaybackSpeedAndPitch(value);
  }

  void refreshInputText() {
    _textController.text = FinampSettingsHelper.finampSettings.playbackSpeed.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: widget.iconColor.withValues(alpha: 0.1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
      child: Consumer(
        builder: (BuildContext builder, ref, _) {
          _textController.text = ref.watch(finampSettingsProvider.playbackSpeed).toString();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: PresetChips(
                  type: PresetTypes.speed,
                  mainColour: widget.iconColor,
                  values: presets,
                  defaultValue: 1.0,
                  prefix: "x",
                  showAsDouble: true,
                  activeValue: ref.watch(finampSettingsProvider.playbackSpeed),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 12.0, right: 12.0, bottom: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(TablerIcons.minus, color: widget.iconColor),
                      onPressed: () {
                        final currentSpeed = FinampSettingsHelper.finampSettings.playbackSpeed;

                        if (currentSpeed > speedSliderMin) {
                          FeedbackHelper.feedback(FeedbackType.selection);
                          _queueService.playbackSpeed = max(
                            speedSliderMin,
                            double.parse((currentSpeed - speedButtonStep).toStringAsFixed(2)),
                          );
                          setState(() {});
                        } else {
                          FeedbackHelper.feedback(FeedbackType.error);
                        }
                      },
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      tooltip: AppLocalizations.of(context)!.playbackSpeedDecreaseLabel,
                    ),
                    Expanded(
                      child: SpeedSlider(iconColor: widget.iconColor, saveSpeedInput: saveSpeedInput),
                    ),
                    IconButton(
                      icon: Icon(TablerIcons.plus, color: widget.iconColor),
                      onPressed: () {
                        final currentSpeed = FinampSettingsHelper.finampSettings.playbackSpeed;

                        if (currentSpeed < speedSliderMax) {
                          FeedbackHelper.feedback(FeedbackType.selection);
                          _queueService.playbackSpeed = min(
                            speedSliderMax,
                            double.parse((currentSpeed + speedButtonStep).toStringAsFixed(2)),
                          );
                          setState(() {});
                        } else {
                          FeedbackHelper.feedback(FeedbackType.error);
                        }
                      },
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      tooltip: AppLocalizations.of(context)!.playbackSpeedIncreaseLabel,
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      height: 32,
                      child: TextFormField(
                        controller: _textController,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: widget.iconColor.withValues(alpha: 0.08),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onFieldSubmitted: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed >= speedSliderMin && parsed <= speedSliderMax) {
                            saveSpeedInput(parsed);
                          } else {
                            refreshInputText();
                          }
                        },
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed >= speedSliderMin && parsed <= speedSliderMax) {
                            saveSpeedInput(parsed);
                          }
                        },
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
                          updatePitchSyncing(!FinampSettingsHelper.finampSettings.syncPlaybackSpeedAndPitch);
                        },
                        child: IntrinsicWidth(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  AppLocalizations.of(context)!.syncPlaybackSpeedAndPitchLabel,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              Checkbox.adaptive(
                                value: ref.watch(finampSettingsProvider.syncPlaybackSpeedAndPitch),
                                onChanged: (val) {
                                  updatePitchSyncing(val ?? false);
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
            ],
          );
        },
      ),
    );
  }
}
