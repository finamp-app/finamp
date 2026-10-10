// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'music_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PagedContent)
final pagedContentProvider = PagedContentFamily._();

final class PagedContentProvider<ChildType extends FinampDisplayableOrPlayable>
    extends
        $NotifierProvider<
          PagedContent<ChildType>,
          PagingState<int, ChildType>
        > {
  PagedContentProvider._({
    required PagedContentFamily super.from,
    required FinampDisplayable<ChildType> super.argument,
  }) : super(
         retry: null,
         name: r'pagedContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pagedContentHash();

  @override
  String toString() {
    return r'pagedContentProvider'
        '<${ChildType}>'
        '($argument)';
  }

  @$internal
  @override
  PagedContent<ChildType> create() => PagedContent<ChildType>();

  $R _captureGenerics<$R>(
    $R Function<ChildType extends FinampDisplayableOrPlayable>() cb,
  ) {
    return cb<ChildType>();
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PagingState<int, ChildType> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PagingState<int, ChildType>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PagedContentProvider &&
        other.runtimeType == runtimeType &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, argument);
  }
}

String _$pagedContentHash() => r'25eb9678f1dea2a6bd5ff22ae4c3bf2cdf6e1daa';

final class PagedContentFamily extends $Family {
  PagedContentFamily._()
    : super(
        retry: null,
        name: r'pagedContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PagedContentProvider<ChildType>
  call<ChildType extends FinampDisplayableOrPlayable>(
    FinampDisplayable<ChildType> request,
  ) => PagedContentProvider<ChildType>._(argument: request, from: this);

  @override
  String toString() => r'pagedContentProvider';

  /// {@macro riverpod.override_with}
  Override overrideWith(
    PagedContent<ChildType>
    Function<ChildType extends FinampDisplayableOrPlayable>()
    create,
  ) => $FamilyOverride(
    from: this,
    createElement: (pointer) {
      final provider = pointer.origin as PagedContentProvider;
      return provider._captureGenerics(
        <ChildType extends FinampDisplayableOrPlayable>() {
          provider as PagedContentProvider<ChildType>;
          return provider
              .$view(create: create<ChildType>)
              .$createElement(pointer);
        },
      );
    },
  );

  /// {@macro riverpod.override_with_build}
  Override overrideWithBuild(
    PagingState<int, ChildType> Function<
      ChildType extends FinampDisplayableOrPlayable
    >(Ref ref, PagedContent<ChildType> notifier)
    build,
  ) => $FamilyOverride(
    from: this,
    createElement: (pointer) {
      final provider = pointer.origin as PagedContentProvider;
      return provider._captureGenerics(
        <ChildType extends FinampDisplayableOrPlayable>() {
          provider as PagedContentProvider<ChildType>;
          return provider
              .$view(runNotifierBuildOverride: build<ChildType>)
              .$createElement(pointer);
        },
      );
    },
  );
}

abstract class _$PagedContent<ChildType extends FinampDisplayableOrPlayable>
    extends $Notifier<PagingState<int, ChildType>> {
  late final _$args = ref.$arg as FinampDisplayable<ChildType>;
  FinampDisplayable<ChildType> get request => _$args;

  PagingState<int, ChildType> build(FinampDisplayable<ChildType> request);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<PagingState<int, ChildType>, PagingState<int, ChildType>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                PagingState<int, ChildType>,
                PagingState<int, ChildType>
              >,
              PagingState<int, ChildType>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(loadHomeSectionItems)
final loadHomeSectionItemsProvider = LoadHomeSectionItemsFamily._();

final class LoadHomeSectionItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BaseItemDto>?>,
          List<BaseItemDto>?,
          FutureOr<List<BaseItemDto>?>
        >
    with
        $FutureModifier<List<BaseItemDto>?>,
        $FutureProvider<List<BaseItemDto>?> {
  LoadHomeSectionItemsProvider._({
    required LoadHomeSectionItemsFamily super.from,
    required ({
      MusicScreenPlayable<FinampPlayableDto> request,
      int startIndex,
      int limit,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'loadHomeSectionItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$loadHomeSectionItemsHash();

  @override
  String toString() {
    return r'loadHomeSectionItemsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<BaseItemDto>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BaseItemDto>?> create(Ref ref) {
    final argument =
        this.argument
            as ({
              MusicScreenPlayable<FinampPlayableDto> request,
              int startIndex,
              int limit,
            });
    return loadHomeSectionItems(
      ref,
      request: argument.request,
      startIndex: argument.startIndex,
      limit: argument.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LoadHomeSectionItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$loadHomeSectionItemsHash() =>
    r'79de212cae057856d0c2c10ef7dea9dc84ede6d4';

final class LoadHomeSectionItemsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<BaseItemDto>?>,
          ({
            MusicScreenPlayable<FinampPlayableDto> request,
            int startIndex,
            int limit,
          })
        > {
  LoadHomeSectionItemsFamily._()
    : super(
        retry: null,
        name: r'loadHomeSectionItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LoadHomeSectionItemsProvider call({
    required MusicScreenPlayable<FinampPlayableDto> request,
    required int startIndex,
    required int limit,
  }) => LoadHomeSectionItemsProvider._(
    argument: (request: request, startIndex: startIndex, limit: limit),
    from: this,
  );

  @override
  String toString() => r'loadHomeSectionItemsProvider';
}

/// Total item count for [request], ignoring pagination. CarPlay uses this to
/// decide whether a view needs the letter picker.

@ProviderFor(musicScreenItemCount)
final musicScreenItemCountProvider = MusicScreenItemCountFamily._();

/// Total item count for [request], ignoring pagination. CarPlay uses this to
/// decide whether a view needs the letter picker.

final class MusicScreenItemCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Total item count for [request], ignoring pagination. CarPlay uses this to
  /// decide whether a view needs the letter picker.
  MusicScreenItemCountProvider._({
    required MusicScreenItemCountFamily super.from,
    required MusicScreenPlayable<FinampPlayableDto> super.argument,
  }) : super(
         retry: null,
         name: r'musicScreenItemCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$musicScreenItemCountHash();

  @override
  String toString() {
    return r'musicScreenItemCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as MusicScreenPlayable<FinampPlayableDto>;
    return musicScreenItemCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MusicScreenItemCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$musicScreenItemCountHash() =>
    r'c49c43e47599e8b6f4f7bc6280fa844767f0eee8';

/// Total item count for [request], ignoring pagination. CarPlay uses this to
/// decide whether a view needs the letter picker.

final class MusicScreenItemCountFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<int>,
          MusicScreenPlayable<FinampPlayableDto>
        > {
  MusicScreenItemCountFamily._()
    : super(
        retry: null,
        name: r'musicScreenItemCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Total item count for [request], ignoring pagination. CarPlay uses this to
  /// decide whether a view needs the letter picker.

  MusicScreenItemCountProvider call(
    MusicScreenPlayable<FinampPlayableDto> request,
  ) => MusicScreenItemCountProvider._(argument: request, from: this);

  @override
  String toString() => r'musicScreenItemCountProvider';
}

@ProviderFor(getJellyfinCollection)
final getJellyfinCollectionProvider = GetJellyfinCollectionFamily._();

final class GetJellyfinCollectionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BaseItemDto>?>,
          List<BaseItemDto>?,
          FutureOr<List<BaseItemDto>?>
        >
    with
        $FutureModifier<List<BaseItemDto>?>,
        $FutureProvider<List<BaseItemDto>?> {
  GetJellyfinCollectionProvider._({
    required GetJellyfinCollectionFamily super.from,
    required (BaseItemDto, SortAndFilterConfiguration) super.argument,
  }) : super(
         retry: null,
         name: r'getJellyfinCollectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getJellyfinCollectionHash();

  @override
  String toString() {
    return r'getJellyfinCollectionProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<BaseItemDto>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BaseItemDto>?> create(Ref ref) {
    final argument = this.argument as (BaseItemDto, SortAndFilterConfiguration);
    return getJellyfinCollection(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is GetJellyfinCollectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getJellyfinCollectionHash() =>
    r'1c7ade2240687f4de0fb3a93b51f27a97fb80e8a';

final class GetJellyfinCollectionFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<BaseItemDto>?>,
          (BaseItemDto, SortAndFilterConfiguration)
        > {
  GetJellyfinCollectionFamily._()
    : super(
        retry: null,
        name: r'getJellyfinCollectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetJellyfinCollectionProvider call(
    BaseItemDto collection,
    SortAndFilterConfiguration sortConfig,
  ) => GetJellyfinCollectionProvider._(
    argument: (collection, sortConfig),
    from: this,
  );

  @override
  String toString() => r'getJellyfinCollectionProvider';
}
