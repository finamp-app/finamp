import 'dart:convert';
import 'dart:io';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

/// Used for discovering Jellyfin servers on the local network
/// and for advertising the current server to other clients (discovery emulation).
/// https://jellyfin.org/docs/general/networking/#port-bindings
/// For some reason it's always being referred to as "client discovery" in the Jellyfin docs, even though we're actually discovering servers
class JellyfinServerClientDiscovery {
  static final _clientDiscoveryLogger = Logger("JellyfinServerClientDiscovery");

  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  late RawDatagramSocket _discoverySocket;
  late RawDatagramSocket _advertisingSocket;
  bool isDiscovering = false;
  bool isAdvertising = false;

  static const discoveryMessage =
      "who is JellyfinServer?"; // doesn't seem to be case sensitive, but the Kotlin SDK uses this capitalization
  final broadcastAddress = InternetAddress("255.255.255.255"); // UDP broadcast address
  static const discoveryPort = 7359; // Jellyfin client discovery port

  void discoverServers(void Function(ClientDiscoveryResponse response) onServerFound) async {
    try {
      isDiscovering = true;

      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      // We have to use ? throughout since _discoverySocket isn't final, although at this
      // point in the code it should never be null

      _discoverySocket.broadcastEnabled = true; // important to allow sending to broadcast address
      _discoverySocket.multicastHops = 5; // to account for weird network setups

      _discoverySocket.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = _discoverySocket.receive();
            if (datagram != null) {
              _clientDiscoveryLogger.finest("Received datagram: ${utf8.decode(datagram.data)}");
              final response = ClientDiscoveryResponse.fromJson(
                jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>,
              );
              _clientDiscoveryLogger.fine(
                "Received discovery response from ${datagram.address}:${datagram.port}: ${jsonEncode(response)}",
              );
              onServerFound(response);
            }
          }
        },
        onError: (Object error) {
          _clientDiscoveryLogger.severe("Discovery socket error: $error");
        },
        onDone: () {
          _clientDiscoveryLogger.finest("Discovery socket closed");
        },
      );

      // Send discovery message repeatedly to scan for local servers (because UDP is unreliable)
      do {
        _clientDiscoveryLogger.fine("Sending discovery message");
        _discoverySocket.send(discoveryMessage.codeUnits, broadcastAddress, discoveryPort);
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      } while (isDiscovering);
    } catch (e) {
      _clientDiscoveryLogger.severe("Error during server discovery: $e");
      GlobalSnackbar.error(e);
      stopDiscovery();
      return;
    }
  }

  void advertiseServer() async {
    try {
      if (isAdvertising) {
        _clientDiscoveryLogger.warning("Server is already being advertised, ignoring request");
        return;
      }
      isAdvertising = true;

      _advertisingSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      _advertisingSocket.broadcastEnabled = true; // important to allow sending to broadcast address
      _advertisingSocket.multicastHops = 5; // to account for weird network setups

      _clientDiscoveryLogger.fine("Advertising server on port $discoveryPort");

      _advertisingSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _advertisingSocket.receive();
          if (datagram != null) {
            _clientDiscoveryLogger.finest("Received datagram: ${utf8.decode(datagram.data)}");
            final requestMessage = utf8.decode(datagram.data);
            if (requestMessage.toLowerCase().contains(discoveryMessage.toLowerCase())) {
              _clientDiscoveryLogger.fine("Received discovery message from ${datagram.address}:${datagram.port}");
              // Respond with the server's information
              final responseActiveOrPublicAddress = ClientDiscoveryResponse(
                address: _finampUserHelper.currentUser?.publicAddress ?? _finampUserHelper.currentUser?.baseURL,
                endpointAddress: _finampUserHelper.currentUser?.publicAddress ?? _finampUserHelper.currentUser?.baseURL,
                id: _finampUserHelper.currentUser?.serverId,
                name: "Shared by Finamp",
              );
              final responseMessageActiveOrPublicAddress = jsonEncode(responseActiveOrPublicAddress);
              _clientDiscoveryLogger.finest("Sending discovery response: $responseMessageActiveOrPublicAddress");
              _advertisingSocket.send(
                utf8.encode(responseMessageActiveOrPublicAddress),
                datagram.address,
                datagram.port,
              );
              _clientDiscoveryLogger.fine("Sent discovery response to ${datagram.address}:${datagram.port}");

              if (_finampUserHelper.currentUser?.localAddress != null) {
                final responseLocalAddress = ClientDiscoveryResponse(
                  address: _finampUserHelper.currentUser?.localAddress,
                  endpointAddress: _finampUserHelper.currentUser?.localAddress,
                  id: _finampUserHelper.currentUser?.serverId,
                  name: "Shared by Finamp",
                );
                final responseMessageLocalAddress = jsonEncode(responseLocalAddress);
                _clientDiscoveryLogger.finest(
                  "Sending discovery response for local address: $responseMessageLocalAddress",
                );
                _advertisingSocket.send(utf8.encode(responseMessageLocalAddress), datagram.address, datagram.port);
                _clientDiscoveryLogger.fine("Sent discovery response to ${datagram.address}:${datagram.port}");
              }
            }
          }
        }
      });
    } catch (e) {
      _clientDiscoveryLogger.severe("Error during server sharing: $e");
      GlobalSnackbar.error(e);
      stopAdvertising();
      return;
    }
  }

  void stopDiscovery() {
    if (!isDiscovering) {
      return;
    }
    isDiscovering = false;
    _discoverySocket.close();
    _clientDiscoveryLogger.fine("Stopped server discovery");
  }

  void stopAdvertising() {
    if (!isAdvertising) {
      return;
    }
    isAdvertising = false;
    _advertisingSocket.close();
    _clientDiscoveryLogger.fine("Stopped server advertising");
  }

  void dispose() {
    stopDiscovery();
    stopAdvertising();
  }
}
