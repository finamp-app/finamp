import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ToggleableListTile extends ConsumerWidget {
  const ToggleableListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.leading,
    this.icon,
    required this.state,
    required this.onToggle,
    this.trailing,
    this.divider,
    this.isLoading = false,
    this.enabled = true,
    this.confirmationFeedback = true,
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final IconData? icon;
  final Widget? trailing;
  final bool state;
  final Future<void> Function(bool state) onToggle;
  final bool isLoading;
  final bool enabled;
  final bool confirmationFeedback;
  final bool? divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(icon != null || trailing != null, "Either icon or trailing must be provided.");
    var themeColor = Theme.of(context).colorScheme.primary;
    final showDivider = divider ?? trailing == null;
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 4.0, bottom: 4.0),
      child: Container(
        decoration: ShapeDecoration(
          color: themeColor.withOpacity(state ? 0.3 : 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            enableFeedback: true,
            enabled: enabled,
            leading: leading,
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (showDivider)
                  SizedBox(
                    height: 48.0,
                    width: 16.0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: VerticalDivider(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                        thickness: 1.5,
                        indent: 8.0,
                        endIndent: 8.0,
                        width: 1.0,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(left: showDivider ? 8.0 : 16.0, right: 12.0),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : trailing ?? Icon(icon, size: 36.0, color: themeColor),
                ),
              ],
            ),
            onTap: isLoading
                ? null
                : () async {
                    FeedbackHelper.feedback(FeedbackType.selection);
                    try {
                      await onToggle(state);
                      if (confirmationFeedback) {
                        FeedbackHelper.feedback(FeedbackType.heavy);
                      }
                    } catch (e) {
                      GlobalSnackbar.error(e);
                    }
                  },
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 0,
            // visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          ),
        ),
      ),
    );
  }
}
