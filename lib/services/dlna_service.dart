import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:upnp_client/upnp_client.dart' as upnp;
import 'package:xml/xml.dart' as xml;

import 'dlna_media_proxy.dart';

/// A discovered DLNA device that can be used for output.
class DlnaOutputDevice {
  final String name;
  final String id;
  final String address;
  final int port;

  /// The location URL (description.xml endpoint) of the device.
  /// Used to re-fetch the device description for [DlnaService.connect].
  final String locationUrl;

  DlnaOutputDevice({
    required this.name,
    required this.id,
    required this.address,
    required this.port,
    required this.locationUrl,
  });

  @override
  bool operator ==(Object other) => identical(this, other) || other is DlnaOutputDevice && id == other.id;

  @override
  int get hashCode => id.hashCode;

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

  DlnaPlaybackStatus({required this.state, required this.position, required this.duration});
}

/// Service that manages DLNA/UPnP device discovery and playback control.
///
/// Uses [upnp.UpnpClient] (the `upnp_client` package) for SOAP/UPnP control
/// and a custom [DlnaMediaProxy] for serving media with DLNA content-feature
/// headers. Registered in GetIt as a singleton.
class DlnaService {
  final _logger = Logger("DlnaService");

  /// The media proxy that serves files/streams to the DLNA device with
  /// correct DLNA content-feature headers.
  final DlnaMediaProxy _mediaProxy = DlnaMediaProxy();

  /// The connected upnp_client device, or null when disconnected.
  upnp.Device? _device;

  /// The AVTransport service of the connected device.
  upnp.AvTransportService? _avTransport;

  /// The RenderingControl service of the connected device.
  upnp.RenderingControlService? _renderingControl;

  /// The currently connected device info, or null when disconnected.
  DlnaOutputDevice? _connectedDevice;

  /// Stream controller for the current playback status.
  final _statusController = StreamController<DlnaPlaybackStatus>.broadcast();

  /// Stream controller for the currently connected device.
  final _deviceController = StreamController<DlnaOutputDevice?>.broadcast();

  /// Timer for polling DLNA playback position.
  Timer? _pollTimer;

  /// Timestamp when playback started, used to avoid false STOPPED detection
  /// during the first few seconds after loading.
  DateTime? _playbackStartTime;

  /// Current cached playback state.
  DlnaPlaybackState _playbackState = DlnaPlaybackState.stopped;

  /// Current cached position.
  Duration _position = Duration.zero;

  /// Current cached duration.
  Duration _duration = Duration.zero;

  /// Active discovery stream subscriptions, cancelled on stopDiscovery.
  final List<StreamSubscription<dynamic>> _discoverySubs = [];

  // ── Public API ──────────────────────────────────────────────────

  /// Stream of playback status updates (position, state, duration).
  Stream<DlnaPlaybackStatus> get statusStream => _statusController.stream;

  /// Stream of the currently connected device (null when disconnected).
  Stream<DlnaOutputDevice?> get deviceStream => _deviceController.stream;

  /// The currently connected device, or null.
  DlnaOutputDevice? get connectedDevice => _connectedDevice;

  /// Whether a DLNA device is currently connected.
  bool get isConnected => _device != null && _connectedDevice != null;

  /// Whether a DLNA device is currently playing.
  bool get isPlaying => _playbackState == DlnaPlaybackState.playing;

  /// Get the current playback position.
  Duration get position => _position;

  /// Get the media duration.
  Duration get duration => _duration;

  /// Get the current playback state.
  DlnaPlaybackState get playbackState => _playbackState;

  // ── Discovery ────────────────────────────────────────────────────

