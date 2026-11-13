// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'animated_music_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnimatedAssetDto _$AnimatedAssetDtoFromJson(Map json) => AnimatedAssetDto(
  available: json['Available'] as bool? ?? false,
  url: json['Url'] as String?,
  previewUrl: json['PreviewUrl'] as String?,
  mimeType: json['MimeType'] as String?,
  fileName: json['FileName'] as String?,
  fileSize: (json['FileSize'] as num?)?.toInt(),
  trackSpecific: json['TrackSpecific'] as bool?,
);

Map<String, dynamic> _$AnimatedAssetDtoToJson(AnimatedAssetDto instance) =>
    <String, dynamic>{
      'Available': instance.available,
      'Url': instance.url,
      'PreviewUrl': instance.previewUrl,
      'MimeType': instance.mimeType,
      'FileName': instance.fileName,
      'FileSize': instance.fileSize,
      'TrackSpecific': instance.trackSpecific,
    };

PluginStatusDto _$PluginStatusDtoFromJson(Map json) => PluginStatusDto(
  pluginName: json['PluginName'] as String? ?? '',
  version: json['Version'] as String? ?? '',
  status: json['Status'] as String? ?? '',
);

Map<String, dynamic> _$PluginStatusDtoToJson(PluginStatusDto instance) =>
    <String, dynamic>{
      'PluginName': instance.pluginName,
      'Version': instance.version,
      'Status': instance.status,
    };

TrackAnimatedInfoDto _$TrackAnimatedInfoDtoFromJson(Map json) =>
    TrackAnimatedInfoDto(
      trackId: const BaseItemIdConverter().fromJson(json['TrackId'] as String),
      albumId: _$JsonConverterFromJson<String, BaseItemId>(
        json['AlbumId'],
        const BaseItemIdConverter().fromJson,
      ),
      trackFileName: json['TrackFileName'] as String?,
      cover: json['Cover'] == null
          ? AnimatedAssetDto.unavailable
          : AnimatedAssetDto.fromJson(
              Map<String, dynamic>.from(json['Cover'] as Map),
            ),
      tallCover: json['TallCover'] == null
          ? AnimatedAssetDto.unavailable
          : AnimatedAssetDto.fromJson(
              Map<String, dynamic>.from(json['TallCover'] as Map),
            ),
      verticalBackground: json['VerticalBackground'] == null
          ? AnimatedAssetDto.unavailable
          : AnimatedAssetDto.fromJson(
              Map<String, dynamic>.from(json['VerticalBackground'] as Map),
            ),
    );

Map<String, dynamic> _$TrackAnimatedInfoDtoToJson(
  TrackAnimatedInfoDto instance,
) => <String, dynamic>{
  'TrackId': const BaseItemIdConverter().toJson(instance.trackId),
  'AlbumId': _$JsonConverterToJson<String, BaseItemId>(
    instance.albumId,
    const BaseItemIdConverter().toJson,
  ),
  'TrackFileName': instance.trackFileName,
  'Cover': instance.cover.toJson(),
  'TallCover': instance.tallCover.toJson(),
  'VerticalBackground': instance.verticalBackground.toJson(),
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
