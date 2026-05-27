import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
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
  final EdgeInsets headerPadding;
  final EdgeInsets contentPadding;
  final void Function()? onTap;
  final void Function()? onSecondaryTap;
  final Future<bool?> Function(ItemSwipeActions)? onDismiss;
  final bool sticky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverStickyHeader(
      sticky: sticky,
      header: Material(
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          onLongPress: onSecondaryTap,
          onSecondaryTap: onSecondaryTap,
          onTap: onTap,
          child: Padding(
            padding: headerPadding,
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
                  Expanded(
                    child: Text(
                      title,
                      style: TextTheme.of(context).titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
      sliver: SliverPadding(padding: contentPadding, sliver: sectionContentSliver),
    );
  }
}
