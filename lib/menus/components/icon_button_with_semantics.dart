import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IconButtonWithSemantics extends ConsumerWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final IconData icon;
  final Color? color;
  final String label;
  final double? iconSize;
  final double? strokeWidth;
  final EdgeInsetsGeometry? padding;
  final VisualDensity? visualDensity;

  const IconButtonWithSemantics({
    super.key,
    required this.onPressed,
    required this.label,
    required this.icon,
    this.color,
    this.iconSize,
    this.strokeWidth,
    this.visualDensity,
    this.padding,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: label,
      excludeSemantics: true, // replace child semantics with custom semantics
      container: true,
      child: GestureDetector(
        onSecondaryTap: onLongPress == null
            ? null
            : () {
                onLongPress!();
                FeedbackHelper.feedback(FeedbackType.selection);
              },
        child: IconTheme(
          data: IconThemeData(color: color ?? IconTheme.of(context).color, size: iconSize ?? 24.0, weight: strokeWidth),
          child: IconButton(
            tooltip: label,
            icon: Icon(icon),
            visualDensity: visualDensity ?? VisualDensity.compact,
            onPressed: onPressed == null
                ? null
                : () {
                    onPressed!();
                    FeedbackHelper.feedback(FeedbackType.selection);
                  },
            onLongPress: onLongPress == null
                ? null
                : () {
                    onLongPress!();
                    FeedbackHelper.feedback(FeedbackType.selection);
                  },
            padding: padding,
          ),
        ),
      ),
    );
  }
}
