import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../models/jellyfin_models.dart';
import 'finamp_user_helper.dart';

/// Calls the native iOS AVFoundation chapter extraction channel.
/// Returns an empty list on any error or on non-iOS platforms.
class ChapterExtractorService {
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/chapters');
  static final _log = Logger('ChapterExtractorService');

  /// Build the direct-stream URL for [itemId] using the current server config.
  static Uri _streamUri(String itemId) {
    final user = GetIt.instance<FinampUserHelper>().currentUser!;
    final base = Uri.parse(user.baseURL);
    final segments = List<String>.from(base.pathSegments)
      ..addAll(['Items', itemId, 'File']);
    final params = Map<String, String>.from(base.queryParameters)
      ..['ApiKey'] = user.accessToken;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      userInfo: base.userInfo,
      pathSegments: segments,
      queryParameters: params,
    );
  }

  /// Extract chapters from the streaming file for [itemId].
  /// Returns an empty list if extraction fails or if no chapters are found.
  static Future<List<ChapterInfo>> extractChapters(String itemId) async {
    try {
      final uri = _streamUri(itemId);
      _log.info('Calling iOS channel for $itemId → $uri');
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'extractChapters',
        uri.toString(),
      );
      _log.info('Channel returned ${raw?.length ?? 0} raw entries for $itemId');
      if (raw == null || raw.isEmpty) return [];

      final chapters = raw
          .cast<Map<Object?, Object?>>()
          .map((m) {
            final ticks = (m['ticks'] as num?)?.toInt() ?? 0;
            final name = m['name'] as String?;
            return ChapterInfo(
              startPositionTicks: ticks,
              name: (name?.isNotEmpty ?? false) ? name : null,
              imageDateModified: '0001-01-01T00:00:00.0000000Z',
            );
          })
          .where((c) => c.startPositionTicks >= 0)
          .toList();
      _log.info('Parsed ${chapters.length} chapters for $itemId');
      return chapters;
    } catch (e, st) {
      _log.warning('Chapter extraction failed for $itemId: $e', e, st);
      return [];
    }
  }
}
