import 'dart:math';

import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

class FinampSectionHeader extends ConsumerWidget {
  const FinampSectionHeader({
    required super.key,
    required this.sectionContentSliver,
    required this.title,
    this.titleTrailingIcon,
    this.label,
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.contentPadding = EdgeInsets.zero,
    this.onTap,
    this.onSecondaryTap,
    this.actions = const [],
    this.onDismiss,
    this.sticky = true,
  });

  final Widget sectionContentSliver;
  final List<Widget> actions;
  final String title;
  final String? label;
  final IconData? titleTrailingIcon;
  final EdgeInsets headerPadding;
  final EdgeInsets contentPadding;
  final void Function()? onTap;
  final void Function()? onSecondaryTap;
  final Future<bool?> Function(ItemSwipeActions)? onDismiss;
  final bool sticky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoverTargetPadding = EdgeInsets.only(left: 8.0, right: 4.0);
    final hoverPadding = EdgeInsets.only(
      left: min(hoverTargetPadding.left, headerPadding.left),
      right: min(hoverTargetPadding.right, headerPadding.right),
    );
    final correctedHeaderPadding = EdgeInsets.only(
      left: max(headerPadding.left - hoverPadding.left, 0),
      right: max(headerPadding.right - hoverPadding.right, 0),
    );
    return SliverStickyHeader(
      sticky: sticky,
      header: GestureDetector(
        onTap: onTap,
        onLongPress: onSecondaryTap,
        onSecondaryTap: onSecondaryTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: correctedHeaderPadding,
          child: Dismissible(
            key: Key("$key-dismissible"),
            direction: ref.watch(finampSettingsProvider.disableGesture) || onDismiss == null
                ? DismissDirection.none
                : getAllowedDismissDirection(
                    swipeLeftEnabled:
                        ref.watch(finampSettingsProvider.itemSwipeActionLeftToRight) != ItemSwipeActions.nothing,
                    swipeRightEnabled:
                        ref.watch(finampSettingsProvider.itemSwipeActionRightToLeft) != ItemSwipeActions.nothing,
                  ),
            dismissThresholds: const {DismissDirection.startToEnd: 0.65, DismissDirection.endToStart: 0.65},
            confirmDismiss: onDismiss != null
                ? (direction) async {
                    var followUpAction = (direction == DismissDirection.startToEnd)
                        ? FinampSettingsHelper.finampSettings.itemSwipeActionLeftToRight
                        : FinampSettingsHelper.finampSettings.itemSwipeActionRightToLeft;
                    return await onDismiss!(followUpAction);
                  }
                : null,
            background: buildSwipeActionBackground(
              context: context,
              direction: DismissDirection.startToEnd,
              action: ref.watch(finampSettingsProvider.itemSwipeActionLeftToRight),
            ),
            secondaryBackground: buildSwipeActionBackground(
              context: context,
              direction: DismissDirection.endToStart,
              action: ref.watch(finampSettingsProvider.itemSwipeActionRightToLeft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6.0),
                    // all handled by the [GestureDetector] above,
                    // but kept here for the desktop hover effect
                    onTap: onTap,
                    onLongPress: onSecondaryTap,
                    onSecondaryTap: onSecondaryTap,
                    child: Padding(
                      padding: hoverPadding,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            title,
                            semanticsLabel: label,
                            style: TextTheme.of(context).titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(width: 2.0),
                          if (titleTrailingIcon != null) Icon(titleTrailingIcon, size: 20.0, applyTextScaling: true),
                        ],
                      ),
                    ),
                  ),
                ),
                Spacer(),
                ...actions,
              ],
            ),
          ),
        ),
      ),
      sliver: SliverPadding(padding: contentPadding, sliver: sectionContentSliver),
    );
  }
}
