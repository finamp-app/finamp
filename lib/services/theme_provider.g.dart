// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$finampThemeHash() => r'1065d27efdcdb93cc700ae0c8ecf3245fabd3371';

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

/// See also [finampTheme].
@ProviderFor(finampTheme)
const finampThemeProvider = FinampThemeFamily();

/// See also [finampTheme].
class FinampThemeFamily extends Family<ColorScheme> {
  /// See also [finampTheme].
  const FinampThemeFamily();

  /// See also [finampTheme].
  FinampThemeProvider call(ThemeInfo request) {
    return FinampThemeProvider(request);
  }

  @override
  FinampThemeProvider getProviderOverride(
    covariant FinampThemeProvider provider,
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
  String? get name => r'finampThemeProvider';
}

/// See also [finampTheme].
class FinampThemeProvider extends AutoDisposeProvider<ColorScheme> {
  /// See also [finampTheme].
  FinampThemeProvider(ThemeInfo request)
    : this._internal(
        (ref) => finampTheme(ref as FinampThemeRef, request),
        from: finampThemeProvider,
        name: r'finampThemeProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$finampThemeHash,
        dependencies: FinampThemeFamily._dependencies,
        allTransitiveDependencies: FinampThemeFamily._allTransitiveDependencies,
        request: request,
      );

  FinampThemeProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.request,
  }) : super.internal();

  final ThemeInfo request;

  @override
  Override overrideWith(ColorScheme Function(FinampThemeRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: FinampThemeProvider._internal(
        (ref) => create(ref as FinampThemeRef),
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
  AutoDisposeProviderElement<ColorScheme> createElement() {
    return _FinampThemeProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FinampThemeProvider && other.request == request;
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
mixin FinampThemeRef on AutoDisposeProviderRef<ColorScheme> {
  /// The parameter `request` of this provider.
  ThemeInfo get request;
}

class _FinampThemeProviderElement
    extends AutoDisposeProviderElement<ColorScheme>
    with FinampThemeRef {
  _FinampThemeProviderElement(super.provider);

  @override
  ThemeInfo get request => (origin as FinampThemeProvider).request;
}

String _$themeImageHash() => r'4c14e6d1ad29267d4a93be3de5caf69e158bda5e';

/// See also [themeImage].
@ProviderFor(themeImage)
const themeImageProvider = ThemeImageFamily();

/// See also [themeImage].
class ThemeImageFamily extends Family<FinampThemeImage> {
  /// See also [themeImage].
  const ThemeImageFamily();

  /// See also [themeImage].
  ThemeImageProvider call(ThemeInfo request) {
    return ThemeImageProvider(request);
  }

  @override
  ThemeImageProvider getProviderOverride(
    covariant ThemeImageProvider provider,
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
  String? get name => r'themeImageProvider';
}

/// See also [themeImage].
class ThemeImageProvider extends AutoDisposeProvider<FinampThemeImage> {
  /// See also [themeImage].
  ThemeImageProvider(ThemeInfo request)
    : this._internal(
        (ref) => themeImage(ref as ThemeImageRef, request),
        from: themeImageProvider,
        name: r'themeImageProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$themeImageHash,
        dependencies: ThemeImageFamily._dependencies,
        allTransitiveDependencies: ThemeImageFamily._allTransitiveDependencies,
        request: request,
      );

  ThemeImageProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.request,
  }) : super.internal();

  final ThemeInfo request;

  @override
  Override overrideWith(
    FinampThemeImage Function(ThemeImageRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ThemeImageProvider._internal(
        (ref) => create(ref as ThemeImageRef),
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
  AutoDisposeProviderElement<FinampThemeImage> createElement() {
    return _ThemeImageProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ThemeImageProvider && other.request == request;
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
mixin ThemeImageRef on AutoDisposeProviderRef<FinampThemeImage> {
  /// The parameter `request` of this provider.
  ThemeInfo get request;
}

class _ThemeImageProviderElement
    extends AutoDisposeProviderElement<FinampThemeImage>
    with ThemeImageRef {
  _ThemeImageProviderElement(super.provider);

  @override
  ThemeInfo get request => (origin as ThemeImageProvider).request;
}

String _$finampThemeFromImageHash() =>
    r'2df81a892f2a2da45e6e351def4fe2102c0ef8df';

abstract class _$FinampThemeFromImage
    extends BuildlessAutoDisposeNotifier<ColorScheme> {
  late final ThemeColorRequest theme;

  ColorScheme build(ThemeColorRequest theme);
}

/// See also [FinampThemeFromImage].
@ProviderFor(FinampThemeFromImage)
const finampThemeFromImageProvider = FinampThemeFromImageFamily();

/// See also [FinampThemeFromImage].
class FinampThemeFromImageFamily extends Family<ColorScheme> {
  /// See also [FinampThemeFromImage].
  const FinampThemeFromImageFamily();

  /// See also [FinampThemeFromImage].
  FinampThemeFromImageProvider call(ThemeColorRequest theme) {
    return FinampThemeFromImageProvider(theme);
  }

  @override
  FinampThemeFromImageProvider getProviderOverride(
    covariant FinampThemeFromImageProvider provider,
  ) {
    return call(provider.theme);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'finampThemeFromImageProvider';
}

/// See also [FinampThemeFromImage].
class FinampThemeFromImageProvider
    extends AutoDisposeNotifierProviderImpl<FinampThemeFromImage, ColorScheme> {
  /// See also [FinampThemeFromImage].
  FinampThemeFromImageProvider(ThemeColorRequest theme)
    : this._internal(
        () => FinampThemeFromImage()..theme = theme,
        from: finampThemeFromImageProvider,
        name: r'finampThemeFromImageProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$finampThemeFromImageHash,
        dependencies: FinampThemeFromImageFamily._dependencies,
        allTransitiveDependencies:
            FinampThemeFromImageFamily._allTransitiveDependencies,
        theme: theme,
      );

  FinampThemeFromImageProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.theme,
  }) : super.internal();

  final ThemeColorRequest theme;

  @override
  ColorScheme runNotifierBuild(covariant FinampThemeFromImage notifier) {
    return notifier.build(theme);
  }

  @override
  Override overrideWith(FinampThemeFromImage Function() create) {
    return ProviderOverride(
      origin: this,
      override: FinampThemeFromImageProvider._internal(
        () => create()..theme = theme,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        theme: theme,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<FinampThemeFromImage, ColorScheme>
  createElement() {
    return _FinampThemeFromImageProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FinampThemeFromImageProvider && other.theme == theme;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, theme.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FinampThemeFromImageRef on AutoDisposeNotifierProviderRef<ColorScheme> {
  /// The parameter `theme` of this provider.
  ThemeColorRequest get theme;
}

class _FinampThemeFromImageProviderElement
    extends
        AutoDisposeNotifierProviderElement<FinampThemeFromImage, ColorScheme>
    with FinampThemeFromImageRef {
  _FinampThemeFromImageProviderElement(super.provider);

  @override
  ThemeColorRequest get theme => (origin as FinampThemeFromImageProvider).theme;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
