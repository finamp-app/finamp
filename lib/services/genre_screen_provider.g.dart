// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'genre_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(genreCuratedItems)
final genreCuratedItemsProvider = GenreCuratedItemsFamily._();

final class GenreCuratedItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<
            (
              List<BaseItemDto>,
              int,
              CuratedItemSelectionType,
              Set<CuratedItemSelectionType>?,
            )
          >,
          (
            List<BaseItemDto>,
            int,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          ),
          FutureOr<
            (
              List<BaseItemDto>,
              int,
              CuratedItemSelectionType,
              Set<CuratedItemSelectionType>?,
            )
          >
        >
    with
        $FutureModifier<
          (
            List<BaseItemDto>,
            int,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        >,
        $FutureProvider<
          (
            List<BaseItemDto>,
            int,
            CuratedItemSelectionType,
            Set<CuratedItemSelectionType>?,
          )
        > {
  GenreCuratedItemsProvider._({
    required GenreCuratedItemsFamily super.from,
    required (BaseItemDto, BaseItemDtoType, BaseItemDto?) super.argument,
  }) : super(
         retry: null,
         name: r'genreCuratedItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$genreCuratedItemsHash();

  @override
  String toString() {
    return r'genreCuratedItemsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<
    (
      List<BaseItemDto>,
      int,
      CuratedItemSelectionType,
      Set<CuratedItemSelectionType>?,
    )
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<
    (
      List<BaseItemDto>,
      int,
      CuratedItemSelectionType,
      Set<CuratedItemSelectionType>?,
    )
  >
  create(Ref ref) {
    final argument =
        this.argument as (BaseItemDto, BaseItemDtoType, BaseItemDto?);
    return genreCuratedItems(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is GenreCuratedItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$genreCuratedItemsHash() => r'2e40db93d99555677c38e066509ddfeb5894c405';

final class GenreCuratedItemsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<
            (
              List<BaseItemDto>,
              int,
              CuratedItemSelectionType,
              Set<CuratedItemSelectionType>?,
            )
          >,
          (BaseItemDto, BaseItemDtoType, BaseItemDto?)
        > {
  GenreCuratedItemsFamily._()
    : super(
        retry: null,
        name: r'genreCuratedItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GenreCuratedItemsProvider call(
    BaseItemDto parent,
    BaseItemDtoType baseItemType,
    BaseItemDto? library,
  ) => GenreCuratedItemsProvider._(
    argument: (parent, baseItemType, library),
    from: this,
  );

  @override
  String toString() => r'genreCuratedItemsProvider';
}
