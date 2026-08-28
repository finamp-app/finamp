import 'dart:math';

import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';

class CTAMedium extends StatelessWidget {
  final String text;
  final IconData icon;
  final void Function() onPressed;
  final double? minWidth;
  final bool disabled;

  const CTAMedium({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.minWidth,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final minWidth = this.minWidth ?? screenSize.width * 0.25;
    final paddingHorizontal = screenSize.width * 0.015;
    final paddingVertical = screenSize.height * 0.015;
    final accentColor = disabled
        ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
        : Theme.of(context).colorScheme.primary;

    return FilledButton(
      onPressed: disabled
          ? null
          : () {
              FeedbackHelper.feedback(FeedbackType.selection);
              onPressed();
            },
      style: ButtonStyle(
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
          EdgeInsets.only(left: 8 + paddingHorizontal, right: 8, top: paddingVertical, bottom: paddingVertical),
        ),
        backgroundColor: WidgetStateProperty.all<Color>(
          Theme.brightnessOf(context) == Brightness.dark
              ? accentColor.withOpacity(disabled ? 0.05 : 0.15)
              : Color.alphaBlend(accentColor.withOpacity(0.2), Colors.white).withOpacity(disabled ? 0.5 : 1.0),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth + paddingHorizontal),
        padding: EdgeInsets.only(right: paddingHorizontal), // this is to center the content when a minWidth is set
        alignment: Alignment.center,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, size: 24, color: accentColor, weight: 1.0),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color:
                    (Theme.brightnessOf(context) == Brightness.light
                            ? Color.alphaBlend(accentColor.withOpacity(0.33), Colors.black)
                            : Colors.white)
                        .withOpacity(disabled ? 0.5 : 1.0),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double predictedHeight(BuildContext context) {
    final densityAdj = VisualDensity.adaptivePlatformDensity.baseSizeAdjustment.dy;
    return max(
      MediaQuery.heightOf(context) * 0.03 + 24 + densityAdj + densityAdj,
      kMinInteractiveDimension + densityAdj,
    );
  }
}
