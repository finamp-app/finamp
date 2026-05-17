// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'music_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loadHomeSectionItemsHash() =>
    r'24de9f6513fa6baf359f8993c0ec7c4118fdfd96';

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

/// See also [loadHomeSectionItems].
@ProviderFor(loadHomeSectionItems)
const loadHomeSectionItemsProvider = LoadHomeSectionItemsFamily();

/// See also [loadHomeSectionItems].
class LoadHomeSectionItemsFamily
    extends Family<AsyncValue<List<BaseItemDto>?>> {
  /// See also [loadHomeSectionItems].
  const LoadHomeSectionItemsFamily();

  /// See also [loadHomeSectionItems].
  LoadHomeSectionItemsProvider call({
    required HomeScreenSectionConfiguration sectionInfo,
    required int startIndex,
    required int limit,
  }) {
    return LoadHomeSectionItemsProvider(
      sectionInfo: sectionInfo,
      startIndex: startIndex,
      limit: limit,
    );
  }

  @override
  LoadHomeSectionItemsProvider getProviderOverride(
    covariant LoadHomeSectionItemsProvider provider,
  ) {
    return call(
      sectionInfo: provider.sectionInfo,
      startIndex: provider.startIndex,
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
  String? get name => r'loadHomeSectionItemsProvider';
}

/// See also [loadHomeSectionItems].
class LoadHomeSectionItemsProvider extends FutureProvider<List<BaseItemDto>?> {
  /// See also [loadHomeSectionItems].
  LoadHomeSectionItemsProvider({
    required HomeScreenSectionConfiguration sectionInfo,
    required int startIndex,
    required int limit,
  }) : this._internal(
         (ref) => loadHomeSectionItems(
           ref as LoadHomeSectionItemsRef,
           sectionInfo: sectionInfo,
           startIndex: startIndex,
           limit: limit,
         ),
         from: loadHomeSectionItemsProvider,
         name: r'loadHomeSectionItemsProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$loadHomeSectionItemsHash,
         dependencies: LoadHomeSectionItemsFamily._dependencies,
         allTransitiveDependencies:
             LoadHomeSectionItemsFamily._allTransitiveDependencies,
         sectionInfo: sectionInfo,
         startIndex: startIndex,
         limit: limit,
       );

  LoadHomeSectionItemsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sectionInfo,
    required this.startIndex,
    required this.limit,
  }) : super.internal();

  final HomeScreenSectionConfiguration sectionInfo;
  final int startIndex;
  final int limit;

  @override
  Override overrideWith(
    FutureOr<List<BaseItemDto>?> Function(LoadHomeSectionItemsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LoadHomeSectionItemsProvider._internal(
        (ref) => create(ref as LoadHomeSectionItemsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sectionInfo: sectionInfo,
        startIndex: startIndex,
        limit: limit,
      ),
    );
  }

  @override
  FutureProviderElement<List<BaseItemDto>?> createElement() {
    return _LoadHomeSectionItemsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LoadHomeSectionItemsProvider &&
        other.sectionInfo == sectionInfo &&
        other.startIndex == startIndex &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sectionInfo.hashCode);
    hash = _SystemHash.combine(hash, startIndex.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LoadHomeSectionItemsRef on FutureProviderRef<List<BaseItemDto>?> {
  /// The parameter `sectionInfo` of this provider.
  HomeScreenSectionConfiguration get sectionInfo;

  /// The parameter `startIndex` of this provider.
  int get startIndex;

  /// The parameter `limit` of this provider.
  int get limit;
}

class _LoadHomeSectionItemsProviderElement
    extends FutureProviderElement<List<BaseItemDto>?>
    with LoadHomeSectionItemsRef {
  _LoadHomeSectionItemsProviderElement(super.provider);

  @override
  HomeScreenSectionConfiguration get sectionInfo =>
      (origin as LoadHomeSectionItemsProvider).sectionInfo;
  @override
  int get startIndex => (origin as LoadHomeSectionItemsProvider).startIndex;
  @override
  int get limit => (origin as LoadHomeSectionItemsProvider).limit;
}

String _$globalSearchHash() => r'629baea3ff8943df78747a6e6804455125ae7136';

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

String _$resolveSectionHash() => r'fd3db6eb2cbff4c07895aea396f91845a613f7ac';

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

String _$getPlayerSliceHash() => r'b8d6f1bce13656006b0a45f7c69a71a6988d2e39';

/// See also [getPlayerSlice].
@ProviderFor(getPlayerSlice)
const getPlayerSliceProvider = GetPlayerSliceFamily();

/// See also [getPlayerSlice].
class GetPlayerSliceFamily extends Family<AsyncValue<PlayableSlice>> {
  /// See also [getPlayerSlice].
  const GetPlayerSliceFamily();

  /// See also [getPlayerSlice].
  GetPlayerSliceProvider call({
    required FinampPlayable item,
    required int startingOffset,
    int? limit,
  }) {
    return GetPlayerSliceProvider(
      item: item,
      startingOffset: startingOffset,
      limit: limit,
    );
  }

  @override
  GetPlayerSliceProvider getProviderOverride(
    covariant GetPlayerSliceProvider provider,
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
  String? get name => r'getPlayerSliceProvider';
}

/// See also [getPlayerSlice].
class GetPlayerSliceProvider extends AutoDisposeFutureProvider<PlayableSlice> {
  /// See also [getPlayerSlice].
  GetPlayerSliceProvider({
    required FinampPlayable item,
    required int startingOffset,
    int? limit,
  }) : this._internal(
         (ref) => getPlayerSlice(
           ref as GetPlayerSliceRef,
           item: item,
           startingOffset: startingOffset,
           limit: limit,
         ),
         from: getPlayerSliceProvider,
         name: r'getPlayerSliceProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$getPlayerSliceHash,
         dependencies: GetPlayerSliceFamily._dependencies,
         allTransitiveDependencies:
             GetPlayerSliceFamily._allTransitiveDependencies,
         item: item,
         startingOffset: startingOffset,
         limit: limit,
       );

  GetPlayerSliceProvider._internal(
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
    FutureOr<PlayableSlice> Function(GetPlayerSliceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetPlayerSliceProvider._internal(
        (ref) => create(ref as GetPlayerSliceRef),
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
    return _GetPlayerSliceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetPlayerSliceProvider &&
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
mixin GetPlayerSliceRef on AutoDisposeFutureProviderRef<PlayableSlice> {
  /// The parameter `item` of this provider.
  FinampPlayable get item;

  /// The parameter `startingOffset` of this provider.
  int get startingOffset;

  /// The parameter `limit` of this provider.
  int? get limit;
}

class _GetPlayerSliceProviderElement
    extends AutoDisposeFutureProviderElement<PlayableSlice>
    with GetPlayerSliceRef {
  _GetPlayerSliceProviderElement(super.provider);

  @override
  FinampPlayable get item => (origin as GetPlayerSliceProvider).item;
  @override
  int get startingOffset => (origin as GetPlayerSliceProvider).startingOffset;
  @override
  int? get limit => (origin as GetPlayerSliceProvider).limit;
}

String _$getChildTracksHash() => r'e08a547da56b302f527e86e0cf1cd3b3a312930f';

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

String _$getChildrenHash() => r'e528cebae8bcb29f18a720a7f2e037554505da19';

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

String _$pagedContentHash() => r'2a073b6f8f72e426818557c387d29fd3ea2f49a8';

abstract class _$PagedContent
    extends
        BuildlessAutoDisposeNotifier<
          PagingState<int, FinampDisplayableOrPlayable>
        > {
  late final FinampDisplayable<FinampDisplayableOrPlayable> request;

  PagingState<int, FinampDisplayableOrPlayable> build(
    FinampDisplayable<FinampDisplayableOrPlayable> request,
  );
}

/// See also [PagedContent].
@ProviderFor(PagedContent)
const pagedContentProvider = PagedContentFamily();

/// See also [PagedContent].
class PagedContentFamily
    extends Family<PagingState<int, FinampDisplayableOrPlayable>> {
  /// See also [PagedContent].
  const PagedContentFamily();

  /// See also [PagedContent].
  PagedContentProvider call(
    FinampDisplayable<FinampDisplayableOrPlayable> request,
  ) {
    return PagedContentProvider(request);
  }

  @override
  PagedContentProvider getProviderOverride(
    covariant PagedContentProvider provider,
  ) {
    return call(provider.request);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'pagedContentProvider';
}

/// See also [PagedContent].
class PagedContentProvider
    extends
        AutoDisposeNotifierProviderImpl<
          PagedContent,
          PagingState<int, FinampDisplayableOrPlayable>
        > {
  /// See also [PagedContent].
  PagedContentProvider(FinampDisplayable<FinampDisplayableOrPlayable> request)
    : this._internal(
        () => PagedContent()..request = request,
        from: pagedContentProvider,
        name: r'pagedContentProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$pagedContentHash,
        dependencies: PagedContentFamily._dependencies,
        allTransitiveDependencies:
            PagedContentFamily._allTransitiveDependencies,
        request: request,
      );

  PagedContentProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.request,
  }) : super.internal();

  final FinampDisplayable<FinampDisplayableOrPlayable> request;

  @override
  PagingState<int, FinampDisplayableOrPlayable> runNotifierBuild(
    covariant PagedContent notifier,
  ) {
    return notifier.build(request);
  }

  @override
  Override overrideWith(PagedContent Function() create) {
    return ProviderOverride(
      origin: this,
      override: PagedContentProvider._internal(
        () => create()..request = request,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        request: request,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    PagedContent,
    PagingState<int, FinampDisplayableOrPlayable>
  >
  createElement() {
    return _PagedContentProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PagedContentProvider && other.request == request;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, request.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PagedContentRef
    on
        AutoDisposeNotifierProviderRef<
          PagingState<int, FinampDisplayableOrPlayable>
        > {
  /// The parameter `request` of this provider.
  FinampDisplayable<FinampDisplayableOrPlayable> get request;
}

class _PagedContentProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          PagedContent,
          PagingState<int, FinampDisplayableOrPlayable>
        >
    with PagedContentRef {
  _PagedContentProviderElement(super.provider);

  @override
  FinampDisplayable<FinampDisplayableOrPlayable> get request =>
      (origin as PagedContentProvider).request;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
