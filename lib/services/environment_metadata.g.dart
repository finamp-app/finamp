// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'environment_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) => DeviceInfo(
  deviceName: json['deviceName'] as String,
  deviceModel: json['deviceModel'] as String,
  osVersion: json['osVersion'] as String,
  platform: json['platform'] as String,
);

Map<String, dynamic> _$DeviceInfoToJson(DeviceInfo instance) =>
    <String, dynamic>{
      'deviceName': instance.deviceName,
      'deviceModel': instance.deviceModel,
      'osVersion': instance.osVersion,
      'platform': instance.platform,
    };

AppInfo _$AppInfoFromJson(Map<String, dynamic> json) => AppInfo(
  appName: json['appName'] as String,
  packageName: json['packageName'] as String,
  source: json['source'] as String?,
  version: json['version'] as String,
  buildNumber: json['buildNumber'] as String,
  installTime: json['installTime'] == null
      ? null
      : DateTime.parse(json['installTime'] as String),
  updateTime: json['updateTime'] == null
      ? null
      : DateTime.parse(json['updateTime'] as String),
  versionHistory: (json['versionHistory'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$AppInfoToJson(AppInfo instance) => <String, dynamic>{
  'appName': instance.appName,
  'packageName': instance.packageName,
  'source': instance.source,
  'version': instance.version,
  'buildNumber': instance.buildNumber,
  'installTime': instance.installTime?.toIso8601String(),
  'updateTime': instance.updateTime?.toIso8601String(),
  'versionHistory': instance.versionHistory,
};

ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => ServerInfo(
  serverAddressType: json['serverAddressType'] as String,
  serverPort: (json['serverPort'] as num).toInt(),
  serverProtocol: json['serverProtocol'] as String,
  serverVersion: json['serverVersion'] as String,
);

Map<String, dynamic> _$ServerInfoToJson(ServerInfo instance) =>
    <String, dynamic>{
      'serverAddressType': instance.serverAddressType,
      'serverPort': instance.serverPort,
      'serverProtocol': instance.serverProtocol,
      'serverVersion': instance.serverVersion,
    };

EnvironmentMetadata _$EnvironmentMetadataFromJson(Map<String, dynamic> json) =>
    EnvironmentMetadata(
      deviceInfo: DeviceInfo.fromJson(
        json['deviceInfo'] as Map<String, dynamic>,
      ),
      appInfo: AppInfo.fromJson(json['appInfo'] as Map<String, dynamic>),
      serverInfo: json['serverInfo'] == null
          ? null
          : ServerInfo.fromJson(json['serverInfo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$EnvironmentMetadataToJson(
  EnvironmentMetadata instance,
) => <String, dynamic>{
  'deviceInfo': instance.deviceInfo,
  'appInfo': instance.appInfo,
  'serverInfo': instance.serverInfo,
};
