import 'package:flutter/cupertino.dart';

/// A customScrollView that adds additional padding to the top/bottom of the list to
/// avoid system elements
class PaddedCustomScrollview extends CustomScrollView {
  const PaddedCustomScrollview({
    super.key,
    // Only vertical scrolling supported
    //super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.scrollBehavior,
    super.shrinkWrap,
    super.center,
    super.anchor,
    super.scrollCacheExtent,
    super.slivers,
    super.semanticChildCount,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.clipBehavior,
    super.hitTestBehavior,
    this.bottomPadding = 32.0,
    this.applyHeaderPadding = false,
  });

  /// Additional bottom padding to add in addition to system element padding
  final double bottomPadding;

  /// Whether header padding should be added.  This is false by default to allow for SliverAppBars.
  final bool applyHeaderPadding;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return [...slivers, SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding))];
    }

    // Strip bottom MediaQuery padding because it is being added by this widget.
    final MediaQueryData strippedMediaQuery = mediaQuery.copyWith(
      padding: mediaQuery.padding.copyWith(bottom: 0.0, top: applyHeaderPadding ? 0.0 : null),
    );

    return [
      if (applyHeaderPadding) SliverPadding(padding: EdgeInsets.only(top: mediaQuery.padding.top)),
      ...slivers.map((x) => MediaQuery(data: strippedMediaQuery, child: x)),
      SliverPadding(padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom + bottomPadding)),
    ];
  }
}
