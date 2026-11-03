import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

final _carPlayImageLogger = Logger("CarPlayImages");

/// Image size for CarPlay artwork. 100x100 is plenty for car displays
/// and transfers much faster than 200x200.
const _carPlayImageSize = 100;

/// Last resort artwork stand-in when the rendered placeholder tile is unavailable.
const _carPlayFallbackImage = 'sfsymbol:music.note.list';

/// Number of distinct albums composed into a Recent Queues collage cover,
/// and the side length in pixels of each tile within it.
const _collageTileCount = 4;
const _collageTileSize = 100;

/// Upper bound on tracks looked up for one collage.
const _maxCollageTrackScan = 20;

const _collageBuildTimeout = Duration(seconds: 10);

/// Resolves and renders every image CarPlay shows.
class CarPlayImageHelper {
  final _providers = GetIt.instance<ProviderContainer>();

  /// Resolves the image URI for a CarPlay list item via [albumImageProvider],
  /// so CarPlay shares Finamp's image cache. Returns a `file://` URI for
  /// downloaded images and a network URL otherwise.
  String? imageUri(BaseItemDto item) {
    if (item.imageId == null) return null;
    return _providers
        .read(
          albumImageProvider(AlbumImageRequest(item: item, maxHeight: _carPlayImageSize, maxWidth: _carPlayImageSize)),
        )
        .uri
        ?.toString();
  }

  /// Resolves the art-row image for a saved queue: a 2x2 collage of covers
  /// from the next [_collageTileCount] distinct albums coming up in the
  /// queue, falling back to the current track's own artwork, then to a
  /// placeholder icon, so a missing track or missing artwork doesn't shift
  /// indices out of alignment with the queue list.
  Future<String> recentQueueImage(FinampStorableQueueInfo info) async {
    try {
      final collage = await _buildRecentQueueCollage(info).timeout(_collageBuildTimeout);
      if (collage != null) {
        return collage;
      }
    } catch (e) {
      _carPlayImageLogger.warning("Failed to build collage for recent queue: $e");
    }
    return _getRecentQueueCoverImage(info).timeout(_collageBuildTimeout, onTimeout: placeholderImageUri);
  }

  Future<String?> savedRecentQueueImage(FinampStorableQueueInfo info) async {
    try {
      final cacheFile = await _collageCacheFile(info, _collageCandidateIds(info));
      return await cacheFile.exists() ? Uri.file(cacheFile.path).toString() : null;
    } catch (e) {
      _carPlayImageLogger.warning("Failed to check for a saved recent queue cover: $e");
      return null;
    }
  }

  /// Resolves the current track's own artwork for a saved queue, falling
  /// back to a placeholder icon. Used when a collage can't be built.
  Future<String> _getRecentQueueCoverImage(FinampStorableQueueInfo info) async {
    final currentTrackId = info.currentTrack;
    if (currentTrackId == null) {
      return placeholderImageUri();
    }
    try {
      final track = await _providers.read(itemByIdProvider(currentTrackId).future);
      if (track == null) {
        return placeholderImageUri();
      }
      return imageUri(track) ?? await placeholderImageUri();
    } catch (e) {
      _carPlayImageLogger.warning("Failed to resolve artwork for recent queue: $e");
      return placeholderImageUri();
    }
  }

  /// Looks up [ids] in one request, or from the downloads database when offline.
  Future<Map<BaseItemId, BaseItemDto>> _lookupTracks(List<BaseItemId> ids) async {
    if (ids.isEmpty) {
      return {};
    }
    final tracks = <BaseItemId, BaseItemDto>{};
    if (FinampSettingsHelper.finampSettings.isOffline) {
      final downloadsService = GetIt.instance<DownloadsService>();
      for (final id in ids) {
        final track = (await downloadsService.getTrackInfo(id: id))?.baseItem;
        if (track != null) {
          tracks[id] = track;
        }
      }
    } else {
      final items = await GetIt.instance<JellyfinApiHelper>().getItems(itemIds: ids);
      for (final item in items ?? const <BaseItemDto>[]) {
        tracks[item.id] = item;
      }
    }
    return tracks;
  }

  List<BaseItemId> _collageCandidateIds(FinampStorableQueueInfo info) {
    // Prefer albums still coming up, then pad with the most recently played
    // ones so a queue archived near its end can still fill the collage.
    final upcomingIds = <BaseItemId>[
      if (info.currentTrack != null) info.currentTrack!,
      ...info.nextUp,
      ...info.queue,
      ...info.previousTracks.reversed,
    ];
    return upcomingIds.take(_maxCollageTrackScan).toList();
  }

  Future<File> _collageCacheFile(FinampStorableQueueInfo info, List<BaseItemId> candidateIds) async {
    final tempPath = (await getTemporaryDirectory()).path;
    return File(
      path_helper.join(tempPath, 'carplay_queue_collage_${info.creation}_${candidateIds.join(',').hashCode}.png'),
    );
  }

