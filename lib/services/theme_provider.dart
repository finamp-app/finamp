import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:finamp/extensions/color_extensions.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import 'widget_bindings_observer_provider.dart';

part 'theme_provider.g.dart';

final themeProviderLogger = Logger("ThemeProvider");

class PlayerScreenTheme extends StatelessWidget {
  final Widget child;
  final Duration? themeTransitionDuration;
  final ThemeData Function(ThemeData)? themeOverride;

  const PlayerScreenTheme({super.key, required this.child, this.themeTransitionDuration, this.themeOverride});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final image = ref.watch(currentAlbumImageProvider);
        // Directly watching currentAlbumImageProvider in the override seems to have issues with not rebuilding the
        // provider until after the consuming widgets have already started building, so watch in a surrounding consumer
        // to work around this.
        return ProviderScope(overrides: [localImageProvider.overrideWithValue(image)], child: child!);
      },
      child: Consumer(
        builder: (context, ref, child) {
          // precache adjacent themes
          final List<FinampQueueItem> precacheItems = GetIt.instance<QueueService>().peekQueue(
            next: 2,
            previous: 1,
            current: true,
          );
          for (final itemToPrecache in precacheItems) {
            final base = itemToPrecache.baseItem;
            ref.listen(finampThemeProvider(ThemeInfo(base, useLargeImage: true)), (_, __) {});
          }
          var theme = Theme.of(context).withColorScheme(ref.watch(localThemeProvider));
          if (themeOverride != null) {
            theme = themeOverride!(theme);
          }
          return AnimatedTheme(
            duration: getThemeTransitionDuration(context, themeTransitionDuration),
            data: theme,
            child: child!,
          );
        },
        child: child,
      ),
    );
  }
}

class ItemTheme extends StatelessWidget {
  final Widget child;
  final BaseItemDto item;
  final Duration? themeTransitionDuration;
  final ThemeData Function(ThemeData)? themeOverride;

  const ItemTheme({
    super.key,
    required this.item,
    required this.child,
    this.themeTransitionDuration,
    this.themeOverride,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [localThemeInfoProvider.overrideWithValue(ThemeInfo(item))],
      child: Consumer(
        builder: (context, ref, child) {
          var theme = Theme.of(context).withColorScheme(ref.watch(localThemeProvider));
          if (themeOverride != null) {
            theme = themeOverride!(theme);
          }
          return AnimatedTheme(
            duration: getThemeTransitionDuration(context, themeTransitionDuration),
            data: theme,
            child: child!,
          );
        },
        child: child,
      ),
    );
  }
}

/// The local ThemeInfo request.  Do not read this directly, use [localImageProvider].
final Provider<ThemeInfo?> localThemeInfoProvider = Provider((ref) => null, dependencies: const []);

final Provider<FinampImage> localImageProvider = Provider((ref) {
  var item = ref.watch(localThemeInfoProvider);
  if (item == null) {
    return FinampImage.empty();
  }
  return ref.watch(themeImageProvider(item));
}, dependencies: [localThemeInfoProvider]);

final Provider<ColorScheme> localThemeProvider = Provider((ref) {
  var image = ref.watch(localImageProvider);
  if (image is FinampThemeImage) {
    return ref.watch(finampThemeFromImageProvider(image.colorRequest));
  }
  return getGrayTheme(ref.watch(brightnessProvider));
}, dependencies: [localImageProvider]);

@riverpod
ColorScheme finampTheme(Ref ref, ThemeInfo request) {
  var image = ref.watch(themeImageProvider(request));
  return ref.watch(finampThemeFromImageProvider(image.colorRequest));
}

