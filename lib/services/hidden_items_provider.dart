import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';

import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'hidden_items.dart';
import 'jellyfin_api_helper.dart';

/// Kept out of FinampSettings so "Reset settings" doesn't unhide everything.
const hiddenItemsBoxName = "HiddenItems";

/// Items hidden on this device, per user so other accounts here keep their own list.
final localHiddenIdsProvider = NotifierProvider<LocalHiddenIds, Set<BaseItemId>>(LocalHiddenIds.new);

class LocalHiddenIds extends Notifier<Set<BaseItemId>> {
  String? _userId;

  Box<List<dynamic>> get _box => Hive.box<List<dynamic>>(hiddenItemsBoxName);

  @override
  Set<BaseItemId> build() {
    _userId = ref.watch(FinampUserHelper.finampCurrentUserProvider)?.id;
    final stored = _userId == null ? null : _box.get(_userId);
    return {...?stored?.cast<String>().map(BaseItemId.new)};
  }

  Future<void> hide(BaseItemId id) => _save({...state, id});

  Future<void> unhide(BaseItemId id) => _save(state.difference({id}));

  Future<void> _save(Set<BaseItemId> ids) async {
    final userId = _userId;
    if (userId == null) return;
    state = ids;
    await _box.put(userId, ids.map((id) => id.raw).toList());
  }
}

/// Items with the server-wide hidden tag.
final serverHiddenIdsProvider = AsyncNotifierProvider<ServerHiddenIds, Set<BaseItemId>>(ServerHiddenIds.new);

class ServerHiddenIds extends AsyncNotifier<Set<BaseItemId>> {
  @override
  Future<Set<BaseItemId>> build() async {
    ref.watch(FinampUserHelper.finampCurrentUserProvider);
    final isOffline = ref.watch(
      finampSettingsProvider.select(
        (settings) => settings.value?.isOffline ?? FinampSettingsHelper.finampSettings.isOffline,
      ),
    );
    if (isOffline) {
      // Downloads keep the tags from their last sync.
      final downloads = GetIt.instance<DownloadsService>();
      final stubs = [...await downloads.getAllTracks(), ...await downloads.getAllCollections()];
      return {
        for (final item in stubs.map((stub) => stub.baseItem).nonNulls)
          if (isItemHidden(item, const {})) item.id,
      };
    }
    final items = await GetIt.instance<JellyfinApiHelper>().getItems(
      tags: hiddenTag,
      includeItemTypes: [BaseItemDtoType.track.jellyfinName, BaseItemDtoType.album.jellyfinName].join(","),
      fields: "",
    );
    return {...?items?.map((item) => item.id)};
  }

  Future<void> setHidden(BaseItemId id, bool hidden) async {
    await GetIt.instance<JellyfinApiHelper>().setServerHidden(id, hidden);
    final ids = await future;
    state = AsyncData(hidden ? {...ids, id} : ids.difference({id}));
  }
}

/// Everything hidden for the current user: local hides plus server-tagged items.
final hiddenIdsProvider = Provider<Set<BaseItemId>>((ref) {
  return {...ref.watch(localHiddenIdsProvider), ...?ref.watch(serverHiddenIdsProvider).value};
});

final isHiddenProvider = Provider.family<bool, BaseItemDto>((ref, item) {
  return isItemHidden(item, ref.watch(hiddenIdsProvider));
});