  /// Start a combined discovery stream using both SSDP and mDNS.
  ///
  /// SSDP (via [upnp.DeviceDiscoverer]) finds standard DLNA devices that
  /// advertise via multicast. mDNS (via `_raop._tcp.local`) finds devices
  /// like the Up2Stream PRO that advertise AirPlay/RAOP but not SSDP — we
  /// then fetch their DLNA description.xml to get the control URLs.
  ///
  /// [timeout] controls how long discovery runs before the stream closes.
  Stream<List<DlnaOutputDevice>> startDiscoveryStream({Duration timeout = const Duration(seconds: 15)}) {
    final controller = StreamController<List<DlnaOutputDevice>>.broadcast();
    final devices = <String, DlnaOutputDevice>{};

    void emit() {
      if (!controller.isClosed) {
        controller.add(devices.values.toList());
      }
    }

    // 1. SSDP discovery via upnp_client
    final discoverer = upnp.DeviceDiscoverer();
    final ssdpSub = discoverer.devices.listen(
      (device) {
        // Only care about MediaRenderer devices.
        if (device.description?.deviceType?.contains('MediaRenderer') != true) {
          return;
        }
        final id = device.description?.uuid ?? device.url ?? '';
        if (id.isEmpty) return;

        final uri = Uri.parse(device.url!);
        final dlnaDevice = DlnaOutputDevice(
          name: device.description?.friendlyName ?? 'Unknown',
          id: id,
          address: uri.host,
          port: uri.port,
          locationUrl: device.url!,
        );
        devices[dlnaDevice.id] = dlnaDevice;
        emit();
      },
      onError: (Object e) => _logger.warning("SSDP discovery error: $e"),
      onDone: () {
        // Don't close controller yet — mDNS might still be running
      },
    );

    // Start the SSDP search — must call start() first to create the
    // UDP sockets, then getDevices() to send M-SEARCH packets.
    // Use the MediaRenderer-specific search target so devices like
    // Samsung TVs respond (they may not answer to upnp:rootdevice).
    discoverer
        .start(addressTypes: [InternetAddressType.IPv4])
        .then(
          (_) => discoverer.getDevices(timeout: timeout, searchTarget: 'urn:schemas-upnp-org:device:MediaRenderer:1'),
        )
        .catchError((Object e) {
          _logger.warning("SSDP search error: $e");
          return <upnp.Device>[];
        })
        .whenComplete(() {
          ssdpSub.cancel();
          discoverer.dispose();
        });

    _discoverySubs.add(ssdpSub);

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
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    return controller.stream;
  }

  /// Stop an active discovery scan.
  void stopDiscovery() {
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
    required void Function(DlnaOutputDevice device) onDevice,
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
          await Future<void>.delayed(const Duration(seconds: 2));
        }

