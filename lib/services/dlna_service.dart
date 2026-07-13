import 'dart:async';
import 'dart:io';

import 'package:dart_cast/dart_cast.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// A discovered DLNA device that can be used for output.
class DlnaOutputDevice {
  final String name;
  final String id;
  final String address;
  final int port;

  DlnaOutputDevice({
    required this.name,
    required this.id,
    required this.address,
    required this.port,
  });

  @override
  String toString() => 'DlnaOutputDevice(name: $name, address: $address)';
}

/// State of a DLNA playback session.
enum DlnaPlaybackState { stopped, playing, paused, transitioning, unknown }

/// Snapshot of DLNA playback status.
class DlnaPlaybackStatus {
  final DlnaPlaybackState state;
  final Duration position;
  final Duration duration;

  DlnaPlaybackStatus({
    required this.state,
    required this.position,
    required this.duration,
  });
}

/// Service that manages DLNA/UPnP device discovery and playback control.
///
/// Wraps [dart_cast] to provide a simplified API for the rest of the app.
/// Registered in GetIt as a singleton.
///
/// This service uses [CastService] only for device discovery. Session creation
/// is handled manually because [DlnaSession.fromDevice] extracts control URLs
/// from the device metadata populated by [DlnaDiscoveryProvider] during discovery,
/// rather than going through [CastService.connect].
class DlnaService {
  final _logger = Logger("DlnaService");

  /// The underlying cast service, used only for device discovery.
  late final CastService _castService;

  /// HTTP client for sending SOAP commands directly to the DLNA device.
  /// Used for SetAVTransportURI with correct audio protocolInfo, since
  /// dart_cast's DlnaSession.loadMedia() always sends video/mp4.
  final DlnaHttpClient _soapClient = DlnaHttpClient();

  /// Media proxy for serving local files to the DLNA device.
  /// We create and manage this ourselves so we can register files and get
  /// proxy URLs without going through DlnaSession.loadMedia() (which
  /// sends wrong video/mp4 protocolInfo).
  final MediaProxy _mediaProxy = MediaProxy();

  /// The active DLNA session, or null when disconnected.
  CastSession? _session;

  /// The currently connected device info, or null when disconnected.
  DlnaOutputDevice? _connectedDevice;

  /// Stream controller for the current playback status (position, state, duration).
  final _statusController = StreamController<DlnaPlaybackStatus>.broadcast();

  /// Stream controller for the currently connected device.
  final _deviceController = StreamController<DlnaOutputDevice?>.broadcast();

  /// Timer for polling DLNA playback position.
  Timer? _pollTimer;

  /// Timestamp when playback started, used to avoid false STOPPED detection
  /// during the first few seconds after loading (device may briefly report
  /// STOPPED before transitioning to PLAYING).
  DateTime? _playbackStartTime;

  /// Active stream subscriptions from the session, cancelled on disconnect.
  final List<StreamSubscription> _sessionSubscriptions = [];

  /// Active discovery stream subscriptions, cancelled on stopDiscovery.
  final List<StreamSubscription> _discoverySubs = [];

  DlnaService() {
    // Only set discoveryProviders — we don't use castService.connect(),
    // so sessionFactory is not needed.
    _castService = CastService(
      discoveryProviders: [DlnaDiscoveryProvider()],
    );
  }

  /// Stream of playback status updates (position, state, duration).
  Stream<DlnaPlaybackStatus> get statusStream => _statusController.stream;

  /// Stream of the currently connected device (null when disconnected).
  Stream<DlnaOutputDevice?> get deviceStream => _deviceController.stream;

  /// The currently connected device, or null.
  DlnaOutputDevice? get connectedDevice => _connectedDevice;

  /// Whether a DLNA device is currently connected.
  bool get isConnected => _session != null && _connectedDevice != null;

  /// Whether a DLNA device is currently playing.
  bool get isPlaying {
    final session = _session;
    if (session == null) return false;
    return session.state == SessionState.playing;
  }

