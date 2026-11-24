import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MenuEntry extends ConsumerWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String? tooltip;

  const MenuEntry({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var iconColor = Theme.of(context).colorScheme.primary;

    final entry = Material(
      color: Colors.transparent,
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: enabled ? iconColor : iconColor.withValues(alpha: 0.5)),
        title: Text(title),
        onTap: onTap,
      ),
    );

    if (tooltip != null) {
      // A disabled entry ignores taps, so show why it's disabled on tap too.
      return Tooltip(message: tooltip, triggerMode: enabled ? null : TooltipTriggerMode.tap, child: entry);
    } else {
      return entry;
    }
  }
}

abstract class HideableMenuEntry implements Widget {
  /// Whether the menuentry is expected to be visible.  If visibility is unknown until
  /// a server request or other async code completes, the implementation should return true;
  bool get isVisible;
}
