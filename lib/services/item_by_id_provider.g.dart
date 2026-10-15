// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'item_by_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(itemById)
final itemByIdProvider = ItemByIdFamily._();

final class ItemByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<BaseItemDto?>,
          BaseItemDto?,
          FutureOr<BaseItemDto?>
        >
    with $FutureModifier<BaseItemDto?>, $FutureProvider<BaseItemDto?> {
  ItemByIdProvider._({
    required ItemByIdFamily super.from,
    required BaseItemId super.argument,
  }) : super(
         retry: null,
         name: r'itemByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemByIdHash();

  @override
  String toString() {
    return r'itemByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BaseItemDto?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BaseItemDto?> create(Ref ref) {
    final argument = this.argument as BaseItemId;
    return itemById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemByIdHash() => r'95079a488f7c131f183de0d61ec6d3c463d88969';

final class ItemByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BaseItemDto?>, BaseItemId> {
  ItemByIdFamily._()
    : super(
        retry: null,
        name: r'itemByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ItemByIdProvider call(BaseItemId baseItemId) =>
      ItemByIdProvider._(argument: baseItemId, from: this);

  @override
  String toString() => r'itemByIdProvider';
}
