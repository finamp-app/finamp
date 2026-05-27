import 'dart:async';
import 'dart:convert';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/favorite_provider.dart';
import 'package:finamp/services/jellyfin_api.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../services/finamp_settings_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../../services/music_player_background_task.dart';
import 'finamp_user_helper.dart';

final _playOnServiceLogger = Logger("PlayOnService");
final _finampUserHelper = GetIt.instance<FinampUserHelper>();
final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
final _queueService = GetIt.instance<QueueService>();
final _audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
late WebSocketChannel _channel;
StreamSubscription<void>? _keepaliveSubscription;
StreamSubscription<int>? _isControlledSubscription;

enum SocketState { disconnected, connecting, connected }

class PlayOnService {
  // If the websocket connection to the server is established
  SocketState socketState = SocketState.disconnected;
  // If a remote client is controlling the session
  bool isControlled = false;
  // If pending connections should be cancelled and the socket closed
  bool abortConnect = false;
  // If the connection retry loop is currently running
  bool retryActive = false;

  Future<void> initialize() async {
    _playOnServiceLogger.info("Initializing PlayOn service");

    // Turn on/off when offline mode is toggled
    var settingsListener = FinampSettingsHelper.finampSettingsListener;
    settingsListener.addListener(() async {
      if (socketState != SocketState.disconnected && FinampSettingsHelper.finampSettings.isOffline) {
        _playOnServiceLogger.info("Offline mode enabled, closing PlayOn listener now");
        closeListener();
      } else if (!FinampSettingsHelper.finampSettings.enablePlayon) {
        if (socketState != SocketState.disconnected) {
          closeListener();
        }
      } else if (FinampSettingsHelper.finampSettings.enablePlayon && socketState == SocketState.disconnected) {
        await startListener();
      }
    });

    //!!! not working, context is null during initialization
    // GetIt.instance<ProviderContainer>()
    //     .listen(
    //         finampSettingsProvider.select((s) => (
    //               s.value?.isOffline ?? false,
    //               s.value?.enablePlayon ?? false
    //             )), (previous, next) async {
    //   final (isOffline, enablePlayon) = next;
    //   if (isConnected && isOffline) {
    //     _playOnServiceLogger
    //         .info("Offline mode enabled, closing PlayOn listener now");
    //     await closeListener();
    //   } else if (!enablePlayon) {
    //     await closeListener();
    //   } else if (!isConnected && enablePlayon) {
    //     await startListener();
    //   }
    // });

    // Sometimes we temporarily lose connection while the screen is locked.
    // Try reconnecting once again when the user begins interacting again, if still disconnected
    AppLifecycleListener(
      onRestart: () {},
      onHide: () {},
      onShow: () {
        if (socketState == SocketState.disconnected && FinampSettingsHelper.finampSettings.enablePlayon) {
          _playOnServiceLogger.info("App in foreground and visible, attempting to reconnect.");
          _startReconnectionLoop();
        }
      },
      onPause: () {},
    );

    await startListener();
  }

  Future<void> startListener() async {
    abortConnect = false;
    try {
      if (!FinampSettingsHelper.finampSettings.isOffline &&
          FinampSettingsHelper.finampSettings.enablePlayon &&
          _finampUserHelper.currentUser != null) {
        assert(socketState == SocketState.disconnected);
        _playOnServiceLogger.info("Attempting to start PlayOn listener");
        socketState = SocketState.connecting;

        await _jellyfinApiHelper.updateCapabilitiesFull(
          ClientCapabilities(
            supportsMediaControl: true,
            supportsPersistentIdentifier: true,
            playableMediaTypes: ["Audio"],
            supportedCommands: [
              "MoveUp",
              "MoveDown",
              "MoveLeft",
              "MoveRight",
              "PageUp",
              "PageDown",
              "PreviousLetter",
              "NextLetter",
              "ToggleOsd",
              "ToggleContextMenu",
              "Select",
              "Back",
              "TakeScreenshot",
              "SendKey",
              "SendString",
              "GoHome",
              "GoToSettings",
              "VolumeUp",
              "VolumeDown",
              "Mute",
              "Unmute",
              "ToggleMute",
              "SetVolume",
              "SetAudioStreamIndex",
              "SetSubtitleStreamIndex",
              "ToggleFullscreen",
              "DisplayContent",
              "GoToSearch",
              "DisplayMessage",
              "SetRepeatMode",
              "ChannelUp",
              "ChannelDown",
              "Guide",
              "ToggleStats",
              "PlayMediaSource",
              "PlayTrailers",
              "SetShuffleQueue",
              "PlayState",
              "PlayNext",
              "ToggleOsdMenu",
              "Play",
              "SetMaxStreamingBitrate",
              "SetPlaybackOrder",
            ],
          ),
        );
        if (abortConnect) {
          socketState = SocketState.disconnected;
          return;
        }
        await _connectWebsocket();
      }
    } catch (e) {
      _playOnServiceLogger.severe("Error starting PlayOn listener: $e");
      assert(socketState != SocketState.connected);
      socketState = SocketState.disconnected;
      unawaited(_startReconnectionLoop());
    }
  }

