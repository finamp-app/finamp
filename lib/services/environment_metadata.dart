// This file collects structured metadata about the device, app, and server
// for logging, analytics, and diagnostics.

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'finamp_user_helper.dart';

part 'environment_metadata.g.dart';

const _sharedPreferencesVersionHistoryKey = 'version_history';
final _environmentMetadataLogger = Logger('EnvironmentMetadata');

/// Contains information about the current device (id, model, OS, platform).
@JsonSerializable()
class DeviceInfo {
  final String deviceName;
  final String deviceModel;
  final String osVersion;
  final String platform;

  DeviceInfo({required this.deviceName, required this.deviceModel, required this.osVersion, required this.platform});

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => _$DeviceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);

  /// Detects device info based on the current platform.
  static Future<DeviceInfo> fromPlatform() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      final isTV = info.systemFeatures.contains('android.software.leanback');
      final isWatch = info.systemFeatures.contains('android.hardware.type.watch');
      return DeviceInfo(
        deviceName: info.brand,
        deviceModel: info.model,
        osVersion: info.version.release,
        platform: "Android${isTV ? ' (TV)' : ''}${isWatch ? ' (Watch)' : ''}",
      );
    } else if (Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      return DeviceInfo(deviceName: info.name, deviceModel: info.model, osVersion: info.systemVersion, platform: 'iOS');
    } else if (Platform.isMacOS) {
      final info = await deviceInfoPlugin.macOsInfo;
      return DeviceInfo(
        deviceName: info.computerName,
        deviceModel: info.model,
        osVersion: "${info.majorVersion}.${info.minorVersion}.${info.patchVersion}",
        platform: 'macOS',
      );
    } else if (Platform.isLinux) {
      final info = await deviceInfoPlugin.linuxInfo;
      return DeviceInfo(
        deviceName: info.name,
        deviceModel: info.id,
        osVersion: info.version ?? 'Unknown',
        platform: 'Linux',
      );
    } else if (Platform.isWindows) {
      final info = await deviceInfoPlugin.windowsInfo;
      return DeviceInfo(
        deviceName: info.computerName,
        deviceModel: info.deviceId,
        osVersion: info.displayVersion,
        platform: 'Windows',
      );
    }

    throw UnsupportedError("Unsupported platform");
  }

  String get pretty =>
      "Device Info:\n"
      "  Device Name: $deviceName\n"
      "  Device Model: $deviceModel\n"
      "  OS Version: $osVersion\n"
      "  Platform: $platform";
}

/// Contains information about the app itself (name, version, version history).
@JsonSerializable()
class AppInfo {
  final String appName;
  final String packageName;
  final String? source;
  final String version;
  final String buildNumber;
  final DateTime? installTime;
  final DateTime? updateTime;
  final List<String>? versionHistory;

  AppInfo({
    required this.appName,
    required this.packageName,
    required this.source,
    required this.version,
    required this.buildNumber,
    required this.installTime,
    required this.updateTime,
    required this.versionHistory,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) => _$AppInfoFromJson(json);
  Map<String, dynamic> toJson() => _$AppInfoToJson(this);

  /// Detects app metadata using package_info_plus and updates stored version history.
  static Future<AppInfo> fromPlatform() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = "${packageInfo.version} (${packageInfo.buildNumber})";

    final SharedPreferencesAsync prefs = SharedPreferencesAsync();

    List<String>? history;
    try {
      history = List<String>.from((await prefs.getStringList(_sharedPreferencesVersionHistoryKey) ?? <String>[]));
      final previousVersion = history.isNotEmpty ? history.last : null;

      if (previousVersion != currentVersion) {
        history.add(currentVersion);
        await prefs.setStringList(_sharedPreferencesVersionHistoryKey, history);
      }
    } catch (e) {
      _environmentMetadataLogger.warning("Failed to update version history: $e");
    }

    return AppInfo(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      source: packageInfo.installerStore,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      installTime: packageInfo.installTime,
      updateTime: packageInfo.updateTime,
      versionHistory: history,
    );
  }

  String get pretty =>
      "App Info:\n"
      "  App Name: $appName\n"
      "  Package Name: $packageName\n"
      "  Source: $source\n"
      "  Version: $version\n"
      "  Build Number: $buildNumber\n"
      "  Installed At: ${installTime?.toIso8601String() ?? "n/a"}\n"
      "  Updated At: ${updateTime?.toIso8601String() ?? "n/a"}\n"
      "  Version History: ${versionHistory?.join(", ") ?? "n/a"}";
}

/// Contains information about the Jellyfin server in use.
@JsonSerializable()
class ServerInfo {
  final String serverAddressType;
  final int serverPort;
  final String serverProtocol;
  final String serverVersion;

  ServerInfo({
    required this.serverAddressType,
    required this.serverPort,
    required this.serverProtocol,
    required this.serverVersion,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) => _$ServerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ServerInfoToJson(this);

  /// Extracts server info from the current user's base URL.
  static Future<ServerInfo?> fromServer() async {
    final userHelper = GetIt.instance.isRegistered<FinampUserHelper>() ? GetIt.instance<FinampUserHelper>() : null;
    final jellyfinApiHelper = GetIt.instance.isRegistered<JellyfinApiHelper>()
        ? GetIt.instance<JellyfinApiHelper>()
        : null;
    final user = userHelper?.currentUser;
    if (user == null) {
      // without the user helper, we don't know the server URL
      return null;
    }

    PublicSystemInfoResult? serverInfo;
    try {
      serverInfo = await jellyfinApiHelper?.loadServerPublicInfo(timeout: Duration(milliseconds: 2500));
    } catch (e) {
      _environmentMetadataLogger.warning("Failed to load server info: $e");
    }

    final uri = Uri.parse(user.baseURL);
    return ServerInfo(
      serverAddressType: RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(uri.host)
          ? 'ipv4'
          : RegExp(r'^[\da-fA-F:]+$').hasMatch(uri.host) && uri.host.contains(':')
          ? 'ipv6'
          : (uri.host.contains('.') ? 'domainWithTld' : 'customDomain'),
      serverPort: uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
      serverProtocol: uri.scheme,
      serverVersion: serverInfo?.version ?? 'Unknown',
    );
  }

  String get pretty =>
      "Server Info:\n"
      "  Address Type: $serverAddressType\n"
      "  Port: $serverPort\n"
      "  Protocol: $serverProtocol\n"
      "  Version: $serverVersion";
}

/// Encapsulates device, app, and server info for logging.
@JsonSerializable()
class EnvironmentMetadata {
  final DeviceInfo deviceInfo;
  final AppInfo appInfo;
  final ServerInfo? serverInfo;
  EnvironmentMetadata({required this.deviceInfo, required this.appInfo, required this.serverInfo});

  /// Constructs a full log instance from platform and server metadata.
  static Future<EnvironmentMetadata> create({bool fetchServerInfo = true}) async {
    final deviceInfo = await DeviceInfo.fromPlatform();
    final appInfo = await AppInfo.fromPlatform();
    final serverInfo = fetchServerInfo ? await ServerInfo.fromServer() : null;

    return EnvironmentMetadata(deviceInfo: deviceInfo, appInfo: appInfo, serverInfo: serverInfo);
  }

  factory EnvironmentMetadata.fromJson(Map<String, dynamic> json) => _$EnvironmentMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$EnvironmentMetadataToJson(this);

  String get pretty =>
      "${deviceInfo.pretty}\n"
      "${appInfo.pretty}\n"
      "${serverInfo?.pretty ?? "Server Info: Not available"}";
}
