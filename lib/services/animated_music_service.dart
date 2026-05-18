import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

/// Response model for the AnimatedMusic Track Info endpoint
class AnimatedMusicTrackInfo {
  final String trackId;
  final bool hasAnimatedCover;
  final bool hasAnimatedCoverPreview;
  final bool hasAnimatedCoverTall;
  final bool hasVerticalBackground;
  final bool hasTrackSpecificVerticalBackground;
  final String? animatedCoverUrl;
  final String? animatedCoverPreviewUrl;
  final String? animatedCoverTallUrl;
  final String? verticalBackgroundUrl;

  AnimatedMusicTrackInfo({
    required this.trackId,
    required this.hasAnimatedCover,
    required this.hasAnimatedCoverPreview,
    required this.hasAnimatedCoverTall,
    required this.hasVerticalBackground,
    required this.hasTrackSpecificVerticalBackground,
    this.animatedCoverUrl,
    this.animatedCoverPreviewUrl,
    this.animatedCoverTallUrl,
    this.verticalBackgroundUrl,
  });

  factory AnimatedMusicTrackInfo.fromJson(Map<String, dynamic> json) {
    return AnimatedMusicTrackInfo(
      trackId: json['TrackId'] as String,
      hasAnimatedCover: json['HasAnimatedCover'] as bool? ?? false,
      hasAnimatedCoverPreview: json['HasAnimatedCoverPreview'] as bool? ?? false,
      hasAnimatedCoverTall: json['HasAnimatedCoverTall'] as bool? ?? false,
      hasVerticalBackground: json['HasVerticalBackground'] as bool? ?? false,
      hasTrackSpecificVerticalBackground: json['HasTrackSpecificVerticalBackground'] as bool? ?? false,
      animatedCoverUrl: json['AnimatedCoverUrl'] as String?,
      animatedCoverPreviewUrl: json['AnimatedCoverPreviewUrl'] as String?,
      animatedCoverTallUrl: json['AnimatedCoverTallUrl'] as String?,
      verticalBackgroundUrl: json['VerticalBackgroundUrl'] as String?,
    );
  }
}

class AnimatedMusicService {
  final _logger = Logger("AnimatedMusicService");
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  /// Get animated cover URL for a track
  /// Returns null if no user is logged in
  Future<String?> getAnimatedCoverForTrack(BaseItemId trackId) async {
    final trackIdStr = trackId.raw;

    // Build URL
    final url = _buildAnimatedCoverUrlForTrack(trackId);
    if (url != null) {
      return url;
    }

    _logger.fine("Could not build animated cover URL for track $trackIdStr");
    return null;
  }

  /// Get vertical background URL for a track
  /// Returns null if no user is logged in
  Future<String?> getVerticalBackgroundForTrack(BaseItemId trackId) async {
    final trackIdStr = trackId.raw;

    // Build URL
    final url = _buildVerticalBackgroundUrlForTrack(trackId);
    if (url != null) {
      return url;
    }

    _logger.fine("Could not build vertical background URL for track $trackIdStr");
    return null;
  }

  /// Get animated music track info from the plugin
  /// Returns null if no user is logged in or if the request fails
  Future<AnimatedMusicTrackInfo?> getAnimatedMusicTrackInfo(BaseItemId trackId) async {
    final currentUser = _finampUserHelper.currentUser;
    if (currentUser == null) {
      return null;
    }

    final url = _buildTrackInfoUrl(trackId);
    if (url == null) {
      return null;
    }

    try {
      final client = HttpClient();
      final request = await client.openUrl('GET', Uri.parse(url));
      request.headers.set('Authorization', _finampUserHelper.authorizationHeader);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return AnimatedMusicTrackInfo.fromJson(json);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Check if animated cover exists for a track
  /// Returns true if the resource exists, false otherwise
  Future<bool> hasAnimatedCover(BaseItemId trackId) async {
    final trackInfo = await getAnimatedMusicTrackInfo(trackId);
    return trackInfo?.hasAnimatedCover ?? false;
  }

  /// Check if vertical background video exists for a track
  /// Returns true if the resource exists, false otherwise
  Future<bool> hasVerticalBackgroundVideo(BaseItemId trackId) async {
    final trackInfo = await getAnimatedMusicTrackInfo(trackId);
    return trackInfo?.hasVerticalBackground ?? false;
  }

  /// Build track info URL for a track
  String? _buildTrackInfoUrl(BaseItemId trackId) {
    final currentUser = _finampUserHelper.currentUser;
    if (currentUser == null) {
      return null;
    }

    final parsedBaseUrl = Uri.parse(currentUser.baseURL);
    List<String> builtPath = List<String>.from(parsedBaseUrl.pathSegments);
    builtPath.addAll(["AnimatedMusic", "Track", trackId.raw, "Info"]);

    return Uri(
      host: parsedBaseUrl.host,
      port: parsedBaseUrl.port,
      scheme: parsedBaseUrl.scheme,
      userInfo: parsedBaseUrl.userInfo,
      pathSegments: builtPath,
    ).toString();
  }

  /// Build animated cover URL for a track
  String? _buildAnimatedCoverUrlForTrack(BaseItemId trackId) {
    final currentUser = _finampUserHelper.currentUser;
    if (currentUser == null) {
      return null;
    }

    final parsedBaseUrl = Uri.parse(currentUser.baseURL);
    List<String> builtPath = List<String>.from(parsedBaseUrl.pathSegments);
    builtPath.addAll(["AnimatedMusic", "Track", trackId.raw, "AnimatedCover"]);

    return Uri(
      host: parsedBaseUrl.host,
      port: parsedBaseUrl.port,
      scheme: parsedBaseUrl.scheme,
      userInfo: parsedBaseUrl.userInfo,
      pathSegments: builtPath,
    ).toString();
  }

  /// Build vertical background URL for a track
  String? _buildVerticalBackgroundUrlForTrack(BaseItemId trackId) {
    final currentUser = _finampUserHelper.currentUser;
    if (currentUser == null) {
      return null;
    }

    final parsedBaseUrl = Uri.parse(currentUser.baseURL);
    List<String> builtPath = List<String>.from(parsedBaseUrl.pathSegments);
    builtPath.addAll(["AnimatedMusic", "Track", trackId.raw, "VerticalBackground"]);

    return Uri(
      host: parsedBaseUrl.host,
      port: parsedBaseUrl.port,
      scheme: parsedBaseUrl.scheme,
      userInfo: parsedBaseUrl.userInfo,
      pathSegments: builtPath,
    ).toString();
  }

  /// Build animated cover URL for a track (public method for downloads service)
  String? buildAnimatedCoverUrlForTrack(BaseItemId trackId) {
    return _buildAnimatedCoverUrlForTrack(trackId);
  }

  /// Build vertical background URL for a track (public method for downloads service)
  String? buildVerticalBackgroundUrlForTrack(BaseItemId trackId) {
    return _buildVerticalBackgroundUrlForTrack(trackId);
  }
}
