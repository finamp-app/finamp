// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'network_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$networkConnectivityHash() =>
    r'1cc9077420cebb8508807040e7ac651db9ddebdb';

/// See also [networkConnectivity].
@ProviderFor(networkConnectivity)
final networkConnectivityProvider =
    AutoDisposeFutureProvider<FinampConnectivityState>.internal(
      networkConnectivity,
      name: r'networkConnectivityProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$networkConnectivityHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NetworkConnectivityRef =
    AutoDisposeFutureProviderRef<FinampConnectivityState>;
String _$serverReachabilityHash() =>
    r'8a194cfe868cf2daa174aa41e6b66038c37691be';

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

/// See also [serverReachability].
@ProviderFor(serverReachability)
const serverReachabilityProvider = ServerReachabilityFamily();

/// See also [serverReachability].
class ServerReachabilityFamily extends Family<AsyncValue<bool>> {
  /// See also [serverReachability].
  const ServerReachabilityFamily();

  /// See also [serverReachability].
  ServerReachabilityProvider call(ServerPingType target) {
    return ServerReachabilityProvider(target);
  }

  @override
  ServerReachabilityProvider getProviderOverride(
    covariant ServerReachabilityProvider provider,
  ) {
    return call(provider.target);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'serverReachabilityProvider';
}

/// See also [serverReachability].
class ServerReachabilityProvider extends AutoDisposeFutureProvider<bool> {
  /// See also [serverReachability].
  ServerReachabilityProvider(ServerPingType target)
    : this._internal(
        (ref) => serverReachability(ref as ServerReachabilityRef, target),
        from: serverReachabilityProvider,
        name: r'serverReachabilityProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$serverReachabilityHash,
        dependencies: ServerReachabilityFamily._dependencies,
        allTransitiveDependencies:
            ServerReachabilityFamily._allTransitiveDependencies,
        target: target,
      );

  ServerReachabilityProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.target,
  }) : super.internal();

  final ServerPingType target;

  @override
  Override overrideWith(
    FutureOr<bool> Function(ServerReachabilityRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ServerReachabilityProvider._internal(
        (ref) => create(ref as ServerReachabilityRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        target: target,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _ServerReachabilityProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ServerReachabilityProvider && other.target == target;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, target.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ServerReachabilityRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `target` of this provider.
  ServerPingType get target;
}

class _ServerReachabilityProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with ServerReachabilityRef {
  _ServerReachabilityProviderElement(super.provider);

  @override
  ServerPingType get target => (origin as ServerReachabilityProvider).target;
}

String _$setOfflineModeHash() => r'ae4c901aadd01076c3f1599a60065e28a8811949';

/// See also [setOfflineMode].
@ProviderFor(setOfflineMode)
final setOfflineModeProvider = AutoDisposeProvider<bool?>.internal(
  setOfflineMode,
  name: r'setOfflineModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$setOfflineModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SetOfflineModeRef = AutoDisposeProviderRef<bool?>;
String _$setLocalUrlHash() => r'c02273e921a5d35a5a8a174bdf4756be44488101';

/// See also [setLocalUrl].
@ProviderFor(setLocalUrl)
final setLocalUrlProvider = AutoDisposeProvider<bool?>.internal(
  setLocalUrl,
  name: r'setLocalUrlProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$setLocalUrlHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SetLocalUrlRef = AutoDisposeProviderRef<bool?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
