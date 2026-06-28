// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'artist_content_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getArtistTracksSectionHash() =>
    r'568e17b713d1e4f47ad71d50093f0c887743145c';

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

/// See also [getArtistTracksSection].
@ProviderFor(getArtistTracksSection)
const getArtistTracksSectionProvider = GetArtistTracksSectionFamily();

/// See also [getArtistTracksSection].
class GetArtistTracksSectionFamily
    extends
        Family<
          AsyncValue<
            (
              List<BaseItemDto>,
              CuratedItemSelectionType,
              Set<CuratedItemSelectionType>?,
            )
          >
        > {
  /// See also [getArtistTracksSection].
  const GetArtistTracksSectionFamily();

  /// See also [getArtistTracksSection].
  GetArtistTracksSectionProvider call({
    required BaseItemDto artist,
    BaseItemDto? libraryFilter,
    BaseItemId? genreFilter,
  }) {
    return GetArtistTracksSectionProvider(
      artist: artist,
      libraryFilter: libraryFilter,
      genreFilter: genreFilter,
    );
  }

  @override
  GetArtistTracksSectionProvider getProviderOverride(
    covariant GetArtistTracksSectionProvider provider,
  ) {
    return call(
      artist: provider.artist,
      libraryFilter: provider.libraryFilter,
      genreFilter: provider.genreFilter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getArtistTracksSectionProvider';
}

/// See also [getArtistTracksSection].
class GetArtistTracksSectionProvider
    extends
        AutoDisposeFutureProvider<
          (
            List<BaseItemDto>,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        > {
  /// See also [getArtistTracksSection].
  GetArtistTracksSectionProvider({
    required BaseItemDto artist,
    BaseItemDto? libraryFilter,
    BaseItemId? genreFilter,
  }) : this._internal(
         (ref) => getArtistTracksSection(
           ref as GetArtistTracksSectionRef,
           artist: artist,
           libraryFilter: libraryFilter,
           genreFilter: genreFilter,
         ),
         from: getArtistTracksSectionProvider,
         name: r'getArtistTracksSectionProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getArtistTracksSectionHash,
         dependencies: GetArtistTracksSectionFamily._dependencies,
         allTransitiveDependencies:
             GetArtistTracksSectionFamily._allTransitiveDependencies,
         artist: artist,
         libraryFilter: libraryFilter,
         genreFilter: genreFilter,
       );

  GetArtistTracksSectionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.artist,
    required this.libraryFilter,
    required this.genreFilter,
  }) : super.internal();

  final BaseItemDto artist;
  final BaseItemDto? libraryFilter;
  final BaseItemId? genreFilter;

  @override
  Override overrideWith(
    FutureOr<
      (
        List<BaseItemDto>,
        CuratedItemSelectionType,
        Set<CuratedItemSelectionType>?,
      )
    >
    Function(GetArtistTracksSectionRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetArtistTracksSectionProvider._internal(
        (ref) => create(ref as GetArtistTracksSectionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        artist: artist,
        libraryFilter: libraryFilter,
        genreFilter: genreFilter,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<
    (
      List<BaseItemDto>,
      CuratedItemSelectionType,
      Set<CuratedItemSelectionType>?,
    )
  >
  createElement() {
    return _GetArtistTracksSectionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetArtistTracksSectionProvider &&
        other.artist == artist &&
        other.libraryFilter == libraryFilter &&
        other.genreFilter == genreFilter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, artist.hashCode);
    hash = _SystemHash.combine(hash, libraryFilter.hashCode);
    hash = _SystemHash.combine(hash, genreFilter.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetArtistTracksSectionRef
    on
        AutoDisposeFutureProviderRef<
          (
            List<BaseItemDto>,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        > {
  /// The parameter `artist` of this provider.
  BaseItemDto get artist;

  /// The parameter `libraryFilter` of this provider.
  BaseItemDto? get libraryFilter;

  /// The parameter `genreFilter` of this provider.
  BaseItemId? get genreFilter;
}

class _GetArtistTracksSectionProviderElement
    extends
        AutoDisposeFutureProviderElement<
          (
            List<BaseItemDto>,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        >
    with GetArtistTracksSectionRef {
  _GetArtistTracksSectionProviderElement(super.provider);

  @override
  BaseItemDto get artist => (origin as GetArtistTracksSectionProvider).artist;
  @override
  BaseItemDto? get libraryFilter =>
      (origin as GetArtistTracksSectionProvider).libraryFilter;
  @override
  BaseItemId? get genreFilter =>
      (origin as GetArtistTracksSectionProvider).genreFilter;
}

String _$getArtistAlbumsHash() => r'9604fbf0b816367ec52ebadceaf2d1ed242dd1b7';

/// See also [getArtistAlbums].
@ProviderFor(getArtistAlbums)
const getArtistAlbumsProvider = GetArtistAlbumsFamily();

/// See also [getArtistAlbums].
class GetArtistAlbumsFamily extends Family<AsyncValue<List<BaseItemDto>>> {
  /// See also [getArtistAlbums].
  const GetArtistAlbumsFamily();

  /// See also [getArtistAlbums].
  GetArtistAlbumsProvider call({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    SortBy sortBy = SortBy.premiereDate,
    SortOrder sortOrder = SortOrder.ascending,
  }) {
    return GetArtistAlbumsProvider(
      artist: artist,
      libraryFilter: libraryFilter,
      genreFilter: genreFilter,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  @override
  GetArtistAlbumsProvider getProviderOverride(
    covariant GetArtistAlbumsProvider provider,
  ) {
    return call(
      artist: provider.artist,
      libraryFilter: provider.libraryFilter,
      genreFilter: provider.genreFilter,
      sortBy: provider.sortBy,
      sortOrder: provider.sortOrder,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getArtistAlbumsProvider';
}

/// See also [getArtistAlbums].
class GetArtistAlbumsProvider
    extends AutoDisposeFutureProvider<List<BaseItemDto>> {
  /// See also [getArtistAlbums].
  GetArtistAlbumsProvider({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    SortBy sortBy = SortBy.premiereDate,
    SortOrder sortOrder = SortOrder.ascending,
  }) : this._internal(
         (ref) => getArtistAlbums(
           ref as GetArtistAlbumsRef,
           artist: artist,
           libraryFilter: libraryFilter,
           genreFilter: genreFilter,
           sortBy: sortBy,
           sortOrder: sortOrder,
         ),
         from: getArtistAlbumsProvider,
         name: r'getArtistAlbumsProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getArtistAlbumsHash,
         dependencies: GetArtistAlbumsFamily._dependencies,
         allTransitiveDependencies:
             GetArtistAlbumsFamily._allTransitiveDependencies,
         artist: artist,
         libraryFilter: libraryFilter,
         genreFilter: genreFilter,
         sortBy: sortBy,
         sortOrder: sortOrder,
       );

  GetArtistAlbumsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.artist,
    required this.libraryFilter,
    required this.genreFilter,
    required this.sortBy,
    required this.sortOrder,
  }) : super.internal();

  final BaseItemDto artist;
  final LibraryId? libraryFilter;
  final BaseItemId? genreFilter;
  final SortBy sortBy;
  final SortOrder sortOrder;

  @override
  Override overrideWith(
    FutureOr<List<BaseItemDto>> Function(GetArtistAlbumsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetArtistAlbumsProvider._internal(
        (ref) => create(ref as GetArtistAlbumsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        artist: artist,
        libraryFilter: libraryFilter,
        genreFilter: genreFilter,
        sortBy: sortBy,
        sortOrder: sortOrder,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BaseItemDto>> createElement() {
    return _GetArtistAlbumsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetArtistAlbumsProvider &&
        other.artist == artist &&
        other.libraryFilter == libraryFilter &&
        other.genreFilter == genreFilter &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, artist.hashCode);
    hash = _SystemHash.combine(hash, libraryFilter.hashCode);
    hash = _SystemHash.combine(hash, genreFilter.hashCode);
    hash = _SystemHash.combine(hash, sortBy.hashCode);
    hash = _SystemHash.combine(hash, sortOrder.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetArtistAlbumsRef on AutoDisposeFutureProviderRef<List<BaseItemDto>> {
  /// The parameter `artist` of this provider.
  BaseItemDto get artist;

  /// The parameter `libraryFilter` of this provider.
  LibraryId? get libraryFilter;

  /// The parameter `genreFilter` of this provider.
  BaseItemId? get genreFilter;

  /// The parameter `sortBy` of this provider.
  SortBy get sortBy;

  /// The parameter `sortOrder` of this provider.
  SortOrder get sortOrder;
}

class _GetArtistAlbumsProviderElement
    extends AutoDisposeFutureProviderElement<List<BaseItemDto>>
    with GetArtistAlbumsRef {
  _GetArtistAlbumsProviderElement(super.provider);

  @override
  BaseItemDto get artist => (origin as GetArtistAlbumsProvider).artist;
  @override
  LibraryId? get libraryFilter =>
      (origin as GetArtistAlbumsProvider).libraryFilter;
  @override
  BaseItemId? get genreFilter =>
      (origin as GetArtistAlbumsProvider).genreFilter;
  @override
  SortBy get sortBy => (origin as GetArtistAlbumsProvider).sortBy;
  @override
  SortOrder get sortOrder => (origin as GetArtistAlbumsProvider).sortOrder;
}

String _$getPerformingArtistAlbumsHash() =>
    r'9dab03f6b5346bfb2e88c4333c5b07f633010b74';

/// See also [getPerformingArtistAlbums].
@ProviderFor(getPerformingArtistAlbums)
const getPerformingArtistAlbumsProvider = GetPerformingArtistAlbumsFamily();

/// See also [getPerformingArtistAlbums].
class GetPerformingArtistAlbumsFamily
    extends Family<AsyncValue<List<BaseItemDto>>> {
  /// See also [getPerformingArtistAlbums].
  const GetPerformingArtistAlbumsFamily();

  /// See also [getPerformingArtistAlbums].
  GetPerformingArtistAlbumsProvider call({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    SortBy sortBy = SortBy.premiereDate,
    SortOrder sortOrder = SortOrder.ascending,
  }) {
    return GetPerformingArtistAlbumsProvider(
      artist: artist,
      libraryFilter: libraryFilter,
      genreFilter: genreFilter,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  @override
  GetPerformingArtistAlbumsProvider getProviderOverride(
    covariant GetPerformingArtistAlbumsProvider provider,
  ) {
    return call(
      artist: provider.artist,
      libraryFilter: provider.libraryFilter,
      genreFilter: provider.genreFilter,
      sortBy: provider.sortBy,
      sortOrder: provider.sortOrder,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getPerformingArtistAlbumsProvider';
}

/// See also [getPerformingArtistAlbums].
class GetPerformingArtistAlbumsProvider
    extends AutoDisposeFutureProvider<List<BaseItemDto>> {
  /// See also [getPerformingArtistAlbums].
  GetPerformingArtistAlbumsProvider({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    SortBy sortBy = SortBy.premiereDate,
    SortOrder sortOrder = SortOrder.ascending,
  }) : this._internal(
         (ref) => getPerformingArtistAlbums(
           ref as GetPerformingArtistAlbumsRef,
           artist: artist,
           libraryFilter: libraryFilter,
           genreFilter: genreFilter,
           sortBy: sortBy,
           sortOrder: sortOrder,
         ),
         from: getPerformingArtistAlbumsProvider,
         name: r'getPerformingArtistAlbumsProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getPerformingArtistAlbumsHash,
         dependencies: GetPerformingArtistAlbumsFamily._dependencies,
         allTransitiveDependencies:
             GetPerformingArtistAlbumsFamily._allTransitiveDependencies,
         artist: artist,
         libraryFilter: libraryFilter,
         genreFilter: genreFilter,
         sortBy: sortBy,
         sortOrder: sortOrder,
       );

  GetPerformingArtistAlbumsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.artist,
    required this.libraryFilter,
    required this.genreFilter,
    required this.sortBy,
    required this.sortOrder,
  }) : super.internal();

  final BaseItemDto artist;
  final LibraryId? libraryFilter;
  final BaseItemId? genreFilter;
  final SortBy sortBy;
  final SortOrder sortOrder;

  @override
  Override overrideWith(
    FutureOr<List<BaseItemDto>> Function(GetPerformingArtistAlbumsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetPerformingArtistAlbumsProvider._internal(
        (ref) => create(ref as GetPerformingArtistAlbumsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        artist: artist,
        libraryFilter: libraryFilter,
        genreFilter: genreFilter,
        sortBy: sortBy,
        sortOrder: sortOrder,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BaseItemDto>> createElement() {
    return _GetPerformingArtistAlbumsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetPerformingArtistAlbumsProvider &&
        other.artist == artist &&
        other.libraryFilter == libraryFilter &&
        other.genreFilter == genreFilter &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, artist.hashCode);
    hash = _SystemHash.combine(hash, libraryFilter.hashCode);
    hash = _SystemHash.combine(hash, genreFilter.hashCode);
    hash = _SystemHash.combine(hash, sortBy.hashCode);
    hash = _SystemHash.combine(hash, sortOrder.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetPerformingArtistAlbumsRef
    on AutoDisposeFutureProviderRef<List<BaseItemDto>> {
  /// The parameter `artist` of this provider.
  BaseItemDto get artist;

  /// The parameter `libraryFilter` of this provider.
  LibraryId? get libraryFilter;

  /// The parameter `genreFilter` of this provider.
  BaseItemId? get genreFilter;

  /// The parameter `sortBy` of this provider.
  SortBy get sortBy;

  /// The parameter `sortOrder` of this provider.
  SortOrder get sortOrder;
}

class _GetPerformingArtistAlbumsProviderElement
    extends AutoDisposeFutureProviderElement<List<BaseItemDto>>
    with GetPerformingArtistAlbumsRef {
  _GetPerformingArtistAlbumsProviderElement(super.provider);

  @override
  BaseItemDto get artist =>
      (origin as GetPerformingArtistAlbumsProvider).artist;
  @override
  LibraryId? get libraryFilter =>
      (origin as GetPerformingArtistAlbumsProvider).libraryFilter;
  @override
  BaseItemId? get genreFilter =>
      (origin as GetPerformingArtistAlbumsProvider).genreFilter;
  @override
  SortBy get sortBy => (origin as GetPerformingArtistAlbumsProvider).sortBy;
  @override
  SortOrder get sortOrder =>
      (origin as GetPerformingArtistAlbumsProvider).sortOrder;
}

String _$getPerformingArtistTracksHash() =>
    r'2bf1c967f60b7500e63aa849972e549497b43356';

/// See also [getPerformingArtistTracks].
@ProviderFor(getPerformingArtistTracks)
const getPerformingArtistTracksProvider = GetPerformingArtistTracksFamily();

/// See also [getPerformingArtistTracks].
class GetPerformingArtistTracksFamily
    extends Family<AsyncValue<List<BaseItemDto>>> {
  /// See also [getPerformingArtistTracks].
  const GetPerformingArtistTracksFamily();

  /// See also [getPerformingArtistTracks].
  GetPerformingArtistTracksProvider call({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    bool onlyFavorites = false,
  }) {
    return GetPerformingArtistTracksProvider(
      artist: artist,
      libraryFilter: libraryFilter,
      genreFilter: genreFilter,
      onlyFavorites: onlyFavorites,
    );
  }

  @override
  GetPerformingArtistTracksProvider getProviderOverride(
    covariant GetPerformingArtistTracksProvider provider,
  ) {
    return call(
      artist: provider.artist,
      libraryFilter: provider.libraryFilter,
      genreFilter: provider.genreFilter,
      onlyFavorites: provider.onlyFavorites,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getPerformingArtistTracksProvider';
}

/// See also [getPerformingArtistTracks].
class GetPerformingArtistTracksProvider
    extends AutoDisposeFutureProvider<List<BaseItemDto>> {
  /// See also [getPerformingArtistTracks].
  GetPerformingArtistTracksProvider({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    bool onlyFavorites = false,
  }) : this._internal(
         (ref) => getPerformingArtistTracks(
           ref as GetPerformingArtistTracksRef,
           artist: artist,
           libraryFilter: libraryFilter,
           genreFilter: genreFilter,
           onlyFavorites: onlyFavorites,
         ),
         from: getPerformingArtistTracksProvider,
         name: r'getPerformingArtistTracksProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getPerformingArtistTracksHash,
         dependencies: GetPerformingArtistTracksFamily._dependencies,
         allTransitiveDependencies:
             GetPerformingArtistTracksFamily._allTransitiveDependencies,
         artist: artist,
         libraryFilter: libraryFilter,
         genreFilter: genreFilter,
         onlyFavorites: onlyFavorites,
       );

  GetPerformingArtistTracksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.artist,
    required this.libraryFilter,
    required this.genreFilter,
    required this.onlyFavorites,
  }) : super.internal();

  final BaseItemDto artist;
  final LibraryId? libraryFilter;
  final BaseItemId? genreFilter;
  final bool onlyFavorites;

  @override
  Override overrideWith(
    FutureOr<List<BaseItemDto>> Function(GetPerformingArtistTracksRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetPerformingArtistTracksProvider._internal(
        (ref) => create(ref as GetPerformingArtistTracksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        artist: artist,
        libraryFilter: libraryFilter,
        genreFilter: genreFilter,
        onlyFavorites: onlyFavorites,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BaseItemDto>> createElement() {
    return _GetPerformingArtistTracksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetPerformingArtistTracksProvider &&
        other.artist == artist &&
        other.libraryFilter == libraryFilter &&
        other.genreFilter == genreFilter &&
        other.onlyFavorites == onlyFavorites;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, artist.hashCode);
    hash = _SystemHash.combine(hash, libraryFilter.hashCode);
    hash = _SystemHash.combine(hash, genreFilter.hashCode);
    hash = _SystemHash.combine(hash, onlyFavorites.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetPerformingArtistTracksRef
    on AutoDisposeFutureProviderRef<List<BaseItemDto>> {
  /// The parameter `artist` of this provider.
  BaseItemDto get artist;

  /// The parameter `libraryFilter` of this provider.
  LibraryId? get libraryFilter;

  /// The parameter `genreFilter` of this provider.
  BaseItemId? get genreFilter;

  /// The parameter `onlyFavorites` of this provider.
  bool get onlyFavorites;
}

class _GetPerformingArtistTracksProviderElement
    extends AutoDisposeFutureProviderElement<List<BaseItemDto>>
    with GetPerformingArtistTracksRef {
  _GetPerformingArtistTracksProviderElement(super.provider);

  @override
  BaseItemDto get artist =>
      (origin as GetPerformingArtistTracksProvider).artist;
  @override
  LibraryId? get libraryFilter =>
      (origin as GetPerformingArtistTracksProvider).libraryFilter;
  @override
  BaseItemId? get genreFilter =>
      (origin as GetPerformingArtistTracksProvider).genreFilter;
  @override
  bool get onlyFavorites =>
      (origin as GetPerformingArtistTracksProvider).onlyFavorites;
}

String _$getArtistTracksHash() => r'8d1b6456b713dcd0e56dfcade5a6f4f12ee02b66';

/// See also [getArtistTracks].
@ProviderFor(getArtistTracks)
const getArtistTracksProvider = GetArtistTracksFamily();

/// See also [getArtistTracks].
class GetArtistTracksFamily extends Family<AsyncValue<List<BaseItemDto>>> {
  /// See also [getArtistTracks].
  const GetArtistTracksFamily();

  /// See also [getArtistTracks].
  GetArtistTracksProvider call({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    bool onlyFavorites = false,
  }) {
    return GetArtistTracksProvider(
      artist: artist,
      libraryFilter: libraryFilter,
      genreFilter: genreFilter,
      onlyFavorites: onlyFavorites,
    );
  }

  @override
  GetArtistTracksProvider getProviderOverride(
    covariant GetArtistTracksProvider provider,
  ) {
    return call(
      artist: provider.artist,
      libraryFilter: provider.libraryFilter,
      genreFilter: provider.genreFilter,
      onlyFavorites: provider.onlyFavorites,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getArtistTracksProvider';
}

/// See also [getArtistTracks].
class GetArtistTracksProvider
    extends AutoDisposeFutureProvider<List<BaseItemDto>> {
  /// See also [getArtistTracks].
  GetArtistTracksProvider({
    required BaseItemDto artist,
    LibraryId? libraryFilter,
    BaseItemId? genreFilter,
    bool onlyFavorites = false,
  }) : this._internal(
         (ref) => getArtistTracks(
           ref as GetArtistTracksRef,
           artist: artist,
           libraryFilter: libraryFilter,
           genreFilter: genreFilter,
           onlyFavorites: onlyFavorites,
         ),
         from: getArtistTracksProvider,
         name: r'getArtistTracksProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getArtistTracksHash,
         dependencies: GetArtistTracksFamily._dependencies,
         allTransitiveDependencies:
             GetArtistTracksFamily._allTransitiveDependencies,
         artist: artist,
         libraryFilter: libraryFilter,
         genreFilter: genreFilter,
         onlyFavorites: onlyFavorites,
       );

  GetArtistTracksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.artist,
    required this.libraryFilter,
    required this.genreFilter,
    required this.onlyFavorites,
  }) : super.internal();

  final BaseItemDto artist;
  final LibraryId? libraryFilter;
  final BaseItemId? genreFilter;
  final bool onlyFavorites;

  @override
  Override overrideWith(
    FutureOr<List<BaseItemDto>> Function(GetArtistTracksRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetArtistTracksProvider._internal(
        (ref) => create(ref as GetArtistTracksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        artist: artist,
        libraryFilter: libraryFilter,
        genreFilter: genreFilter,
        onlyFavorites: onlyFavorites,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BaseItemDto>> createElement() {
    return _GetArtistTracksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetArtistTracksProvider &&
        other.artist == artist &&
        other.libraryFilter == libraryFilter &&
        other.genreFilter == genreFilter &&
        other.onlyFavorites == onlyFavorites;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, artist.hashCode);
    hash = _SystemHash.combine(hash, libraryFilter.hashCode);
    hash = _SystemHash.combine(hash, genreFilter.hashCode);
    hash = _SystemHash.combine(hash, onlyFavorites.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetArtistTracksRef on AutoDisposeFutureProviderRef<List<BaseItemDto>> {
  /// The parameter `artist` of this provider.
  BaseItemDto get artist;

  /// The parameter `libraryFilter` of this provider.
  LibraryId? get libraryFilter;

  /// The parameter `genreFilter` of this provider.
  BaseItemId? get genreFilter;

  /// The parameter `onlyFavorites` of this provider.
  bool get onlyFavorites;
}

class _GetArtistTracksProviderElement
    extends AutoDisposeFutureProviderElement<List<BaseItemDto>>
    with GetArtistTracksRef {
  _GetArtistTracksProviderElement(super.provider);

  @override
  BaseItemDto get artist => (origin as GetArtistTracksProvider).artist;
  @override
  LibraryId? get libraryFilter =>
      (origin as GetArtistTracksProvider).libraryFilter;
  @override
  BaseItemId? get genreFilter =>
      (origin as GetArtistTracksProvider).genreFilter;
  @override
  bool get onlyFavorites => (origin as GetArtistTracksProvider).onlyFavorites;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
