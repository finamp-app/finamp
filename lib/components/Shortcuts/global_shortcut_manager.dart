import 'package:collection/collection.dart';
import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final shortcutLogger = Logger("KeyboardShortcut");

class GlobalShortcuts {
  static final Map<Intent, SingleActivator> _raw = {
    const TogglePlaybackIntent(): SingleActivator(LogicalKeyboardKey.space),
    const SkipToNextIntent(): SingleActivator(LogicalKeyboardKey.keyN, control: true),
    const SkipToPreviousIntent(): SingleActivator(LogicalKeyboardKey.keyP, control: true),
    const SeekForwardIntent(): SingleActivator(LogicalKeyboardKey.arrowRight, control: true),
    const SeekBackwardIntent(): SingleActivator(LogicalKeyboardKey.arrowLeft, control: true),
    const VolumeUpIntent(): SingleActivator(LogicalKeyboardKey.arrowUp, control: true),
    const VolumeDownIntent(): SingleActivator(LogicalKeyboardKey.arrowDown, control: true),
    const ToggleLoopModeIntent(): SingleActivator(LogicalKeyboardKey.keyL, control: true),
    const TogglePlaybackOrderIntent(): SingleActivator(LogicalKeyboardKey.keyS, control: true),
    const BackIntent(): SingleActivator(LogicalKeyboardKey.escape),
  };

  static Map<ShortcutActivator, Intent> get shortcutMap {
    final Map<ShortcutActivator, Intent> map = {};
    map.addAll(WidgetsApp.defaultShortcuts);
    for (final entry in _raw.entries) {
      final keys = entry.value;
      // Remove default bindings that conflict with the one we're adding
      map.removeWhere(
        (x, _) =>
            x is SingleActivator &&
            x.trigger == keys.trigger &&
            x.alt == keys.alt &&
            x.shift == keys.shift &&
            x.control == keys.control &&
            x.meta == keys.meta,
      );
      map[keys] = entry.key;
    }
    return map;
  }

  static Map<Type, Action<Intent>> get actionMap {
    final Map<Type, Action<Intent>> map = {};
    map.addAll(WidgetsApp.defaultActions);
    map.addAll(getMusicControlActions());
    return map;
  }

  static String getDisplay(Type intentType) {
    final entry = _raw.entries.firstWhereOrNull((e) => e.key.runtimeType == intentType);
    if (entry == null) return "";
    final action = entry.value;
    final parts = <String>[];

    // Modifiers
    if (action.control) parts.add(ShortcutKeyDisplay.primaryModifier);
    if (action.shift) parts.add(ShortcutKeyDisplay.shift);
    if (action.alt) parts.add(ShortcutKeyDisplay.alt);

    parts.add(_formatKey(action.trigger));
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