  Future<void> _startReconnectionLoop() async {
    assert(socketState == SocketState.disconnected);
    if (retryActive) return;
    try {
      retryActive = true;
      final startTime = DateTime.now();
      while (true) {
        await Future<void>.delayed(Duration(seconds: FinampSettingsHelper.finampSettings.playOnReconnectionDelay));
        assert(retryActive);
        if (abortConnect) {
          return;
        }
        switch (socketState) {
          case SocketState.disconnected:
            if (startTime.difference(DateTime.now()) > Duration(minutes: 5)) {
              // Retry loop has timed out
              _playOnServiceLogger.warning("Stopped attempting to connect playon");
              socketState = SocketState.disconnected;
              return;
            } else {
              // Retry the connection
              await startListener();
            }
          case SocketState.connecting:
            // Someone else called startListener().  Wait them out and do not exit the loop.
            break;
          case SocketState.connected:
            // The retry loop is no longer needed
            return;
        }
      }
    } finally {
      retryActive = false;
    }
  }

  Future<void> _connectWebsocket() async {
    assert(socketState == SocketState.connecting);
    final deviceInfo = await getDeviceInfo();
    //FIXME the websocket connection doesn't work on 10.11 with legacy auth disabled (https://gist.github.com/nielsvanvelzen/ea047d9028f676185832e51ffaf12a6f#disabling-deprecated-authorization-methods)
    // the [api_key] parameter is deprecated, but there's no way to set HTTP headers for our websocket client
    // apparently this is because it's not possible to do on the web, which would mean that Jellyfin Web (which is also broken as of 10.11.5) would also need an alternative to authenticate, for example sending the auth token in the first message after connecting
    final url =
        "${_finampUserHelper.currentUser!.baseURL}/socket?api_key=${_finampUserHelper.currentUser!.accessToken}&deviceId=${deviceInfo.id}";
    final parsedUrl = Uri.parse(url);
    final wsUrl = parsedUrl.replace(scheme: parsedUrl.scheme == "https" ? "wss" : "ws");
    _channel = WebSocketChannel.connect(wsUrl);

    await _channel.ready;
    _playOnServiceLogger.info("WebSocket connection to server established");
    socketState = SocketState.connected;
    if (abortConnect) {
      closeListener();
      return;
    }

    _channel.sink.add('{"MessageType":"KeepAlive"}');

    _channel.stream.listen(
      _handleMessage,
      onDone: () {
        _keepaliveSubscription?.cancel();
        socketState = SocketState.disconnected;
        if (!FinampSettingsHelper.finampSettings.isOffline && FinampSettingsHelper.finampSettings.enablePlayon) {
          _playOnServiceLogger.warning("WebSocket connection closed, attempting to reconnect");
          _startReconnectionLoop();
        }
      },
      onError: (error) {
        _playOnServiceLogger.severe("WebSocket Error: $error");
        _keepaliveSubscription?.cancel();
        socketState = SocketState.disconnected;
      },
    );

    _keepaliveSubscription = Stream<void>.periodic(const Duration(seconds: 30)).listen((event) {
      _playOnServiceLogger.info("Sent KeepAlive message through websocket");
      _channel.sink.add('{"MessageType":"KeepAlive"}');
    });
  }

  void closeListener() {
    abortConnect = true;
    _playOnServiceLogger.info("Closing playon session");
    switch (socketState) {
      case SocketState.connected:
        _channel.sink.add('{"MessageType":"SessionsStop"}');
        unawaited(_keepaliveSubscription?.cancel());
        unawaited(_channel.sink.close());
        socketState = SocketState.disconnected;
      case SocketState.connecting:
        // Wait for abortConnection to take, closeListener will be called again if needed
        break;
      case SocketState.disconnected:
        // Nothing to do
        break;
    }
  }

