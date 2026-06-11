import 'dart:async';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

/// The subset of remote session state the player UI mirrors (Slice D3).
/// Derived from the polled [SessionInfo] so widgets don't re-derive tick math.
class RemotePlaybackState {
  final Duration position;
  final Duration? duration;
  final bool playing;

  const RemotePlaybackState({
    required this.position,
    required this.duration,
    required this.playing,
  });
}

/// Drives playback on another Jellyfin session ("Play On" / Connect controller
/// side). While connected, polls the server for the remote session's state and
/// exposes typed transport commands. This is the inverse of [PlayOnService],
/// which handles the controllee side (receiving commands).
class RemoteSessionService {
  final _log = Logger("RemoteSessionService");
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  /// Jellyfin ticks are 100ns units, so 1 millisecond == 10000 ticks.
  static const int _ticksPerMillisecond = 10000;

  /// How often to poll the server for the remote session's state.
  static const Duration _pollInterval = Duration(seconds: 1);

  String? _activeSessionId;
  Timer? _pollTimer;
  final _remoteStateStream = BehaviorSubject<SessionInfo?>.seeded(null);

  // mpv-shim reports PlayState.PositionTicks as null while paused / between
  // progress events, so we remember the last non-null position and fall back to
  // it. Reset on connect/disconnect and whenever the remote track changes.
  int? _lastKnownPositionTicks;
  String? _lastKnownItemId;

  // Consecutive polls where the remote session wasn't found. We tolerate a few
  // transient misses (network blips, mpv-shim hiccups) before falling back to
  // local, so a momentary gap doesn't bounce us out of remote mode.
  int _consecutiveMisses = 0;
  static const int _maxConsecutiveMisses = 3;

  /// Whether we are currently controlling a remote session.
  bool get isRemote => _activeSessionId != null;

  /// The id of the session we are controlling, or null if local.
  String? get activeSessionId => _activeSessionId;

  /// The most recently polled state of the remote session, or null.
  SessionInfo? get currentRemoteState => _remoteStateStream.valueOrNull;

  /// A stream of the remote session's state, updated on each poll.
  Stream<SessionInfo?> getRemoteStateStream() => _remoteStateStream;

  /// The current derived playback state for the player UI, or null if not
  /// connected / before the first poll.
  RemotePlaybackState? get remotePlaybackState => _toPlaybackState(_remoteStateStream.valueOrNull);

  /// A stream of the derived playback state (position/duration/playing) for the
  /// player UI to mirror.
  Stream<RemotePlaybackState?> getRemotePlaybackStateStream() => _remoteStateStream.map(_toPlaybackState);

  RemotePlaybackState? _toPlaybackState(SessionInfo? session) {
    if (session == null) return null;
    // Fall back to the last known position when the remote reports null (e.g.
    // while paused). The cache is updated in _poll before the stream emits.
    final positionTicks = session.playState?.positionTicks ?? _lastKnownPositionTicks ?? 0;
    return RemotePlaybackState(
      position: Duration(microseconds: positionTicks ~/ 10),
      duration: session.nowPlayingItem?.runTimeTicksDuration(),
      playing: !(session.playState?.isPaused ?? true),
    );
  }

