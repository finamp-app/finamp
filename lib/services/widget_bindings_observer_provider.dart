import 'dart:ui';

import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final displayFeaturesProvider = StateProvider<List<DisplayFeature>>((ref) {
  return [];
});

final brightnessProvider = StateProvider((ref) => Brightness.dark);

final halfOpenFoldableProvider = Provider(
  (ref) => ref.watch(
    displayFeaturesProvider.select(
      (x) => x.any(
        (d) =>
            (d.type == DisplayFeatureType.fold || d.type == DisplayFeatureType.hinge) &&
            // Flip-style foldable, top == bottom, height == 0
            d.bounds.height == 0 &&
            d.state == DisplayFeatureState.postureHalfOpened,
      ),
    ),
  ),
);

class FinampProviderBuilder extends ConsumerStatefulWidget {
  const FinampProviderBuilder({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FinampProviderBuilder> createState() => _FinampProviderBuilderState();
}

class _FinampProviderBuilderState extends ConsumerState<FinampProviderBuilder> with WidgetsBindingObserver {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(finampSettingsProvider.themeMode, (_, _) => didChangePlatformBrightness());
    Future.microtask(() {
      didChangePlatformBrightness();
      didChangeMetrics();
      setState(() {
        _initialized = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return SizedBox.shrink();
    }
    final textScaling = ref.watch(finampSettingsProvider.textScaleOverride);
    if (textScaling != null) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: FinampTextScaler(textScaling)),
        child: widget.child,
      );
    }
    return widget.child;
  }

  @override
  void didChangePlatformBrightness() {
    final themeMode = FinampSettingsHelper.finampSettings.themeMode;
    var theme = switch (themeMode) {
      ThemeMode.system => View.of(context).platformDispatcher.platformBrightness,
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };
    ref.read(brightnessProvider.notifier).state = theme;
  }

  @override
  void didChangeMetrics() {
    ref.read(displayFeaturesProvider.notifier).state = View.of(context).displayFeatures;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class FinampTextScaler extends TextScaler {
  const FinampTextScaler(this.scaleFactor);
  final double scaleFactor;

  @override
  double scale(double fontSize) {
    // This is calibrated to roughly match android scaling.
    // Scaling is fully applied at 8.0, not applied at all at 100.0
    final applicationFactor = (100 - fontSize) / 92;
    return fontSize * (1.0 + (scaleFactor - 1.0) * applicationFactor);
  }

  @override
  double get textScaleFactor => scaleFactor;
}
