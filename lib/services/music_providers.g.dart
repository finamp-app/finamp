// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'music_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$globalSearchHash() => r'629baea3ff8943df78747a6e6804455125ae7136';

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

/// See also [globalSearch].
@ProviderFor(globalSearch)
const globalSearchProvider = GlobalSearchFamily();

/// See also [globalSearch].
class GlobalSearchFamily extends Family<AsyncValue<List<BaseItemDto>>> {
  /// See also [globalSearch].
  const GlobalSearchFamily();

  /// See also [globalSearch].
  GlobalSearchProvider call(String searchTerm, {required bool includeTracks}) {
    return GlobalSearchProvider(searchTerm, includeTracks: includeTracks);
  }

  @override
  GlobalSearchProvider getProviderOverride(
    covariant GlobalSearchProvider provider,
  ) {
    return call(provider.searchTerm, includeTracks: provider.includeTracks);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'globalSearchProvider';
}

/// See also [globalSearch].
class GlobalSearchProvider
    extends AutoDisposeFutureProvider<List<BaseItemDto>> {
  /// See also [globalSearch].
  GlobalSearchProvider(String searchTerm, {required bool includeTracks})
    : this._internal(
        (ref) => globalSearch(
          ref as GlobalSearchRef,
          searchTerm,
          includeTracks: includeTracks,
        ),
        from: globalSearchProvider,
        name: r'globalSearchProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$globalSearchHash,
        dependencies: GlobalSearchFamily._dependencies,
        allTransitiveDependencies:
            GlobalSearchFamily._allTransitiveDependencies,
        searchTerm: searchTerm,
        includeTracks: includeTracks,
      );

  GlobalSearchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.searchTerm,
    required this.includeTracks,
  }) : super.internal();

  final String searchTerm;
  final bool includeTracks;

  @override
  Override overrideWith(
    FutureOr<List<BaseItemDto>> Function(GlobalSearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GlobalSearchProvider._internal(
        (ref) => create(ref as GlobalSearchRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        searchTerm: searchTerm,
        includeTracks: includeTracks,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BaseItemDto>> createElement() {
    return _GlobalSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GlobalSearchProvider &&
        other.searchTerm == searchTerm &&
        other.includeTracks == includeTracks;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, searchTerm.hashCode);
    hash = _SystemHash.combine(hash, includeTracks.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GlobalSearchRef on AutoDisposeFutureProviderRef<List<BaseItemDto>> {
  /// The parameter `searchTerm` of this provider.
  String get searchTerm;

  /// The parameter `includeTracks` of this provider.
  bool get includeTracks;
}

class _GlobalSearchProviderElement
    extends AutoDisposeFutureProviderElement<List<BaseItemDto>>
    with GlobalSearchRef {
  _GlobalSearchProviderElement(super.provider);

  @override
  String get searchTerm => (origin as GlobalSearchProvider).searchTerm;
  @override
  bool get includeTracks => (origin as GlobalSearchProvider).includeTracks;
}

String _$resolveSectionHash() => r'fb1ca99c7145fa70fc9bbf931029039584829f8c';

/// See also [resolveSection].
@ProviderFor(resolveSection)
const resolveSectionProvider = ResolveSectionFamily();

/// See also [resolveSection].
class ResolveSectionFamily
    extends Family<AsyncValue<FinampDisplayable<FinampPlayable>>> {
  /// See also [resolveSection].
  const ResolveSectionFamily();

  /// See also [resolveSection].
  ResolveSectionProvider call(HomeScreenSectionConfiguration section) {
    return ResolveSectionProvider(section);
  }

  @override
  ResolveSectionProvider getProviderOverride(
    covariant ResolveSectionProvider provider,
  ) {
    return call(provider.section);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'resolveSectionProvider';
}

/// See also [resolveSection].
class ResolveSectionProvider
    extends FutureProvider<FinampDisplayable<FinampPlayable>> {
  /// See also [resolveSection].
  ResolveSectionProvider(HomeScreenSectionConfiguration section)
    : this._internal(
        (ref) => resolveSection(ref as ResolveSectionRef, section),
        from: resolveSectionProvider,
        name: r'resolveSectionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$resolveSectionHash,
        dependencies: ResolveSectionFamily._dependencies,
        allTransitiveDependencies:
            ResolveSectionFamily._allTransitiveDependencies,
        section: section,
      );

  ResolveSectionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.section,
  }) : super.internal();

  final HomeScreenSectionConfiguration section;

  @override
  Override overrideWith(
    FutureOr<FinampDisplayable<FinampPlayable>> Function(
      ResolveSectionRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ResolveSectionProvider._internal(
        (ref) => create(ref as ResolveSectionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        section: section,
      ),
    );
  }

  @override
  FutureProviderElement<FinampDisplayable<FinampPlayable>> createElement() {
    return _ResolveSectionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ResolveSectionProvider && other.section == section;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, section.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ResolveSectionRef
    on FutureProviderRef<FinampDisplayable<FinampPlayable>> {
  /// The parameter `section` of this provider.
  HomeScreenSectionConfiguration get section;
}

class _ResolveSectionProviderElement
    extends FutureProviderElement<FinampDisplayable<FinampPlayable>>
    with ResolveSectionRef {
  _ResolveSectionProviderElement(super.provider);

  @override
  HomeScreenSectionConfiguration get section =>
      (origin as ResolveSectionProvider).section;
}

String _$getPlayableSliceHash() => r'a7de6c8ea850e99401cdae69950743ea398e1370';

/// See also [getPlayableSlice].
@ProviderFor(getPlayableSlice)
const getPlayableSliceProvider = GetPlayableSliceFamily();

/// See also [getPlayableSlice].
class GetPlayableSliceFamily extends Family<AsyncValue<PlayableSlice>> {
  /// See also [getPlayableSlice].
  const GetPlayableSliceFamily();

  /// See also [getPlayableSlice].
  GetPlayableSliceProvider call({
    required FinampPlayable item,
    required int startingOffset,
    int? limit,
  }) {
    return GetPlayableSliceProvider(
      item: item,
      startingOffset: startingOffset,
      limit: limit,
    );
  }

  @override
  GetPlayableSliceProvider getProviderOverride(
    covariant GetPlayableSliceProvider provider,
  ) {
    return call(
      item: provider.item,
      startingOffset: provider.startingOffset,
      limit: provider.limit,
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
  String? get name => r'getPlayableSliceProvider';
}

/// See also [getPlayableSlice].
class GetPlayableSliceProvider
    extends AutoDisposeFutureProvider<PlayableSlice> {
  /// See also [getPlayableSlice].
  GetPlayableSliceProvider({
    required FinampPlayable item,
    required int startingOffset,
    int? limit,
  }) : this._internal(
         (ref) => getPlayableSlice(
           ref as GetPlayableSliceRef,
           item: item,
           startingOffset: startingOffset,
           limit: limit,
         ),
         from: getPlayableSliceProvider,
         name: r'getPlayableSliceProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getPlayableSliceHash,
         dependencies: GetPlayableSliceFamily._dependencies,
         allTransitiveDependencies:
             GetPlayableSliceFamily._allTransitiveDependencies,
         item: item,
         startingOffset: startingOffset,
         limit: limit,
       );

  GetPlayableSliceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.item,
    required this.startingOffset,
    required this.limit,
  }) : super.internal();

  final FinampPlayable item;
  final int startingOffset;
  final int? limit;

  @override
  Override overrideWith(
    FutureOr<PlayableSlice> Function(GetPlayableSliceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetPlayableSliceProvider._internal(
        (ref) => create(ref as GetPlayableSliceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        item: item,
        startingOffset: startingOffset,
        limit: limit,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PlayableSlice> createElement() {
    return _GetPlayableSliceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetPlayableSliceProvider &&
        other.item == item &&
        other.startingOffset == startingOffset &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, item.hashCode);
    hash = _SystemHash.combine(hash, startingOffset.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetPlayableSliceRef on AutoDisposeFutureProviderRef<PlayableSlice> {
  /// The parameter `item` of this provider.
  FinampPlayable get item;

  /// The parameter `startingOffset` of this provider.
  int get startingOffset;

  /// The parameter `limit` of this provider.
  int? get limit;
}

class _GetPlayableSliceProviderElement
    extends AutoDisposeFutureProviderElement<PlayableSlice>
    with GetPlayableSliceRef {
  _GetPlayableSliceProviderElement(super.provider);

  @override
  FinampPlayable get item => (origin as GetPlayableSliceProvider).item;
  @override
  int get startingOffset => (origin as GetPlayableSliceProvider).startingOffset;
  @override
  int? get limit => (origin as GetPlayableSliceProvider).limit;
}

String _$getAlbumShuffledPlayerSliceHash() =>
    r'230a194145a309c3a69f5f80fe062400ae278e1a';

/// See also [getAlbumShuffledPlayerSlice].
@ProviderFor(getAlbumShuffledPlayerSlice)
const getAlbumShuffledPlayerSliceProvider = GetAlbumShuffledPlayerSliceFamily();

/// See also [getAlbumShuffledPlayerSlice].
class GetAlbumShuffledPlayerSliceFamily
    extends Family<AsyncValue<PlayableSlice>> {
  /// See also [getAlbumShuffledPlayerSlice].
  const GetAlbumShuffledPlayerSliceFamily();

  /// See also [getAlbumShuffledPlayerSlice].
  GetAlbumShuffledPlayerSliceProvider call({required FinampPlayable item}) {
    return GetAlbumShuffledPlayerSliceProvider(item: item);
  }

  @override
  GetAlbumShuffledPlayerSliceProvider getProviderOverride(
    covariant GetAlbumShuffledPlayerSliceProvider provider,
  ) {
    return call(item: provider.item);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getAlbumShuffledPlayerSliceProvider';
}

/// See also [getAlbumShuffledPlayerSlice].
class GetAlbumShuffledPlayerSliceProvider
    extends AutoDisposeFutureProvider<PlayableSlice> {
  /// See also [getAlbumShuffledPlayerSlice].
  GetAlbumShuffledPlayerSliceProvider({required FinampPlayable item})
    : this._internal(
        (ref) => getAlbumShuffledPlayerSlice(
          ref as GetAlbumShuffledPlayerSliceRef,
          item: item,
        ),
        from: getAlbumShuffledPlayerSliceProvider,
        name: r'getAlbumShuffledPlayerSliceProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getAlbumShuffledPlayerSliceHash,
        dependencies: GetAlbumShuffledPlayerSliceFamily._dependencies,
        allTransitiveDependencies:
            GetAlbumShuffledPlayerSliceFamily._allTransitiveDependencies,
        item: item,
      );

  GetAlbumShuffledPlayerSliceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.item,
  }) : super.internal();

  final FinampPlayable item;

  @override
  Override overrideWith(
    FutureOr<PlayableSlice> Function(GetAlbumShuffledPlayerSliceRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetAlbumShuffledPlayerSliceProvider._internal(
        (ref) => create(ref as GetAlbumShuffledPlayerSliceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        item: item,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PlayableSlice> createElement() {
    return _GetAlbumShuffledPlayerSliceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetAlbumShuffledPlayerSliceProvider && other.item == item;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, item.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetAlbumShuffledPlayerSliceRef
    on AutoDisposeFutureProviderRef<PlayableSlice> {
  /// The parameter `item` of this provider.
  FinampPlayable get item;
}

class _GetAlbumShuffledPlayerSliceProviderElement
    extends AutoDisposeFutureProviderElement<PlayableSlice>
    with GetAlbumShuffledPlayerSliceRef {
  _GetAlbumShuffledPlayerSliceProviderElement(super.provider);

  @override
  FinampPlayable get item =>
      (origin as GetAlbumShuffledPlayerSliceProvider).item;
}

String _$getChildTracksHash() => r'549f7a09f30ea42698768bf2b1243312485b70b6';

/// See also [getChildTracks].
@ProviderFor(getChildTracks)
const getChildTracksProvider = GetChildTracksFamily();

/// See also [getChildTracks].
class GetChildTracksFamily extends Family<AsyncValue<List<Track>>> {
  /// See also [getChildTracks].
  const GetChildTracksFamily();

  /// See also [getChildTracks].
  GetChildTracksProvider call({required FinampUnpagedDisplayable<Track> item}) {
    return GetChildTracksProvider(item: item);
  }

  @override
  GetChildTracksProvider getProviderOverride(
    covariant GetChildTracksProvider provider,
  ) {
    return call(item: provider.item);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getChildTracksProvider';
}

/// See also [getChildTracks].
class GetChildTracksProvider extends AutoDisposeFutureProvider<List<Track>> {
  /// See also [getChildTracks].
  GetChildTracksProvider({required FinampUnpagedDisplayable<Track> item})
    : this._internal(
        (ref) => getChildTracks(ref as GetChildTracksRef, item: item),
        from: getChildTracksProvider,
        name: r'getChildTracksProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getChildTracksHash,
        dependencies: GetChildTracksFamily._dependencies,
        allTransitiveDependencies:
            GetChildTracksFamily._allTransitiveDependencies,
        item: item,
      );

  GetChildTracksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.item,
  }) : super.internal();

  final FinampUnpagedDisplayable<Track> item;

  @override
  Override overrideWith(
    FutureOr<List<Track>> Function(GetChildTracksRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetChildTracksProvider._internal(
        (ref) => create(ref as GetChildTracksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        item: item,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Track>> createElement() {
    return _GetChildTracksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetChildTracksProvider && other.item == item;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, item.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetChildTracksRef on AutoDisposeFutureProviderRef<List<Track>> {
  /// The parameter `item` of this provider.
  FinampUnpagedDisplayable<Track> get item;
}

class _GetChildTracksProviderElement
    extends AutoDisposeFutureProviderElement<List<Track>>
    with GetChildTracksRef {
  _GetChildTracksProviderElement(super.provider);

  @override
  FinampUnpagedDisplayable<Track> get item =>
      (origin as GetChildTracksProvider).item;
}

String _$getChildItemsHash() => r'9bb5a70df1d6eeb9407ba0e44729af2cce2a0dd2';

/// See also [getChildItems].
@ProviderFor(getChildItems)
const getChildItemsProvider = GetChildItemsFamily();

/// See also [getChildItems].
class GetChildItemsFamily extends Family<AsyncValue<List<FinampPlayableDto>>> {
  /// See also [getChildItems].
  const GetChildItemsFamily();

  /// See also [getChildItems].
  GetChildItemsProvider call({
    required FinampUnpagedDisplayable<FinampPlayableDto> item,
  }) {
    return GetChildItemsProvider(item: item);
  }

  @override
  GetChildItemsProvider getProviderOverride(
    covariant GetChildItemsProvider provider,
  ) {
    return call(item: provider.item);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getChildItemsProvider';
}

/// See also [getChildItems].
class GetChildItemsProvider
    extends AutoDisposeFutureProvider<List<FinampPlayableDto>> {
  /// See also [getChildItems].
  GetChildItemsProvider({
    required FinampUnpagedDisplayable<FinampPlayableDto> item,
  }) : this._internal(
         (ref) => getChildItems(ref as GetChildItemsRef, item: item),
         from: getChildItemsProvider,
         name: r'getChildItemsProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getChildItemsHash,
         dependencies: GetChildItemsFamily._dependencies,
         allTransitiveDependencies:
             GetChildItemsFamily._allTransitiveDependencies,
         item: item,
       );

  GetChildItemsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.item,
  }) : super.internal();

  final FinampUnpagedDisplayable<FinampPlayableDto> item;

  @override
  Override overrideWith(
    FutureOr<List<FinampPlayableDto>> Function(GetChildItemsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetChildItemsProvider._internal(
        (ref) => create(ref as GetChildItemsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        item: item,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<FinampPlayableDto>> createElement() {
    return _GetChildItemsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetChildItemsProvider && other.item == item;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, item.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetChildItemsRef
    on AutoDisposeFutureProviderRef<List<FinampPlayableDto>> {
  /// The parameter `item` of this provider.
  FinampUnpagedDisplayable<FinampPlayableDto> get item;
}

class _GetChildItemsProviderElement
    extends AutoDisposeFutureProviderElement<List<FinampPlayableDto>>
    with GetChildItemsRef {
  _GetChildItemsProviderElement(super.provider);

  @override
  FinampUnpagedDisplayable<FinampPlayableDto> get item =>
      (origin as GetChildItemsProvider).item;
}

String _$getChildrenHash() => r'd2ea3dcb7eda184998a67d1f5ba49780a08c72b1';

/// See also [getChildren].
@ProviderFor(getChildren)
const getChildrenProvider = GetChildrenFamily();

/// See also [getChildren].
class GetChildrenFamily
    extends Family<AsyncValue<List<FinampDisplayableOrPlayable>>> {
  /// See also [getChildren].
  const GetChildrenFamily();

  /// See also [getChildren].
  GetChildrenProvider call({
    required FinampUnpagedDisplayable<FinampDisplayableOrPlayable> item,
  }) {
    return GetChildrenProvider(item: item);
  }

  @override
  GetChildrenProvider getProviderOverride(
    covariant GetChildrenProvider provider,
  ) {
    return call(item: provider.item);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getChildrenProvider';
}

/// See also [getChildren].
class GetChildrenProvider
    extends AutoDisposeFutureProvider<List<FinampDisplayableOrPlayable>> {
  /// See also [getChildren].
  GetChildrenProvider({
    required FinampUnpagedDisplayable<FinampDisplayableOrPlayable> item,
  }) : this._internal(
         (ref) => getChildren(ref as GetChildrenRef, item: item),
         from: getChildrenProvider,
         name: r'getChildrenProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getChildrenHash,
         dependencies: GetChildrenFamily._dependencies,
         allTransitiveDependencies:
             GetChildrenFamily._allTransitiveDependencies,
         item: item,
       );

  GetChildrenProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.item,
  }) : super.internal();

  final FinampUnpagedDisplayable<FinampDisplayableOrPlayable> item;

  @override
  Override overrideWith(
    FutureOr<List<FinampDisplayableOrPlayable>> Function(
      GetChildrenRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetChildrenProvider._internal(
        (ref) => create(ref as GetChildrenRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        item: item,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<FinampDisplayableOrPlayable>>
  createElement() {
    return _GetChildrenProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetChildrenProvider && other.item == item;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, item.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetChildrenRef
    on AutoDisposeFutureProviderRef<List<FinampDisplayableOrPlayable>> {
  /// The parameter `item` of this provider.
  FinampUnpagedDisplayable<FinampDisplayableOrPlayable> get item;
}

class _GetChildrenProviderElement
    extends AutoDisposeFutureProviderElement<List<FinampDisplayableOrPlayable>>
    with GetChildrenRef {
  _GetChildrenProviderElement(super.provider);

  @override
  FinampUnpagedDisplayable<FinampDisplayableOrPlayable> get item =>
      (origin as GetChildrenProvider).item;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
