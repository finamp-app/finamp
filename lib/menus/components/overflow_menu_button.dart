import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class OverflowMenuButton extends IconButtonWithSemantics {
  const OverflowMenuButton({
    super.key,
    required super.onPressed,
    required super.label,
    super.icon = TablerIcons.dots,
    super.color,
  });
}
