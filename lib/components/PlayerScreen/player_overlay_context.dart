import 'package:flutter/material.dart';

/// Present overlays from this context so player-only themes are not captured.
class PlayerOverlayContext extends InheritedWidget {
  const PlayerOverlayContext({required super.child, super.key});

  static BuildContext resolve(BuildContext context) {
    return context.getElementForInheritedWidgetOfExactType<PlayerOverlayContext>() ?? context;
  }

  @override
  bool updateShouldNotify(PlayerOverlayContext oldWidget) => false;
}
