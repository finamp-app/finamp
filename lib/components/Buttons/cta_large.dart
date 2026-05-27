import 'dart:io';

import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';

class CTALarge extends StatelessWidget {
  final String text;
  final String? label;
  final IconData icon;
  final double? minWidth;
  final bool vertical;
  final void Function() onPressed;
  final bool disabled;

  const CTALarge({
    super.key,
    required this.text,
    this.label,
    required this.icon,
    this.minWidth,
    this.vertical = false,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = disabled
        ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
        : Theme.of(context).colorScheme.primary;
    return Semantics(
      label: text,
      tooltip: label,
      button: true,
      focusable: true,
      onLongPressHint: label,
      excludeSemantics: true, // replace child semantics with custom semantics
      container: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth ?? 0),
        child: FilledButton(
          onPressed: disabled
              ? null
              : () {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  onPressed();
                },
          style: ButtonStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  Platform.isLinux || Platform.isWindows || Platform.isMacOS ? 16 : 20,
                ),
              ),
            ),
            padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            backgroundColor: WidgetStateProperty.all<Color>(
              Theme.brightnessOf(context) == Brightness.dark
                  ? accentColor.withOpacity(disabled ? 0.05 : 0.15)
                  : Color.alphaBlend(accentColor.withOpacity(0.2), Colors.white).withOpacity(disabled ? 0.5 : 1.0),
            ),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            direction: vertical ? Axis.vertical : Axis.horizontal,
            alignment: vertical ? WrapAlignment.center : WrapAlignment.start,
            children: [
              Icon(icon, size: 24, color: accentColor, weight: 1.0),
              const SizedBox(width: 16, height: 8),
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
      ),
    );
  }
}
