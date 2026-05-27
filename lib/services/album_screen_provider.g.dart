// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'album_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getAlbumOrPlaylistTracksHash() =>
    r'682b95290e0c4a38835f7e441dca88174b73d695';

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

/// See also [getAlbumOrPlaylistTracks].
@ProviderFor(getAlbumOrPlaylistTracks)
const getAlbumOrPlaylistTracksProvider = GetAlbumOrPlaylistTracksFamily();

/// See also [getAlbumOrPlaylistTracks].
class GetAlbumOrPlaylistTracksFamily
    extends Family<AsyncValue<(List<BaseItemDto>, List<BaseItemDto>)>> {
  /// See also [getAlbumOrPlaylistTracks].
  const GetAlbumOrPlaylistTracksFamily();

  /// See also [getAlbumOrPlaylistTracks].
  GetAlbumOrPlaylistTracksProvider call(BaseItemDto parent) {
    return GetAlbumOrPlaylistTracksProvider(parent);
  }

  @override
  GetAlbumOrPlaylistTracksProvider getProviderOverride(
    covariant GetAlbumOrPlaylistTracksProvider provider,
  ) {
    return call(provider.parent);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getAlbumOrPlaylistTracksProvider';
}

/// See also [getAlbumOrPlaylistTracks].
class GetAlbumOrPlaylistTracksProvider
    extends AutoDisposeFutureProvider<(List<BaseItemDto>, List<BaseItemDto>)> {
  /// See also [getAlbumOrPlaylistTracks].
  GetAlbumOrPlaylistTracksProvider(BaseItemDto parent)
    : this._internal(
        (ref) => getAlbumOrPlaylistTracks(
          ref as GetAlbumOrPlaylistTracksRef,
          parent,
        ),
        from: getAlbumOrPlaylistTracksProvider,
        name: r'getAlbumOrPlaylistTracksProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getAlbumOrPlaylistTracksHash,
        dependencies: GetAlbumOrPlaylistTracksFamily._dependencies,
        allTransitiveDependencies:
            GetAlbumOrPlaylistTracksFamily._allTransitiveDependencies,
        parent: parent,
      );

  GetAlbumOrPlaylistTracksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.parent,
  }) : super.internal();

  final BaseItemDto parent;

  @override
  Override overrideWith(
    FutureOr<(List<BaseItemDto>, List<BaseItemDto>)> Function(
      GetAlbumOrPlaylistTracksRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetAlbumOrPlaylistTracksProvider._internal(
        (ref) => create(ref as GetAlbumOrPlaylistTracksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        parent: parent,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)>
  createElement() {
    return _GetAlbumOrPlaylistTracksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetAlbumOrPlaylistTracksProvider && other.parent == parent;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, parent.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetAlbumOrPlaylistTracksRef
    on AutoDisposeFutureProviderRef<(List<BaseItemDto>, List<BaseItemDto>)> {
  /// The parameter `parent` of this provider.
  BaseItemDto get parent;
}

class _GetAlbumOrPlaylistTracksProviderElement
    extends
        AutoDisposeFutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)>
    with GetAlbumOrPlaylistTracksRef {
  _GetAlbumOrPlaylistTracksProviderElement(super.provider);

  @override
  BaseItemDto get parent => (origin as GetAlbumOrPlaylistTracksProvider).parent;
}

String _$getDefaultSortedPlaylistTracksHash() =>
    r'38b604cd5f85a459804c174426a400065db8ce9e';

/// See also [getDefaultSortedPlaylistTracks].
@ProviderFor(getDefaultSortedPlaylistTracks)
const getDefaultSortedPlaylistTracksProvider =
    GetDefaultSortedPlaylistTracksFamily();

/// See also [getDefaultSortedPlaylistTracks].
class GetDefaultSortedPlaylistTracksFamily
    extends Family<AsyncValue<(List<BaseItemDto>, List<BaseItemDto>)>> {
  /// See also [getDefaultSortedPlaylistTracks].
  const GetDefaultSortedPlaylistTracksFamily();

  /// See also [getDefaultSortedPlaylistTracks].
  GetDefaultSortedPlaylistTracksProvider call(BaseItemDto parent) {
    return GetDefaultSortedPlaylistTracksProvider(parent);
  }

  @override
  GetDefaultSortedPlaylistTracksProvider getProviderOverride(
    covariant GetDefaultSortedPlaylistTracksProvider provider,
  ) {
    return call(provider.parent);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getDefaultSortedPlaylistTracksProvider';
}

/// See also [getDefaultSortedPlaylistTracks].
class GetDefaultSortedPlaylistTracksProvider
    extends AutoDisposeFutureProvider<(List<BaseItemDto>, List<BaseItemDto>)> {
  /// See also [getDefaultSortedPlaylistTracks].
  GetDefaultSortedPlaylistTracksProvider(BaseItemDto parent)
    : this._internal(
        (ref) => getDefaultSortedPlaylistTracks(
          ref as GetDefaultSortedPlaylistTracksRef,
          parent,
        ),
        from: getDefaultSortedPlaylistTracksProvider,
        name: r'getDefaultSortedPlaylistTracksProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getDefaultSortedPlaylistTracksHash,
        dependencies: GetDefaultSortedPlaylistTracksFamily._dependencies,
        allTransitiveDependencies:
            GetDefaultSortedPlaylistTracksFamily._allTransitiveDependencies,
        parent: parent,
      );

  GetDefaultSortedPlaylistTracksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.parent,
  }) : super.internal();

  final BaseItemDto parent;

  @override
  Override overrideWith(
    FutureOr<(List<BaseItemDto>, List<BaseItemDto>)> Function(
      GetDefaultSortedPlaylistTracksRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetDefaultSortedPlaylistTracksProvider._internal(
        (ref) => create(ref as GetDefaultSortedPlaylistTracksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        parent: parent,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)>
  createElement() {
    return _GetDefaultSortedPlaylistTracksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetDefaultSortedPlaylistTracksProvider &&
        other.parent == parent;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, parent.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetDefaultSortedPlaylistTracksRef
    on AutoDisposeFutureProviderRef<(List<BaseItemDto>, List<BaseItemDto>)> {
  /// The parameter `parent` of this provider.
  BaseItemDto get parent;
}

class _GetDefaultSortedPlaylistTracksProviderElement
    extends
        AutoDisposeFutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)>
    with GetDefaultSortedPlaylistTracksRef {
  _GetDefaultSortedPlaylistTracksProviderElement(super.provider);

  @override
  BaseItemDto get parent =>
      (origin as GetDefaultSortedPlaylistTracksProvider).parent;
}

String _$getSortedPlaylistTracksHash() =>
    r'b1a38a61289c3bbe1d0939f15ff0ca19e22e4da4';

/// See also [getSortedPlaylistTracks].
@ProviderFor(getSortedPlaylistTracks)
const getSortedPlaylistTracksProvider = GetSortedPlaylistTracksFamily();

/// See also [getSortedPlaylistTracks].
class GetSortedPlaylistTracksFamily
    extends Family<AsyncValue<(List<BaseItemDto>, List<BaseItemDto>)>> {
  /// See also [getSortedPlaylistTracks].
  const GetSortedPlaylistTracksFamily();

  /// See also [getSortedPlaylistTracks].
  GetSortedPlaylistTracksProvider call(
    BaseItemDto parent,
    SortAndFilterConfiguration sortConfig,
  ) {
    return GetSortedPlaylistTracksProvider(parent, sortConfig);
  }

  @override
  GetSortedPlaylistTracksProvider getProviderOverride(
    covariant GetSortedPlaylistTracksProvider provider,
  ) {
    return call(provider.parent, provider.sortConfig);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getSortedPlaylistTracksProvider';
}

/// See also [getSortedPlaylistTracks].
class GetSortedPlaylistTracksProvider
    extends AutoDisposeFutureProvider<(List<BaseItemDto>, List<BaseItemDto>)> {
  /// See also [getSortedPlaylistTracks].
  GetSortedPlaylistTracksProvider(
    BaseItemDto parent,
    SortAndFilterConfiguration sortConfig,
  ) : this._internal(
        (ref) => getSortedPlaylistTracks(
          ref as GetSortedPlaylistTracksRef,
          parent,
          sortConfig,
        ),
        from: getSortedPlaylistTracksProvider,
        name: r'getSortedPlaylistTracksProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getSortedPlaylistTracksHash,
        dependencies: GetSortedPlaylistTracksFamily._dependencies,
        allTransitiveDependencies:
            GetSortedPlaylistTracksFamily._allTransitiveDependencies,
        parent: parent,
        sortConfig: sortConfig,
      );

  GetSortedPlaylistTracksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.parent,
    required this.sortConfig,
  }) : super.internal();

  final BaseItemDto parent;
  final SortAndFilterConfiguration sortConfig;

  @override
  Override overrideWith(
    FutureOr<(List<BaseItemDto>, List<BaseItemDto>)> Function(
      GetSortedPlaylistTracksRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetSortedPlaylistTracksProvider._internal(
        (ref) => create(ref as GetSortedPlaylistTracksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        parent: parent,
        sortConfig: sortConfig,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)>
  createElement() {
    return _GetSortedPlaylistTracksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetSortedPlaylistTracksProvider &&
        other.parent == parent &&
        other.sortConfig == sortConfig;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, parent.hashCode);
    hash = _SystemHash.combine(hash, sortConfig.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetSortedPlaylistTracksRef
    on AutoDisposeFutureProviderRef<(List<BaseItemDto>, List<BaseItemDto>)> {
  /// The parameter `parent` of this provider.
  BaseItemDto get parent;

  /// The parameter `sortConfig` of this provider.
  SortAndFilterConfiguration get sortConfig;
}

class _GetSortedPlaylistTracksProviderElement
    extends
        AutoDisposeFutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)>
    with GetSortedPlaylistTracksRef {
  _GetSortedPlaylistTracksProviderElement(super.provider);

  @override
  BaseItemDto get parent => (origin as GetSortedPlaylistTracksProvider).parent;
  @override
  SortAndFilterConfiguration get sortConfig =>
      (origin as GetSortedPlaylistTracksProvider).sortConfig;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
