// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'item_amount_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(itemAmount)
final itemAmountProvider = ItemAmountFamily._();

final class ItemAmountProvider
    extends
        $FunctionalProvider<
          AsyncValue<(int, BaseItemDtoType)>,
          (int, BaseItemDtoType),
          FutureOr<(int, BaseItemDtoType)>
        >
    with
        $FutureModifier<(int, BaseItemDtoType)>,
        $FutureProvider<(int, BaseItemDtoType)> {
  ItemAmountProvider._({
    required ItemAmountFamily super.from,
    required ({BaseItemDto baseItem, bool showTrackCountForArtists})
    super.argument,
  }) : super(
         retry: null,
         name: r'itemAmountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemAmountHash();

  @override
  String toString() {
    return r'itemAmountProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<(int, BaseItemDtoType)> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<(int, BaseItemDtoType)> create(Ref ref) {
    final argument =
        this.argument
            as ({BaseItemDto baseItem, bool showTrackCountForArtists});
    return itemAmount(
      ref,
      baseItem: argument.baseItem,
      showTrackCountForArtists: argument.showTrackCountForArtists,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ItemAmountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemAmountHash() => r'6ea3d358f4b728c82d2009c7f287cde70a16a363';

final class ItemAmountFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<(int, BaseItemDtoType)>,
          ({BaseItemDto baseItem, bool showTrackCountForArtists})
        > {
  ItemAmountFamily._()
    : super(
        retry: null,
        name: r'itemAmountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ItemAmountProvider call({
    required BaseItemDto baseItem,
    bool showTrackCountForArtists = false,
  }) => ItemAmountProvider._(
    argument: (
      baseItem: baseItem,
      showTrackCountForArtists: showTrackCountForArtists,
    ),
    from: this,
  );

  @override
  String toString() => r'itemAmountProvider';
}

@ProviderFor(childItemType)
final childItemTypeProvider = ChildItemTypeFamily._();

final class ChildItemTypeProvider
    extends
        $FunctionalProvider<BaseItemDtoType, BaseItemDtoType, BaseItemDtoType>
    with $Provider<BaseItemDtoType> {
  ChildItemTypeProvider._({
    required ChildItemTypeFamily super.from,
    required BaseItemDto super.argument,
  }) : super(
         retry: null,
         name: r'childItemTypeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$childItemTypeHash();

  @override
  String toString() {
    return r'childItemTypeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<BaseItemDtoType> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BaseItemDtoType create(Ref ref) {
    final argument = this.argument as BaseItemDto;
    return childItemType(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BaseItemDtoType value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BaseItemDtoType>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChildItemTypeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$childItemTypeHash() => r'c65893697d022dbe49bb11327dd9d9df3cbdfc49';

final class ChildItemTypeFamily extends $Family
    with $FunctionalFamilyOverride<BaseItemDtoType, BaseItemDto> {
  ChildItemTypeFamily._()
    : super(
        retry: null,
        name: r'childItemTypeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChildItemTypeProvider call(BaseItemDto item) =>
      ChildItemTypeProvider._(argument: item, from: this);

  @override
  String toString() => r'childItemTypeProvider';
}
