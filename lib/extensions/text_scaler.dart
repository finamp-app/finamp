import 'package:flutter/painting.dart';

extension TextLayoutCompensdation on TextScaler {
  /// Returns an offset value to be added to the expected height of a widget if it contains a text line with
  /// the given parameters.  Will always be 0.0 on a system using the default text scaling.
  double heightAdjustment(double fontSize, {double heightFactor = 1.0}) {
    return (-fontSize + scale(fontSize)) * heightFactor;
  }
}
