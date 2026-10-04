// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'genre_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$genreCuratedItemsHash() => r'1444246d44d2ce4891a88afa17221d421a28b02c';

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

/// See also [genreCuratedItems].
@ProviderFor(genreCuratedItems)
const genreCuratedItemsProvider = GenreCuratedItemsFamily();

/// See also [genreCuratedItems].
class GenreCuratedItemsFamily
    extends
        Family<
          AsyncValue<
            (
              List<BaseItemDto>,
              int,
              CuratedItemSelectionType,
              Set<CuratedItemSelectionType>?,
            )
          >
        > {
  /// See also [genreCuratedItems].
  const GenreCuratedItemsFamily();

  /// See also [genreCuratedItems].
  GenreCuratedItemsProvider call(
    BaseItemDto parent,
    BaseItemDtoType baseItemType,
    LibraryId? library,
  ) {
    return GenreCuratedItemsProvider(parent, baseItemType, library);
  }

  @override
  GenreCuratedItemsProvider getProviderOverride(
    covariant GenreCuratedItemsProvider provider,
  ) {
    return call(provider.parent, provider.baseItemType, provider.library);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'genreCuratedItemsProvider';
}

/// See also [genreCuratedItems].
class GenreCuratedItemsProvider
    extends
        AutoDisposeFutureProvider<
          (
            List<BaseItemDto>,
            int,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        > {
  /// See also [genreCuratedItems].
  GenreCuratedItemsProvider(
    BaseItemDto parent,
    BaseItemDtoType baseItemType,
    LibraryId? library,
  ) : this._internal(
        (ref) => genreCuratedItems(
          ref as GenreCuratedItemsRef,
          parent,
          baseItemType,
          library,
        ),
        from: genreCuratedItemsProvider,
        name: r'genreCuratedItemsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$genreCuratedItemsHash,
        dependencies: GenreCuratedItemsFamily._dependencies,
        allTransitiveDependencies:
            GenreCuratedItemsFamily._allTransitiveDependencies,
        parent: parent,
        baseItemType: baseItemType,
        library: library,
      );

  GenreCuratedItemsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.parent,
    required this.baseItemType,
    required this.library,
  }) : super.internal();

  final BaseItemDto parent;
  final BaseItemDtoType baseItemType;
  final LibraryId? library;

  @override
  Override overrideWith(
    FutureOr<
      (
        List<BaseItemDto>,
        int,
        CuratedItemSelectionType,
        Set<CuratedItemSelectionType>?,
      )
    >
    Function(GenreCuratedItemsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GenreCuratedItemsProvider._internal(
        (ref) => create(ref as GenreCuratedItemsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        parent: parent,
        baseItemType: baseItemType,
        library: library,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<
    (
      List<BaseItemDto>,
      int,
      CuratedItemSelectionType,
      Set<CuratedItemSelectionType>?,
    )
  >
  createElement() {
    return _GenreCuratedItemsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GenreCuratedItemsProvider &&
        other.parent == parent &&
        other.baseItemType == baseItemType &&
        other.library == library;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, parent.hashCode);
    hash = _SystemHash.combine(hash, baseItemType.hashCode);
    hash = _SystemHash.combine(hash, library.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GenreCuratedItemsRef
    on
        AutoDisposeFutureProviderRef<
          (
            List<BaseItemDto>,
            int,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        > {
  /// The parameter `parent` of this provider.
  BaseItemDto get parent;

  /// The parameter `baseItemType` of this provider.
  BaseItemDtoType get baseItemType;

  /// The parameter `library` of this provider.
  LibraryId? get library;
}

class _GenreCuratedItemsProviderElement
    extends
        AutoDisposeFutureProviderElement<
          (
            List<BaseItemDto>,
            int,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        >
    with GenreCuratedItemsRef {
  _GenreCuratedItemsProviderElement(super.provider);

  @override
  BaseItemDto get parent => (origin as GenreCuratedItemsProvider).parent;
  @override
  BaseItemDtoType get baseItemType =>
      (origin as GenreCuratedItemsProvider).baseItemType;
  @override
  LibraryId? get library => (origin as GenreCuratedItemsProvider).library;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
