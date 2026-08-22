import 'dart:math';
import 'dart:ui';

import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

const _radius = Radius.circular(4);
const _borderRadius = BorderRadius.all(_radius);
final _defaultBackgroundColour = Colors.white.withValues(alpha: 0.1);
const _spacing = 8.0;

enum PresetTypes { speed }

class PresetChips extends StatefulWidget {
  const PresetChips({
    super.key,
    required this.type,
    required this.values,
    required this.activeValue,
    this.defaultValue,
    this.onTap,
    this.mainColour,
    this.onPresetSelected,
    this.prefix = "",
    this.showAsDouble = false,
    this.chipWidth = 64.0,
    this.chipHeight = 44.0,
  });

  final PresetTypes type;

  final List<double> values;
  final double? defaultValue;
  final double activeValue;
  final VoidCallback? onTap;
  final Color? mainColour; // used for different background colours
  final ValueChanged<double>? onPresetSelected;
  final bool showAsDouble;
  final String prefix;
  final double chipWidth;
  final double chipHeight;

  @override
  State<PresetChips> createState() => _PresetChipsState();
}

class _PresetChipsState extends State<PresetChips> {
  final _queueService = GetIt.instance<QueueService>();
  ScrollController? _controller;

  void scrollToActivePreset(double currentValue, double maxWidth) {
    if (_controller != null && !_controller!.hasClients) return;
    var offset =
        widget.chipWidth * widget.values.indexOf(currentValue) + widget.chipWidth / 2 - maxWidth / 2 - _spacing / 2;

    offset = min(max(0, offset), widget.chipWidth * (widget.values.length) - maxWidth - _spacing);

    if (_controller == null) {
      _controller = ScrollController(initialScrollOffset: offset);
    } else {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller!.jumpTo(offset);
      } else {
        _controller!.animateTo(offset, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    }
  }

  PresetChip generatePresetChip(double value, BoxConstraints constraints) {
    // Scroll to the active preset
    if (value == widget.activeValue) {
      scrollToActivePreset(value, constraints.maxWidth);
    }

    final stringValue = "${widget.prefix}${widget.showAsDouble ? value : value.round()}";

    return PresetChip(
      value: stringValue,
      backgroundColour: widget.mainColour?.withValues(
        alpha: value == widget.activeValue
            ? 0.6
            : (value == widget.defaultValue)
            ? 0.3
            : 0.1,
      ),
      isSelected: value == widget.activeValue,
      isPresetDefault: value == widget.defaultValue,
      width: widget.chipWidth,
      height: widget.chipHeight,
      onTap: () {
        setState(() {});
        // Only update playbackSpeed for speed menu, not for sleep timer menu
        if (widget.type == PresetTypes.speed && widget.onPresetSelected == null) {
          _queueService.playbackSpeed = value;
        }
        if (widget.onPresetSelected != null) {
          widget.onPresetSelected!(value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Create preset list to before scrollView to allow the scrollController
        // initial offset to be calculated first.
        var list = List.generate(
          widget.values.length,
          (index) => generatePresetChip(widget.values[index], constraints),
        );
        // assert(_controller != null);
        // Allow drag scrolling on desktop
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: Wrap(spacing: _spacing, crossAxisAlignment: WrapCrossAlignment.center, children: list),
          ),
        );
      },
    );
  }
}

class PresetChip extends StatelessWidget {
  const PresetChip({
    super.key,
    required this.width,
    required this.height,
    this.value = "",
    this.onTap,
    this.backgroundColour,
    this.isSelected,
    this.isPresetDefault,
  });

  final double width;
  final double height;
  final String value;
  final void Function()? onTap;
  final Color? backgroundColour;
  final bool? isSelected;
  final bool? isPresetDefault;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = backgroundColour ?? _defaultBackgroundColour;
    final color = (isSelected ?? false) ? Colors.white : Theme.of(context).textTheme.bodySmall?.color ?? Colors.white;

    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: backgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
        minimumSize: Size(width, height),
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      child: Text(
        value,
        style: TextStyle(
          color: color,
          overflow: TextOverflow.visible,
          fontWeight: isSelected! ? FontWeight.w600 : FontWeight.normal,
        ),
        softWrap: false,
      ),
    );
  }
}
