import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class ShowAllButton extends IconButtonWithSemantics {
  const ShowAllButton({
    super.key,
    required super.onPressed,
    required super.label,
    super.icon = TablerIcons.chevron_right,
    super.color,
  }) : super(
         visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
         padding: const EdgeInsets.only(left: 8.0, right: 0, top: 8.0, bottom: 8.0),
       );
}