  /// Start a combined discovery stream using both SSDP and mDNS.
  ///
  /// SSDP (via [CastService]) finds standard DLNA devices that advertise
  /// via multicast. mDNS (via `_raop._tcp.local`) finds devices like the
  /// Up2Stream PRO that advertise AirPlay/RAOP but not SSDP — we then
  /// fetch their DLNA description.xml to get the control URLs.
  ///
  /// [timeout] controls how long discovery runs before the stream closes.
  Stream<List<CastDevice>> startDiscoveryStream({
    Duration timeout = const Duration(seconds: 15),
  }) {
    final controller = StreamController<List<CastDevice>>.broadcast();
    final devices = <String, CastDevice>{};

    void emit() {
      if (!controller.isClosed) {
        controller.add(devices.values.toList());
      }
    }

    // 1. SSDP discovery via CastService
    final ssdpSub = _castService.startDiscovery(timeout: timeout).listen(
      (found) {
        for (final device in found) {
          devices[device.id] = device;
        }
        emit();
      },
      onError: (e) => _logger.warning("SSDP discovery error: $e"),
      onDone: () {
        // Don't close controller yet — mDNS might still be running
      },
    );

    // 2. mDNS discovery for _raop._tcp.local (AirPlay audio devices
    //    that also have a DLNA control endpoint)
    _discoverViaMdns(
      serviceType: '_raop._tcp.local',
      timeout: timeout,
      onDevice: (device) {
        devices[device.id] = device;
        emit();
      },
      onDone: () {
        // Both discovery streams are done
        _discoverySubs.remove(ssdpSub);
        ssdpSub.cancel();
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    _discoverySubs.add(ssdpSub);
    return controller.stream;
  }

  /// Stop an active discovery scan.
  void stopDiscovery() {
    _castService.stopDiscovery();
    for (final sub in _discoverySubs) {
      sub.cancel();
    }
    _discoverySubs.clear();
  }

  /// mDNS discovery for DLNA renderers that advertise via RAOP/AirPlay.
  ///
  /// Queries [serviceType] (e.g. `_raop._tcp.local`), resolves each found
  /// service to an IP address, then fetches `http://{ip}:49152/description.xml`
  /// to extract DLNA control URLs. Tries common UPnP ports.
  Future<void> _discoverViaMdns({
    required String serviceType,
    required Duration timeout,
    required void Function(CastDevice device) onDevice,
    required void Function() onDone,
  }) async {
    final client = MDnsClient();
    try {
      await client.start();
    } catch (e) {
      _logger.warning("mDNS client failed to start: $e");
      onDone();
      return;
    }

    try {
      final seen = <String>{};

      // Send multiple rounds of queries (devices may not respond to first)
      for (int round = 0; round < 3; round++) {
        if (round > 0) {
          await Future.delayed(const Duration(seconds: 2));
        }

        await for (final PtrResourceRecord ptr
            in client.lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(serviceType),
            )) {
          if (seen.contains(ptr.domainName)) continue;
          seen.add(ptr.domainName);

          // Resolve SRV record to get host + port
          await for (final SrvResourceRecord srv
              in client.lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              ).timeout(
                const Duration(seconds: 3),
                onTimeout: (sink) => sink.close(),
              )) {
            // Resolve A record to get IP
            await for (final IPAddressResourceRecord ip
                in client.lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target),
                ).timeout(
                  const Duration(seconds: 3),
                  onTimeout: (sink) => sink.close(),
                )) {
              final addressStr = ip.address.address;
              _logger.fine("mDNS found: ${ptr.domainName} at $addressStr");

              // Fetch DLNA description from the device
              final device = await _fetchDlnaDescription(addressStr);
              if (device != null) {
                onDevice(device);
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.warning("mDNS discovery error: $e");
    } finally {
      client.stop();
      onDone();
    }
  }

  /// Fetch the DLNA device description from `http://{address}:{port}/description.xml`.
  /// Tries common UPnP ports. Returns a [CastDevice] if a MediaRenderer is found.
  Future<CastDevice?> _fetchDlnaDescription(String address) async {
    final ports = [49152, 49153, 49154, 80, 8080, 8200, 50000];
    for (final port in ports) {
      final url = 'http://$address:$port/description.xml';
      try {
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 5),
        );
        if (response.statusCode == 200 &&
            response.body.contains('MediaRenderer')) {
          final description =
              DlnaDeviceDescription.parse(response.body, url);
          final device = description.toCastDevice();
          _logger.info("Found DLNA device via mDNS: ${device.name} at $address:$port");
          return device;
        }
      } catch (_) {
        // Port not open or not a DLNA device — try next port
      }
    }
    return null;
  }

  /// Connect to a DLNA device and prepare it for playback.
  ///
  /// Returns true on success, false on failure.
  ///
  /// This method creates the [DlnaSession] manually using
  /// [DlnaSession.fromDevice], which extracts control URLs from the device
  /// metadata that [DlnaDiscoveryProvider] populated during discovery.
  Future<bool> connect(CastDevice device) async {
    try {
      _logger.info("Connecting to DLNA device: ${device.name}");

      // Disconnect any existing session first
      if (_session != null) {
        await disconnect();
      }

      // Create the DLNA session. We use the regular constructor (not
      // DlnaSession.fromDevice) so we can inject a custom MediaTransformer
      // that bypasses the proxy for remote URLs. This avoids network
      // reachability issues where the proxy binds to an IP the DLNA device
      // can't reach (e.g. Docker container IP, VPN adapter).
      final description = DlnaDeviceDescription(
        friendlyName: device.name,
        udn: device.id,
        manufacturer: device.metadata['manufacturer'],
        modelName: device.metadata['modelName'],
        avTransportControlUrl: device.metadata['avTransportControlUrl'],
        renderingControlUrl: device.metadata['renderingControlUrl'],
        connectionManagerControlUrl: device.metadata['connectionManagerControlUrl'],
        locationUrl: 'http://${device.address.address}:${device.port}',
      );
      final session = DlnaSession(
        device: device,
        description: description,
        proxy: _mediaProxy,
        mediaTransformer: const _DirectUrlTransformer(),
      );

      // Run the session's connect handshake to transition state machine
      // from disconnected -> connecting -> connected.
      await session.connect();

      _session = session;
      _connectedDevice = DlnaOutputDevice(
        name: device.name,
        id: device.id,
        address: device.address.address,
        port: device.port,
      );
      _deviceController.add(_connectedDevice);

      // Listen to session state changes
      _sessionSubscriptions.add(session.stateStream.listen((state) {
        _logger.fine("DLNA session state: $state");
        _emitStatus();
      }));

      // Listen to position updates from the device
      _sessionSubscriptions.add(session.positionStream.listen((_) {
        _emitStatus();
      }));

      // Listen to duration updates from the device
      _sessionSubscriptions.add(session.durationStream.listen((_) {
        _emitStatus();
      }));

      _logger.info("Connected to DLNA device: ${device.name}");
      return true;
    } catch (e) {
      _logger.severe("Failed to connect to DLNA device: $e");
      _session = null;
      _connectedDevice = null;
      _deviceController.add(null);
      return false;
    }
  }

  /// Connect to a DLNA device by its IP address, bypassing SSDP discovery.
  ///
  /// Fetches the device description XML from `http://{address}:{port}/description.xml`
  /// and parses it to extract the control URLs needed for SOAP commands.
  /// This is useful for devices that don't respond to SSDP multicast.
  ///
  /// [port] defaults to 49152, the most common UPnP port. Try common ports
  /// (49152, 49153, 49154, 80, 8080, 8200) if the default doesn't work.
  Future<CastDevice?> discoverDeviceByAddress(
    String address, {
    int port = 49152,
  }) async {
    final ports = [port, 49152, 49153, 49154, 80, 8080, 8200];
    for (final p in ports.toSet()) {
      final descriptionUrl = 'http://$address:$p/description.xml';
      try {
        _logger.info("Fetching DLNA device description from $descriptionUrl");
        final response = await http.get(Uri.parse(descriptionUrl)).timeout(
          const Duration(seconds: 5),
        );
        if (response.statusCode == 200 && response.body.contains('MediaRenderer')) {
          final description = DlnaDeviceDescription.parse(response.body, descriptionUrl);
          final device = description.toCastDevice();
          _logger.info("Found DLNA device: ${device.name} at $address:$p");
          return device;
        }
      } catch (e) {
        _logger.fine("No DLNA device at $address:$p: $e");
      }
    }
    _logger.warning("No DLNA device found at $address");
    return null;
  }

  /// Connect to a DLNA device by its IP address, bypassing SSDP discovery.
  ///
  /// Returns true on success, false on failure.
  Future<bool> connectByAddress(String address, {int port = 49152}) async {
    final device = await discoverDeviceByAddress(address, port: port);
    if (device == null) return false;
    return connect(device);
  }

  /// Load media onto the connected DLNA device and start playback.
  ///
  /// If [filePath] is provided, the file is served via the HTTP proxy so the
  /// DLNA device can access it.  Otherwise, [url] must be provided — the DLNA
  /// device fetches it directly.
  ///
  /// [mimeType] is the MIME type of the audio (e.g. "audio/mpeg", "audio/flac").
  /// If not provided, it is inferred from the file extension or defaults to
  /// "audio/mpeg".
  ///
  /// We bypass `DlnaSession.loadMedia()` entirely (it always sends
  /// `video/mp4` protocolInfo and fires `SetAVTransportURI` + `Play` in
  /// rapid succession which overwhelms the device). Instead we:
  ///   1. Send `SetAVTransportURI` with correct audio `protocolInfo` and
  ///      `object.item.audioItem.musicTrack` DIDL-Lite class via our own
  ///      SOAP client.
  ///   2. Wait briefly for the device to process the URI.
  ///   3. Send `Play` via our own SOAP client.
  ///   4. Force the session state machine to `playing`.
  ///   5. Start our own position polling (since `DlnaSession._startPolling`
  ///      is private and only called from `loadMedia()`).
  Future<bool> loadMedia({
    String? url,
    String? filePath,
    String? title,
    String? imageUrl,
    Duration? startPosition,
    String? mimeType,
  }) async {
    final session = _session;
    if (session == null) {
      _logger.warning("Cannot load media: no DLNA session");
      return false;
    }

    try {
      _logger.info("Loading media on DLNA device: ${filePath ?? url}");

      final String mediaUrl;
      final String effectiveMime;

      // Always start the proxy — even for remote URLs, we proxy through
      // the app so the DLNA device doesn't need to reach the Jellyfin
      // server directly. This is essential when the phone and DLNA device
      // are on the same network but the Jellyfin server is on a different
      // network, or when the Jellyfin URL uses a hostname the device can't
      // resolve.
      await _mediaProxy.start(
        targetDeviceIp: _connectedDevice?.address,
      );

      if (filePath != null) {
        // Local downloaded file — serve via proxy.
        effectiveMime = mimeType ?? _mimeTypeFromFilePath(filePath);
        mediaUrl = _mediaProxy.registerFile(filePath);
      } else {
        // Remote URL (e.g. Jellyfin direct-play URL) — proxy through the
        // app so the DLNA device fetches from the phone, not from Jellyfin.
        effectiveMime = mimeType ?? "audio/mpeg";
        final ext = _extensionFromMime(effectiveMime);
        mediaUrl = _mediaProxy.registerMedia(
          url!,
          pathExtension: ext,
        );
      }

      final dlnaSession = session as DlnaSession;
      final controlUrl = dlnaSession.description.avTransportControlUrl;
      if (controlUrl == null) {
        _logger.severe("No AVTransport control URL available");
        return false;
      }

      // Step 1: Send SetAVTransportURI with correct audio protocolInfo.
      final protocolInfo = _audioProtocolInfo(effectiveMime);
      _logger.info("DLNA: SetAVTransportURI protocolInfo=$protocolInfo");

      // Transition state to loading for UI feedback.
      dlnaSession.stateMachine.forceState(SessionState.loading);

      final soapBody = _buildSetAVTransportURISoap(
        url: mediaUrl,
        title: title ?? "Finamp",
        protocolInfo: protocolInfo,
      );

      await _soapClient.sendAction(
        controlUrl,
        DlnaServiceType.avTransport,
        'SetAVTransportURI',
        soapBody,
      );

      // Step 2: Wait briefly for the device to process the URI before
      // sending Play. The device needs time to fetch the content.
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: Send Play.
      await _soapClient.sendAction(
        controlUrl,
        DlnaServiceType.avTransport,
        'Play',
        DlnaSoapBuilder.buildPlay(),
      );

      // Step 4: Force state to playing.
      dlnaSession.stateMachine.forceState(SessionState.playing);
      _playbackStartTime = DateTime.now();

      // Step 5: Start our own polling.
      _startPolling();

      // Handle start position via seek if provided.
      if (startPosition != null && startPosition > Duration.zero) {
        await Future.delayed(const Duration(seconds: 1));
        await session.seek(startPosition);
      }

      _emitStatus();
      return true;
    } catch (e) {
      _logger.severe("Failed to load media on DLNA device: $e");
      return false;
    }
  }

  /// Build DLNA protocolInfo string for an audio MIME type.
  ///
  /// Example: "audio/mpeg" → "http-get:*:audio/mpeg:DLNA.ORG_PN=MP3;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000"
  String _audioProtocolInfo(String mimeType) {
    const dlnaFlags = '01700000000000000000000000000000';
    // Map common audio MIME types to their DLNA profile names.
    // If no specific PN exists, omit it and use a generic protocolInfo.
    final pn = switch (mimeType) {
      'audio/mpeg' => 'DLNA.ORG_PN=MP3',
      'audio/x-ms-wma' => 'DLNA.ORG_PN=WMABASE',
      'audio/vnd.dlna.adts' => 'DLNA.ORG_PN=AAC_ADTS',
      'audio/mp4' || 'audio/m4a' || 'audio/aac' => 'DLNA.ORG_PN=AAC_ISO',
      'audio/wav' || 'audio/x-wav' => 'DLNA.ORG_PN=LPCM',
      'audio/flac' || 'audio/ogg' || 'audio/ape' || 'audio/x-ape' ||
      'audio/ac3' => null, // No standard DLNA PN, use generic
      _ => null,
    };

    if (pn != null) {
      return 'http-get:*:$mimeType:$pn;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=$dlnaFlags';
    }
    return 'http-get:*:$mimeType:DLNA.ORG_OP=01;DLNA.ORG_FLAGS=$dlnaFlags';
  }

  /// Build a complete SetAVTransportURI SOAP envelope with audio DIDL-Lite.
  ///
  /// Unlike [DlnaSoapBuilder.buildSetAVTransportURI] which hardcodes
  /// `object.item.videoItem`, this uses `object.item.audioItem.musicTrack`
  /// which is the correct UPnP class for audio tracks.
  String _buildSetAVTransportURISoap({
    required String url,
    required String title,
    required String protocolInfo,
  }) {
    final escapedTitle = _escapeXml(title);
    final escapedUrl = _escapeXml(url);

    // Build DIDL-Lite metadata for an audio music track.
    final didlLite =
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"'
        ' xmlns:dc="http://purl.org/dc/elements/1.1/"'
        ' xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="0" parentID="0" restricted="1">'
        '<dc:title>$escapedTitle</dc:title>'
        '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
        '<res protocolInfo="$protocolInfo">$escapedUrl</res>'
        '</item>'
        '</DIDL-Lite>';

    final escapedDidl = _escapeXml(didlLite);

    return '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"'
        ' s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:SetAVTransportURI xmlns:u="${DlnaServiceType.avTransport}">'
        '<InstanceID>0</InstanceID>'
        '<CurrentURI>$escapedUrl</CurrentURI>'
        '<CurrentURIMetaData>$escapedDidl</CurrentURIMetaData>'
        '</u:SetAVTransportURI>'
        '</s:Body>'
        '</s:Envelope>';
  }

  /// Infer MIME type from a file path/extension.
  String _mimeTypeFromFilePath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return switch (ext) {
      'mp3' => 'audio/mpeg',
      'flac' => 'audio/flac',
      'wav' => 'audio/wav',
      'm4a' => 'audio/m4a',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      'wma' => 'audio/x-ms-wma',
      'ape' => 'audio/ape',
      'ac3' => 'audio/ac3',
      _ => 'audio/mpeg', // default to MP3
    };
  }

