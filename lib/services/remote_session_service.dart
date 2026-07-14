import 'dart:async';

import 'package:collection/collection.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/playon_service.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

/// The subset of remote session state the player UI mirrors.
/// Derived from the remote [SessionInfo] so widgets don't re-derive tick math.
class RemotePlaybackState {
  final Duration position;
  final Duration? duration;
  final bool playing;

  const RemotePlaybackState({required this.position, required this.duration, required this.playing});
}

/// Drives playback on another Jellyfin session ("Play On" / Connect controller
/// side). While connected:
///
/// - The remote session's state is monitored via the [PlayOnService]
///   websocket (server-pushed Sessions messages) and mirrored into
///   [MusicPlayerBackgroundTask]'s playbackState/mediaItem streams, so every
///   consumer (player screen, now playing bar, queue list, media notification,
///   and the PlayOn receiver when we're being controlled ourselves) reflects
///   remote playback without special-casing.
/// - Transport commands issued to the audio handler are routed here and
///   forwarded to the remote session as playstate commands.
/// - The local queue acts as a paused mirror of the remote queue: local queue
///   changes are pushed to the remote (see [QueueService]), and remote queue
///   changes are adopted locally with the remoteClient queue source, keeping
///   queue persistence/restore working.
///
/// This is the inverse of [PlayOnService], which handles the controllee side
/// (receiving commands).
class RemoteSessionService {
  final _log = Logger("RemoteSessionService");
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  MusicPlayerBackgroundTask get _audioHandler => GetIt.instance<MusicPlayerBackgroundTask>();
  QueueService get _queueService => GetIt.instance<QueueService>();

  /// Jellyfin ticks are 100ns units, so 1 millisecond == 10000 ticks.
  static const int _ticksPerMillisecond = 10000;

  /// Maximum item ids per /Sessions/{id}/Playing request when adding tracks
  /// (PlayNext/PlayLast). Item ids are passed as a comma-separated query
  /// parameter (~33 chars per id), so large additions are split across
  /// requests to stay below common URI length limits (414 URI Too Long at
  /// ~250 items).
  static const int _maxItemsPerPlayRequest = 100;

  /// Maximum tracks per queue sent to a remote session (handoff, remove,
  /// reorder, skip), truncating any excess. Queues are sent as a single
  /// PlayNow request (it can't be split: appending would need PlayLast, which
  /// some clients mishandle), and remote clients broke on more anyway
  /// (Jellyfin Web capped at ~460 tracks with desyncs), so the cap is flat
  /// per review.
  static const int _maxTracksPerPlayNow = 150;

  String? _activeSessionId;
  StreamSubscription<List<SessionInfo>>? _sessionsSubscription;
  final _sessionStream = BehaviorSubject<SessionInfo?>.seeded(null);

  // mpv-shim reports PlayState.PositionTicks as null while paused / between
  // progress events, so we remember the last non-null position and fall back to
  // it. Reset on connect/disconnect and whenever the remote track changes.
  int? _lastKnownPositionTicks;
  String? _lastKnownItemId;

  // Server-pushed Sessions messages are event-driven (SessionEnded, playback
  // progress, ...), not periodic: if the remote dies without a clean websocket
  // close, no push ever reports it gone. After this long without a Sessions
  // message, fetch GET /Sessions once to confirm the session still exists.
  // Kept well above the ~10s playback-progress reporting cadence so it only
  // fires during genuine silence (e.g. a long pause), where the occasional
  // request is cheap.
  static const Duration _watchdogInterval = Duration(seconds: 30);
  Timer? _watchdogTimer;

  /// Non-null between pushing a queue to the remote and the remote reporting
  /// playback of one of the pushed tracks: session updates during that window
  /// predate the push, so they are ignored and the pushed target state is
  /// presented optimistically instead (see [_toPlaybackState]). The deadline
  /// is a backstop for remotes that never report the pushed queue.
  DateTime? _settleDeadline;

  /// True while a pushed queue hasn't been confirmed playing by the remote
  /// yet (see [_settleDeadline]).
  bool get isSettling => _settleDeadline != null;

  // ---- queue sync bookkeeping (echo suppression) ----

  /// While we're pushing our own queue to the remote, its NowPlayingQueue
  /// will disagree with ours until all chunks are processed. Don't adopt the
  /// remote queue during that window (it would echo half-transferred state
  /// back into the local queue).
  DateTime _suppressAdoptUntil = DateTime.fromMillisecondsSinceEpoch(0);
  List<String> _lastPushedQueueIds = [];
  bool _adoptScheduled = false;
  bool _adoptInProgress = false;

