// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'item_by_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$itemByIdHash() => r'95079a488f7c131f183de0d61ec6d3c463d88969';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [itemById].
@ProviderFor(itemById)
const itemByIdProvider = ItemByIdFamily();

/// See also [itemById].
class ItemByIdFamily extends Family<AsyncValue<BaseItemDto?>> {
  /// See also [itemById].
  const ItemByIdFamily();

  /// See also [itemById].
  ItemByIdProvider call(BaseItemId baseItemId) {
    return ItemByIdProvider(baseItemId);
  }

  @override
  ItemByIdProvider getProviderOverride(covariant ItemByIdProvider provider) {
    return call(provider.baseItemId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'itemByIdProvider';
}

/// See also [itemById].
class ItemByIdProvider extends AutoDisposeFutureProvider<BaseItemDto?> {
  /// See also [itemById].
  ItemByIdProvider(BaseItemId baseItemId)
    : this._internal(
        (ref) => itemById(ref as ItemByIdRef, baseItemId),
        from: itemByIdProvider,
        name: r'itemByIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$itemByIdHash,
        dependencies: ItemByIdFamily._dependencies,
        allTransitiveDependencies: ItemByIdFamily._allTransitiveDependencies,
        baseItemId: baseItemId,
      );

  ItemByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.baseItemId,
  }) : super.internal();

  final BaseItemId baseItemId;

  @override
  Override overrideWith(
    FutureOr<BaseItemDto?> Function(ItemByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ItemByIdProvider._internal(
        (ref) => create(ref as ItemByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        baseItemId: baseItemId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<BaseItemDto?> createElement() {
    return _ItemByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemByIdProvider && other.baseItemId == baseItemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, baseItemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ItemByIdRef on AutoDisposeFutureProviderRef<BaseItemDto?> {
  /// The parameter `baseItemId` of this provider.
  BaseItemId get baseItemId;
}

class _ItemByIdProviderElement
    extends AutoDisposeFutureProviderElement<BaseItemDto?>
    with ItemByIdRef {
  _ItemByIdProviderElement(super.provider);

  @override
  BaseItemId get baseItemId => (origin as ItemByIdProvider).baseItemId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
