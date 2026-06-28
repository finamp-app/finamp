import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api.dart' as jellyfin_api;
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:isar/isar.dart';
import 'package:logging/logging.dart';

final finampUserHelperLogger = Logger("FinampUserHelper");

/// Helper class for Finamp users. Note that this class does not talk to the
/// Jellyfin server, so stuff like logging in/out is handled in JellyfinApiData.
class FinampUserHelper {
  FinampUserHelper() {
    _isar.finampUsers.watchObjectLazy(0).listen((event) {
      _currentUserCache = null;
      setAuthHeader();
      if (GetIt.instance.isRegistered(type: ProviderContainer)) {
        GetIt.instance<ProviderContainer>().invalidate(finampCurrentUserProvider);
      }
    });
  }

  Future<void> setAuthHeader() async {
    authorizationHeader = await jellyfin_api.getAuthHeader();
  }

  final _isar = GetIt.instance<Isar>();

  final List<void Function()> _postUserHooks = [];

  /// Checks if there are any saved users.
  bool get isUsersEmpty => _isar.finampUsers.countSync() == 0;

  /// Loads the id from CurrentUserId. Returns null if no id is stored.
  String? get currentUserId => _isar.finampUsers.getSync(0)?.id;

  /// Loads the FinampUser with the id from CurrentUserId. Returns null if no
  /// user exists.
  FinampUser? get currentUser => _currentUserCache ??= _isar.finampUsers.getSync(0);
  FinampUser? _currentUserCache;

  Iterable<FinampUser> get finampUsers => _isar.finampUsers.where().findAllSync();

  late String authorizationHeader;

  static final Provider<FinampUser?> finampCurrentUserProvider = Provider((ref) {
    return GetIt.instance<FinampUserHelper>().currentUser;
  });

  Future<void> migrateFromHive() async {
    await Hive.openBox<FinampUser>("FinampUsers");
    await Hive.openBox<String>("CurrentUserId");
    var currentUserId = Hive.box<String>("CurrentUserId").get("CurrentUserId");
    if (currentUserId != null) {
      var currentUser = Hive.box<FinampUser>("FinampUsers").get(currentUserId);
      if (currentUser != null) {
        _isar.writeTxnSync(() {
          _isar.finampUsers.putSync(currentUser, saveLinks: false);
        });
      }
    }
  }

  /// Saves a new user to the Hive box and sets the CurrentUserId.
  Future<void> saveUser(FinampUser newUser) async {
    _isar.writeTxnSync(() {
      _isar.finampUsers.putSync(newUser, saveLinks: false);
    });
    await setAuthHeader();
    while (_postUserHooks.isNotEmpty) {
      _postUserHooks.removeAt(0)();
    }
  }

  void runUserHook(void Function() func) {
    if (currentUser != null) {
      func();
    } else {
      _postUserHooks.add(func);
    }
  }

  /// Sets the views of the current user
  void setCurrentUserViews(List<BaseItemDto> newViews) {
    FinampUser currentUserTemp = currentUser!;

    currentUserTemp.views = Map<BaseItemId, BaseItemDto>.fromEntries(newViews.map((e) => MapEntry(e.id, e)));
    currentUserTemp.currentViewId = currentUserTemp.views.keys.first;

    _isar.writeTxnSync(() {
      _isar.finampUsers.putSync(currentUserTemp, saveLinks: false);
    });
  }

  void setCurrentUserCurrentViewId(BaseItemId newViewId) {
    FinampUser currentUserTemp = currentUser!;

    currentUserTemp.currentViewId = newViewId;

    _isar.writeTxnSync(() {
      _isar.finampUsers.putSync(currentUserTemp, saveLinks: false);
    });
  }

  /// Removes the user with the given id. If the given id is the current user
  /// id, CurrentUserId is cleared.
  void removeUser(String id) {
    _isar.writeTxnSync(() {
      _isar.finampUsers.filter().idEqualTo(id).deleteAllSync();
    });
    if (_currentUserCache?.id == id) {
      _currentUserCache = null;
    }
  }
}

class UserInfo {
  final UserDto? jellyfinUser;
  final FinampUser? finampUser;

  UserInfo({required this.jellyfinUser, required this.finampUser});

  bool get isAdmin => jellyfinUser?.policy?.isAdministrator ?? false;

  @override
  String toString() {
    return "UserInfo(jellyfinUser: $jellyfinUser, finampUser: $finampUser)";
  }
}

class UserInfoProviders {
  static final AutoDisposeFutureProviderFamily<UserInfo?, String> userInfoProvider = FutureProvider.autoDispose
      .family<UserInfo?, String>((ref, userId) async {
        final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

        final currentUserInfo = ref.watch(FinampUserHelper.finampCurrentUserProvider);
        final bool isCurrentUser = currentUserInfo?.id == userId;
        UserInfo userInfo = UserInfo(jellyfinUser: null, finampUser: currentUserInfo);
        finampUserHelperLogger.fine("Fetching user info for '$userId'");

        //!!! return last-known value if offline, instead of making a network request
        if (ref.watch(finampSettingsProvider.isOffline)) {
          return ref.state.value;
        }

        UserDto jellyfinUser;
        try {
          final user = await jellyfinApiHelper.getUserById(userId);
          if (user == null) {
            throw Exception("Received null user info");
          }
          jellyfinUser = user;
        } catch (e) {
          finampUserHelperLogger.severe("Failed to fetch user '$userId':", e);
          return null;
        }

        userInfo = UserInfo(jellyfinUser: jellyfinUser, finampUser: isCurrentUser ? currentUserInfo : null);

        finampUserHelperLogger.fine("Fetched user info for '$userId': $userInfo");

        return userInfo;
      });

  /// Provider for additional user info fetched from the server
  static final currentUserInfoProvider = Provider<AsyncValue<UserInfo?>>((ref) {
    final currentUserId = ref.watch(FinampUserHelper.finampCurrentUserProvider)?.id;
    if (currentUserId != null) {
      return ref.watch(userInfoProvider(currentUserId));
    }
    return const AsyncValue.data(null);
  });
}
