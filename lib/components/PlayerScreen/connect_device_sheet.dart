import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/jellyfin_api.dart' as jellyfin_api;
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/remote_session_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

final _log = Logger("ConnectDeviceSheet");

void showConnectDeviceSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _ConnectDeviceSheet(),
  );
}

class _ConnectDeviceSheet extends StatefulWidget {
  const _ConnectDeviceSheet();

  @override
  State<_ConnectDeviceSheet> createState() => _ConnectDeviceSheetState();
}

class _ConnectDeviceSheetState extends State<_ConnectDeviceSheet> {
  late Future<List<SessionInfo>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
  }

  Future<List<SessionInfo>> _loadSessions() async {
    final myDeviceId = (await jellyfin_api.getDeviceInfo()).id;
    final sessions = await GetIt.instance<JellyfinApiHelper>().getSessions();
    return sessions
        .where((s) => s.supportsRemoteControl && s.deviceId != myDeviceId)
        .toList();
  }

  Future<void> _sendPlay(SessionInfo session) async {
    _log.info("_sendPlay tapped: sessionId=${session.id}, deviceName=${session.deviceName}");

    final queueInfo = GetIt.instance<QueueService>().getQueue();
    final allItems = [
      if (queueInfo.currentTrack != null) queueInfo.currentTrack!,
      ...queueInfo.nextUp,
      ...queueInfo.queue,
    ];

    _log.info("Queue items to send: ${allItems.length}");

    if (allItems.isEmpty) {
      _log.warning("Queue is empty, aborting sendPlay");
      GlobalSnackbar.message((context) => "No items in queue");
      return;
    }

    final itemIds = allItems.map((item) => item.baseItemId).toList();
    // Capture the current local position (while still playing) so the remote
    // resumes from where the phone was, not from 0. Ticks = ms * 10000.
    final startPositionTicks = GetIt.instance<MusicPlayerBackgroundTask>().playbackPosition.inMilliseconds * 10000;
    if (!mounted) return;
    Navigator.of(context).pop();

    _log.info("Calling sendPlayToSession with ${itemIds.length} items");
    try {
      await GetIt.instance<JellyfinApiHelper>().sendPlayToSession(
        sessionId: session.id!,
        itemIds: itemIds,
        startPositionTicks: startPositionTicks,
      );
      _log.info("sendPlayToSession completed successfully");
      // Hand-off succeeded: pause local playback so audio doesn't play on both
      // the phone and the remote device. Pause (not stop) keeps the queue and
      // player screen intact for the upcoming remote-mirror UI (Slice D3+).
      await GetIt.instance<MusicPlayerBackgroundTask>().pause();
      // Enter remote mode: start polling the remote session's state so the UI
      // can mirror it (Slice D3+) and transport commands have a target.
      GetIt.instance<RemoteSessionService>().connect(session.id!);
      GlobalSnackbar.message(
        (context) => "Playing on ${session.deviceName ?? session.client ?? 'remote device'}",
      );
    } catch (e, stack) {
      _log.severe("sendPlayToSession failed", e, stack);
      GlobalSnackbar.message((context) => "Connect failed: $e");
    }
  }

  /// Shown when already controlling a remote device: names it and offers a
  /// Disconnect action (Slice D5b, option A — leaves the remote playing and
  /// returns control to the phone, which stays paused).
  Widget _buildConnectedHeader(BuildContext context) {
    final remoteSession = GetIt.instance<RemoteSessionService>();
    final name = remoteSession.currentRemoteState?.deviceName ??
        remoteSession.currentRemoteState?.client ??
        "remote device";
    return ListTile(
      leading: const Icon(Icons.cast_connected),
      title: Text("Connected to $name"),
      trailing: TextButton(
        onPressed: () {
          remoteSession.disconnect();
          Navigator.of(context).pop();
          GlobalSnackbar.message((context) => "Disconnected");
        },
        child: const Text("Disconnect"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remoteSession = GetIt.instance<RemoteSessionService>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              "Play on device",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (remoteSession.isRemote) _buildConnectedHeader(context),
          FutureBuilder<List<SessionInfo>>(
            future: _sessionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(child: Text("Error: ${snapshot.error}")),
                );
              }
              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text("No devices found")),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return ListTile(
                    leading: const Icon(Icons.cast),
                    title: Text(session.deviceName ?? session.client ?? "Unknown device"),
                    subtitle: session.client != null ? Text(session.client!) : null,
                    onTap: () => _sendPlay(session),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
