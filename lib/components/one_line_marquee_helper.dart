import 'dart:math' as math;

import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marquee/marquee.dart';

class OneLineMarqueeHelper extends ConsumerWidget {
  final String text;
  final TextStyle style;

  const OneLineMarqueeHelper({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(finampSettingsProvider.oneLineMarqueeTextButton)) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis, maxLines: 1);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;
        textPainter.dispose();

        if (isOverflowing) {
          return Container(
            alignment: Alignment.centerLeft,
            height: style.fontSize ?? 16.0,
            width: constraints.maxWidth,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Marquee(
                    key: key,
                    text: text,
                    style: style,
                    scrollAxis: Axis.horizontal,
                    blankSpace: 20.0,
                    velocity: 50.0,
                    pauseAfterRound: const Duration(seconds: 3),
                    accelerationDuration: const Duration(seconds: 1),
                    accelerationCurve: Curves.linear,
                    decelerationDuration: const Duration(milliseconds: 500),
                    decelerationCurve: Curves.easeOut,
                    textDirection: TextDirection.ltr,
                  ),
                ),
                Positioned(left: 0, child: Container(width: 20, color: Theme.of(context).scaffoldBackgroundColor)),
                Positioned(right: 0, child: Container(width: 20, color: Theme.of(context).scaffoldBackgroundColor)),
              ],
            ),
          );
        } else {
          return Text(text, style: style, overflow: TextOverflow.ellipsis, maxLines: 1);
        }
      },
    );
  }
}

class LeftSideEllipsis extends StatelessWidget {
  final String text;

  final TextStyle? style;

  const LeftSideEllipsis({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 7.0;
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width);

        if (!textPainter.didExceedMaxLines) {
          textPainter.dispose();
          return Text(text, style: style, overflow: TextOverflow.visible, softWrap: false);
        }

        double getWidth(String? text) {
          textPainter.text = TextSpan(text: text, style: style);
          textPainter.layout();

          return textPainter.size.width;
        }

        final showable = _binarySearch(
          0,
          text.length,
          (length) => getWidth("...${text.substring(text.length - length, text.length)}").compareTo(width),
        );
        textPainter.dispose();
        return Text(
          "...${text.substring(text.length - showable, text.length)}",
          style: style,
          overflow: TextOverflow.visible,
          softWrap: false,
        );
      },
    );
  }

  /// Uses binary search to find the value between min and max, inclusive, that satisfies the given comparison.
  /// If no exact match is found, returns the largest value below the target if floor is true, or smallest above if floor is false.
  int _binarySearch(int min, int max, int Function(int) evaluate, {bool floor = true}) {
    if (min >= max) {
      if (floor) {
        return math.min(min, max);
      } else {
        return math.max(min, max);
      }
    }
    final midpoint = (max - min) / 2.0 + min;
    final center = floor ? midpoint.ceil() : midpoint.floor();
    final result = evaluate(center);
    if (result > 0) {
      return _binarySearch(min, center - (floor ? 1 : 0), evaluate, floor: floor);
    } else if (result < 0) {
      return _binarySearch(center + (floor ? 0 : 1), max, evaluate, floor: floor);
    } else {
      return center;
    }
  }
}