  /// True while this service is applying a remote-initiated update to the
  /// local queue/player. QueueService uses this to avoid pushing those changes
  /// straight back to the remote.
  bool _applyingRemoteUpdate = false;
  bool get isApplyingRemoteUpdate => _applyingRemoteUpdate;

  /// Whether we are currently controlling a remote session.
  bool get isRemote => _activeSessionId != null;

  /// The id of the session we are controlling, or null if local.
  String? get activeSessionId => _activeSessionId;

  /// The most recently observed state of the remote session, or null.
  SessionInfo? get currentRemoteState => _sessionStream.valueOrNull;

  /// A stream of the remote session's state, updated on each poll / websocket
  /// message. Emits null when disconnected.
  Stream<SessionInfo?> getRemoteStateStream() => _sessionStream;

  /// The current derived playback state, or null if not connected / before the
  /// first update.
  RemotePlaybackState? get remotePlaybackState => _toPlaybackState(_sessionStream.valueOrNull);

  /// The remote session's volume (0.0 - 1.0), if it reports one. Falls back
  /// to the volume observed when connecting, so the value is available
  /// immediately instead of only after the first monitoring update.
  double? get remoteVolume {
    final level = _sessionStream.valueOrNull?.playState?.volumeLevel ?? _seededVolumeLevel;
    return level == null ? null : level / 100.0;
  }

  /// Volume level (0-100) taken from the SessionInfo passed to [connect],
  /// used until monitoring reports a live value.
  int? _seededVolumeLevel;

  RemotePlaybackState? _toPlaybackState(SessionInfo? session) {
    // While a pushed queue is settling, any session snapshot predates the
    // push: present the pushed target optimistically (the remote starts
    // playing it on arrival) instead of stale or missing state.
    if (isSettling) {
      return RemotePlaybackState(
        position: Duration(microseconds: (_lastKnownPositionTicks ?? 0) ~/ 10),
        duration: _queueService.getQueue().currentTrack?.item.duration,
        playing: true,
      );
    }
    if (session == null) return null;
    // Fall back to the last known position when the remote reports null (e.g.
    // while paused). The cache is updated in _applySessionUpdate before the
    // stream emits.
    final positionTicks = session.playState?.positionTicks ?? _lastKnownPositionTicks ?? 0;
    return RemotePlaybackState(
      position: Duration(microseconds: positionTicks ~/ 10),
      duration: session.nowPlayingItem?.runTimeTicksDuration(),
      playing: !(session.playState?.isPaused ?? true),
    );
  }

  /// Begins controlling [session]. If [migrateQueue] is true, the current
  /// local queue is handed off to the remote (overriding whatever it was
  /// playing); otherwise we attach to the remote's existing playback and adopt
  /// its queue locally.
  Future<void> connect(SessionInfo session, {required bool migrateQueue}) async {
    final sessionId = session.id;
    if (sessionId == null) {
      _log.warning("Cannot connect to session without id");
      return;
    }
    _log.info("Connecting to remote session $sessionId (migrateQueue: $migrateQueue)");

    // Capture playback state before switching sessions (the getters follow
    // whichever session is active): when switching remote-to-remote this is
    // the previous remote's state, which the new session continues from.
    final wasPlaying = !_audioHandler.paused;
    final localPosition = _audioHandler.playbackPosition;

    // Pause whatever is currently audible so audio never plays on both ends:
    // the previous remote when switching remote-to-remote (the local player
    // is already a paused mirror then), the local player otherwise.
    if (isRemote) {
      try {
        await pause();
      } catch (e) {
        _log.warning("Failed to pause previous remote session $_activeSessionId: $e");
      }
    } else if (wasPlaying) {
      await _audioHandler.pause(disableFade: true, localOnly: true);
    }

    _activeSessionId = sessionId;
    _lastKnownPositionTicks = null;
    _lastKnownItemId = null;
    _settleDeadline = null;
    // The session list the user connected from already contains the remote's
    // volume; seed it so the volume slider is correct right away.
    _seededVolumeLevel = session.playState?.volumeLevel;
    // Drop any retained state from a previous session: the BehaviorSubject
    // would otherwise replay the old SessionInfo.
    _sessionStream.add(null);

    try {
      if (migrateQueue) {
        // The PlayTo API has no way to hand a queue off without starting
        // playback, so the remote starts playing even if local was paused.
        await pushQueueToRemote(startPosition: localPosition);
      } else {
        // Attach to existing playback: adopt whatever the remote is playing.
        _sessionStream.add(session);
        await _adoptRemoteQueue();
      }
    } catch (e) {
      _log.severe("Connecting to remote session failed", e);
      _teardown();
      rethrow;
    }

    _startMonitoring();
    unawaited(_audioHandler.refreshPlaybackStateAndMediaNotification());
  }

