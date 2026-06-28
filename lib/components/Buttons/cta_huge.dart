import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';

class CTAHuge extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool vertical;
  final void Function() onPressed;
  final bool disabled;

  const CTAHuge({
    super.key,
    required this.text,
    required this.icon,
    this.vertical = false,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
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
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
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
          Icon(icon, size: 28, color: accentColor, weight: 1.5),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color:
                  (Theme.brightnessOf(context) == Brightness.light
                          ? Color.alphaBlend(accentColor.withOpacity(0.33), Colors.black)
                          : Colors.white)
                      .withOpacity(disabled ? 0.5 : 1.0),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
