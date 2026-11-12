import 'dart:io';

import 'package:finamp/models/animated_music_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../models/finamp_models.dart';

final _animatedMusicLogger = Logger("AnimatedMusic");

const animatedMusicFadeDuration = Duration(milliseconds: 400);
const animatedMusicFadeCurve = Curves.easeInOutCubic;

Duration animatedMusicFadeDurationOf(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : animatedMusicFadeDuration;

class AnimatedPlaybackSource {
  const AnimatedPlaybackSource({
    required this.kind,
    required this.mimeType,
    this.fileName,
    this.file,
    this.url,
    this.previewUrl,
    this.headers,
  });

  final AnimatedAssetKind kind;
  final String? mimeType;
  final String? fileName;
  final File? file;
  final Uri? url;
  final Uri? previewUrl;
  final Map<String, String>? headers;

  String get id => file?.path ?? url?.toString() ?? '';

  bool get isImage {
    final mime = mimeType?.toLowerCase();
    if (mime != null && mime.startsWith("image/")) {
      return true;
    }
    if (mime != null && mime.startsWith("video/")) {
      return false;
    }
    final path = (fileName ?? file?.path ?? url?.path ?? "").toLowerCase();
    return path.endsWith(".gif") ||
        path.endsWith(".png") ||
        path.endsWith(".webp") ||
        path.endsWith(".jpg") ||
        path.endsWith(".jpeg");
  }

  bool get isPlayable {
    if (file == null && url == null) {
      return false;
    }
    if (isImage) {
      return true;
    }
    return !Platform.isLinux;
  }

  @override
  bool operator ==(Object other) {
    return other is AnimatedPlaybackSource &&
        kind == other.kind &&
        mimeType == other.mimeType &&
        file?.path == other.file?.path &&
        url == other.url;
  }

  @override
  int get hashCode => Object.hash(kind, mimeType, file?.path, url);
}

final animatedMusicPluginAvailableProvider = FutureProvider<bool?>((ref) async {
  if (ref.watch(finampSettingsProvider.isOffline)) {
    return null;
  }
  final user = ref.watch(FinampUserHelper.finampCurrentUserProvider);
  if (user == null) {
    return null;
  }
  try {
    return await GetIt.instance<JellyfinApiHelper>().isAnimatedMusicPluginAvailable();
  } catch (e, stack) {
    _animatedMusicLogger.warning("Animated Music plugin probe failed", e, stack);
    return null;
  }
});

final animatedTrackInfoProvider = FutureProvider.autoDispose.family<TrackAnimatedInfoDto?, BaseItemId>((
  ref,
  trackId,
) async {
  if (ref.watch(finampSettingsProvider.isOffline)) {
    return null;
  }
  final plugin = await ref.watch(animatedMusicPluginAvailableProvider.future);
  if (plugin == false) {
    return null;
  }
  try {
    return await GetIt.instance<JellyfinApiHelper>().getTrackAnimatedInfo(itemId: trackId);
  } catch (e, stack) {
    _animatedMusicLogger.fine("No animated info for $trackId: $e", e, stack);
    return null;
  }
});

final currentAnimatedTrackInfoProvider = Provider<AsyncValue<TrackAnimatedInfoDto?>>((ref) {
  final currentTrack = ref.watch(currentTrackProvider).valueOrNull;
  final baseItem = currentTrack?.baseItem;
  if (baseItem == null) {
    return const AsyncValue.data(null);
  }

  final queueService = GetIt.instance<QueueService>();
  for (final item in queueService.peekQueue(next: 1, previous: 0, current: false)) {
    ref.listen(animatedTrackInfoProvider(item.baseItem.id), (_, _) {});
  }

  return ref.watch(animatedTrackInfoProvider(baseItem.id));
});

final verticalBackgroundReadyProvider = NotifierProvider.autoDispose<VerticalBackgroundReady, bool>(
  VerticalBackgroundReady.new,
);

class VerticalBackgroundReady extends AutoDisposeNotifier<bool> {
  @override
  bool build() {
    ref.listen(currentVerticalBackgroundSourceProvider, (previous, next) {
      if (next == null) {
        state = false;
      }
    });
    return false;
  }

  void markReady() {
    state = true;
  }
}

final verticalBackgroundControlsCollapsedProvider =
    NotifierProvider.autoDispose<VerticalBackgroundControlsCollapsed, bool>(VerticalBackgroundControlsCollapsed.new);

class VerticalBackgroundControlsCollapsed extends AutoDisposeNotifier<bool> {
  @override
  bool build() {
    ref.listen(currentVerticalBackgroundSourceProvider, (previous, next) {
      if (previous != next) {
        state = false;
      }
    });
    ref.listen(verticalBackgroundReadyProvider, (_, ready) {
      if (!ready) {
        state = false;
      }
    });
    return false;
  }

  void toggle() {
    state = !state;
  }
}

AnimatedPlaybackSource? _sourceForAsset({
  required BaseItemDto item,
  required AnimatedAssetKind kind,
  AnimatedAssetDto? asset,
  required bool offline,
}) {
  final downloadedFile = GetIt.instance<DownloadsService>()
      .getAnimatedDownload(
        item: item,
        type: kind == AnimatedAssetKind.cover ? DownloadItemType.animatedCover : DownloadItemType.verticalBackground,
      )
      ?.file;
  final helper = GetIt.instance<JellyfinApiHelper>();
  final userHelper = GetIt.instance<FinampUserHelper>();
  final token = userHelper.currentUser?.accessToken;
  final headers = {
    "Authorization": userHelper.authorizationHeader,
    if (token != null && token.isNotEmpty) "X-Emby-Token": token,
  };

  Uri? withAuth(Uri? url) {
    if (url == null) {
      return null;
    }
    if (token == null || token.isEmpty) {
      return url;
    }
    return url.replace(queryParameters: {...url.queryParameters, "ApiKey": token});
  }

  final previewUrl = offline ? null : withAuth(helper.resolveAnimatedAssetUrl(asset?.previewUrl));

  if (downloadedFile != null) {
    return AnimatedPlaybackSource(
      kind: kind,
      mimeType: asset?.mimeType,
      fileName: asset?.fileName,
      file: downloadedFile,
      previewUrl: previewUrl,
      headers: headers,
    );
  }
  if (offline || asset == null || !asset.available) {
    return null;
  }

  final url = withAuth(
    helper.resolveAnimatedAssetUrl(asset.url) ?? helper.getAnimatedAssetUrl(trackId: item.id, kind: kind),
  );
  if (url == null) {
    return null;
  }
  return AnimatedPlaybackSource(
    kind: kind,
    mimeType: asset.mimeType,
    fileName: asset.fileName,
    url: url,
    previewUrl: previewUrl,
    headers: headers,
  );
}

AnimatedPlaybackSource? _currentSource(Ref ref, {required bool enabled, required AnimatedAssetKind kind}) {
  if (!enabled) {
    return null;
  }
  final plugin = ref.watch(animatedMusicPluginAvailableProvider).valueOrNull;
  final offline = ref.watch(finampSettingsProvider.isOffline);
  if (plugin == false && !offline) {
    return null;
  }
  final track = ref.watch(currentTrackProvider).valueOrNull?.baseItem;
  if (track == null) {
    return null;
  }
  final info = ref.watch(currentAnimatedTrackInfoProvider).valueOrNull;
  final asset = switch (kind) {
    AnimatedAssetKind.cover => info?.cover,
    AnimatedAssetKind.verticalBackground => info?.verticalBackground,
  };
  final source = _sourceForAsset(item: track, kind: kind, asset: asset, offline: offline);
  if (source == null || !source.isPlayable) {
    return null;
  }
  return source;
}

final currentVerticalBackgroundSourceProvider = Provider<AnimatedPlaybackSource?>((ref) {
  return _currentSource(
    ref,
    enabled: ref.watch(finampSettingsProvider.showVerticalBackground),
    kind: AnimatedAssetKind.verticalBackground,
  );
});

final currentAnimatedCoverSourceProvider = Provider<AnimatedPlaybackSource?>((ref) {
  if (ref.watch(verticalBackgroundReadyProvider)) {
    return null;
  }
  return _currentSource(
    ref,
    enabled: ref.watch(finampSettingsProvider.showAnimatedCover),
    kind: AnimatedAssetKind.cover,
  );
});