  /// Stops controlling the remote session and returns control to local
  /// playback. The remote is paused first (the queue "migrates back" to
  /// Finamp, so it shouldn't keep playing on both ends), unless [pauseRemote]
  /// is false (e.g. when the remote session has already vanished). If the
  /// remote was playing, local playback resumes from where it left off; a
  /// paused remote stays paused locally.
  Future<void> disconnect({bool pauseRemote = true}) async {
    _log.info("Disconnecting from remote session $_activeSessionId");
    // Continue locally from where the remote left off: remember the remote's
    // last-known track, position and playing state before tearing down state
    // (pause() below mutates the mirrored playing state).
    final lastItemId = _lastKnownItemId;
    final lastPosition = remotePlaybackState?.position;
    final wasPlaying = remotePlaybackState?.playing ?? false;

    if (pauseRemote) {
      try {
        await pause();
      } catch (e) {
        _log.warning("Failed to pause remote before disconnecting: $e");
      }
    }

    _teardown();

    // Sync local playback to where the remote left off. Must run after
    // _teardown so the commands hit the local player, not the (now gone)
    // remote.
    if (lastPosition != null) {
      await _syncLocalToRemote(lastItemId, lastPosition);
    }
    // Playback moved back to this device: continue playing if the remote was.
    // When the remote vanished instead of being migrated back (pauseRemote is
    // false), stay paused - suddenly blasting audio locally because a remote
    // player died would be surprising.
    if (pauseRemote && wasPlaying) {
      await _audioHandler.play(disableFade: true);
    }
    unawaited(_audioHandler.refreshPlaybackStateAndMediaNotification());
  }

  /// Stops the remote session's playback while staying connected: both ends
  /// end up stopped together, and the next queue started locally is handed
  /// off to the remote again. Used when the local queue is stopped while
  /// connected.
  Future<void> stopRemote() async {
    if (!isRemote) return;
    _log.info("Stopping playback on remote session $_activeSessionId (staying connected)");
    _lastKnownItemId = null;
    _lastKnownPositionTicks = null;
    _settleDeadline = null;
    _lastPushedQueueIds = [];
    // The remote may still push updates reflecting its pre-stop queue; don't
    // adopt those into the (now stopped) local queue.
    _suppressAdoptUntil = DateTime.now().add(const Duration(seconds: 10));
    // Present the stopped state immediately instead of the last mirrored one.
    _sessionStream.add(null);
    try {
      await stop();
    } catch (e) {
      _log.warning("Failed to stop remote session: $e");
    }
    unawaited(_audioHandler.refreshPlaybackStateAndMediaNotification());
  }

  /// Stops the remote session's playback entirely and returns control to
  /// local playback, without migrating the remote position back. Used when
  /// the connection is being torn down completely (e.g. logout), where
  /// [disconnect]'s pause-and-continue-locally behavior would be wrong.
  Future<void> stopAndDisconnect() async {
    if (!isRemote) return;
    _log.info("Stopping remote session $_activeSessionId and disconnecting");
    try {
      await stop();
    } catch (e) {
      _log.warning("Failed to stop remote before disconnecting: $e");
    }
    _teardown();
    unawaited(_audioHandler.refreshPlaybackStateAndMediaNotification());
  }

  void _teardown() {
    _stopMonitoring();
    _activeSessionId = null;
    _lastKnownPositionTicks = null;
    _lastKnownItemId = null;
    _settleDeadline = null;
    _adoptScheduled = false;
    _lastPushedQueueIds = [];
    _seededVolumeLevel = null;
    _sessionStream.add(null);
  }

  // ---- monitoring ----

  void _startMonitoring() {
    _stopMonitoring();
    _log.info("Monitoring remote session via the PlayOn websocket");
    _sessionsSubscription = GetIt.instance<PlayOnService>().startSessionUpdates().listen(_handleSessions);
    _armWatchdog();
  }

