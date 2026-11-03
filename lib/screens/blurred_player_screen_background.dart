import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:octo_image/octo_image.dart';

import '../services/theme_provider.dart';

/// Same as [_PlayerScreenAlbumImage], but with a BlurHash instead. We also
/// filter the BlurHash so that it works as a background image.
class BlurredPlayerScreenBackground extends ConsumerWidget {
  /// should never be less than 1.0
  final double opacityFactor;

  const BlurredPlayerScreenBackground({super.key, this.opacityFactor = 1.0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finampImage = ref.watch(localImageProvider);
    final localBlurhash = finampImage.item?.blurHash;
    final imageProvider = finampImage.image;

    var overlayColor = Theme.brightnessOf(context) == Brightness.dark
        ? Colors.black.withValues(alpha: ui.clampDouble(0.675 * opacityFactor, 0.0, 1.0))
        : Colors.white.withValues(alpha: ui.clampDouble(0.75 * opacityFactor, 0.0, 1.0));

    Widget placeholderBuilder(_) => localBlurhash != null
        ? SizedBox.expand(
            child: Image(
              fit: BoxFit.cover,
              color: overlayColor,
              colorBlendMode: BlendMode.srcOver,
              image: BlurHashImage(localBlurhash),
            ),
          )
        : const SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: getThemeTransitionDuration(context, null),
        switchOutCurve: const Threshold(0.0),
        child: imageProvider == null
            ? placeholderBuilder(null)
            : OctoImage(
                // Don't transition between images with identical files/urls unless
                // system theme has changed
                key: ValueKey(imageProvider.hashCode + Theme.brightnessOf(context).hashCode),
                image: imageProvider,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                color: overlayColor,
                colorBlendMode: BlendMode.srcOver,
                filterQuality: FilterQuality.none,
                errorBuilder: (x, _, _) => placeholderBuilder(x),
                placeholderBuilder: placeholderBuilder,
                imageBuilder: (context, child) {
                  var image = ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 85, sigmaY: 85, tileMode: TileMode.mirror),
                    child: SizedBox.expand(child: child),
                  );
                  // There seems to be some sort of issue with how Linux handles ui.Image that breaks
                  // cachePaint.  This shouldn't be too important outside mobile, though.
                  if (Platform.isLinux) {
                    return image;
                  }
                  return CachePaint(imageKey: imageProvider, child: image);
                },
              ),
      ),
    );
  }
}

class CachePaint extends SingleChildRenderObjectWidget {
  const CachePaint({super.key, super.child, required this.imageKey});

  final ImageProvider imageKey;

  @override
  void updateRenderObject(BuildContext context, RenderCachePaint renderObject) {
    renderObject.screenSize = MediaQuery.sizeOf(context);
  }

  @override
  RenderCachePaint createRenderObject(BuildContext context) {
    return RenderCachePaint(imageKey, MediaQuery.sizeOf(context), Theme.brightnessOf(context));
  }
}

class RenderCachePaint extends RenderProxyBox {
  RenderCachePaint(this._imageKey, this._screenSize, this._brightness);

  final ImageProvider _imageKey;

  int get _cacheKey => Object.hash(_imageKey, _screenSize, _brightness);

  Size _screenSize;

  final Brightness _brightness;

  set screenSize(Size value) {
    if (value != _screenSize) {
      _disposeCache();
    }
    _screenSize = value;
  }

  static final Map<int, (List<RenderCachePaint>, ui.Image?)> _cache = {};

  @override
  void performLayout() {
    child?.layout(BoxConstraints.tightFor(width: _screenSize.width, height: _screenSize.height));
    size = constraints.biggest;
    return;
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, ui.Offset offset) {
    if (_cache[_cacheKey] != null) {
      if (!_cache[_cacheKey]!.$1.contains(this)) {
        // Add use to list of widgets using image
        _cache[_cacheKey]!.$1.add(this);
      }
      if (_cache[_cacheKey]!.$2 != null) {
        // Use cached child
        context.canvas.drawImage(_cache[_cacheKey]!.$2!, offset, Paint());
      } else {
        // Image is currently building, so paint child and move on.
        super.paint(context, offset);
      }
    } else {
      // Create cache entry
      _cache[_cacheKey] = ([this], null);
      // Paint our child
      super.paint(context, offset);
      // Save image of child to cache
      final OffsetLayer offsetLayer = layer! as OffsetLayer;
      Future.sync(() async {
        _cache[_cacheKey] = (_cache[_cacheKey]!.$1, await offsetLayer.toImage(offset & _screenSize));
        // Schedule repaint next frame because the image is lighter than the full
        // child during compositing, which is more frequent than paints.
        for (var element in _cache[_cacheKey]!.$1) {
          element.markNeedsPaint();
        }
      });
    }
  }

  void _disposeCache() {
    _cache[_cacheKey]?.$1.remove(this);
    if (_cache[_cacheKey]?.$1.isEmpty ?? false) {
      // If we are last user of image, dispose
      _cache[_cacheKey]?.$2?.dispose();
      _cache.remove(_cacheKey);
    }
  }

  @override
  void dispose() {
    _disposeCache();
    super.dispose();
  }
}
