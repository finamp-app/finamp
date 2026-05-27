import 'package:collection/collection.dart';

extension Lengthslice<T> on List<T> {
  ListSlice<T> safeSliceByLength(int start, [int? length]) {
    final safeStart = start.clamp(0, this.length);
    if (length == null) {
      return slice(safeStart);
    }
    final end = safeStart + length;
    final safeEnd = end.clamp(safeStart, this.length);
    return slice(safeStart, safeEnd);
  }
}
