import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:octo_image/src/image/fade_widget.dart';
import 'package:uuid/v4.dart';

import '../models/jellyfin_models.dart';
import '../services/album_image_provider.dart';
import '../services/theme_provider.dart';

typedef ImageProviderCallback = void Function(ImageProvider theme);

/// This widget provides the default look for album images throughout Finamp -
/// Aspect ratio 1 with a circular border radius of 4. If you don't want these
/// customisations, use [BareAlbumImage] or get an [ImageProvider] directly
/// through [AlbumImageInfo.init].
class AlbumImage extends ConsumerStatefulWidget {
  const AlbumImage({
    super.key,
    this.item,
    this.imageListenable,
    this.sizePreset,
    this.borderRadius,
    this.placeholderBuilder,
    this.disabled = false,
    this.autoScale = true,
    this.decoration,
    this.tapToZoom = false,
    this.onZoomRoute = false,
  });

  /// The item to get an image for.
  final BaseItemDto? item;

  final ProviderListenable<FinampImage>? imageListenable;

  final int? sizePreset;

  final BorderRadius? borderRadius;

  final WidgetBuilder? placeholderBuilder;

  final bool disabled;

  /// Whether to automatically scale the image to the size of the widget.
  final bool autoScale;

  final bool tapToZoom;

  final bool onZoomRoute;

  /// The decoration to use for the album image. This is defined in AlbumImage
  /// instead of being used as a separate widget so that non-square images don't
  /// look incorrect due to AlbumImage having an aspect ratio of 1:1
  final Decoration? decoration;

  static final defaultBorderRadius = BorderRadius.circular(4);

  @override
  ConsumerState<AlbumImage> createState() => _AlbumImageState();
}

class _AlbumImageState extends ConsumerState<AlbumImage> {
  final String zoomID = UuidV4().generate();
  int? currentPhysicalWidth;
  int? currentPhysicalHeight;

  @override
  void didUpdateWidget(AlbumImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // reset cached image size
    if (widget.sizePreset != oldWidget.sizePreset) {
      currentPhysicalWidth = null;
      currentPhysicalHeight = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? AlbumImage.defaultBorderRadius;
    assert(widget.item == null || widget.imageListenable == null);
    assert(!(widget.disabled && widget.tapToZoom));
    if ((widget.item == null || widget.item!.imageId == null) && widget.imageListenable == null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(decoration: widget.decoration, child: const _AlbumImageErrorPlaceholder()),
        ),
      );
    }

    final content = ClipRRect(borderRadius: borderRadius, child: _buildContent());

    return Semantics(
      // label: item?.name != null ? AppLocalizations.of(context)!.artworkTooltip(item!.name!) : AppLocalizations.of(context)!.artwork, // removed to reduce screen reader verbosity
      excludeSemantics: true,
      child: AspectRatio(aspectRatio: 1.0, child: widget.onZoomRoute ? content : Align(child: content)),
    );
  }

  Widget _buildContent() {
    final listenable = widget.imageListenable;

    if (listenable == null) {
      // If the current themeing context has a usable image for this item,
      // use that instead of generating a new request
      if (ref.watch(
        localImageProvider.select((localImage) => localImage.fullQuality && localImage.item == widget.item),
      )) {
        return _buildFromListenable(false, localImageProvider);
      } else {
        if (widget.autoScale) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // LayoutBuilder (and other pixel-related stuff in Flutter) returns logical pixels instead of physical pixels.
              // While this is great for doing layout stuff, we want to get images that are the right size in pixels.
              // Logical pixels aren't the same as the physical pixels on the device, they're quite a bit bigger.
              // If we use logical pixels for the image request, we'll get a smaller image than we want.
              // Because of this, we convert the logical pixels to physical pixels by multiplying by the device's DPI.
              final pixelRatio = MediaQuery.devicePixelRatioOf(context);
              int physicalWidth = currentPhysicalWidth ?? (constraints.maxWidth * pixelRatio).toInt();
              int physicalHeight = currentPhysicalHeight ?? (constraints.maxHeight * pixelRatio).toInt();
              if (widget.sizePreset != null) {
                currentPhysicalHeight = physicalHeight;
                currentPhysicalWidth = physicalWidth;
              }
              return _buildFromListenable(
                true,
                albumImageProvider(
                  AlbumImageRequest(item: widget.item!, maxWidth: physicalWidth, maxHeight: physicalHeight),
                ),
              );
            },
          );
        } else {
          return _buildFromListenable(false, albumImageProvider(AlbumImageRequest(item: widget.item!)));
        }
      }
    } else {
      return _buildFromListenable(false, listenable);
    }
  }

  Widget _buildFromListenable(bool imageScaled, ProviderListenable<FinampImage> listenable) {
    var image = Container(
      decoration: widget.decoration,
      child: BareAlbumImage(
        imageListenable: listenable,
        placeholderBuilder: widget.placeholderBuilder,
        onZoomRoute: widget.onZoomRoute,
      ),
    );

    if (widget.tapToZoom) {
      final largeImage = AlbumImage(
        item: imageScaled ? widget.item : null,
        imageListenable: imageScaled ? null : listenable,
        borderRadius: BorderRadius.zero,
        placeholderBuilder: (_) => Stack(
          fit: StackFit.passthrough,
          children: [
            image,
            const Center(child: CircularProgressIndicator.adaptive()),
          ],
        ),
        autoScale: false,
        tapToZoom: false,
        onZoomRoute: true,
      );
      // Show album as clickable on desktop
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder<_ZoomedImage>(
              opaque: false,
              barrierDismissible: true,
              transitionDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
                return _ZoomedImage(albumImage: largeImage, id: zoomID);
              },
            ),
          ),
          child: Hero(
            tag: zoomID,
            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
            child: image,
            placeholderBuilder: (context, heroSize, child) => image,
            flightShuttleBuilder: (_, __, ___, ____, _____) => largeImage,
          ),
        ),
      );
    }

    return widget.disabled
        ? Opacity(
            opacity: 0.75,
            child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.black, BlendMode.color), child: image),
          )
        : image;
  }
}