@riverpod
FinampThemeImage themeImage(Ref ref, ThemeInfo request) {
  var item = request.item;
  String? cacheKey = request.item.blurHash ?? request.item.imageId;
  // If useLargeImage, we are doing theme pre-caching for the player and should always use the full-size image,
  // even if no-one else is currently using it.
  if (request.useLargeImage) {
    final albumImage = ref.watch(albumImageProvider(AlbumImageRequest(item: item)));
    assert(albumImage.fullQuality);
    return albumImage.asTheme(request);
  }
  // Re-use an existing request if possible to hit the image cache
  else if (albumRequestsCache.containsKey(cacheKey)) {
    if (albumRequestsCache[cacheKey] == null) {
      return FinampThemeImage.empty(request);
    }
    final albumImage = ref.watch(albumImageProvider(albumRequestsCache[cacheKey]!));
    return albumImage.asTheme(request);
  } else {
    // Use blurhash if possible, otherwise fetch 100x100
    if (item.blurHash != null) {
      final image = BlurHashImage(item.blurHash!);
      return FinampThemeImage(image, request, fullQuality: false);
    } else if (item.imageId != null) {
      // ignore: avoid_manual_providers_as_generated_provider_dependency
      final albumImage = ref.watch(albumImageProvider(AlbumImageRequest(item: item, maxHeight: 100, maxWidth: 100)));
      return albumImage.asTheme(request);
    } else {
      return FinampThemeImage.empty(request);
    }
  }
}

@riverpod
class FinampThemeFromImage extends _$FinampThemeFromImage {
  @override
  ColorScheme build(ThemeColorRequest theme) {
    var brightness = ref.watch(brightnessProvider);
    if (theme.image == null) {
      return getGrayTheme(brightness);
    }
    final cachedColors = _getImageTheme(theme.blurHash);
    if (cachedColors != null) {
      return _getColorScheme(cachedColors, brightness);
    }

    Future.sync(() async {
      /*return await ColorScheme.fromImageProvider(
        provider: request.image!,
        brightness: brightness,
      );*/

      var image = await _fetchImage(theme.image!);
      if (image == null) {
        return getDefaultTheme(brightness);
      }
      // TODO this calculation can take several seconds for very large images.  Scale before using or
      // switch to ColorScheme.fromImageProvider, which has this built in.
      final colors = await _getColorsForImage(image, theme.useIsolate);
      if (colors == null) {
        return getDefaultTheme(brightness);
      }
      if (theme.fullQuality) {
        // If image is downloaded but no theme is cached, and we are using the full size player image, attempt to cache value.
        _setImageTheme(theme.blurHash, colors);
        // Keep cached player themes until app closure, as they can take several seconds to calculate
        ref.keepAlive();
      }
      themeProviderLogger.finer("Calculated theme color ${colors.highlight} for image $image");
      return _getColorScheme(colors, brightness);
    }).then((value) => state = value);
    return getGrayTheme(brightness);
  }

  RawThemeResult? _getImageTheme(String? blurHash) {
    if (blurHash == null) {
      return null;
    }
    final box = Hive.box<RawThemeResult>("CachedThemes");
    return box.get(blurHash);
  }

  // Only images with a blurhash can have themes cached, because it might be possible for images
  // with only an imageId to be updated and require a retheme.
  void _setImageTheme(String? blurHash, RawThemeResult colors) {
    if (blurHash == null) {
      return;
    }
    final box = Hive.box<RawThemeResult>("CachedThemes");
    box.put(blurHash, colors);
  }

  Future<ImageInfo?> _fetchImage(ImageProvider image) {
    ImageStream stream = image.resolve(const ImageConfiguration(devicePixelRatio: 1.0, size: Size(5, 5)));
    ImageStreamListener? listener;
    Completer<ImageInfo?> completer = Completer();

    listener = ImageStreamListener(
      (listenerImage, synchronousCall) async {
        stream.removeListener(listener!);
        completer.complete(listenerImage);
      },
      onError: (e, stack) {
        stream.removeListener(listener!);
        completer.complete(null);
        themeProviderLogger.severe(e, e, stack);
      },
    );

    ref.onDispose(() {
      if (!completer.isCompleted) {
        stream.removeListener(listener!);
      }
    });

    stream.addListener(listener);
    return completer.future;
  }

