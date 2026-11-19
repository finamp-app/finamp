import 'dart:math';

/// Padding on each side of the home screen quick actions; centres them when the screen is wider than [maxWidth].
double quickActionsHorizontalPadding({required double usableWidth, required double maxWidth}) =>
    max(0, (usableWidth - maxWidth) / 2) + 14.0;

/// Width of the quick action at [index], and whether it uses the tall (vertical) style.
/// Rows are always filled completely: three tall buttons, two wide ones, or one full-width button.
({double width, bool vertical}) quickActionButtonLayout({
  required double usableWidth,
  required double maxWidth,
  required int actionCount,
  required int index,
}) {
  final horizontalPadding = quickActionsHorizontalPadding(usableWidth: usableWidth, maxWidth: maxWidth);
  final double quickActionsWidth = min(usableWidth - horizontalPadding - horizontalPadding, maxWidth);
  double verticalButtonWidth = (quickActionsWidth / 3) - 2 * (5.0);
  double horizontalButtonWidth = (quickActionsWidth / 2) - 1 * (8.0);
  double singleButtonWidth = quickActionsWidth;
  double buttonWidth;
  if (actionCount == 1) {
    buttonWidth = singleButtonWidth;
  } else if (actionCount % 3 == 0) {
    buttonWidth = verticalButtonWidth;
  } else if (actionCount == 4) {
    buttonWidth = horizontalButtonWidth;
  } else if ((actionCount % 3 == 1 && actionCount - index <= 4) || (actionCount % 3 == 2 && actionCount - index < 3)) {
    buttonWidth = horizontalButtonWidth;
  } else {
    buttonWidth = verticalButtonWidth;
  }
  // Before the window has a size (e.g. Finamp started in the background by a car), widths would go negative.
  return (width: max(0, buttonWidth), vertical: buttonWidth == verticalButtonWidth);
}
