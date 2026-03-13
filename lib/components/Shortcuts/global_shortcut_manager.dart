import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:logging/logging.dart';

final shortcutLogger = Logger("KeyboardShortcut");

class GlobalShortcuts {
  static final Map<Intent, List<LogicalKeySet>> _raw = {
    const TogglePlaybackIntent(): [LogicalKeySet(LogicalKeyboardKey.space)],
    const SkipToNextIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN)],
    const SkipToPreviousIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP)],
    const SeekForwardIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowRight)],
    const SeekBackwardIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft)],
    const VolumeUpIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp)],
    const VolumeDownIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown)],
    const ToggleLoopModeIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL)],
    const TogglePlaybackOrderIntent(): [LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS)],
  };

  static Map<LogicalKeySet, Intent> get shortcutMap {
    final Map<LogicalKeySet, Intent> map = {};
    for (final entry in _raw.entries) {
      for (final keySet in entry.value) {
        map[keySet] = entry.key;
      }
    }
    return map;
  }

  static String getDisplay(Type intentType) {
    final entry = _raw.entries.firstWhere((e) => e.key.runtimeType == intentType);
    final keys = entry.value.first.keys;
    final parts = <String>[];

    // Modifiers
    if (keys.contains(LogicalKeyboardKey.control)) parts.add(ShortcutKeyDisplay.primaryModifier);
    if (keys.contains(LogicalKeyboardKey.shift)) parts.add(ShortcutKeyDisplay.shift);
    if (keys.contains(LogicalKeyboardKey.alt)) parts.add(ShortcutKeyDisplay.alt);

    // Trigger Key
    final trigger = keys.firstWhere(
      (k) => !{
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.alt,
      }.contains(k),
    );

    parts.add(_formatKey(trigger));
    return parts.join('+');
  }

  static String _formatKey(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowUp) return "↑";
    if (k == LogicalKeyboardKey.arrowDown) return "↓";
    if (k == LogicalKeyboardKey.arrowLeft) return "←";
    if (k == LogicalKeyboardKey.arrowRight) return "→";
    if (k == LogicalKeyboardKey.space) return "⎵";
    return k.keyLabel.toUpperCase();
  }
}

class GlobalShortcutManager extends StatelessWidget {
  final Widget child;

  const GlobalShortcutManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: GlobalShortcuts.shortcutMap,
      child: Actions(
        actions: {
          ...getMusicControlActions(),
          // Other actions can be added here
        },
        //!!! without this FocusScope, focus can get lost (clicking into a different window), and then it's hard to get back the focus, since most parts of the UI are not focusable by default. And without focus, no actions will be dispatched
        child: FocusScope(autofocus: true, child: child),
      ),
    );
  }
}