  /// Get a file extension for a MIME type, used for the proxy URL path
  /// so DLNA devices that rely on file extensions can detect the format.
  String? _extensionFromMime(String mimeType) {
    return switch (mimeType) {
      'audio/mpeg' => 'mp3',
      'audio/flac' => 'flac',
      'audio/wav' || 'audio/x-wav' => 'wav',
      'audio/m4a' => 'm4a',
      'audio/aac' => 'aac',
      'audio/ogg' => 'ogg',
      'audio/x-ms-wma' => 'wma',
      'audio/ape' || 'audio/x-ape' => 'ape',
      'audio/ac3' => 'ac3',
      'audio/vnd.dlna.adts' => 'adts',
      _ => null,
    };
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Resume playback on the DLNA device.
  Future<void> play() async {
    final session = _session;
    if (session == null) return;
    try {
      await session.play();
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA play failed: $e");
    }
  }

  /// Pause playback on the DLNA device.
  Future<void> pause() async {
    final session = _session;
    if (session == null) return;
    try {
      await session.pause();
      _stopPolling();
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA pause failed: $e");
    }
  }

  /// Stop playback on the DLNA device.
  Future<void> stop() async {
    final session = _session;
    if (session == null) return;
    try {
      await session.stop();
      _stopPolling();
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA stop failed: $e");
    }
  }

  /// Seek to a position on the DLNA device.
  Future<void> seek(Duration position) async {
    final session = _session;
    if (session == null) return;
    try {
      await session.seek(position);
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA seek failed: $e");
    }
  }

  /// Get the current playback position.
  Duration get position => _session?.position ?? Duration.zero;

  /// Get the media duration.
  Duration get duration => _session?.duration ?? Duration.zero;

  /// Get the current session state mapped to [DlnaPlaybackState].
  DlnaPlaybackState get playbackState {
    final session = _session;
    if (session == null) return DlnaPlaybackState.stopped;
    switch (session.state) {
      case SessionState.playing:
        return DlnaPlaybackState.playing;
      case SessionState.paused:
        return DlnaPlaybackState.paused;
      case SessionState.connecting:
      case SessionState.connected:
      case SessionState.loading:
      case SessionState.buffering:
        return DlnaPlaybackState.transitioning;
      case SessionState.idle:
      case SessionState.disconnected:
        return DlnaPlaybackState.stopped;
    }
  }

  /// Disconnect from the DLNA device and clean up resources.
  Future<void> disconnect() async {
    _stopPolling();

    // Cancel all session stream subscriptions
    await Future.wait(_sessionSubscriptions.map((sub) => sub.cancel()));
    _sessionSubscriptions.clear();

    final session = _session;
    if (session != null) {
      try {
        await session.stop();
        await session.disconnect();
      } catch (e) {
        _logger.warning("Error during DLNA disconnect: $e");
      }
    }

    _session = null;
    _connectedDevice = null;
    await _mediaProxy.stop();
    _deviceController.add(null);
    _statusController.add(DlnaPlaybackStatus(
      state: DlnaPlaybackState.stopped,
      position: Duration.zero,
      duration: Duration.zero,
    ));
    _logger.info("Disconnected from DLNA device");
  }

  /// Start periodic polling of DLNA playback status.
  ///
  /// Since we bypass `DlnaSession.loadMedia()` (which starts the session's
  /// internal polling), we need our own polling to update position/duration
  /// and detect when the track ends (device transitions to STOPPED).
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _pollDevice();
    });
  }

  Future<void> _pollDevice() async {
    final session = _session;
    if (session == null) return;
    final dlnaSession = session as DlnaSession;
    final controlUrl = dlnaSession.description.avTransportControlUrl;
    if (controlUrl == null) return;

    try {
      // Get position info
      final posResponse = await _soapClient.sendAction(
        controlUrl,
        DlnaServiceType.avTransport,
        'GetPositionInfo',
        DlnaSoapBuilder.buildGetPositionInfo(),
      );
      final posInfo = DlnaSoapParser.parsePositionInfo(posResponse);
      dlnaSession.updatePosition(posInfo.position);
      if (posInfo.duration > Duration.zero) {
        dlnaSession.updateDuration(posInfo.duration);
      }

      // Get transport info to detect state changes
      final transportResponse = await _soapClient.sendAction(
        controlUrl,
        DlnaServiceType.avTransport,
        'GetTransportInfo',
        DlnaSoapBuilder.buildGetTransportInfo(),
      );
      final transportState = DlnaSoapParser.parseTransportInfo(transportResponse);

      // If device reports STOPPED while we think we're playing, the track
      // ended. But don't do this during the first few seconds after loading
      // — the device may briefly report STOPPED before transitioning to
      // PLAYING.
      if (transportState == 'STOPPED' &&
          dlnaSession.state == SessionState.playing &&
          _playbackStartTime != null &&
          DateTime.now().difference(_playbackStartTime!) >
              const Duration(seconds: 5)) {
        dlnaSession.stateMachine.forceState(SessionState.idle);
        _stopPolling();
      }
    } catch (e) {
      _logger.fine("DLNA polling failed: $e");
    }

    _emitStatus();
  }

  /// Stop polling.
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Emit a status update to listeners.
  void _emitStatus() {
    final session = _session;
    if (session == null) return;

    _statusController.add(DlnaPlaybackStatus(
      state: playbackState,
      position: session.position,
      duration: session.duration,
    ));
  }

  /// Dispose all resources. Call this when the service is no longer needed.
  void dispose() {
    _stopPolling();
    for (final sub in _sessionSubscriptions) {
      unawaited(sub.cancel());
    }
    _sessionSubscriptions.clear();
    for (final sub in _discoverySubs) {
      unawaited(sub.cancel());
    }
    _discoverySubs.clear();
    _soapClient.close();
    unawaited(_mediaProxy.stop());
    unawaited(_castService.dispose());
    _statusController.close();
    _deviceController.close();
  }
}

/// A [MediaTransformer] that passes remote URLs directly to the DLNA device
/// without routing them through [MediaProxy].
///
/// For local files (file:// paths), it still registers with the proxy since
/// the DLNA device can't access the filesystem directly.
///
/// This avoids network reachability issues where the proxy binds to an IP
/// that the DLNA device can't reach (e.g. Docker container IP, VPN adapter).
class _DirectUrlTransformer implements MediaTransformer {
  const _DirectUrlTransformer();

  @override
  Future<TransformedMedia> transform(CastMedia media, MediaProxy proxy) async {
    if (media.isLocalFile) {
      // Local files must go through the proxy — the DLNA device can't
      // access the local filesystem.
      final proxyUrl = proxy.registerFile(media.url);
      return TransformedMedia(proxyUrl: proxyUrl, effectiveType: media.type);
    }

    // Remote URLs: pass directly to the DLNA device, no proxy needed.
    // The DLNA device fetches the URL itself.
    return TransformedMedia(proxyUrl: media.url, effectiveType: media.type);
  }
}
