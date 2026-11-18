import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';

import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'hidden_items.dart';
import 'jellyfin_api_helper.dart';

final _logger = Logger("HiddenItems");

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
    if (!Hive.isBoxOpen(hiddenItemsBoxName)) return {};
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
  /// Album of each loaded track. Jellyfin reports a hidden album's tag on its tracks too, so they're loaded with it.
  Map<BaseItemId, BaseItemId> _albumOfTrack = {};

  @override
  Future<Set<BaseItemId>> build() async {
    ref.watch(FinampUserHelper.finampCurrentUserProvider);
    final isOffline = ref.watch(
      finampSettingsProvider.select(
        (settings) => settings.value?.isOffline ?? FinampSettingsHelper.finampSettings.isOffline,
      ),
    );
    // Every list reads these ids, so a failed lookup must not break them; local hides still apply.
    return await _load(isOffline: isOffline) ?? {};
  }

  Future<Set<BaseItemId>?> _load({required bool isOffline}) async {
    try {
      final List<BaseItemDto> items;
      if (isOffline) {
        // Downloads keep the tags from their last sync.
        final downloads = GetIt.instance<DownloadsService>();
        final stubs = [...await downloads.getAllTracks(), ...await downloads.getAllCollections()];
        items = stubs.map((stub) => stub.baseItem).nonNulls.where(hasHiddenTag).toList();
      } else {
        items =
            await GetIt.instance<JellyfinApiHelper>().getItems(
              tags: hiddenTag,
              includeItemTypes: [BaseItemDtoType.track.jellyfinName, BaseItemDtoType.album.jellyfinName].join(","),
              fields: "",
            ) ??
            [];
      }
      _albumOfTrack = {for (final item in items) item.id: ?item.albumId};
      return {for (final item in items) item.id};
    } catch (e) {
      _logger.warning("Couldn't load server-hidden items: $e");
      return null;
    }
  }

  /// The album a server-hidden track was loaded with, if it carried the album's tag.
  BaseItemId? albumOf(BaseItemId track) => _albumOfTrack[track];

  Future<void> setHidden(BaseItemId id, bool hidden) async {
    final before = await future;
    // Show the change right away: the server round trip can take several seconds.
    final optimistic = hidden
        ? {...before, id}
        : before.where((item) => item != id && _albumOfTrack[item] != id).toSet();
    state = AsyncData(optimistic);
    try {
      await GetIt.instance<JellyfinApiHelper>().setServerHidden(id, hidden);
    } catch (_) {
      final current = state.valueOrNull ?? const {};
      state = AsyncData(current.difference(optimistic.difference(before)).union(before.difference(optimistic)));
      rethrow;
    }
    // Tracks can also be tagged on their own, so take the server's word once it has answered.
    final reloaded = await _load(isOffline: FinampSettingsHelper.finampSettings.isOffline);
    if (reloaded != null) state = AsyncData(reloaded);
  }
}

/// Everything hidden for the current user: local hides plus server-tagged items.
final hiddenIdsProvider = Provider<Set<BaseItemId>>((ref) {
  return {...ref.watch(localHiddenIdsProvider), ...?ref.watch(serverHiddenIdsProvider).valueOrNull};
});

final isHiddenProvider = Provider.family<bool, BaseItemDto>((ref, item) {
  return isItemHidden(item, ref.watch(hiddenIdsProvider));
});