        await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(serviceType),
        )) {
          if (seen.contains(ptr.domainName)) continue;
          seen.add(ptr.domainName);

          // Resolve SRV record to get host + port
          await for (final SrvResourceRecord srv
              in client
                  .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
                  .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
            // Resolve A record to get IP
            await for (final IPAddressResourceRecord ip
                in client
                    .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
                    .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
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
  /// Tries common UPnP ports. Returns a [DlnaOutputDevice] if a MediaRenderer is found.
  Future<DlnaOutputDevice?> _fetchDlnaDescription(String address) async {
    final ports = [49152, 49153, 49154, 80, 8080, 8200, 50000];
    for (final port in ports) {
      final url = 'http://$address:$port/description.xml';
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.body.contains('MediaRenderer')) {
          final device = _parseDeviceDescription(response.body, url, address, port);
          if (device != null) {
            _logger.info("Found DLNA device via mDNS: ${device.name} at $address:$port");
            return device;
          }
        }
      } catch (_) {
        // Port not open or not a DLNA device — try next port
      }
    }
    return null;
  }

  /// Parse a device description XML and extract the friendly name and UDN.
  DlnaOutputDevice? _parseDeviceDescription(String xmlBody, String locationUrl, String address, int port) {
    try {
      final doc = xml.XmlDocument.parse(xmlBody);
      final root = doc.rootElement;
      final deviceEl = root.getElement('device');
      if (deviceEl == null) return null;

      final friendlyName = deviceEl.getElement('friendlyName')?.innerText ?? 'Unknown';
      final udn = deviceEl.getElement('UDN')?.innerText ?? locationUrl;
      final id = udn.startsWith('uuid:') ? udn.substring(5) : udn;

      return DlnaOutputDevice(name: friendlyName, id: id, address: address, port: port, locationUrl: locationUrl);
    } catch (e) {
      _logger.warning("Failed to parse device description: $e");
      return null;
    }
  }

  // ── Connection ──────────────────────────────────────────────────

  /// Connect to a DLNA device and prepare it for playback.
  ///
  /// Fetches the device description XML from the device's location URL,
  /// parses it into an [upnp.Device], and extracts the AVTransport and
  /// RenderingControl services.
  ///
  /// Returns true on success, false on failure.
  Future<bool> connect(DlnaOutputDevice device) async {
    try {
      _logger.info("Connecting to DLNA device: ${device.name}");

      // Disconnect any existing session first
      if (_device != null) {
        await disconnect();
      }

      // Fetch and parse the device description XML
      final response = await http.get(Uri.parse(device.locationUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _logger.severe("Failed to fetch device description: ${response.statusCode}");
        return false;
      }

      final doc = xml.XmlDocument.parse(response.body);
      final deviceEl = doc.rootElement.getElement('device');
      if (deviceEl == null) {
        _logger.severe("No <device> element in description XML");
        return false;
      }

      final upnpDevice = upnp.Device.fromXml(deviceEl, device.locationUrl);

      // Verify it has the services we need
      final avTransport = upnpDevice.avTransportService();
      if (avTransport == null) {
        _logger.severe("Device has no AVTransport service");
        return false;
      }
      final renderingControl = upnpDevice.renderingControlService();

      _device = upnpDevice;
      _avTransport = avTransport;
      _renderingControl = renderingControl;
      _connectedDevice = device;
      _playbackState = DlnaPlaybackState.stopped;
      _position = Duration.zero;
      _duration = Duration.zero;

      _deviceController.add(_connectedDevice);
      _logger.info("Connected to DLNA device: ${device.name}");
      return true;
    } catch (e) {
      _logger.severe("Failed to connect to DLNA device: $e");
      _device = null;
      _avTransport = null;
      _renderingControl = null;
      _connectedDevice = null;
      _deviceController.add(null);
      return false;
    }
  }

  /// Discover a DLNA device by its IP address, bypassing SSDP/mDNS discovery.
  ///
  /// Fetches the device description XML from `http://{address}:{port}/description.xml`
  /// and parses it to extract the device info.
  ///
  /// [port] defaults to 49152, the most common UPnP port. Common ports
  /// (49152, 49153, 49154, 80, 8080, 8200) are tried if the default fails.
  Future<DlnaOutputDevice?> discoverDeviceByAddress(String address, {int port = 49152}) async {
    final ports = [port, 49152, 49153, 49154, 80, 8080, 8200];
    for (final p in ports.toSet()) {
      final descriptionUrl = 'http://$address:$p/description.xml';
      try {
        _logger.info("Fetching DLNA device description from $descriptionUrl");
        final response = await http.get(Uri.parse(descriptionUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.body.contains('MediaRenderer')) {
          final device = _parseDeviceDescription(response.body, descriptionUrl, address, p);
          if (device != null) {
            _logger.info("Found DLNA device: ${device.name} at $address:$p");
            return device;
          }
        }
      } catch (e) {
        _logger.fine("No DLNA device at $address:$p: $e");
      }
    }
    _logger.warning("No DLNA device found at $address");
    return null;
  }

  // ── Media loading ───────────────────────────────────────────────

  /// Load media onto the connected DLNA device and start playback.
  ///
  /// If [filePath] is provided, the file is served via the HTTP proxy so the
  /// DLNA device can access it. Otherwise, [url] must be provided — the URL
  /// is proxied through the app so the DLNA device fetches from the phone.
  ///
  /// [mimeType] is the MIME type of the audio (e.g. "audio/mpeg", "audio/flac").
  /// If not provided, it is inferred from the file extension or defaults to
  /// "audio/mpeg".
  Future<bool> loadMedia({
    String? url,
    String? filePath,
    String? title,
    String? imageUrl,
    Duration? startPosition,
    String? mimeType,
  }) async {
    final avTransport = _avTransport;
    if (avTransport == null) {
      _logger.warning("Cannot load media: no DLNA connection");
      return false;
    }

    try {
      _logger.info("Loading media on DLNA device: ${filePath ?? url}");

      final String mediaUrl;
      final String effectiveMime;

      // Always start the proxy — even for remote URLs, we proxy through
      // the app so the DLNA device doesn't need to reach the Jellyfin
      // server directly.
      await _mediaProxy.start(targetDeviceIp: _connectedDevice?.address);

      if (filePath != null) {
        effectiveMime = mimeType ?? _mimeTypeFromFilePath(filePath);
        mediaUrl = _mediaProxy.registerFile(filePath, mimeType: effectiveMime);
      } else {
        effectiveMime = mimeType ?? "audio/mpeg";
        mediaUrl = _mediaProxy.registerUrl(url!, mimeType: effectiveMime);
      }

      // Build DIDL-Lite metadata with correct audio protocolInfo.
      final protocolInfo = _audioProtocolInfo(effectiveMime);
      final didlLite = _buildDidlLite(url: mediaUrl, title: title ?? "Finamp", protocolInfo: protocolInfo);

      _logger.info("DLNA: SetAVTransportURI protocolInfo=$protocolInfo");

      _playbackState = DlnaPlaybackState.transitioning;
      _emitStatus();

      // Send SetAVTransportURI
      await avTransport.setAVTransportURI(mediaUrl, metadata: didlLite);

      // Wait briefly for the device to process the URI before sending Play.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Send Play
      await avTransport.play();

      _playbackState = DlnaPlaybackState.playing;
      _playbackStartTime = DateTime.now();
      _startPolling();

      // Handle start position via seek if provided.
      if (startPosition != null && startPosition > Duration.zero) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await seek(startPosition);
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
  static const _dlnaFlags = '01700000000000000000000000000000';

  String _audioProtocolInfo(String mimeType) {
    final pn = switch (mimeType) {
      'audio/mpeg' => 'DLNA.ORG_PN=MP3',
      'audio/x-ms-wma' => 'DLNA.ORG_PN=WMABASE',
      'audio/vnd.dlna.adts' => 'DLNA.ORG_PN=AAC_ADTS',
      'audio/mp4' || 'audio/m4a' || 'audio/aac' => 'DLNA.ORG_PN=AAC_ISO',
      'audio/wav' || 'audio/x-wav' => 'DLNA.ORG_PN=LPCM',
      'audio/flac' ||
      'audio/ogg' ||
      'audio/ape' ||
      'audio/x-ape' ||
      'audio/ac3' => null, // No standard DLNA PN, use generic
      _ => null,
    };

    if (pn != null) {
      return 'http-get:*:$mimeType:$pn;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=$_dlnaFlags';
    }
    return 'http-get:*:$mimeType:DLNA.ORG_OP=01;DLNA.ORG_FLAGS=$_dlnaFlags';
  }

  /// Build DIDL-Lite metadata for an audio music track with protocolInfo.
  String _buildDidlLite({required String url, required String title, required String protocolInfo}) {
    final escapedTitle = _escapeXml(title);
    final escapedUrl = _escapeXml(url);

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

    return _escapeXml(didlLite);
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
      _ => 'audio/mpeg',
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

  // ── Playback control ───────────────────────────────────────────

  /// Resume playback on the DLNA device.
  Future<void> play() async {
    final avTransport = _avTransport;
    if (avTransport == null) return;
    try {
      await avTransport.play();
      _playbackState = DlnaPlaybackState.playing;
      _startPolling();
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA play failed: $e");
    }
  }

  /// Pause playback on the DLNA device.
  Future<void> pause() async {
    final avTransport = _avTransport;
    if (avTransport == null) {
      _logger.warning("DLNA pause failed: no AVTransport service");
      return;
    }
    try {
      await avTransport.pause();
      _playbackState = DlnaPlaybackState.paused;
      _stopPolling();
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA pause failed: $e (type: ${e.runtimeType})");
      rethrow;
    }
  }

  /// Stop playback on the DLNA device.
  Future<void> stop() async {
    final avTransport = _avTransport;
    if (avTransport == null) return;
    try {
      await avTransport.stop();
      _playbackState = DlnaPlaybackState.stopped;
      _stopPolling();
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA stop failed: $e");
    }
  }

  /// Seek to a position on the DLNA device.
  Future<void> seek(Duration position) async {
    final avTransport = _avTransport;
    if (avTransport == null) return;
    try {
      final target = _formatDuration(position);
      await avTransport.seek(upnp.SeekMode.relTime, target);
      _position = position;
      _emitStatus();
    } catch (e) {
      _logger.severe("DLNA seek failed: $e");
    }
  }

  /// Set the volume on the DLNA device (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    final renderingControl = _renderingControl;
    if (renderingControl == null) return;
    try {
      final intVolume = (volume * 100).round().clamp(0, 100);
      await renderingControl.setVolume(volume: intVolume);
    } catch (e) {
      _logger.fine("DLNA setVolume failed: $e");
    }
  }

  /// Get the current volume from the DLNA device (0.0 to 1.0).
  Future<double> getVolume() async {
    final renderingControl = _renderingControl;
    if (renderingControl == null) return 0.0;
    try {
      final intVolume = await renderingControl.getVolume();
      return intVolume / 100.0;
    } catch (e) {
      _logger.fine("DLNA getVolume failed: $e");
      return 0.0;
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────

  /// Disconnect from the DLNA device and clean up resources.
  Future<void> disconnect() async {
    _stopPolling();

    final avTransport = _avTransport;
    if (avTransport != null) {
      try {
        await avTransport.stop();
      } catch (e) {
        _logger.warning("Error stopping DLNA during disconnect: $e");
      }
    }

    _device = null;
    _avTransport = null;
    _renderingControl = null;
    _connectedDevice = null;
    _playbackState = DlnaPlaybackState.stopped;
    _position = Duration.zero;
    _duration = Duration.zero;
    await _mediaProxy.stop();
    _deviceController.add(null);
    _statusController.add(
      DlnaPlaybackStatus(state: DlnaPlaybackState.stopped, position: Duration.zero, duration: Duration.zero),
    );
    _logger.info("Disconnected from DLNA device");
  }

  // ── Polling ─────────────────────────────────────────────────────

  /// Start periodic polling of DLNA playback status.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _pollDevice();
    });
  }

  /// Stop polling.
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollDevice() async {
    final avTransport = _avTransport;
    if (avTransport == null) return;

    try {
      // Get position info
      final posInfo = await avTransport.getPositionInfo();
      _position = _parseDuration(posInfo.relTime);
      if (posInfo.trackDuration != null) {
        final parsed = _parseDuration(posInfo.trackDuration);
        if (parsed > Duration.zero) {
          _duration = parsed;
        }
      }

      // Get transport info to detect state changes
      final transportInfo = await avTransport.getTransportInfo();
      final state = transportInfo.currentTransportState;

      if (state == upnp.TransportState.playing) {
        _playbackState = DlnaPlaybackState.playing;
      } else if (state == upnp.TransportState.pausedPlayback) {
        _playbackState = DlnaPlaybackState.paused;
      } else if (state == upnp.TransportState.stopped) {
        // If device reports STOPPED while we think we're playing, the track
        // ended. But don't do this during the first few seconds after loading
        // — the device may briefly report STOPPED before transitioning to
        // PLAYING.
        if (_playbackState == DlnaPlaybackState.playing &&
            _playbackStartTime != null &&
            DateTime.now().difference(_playbackStartTime!) > const Duration(seconds: 5)) {
          _playbackState = DlnaPlaybackState.stopped;
          _stopPolling();
        }
      }
    } catch (e) {
      _logger.fine("DLNA polling failed: $e");
    }

    _emitStatus();
  }

  /// Emit a status update to listeners.
  void _emitStatus() {
    _statusController.add(DlnaPlaybackStatus(state: _playbackState, position: _position, duration: _duration));
  }

  // ── Duration helpers ────────────────────────────────────────────

  /// Format a [Duration] as 'HH:MM:SS' for DLNA Seek commands.
  static String _formatDuration(Duration duration) {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Parse a 'HH:MM:SS' string into a [Duration].
  static Duration _parseDuration(String? formatted) {
    if (formatted == null || formatted.isEmpty || formatted == 'NOT_IMPLEMENTED') {
      return Duration.zero;
    }
    final parts = formatted.split(':');
    if (parts.length != 3) return Duration.zero;
    return Duration(
      hours: int.tryParse(parts[0]) ?? 0,
      minutes: int.tryParse(parts[1]) ?? 0,
      seconds: int.tryParse(parts[2]) ?? 0,
    );
  }

  // ── Dispose ─────────────────────────────────────────────────────

  /// Dispose all resources. Call this when the service is no longer needed.
  void dispose() {
    _stopPolling();
    for (final sub in _discoverySubs) {
      unawaited(sub.cancel());
    }
    _discoverySubs.clear();
    unawaited(_mediaProxy.stop());
    _statusController.close();
    _deviceController.close();
  }
}
