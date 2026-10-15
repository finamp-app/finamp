// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'album_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getAlbumOrPlaylistTracks)
final getAlbumOrPlaylistTracksProvider = GetAlbumOrPlaylistTracksFamily._();

final class GetAlbumOrPlaylistTracksProvider
    extends
        $FunctionalProvider<
          AsyncValue<(List<BaseItemDto>, List<BaseItemDto>)>,
          (List<BaseItemDto>, List<BaseItemDto>),
          FutureOr<(List<BaseItemDto>, List<BaseItemDto>)>
        >
    with
        $FutureModifier<(List<BaseItemDto>, List<BaseItemDto>)>,
        $FutureProvider<(List<BaseItemDto>, List<BaseItemDto>)> {
  GetAlbumOrPlaylistTracksProvider._({
    required GetAlbumOrPlaylistTracksFamily super.from,
    required BaseItemDto super.argument,
  }) : super(
         retry: null,
         name: r'getAlbumOrPlaylistTracksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getAlbumOrPlaylistTracksHash();

  @override
  String toString() {
    return r'getAlbumOrPlaylistTracksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<(List<BaseItemDto>, List<BaseItemDto>)> create(Ref ref) {
    final argument = this.argument as BaseItemDto;
    return getAlbumOrPlaylistTracks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetAlbumOrPlaylistTracksProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getAlbumOrPlaylistTracksHash() =>
    r'5ae61c7e578f82d573fbc56877575353d479f524';

final class GetAlbumOrPlaylistTracksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<(List<BaseItemDto>, List<BaseItemDto>)>,
          BaseItemDto
        > {
  GetAlbumOrPlaylistTracksFamily._()
    : super(
        retry: null,
        name: r'getAlbumOrPlaylistTracksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetAlbumOrPlaylistTracksProvider call(BaseItemDto parent) =>
      GetAlbumOrPlaylistTracksProvider._(argument: parent, from: this);

  @override
  String toString() => r'getAlbumOrPlaylistTracksProvider';
}

@ProviderFor(getDefaultSortedPlaylistTracks)
final getDefaultSortedPlaylistTracksProvider =
    GetDefaultSortedPlaylistTracksFamily._();

final class GetDefaultSortedPlaylistTracksProvider
    extends
        $FunctionalProvider<
          AsyncValue<(List<BaseItemDto>, List<BaseItemDto>)>,
          (List<BaseItemDto>, List<BaseItemDto>),
          FutureOr<(List<BaseItemDto>, List<BaseItemDto>)>
        >
    with
        $FutureModifier<(List<BaseItemDto>, List<BaseItemDto>)>,
        $FutureProvider<(List<BaseItemDto>, List<BaseItemDto>)> {
  GetDefaultSortedPlaylistTracksProvider._({
    required GetDefaultSortedPlaylistTracksFamily super.from,
    required BaseItemDto super.argument,
  }) : super(
         retry: null,
         name: r'getDefaultSortedPlaylistTracksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getDefaultSortedPlaylistTracksHash();

  @override
  String toString() {
    return r'getDefaultSortedPlaylistTracksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<(List<BaseItemDto>, List<BaseItemDto>)> create(Ref ref) {
    final argument = this.argument as BaseItemDto;
    return getDefaultSortedPlaylistTracks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetDefaultSortedPlaylistTracksProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getDefaultSortedPlaylistTracksHash() =>
    r'38b604cd5f85a459804c174426a400065db8ce9e';

final class GetDefaultSortedPlaylistTracksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<(List<BaseItemDto>, List<BaseItemDto>)>,
          BaseItemDto
        > {
  GetDefaultSortedPlaylistTracksFamily._()
    : super(
        retry: null,
        name: r'getDefaultSortedPlaylistTracksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetDefaultSortedPlaylistTracksProvider call(BaseItemDto parent) =>
      GetDefaultSortedPlaylistTracksProvider._(argument: parent, from: this);

  @override
  String toString() => r'getDefaultSortedPlaylistTracksProvider';
}

@ProviderFor(getSortedPlaylistTracks)
final getSortedPlaylistTracksProvider = GetSortedPlaylistTracksFamily._();

final class GetSortedPlaylistTracksProvider
    extends
        $FunctionalProvider<
          AsyncValue<(List<BaseItemDto>, List<BaseItemDto>)>,
          (List<BaseItemDto>, List<BaseItemDto>),
          FutureOr<(List<BaseItemDto>, List<BaseItemDto>)>
        >
    with
        $FutureModifier<(List<BaseItemDto>, List<BaseItemDto>)>,
        $FutureProvider<(List<BaseItemDto>, List<BaseItemDto>)> {
  GetSortedPlaylistTracksProvider._({
    required GetSortedPlaylistTracksFamily super.from,
    required (BaseItemDto, ResolvedSortConfig) super.argument,
  }) : super(
         retry: null,
         name: r'getSortedPlaylistTracksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getSortedPlaylistTracksHash();

  @override
  String toString() {
    return r'getSortedPlaylistTracksProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<(List<BaseItemDto>, List<BaseItemDto>)> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<(List<BaseItemDto>, List<BaseItemDto>)> create(Ref ref) {
    final argument = this.argument as (BaseItemDto, ResolvedSortConfig);
    return getSortedPlaylistTracks(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is GetSortedPlaylistTracksProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getSortedPlaylistTracksHash() =>
    r'f4cc84c7a588acdfabd32956b014e59d093f163b';

final class GetSortedPlaylistTracksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<(List<BaseItemDto>, List<BaseItemDto>)>,
          (BaseItemDto, ResolvedSortConfig)
        > {
  GetSortedPlaylistTracksFamily._()
    : super(
        retry: null,
        name: r'getSortedPlaylistTracksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetSortedPlaylistTracksProvider call(
    BaseItemDto parent,
    ResolvedSortConfig sortConfig,
  ) => GetSortedPlaylistTracksProvider._(
    argument: (parent, sortConfig),
    from: this,
  );

  @override
  String toString() => r'getSortedPlaylistTracksProvider';
}