  Future<void> _handleMessage(dynamic value) async {
    try {
      _playOnServiceLogger.finest("Received message: $value");

      var request = jsonDecode(value as String);

      if (request['MessageType'] != 'ForceKeepAlive' && request['MessageType'] != 'KeepAlive') {
        switch (request['MessageType']) {
          case "GeneralCommand":
            switch (request['Data']['Name']) {
              case "DisplayMessage":
                final messageFromServer = request['Data']['Arguments']['Text'];
                final header = request['Data']['Arguments']['Header'];
                final timeout = request['Data']['Arguments']['Timeout'];
                _playOnServiceLogger.info("Displaying message from server: '$messageFromServer'");
                GlobalSnackbar.message((context) => "$header: $messageFromServer");
                break;
              case "SetVolume":
                _playOnServiceLogger.info("Server requested a volume adjustment");

                final desiredVolume = request['Data']['Arguments']['Volume'] as String;
                _audioHandler.setVolume(double.parse(desiredVolume) / 100.0);
            }
            break;
          case "UserDataChanged":
            var item = await _jellyfinApiHelper.getItemById(
              BaseItemId(request['Data']['UserDataList'][0]['ItemId'] as String),
            );

            // Handle toggling favorite status from remote client
            _playOnServiceLogger.info("Updating favorite ui state");
            GetIt.instance<ProviderContainer>()
                .read(isFavoriteProvider(item).notifier)
                .updateState(item.userData!.isFavorite);
            break;
          default:
            // Because the Jellyfin server doesn't notify remote client connection/disconnection,
            // we mark the remote controlling as stale after 90 seconds without input as a workaround.
            // This is particularly useful to stop agressively reporting playback when it's not needed
            await _isControlledSubscription?.cancel();
            isControlled = true;
            _isControlledSubscription =
                Stream.periodic(
                  Duration(seconds: FinampSettingsHelper.finampSettings.playOnStaleDelay),
                  (count) => count,
                ).listen((event) {
                  _playOnServiceLogger.info("Mark remote controlling as stale");
                  isControlled = false;
                  _isControlledSubscription?.cancel();
                });
            switch (request['Data']['Command']) {
              case "Stop":
                await _audioHandler.stop();
                break;
              case "Pause":
                await _audioHandler.pause();
                break;
              case "Unpause":
                await _audioHandler.play();
                break;
              case "NextTrack":
                await _audioHandler.skipToNext();
                break;
              case "PreviousTrack":
                await _audioHandler.skipToPrevious();
                break;
              case "Seek":
                // val to = message.data?.seekPositionTicks?.ticks ?: Duration.ZERO
                final seekPosition = request['Data']['SeekPositionTicks'] != null
                    ? Duration(milliseconds: ((request['Data']['SeekPositionTicks'] as int) / 10000).round())
                    : Duration.zero;
                await _audioHandler.seek(seekPosition);
                break;
              case "Rewind":
                await _audioHandler.rewind();
                break;
              case "FastForward":
                await _audioHandler.fastForward();
                break;
              case "PlayPause":
                await _audioHandler.togglePlayback();
                break;

              // Do nothing
              default:
                switch (request['Data']['PlayCommand']) {
                  case 'PlayNow':
                    if (!(request['Data'].containsKey('StartIndex') as bool)) {
                      request['Data']['StartIndex'] = 0;
                    }
                    var items = await _jellyfinApiHelper.getItems(
                      // sortBy: "IndexNumber", //!!! don't sort, use the sorting provided by the command!
                      includeItemTypes: "Audio",
                      itemIds: List<BaseItemId>.from(request['Data']['ItemIds'] as List<dynamic>),
                    );
                    if (items!.isNotEmpty) {
                      //TODO check if all tracks in the request are in the upcoming queue (peekQueue). If they are, we should try to only reorder the upcoming queue instead of treating it as a new queue, and then skip to the correct index.
                      unawaited(
                        _queueService.startPlayback(
                          items: items,
                          source: QueueItemSource(
                            name: QueueItemSourceName(type: QueueItemSourceNameType.remoteClient),
                            type: QueueItemSourceType.remoteClient,
                            id: items[0].id,
                            item: items[0],
                          ),
                          // seems like Jellyfin isn't always sending the correct index
                          startingIndex: request['Data']['StartIndex'] as int,
                        ),
                      );
                    } else {
                      _playOnServiceLogger.severe("Server asked to start an unplayable item");
                    }
                    break;
                  case 'PlayNext':
                    var items = await _jellyfinApiHelper.getItems(
                      sortBy: "IndexNumber", //!!! don't sort, use the sorting provided by the command!
                      includeItemTypes: "Audio",
                      itemIds: List<BaseItemId>.from(request['Data']['ItemIds'] as List<dynamic>),
                    );
                    unawaited(_queueService.addToNextUp(items: items!));
                    break;
                  case 'PlayLast':
                    var items = await _jellyfinApiHelper.getItems(
                      sortBy: "IndexNumber", //!!! don't sort, use the sorting provided by the command!
                      includeItemTypes: "Audio",
                      itemIds: List<BaseItemId>.from(request['Data']['ItemIds'] as List<dynamic>),
                    );
                    unawaited(_queueService.addToQueue(items: items!));
                    break;
                }
            }
            break;
        }
      }
    } catch (e) {
      _playOnServiceLogger.severe("Error handling message: $e");
    }
  }
}
