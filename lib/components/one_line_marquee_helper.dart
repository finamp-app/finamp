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
    // TODO should this be on its own setting along with the player screen?
    // But I feel having a marquee by default on the player screen is less of an issue then on the now playing bar,
    // so that would push us towards not unifying them.  Maybe this is fine as-is?
    if (!ref.watch(finampSettingsProvider.preferMarqueeOverOverflowingTwoLine)) {
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
        final height = textPainter.height;
        textPainter.dispose();

        if (isOverflowing) {
          return SizedBox(
            height: height,
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
          );
        } else {
          return Text(text, style: style, overflow: TextOverflow.ellipsis, maxLines: 1);
        }
      },
    );
  }
}
