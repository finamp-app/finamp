import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';

import '../../extensions/localizations.dart';

enum IconPosition { start, end }

class SimpleButton extends StatelessWidget {
  final String text;
  final String? label;
  final TextStyle textStyle;
  final IconData icon;
  final IconPosition? iconPosition;
  final double iconSize;
  final Color? iconColor;
  final Color? textColor;
  final FontWeight? fontWeight;
  final void Function() onPressed;
  final void Function()? onPressedSecondary;
  final void Function()? onIconPressed;
  final bool disabled;
  final Color? backgroundColor;

  /// If false, the text will be used for the tooltip but only the icon will be visible
  final bool showText;

  /// fades the button out, while keeping it enabled
  /// used for representing state while also allowing interaction that can yield more information about the state (e.g. lyrics button)
  final bool inactive;

  const SimpleButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.onPressedSecondary,
    this.onIconPressed,
    this.textColor,
    this.fontWeight,
    this.label,
    this.iconPosition = IconPosition.start,
    this.iconSize = 20.0,
    this.iconColor,
    this.disabled = false,
    this.inactive = false,
    this.backgroundColor,
    this.showText = true,
  }) : textStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.normal);

  const SimpleButton.small({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.onPressedSecondary,
    this.onIconPressed,
    this.textColor,
    this.fontWeight,
    this.label,
    this.iconPosition = IconPosition.start,
    this.iconSize = 16.0,
    this.iconColor,
    this.disabled = false,
    this.inactive = false,
    this.backgroundColor,
    this.showText = true,
  }) : textStyle = const TextStyle(fontSize: 12, fontWeight: FontWeight.normal);

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: iconSize,
      color: (disabled || inactive) ? iconColor?.withOpacity(0.5) : iconColor,
      weight: 1.5,
    );

    final contents = [
      if (onIconPressed != null)
        IconButton(
          onPressed: (!disabled && !inactive) ? onIconPressed : null,
          icon: iconWidget,
          visualDensity: VisualDensity(horizontal: -4, vertical: -4),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(maxWidth: iconSize, maxHeight: iconSize),
          style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onLongPress: () {
            FeedbackHelper.feedback(FeedbackType.selection);
            onPressed();
          },
        )
      else
        iconWidget,
      if (showText)
        Text(
          text,
          style: TextStyle(
            color: (disabled || inactive)
                ? Theme.of(context).disabledColor
                : (textColor != null)
                ? textColor
                : Theme.of(context).textTheme.bodyMedium!.color!,
            fontSize: textStyle.fontSize,
            fontWeight: (fontWeight != null) ? fontWeight : textStyle.fontWeight,
          ),
          textAlign: TextAlign.center,
        ),
    ];

    return Tooltip(
      message: disabled ? context.l10n.tooltipDisabled(label ?? text) : label ?? text,
      child: GestureDetector(
        onLongPress: () {
          FeedbackHelper.feedback(FeedbackType.selection);
          if (onPressedSecondary != null) {
            onPressedSecondary!();
          }
        },
        onSecondaryTap: () {
          if (onPressedSecondary != null) {
            FeedbackHelper.feedback(FeedbackType.selection);
            onPressedSecondary!();
          }
        },
        child: TextButton(
          onPressed: disabled ? null : onPressed,
          style: ButtonStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
              iconPosition == IconPosition.start
                  ? EdgeInsets.only(left: 2, top: 0, bottom: 0, right: backgroundColor != null ? 6 : 2)
                  : EdgeInsets.only(left: backgroundColor != null ? 6 : 2, top: 0, bottom: 0, right: 2),
            ),
            backgroundColor: WidgetStateProperty.all<Color>(backgroundColor ?? Colors.transparent),
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            spacing: 6.0,
            children: iconPosition == IconPosition.start ? contents : contents.reversed.toList(),
          ),
        ),
      ),
    );
  }
}
