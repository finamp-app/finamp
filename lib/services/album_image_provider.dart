import 'dart:async';
import 'dart:io';

import 'package:file/file.dart' as cache;
import 'package:file/local.dart';
// Directly use LocalFile to avoid touching every cached file on initialization
import 'package:file/src/backends/local/local_file.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'jellyfin_api_helper.dart';

final albumImageProviderLogger = Logger("AlbumImageProvider");

class AlbumImageRequest {
  const AlbumImageRequest({required this.item, this.maxWidth, this.maxHeight});

  final BaseItemDto item;

  final int? maxWidth;

  final int? maxHeight;

  bool get fullQuality => maxWidth == null && maxHeight == null;

  @override
  bool operator ==(Object other) {
    return other is AlbumImageRequest &&
        other.maxHeight == maxHeight &&
        other.maxWidth == maxWidth &&
        other.item.id == item.id;
  }

  @override
  int get hashCode => Object.hash(item.id, maxHeight, maxWidth);
}

Future<void> initImageCache() async {
  await _imageCache.config.repo.open();
  final entries = await _imageCache.config.repo.getAllObjects();
  final basePath = path_helper.join((await getTemporaryDirectory()).path, _imageCache.config.cacheKey);
  for (final cacheEntry in entries) {
    // Directly create FileInfo from cachentry instead of using CacheStore.getFile because that checks for file existence
    // as it goes, and we do that when the entry is read and can't afford the speed penalty
    _playerImageCache[cacheEntry.key] = FileInfo(
      LocalFile(const LocalFileSystem(), File(path_helper.join(basePath, cacheEntry.relativePath))),
      FileSource.Cache,
      cacheEntry.validTill,
      cacheEntry.url,
    );
  }
  await _imageCache.config.repo.close();
}

final Map<String?, AlbumImageRequest> albumRequestsCache = {};

// This caches mappings between cache keys and files on the player screen, to avoid the async delay of checking if
// the cached file actually exists when transitioning between non-precached items with identical images.
final Map<String?, FileInfo?> _playerImageCache = {};

final _imageCache = DefaultCacheManager();

const _infiniteHeight = 999999;

final AutoDisposeProviderFamily<AlbumImageInfo, AlbumImageRequest>
albumImageProvider = Provider.autoDispose.family<AlbumImageInfo, AlbumImageRequest>((ref, request) {
  String? requestCacheKey = request.item.blurHash ?? request.item.imageId;
  // We currently only support square image requests
  assert(request.maxWidth == request.maxHeight);
  if (albumRequestsCache.containsKey(requestCacheKey)) {
    final cacheRequestHeight = albumRequestsCache[requestCacheKey]!.maxHeight;
    if ((request.maxHeight ?? _infiniteHeight) > (cacheRequestHeight ?? _infiniteHeight)) {
      albumRequestsCache[requestCacheKey] = request;
    }
  } else {
    albumRequestsCache[requestCacheKey] = request;
  }
  ref.onDispose(() {
    if (albumRequestsCache.containsKey(requestCacheKey)) {
      if (albumRequestsCache[requestCacheKey] == request) {
        albumRequestsCache.remove(requestCacheKey);
      }
    }
  });

  if (request.item.imageId == null) {
    return AlbumImageInfo.empty(request);
  }

  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final isardownloader = GetIt.instance<DownloadsService>();

  File? downloadedImage = isardownloader.getImageDownload(item: request.item)?.file;

  String key;
  bool blurhashKey = false;
  if (request.item.blurHash != null) {
    key = request.item.blurHash! + request.maxWidth.toString() + request.maxHeight.toString();
    blurhashKey = true;
  } else {
    key = request.item.imageId! + request.maxWidth.toString() + request.maxHeight.toString();
  }

  if (downloadedImage == null) {
    final cacheEntry = _playerImageCache[key];
    final isValid = cacheEntry?.validTill.isAfter(DateTime.now()) ?? false;
    if (isValid && cacheEntry!.file.existsSync()) {
      downloadedImage = cacheEntry.file;
    }
  }

  if (downloadedImage == null) {
    if (ref.watch(finampSettingsProvider.isOffline)) {
      return AlbumImageInfo.empty(request);
    }

    // TODO maybe we can reuse cached player images or existing sufficiently larger image requests instead of fetching from server

    Uri? imageUrl;

    if (request.fullQuality) {
      imageUrl = jellyfinApiHelper.getImageUrl(item: request.item, quality: null, format: null);
    } else {
      imageUrl = jellyfinApiHelper.getImageUrl(
        item: request.item,
        maxWidth: request.maxWidth,
        maxHeight: request.maxHeight,
      );
    }

    if (imageUrl == null) {
      return AlbumImageInfo.empty(request);
    }

    if (request.fullQuality) {
      // If we want full quality player images, retrieve them via the image cache instead of linking directly.
      // In most cases, the initial null value will only be seen by the precache logic.
      Future.sync(() async {
        FileInfo imageFile = await _imageCache.downloadFile(imageUrl.toString(), key: key);
        if (blurhashKey) {
          // The default validTill length is 7 days.  Images fetched by blurhash cannot change, as that would change the
          // blurhash, so update vaildTill to one year.
          var cacheObject = await _imageCache.store.retrieveCacheData(key);
          cacheObject = cacheObject!.copyWith(validTill: DateTime.now().add(Duration(days: 365)));
          await _imageCache.store.putFile(cacheObject);
        }
        _playerImageCache[key] = imageFile;
        ref.state = AlbumImageInfo(
          FileImage(imageFile.file, scale: 0.25),
          request,
          Uri.file(imageFile.file.path),
          fullQuality: true,
        );
      });
      // Temporary result for the frame or so the cache loads
      return AlbumImageInfo(null, request, null, fullQuality: true);
    } else {
      // Allow drawing albums up to 4X intrinsic size by setting scale
      return AlbumImageInfo(
        CachedImage(NetworkImage(imageUrl.toString(), scale: 0.25), key),
        request,
        imageUrl,
        fullQuality: request.fullQuality,
      );
    }
  }

  // downloads are already de-dupped by blurHash and do not need CachedImage
  // Allow drawing albums up to 4X intrinsic size by setting scale
  ImageProvider out = FileImage(downloadedImage, scale: 0.25);
  if (!request.fullQuality) {
    // Limit memory cached image size to twice displayed size
    // This helps keep cache usage by fileImages in check
    // Caching smaller at 2X size results in blurriness comparable to
    // NetworkImages fetched with display size
    out = ResizeImage(out, width: request.maxWidth! * 2, height: request.maxHeight! * 2, policy: ResizeImagePolicy.fit);
  }
  return AlbumImageInfo(out, request, Uri.file(downloadedImage.path), fullQuality: request.fullQuality);
});