  /// Begins controlling the session with the given [sessionId] and starts
  /// polling for its state.
  void connect(String sessionId) {
    // Idempotent: ignore a duplicate connect to the session we're already
    // polling, so we don't needlessly reset state or restart the timer.
    // Connecting to a different session falls through and switches over.
    if (_activeSessionId == sessionId && _pollTimer != null) {
      _log.info("Already controlling remote session $sessionId; ignoring duplicate connect");
      return;
    }
    _log.info("Connecting to remote session $sessionId");
    _activeSessionId = sessionId;
    _lastKnownPositionTicks = null;
    _lastKnownItemId = null;
    _consecutiveMisses = 0;
    // Drop any retained state from a previous session: the BehaviorSubject would
    // otherwise replay the old SessionInfo, so the player UI briefly shows the
    // previous remote position before the first poll of the new session arrives.
    _remoteStateStream.add(null);
    // Poll immediately so the UI doesn't have to wait a full interval.
    unawaited(_poll());
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Stops controlling the remote session and stops polling. Returns control
  /// to local playback.
  void disconnect() {
    _log.info("Disconnecting from remote session $_activeSessionId");
    // Continue locally from where the remote left off: sync local playback to
    // the remote's last-known track and position before we tear down state
    // (the getters read from it). Local stays paused (option A); the user
    // taps play to resume from here.
    final lastItemId = _lastKnownItemId;
    final lastPosition = remotePlaybackState?.position;
    if (lastPosition != null) {
      unawaited(_syncLocalToRemote(lastItemId, lastPosition));
    }
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeSessionId = null;
    _lastKnownPositionTicks = null;
    _lastKnownItemId = null;
    _consecutiveMisses = 0;
    _remoteStateStream.add(null);
  }

  /// Best-effort sync of local playback to where the remote left off. Finds
  /// [itemId] in the local queue and skips to it at [position] in a single
  /// atomic player seek, so the player never passes through "new track at
  /// 0:00". just_audio's seek never starts playback, so local stays paused.
  /// If the remote was playing something outside the local queue, local
  /// playback is left untouched (better than seeking the wrong track to a
  /// meaningless position).
  Future<void> _syncLocalToRemote(String? itemId, Duration position) async {
    if (itemId == null) {
      // Remote item unknown (e.g. the remote went idle): the track can't have
      // changed under us, so just seek the current local track.
      await GetIt.instance<MusicPlayerBackgroundTask>().seek(position);
      return;
    }
    final queueInfo = GetIt.instance<QueueService>().getQueue();
    if (queueInfo.currentTrack == null) return;
    final fullQueue = queueInfo.fullQueue;
    // The current track's index in fullQueue. (Not currentTrackIndex, which
    // counts tracks up to and including the current one.)
    final currentIndex = queueInfo.previousTracks.length;
    // Search forward from the current track first: the remote plays the
    // handed-off queue sequentially, so the first match at or after the
    // current track is the right one even if a song appears twice. Only then
    // look backwards (e.g. the remote was skipped to a previous track).
    var matchIndex = -1;
    for (var i = currentIndex; i < fullQueue.length; i++) {
      if (fullQueue[i].baseItemId.raw == itemId) {
        matchIndex = i;
        break;
      }
    }
    if (matchIndex == -1) {
      for (var i = currentIndex - 1; i >= 0; i--) {
        if (fullQueue[i].baseItemId.raw == itemId) {
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
    await GetIt.instance<QueueService>().skipByOffset(offset, position: position);
  }

  Future<void> _poll() async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    try {
      // No controllableByUserId filter: it can hide linux/mpv-shim when other
      // sessions are present. We fetch all sessions and match by id instead.
      final sessions = await _jellyfinApiHelper.getSessions(
        logSessions: false,
        controllableByCurrentUserOnly: false,
      );
      final session = sessions.where((s) => s.id == sessionId).firstOrNull;
      if (session == null) {
        // Session ended or vanished (e.g. DAC stopped). Tolerate a few transient
        // misses before falling back, and keep the last-known state on screen
        // during the window rather than flickering to local.
        _consecutiveMisses++;
        // Log the id we're searching for vs. every id+name the server returned,
        // to tell "id changed" apart from "genuinely absent".
        final returned = sessions.map((s) => "${s.id} (${s.deviceName} / ${s.client})").join(", ");
        _log.warning(
          "Remote session $sessionId not in /Sessions (miss $_consecutiveMisses/$_maxConsecutiveMisses). "
          "Returned ${sessions.length}: [$returned]",
        );
        if (_consecutiveMisses >= _maxConsecutiveMisses) {
          _log.info("Remote session gone after $_consecutiveMisses misses; falling back to local");
          GlobalSnackbar.message((context) =>
              AppLocalizations.of(context)!.playOnRemoteDeviceDisconnected);
          // disconnect() cancels this timer, clears state, and emits null so the
          // player UI returns to local control (left paused; user taps play).
          disconnect();
        }
        return;
      }
      // Session found again: clear the transient-miss counter.
      _consecutiveMisses = 0;
      // Maintain the last-known-position cache. Reset it when the remote track
      // changes so we don't carry a stale position into a new song; otherwise
      // remember any non-null position the remote reports.
      final itemId = session.nowPlayingItem?.id?.raw;
      if (itemId != _lastKnownItemId) {
        _lastKnownItemId = itemId;
        _lastKnownPositionTicks = null;
      }
      final reportedTicks = session.playState?.positionTicks;
      if (reportedTicks != null) {
        _lastKnownPositionTicks = reportedTicks;
      }
      _log.finer(
        "Remote poll: position=$reportedTicks (effective=$_lastKnownPositionTicks) isPaused=${session.playState?.isPaused} item=${session.nowPlayingItem?.name}",
      );
      _remoteStateStream.add(session);
    } catch (e, stack) {
      // Never let a transient error kill the polling timer.
      _log.severe("Remote poll failed", e, stack);
    }
  }

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

  Future<void> playPause() => _sendCommand("PlayPause");
  Future<void> pause() => _sendCommand("Pause");
  Future<void> unpause() => _sendCommand("Unpause");
  Future<void> next() => _sendCommand("NextTrack");
  Future<void> previous() => _sendCommand("PreviousTrack");
  Future<void> stop() => _sendCommand("Stop");

  Future<void> seek(Duration position) =>
      _sendCommand("Seek", seekPositionTicks: position.inMilliseconds * _ticksPerMillisecond);
}
