// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(finampTheme)
final finampThemeProvider = FinampThemeFamily._();

final class FinampThemeProvider
    extends $FunctionalProvider<ColorScheme, ColorScheme, ColorScheme>
    with $Provider<ColorScheme> {
  FinampThemeProvider._({
    required FinampThemeFamily super.from,
    required ThemeInfo super.argument,
  }) : super(
         retry: null,
         name: r'finampThemeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$finampThemeHash();

  @override
  String toString() {
    return r'finampThemeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ColorScheme> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ColorScheme create(Ref ref) {
    final argument = this.argument as ThemeInfo;
    return finampTheme(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ColorScheme value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ColorScheme>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FinampThemeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$finampThemeHash() => r'1065d27efdcdb93cc700ae0c8ecf3245fabd3371';

final class FinampThemeFamily extends $Family
    with $FunctionalFamilyOverride<ColorScheme, ThemeInfo> {
  FinampThemeFamily._()
    : super(
        retry: null,
        name: r'finampThemeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinampThemeProvider call(ThemeInfo request) =>
      FinampThemeProvider._(argument: request, from: this);

  @override
  String toString() => r'finampThemeProvider';
}

@ProviderFor(themeImage)
final themeImageProvider = ThemeImageFamily._();

final class ThemeImageProvider
    extends
        $FunctionalProvider<
          FinampThemeImage,
          FinampThemeImage,
          FinampThemeImage
        >
    with $Provider<FinampThemeImage> {
  ThemeImageProvider._({
    required ThemeImageFamily super.from,
    required ThemeInfo super.argument,
  }) : super(
         retry: null,
         name: r'themeImageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$themeImageHash();

  @override
  String toString() {
    return r'themeImageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<FinampThemeImage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FinampThemeImage create(Ref ref) {
    final argument = this.argument as ThemeInfo;
    return themeImage(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinampThemeImage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinampThemeImage>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ThemeImageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$themeImageHash() => r'4c14e6d1ad29267d4a93be3de5caf69e158bda5e';

final class ThemeImageFamily extends $Family
    with $FunctionalFamilyOverride<FinampThemeImage, ThemeInfo> {
  ThemeImageFamily._()
    : super(
        retry: null,
        name: r'themeImageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ThemeImageProvider call(ThemeInfo request) =>
      ThemeImageProvider._(argument: request, from: this);

  @override
  String toString() => r'themeImageProvider';
}

@ProviderFor(FinampThemeFromImage)
final finampThemeFromImageProvider = FinampThemeFromImageFamily._();

final class FinampThemeFromImageProvider
    extends $NotifierProvider<FinampThemeFromImage, ColorScheme> {
  FinampThemeFromImageProvider._({
    required FinampThemeFromImageFamily super.from,
    required ThemeColorRequest super.argument,
  }) : super(
         retry: null,
         name: r'finampThemeFromImageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$finampThemeFromImageHash();

  @override
  String toString() {
    return r'finampThemeFromImageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FinampThemeFromImage create() => FinampThemeFromImage();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ColorScheme value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ColorScheme>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FinampThemeFromImageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$finampThemeFromImageHash() =>
    r'2df81a892f2a2da45e6e351def4fe2102c0ef8df';

final class FinampThemeFromImageFamily extends $Family
    with
        $ClassFamilyOverride<
          FinampThemeFromImage,
          ColorScheme,
          ColorScheme,
          ColorScheme,
          ThemeColorRequest
        > {
  FinampThemeFromImageFamily._()
    : super(
        retry: null,
        name: r'finampThemeFromImageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FinampThemeFromImageProvider call(ThemeColorRequest theme) =>
      FinampThemeFromImageProvider._(argument: theme, from: this);

  @override
  String toString() => r'finampThemeFromImageProvider';
}

abstract class _$FinampThemeFromImage extends $Notifier<ColorScheme> {
  late final _$args = ref.$arg as ThemeColorRequest;
  ThemeColorRequest get theme => _$args;

  ColorScheme build(ThemeColorRequest theme);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ColorScheme, ColorScheme>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ColorScheme, ColorScheme>,
              ColorScheme,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
