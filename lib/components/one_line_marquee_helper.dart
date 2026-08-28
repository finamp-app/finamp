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
