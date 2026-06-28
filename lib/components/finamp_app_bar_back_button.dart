import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class FinampAppBarBackButton extends StatelessWidget {
  const FinampAppBarBackButton({super.key, this.onPressed, this.dismissDirection = AxisDirection.left});

  final VoidCallback? onPressed;

  /// The direction in which the screen will slide when the button is pressed.
  final AxisDirection dismissDirection;

  @override
  Widget build(BuildContext context) {
    IconData getIcon() {
      switch (dismissDirection) {
        case AxisDirection.down:
          return TablerIcons.chevron_down;
        case AxisDirection.left:
          return TablerIcons.chevron_left;
        case AxisDirection.right:
          return TablerIcons.chevron_right;
        case AxisDirection.up:
          return TablerIcons.chevron_up;
      }
    }

    return IconButtonWithSemantics(
      // padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      label: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      icon: getIcon(),
      strokeWidth: 1.5,
      visualDensity: VisualDensity(horizontal: 0, vertical: -4),
    );
  }
}
