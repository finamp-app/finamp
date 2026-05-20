// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'music_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loadHomeSectionItemsHash() =>
    r'a9937d339a238d2c100c799260f027a71d819d13';

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
    required MusicScreenPlayable<FinampPlayableDto> request,
    required int startIndex,
    required int limit,
  }) {
    return LoadHomeSectionItemsProvider(
      request: request,
      startIndex: startIndex,
      limit: limit,
    );
  }

  @override
  LoadHomeSectionItemsProvider getProviderOverride(
    covariant LoadHomeSectionItemsProvider provider,
  ) {
    return call(
      request: provider.request,
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
    required MusicScreenPlayable<FinampPlayableDto> request,
    required int startIndex,
    required int limit,
  }) : this._internal(
         (ref) => loadHomeSectionItems(
           ref as LoadHomeSectionItemsRef,
           request: request,
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
         request: request,
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
    required this.request,
    required this.startIndex,
    required this.limit,
  }) : super.internal();

  final MusicScreenPlayable<FinampPlayableDto> request;
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
        request: request,
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
        other.request == request &&
        other.startIndex == startIndex &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, request.hashCode);
    hash = _SystemHash.combine(hash, startIndex.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LoadHomeSectionItemsRef on FutureProviderRef<List<BaseItemDto>?> {
  /// The parameter `request` of this provider.
  MusicScreenPlayable<FinampPlayableDto> get request;

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
  MusicScreenPlayable<FinampPlayableDto> get request =>
      (origin as LoadHomeSectionItemsProvider).request;
  @override
  int get startIndex => (origin as LoadHomeSectionItemsProvider).startIndex;
  @override
  int get limit => (origin as LoadHomeSectionItemsProvider).limit;
}

String _$getJellyfinCollectionHash() =>
    r'2bc0431101a3df4e5800dcf3b325f86c027e9a30';

/// See also [getJellyfinCollection].
@ProviderFor(getJellyfinCollection)
const getJellyfinCollectionProvider = GetJellyfinCollectionFamily();

/// See also [getJellyfinCollection].
class GetJellyfinCollectionFamily
    extends Family<AsyncValue<List<BaseItemDto>?>> {
  /// See also [getJellyfinCollection].
  const GetJellyfinCollectionFamily();

  /// See also [getJellyfinCollection].
  GetJellyfinCollectionProvider call(
    BaseItemDto collection,
    SortAndFilterConfiguration sortConfig,
  ) {
    return GetJellyfinCollectionProvider(collection, sortConfig);
  }

  @override
  GetJellyfinCollectionProvider getProviderOverride(
    covariant GetJellyfinCollectionProvider provider,
  ) {
    return call(provider.collection, provider.sortConfig);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getJellyfinCollectionProvider';
}

/// See also [getJellyfinCollection].
class GetJellyfinCollectionProvider
    extends AutoDisposeFutureProvider<List<BaseItemDto>?> {
  /// See also [getJellyfinCollection].
  GetJellyfinCollectionProvider(
    BaseItemDto collection,
    SortAndFilterConfiguration sortConfig,
  ) : this._internal(
        (ref) => getJellyfinCollection(
          ref as GetJellyfinCollectionRef,
          collection,
          sortConfig,
        ),
        from: getJellyfinCollectionProvider,
        name: r'getJellyfinCollectionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getJellyfinCollectionHash,
        dependencies: GetJellyfinCollectionFamily._dependencies,
        allTransitiveDependencies:
            GetJellyfinCollectionFamily._allTransitiveDependencies,
        collection: collection,
        sortConfig: sortConfig,
      );

  GetJellyfinCollectionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collection,
    required this.sortConfig,
  }) : super.internal();

  final BaseItemDto collection;
  final SortAndFilterConfiguration sortConfig;

  @override
  Override overrideWith(
    FutureOr<List<BaseItemDto>?> Function(GetJellyfinCollectionRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetJellyfinCollectionProvider._internal(
        (ref) => create(ref as GetJellyfinCollectionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        collection: collection,
        sortConfig: sortConfig,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BaseItemDto>?> createElement() {
    return _GetJellyfinCollectionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetJellyfinCollectionProvider &&
        other.collection == collection &&
        other.sortConfig == sortConfig;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, collection.hashCode);
    hash = _SystemHash.combine(hash, sortConfig.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetJellyfinCollectionRef
    on AutoDisposeFutureProviderRef<List<BaseItemDto>?> {
  /// The parameter `collection` of this provider.
  BaseItemDto get collection;

  /// The parameter `sortConfig` of this provider.
  SortAndFilterConfiguration get sortConfig;
}

class _GetJellyfinCollectionProviderElement
    extends AutoDisposeFutureProviderElement<List<BaseItemDto>?>
    with GetJellyfinCollectionRef {
  _GetJellyfinCollectionProviderElement(super.provider);

  @override
  BaseItemDto get collection =>
      (origin as GetJellyfinCollectionProvider).collection;
  @override
  SortAndFilterConfiguration get sortConfig =>
      (origin as GetJellyfinCollectionProvider).sortConfig;
}

String _$pagedContentHash() => r'15bbe776b36af08055b936febe3a015ab0fd0ab9';

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
