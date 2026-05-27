import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MenuEntry extends ConsumerWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const MenuEntry({super.key, required this.title, required this.icon, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var iconColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: enabled ? iconColor : iconColor.withOpacity(0.5)),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}

abstract class HideableMenuEntry implements Widget {
  /// Whether the menuentry is expected to be visible.  If visibility is unknown until
  /// a server request or other async code completes, the implementation should return true;
  bool get isVisible;
}
