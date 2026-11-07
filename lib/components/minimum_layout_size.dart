import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';

/// The smallest window size Finamp supports on desktop platforms.
///
/// On Windows and macOS this is enforced by window_manager. On Linux it is enforced
/// natively in `linux/finamp_application.cc` (keep both in sync), because
/// window_manager's geometry hints get reset by GTK.
const Size kMinimumWindowSize = Size(400, 250);

/// Whether the app runs on a desktop platform with a freely resizable window.
final bool isDesktopWindow = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Lays out [child] at least at [minSize], clipping whatever doesn't fit.
///
/// Some window managers (e.g. tiling compositors) ignore the minimum size hints of
/// a window and briefly give it arbitrary sizes. Instead of letting every widget
/// overflow, the app is laid out at [minSize] and clipped to the actual window.
///
/// The widget tree is identical whether or not the available space is smaller than
/// [minSize], so crossing the threshold never reparents or rebuilds [child]'s subtree.
class MinimumLayoutSize extends StatelessWidget {
  const MinimumLayoutSize({super.key, required this.minSize, required this.child});

  final Size minSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = max(constraints.maxWidth, minSize.width);
        final height = max(constraints.maxHeight, minSize.height);
        final mediaQuery = MediaQuery.of(context);
        final mediaSize = mediaQuery.size;
        return ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.topStart,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: MediaQuery(
              data: mediaQuery.copyWith(
                size: Size(max(mediaSize.width, minSize.width), max(mediaSize.height, minSize.height)),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
