// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'music_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(globalSearch)
final globalSearchProvider = GlobalSearchFamily._();

final class GlobalSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BaseItemDto>>,
          List<BaseItemDto>,
          FutureOr<List<BaseItemDto>>
        >
    with
        $FutureModifier<List<BaseItemDto>>,
        $FutureProvider<List<BaseItemDto>> {
  GlobalSearchProvider._({
    required GlobalSearchFamily super.from,
    required (String, {bool includeTracks}) super.argument,
  }) : super(
         retry: null,
         name: r'globalSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$globalSearchHash();

  @override
  String toString() {
    return r'globalSearchProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<BaseItemDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BaseItemDto>> create(Ref ref) {
    final argument = this.argument as (String, {bool includeTracks});
    return globalSearch(
      ref,
      argument.$1,
      includeTracks: argument.includeTracks,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GlobalSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$globalSearchHash() => r'629baea3ff8943df78747a6e6804455125ae7136';

final class GlobalSearchFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<BaseItemDto>>,
          (String, {bool includeTracks})
        > {
  GlobalSearchFamily._()
    : super(
        retry: null,
        name: r'globalSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GlobalSearchProvider call(String searchTerm, {required bool includeTracks}) =>
      GlobalSearchProvider._(
        argument: (searchTerm, includeTracks: includeTracks),
        from: this,
      );

  @override
  String toString() => r'globalSearchProvider';
}

@ProviderFor(resolveSection)
final resolveSectionProvider = ResolveSectionFamily._();

final class ResolveSectionProvider
    extends
        $FunctionalProvider<
          AsyncValue<FinampDisplayable<FinampPlayable>>,
          FinampDisplayable<FinampPlayable>,
          FutureOr<FinampDisplayable<FinampPlayable>>
        >
    with
        $FutureModifier<FinampDisplayable<FinampPlayable>>,
        $FutureProvider<FinampDisplayable<FinampPlayable>> {
  ResolveSectionProvider._({
    required ResolveSectionFamily super.from,
    required HomeScreenSectionConfiguration super.argument,
  }) : super(
         retry: null,
         name: r'resolveSectionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$resolveSectionHash();

  @override
  String toString() {
    return r'resolveSectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FinampDisplayable<FinampPlayable>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FinampDisplayable<FinampPlayable>> create(Ref ref) {
    final argument = this.argument as HomeScreenSectionConfiguration;
    return resolveSection(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResolveSectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$resolveSectionHash() => r'fb1ca99c7145fa70fc9bbf931029039584829f8c';

final class ResolveSectionFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<FinampDisplayable<FinampPlayable>>,
          HomeScreenSectionConfiguration
        > {
  ResolveSectionFamily._()
    : super(
        retry: null,
        name: r'resolveSectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ResolveSectionProvider call(HomeScreenSectionConfiguration section) =>
      ResolveSectionProvider._(argument: section, from: this);

  @override
  String toString() => r'resolveSectionProvider';
}

@ProviderFor(getPlayableSlice)
final getPlayableSliceProvider = GetPlayableSliceFamily._();

final class GetPlayableSliceProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlayableSlice>,
          PlayableSlice,
          FutureOr<PlayableSlice>
        >
    with $FutureModifier<PlayableSlice>, $FutureProvider<PlayableSlice> {
  GetPlayableSliceProvider._({
    required GetPlayableSliceFamily super.from,
    required ({FinampPlayable item, int startingOffset, int? limit})
    super.argument,
  }) : super(
         retry: null,
         name: r'getPlayableSliceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getPlayableSliceHash();

  @override
  String toString() {
    return r'getPlayableSliceProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PlayableSlice> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlayableSlice> create(Ref ref) {
    final argument =
        this.argument
            as ({FinampPlayable item, int startingOffset, int? limit});
    return getPlayableSlice(
      ref,
      item: argument.item,
      startingOffset: argument.startingOffset,
      limit: argument.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GetPlayableSliceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getPlayableSliceHash() => r'1c96ded656b217312f56f343cd38e5556e50d876';

final class GetPlayableSliceFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PlayableSlice>,
          ({FinampPlayable item, int startingOffset, int? limit})
        > {
  GetPlayableSliceFamily._()
    : super(
        retry: null,
        name: r'getPlayableSliceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetPlayableSliceProvider call({
    required FinampPlayable item,
    required int startingOffset,
    int? limit,
  }) => GetPlayableSliceProvider._(
    argument: (item: item, startingOffset: startingOffset, limit: limit),
    from: this,
  );

  @override
  String toString() => r'getPlayableSliceProvider';
}

@ProviderFor(getAlbumShuffledPlayerSlice)
final getAlbumShuffledPlayerSliceProvider =
    GetAlbumShuffledPlayerSliceFamily._();

final class GetAlbumShuffledPlayerSliceProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlayableSlice>,
          PlayableSlice,
          FutureOr<PlayableSlice>
        >
    with $FutureModifier<PlayableSlice>, $FutureProvider<PlayableSlice> {
  GetAlbumShuffledPlayerSliceProvider._({
    required GetAlbumShuffledPlayerSliceFamily super.from,
    required FinampPlayable super.argument,
  }) : super(
         retry: null,
         name: r'getAlbumShuffledPlayerSliceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getAlbumShuffledPlayerSliceHash();

  @override
  String toString() {
    return r'getAlbumShuffledPlayerSliceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PlayableSlice> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlayableSlice> create(Ref ref) {
    final argument = this.argument as FinampPlayable;
    return getAlbumShuffledPlayerSlice(ref, item: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetAlbumShuffledPlayerSliceProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getAlbumShuffledPlayerSliceHash() =>
    r'230a194145a309c3a69f5f80fe062400ae278e1a';

final class GetAlbumShuffledPlayerSliceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PlayableSlice>, FinampPlayable> {
  GetAlbumShuffledPlayerSliceFamily._()
    : super(
        retry: null,
        name: r'getAlbumShuffledPlayerSliceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetAlbumShuffledPlayerSliceProvider call({required FinampPlayable item}) =>
      GetAlbumShuffledPlayerSliceProvider._(argument: item, from: this);

  @override
  String toString() => r'getAlbumShuffledPlayerSliceProvider';
}

@ProviderFor(getChildren)
final getChildrenProvider = GetChildrenFamily._();

final class GetChildrenProvider<ChildType extends FinampDisplayableOrPlayable>
    extends
        $FunctionalProvider<
          AsyncValue<List<ChildType>>,
          List<ChildType>,
          FutureOr<List<ChildType>>
        >
    with $FutureModifier<List<ChildType>>, $FutureProvider<List<ChildType>> {
  GetChildrenProvider._({
    required GetChildrenFamily super.from,
    required FinampUnpagedDisplayable<ChildType> super.argument,
  }) : super(
         retry: null,
         name: r'getChildrenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getChildrenHash();

  @override
  String toString() {
    return r'getChildrenProvider'
        '<${ChildType}>'
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ChildType>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ChildType>> create(Ref ref) {
    final argument = this.argument as FinampUnpagedDisplayable<ChildType>;
    return getChildren<ChildType>(ref, item: argument);
  }

  $R _captureGenerics<$R>(
    $R Function<ChildType extends FinampDisplayableOrPlayable>() cb,
  ) {
    return cb<ChildType>();
  }

  @override
  bool operator ==(Object other) {
    return other is GetChildrenProvider &&
        other.runtimeType == runtimeType &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, argument);
  }
}

String _$getChildrenHash() => r'df74037f96fe1dced93fb2e1cac431999c955aaa';

final class GetChildrenFamily extends $Family {
  GetChildrenFamily._()
    : super(
        retry: null,
        name: r'getChildrenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetChildrenProvider<ChildType>
  call<ChildType extends FinampDisplayableOrPlayable>({
    required FinampUnpagedDisplayable<ChildType> item,
  }) => GetChildrenProvider<ChildType>._(argument: item, from: this);

  @override
  String toString() => r'getChildrenProvider';

  /// {@macro riverpod.override_with}
  Override overrideWith(
    FutureOr<List<ChildType>> Function<
      ChildType extends FinampDisplayableOrPlayable
    >(Ref ref, FinampUnpagedDisplayable<ChildType> args)
    create,
  ) => $FamilyOverride(
    from: this,
    createElement: (pointer) {
      final provider = pointer.origin as GetChildrenProvider;
      return provider._captureGenerics(
        <ChildType extends FinampDisplayableOrPlayable>() {
          provider as GetChildrenProvider<ChildType>;
          final argument =
              provider.argument as FinampUnpagedDisplayable<ChildType>;
          return provider
              .$view(create: (ref) => create(ref, argument))
              .$createElement(pointer);
        },
      );
    },
  );
}
