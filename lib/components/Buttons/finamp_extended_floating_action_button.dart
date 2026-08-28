import 'package:finamp/extensions/color_extensions.dart';
import 'package:flutter/material.dart';

class FinampExtendedFloatingActionButton extends StatelessWidget {
  const FinampExtendedFloatingActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    Color actualBackgroundColor = backgroundColor ?? ColorScheme.of(context).primary;
    Color textColor = AtContrast.getContrastiveTintedTextColor(onBackground: actualBackgroundColor);

    return SizedBox(
      height: 48.0,
      child: FittedBox(
        child: FloatingActionButton.extended(
          onPressed: onTap,
          backgroundColor: actualBackgroundColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
          icon: Icon(icon, size: 20.0, color: textColor),
          label: Text(
            label,
            style: TextTheme.of(context).bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
