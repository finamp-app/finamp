import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

final AutoDisposeProviderFamily<bool, BaseItemDto> canDeleteFromServerProvider = AutoDisposeProviderFamily((
  ref,
  BaseItemDto item,
) {
  // we can't delete from server when offline
  bool offline = ref.watch(finampSettingsProvider.isOffline);
  if (offline) {
    return false;
  }
  var itemType = BaseItemDtoType.fromItem(item);
  var isPlaylist = itemType == BaseItemDtoType.playlist;
  bool deleteEnabled = ref.watch(finampSettingsProvider.allowDeleteFromServer);

  // always check if a playlist is deletable
  if (!deleteEnabled && !isPlaylist) {
    return false;
  }

  // do not bother checking server for item types known to not be deletable
  if (![BaseItemDtoType.album, BaseItemDtoType.playlist, BaseItemDtoType.track].contains(itemType)) {
    return false;
  }
  bool? serverReturn = ref.watch(_canDeleteFromServerAsyncProvider(item.id)).value;
  if (serverReturn == null) {
    // fallback to allowing deletion even if the response is invalid, since the user might still be able to delete
    // worst case would be getting an error message when trying to delete
    return item.canDelete ?? true;
  } else {
    return serverReturn;
  }
});

final AutoDisposeFutureProviderFamily<bool?, BaseItemId> _canDeleteFromServerAsyncProvider =
    AutoDisposeFutureProviderFamily((ref, BaseItemId id) {
      return GetIt.instance<JellyfinApiHelper>()
          .getItemById(id)
          .then((response) {
            return response.canDelete;
          })
          .catchError((_) {
            return false;
          });
    });

final AutoDisposeProviderFamily<bool, BaseItemDto> canEditPlaylistProvider = AutoDisposeProviderFamily((
  ref,
  BaseItemDto item,
) {
  var itemType = BaseItemDtoType.fromItem(item);
  assert(itemType == BaseItemDtoType.playlist, "canEditPlaylistProvider should only be used with playlists");

  // No need to check if offline, since we might support offline edits (which are synced on reconnect) at a later point, like adding a track to a playlist.
  // For now, the using widgets should still have this check in place.

  // do not bother checking server for item types known to not be editable
  if (![BaseItemDtoType.album, BaseItemDtoType.playlist, BaseItemDtoType.track].contains(itemType)) {
    return false;
  }
  bool? serverReturn = ref.watch(_canEditPlaylistAsyncProvider(item.id)).value;
  if (serverReturn == null) {
    // fallback to allowing deletion even if the response is invalid, since the user might still be able to delete
    // worst case would be getting an error message when trying to delete
    return true;
  } else {
    return serverReturn;
  }
});

final AutoDisposeFutureProviderFamily<bool?, BaseItemId> _canEditPlaylistAsyncProvider =
    AutoDisposeFutureProviderFamily((ref, BaseItemId id) {
      return GetIt.instance<JellyfinApiHelper>()
          .getPlaylistUser(id)
          .then((response) {
            return response.canEdit;
          })
          .catchError((_) {
            return false;
          });
    });

final AutoDisposeProvider<bool> canEditMetadataProvider = AutoDisposeProvider((ref) {
  // editing metadata while offline (e.g., through caching or edit queues) probably isn't a good idea
  bool offline = ref.watch(finampSettingsProvider.isOffline);
  if (offline) {
    return false;
  }
  bool? serverReturn = ref.watch(isServerAdminProvider).value;
  return serverReturn ?? false;
});

/// Kept for the session (refetched when the user changes) because /Users/Me can take seconds to answer.
final FutureProvider<bool> isServerAdminProvider = FutureProvider((ref) {
  ref.watch(FinampUserHelper.finampCurrentUserProvider);
  return GetIt.instance<JellyfinApiHelper>()
      .getUser()
      .then((response) {
        return response.policy?.isAdministrator ?? false;
      })
      .catchError((_) {
        return false;
      });
});
