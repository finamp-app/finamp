// dart format width=120

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $ImagesGen {
  const $ImagesGen();

  /// File path: images/album_white.png
  AssetGenImage get albumWhite => const AssetGenImage('images/album_white.png');

  /// File path: images/finamp.png
  AssetGenImage get finamp => const AssetGenImage('images/finamp.png');

  /// File path: images/finamp_cropped.png
  AssetGenImage get finampCroppedPng => const AssetGenImage('images/finamp_cropped.png');

  /// File path: images/finamp_cropped.svg
  String get finampCroppedSvg => 'images/finamp_cropped.svg';

  /// File path: images/finamp_windows.ico
  String get finampWindows => 'images/finamp_windows.ico';

  /// File path: images/jellyfin-icon-transparent.png
  AssetGenImage get jellyfinIconTransparent => const AssetGenImage('images/jellyfin-icon-transparent.png');

  /// List of all assets
  List<dynamic> get values => [
    albumWhite,
    finamp,
    finampCroppedPng,
    finampCroppedSvg,
    finampWindows,
    jellyfinIconTransparent,
  ];
}

class $AssetsIconGen {
  const $AssetsIconGen();

  /// File path: assets/icon/icon_combined.png
  AssetGenImage get iconCombined => const AssetGenImage('assets/icon/icon_combined.png');

  /// File path: assets/icon/icon_square_bg-black.png
  AssetGenImage get iconSquareBgBlack => const AssetGenImage('assets/icon/icon_square_bg-black.png');

  /// File path: assets/icon/icon_square_bg-white.png
  AssetGenImage get iconSquareBgWhite => const AssetGenImage('assets/icon/icon_square_bg-white.png');

  /// File path: assets/icon/icon_white_noborder.png
  AssetGenImage get iconWhiteNoborder => const AssetGenImage('assets/icon/icon_white_noborder.png');

  /// List of all assets
  List<AssetGenImage> get values => [iconCombined, iconSquareBgBlack, iconSquareBgWhite, iconWhiteNoborder];
}

class Assets {
  const Assets._();

  static const $AssetsIconGen icon = $AssetsIconGen();
  static const $ImagesGen images = $ImagesGen();
}

class AssetGenImage {
  const AssetGenImage(this._assetName, {this.size, this.flavors = const {}, this.animation});

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({required this.isAnimation, required this.duration, required this.frames});

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
