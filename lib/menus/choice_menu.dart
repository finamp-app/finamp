import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class ChoiceMenuListTile extends ConsumerWidget {
  const ChoiceMenuListTile({
    super.key,
    required this.title,
    required this.menuCreator,
    this.subtitle,
    required this.leading,
    this.icon,
    required this.state,
    this.trailing,
    this.isLoading = false,
    this.enabled = true,
    this.confirmationFeedback = true,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final IconData? icon;
  final Widget? trailing;
  final bool state;
  final bool isLoading;
  final bool enabled;
  final bool confirmationFeedback;
  final bool compact;
  final Future<void> Function() menuCreator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(icon != null || trailing != null, "Either icon or trailing must be provided.");
    var themeColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Container(
        decoration: ShapeDecoration(
          color: themeColor.withOpacity(state ? 0.3 : 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.only(left: 10.0, bottom: compact ? 4.0 : 6.0),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            enableFeedback: true,
            enabled: enabled,
            leading: Padding(padding: const EdgeInsets.only(top: 2.0), child: leading),
            horizontalTitleGap: 16.0,
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: subtitle != null
                ? Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextTheme.of(context).bodySmall?.fontSize),
                  )
                : null,
            trailing: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  height: compact ? 24.0 : 48.0,
                  width: 16.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: VerticalDivider(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      thickness: 1.5,
                      indent: compact ? 2.0 : 8.0,
                      endIndent: compact ? 2.0 : 8.0,
                      width: 1.0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 12.0),
                  child: isLoading
                      ? SizedBox(
                          height: compact ? 32.0 : 36.0,
                          width: compact ? 32.0 : 36.0,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: const CircularProgressIndicator(strokeWidth: 3),
                          ),
                        )
                      : trailing ?? Icon(icon, size: compact ? 32.0 : 36.0, color: themeColor),
                ),
              ],
            ),
            onTap: () async {
              FeedbackHelper.feedback(FeedbackType.selection);
              await menuCreator();
            },
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: compact ? 2.0 : null,
            minTileHeight: compact ? 50.0 : null,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          ),
        ),
      ),
    );
  }
}

class ChoiceMenuOption extends StatelessWidget {
  const ChoiceMenuOption({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    this.enabled = true,
    this.isInactive = false,
    this.description,
    this.onSelect,
    this.badges = const [],
  });

  final String title;
  final String? description;
  final IconData icon;
  final bool isSelected;
  final void Function()? onSelect;
  final bool enabled;
  final bool isInactive;

  /// Icons or other small widgets to show in front of the description, to highlight certain options.
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Padding(
          padding: const EdgeInsets.only(right: 2.0),
          child: Icon(icon, size: 32.0, color: enabled ? ColorScheme.of(context).primary : null),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.clip),
        subtitle: badges.isNotEmpty || description != null
            ? Text.rich(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                TextSpan(
                  children: [
                    WidgetSpan(
                      child: Padding(
                        padding: badges.isNotEmpty ? const EdgeInsets.only(right: 4.0) : EdgeInsets.zero,
                        child: Row(mainAxisSize: MainAxisSize.min, spacing: 4.0, children: badges),
                      ),
                      alignment: PlaceholderAlignment.middle,
                    ),
                    if (description != null) TextSpan(text: description!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              )
            : null,
        trailing: isSelected
            ? Padding(
                padding: const EdgeInsets.only(left: 2.0),
                child: isInactive
                    ? SizedBox(
                        width: 32.0,
                        child: Center(
                          child: Icon(
                            TablerIcons.point_filled,
                            size: 20.0,
                            color: TextTheme.of(context).bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      )
                    : Icon(TablerIcons.check, size: 32.0, color: ColorScheme.of(context).primary),
              )
            : null,
        onTap: () async {
          onSelect?.call();
        },
        enabled: enabled,
      ),
    );
  }
}
