import 'dart:async';

import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'item_by_id_provider.g.dart';

@riverpod
Future<BaseItemDto?> itemById(Ref ref, BaseItemId baseItemId) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();

  BaseItemDto? baseItem;

  // Prevent re-fetching item for at least 15 minutes, even if we aren't being watched
  final keepAlive = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 15), keepAlive.close);
  ref.onDispose(timer.cancel);

  try {
    if (ref.watch(finampSettingsProvider.isOffline)) {
      baseItem = (await downloadsService.getCollectionInfo(id: baseItemId))?.baseItem;
      baseItem ??= (await downloadsService.getTrackInfo(id: baseItemId))?.baseItem;
    } else {
      baseItem = await jellyfinApiHelper.getItemById(baseItemId);
    }

    return baseItem;
  } catch (e) {
    // Loading failed, e.g. due to a 404 response. Any accessing widgets either need to handle (catch) the error explicitly, or use .valueOrNull and handle the null case
    keepAlive.close();
    rethrow;
  }
}
