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

  if (ref.watch(finampSettingsProvider.isOffline)) {
    baseItem = (await downloadsService.getCollectionInfo(id: baseItemId))?.baseItem;
    baseItem ??= (await downloadsService.getTrackInfo(id: baseItemId))?.baseItem;
  } else {
    baseItem = await jellyfinApiHelper.getItemById(baseItemId);
  }
  return baseItem;
}
