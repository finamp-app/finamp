// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'music_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loadHomeSectionItemsHash() =>
    r'fc063f7f06280ec5a198e40dbdd931a7a571d184';

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
    required BaseItemDto? library,
    required int startIndex,
    required int limit,
  }) {
    return LoadHomeSectionItemsProvider(
      sectionInfo: sectionInfo,
      library: library,
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
      library: provider.library,
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
    required BaseItemDto? library,
    required int startIndex,
    required int limit,
  }) : this._internal(
         (ref) => loadHomeSectionItems(
           ref as LoadHomeSectionItemsRef,
           sectionInfo: sectionInfo,
           library: library,
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
         library: library,
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
    required this.library,
    required this.startIndex,
    required this.limit,
  }) : super.internal();

  final HomeScreenSectionConfiguration sectionInfo;
  final BaseItemDto? library;
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
        library: library,
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
        other.library == library &&
        other.startIndex == startIndex &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sectionInfo.hashCode);
    hash = _SystemHash.combine(hash, library.hashCode);
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

  /// The parameter `library` of this provider.
  BaseItemDto? get library;

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
  BaseItemDto? get library => (origin as LoadHomeSectionItemsProvider).library;
  @override
  int get startIndex => (origin as LoadHomeSectionItemsProvider).startIndex;
  @override
  int get limit => (origin as LoadHomeSectionItemsProvider).limit;
}

String _$musicScreenContentHash() =>
    r'7766c5c4e33b24f4eaf0842ed23b373294f94f75';

abstract class _$MusicScreenContent
    extends BuildlessAutoDisposeNotifier<PagingState<int, BaseItemDto>> {
  late final MusicScreenRequest request;

  PagingState<int, BaseItemDto> build(MusicScreenRequest request);
}

/// See also [MusicScreenContent].
@ProviderFor(MusicScreenContent)
const musicScreenContentProvider = MusicScreenContentFamily();

/// See also [MusicScreenContent].
class MusicScreenContentFamily extends Family<PagingState<int, BaseItemDto>> {
  /// See also [MusicScreenContent].
  const MusicScreenContentFamily();

  /// See also [MusicScreenContent].
  MusicScreenContentProvider call(MusicScreenRequest request) {
    return MusicScreenContentProvider(request);
  }

  @override
  MusicScreenContentProvider getProviderOverride(
    covariant MusicScreenContentProvider provider,
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
  String? get name => r'musicScreenContentProvider';
}

/// See also [MusicScreenContent].
class MusicScreenContentProvider
    extends
        AutoDisposeNotifierProviderImpl<
          MusicScreenContent,
          PagingState<int, BaseItemDto>
        > {
  /// See also [MusicScreenContent].
  MusicScreenContentProvider(MusicScreenRequest request)
    : this._internal(
        () => MusicScreenContent()..request = request,
        from: musicScreenContentProvider,
        name: r'musicScreenContentProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$musicScreenContentHash,
        dependencies: MusicScreenContentFamily._dependencies,
        allTransitiveDependencies:
            MusicScreenContentFamily._allTransitiveDependencies,
        request: request,
      );

  MusicScreenContentProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.request,
  }) : super.internal();

  final MusicScreenRequest request;

  @override
  PagingState<int, BaseItemDto> runNotifierBuild(
    covariant MusicScreenContent notifier,
  ) {
    return notifier.build(request);
  }

  @override
  Override overrideWith(MusicScreenContent Function() create) {
    return ProviderOverride(
      origin: this,
      override: MusicScreenContentProvider._internal(
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
    MusicScreenContent,
    PagingState<int, BaseItemDto>
  >
  createElement() {
    return _MusicScreenContentProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MusicScreenContentProvider && other.request == request;
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
mixin MusicScreenContentRef
    on AutoDisposeNotifierProviderRef<PagingState<int, BaseItemDto>> {
  /// The parameter `request` of this provider.
  MusicScreenRequest get request;
}

class _MusicScreenContentProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          MusicScreenContent,
          PagingState<int, BaseItemDto>
        >
    with MusicScreenContentRef {
  _MusicScreenContentProviderElement(super.provider);

  @override
  MusicScreenRequest get request =>
      (origin as MusicScreenContentProvider).request;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
