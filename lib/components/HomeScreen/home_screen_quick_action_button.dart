import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/material.dart';

class HomeScreenQuickActionButton extends StatelessWidget {
  final String text;
  final String? label;
  final IconData icon;
  final double width;
  final bool vertical;
  final void Function() onPressed;
  final void Function()? onSecondaryPressed;
  final bool disabled;

  const HomeScreenQuickActionButton({
    super.key,
    required this.text,
    this.label,
    required this.icon,
    required this.width,
    this.vertical = false,
    required this.onPressed,
    this.onSecondaryPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = disabled ? ColorScheme.of(context).primary.withOpacity(0.5) : ColorScheme.of(context).primary;

    final buttonChildren = [
      Icon(icon, size: 24, color: accentColor, weight: 1.0),
      Text(
        text,
        style: TextStyle(
          color:
              (Theme.brightnessOf(context) == Brightness.light
                      ? Color.alphaBlend(accentColor.withOpacity(0.33), Colors.black)
                      : Colors.white)
                  .withOpacity(disabled ? 0.5 : 1.0),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        textAlign: vertical ? TextAlign.center : TextAlign.start,
      ),
    ];

    final buttonContent = vertical
        ? Column(mainAxisAlignment: MainAxisAlignment.center, spacing: isDesktop ? 4.0 : 6.0, children: buttonChildren)
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            spacing: isDesktop ? 4.0 : 6.0,
            children: buttonChildren,
          );

    return Semantics(
      label: text,
      tooltip: label,
      button: true,
      focusable: true,
      onLongPressHint: label,
      excludeSemantics: true, // replace child semantics with custom semantics
      container: true,
      child: SizedBox(
        width: width,
        child: GestureDetector(
          onLongPress: disabled || onSecondaryPressed == null
              ? null
              : () {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  onSecondaryPressed!();
                },
          onSecondaryTap: disabled || onSecondaryPressed == null
              ? null
              : () {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  onSecondaryPressed!();
                },
          child: FilledButton(
            onPressed: disabled
                ? null
                : () {
                    FeedbackHelper.feedback(FeedbackType.selection);
                    onPressed();
                  },

            style: ButtonStyle(
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDesktop ? 8 : 12)),
              ),
              padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: 8, vertical: isDesktop ? 16 : 8),
              ),
              backgroundColor: WidgetStateProperty.all<Color>(
                Theme.brightnessOf(context) == Brightness.dark
                    ? accentColor.withOpacity(disabled ? 0.05 : 0.15)
                    : Color.alphaBlend(accentColor.withOpacity(0.2), Colors.white).withOpacity(disabled ? 0.5 : 1.0),
              ),
            ),
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}
