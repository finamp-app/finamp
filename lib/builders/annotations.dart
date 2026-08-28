import 'package:analyzer/dart/constant/value.dart';
import 'package:meta/meta_meta.dart';

/// Annotation for FinampSettings fields that should not have a setter and/or a
/// finampSettingsProvider selector created
@Target({TargetKind.setter, TargetKind.field})
class SettingsHelperIgnore {
  final String message;
  const SettingsHelperIgnore(this.message);
  @override
  String toString() => "Excluded from automatic sub-provider/setter generation: $message";
}

@Target({TargetKind.setter, TargetKind.field})
class SettingsHelperMap {
  /// Annotation for FinampSettings Map fields, which must use per-field getters and setters.
  /// If [keyGetter] is true, a getter for the keys is also created.  This compares by length, so
  /// keys should never be updated in place, only added or removed.
  const SettingsHelperMap(this.keyName, {this.keyGetter = false});

  final String keyName;
  final bool keyGetter;

  factory SettingsHelperMap.fromRaw(DartObject obj) {
    return SettingsHelperMap(
      obj.getField("keyName")!.toStringValue()!,
      keyGetter: obj.getField("keyGetter")!.toBoolValue()!,
    );
  }
}
