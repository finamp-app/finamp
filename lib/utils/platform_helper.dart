import 'dart:io';

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class ShortcutKeyDisplay {
  static String get primaryModifier => Platform.isIOS || Platform.isMacOS ? '⌘' : 'Ctrl';
  static String get shift => Platform.isIOS || Platform.isMacOS ? '⇧' : 'Shift';
  static String get alt => Platform.isIOS || Platform.isMacOS ? '⌥' : 'Alt';
  static String get enter => Platform.isIOS || Platform.isMacOS ? '⏎' : 'Enter';
  static String get backspace => Platform.isIOS || Platform.isMacOS ? '⌫' : 'Backspace';
}