  void _stopMonitoring() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    if (_sessionsSubscription == null) return;
    unawaited(_sessionsSubscription?.cancel());
    _sessionsSubscription = null;
    GetIt.instance<PlayOnService>().stopSessionUpdates();
  }

  void _armWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(_watchdogInterval, () => unawaited(_checkSessionAlive()));
  }

  /// Watchdog: no Sessions message for [_watchdogInterval]. Legitimate while
  /// the remote is paused (no events to push), but also what a silently
  /// pruned session looks like, so confirm via a one-shot GET /Sessions run
  /// through the same handler (which re-arms the watchdog or disconnects).
  Future<void> _checkSessionAlive() async {
    if (!isRemote) return;
    _log.fine("No Sessions message for ${_watchdogInterval.inSeconds}s; confirming session via GET /Sessions");
    List<SessionInfo> sessions;
    try {
      sessions = await _jellyfinApiHelper.getSessions();
    } catch (e) {
      // Can't reach the server; that says nothing about the remote session,
      // so stay connected and try again later.
      _log.warning("Watchdog GET /Sessions failed: $e");
      _armWatchdog();
      return;
    }
    _handleSessions(sessions);
  }

  void _handleSessions(List<SessionInfo> sessions) {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    _armWatchdog();
    final session = sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) {
      // Every Sessions list (pushed or fetched) is the server's complete
      // session list, so a missing id is authoritative: the session is gone
      // (e.g. the remote player was stopped). Sessions pushes are event-driven,
      // so this message may be the only signal we ever get — fall back to
      // local immediately.
      final returned = sessions.map((s) => "${s.id} (${s.deviceName} / ${s.client})").join(", ");
      _log.info(
        "Remote session $sessionId not in sessions; falling back to local. Returned ${sessions.length}: [$returned]",
      );
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.playOnRemoteDeviceDisconnected);
      // The session is gone, so there's nothing left to pause.
      unawaited(disconnect(pauseRemote: false));
      return;
    }
    _applySessionUpdate(session);
  }

  void _applySessionUpdate(SessionInfo session) {
    final itemId = session.nowPlayingItem?.id.raw;

    // A pushed queue has settled once the remote reports one of the pushed
    // tracks as playing (or the backstop deadline passes).
    if (_settleDeadline != null) {
      if ((itemId != null && _lastPushedQueueIds.contains(_normalizeId(itemId))) ||
          DateTime.now().isAfter(_settleDeadline!)) {
        _settleDeadline = null;
      } else {
        // The remote hasn't applied the push yet, so this update reflects the
        // pre-push state: mirroring it would flap the UI back to the old
        // track, and its queue could get adopted over the just-pushed local
        // one. Keep presenting the optimistic pushed state instead; the
        // deadline caps how long updates are ignored, and session liveness
        // was already checked in _handleSessions.
        _log.finer("Ignoring pre-push remote update (item=${session.nowPlayingItem?.name})");
        return;
      }
    }

    // Maintain the last-known-position cache. Reset it when the remote track
    // changes so we don't carry a stale position into a new song; otherwise
    // remember any non-null position the remote reports.
    if (itemId != _lastKnownItemId) {
      _lastKnownItemId = itemId;
      _lastKnownPositionTicks = null;
    }
    final reportedTicks = session.playState?.positionTicks;
    if (reportedTicks != null) {
      _lastKnownPositionTicks = reportedTicks;
    }

    _log.finer(
      "Remote update: position=$reportedTicks (effective=$_lastKnownPositionTicks) "
      "isPaused=${session.playState?.isPaused} item=${session.nowPlayingItem?.name}",
    );
    _sessionStream.add(session);

    unawaited(_syncFromRemote(session));

    // Mirror the remote state into the audio handler's playbackState so all
    // playback UI (now playing bar, queue list, notification) updates.
    _audioHandler.refreshPlaybackStateAndMediaNotification();
  }

  // ---- remote -> local sync ----

  /// Keeps the local (paused) queue mirror in sync with the remote session:
  /// adopts remote queue changes and follows remote track changes.
  Future<void> _syncFromRemote(SessionInfo session) async {
    if (_adoptInProgress || _applyingRemoteUpdate) return;

    final remoteIds = session.nowPlayingQueue?.map((e) => _normalizeId(e.id)).toList();
    final queueInfo = _queueService.getQueue();
    final localFullIds = queueInfo.fullQueue.map((e) => _normalizeId(e.baseItemId.raw)).toList();

    // The remote queue matches if it is a contiguous window of our full queue:
    // a handed-off queue omits played history, and the window drifts as the
    // remote advances tracks (we only ever hand off from the current track
    // onward).
    final queueInSync = remoteIds == null || remoteIds.isEmpty || _isContiguousSublist(remoteIds, localFullIds);

    if (!queueInSync) {
      // Suppress adoption while a change we sent (push, addition, stop) is
      // still propagating: with no pushed queue to compare against, any
      // mismatch during the window is assumed to be our own change echoing
      // back; after a push, only its prefix is.
      if (DateTime.now().isBefore(_suppressAdoptUntil) && (_lastPushedQueueIds.isEmpty || _isOwnPushEcho(remoteIds))) {
        return;
      }
      _scheduleAdopt();
      return;
    }

    // Queue matches: follow the remote's current track so mediaItem / queue
    // highlighting / metadata stay correct.
    final itemId = session.nowPlayingItem?.id.raw;
    final localCurrentId = queueInfo.currentTrack?.baseItemId.raw;
    if (itemId != null && (localCurrentId == null || _normalizeId(itemId) != _normalizeId(localCurrentId))) {
      _applyingRemoteUpdate = true;
      try {
        await _skipLocalToItem(itemId);
      } finally {
        _applyingRemoteUpdate = false;
      }
    }

    _syncLoopModeFromRemote(session);
  }

  /// Jellyfin ids appear both dashed (GUID) and undashed depending on the
  /// endpoint/client, so normalize before comparing.
  static String _normalizeId(String id) => id.replaceAll("-", "").toLowerCase();

  /// True if [candidate] appears as a contiguous run inside [list].
  static bool _isContiguousSublist(List<String> candidate, List<String> list) {
    if (candidate.length > list.length) return false;
    for (var start = 0; start <= list.length - candidate.length; start++) {
      var matches = true;
      for (var i = 0; i < candidate.length; i++) {
        if (list[start + i] != candidate[i]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  /// True if [remoteIds] looks like a partially-applied version of the queue
  /// we just pushed (a prefix, since chunks are appended with PlayLast).
  bool _isOwnPushEcho(List<String> remoteIds) {
    if (_lastPushedQueueIds.isEmpty || remoteIds.length > _lastPushedQueueIds.length) return false;
    for (var i = 0; i < remoteIds.length; i++) {
      if (remoteIds[i] != _lastPushedQueueIds[i]) return false;
    }
    return true;
  }

  void _syncLoopModeFromRemote(SessionInfo session) {
    final remoteRepeat = session.playState?.repeatMode;
    if (remoteRepeat == null) return;
    final mode = switch (remoteRepeat) {
      "RepeatAll" => FinampLoopMode.all,
      "RepeatOne" => FinampLoopMode.one,
      _ => FinampLoopMode.none,
    };
    if (mode != _queueService.loopMode) {
      _applyingRemoteUpdate = true;
      try {
        _queueService.loopMode = mode;
      } finally {
        _applyingRemoteUpdate = false;
      }
    }
  }

  /// Debounced adoption of the remote queue: remote queue changes can arrive
  /// as several rapid updates (e.g. while the remote client rebuilds its
  /// playlist), so wait for it to settle before rebuilding the local queue.
  void _scheduleAdopt() {
    if (_adoptScheduled) return;
    _adoptScheduled = true;
    Future<void>.delayed(const Duration(seconds: 2), () async {
      _adoptScheduled = false;
      if (!isRemote) return;
      await _adoptRemoteQueue();
    });
  }

  /// Rebuilds the local queue from the remote session's NowPlayingQueue, using
  /// the remoteClient queue source (we can't know the real source of a remote
  /// queue). Goes through the regular queue replacement path so the queue is
  /// persisted and restorable after an app restart.
  Future<void> _adoptRemoteQueue() async {
    final session = _sessionStream.valueOrNull;
    final remoteQueue = session?.nowPlayingQueue;
    if (session == null || remoteQueue == null || remoteQueue.isEmpty) {
      _log.fine("No remote queue to adopt");
      return;
    }
    if (_adoptInProgress) return;
    _adoptInProgress = true;
    try {
      final remoteIds = remoteQueue.map((e) => e.id).toList();

      // Re-use items we already have locally, fetch only the missing ones.
      final queueInfo = _queueService.getQueue();

      // The adoption was scheduled on a stale mismatch (e.g. an own push that
      // has since been applied by the remote); re-check against the latest
      // state before replacing the local queue.
      final remoteIdsNormalized = remoteIds.map(_normalizeId).toList();
      if (_isContiguousSublist(
        remoteIdsNormalized,
        queueInfo.fullQueue.map((e) => _normalizeId(e.baseItemId.raw)).toList(),
      )) {
        _log.fine("Remote queue is in sync again; skipping adoption");
        return;
      }
      if (DateTime.now().isBefore(_suppressAdoptUntil) &&
          (_lastPushedQueueIds.isEmpty || _isOwnPushEcho(remoteIdsNormalized))) {
        _log.fine("Own queue change still propagating; skipping adoption");
        return;
      }
      final idMap = <String, BaseItemDto>{
        for (final item in queueInfo.fullQueue) _normalizeId(item.baseItemId.raw): item.baseItem,
      };
      final missingIds = remoteIds
          .where((id) => !idMap.containsKey(_normalizeId(id)))
          .toSet()
          .map(BaseItemId.new)
          .toList();
      if (missingIds.isNotEmpty) {
        final fetched = await _jellyfinApiHelper.getItems(itemIds: missingIds) ?? [];
        for (final item in fetched) {
          idMap[_normalizeId(item.id.raw)] = item;
        }
      }
      final items = remoteIds.map((id) => idMap[_normalizeId(id)]).nonNulls.toList();
      if (items.isEmpty) {
        _log.warning("Could not resolve any items of the remote queue; not adopting");
        return;
      }
      // The session may have been disconnected (e.g. playback stopped) while
      // the missing items were being fetched; don't resurrect its queue.
      if (!isRemote) return;

      final currentItemId = session.nowPlayingItem?.id.raw;
      var startIndex = currentItemId == null
          ? 0
          : items.indexWhere((item) => _normalizeId(item.id.raw) == _normalizeId(currentItemId));
      if (startIndex == -1) startIndex = 0;
      final position = remotePlaybackState?.position;

      _log.info("Adopting remote queue: ${items.length} items, current index $startIndex");
      _applyingRemoteUpdate = true;
      try {
        await _queueService.replaceQueueFromRemote(items: items, startIndex: startIndex, startPosition: position);
      } finally {
        _applyingRemoteUpdate = false;
      }
    } catch (e, stack) {
      _log.severe("Failed to adopt remote queue", e, stack);
    } finally {
      _adoptInProgress = false;
    }
  }

  /// Skips the local (paused) player to the remote's current track. Searches
  /// forward from the current track first: the remote plays the handed-off
  /// queue sequentially, so the first match at or after the current track is
  /// the right one even if a song appears twice.
  Future<void> _skipLocalToItem(String itemId) async {
    final queueInfo = _queueService.getQueue();
    if (queueInfo.currentTrack == null) return;
    final fullQueue = queueInfo.fullQueue;
    final currentIndex = queueInfo.previousTracks.length;
    final normalizedItemId = _normalizeId(itemId);
    var matchIndex = -1;
    for (var i = currentIndex; i < fullQueue.length; i++) {
      if (_normalizeId(fullQueue[i].baseItemId.raw) == normalizedItemId) {
        matchIndex = i;
        break;
      }
    }
    if (matchIndex == -1) {
      for (var i = currentIndex - 1; i >= 0; i--) {
        if (_normalizeId(fullQueue[i].baseItemId.raw) == normalizedItemId) {
          matchIndex = i;
          break;
        }
      }
    }
    if (matchIndex == -1) {
      _log.warning("Remote track $itemId not in local queue; scheduling queue adoption");
      _scheduleAdopt();
      return;
    }
    final offset = matchIndex - currentIndex;
    if (offset == 0) return;
    _log.info("Syncing local mirror to remote track $itemId (offset $offset)");
    // Bypass QueueService.skipByOffset, which routes to the remote while
    // connected: this call must move the local player.
    await _audioHandler.skipByOffset(offset);
  }

  /// Best-effort sync of local playback to where the remote left off, used at
  /// disconnect. Finds [itemId] in the local queue and skips to it at
  /// [position] in a single atomic player seek, so the player never passes
  /// through "new track at 0:00". just_audio's seek never starts playback, so
  /// local stays paused. If the remote was playing something outside the local
  /// queue, local playback is left untouched.
  Future<void> _syncLocalToRemote(String? itemId, Duration position) async {
    if (itemId == null) {
      // Remote item unknown (e.g. the remote went idle): the track can't have
      // changed under us, so just seek the current local track.
      await _audioHandler.seek(position);
      return;
    }
    final queueInfo = _queueService.getQueue();
    if (queueInfo.currentTrack == null) return;
    final normalizedItemId = _normalizeId(itemId);
    if (_normalizeId(queueInfo.currentTrack!.baseItemId.raw) == normalizedItemId) {
      // Continuous track sync keeps the mirror on the right track, so usually
      // only the position is stale.
      await _audioHandler.seek(position);
      return;
    }
    final fullQueue = queueInfo.fullQueue;
    final currentIndex = queueInfo.previousTracks.length;
    var matchIndex = -1;
    for (var i = currentIndex; i < fullQueue.length; i++) {
      if (_normalizeId(fullQueue[i].baseItemId.raw) == normalizedItemId) {
        matchIndex = i;
        break;
      }
    }
    if (matchIndex == -1) {
      for (var i = currentIndex - 1; i >= 0; i--) {
        if (_normalizeId(fullQueue[i].baseItemId.raw) == normalizedItemId) {
          matchIndex = i;
          break;
        }
      }
    }
    if (matchIndex == -1) {
      _log.warning("Remote track $itemId not in local queue; leaving local playback untouched");
      return;
    }
    final offset = matchIndex - currentIndex;
    _log.info("Syncing local playback to remote track $itemId (offset $offset, position $position)");
    await _audioHandler.skipByOffset(offset, position: position);
  }

  // ---- local -> remote sync ----

  /// Hands the local queue off to the remote session, continuing the current
  /// track from [startPosition] (see [_playQueueFromIndex]).
  Future<void> pushQueueToRemote({Duration? startPosition}) async {
    if (!isRemote) return;
    final currentIndex = _queueService.getQueue().previousTracks.length;
    await _playQueueFromIndex(currentIndex, startPosition: startPosition);
  }

  /// Forwards items added to the local queue to the remote session's queue
  /// ([asNext]: play next vs. append at the end).
  Future<void> sendItemsToRemoteQueue(List<BaseItemId> itemIds, {required bool asNext}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null || itemIds.isEmpty) return;
    _suppressAdoptUntil = DateTime.now().add(const Duration(seconds: 10));
    // After an addition, the local queue is the source of truth for echo
    // detection; recompute after QueueService has updated its state.
    _lastPushedQueueIds = [];
    for (final chunk in itemIds.slices(_maxItemsPerPlayRequest)) {
      await _jellyfinApiHelper.sendPlayToSession(
        sessionId: sessionId,
        itemIds: chunk,
        playCommand: asNext ? "PlayNext" : "PlayLast",
      );
    }
  }

  /// Re-sends the queue to the remote, continuing the current track at the
  /// current position. Used for queue changes that have no incremental remote
  /// command (remove, reorder).
  Future<void> resyncQueueToRemote() async {
    if (!isRemote) return;
    final currentIndex = _queueService.getQueue().previousTracks.length;
    await _playQueueFromIndex(currentIndex, startPosition: remotePlaybackState?.position);
  }

  /// Jumps the remote to the queue item [offset] tracks away from the current
  /// one. Adjacent skips map to playstate commands; larger jumps re-send the
  /// queue with the target track as the start index.
  Future<void> skipByOffset(int offset) async {
    if (offset == 1) return next();
    if (offset == -1) return previous();
    final currentIndex = _queueService.getQueue().previousTracks.length;
    await _playQueueFromIndex(currentIndex + offset);
  }

  /// Makes the remote play the local queue from [targetIndex] (an index into
  /// the full queue, played history included) with a single PlayNow request.
  /// The queue is always sent from the target track onward (played history is
  /// dropped), capped flat at [_maxTracksPerPlayNow]: several remote clients
  /// ignore a nonzero StartIndex and would start at the first sent track, so
  /// the request never relies on it.
  Future<void> _playQueueFromIndex(int targetIndex, {Duration? startPosition}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    final fullQueue = _queueService.getQueue().fullQueue;
    if (fullQueue.isEmpty) return;
    final clampedTarget = targetIndex.clamp(0, fullQueue.length - 1);
    final window = fullQueue.skip(clampedTarget).take(_maxTracksPerPlayNow).toList();
    final itemIds = window.map((item) => item.baseItemId).toList();
    _lastPushedQueueIds = itemIds.map((id) => _normalizeId(id.raw)).toList();
    _suppressAdoptUntil = DateTime.now().add(const Duration(seconds: 20));
    _settleDeadline = DateTime.now().add(const Duration(seconds: 10));
    // Seed the mirrored state with the pushed target: while the push settles,
    // the UI presents this expected state instead of the remote's stale one.
    _lastKnownItemId = window.first.baseItemId.raw;
    _lastKnownPositionTicks = (startPosition ?? Duration.zero).inMilliseconds * _ticksPerMillisecond;
    _log.info("Sending ${itemIds.length} queue items to remote session $sessionId, startPosition=$startPosition");
    try {
      await _jellyfinApiHelper.sendPlayToSession(
        sessionId: sessionId,
        itemIds: itemIds,
        startPositionTicks: startPosition == null ? null : startPosition.inMilliseconds * _ticksPerMillisecond,
      );
    } catch (e) {
      _settleDeadline = null;
      rethrow;
    }
    // Present the optimistic post-push state right away instead of after the
    // next remote update.
    unawaited(_audioHandler.refreshPlaybackStateAndMediaNotification());
  }

  /// Sets the repeat mode on the remote session.
  Future<void> setRemoteRepeatMode(FinampLoopMode mode) async {
    final repeatMode = switch (mode) {
      FinampLoopMode.all => "RepeatAll",
      FinampLoopMode.one => "RepeatOne",
      FinampLoopMode.none => "RepeatNone",
    };
    await _sendGeneralCommand("SetRepeatMode", arguments: {"RepeatMode": repeatMode});
  }

  /// Sets the remote session's volume ([volume] is 0.0 - 1.0).
  Future<void> setVolume(double volume) async {
    final level = (volume.clamp(0.0, 1.0) * 100).round();
    // Optimistically update the mirrored state so the slider doesn't snap back
    // while waiting for the next session update.
    _sessionStream.valueOrNull?.playState?.volumeLevel = level;
    _seededVolumeLevel = level;
    await _sendGeneralCommand("SetVolume", arguments: {"Volume": level.toString()});
  }

  Future<void> _sendGeneralCommand(String name, {Map<String, String>? arguments}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      _log.warning("Ignoring general command '$name': no active remote session");
      return;
    }
    _log.info("Sending general command '$name' ($arguments) to remote session $sessionId");
    await _jellyfinApiHelper.sendGeneralCommandToSession(sessionId: sessionId, name: name, arguments: arguments);
  }

  // ---- transport commands ----

  Future<void> _sendCommand(String command, {int? seekPositionTicks}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      _log.warning("Ignoring '$command': no active remote session");
      return;
    }
    _log.info("Sending '$command' to remote session $sessionId");
    await _jellyfinApiHelper.sendPlaystateCommand(
      sessionId: sessionId,
      command: command,
      seekPositionTicks: seekPositionTicks,
    );
  }

  /// Optimistically updates the mirrored playing state so UI toggles react
  /// immediately instead of after the next remote update.
  void _presentPlaying(bool playing) {
    final session = _sessionStream.valueOrNull;
    if (session?.playState == null) return;
    session!.playState!.isPaused = !playing;
    _sessionStream.add(session);
    _audioHandler.refreshPlaybackStateAndMediaNotification();
  }

  Future<void> playPause() {
    final playing = remotePlaybackState?.playing;
    if (playing != null) _presentPlaying(!playing);
    return _sendCommand("PlayPause");
  }

  Future<void> pause() {
    _presentPlaying(false);
    return _sendCommand("Pause");
  }

  Future<void> unpause() {
    // An idle remote (e.g. stopped while staying connected) has nothing to
    // resume; hand the local queue off again instead.
    if (!isSettling && currentRemoteState?.nowPlayingItem == null && _queueService.getQueue().currentTrack != null) {
      return pushQueueToRemote(startPosition: _audioHandler.playbackPosition);
    }
    _presentPlaying(true);
    return _sendCommand("Unpause");
  }

  Future<void> next() => _sendCommand("NextTrack");
  Future<void> previous() => _sendCommand("PreviousTrack");
  Future<void> stop() => _sendCommand("Stop");

  Future<void> seek(Duration position) {
    // Optimistically move the mirrored position so the progress bar doesn't
    // jump back until the next remote update confirms the seek.
    _lastKnownPositionTicks = position.inMilliseconds * _ticksPerMillisecond;
    final session = _sessionStream.valueOrNull;
    if (session?.playState != null) {
      session!.playState!.positionTicks = _lastKnownPositionTicks;
      _sessionStream.add(session);
      _audioHandler.refreshPlaybackStateAndMediaNotification();
    }
    return _sendCommand("Seek", seekPositionTicks: position.inMilliseconds * _ticksPerMillisecond);
  }
}