/// An [AlbumImage] without any of the padding or media size detection.
class BareAlbumImage extends ConsumerWidget {
  const BareAlbumImage({super.key, required this.imageListenable, this.placeholderBuilder, required this.onZoomRoute});

  final ProviderListenable<FinampImage> imageListenable;
  final WidgetBuilder? placeholderBuilder;
  final bool onZoomRoute;

  static Widget defaultPlaceholderBuilder(BuildContext context) {
    return Container(color: Theme.of(context).cardColor);
  }

  static Widget defaultErrorBuilder(BuildContext context, _, __) {
    return const _AlbumImageErrorPlaceholder();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageInfo = ref.watch(imageListenable);
    final blurHash = imageInfo.item?.blurHash;
    final image = imageInfo.image;
    var localPlaceholder = placeholderBuilder;
    if (blurHash != null) {
      localPlaceholder ??= (_) => Image(
        fit: BoxFit.contain,
        image: BlurHashImage(
          blurHash,
          // Allow scaling blurhashes up to 3200 pixels wide by setting scale
          scale: 0.01,
        ),
      );
    }
    localPlaceholder ??= defaultPlaceholderBuilder;

    if (image != null) {
      final fadeTime = MediaQuery.disableAnimationsOf(context) || onZoomRoute
          ? Duration.zero
          : const Duration(milliseconds: 700);

      return Image(
        key: ValueKey(image),
        image: image,
        frameBuilder: (_, child, frame, _) => ImageFader(
          key: ValueKey(image),
          fadeTime: fadeTime,
          placeholder: localPlaceholder!(context),
          image: frame != null ? child : null,
        ),
        fit: BoxFit.contain,
        alignment: Alignment.center,
        repeat: ImageRepeat.noRepeat,
        matchTextDirection: false,
        filterQuality: FilterQuality.medium,
        errorBuilder: defaultErrorBuilder,
      );
    }

    return Builder(builder: localPlaceholder);
  }
}

/// Wait for an image to load and fade it in over the placeholder.  This is based on Octoimage, but with the ability to
/// dynamically reduce the fade time for images which load quickly.
class ImageFader extends StatefulWidget {
  const ImageFader({super.key, required this.fadeTime, required this.placeholder, required this.image});

  final Duration fadeTime;
  final Widget placeholder;
  final Widget? image;

  @override
  State<ImageFader> createState() => _ImageFaderState();
}

class _ImageFaderState extends State<ImageFader> {
  bool wasSyncronouslyLoaded = true;
  DateTime? startTime;
  Duration? fadeTime;

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    // If we have never built without the image, just return the child without the fadein stack
    if (image != null && wasSyncronouslyLoaded) return image;

    wasSyncronouslyLoaded = false;
    startTime ??= DateTime.now();

    if (image == null) return widget.placeholder;

    // This point is only reached when we have previously shown the placeholder but have now been rebuilt with a loaded image
    if (fadeTime == null) {
      // The widget fade in time is the smaller of the widget fadeTime or the time between widget creation and initial image load
      final loadTime = DateTime.now().difference(startTime!);
      fadeTime = Duration(
        microseconds: loadTime.inMicroseconds.clamp(Duration.zero.inMicroseconds, widget.fadeTime.inMicroseconds),
      );
    }
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: [
        FadeWidget(duration: fadeTime!, curve: Curves.easeIn, child: image),
        FadeWidget(
          duration: fadeTime!,
          curve: Curves.easeOut,
          direction: AnimationDirection.reverse,
          child: widget.placeholder,
        ),
      ],
    );
  }
}

class _AlbumImageErrorPlaceholder extends StatelessWidget {
  const _AlbumImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(color: Theme.of(context).cardColor, child: const Icon(Icons.album));
  }
}

class _ZoomedImage extends StatelessWidget {
  final Widget albumImage;
  final String id;

  const _ZoomedImage({required this.albumImage, required this.id});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), child: SizedBox.expand()),
            ),
          ),
        ),
        Center(
          child: InteractiveViewer(
            constrained: true,
            panEnabled: true,
            clipBehavior: Clip.none,
            child: Hero(
              tag: id,
              createRectTween: (begin, end) => RectTween(begin: begin, end: end),
              child: albumImage,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 8,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(TablerIcons.x),
              color: Colors.white,
              iconSize: 32.0,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ],
    );
  }
}