  Future<RawThemeResult?> _getColorsForImage(ImageInfo image, bool useIsolate) async {
    final PaletteGenerator palette;
    try {
      palette = await PaletteGenerator.fromImage(image.image, useIsolate: useIsolate);
    } catch (e, stack) {
      themeProviderLogger.severe(e, e, stack);
      return null;
    } finally {
      image.dispose();
    }

    // Calculate image average color
    int population = 0;
    double r = 0;
    double g = 0;
    double b = 0;
    for (var color in palette.paletteColors) {
      population += color.population;
      r += color.color.r * color.population;
      g += color.color.g * color.population;
      b += color.color.b * color.population;
    }
    HSLColor average;
    if (population == 0) {
      return RawThemeResult.fromColors(Color.fromARGB(255, 0, 164, 220), Color.fromARGB(255, 0, 164, 220));
    } else {
      average = HSLColor.fromColor(
        Color.from(alpha: 1.0, red: r / population, green: g / population, blue: b / population),
      );
    }

    // Find the palette color most similar to average, disregarding brightness
    double maxScore = 0.93;
    Color? bestMatch;
    for (var color in palette.paletteColors) {
      final hslColor = HSLColor.fromColor(color.color);
      final saturationScore = 0.4 * (1.0 - (hslColor.saturation - average.saturation).abs());
      final hueScore = 0.6 * (1.0 - ((hslColor.hue - average.hue).abs() / 360.0));
      final score = saturationScore + hueScore;
      if (score > maxScore) {
        maxScore = score;
        bestMatch = color.color;
      }
    }
    Color background;
    // If we found a match beyond our minimum similarity score, use that at the target brightness instead of the average
    // This can sometimes help with the background color feeling slightly off
    if (bestMatch == null) {
      background = average.toColor();
    } else {
      background = HSLColor.fromColor(bestMatch).withLightness(average.lightness).toColor();
    }

    return RawThemeResult.fromColors(
      palette.vibrantColor?.color ?? palette.dominantColor?.color ?? const Color.fromARGB(255, 0, 164, 220),
      background,
    );
  }

  ColorScheme _getColorScheme(RawThemeResult colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = Color.alphaBlend(
      isDark ? Colors.black.withOpacity(0.675) : Colors.white.withOpacity(0.675),
      colors.background,
    );

    final accent = colors.highlight.atContrast(
      ref.watch(finampSettingsProvider.useHighContrastColors) ? 8.0 : 5.5,
      background,
      isDark,
    );

    final surfaceText = Color.alphaBlend(
      isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.85),
      colors.highlight,
    );

    return ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: background,
      // We should probably set this ourselves, as otherwise it will be set based on the default
      // surface color for the seed instead of our overridden value.
      onSurface: surfaceText,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  }
}

ColorScheme getGrayTheme(Brightness brightness) {
  final grayForDarkTheme = const Color.fromARGB(255, 133, 133, 133);
  final grayForLightTheme = const Color.fromARGB(255, 61, 61, 61);

  Color accent = brightness == Brightness.dark
      ? grayForDarkTheme.atContrast(
          FinampSettingsHelper.finampSettings.useHighContrastColors ? 8.0 : 5.5,
          Color.alphaBlend(Colors.black.withOpacity(0.675), grayForDarkTheme),
          true,
        )
      : grayForLightTheme.atContrast(
          FinampSettingsHelper.finampSettings.useHighContrastColors ? 8.0 : 5.5,
          Color.alphaBlend(Colors.white.withOpacity(0.675), grayForLightTheme),
          true,
        );

  return ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
}

final defaultThemeDark = ColorScheme.fromSeed(
  seedColor: const Color.fromARGB(255, 0, 164, 220),
  brightness: Brightness.dark,
);

final defaultThemeLight = ColorScheme.fromSeed(
  seedColor: const Color.fromARGB(255, 0, 164, 220),
  brightness: Brightness.light,
);

ColorScheme getDefaultTheme(Brightness brightness) =>
    brightness == Brightness.dark ? defaultThemeDark : defaultThemeLight;

