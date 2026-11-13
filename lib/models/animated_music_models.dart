import 'package:json_annotation/json_annotation.dart';

import 'jellyfin_models.dart';

part 'animated_music_models.g.dart';

enum AnimatedAssetKind { cover, verticalBackground }

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class AnimatedAssetDto {
  const AnimatedAssetDto({
    required this.available,
    this.url,
    this.previewUrl,
    this.mimeType,
    this.fileName,
    this.fileSize,
    this.trackSpecific,
  });

  @JsonKey(defaultValue: false)
  final bool available;
  final String? url;
  final String? previewUrl;
  final String? mimeType;
  final String? fileName;
  final int? fileSize;
  final bool? trackSpecific;

  factory AnimatedAssetDto.fromJson(Map<String, dynamic> json) => _$AnimatedAssetDtoFromJson(_animatedMusicJson(json));

  Map<String, dynamic> toJson() => _$AnimatedAssetDtoToJson(this);

  static const unavailable = AnimatedAssetDto(available: false);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class PluginStatusDto {
  const PluginStatusDto({required this.pluginName, required this.version, required this.status});

  @JsonKey(defaultValue: '')
  final String pluginName;
  @JsonKey(defaultValue: '')
  final String version;
  @JsonKey(defaultValue: '')
  final String status;

  bool get isAvailable => status == "Available";

  factory PluginStatusDto.fromJson(Map<String, dynamic> json) => _$PluginStatusDtoFromJson(_animatedMusicJson(json));

  Map<String, dynamic> toJson() => _$PluginStatusDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class TrackAnimatedInfoDto {
  const TrackAnimatedInfoDto({
    required this.trackId,
    this.albumId,
    this.trackFileName,
    this.cover = AnimatedAssetDto.unavailable,
    this.tallCover = AnimatedAssetDto.unavailable,
    this.verticalBackground = AnimatedAssetDto.unavailable,
  });

  @BaseItemIdConverter()
  final BaseItemId trackId;

  @BaseItemIdConverter()
  final BaseItemId? albumId;

  final String? trackFileName;
  final AnimatedAssetDto cover;
  final AnimatedAssetDto tallCover;
  final AnimatedAssetDto verticalBackground;

  factory TrackAnimatedInfoDto.fromJson(Map<String, dynamic> json) =>
      _$TrackAnimatedInfoDtoFromJson(_animatedMusicJson(json));

  Map<String, dynamic> toJson() => _$TrackAnimatedInfoDtoToJson(this);
}

Map<String, dynamic> _animatedMusicJson(Map<dynamic, dynamic> json) {
  return {
    for (final entry in json.entries)
      _toPascalKey(entry.key.toString()): entry.value is Map
          ? _animatedMusicJson(Map<dynamic, dynamic>.from(entry.value as Map))
          : entry.value,
  };
}

String _toPascalKey(String key) {
  if (key.isEmpty) {
    return key;
  }
  final first = key[0];
  if (first == first.toUpperCase()) {
    return key;
  }
  return '${first.toUpperCase()}${key.substring(1)}';
}