class CachedImage extends ImageProvider<CachedImage> {
  CachedImage(ImageProvider base, this.cacheKey) : _base = base;

  final ImageProvider _base;

  final String? cacheKey;

  double get scale => switch (_base) {
    NetworkImage() => _base.scale,
    FileImage() => _base.scale,
    _ => throw UnsupportedError("Unsupported base image provider $_base"),
  };

  String get location => switch (_base) {
    NetworkImage() => _base.url,
    FileImage() => _base.file.path,
    _ => throw UnsupportedError("Unsupported base image provider $_base"),
  };

  @override
  ImageStreamCompleter loadBuffer(CachedImage key, DecoderBufferCallback decode) => _base.loadBuffer(key._base, decode);

  @override
  ImageStreamCompleter loadImage(CachedImage key, ImageDecoderCallback decode) => _base.loadImage(key._base, decode);

  @override
  Future<CachedImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<CachedImage>(this);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (cacheKey != null) {
      return other is CachedImage && other.cacheKey == cacheKey && other.scale == scale;
    }
    return other is CachedImage && other.location == location && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(cacheKey ?? location, scale);

  @override
  String toString() => 'CachedImage("$location", scale: ${scale.toStringAsFixed(1)})';
}

@immutable
class AlbumImageInfo extends FinampImage {
  const AlbumImageInfo(super.image, this.albumRequest, this.uri, {required super.fullQuality});

  const AlbumImageInfo.empty(this.albumRequest) : uri = null, super(null, fullQuality: true);

  final AlbumImageRequest albumRequest;

  final Uri? uri;

  FinampThemeImage asTheme(ThemeInfo themeRequest) => FinampThemeImage(image, themeRequest, fullQuality: fullQuality);

  @override
  BaseItemDto get item => albumRequest.item;
}

/// This cache implementation does nothing but throw errors.  It is fed to audio service, which should not try to use
/// it due to our player image caching logic.  audio service cannot deduplicate images by blurhash, so we should
/// avoid feeding it network images directly.
class StubImageCache implements BaseCacheManager {
  @override
  Future<void> dispose() {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<FileInfo> downloadFile(String url, {String? key, Map<String, String>? authHeaders, bool force = false}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<void> emptyCache() {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Stream<FileInfo> getFile(String url, {String? key, Map<String, String>? headers}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<FileInfo?> getFileFromMemory(String key) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Stream<FileResponse> getFileStream(String url, {String? key, Map<String, String>? headers, bool? withProgress}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<cache.File> getSingleFile(String url, {String? key, Map<String, String>? headers}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<cache.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<cache.File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<void> removeFile(String key) {
    throw UnsupportedError("This cache should not be used");
  }
}