@immutable
class ThemeInfo {
  const ThemeInfo(this.item, {this.useIsolate = true, this.useLargeImage = false});

  final BaseItemDto item;

  final bool useIsolate;

  final bool useLargeImage;

  @override
  bool operator ==(Object other) {
    return other is ThemeInfo && other._imageCode == _imageCode && other.useLargeImage == useLargeImage;
  }

  @override
  int get hashCode => Object.hash(_imageCode, useLargeImage);

  String? get _imageCode => item.blurHash ?? item.imageId;
}

@immutable
class FinampImage {
  const FinampImage.empty() : image = null, fullQuality = false;
  const FinampImage(this.image, {this.fullQuality = false});

  /// The imageProvider associated with [request]
  final ImageProvider? image;

  /// Whether we have the full-size imageProvider usable in any scenario, or a rescaled version.
  final bool fullQuality;

  BaseItemDto? get item => null;

  @override
  bool operator ==(Object other) {
    return other is FinampImage && other.image == image && other.item == item;
  }

  @override
  String toString() => "FinampImage(image: $image item: ${item?.name} fullQuality: $fullQuality)";

  @override
  int get hashCode => Object.hash(image, item);
}

@immutable
class FinampThemeImage extends FinampImage {
  const FinampThemeImage(super.image, this.themeRequest, {required super.fullQuality});
  const FinampThemeImage.empty(this.themeRequest) : super(null, fullQuality: true);

  final ThemeInfo themeRequest;

  ThemeColorRequest get colorRequest => ThemeColorRequest(image, item.blurHash, themeRequest.useIsolate, fullQuality);

  @override
  BaseItemDto get item => themeRequest.item;
}

@immutable
/// A request to calculate a theme color.  This is separate from [FinampThemeImage] as this does not consider
/// BaseItemDto.id when determining duplicates.
class ThemeColorRequest {
  const ThemeColorRequest(this.image, this.blurHash, this.useIsolate, this.fullQuality);

  final ImageProvider? image;

  final String? blurHash;

  final bool useIsolate;

  final bool fullQuality;

  @override
  bool operator ==(Object other) {
    return other is ThemeColorRequest && other.image == image && other.blurHash == blurHash;
  }

  @override
  int get hashCode => Object.hash(image, blurHash);
}

_ThemeTransitionCalculator? _calculator;

Duration getThemeTransitionDuration(BuildContext context, Duration? duration) =>
    (_calculator ??= _ThemeTransitionCalculator()).getThemeTransitionDuration(context, duration);

/// Skip track change transition animations if app or route is in background
class _ThemeTransitionCalculator {
  _ThemeTransitionCalculator() {
    AppLifecycleListener(
      onShow: () {
        // Continue skipping until we get a foreground track change.
        _skipAllTransitions = true;
      },
      onHide: () {
        _skipAllTransitions = true;
      },
      onRestart: () {
        unawaited(fetchSystemPalette());
      },
      onResume: () {
        unawaited(fetchSystemPalette());
      },
    );
    GetIt.instance<QueueService>().getCurrentTrackStream().listen((value) {
      _skipAllTransitions = false;
    });
  }

  bool _skipAllTransitions = false;

  Duration getThemeTransitionDuration(BuildContext context, Duration? duration) {
    if (_skipAllTransitions || MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return (context.mounted && (ModalRoute.isCurrentOf(context) ?? true))
        ? duration ?? const Duration(milliseconds: 1000)
        : Duration.zero;
  }
}

Future<void> fetchSystemPalette() async {
  final currentColor = FinampSettingsHelper.finampSettings.systemAccentColor;
  Color? newColor;

  if (Platform.isAndroid) {
    final palette = await DynamicColorPlugin.getCorePalette();
    newColor = palette?.toColorScheme().primary;
  } else {
    newColor = await DynamicColorPlugin.getAccentColor();
  }

  // only update when needed (color transitions is laggy, no need to run it when not required)
  if (newColor != currentColor) {
    FinampSetters.setSystemAccentColor(newColor);
  }
}
