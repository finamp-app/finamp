import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Logs offline listens or failed submissions to a file.
class OfflineListenLogHelper {
  final _logger = Logger("OfflineListenLogHelper");
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  Future<Directory> get _logDirectory async {
    if (!Platform.isAndroid) {
      return Platform.isIOS ? await getApplicationDocumentsDirectory() : await getApplicationSupportDirectory();
    }

    final List<Directory>? dirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
    return dirs?.first ?? await getApplicationDocumentsDirectory();
  }

  Future<File> get _logFile async {
    final Directory directory = await _logDirectory;
    return File("${directory.path}/listens.json");
  }

  /// Logs a listen to a file.
  ///
  /// This is used when the user is offline or submitting live playback events fails.
  Future<void> logOfflineListen(MediaItem item, [DateTime? timestamp]) async {
    final itemJson = item.extras!["itemJson"];

    final deviceInfo = await getDeviceInfo(deviceId: FinampSettingsHelper.finampSettings.deviceId);

    final offlineListen = OfflineListen(
      timestamp: (timestamp ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
      userId: _finampUserHelper.currentUserId!,
      itemId: itemJson["Id"] as String,
      name: itemJson["Name"] as String,
      artist: itemJson["AlbumArtist"] as String?,
      album: itemJson["Album"] as String?,
      trackMbid: itemJson["ProviderIds"]?["MusicBrainzTrack"] as String?,
      deviceInfo: deviceInfo,
    );

    return _logOfflineListen(offlineListen);
  }

  /// Logs a listen to a file.
  ///
  /// This is used when the user is offline or submitting live playback events fails.
  /// The [timestamp] provided to this function should be in seconds
  /// and marks the time the track was stopped.
  Future<void> _logOfflineListen(OfflineListen listen) {
    _logger.info("Storing offline listen for ${listen.name}");
    return Future.wait([Hive.box<OfflineListen>("OfflineListens").add(listen), _exportOfflineListenToFile(listen)]);
  }

  Future<void> _exportOfflineListenToFile(OfflineListen listen) async {
    final data = {
      'timestamp': listen.timestamp,
      'item_id': listen.itemId,
      'title': listen.name,
      'artist': listen.artist,
      'album': listen.album,
      'track_mbid': listen.trackMbid,
      'user_id': listen.userId,
      'device': {'name': listen.deviceInfo?.name, 'id': listen.deviceInfo?.id},
    };
    final content = json.encode(data) + Platform.lineTerminator;

    final file = await _logFile;
    try {
      await file.writeAsString(content, mode: FileMode.append, flush: true);
    } catch (e) {
      _logger.warning("Failed to write listen to file: $content");
    }
  }

  /// Share the offline listens log file
  Future<void> shareOfflineListens() async {
    final file = await _logFile;
    final xFile = XFile(file.path, mimeType: "application/json");

    await Share.shareXFiles([xFile]);
  }
}