  /// Composes the first distinct album covers of the queue into a cached PNG.
  Future<String?> _buildRecentQueueCollage(FinampStorableQueueInfo info) async {
    final candidateIds = _collageCandidateIds(info);
    final cacheFile = await _collageCacheFile(info, candidateIds);
    if (await cacheFile.exists()) {
      return Uri.file(cacheFile.path).toString();
    }

    final tracks = await _lookupTracks(candidateIds);

    final albumTracks = <BaseItemDto>[];
    final seenAlbumIds = <String>{};
    for (final id in candidateIds) {
      final track = tracks[id];
      final albumId = track?.albumId?.raw;
      if (albumId == null || !seenAlbumIds.add(albumId)) {
        continue;
      }
      albumTracks.add(track!);
    }

    if (albumTracks.isEmpty) {
      return null;
    }

    final tiles = <ImageInfo>[];
    try {
      for (var i = 0; i < albumTracks.length && tiles.length < _collageTileCount; i++) {
        final tile = await _resolveCollageTileImage(albumTracks[i]);
        if (tile == null) {
          // Cover failed to resolve or decode. Keep scanning for a
          // replacement instead of failing the whole collage.
          continue;
        }
        tiles.add(tile);
      }

      if (tiles.isEmpty) {
        return null;
      }

      final drawnTiles = tiles.length == _collageTileCount ? tiles : [tiles.first];
      final bytes = await _composeCollage(drawnTiles.map((tile) => tile.image).toList());
      if (bytes == null) {
        return null;
      }
      final missingArt = tiles.length < _collageTileCount && albumTracks.length >= _collageTileCount;
      final outputFile = missingArt ? File('${cacheFile.path}.partial') : cacheFile;
      await outputFile.writeAsBytes(bytes, flush: true);
      return Uri.file(outputFile.path).toString();
    } finally {
      for (final tile in tiles) {
        tile.dispose();
      }
    }
  }

  /// The caller owns the returned [ImageInfo] and must dispose it.
  Future<ImageInfo?> _resolveCollageTileImage(BaseItemDto track) async {
    final imageProvider = _providers
        .read(
          albumImageProvider(AlbumImageRequest(item: track, maxWidth: _collageTileSize, maxHeight: _collageTileSize)),
        )
        .image;
    if (imageProvider == null) {
      return null;
    }

    final completer = Completer<ImageInfo?>();
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        stream.removeListener(listener);
        if (completer.isCompleted) {
          imageInfo.dispose();
          return;
        }
        completer.complete(imageInfo);
      },
      onError: (error, stackTrace) {
        if (completer.isCompleted) {
          return;
        }
        stream.removeListener(listener);
        completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Composes [images] into a square collage PNG the same size regardless
  /// of tile count, returning the encoded bytes, or null if encoding fails.
  /// A single image fills the whole canvas. [_collageTileCount] images are
  /// drawn as 2x2 quadrants.
  Future<Uint8List?> _composeCollage(List<ui.Image> images) async {
    final tileSize = _collageTileSize.toDouble();
    final collageSize = tileSize * 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, collageSize, collageSize));
    if (images.length == 1) {
      final image = images.first;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, collageSize, collageSize),
        ui.Paint(),
      );
    } else {
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final dx = (i % 2) * tileSize;
        final dy = (i ~/ 2) * tileSize;
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          ui.Rect.fromLTWH(dx, dy, tileSize, tileSize),
          ui.Paint(),
        );
      }
    }
    return _encodePng(recorder.endRecording(), collageSize.round());
  }

  Future<Uint8List?> _encodePng(ui.Picture picture, int size) async {
    final ui.Image image;
    try {
      image = await picture.toImage(size, size);
    } finally {
      picture.dispose();
    }
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  String? _placeholderImage;

  /// Renders the main UI's artwork placeholder, the album glyph on a card
  /// coloured tile, to a cached PNG and returns its file URI.
  Future<String> placeholderImageUri() async {
    if (_placeholderImage != null) {
      return _placeholderImage!;
    }
    try {
      const size = 100.0;
      final cacheFile = File(
        path_helper.join((await getTemporaryDirectory()).path, 'carplay_placeholder_${size.round()}.png'),
      );
      if (!await cacheFile.exists()) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size, size));
        canvas.drawRect(ui.Rect.fromLTWH(0, 0, size, size), ui.Paint()..color = const ui.Color(0xFF424242));
        final painter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(Icons.album.codePoint),
            style: TextStyle(
              fontFamily: Icons.album.fontFamily,
              fontSize: size * 0.4,
              color: const ui.Color(0xB3FFFFFF),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        try {
          painter.layout();
          painter.paint(canvas, ui.Offset((size - painter.width) / 2, (size - painter.height) / 2));
        } finally {
          painter.dispose();
        }
        final bytes = await _encodePng(recorder.endRecording(), size.round());
        if (bytes == null) {
          return _carPlayFallbackImage;
        }
        await cacheFile.writeAsBytes(bytes, flush: true);
      }
      _placeholderImage = Uri.file(cacheFile.path).toString();
    } catch (e) {
      _carPlayImageLogger.warning("Failed to render artwork placeholder: $e");
      _placeholderImage = _carPlayFallbackImage;
    }
    return _placeholderImage!;
  }

  /// Renders an icon font glyph to a PNG in the temp directory and returns
  /// its file URI, so CarPlay buttons can show the same icons as the phone
  /// UI. Only the glyph's alpha matters, CarPlay tints button images itself.
  /// The @3x file name makes iOS draw the image at [size] points, not pixels.
  Future<String?> iconFontImageUri(IconData icon, double size) async {
    final pixels = size * 3;
    final cacheFile = File(
      path_helper.join((await getTemporaryDirectory()).path, 'carplay_icon_${icon.codePoint}_${size.round()}@3x.png'),
    );
    if (!await cacheFile.exists()) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, pixels, pixels));
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: pixels,
            color: const ui.Color(0xFFFFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      try {
        painter.layout();
        painter.paint(canvas, ui.Offset((pixels - painter.width) / 2, (pixels - painter.height) / 2));
      } finally {
        painter.dispose();
      }
      final bytes = await _encodePng(recorder.endRecording(), pixels.round());
      if (bytes == null) {
        return null;
      }
      await cacheFile.writeAsBytes(bytes, flush: true);
    }
    return Uri.file(cacheFile.path).toString();
  }
}
