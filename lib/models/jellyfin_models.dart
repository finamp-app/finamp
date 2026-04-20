/// This file contains classes returned by Jellyfin. Some values may not be
/// exactly right as there may not be an easy way to convert the values into
/// Dart objects. In most cases, these values will be strings. Enums are also
/// represented as strings. This could probably be changed, but it would cause
/// compatibility problems. Value descriptions are copied directly from
/// Jellyfin's API documentation (https://api.jellyfin.org)
///
/// These classes should be correct with Jellyfin 10.7.5
library;

import 'package:collection/collection.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'jellyfin_models.g.dart';

class BaseItemIdConverter extends JsonConverter<BaseItemId, String> {
  const BaseItemIdConverter();

  @override
  BaseItemId fromJson(String json) => BaseItemId(json);

  @override
  String toJson(BaseItemId object) => object.raw;
}

extension type BaseItemId._(String raw) {
  /// Construct a BaseItemDto id from a raw string.  Please be sure you have a valid ID before using, and
  /// if you might not, consider the invalid ID's scope and if you can use an alternative, such as null
  BaseItemId(this.raw);

  String operator +(BaseItemId other) => raw + other.raw;
}

/// An abstract class to implement converting runTimeTicks into a duration.
/// Ideally, we'd hold runTimeTicks here, but that would break offline storage
/// as everything is already set up to have runTimeTicks in its own class.
///
/// To extend this class, override [runTimeTicksDuration] to call
/// [_runTimeTicksDuration] with the class's runTimeTicks.
mixin RunTimeTickDuration {
  /// Returns a duration of the item's runtime. We define a getter for this
  /// since Jellyfin returns microseconds * 10 for some reason, and manually
  /// making durations for everything was clunky.
  Duration? runTimeTicksDuration() => runTimeTicks == null ? null : Duration(microseconds: runTimeTicks! ~/ 10);

  abstract int? runTimeTicks;
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 9)
class UserDto {
  UserDto({
    this.name,
    this.serverId,
    this.serverName,
    required this.id,
    this.primaryImageTag,
    required this.hasPassword,
    required this.hasConfiguredPassword,
    required this.hasConfiguredEasyPassword,
    this.enableAutoLogin,
    this.lastLoginDate,
    this.lastActivityDate,
    this.configuration,
    this.policy,
    this.primaryImageAspectRatio,
  });

  /// Gets or sets the name.
  @HiveField(0)
  String? name;

  /// Gets or sets the server identifier.
  @HiveField(1)
  String? serverId;

  /// Gets or sets the name of the server. This is not used by the server and is
  /// for client-side usage only.
  @HiveField(2)
  String? serverName;

  /// Gets or sets the id.
  @HiveField(3)
  String id;

  /// Gets or sets the primary image tag.
  @HiveField(4)
  String? primaryImageTag;

  /// Gets or sets a value indicating whether this instance has password.
  @HiveField(5)
  bool hasPassword;

  /// Gets or sets a value indicating whether this instance has configured
  /// password.
  @HiveField(6)
  bool hasConfiguredPassword;

  /// Gets or sets a value indicating whether this instance has configured easy
  /// password.
  @HiveField(7)
  bool hasConfiguredEasyPassword;

  /// Gets or sets whether async login is enabled or not.
  @HiveField(8)
  bool? enableAutoLogin;

  /// Gets or sets the last login date.
  @HiveField(9)
  String? lastLoginDate;

  /// Gets or sets the last activity date.
  @HiveField(10)
  String? lastActivityDate;

  /// Gets or sets the configuration.
  @HiveField(11)
  UserConfiguration? configuration;

  /// Gets or sets the policy.
  @HiveField(12)
  UserPolicy? policy;

  /// Gets or sets the primary image aspect ratio.
  @HiveField(13)
  double? primaryImageAspectRatio;

  factory UserDto.fromJson(Map<String, dynamic> json) => _$UserDtoFromJson(json);
  Map<String, dynamic> toJson() => _$UserDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 11)
class UserConfiguration {
  UserConfiguration({
    this.audioLanguagePreference,
    required this.playDefaultAudioTrack,
    this.subtitleLanguagePreference,
    required this.displayMissingEpisodes,
    this.groupedFolders,
    required this.subtitleMode,
    required this.displayCollectionsView,
    required this.enableLocalPassword,
    this.orderedViews,
    this.latestItemsExcludes,
    this.myMediaExcludes,
    required this.hidePlayedInLatest,
    required this.rememberAudioSelections,
    required this.rememberSubtitleSelections,
    required this.enableNextEpisodeAutoPlay,
  });

  /// Gets or sets the audio language preference.
  @HiveField(0)
  String? audioLanguagePreference;

  /// Gets or sets a value indicating whether [play default audio track].
  @HiveField(1)
  bool playDefaultAudioTrack;

  /// Gets or sets the subtitle language preference.
  @HiveField(2)
  String? subtitleLanguagePreference;

  @HiveField(3)
  bool displayMissingEpisodes;

  @HiveField(4)
  List<String>? groupedFolders;

  /// Enum: "Default" "Always" "OnlyForced" "None" "Smart" An enum representing
  /// a subtitle playback mode.
  @HiveField(5)
  String subtitleMode;

  @HiveField(6)
  bool displayCollectionsView;

  @HiveField(7)
  bool enableLocalPassword;

  @HiveField(8)
  List<String>? orderedViews;

  @HiveField(9)
  List<String>? latestItemsExcludes;

  @HiveField(10)
  List<String>? myMediaExcludes;

  @HiveField(11)
  bool hidePlayedInLatest;

  @HiveField(12)
  bool rememberAudioSelections;

  @HiveField(13)
  bool rememberSubtitleSelections;

  @HiveField(14)
  bool enableNextEpisodeAutoPlay;

  factory UserConfiguration.fromJson(Map<String, dynamic> json) => _$UserConfigurationFromJson(json);
  Map<String, dynamic> toJson() => _$UserConfigurationToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 12)
class UserPolicy {
  UserPolicy({
    required this.isAdministrator,
    required this.isHidden,
    required this.isDisabled,
    this.maxParentalRating,
    this.blockedTags,
    required this.enableUserPreferenceAccess,
    this.accessSchedules,
    this.blockUnratedItems,
    required this.enableRemoteControlOfOtherUsers,
    required this.enableSharedDeviceControl,
    required this.enableRemoteAccess,
    required this.enableLiveTvManagement,
    required this.enableLiveTvAccess,
    required this.enableMediaPlayback,
    required this.enableAudioPlaybackTranscoding,
    required this.enableVideoPlaybackTranscoding,
    required this.enablePlaybackRemuxing,
    required this.forceRemoteSourceTranscoding,
    required this.enableContentDeletion,
    required this.enableContentDeletionFromFolders,
    required this.enableContentDownloading,
    required this.enableSyncTranscoding,
    required this.enableMediaConversion,
    this.enabledDevices,
    required this.enableAllDevices,
    this.enabledChannels,
    required this.enableAllChannels,
    this.enabledFolders,
    required this.enableAllFolders,
    required this.invalidLoginAttemptCount,
    required this.loginAttemptsBeforeLockout,
    required this.maxActiveSessions,
    required this.enablePublicSharing,
    this.blockedMediaFolders,
    this.blockedChannels,
    required this.remoteClientBitrateLimit,
    this.authenticationProviderId,
    this.passwordResetProviderId,
    required this.syncPlayAccess,
  });

  /// Gets or sets a value indicating whether this instance is administrator.
  @HiveField(0)
  bool isAdministrator;

  /// Gets or sets a value indicating whether this instance is hidden.
  @HiveField(1)
  bool isHidden;

  /// Gets or sets a value indicating whether this instance is disabled.
  @HiveField(2)
  bool isDisabled;

  /// Gets or sets the max parental rating.
  @HiveField(3)
  int? maxParentalRating;

  @HiveField(4)
  List<String>? blockedTags;

  @HiveField(5)
  bool enableUserPreferenceAccess;

  @HiveField(6)
  List<AccessSchedule>? accessSchedules;

  /// Items Enum: "Movie" "Trailer" "Series" "Music" "Book" "LiveTvChannel"
  /// "LiveTvProgram" "ChannelContent" "Other"
  @HiveField(7)
  List<String>? blockUnratedItems;

  @HiveField(8)
  bool enableRemoteControlOfOtherUsers;

  @HiveField(9)
  bool enableSharedDeviceControl;

  @HiveField(10)
  bool enableRemoteAccess;

  @HiveField(11)
  bool enableLiveTvManagement;

  @HiveField(12)
  bool enableLiveTvAccess;

  @HiveField(13)
  bool enableMediaPlayback;

  @HiveField(14)
  bool enableAudioPlaybackTranscoding;

  @HiveField(15)
  bool enableVideoPlaybackTranscoding;

  @HiveField(16)
  bool enablePlaybackRemuxing;

  @HiveField(17)
  bool enableContentDeletion;

  @HiveField(18)
  List<String>? enableContentDeletionFromFolders;

  @HiveField(19)
  bool enableContentDownloading;

  /// Gets or sets a value indicating whether [enable synchronize].
  @HiveField(20)
  bool enableSyncTranscoding;

  @HiveField(21)
  bool enableMediaConversion;

  @HiveField(22)
  List<String>? enabledDevices;

  @HiveField(23)
  bool enableAllDevices;

  @HiveField(24)
  List<String>? enabledChannels;

  @HiveField(25)
  bool enableAllChannels;

  @HiveField(26)
  List<String>? enabledFolders;

  @HiveField(27)
  bool enableAllFolders;

  @HiveField(28)
  int invalidLoginAttemptCount;

  @HiveField(29)
  bool enablePublicSharing;

  @HiveField(30)
  List<String>? blockedMediaFolders;

  @HiveField(31)
  List<String>? blockedChannels;

  @HiveField(32)
  int remoteClientBitrateLimit;

  @HiveField(33)
  String? authenticationProviderId;

  // Below fields were added during null safety migration (0.5.0)

  @HiveField(34)
  bool? forceRemoteSourceTranscoding;

  @HiveField(35)
  int? loginAttemptsBeforeLockout;

  @HiveField(36)
  int? maxActiveSessions;

  @HiveField(37)
  String? passwordResetProviderId;

  /// Enum: "CreateAndJoinGroups" "JoinGroups" "None"
  /// Enum SyncPlayUserAccessType.
  @HiveField(38)
  String syncPlayAccess;

  factory UserPolicy.fromJson(Map<String, dynamic> json) => _$UserPolicyFromJson(json);
  Map<String, dynamic> toJson() => _$UserPolicyToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 13)
class AccessSchedule {
  AccessSchedule({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
  });

  /// Enum: "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday"
  /// "Saturday" "Everyday" "Weekday" "Weekend" Gets or sets the day of week.
  @HiveField(0)
  String dayOfWeek;

  /// Gets or sets the start hour.
  @HiveField(1)
  double startHour;

  /// Gets or sets the end hour.
  @HiveField(2)
  double endHour;

  // Below fields were added during null safety migration (0.5.0)

  /// Gets or sets the id of this instance.
  @HiveField(3)
  int id;

  /// Gets or sets the id of the associated user.
  @HiveField(4)
  String userId;

  factory AccessSchedule.fromJson(Map<String, dynamic> json) => _$AccessScheduleFromJson(json);
  Map<String, dynamic> toJson() => _$AccessScheduleToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 7)
class AuthenticationResult {
  AuthenticationResult({this.user, this.sessionInfo, this.accessToken, this.serverId});

  @HiveField(0)
  UserDto? user;

  @HiveField(1)
  SessionInfo? sessionInfo;

  @HiveField(2)
  String? accessToken;

  @HiveField(3)
  String? serverId;

  factory AuthenticationResult.fromJson(Map<String, dynamic> json) => _$AuthenticationResultFromJson(json);
  Map<String, dynamic> toJson() => _$AuthenticationResultToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 10)
class SessionInfo {
  SessionInfo({
    this.playState,
    this.additionalUsers,
    this.capabilities,
    this.remoteEndPoint,
    this.playableMediaTypes,
    this.playlistItemId,
    this.id,
    this.serverId,
    required this.userId,
    this.userName,
    this.userPrimaryImageTag,
    this.client,
    required this.lastActivityDate,
    this.deviceName,
    this.deviceType,
    this.nowPlayingItem,
    this.deviceId,
    this.supportedCommands,
    this.transcodingInfo,
    required this.supportsRemoteControl,
    required this.lastPlaybackCheckIn,
    this.fullNowPlayingItem,
    this.nowViewingItem,
    this.applicationVersion,
    required this.isActive,
    required this.supportsMediaControl,
    this.nowPlayingQueue,
    required this.hasCustomDeviceName,
  });

  @HiveField(0)
  PlayerStateInfo? playState;

  @HiveField(1)
  List<SessionUserInfo>? additionalUsers;

  @HiveField(2)
  ClientCapabilities? capabilities;

  /// Gets or sets the remote end point.
  @HiveField(3)
  String? remoteEndPoint;

  /// Gets or sets the playable media types.
  @HiveField(4)
  List<String>? playableMediaTypes;

  @HiveField(5)
  String? playlistItemId;

  /// Gets or sets the id.
  @HiveField(6)
  String? id;

  @HiveField(7)
  String? serverId;

  /// Gets or sets the user id.
  @HiveField(8)
  String userId;

  /// Gets or sets the username.
  @HiveField(9)
  String? userName;

  @HiveField(10)
  String? userPrimaryImageTag;

  /// Gets or sets the type of the client.
  @HiveField(11)
  String? client;

  /// Gets or sets the last activity date.
  @HiveField(12)
  String lastActivityDate;

  /// Gets or sets the name of the device.
  @HiveField(13)
  String? deviceName;

  /// Gets or sets the type of the device.
  @HiveField(14)
  String? deviceType;

  /// Gets or sets the now playing item.
  @HiveField(15)
  BaseItemDto? nowPlayingItem;

  /// Gets or sets the device id.
  @HiveField(16)
  String? deviceId;

  /// Items Enum: "MoveUp" "MoveDown" "MoveLeft" "MoveRight" "PageUp" "PageDown"
  /// "PreviousLetter" "NextLetter" "ToggleOsd" "ToggleContextMenu" "Select"
  /// "Back" "TakeScreenshot" "SendKey" "SendString" "GoHome" "GoToSettings"
  /// "VolumeUp" "VolumeDown" "Mute" "Unmute" "ToggleMute" "SetVolume"
  /// "SetAudioStreamIndex" "SetSubtitleStreamIndex" "ToggleFullscreen"
  /// "DisplayContent" "GoToSearch" "DisplayMessage" "SetRepeatMode" "ChannelUp"
  /// "ChannelDown" "Guide" "ToggleStats" "PlayMediaSource" "PlayTrailers"
  /// "SetShuffleQueue" "PlayState" "PlayNext" "ToggleOsdMenu" "Play" Gets or
  /// sets the supported commands.
  @HiveField(17)
  List<String>? supportedCommands;

  @HiveField(18)
  TranscodingInfo? transcodingInfo;

  @HiveField(19)
  bool supportsRemoteControl;

  // Below fields were added during null safety migration (0.5.0)

  /// Gets or sets the last playback check in.
  @HiveField(20)
  String? lastPlaybackCheckIn;

  @HiveField(21)
  BaseItem? fullNowPlayingItem;

  @HiveField(22)
  BaseItemDto? nowViewingItem;

  /// Gets or sets the application version.
  @HiveField(23)
  String? applicationVersion;

  /// Gets a value indicating whether this instance is active.
  @HiveField(24)
  bool isActive;

  @HiveField(25)
  bool supportsMediaControl;

  @HiveField(26)
  List<QueueItem>? nowPlayingQueue;

  @HiveField(27)
  bool hasCustomDeviceName;

  factory SessionInfo.fromJson(Map<String, dynamic> json) => _$SessionInfoFromJson(json);
  Map<String, dynamic> toJson() => _$SessionInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class TranscodingInfo {
  TranscodingInfo({
    this.audioCodec,
    this.videoCodec,
    this.container,
    required this.isVideoDirect,
    required this.isAudioDirect,
    this.bitrate,
    this.framerate,
    this.completionPercentage,
    this.width,
    this.height,
    this.audioChannels,
    this.transcodeReasons,
  });

  String? audioCodec;

  String? videoCodec;

  String? container;

  bool isVideoDirect;

  bool isAudioDirect;

  int? bitrate;

  double? framerate;

  double? completionPercentage;

  int? width;

  int? height;

  int? audioChannels;

  /// Items Enum: "ContainerNotSupported" "VideoCodecNotSupported"
  /// "AudioCodecNotSupported" "ContainerBitrateExceedsLimit"
  /// "AudioBitrateNotSupported" "AudioChannelsNotSupported"
  /// "VideoResolutionNotSupported" "UnknownVideoStreamInfo"
  /// "UnknownAudioStreamInfo" "AudioProfileNotSupported"
  /// "AudioSampleRateNotSupported" "AnamorphicVideoNotSupported"
  /// "InterlacedVideoNotSupported" "SecondaryAudioNotSupported"
  /// "RefFramesNotSupported" "VideoBitDepthNotSupported"
  /// "VideoBitrateNotSupported" "VideoFramerateNotSupported"
  /// "VideoLevelNotSupported" "VideoProfileNotSupported"
  /// "AudioBitDepthNotSupported" "SubtitleCodecNotSupported" "DirectPlayError"
  List<String>? transcodeReasons;

  factory TranscodingInfo.fromJson(Map<String, dynamic> json) => _$TranscodingInfoFromJson(json);
  Map<String, dynamic> toJson() => _$TranscodingInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 14)
class PlayerStateInfo {
  PlayerStateInfo({
    this.positionTicks,
    required this.canSeek,
    required this.isPaused,
    required this.isMuted,
    this.volumeLevel,
    this.audioStreamIndex,
    this.subtitleStreamIndex,
    this.mediaSourceId,
    this.playMethod,
    this.repeatMode,
  });

  /// Gets or sets the now playing position ticks.
  @HiveField(0)
  int? positionTicks;

  /// Gets or sets a value indicating whether this instance can seek.
  @HiveField(1)
  bool canSeek;

  /// Gets or sets a value indicating whether this instance is paused.
  @HiveField(2)
  bool isPaused;

  /// Gets or sets a value indicating whether this instance is muted.
  @HiveField(3)
  bool isMuted;

  /// Gets or sets the volume level.
  @HiveField(4)
  int? volumeLevel;

  /// Gets or sets the index of the now playing audio stream.
  @HiveField(5)
  int? audioStreamIndex;

  /// Gets or sets the index of the now playing subtitle stream.
  @HiveField(6)
  int? subtitleStreamIndex;

  /// Gets or sets the now playing media version identifier.
  @HiveField(7)
  String? mediaSourceId;

  /// Enum: "Transcode" "DirectStream" "DirectPlay" Gets or sets the play
  /// method.
  @HiveField(8)
  String? playMethod;

  /// Enum: "RepeatNone" "RepeatAll" "RepeatOne" Gets or sets the repeat mode.
  @HiveField(9)
  String? repeatMode;

  factory PlayerStateInfo.fromJson(Map<String, dynamic> json) => _$PlayerStateInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerStateInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 15)
class SessionUserInfo {
  SessionUserInfo({required this.userId, this.userName});

  /// Gets or sets the user identifier.
  @HiveField(0)
  String userId;

  /// Gets or sets the name of the user.
  @HiveField(1)
  String? userName;

  factory SessionUserInfo.fromJson(Map<String, dynamic> json) => _$SessionUserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$SessionUserInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 16)
class ClientCapabilities {
  ClientCapabilities({
    required this.playableMediaTypes,
    required this.supportedCommands,
    required this.supportsMediaControl,
    required this.supportsPersistentIdentifier,
    this.deviceProfile,
    this.appStoreUrl,
    this.iconUrl,
  });

  @HiveField(0)
  List<String>? playableMediaTypes;

  @HiveField(1)
  List<String>? supportedCommands;

  @HiveField(2)
  bool? supportsMediaControl;

  @HiveField(3)
  bool? supportsPersistentIdentifier;

  /// Defines the MediaBrowser.Model.Dlna.DeviceProfile.
  @HiveField(5)
  DeviceProfile? deviceProfile;

  @HiveField(6)
  String? iconUrl;

  // Below fields were added during null safety migration (0.5.0)

  @HiveField(9)
  String? appStoreUrl;

  factory ClientCapabilities.fromJson(Map<String, dynamic> json) => _$ClientCapabilitiesFromJson(json);
  Map<String, dynamic> toJson() => _$ClientCapabilitiesToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 17)
class DeviceProfile {
  DeviceProfile({
    this.name,
    this.id,
    this.maxStreamingBitrate,
    this.maxStaticBitrate,
    this.musicStreamingTranscodingBitrate,
    this.maxStaticMusicBitrate,
    this.directPlayProfiles = const [],
    this.transcodingProfiles = const [],
    this.containerProfiles = const [],
    this.codecProfiles = const [],
    this.subtitleProfiles = const [],
  });

  /// Gets or sets the Name.
  @HiveField(0)
  String? name;

  /// Gets or sets the Id.
  @HiveField(1)
  String? id;

  /// Gets or sets the Identification.
  // @Deprecated("removed from API")
  // @HiveField(2)
  // DeviceIdentification? identification;

  /// Gets or sets the FriendlyName.
  // @Deprecated("removed from API")
  // @HiveField(3)
  // String? friendlyName;

  /// Gets or sets the Manufacturer.
  // @Deprecated("removed from API")
  // @HiveField(4)
  // String? manufacturer;

  /// Gets or sets the ManufacturerUrl.
  // @Deprecated("removed from API")
  // @HiveField(5)
  // String? manufacturerUrl;

  /// Gets or sets the ModelName.
  // @Deprecated("removed from API")
  // @HiveField(6)
  // String? modelName;

  /// Gets or sets the ModelDescription.
  // @Deprecated("removed from API")
  // @HiveField(7)
  // String? modelDescription;

  /// Gets or sets the ModelNumber.
  // @Deprecated("removed from API")
  // @HiveField(8)
  // String? modelNumber;

  /// Gets or sets the ModelUrl.
  // @Deprecated("removed from API")
  // @HiveField(9)
  // String? modelUrl;

  /// Gets or sets the SerialNumber.
  // @Deprecated("removed from API")
  // @HiveField(10)
  // String? serialNumber;

  /// Gets or sets a value indicating whether EnableAlbumArtInDidl.
  // @Deprecated("removed from API")
  // @HiveField(11)
  // bool enableAlbumArtInDidl;

  /// Gets or sets a value indicating whether EnableSingleAlbumArtLimit.
  // @Deprecated("removed from API")
  // @HiveField(12)
  // bool enableSingleAlbumArtLimit;

  /// Gets or sets a value indicating whether EnableSingleSubtitleLimit.
  // @Deprecated("removed from API")
  // @HiveField(13)
  // bool enableSingleSubtitleLimit;

  /// Gets or sets the SupportedMediaTypes.
  // @Deprecated("removed from API")
  // @HiveField(14)
  // String? supportedMediaTypes;

  /// Gets or sets the UserId.
  // @Deprecated("removed from API")
  // @HiveField(15)
  // String? userId;

  /// Gets or sets the AlbumArtPn.
  // @Deprecated("removed from API")
  // @HiveField(16)
  // String? albumArtPn;

  /// Gets or sets the MaxAlbumArtWidth.
  // @Deprecated("removed from API")
  // @HiveField(17)
  // int maxAlbumArtWidth;

  /// Gets or sets the MaxAlbumArtHeight.
  // @Deprecated("removed from API")
  // @HiveField(18)
  // int maxAlbumArtHeight;

  /// Gets or sets the MaxIconWidth.
  // @Deprecated("removed from API")
  // @HiveField(19)
  // int? maxIconWidth;

  /// Gets or sets the MaxIconHeight.
  // @Deprecated("removed from API")
  // @HiveField(20)
  // int? maxIconHeight;

  /// Gets or sets the MaxStreamingBitrate.
  @HiveField(21)
  int? maxStreamingBitrate;

  /// Gets or sets the MaxStaticBitrate.
  @HiveField(22)
  int? maxStaticBitrate;

  /// Gets or sets the MusicStreamingTranscodingBitrate.
  @HiveField(23)
  int? musicStreamingTranscodingBitrate;

  /// Gets or sets the MaxStaticMusicBitrate.
  @HiveField(24)
  int? maxStaticMusicBitrate;

  /// Gets or sets the content of the aggregationFlags element in the
  /// urn:schemas-sonycom:av namespace.
  // @Deprecated("removed from API")
  // @HiveField(25)
  // String? sonyAggregationFlags;

  /// Gets or sets the ProtocolInfo.
  // @Deprecated("removed from API")
  // @HiveField(26)
  // String? protocolInfo;

  /// Gets or sets the TimelineOffsetSeconds.
  // @Deprecated("removed from API")
  // @HiveField(27)
  // int timelineOffsetSeconds;

  /// Gets or sets a value indicating whether RequiresPlainVideoItems.
  // @Deprecated("removed from API")
  // @HiveField(28)
  // bool requiresPlainVideoItems;

  /// Gets or sets a value indicating whether RequiresPlainFolders.
  // @Deprecated("removed from API")
  // @HiveField(29)
  // bool requiresPlainFolders;

  /// Gets or sets a value indicating whether EnableMSMediaReceiverRegistrar.
  // @Deprecated("removed from API")
  // @HiveField(30)
  // bool enableMSMediaReceiverRegistrar;

  /// Gets or sets a value indicating whether IgnoreTranscodeByteRangeRequests.
  // @Deprecated("removed from API")
  // @HiveField(31)
  // bool ignoreTranscodeByteRangeRequests;

  /// Gets or sets the XmlRootAttributes.
  // @Deprecated("removed from API")
  // @HiveField(32)
  // List<XmlAttribute>? xmlRootAttributes;

  /// Gets or sets the direct play profiles.
  @HiveField(33)
  List<DirectPlayProfile> directPlayProfiles;

  /// Gets or sets the transcoding profiles.
  @HiveField(34)
  List<TranscodingProfile> transcodingProfiles;

  /// Gets or sets the ContainerProfiles.
  @HiveField(35)
  List<ContainerProfile> containerProfiles;

  /// Gets or sets the CodecProfiles.
  @HiveField(36)
  List<CodecProfile> codecProfiles;

  /// Gets or sets the ResponseProfiles.
  // @Deprecated("removed from API")
  // @HiveField(37)
  // List<ResponseProfile>? responseProfiles;

  /// Gets or sets the SubtitleProfiles.
  @HiveField(38)
  List<SubtitleProfile> subtitleProfiles;

  factory DeviceProfile.fromJson(Map<String, dynamic> json) => _$DeviceProfileFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceProfileToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 18)
class DeviceIdentification {
  DeviceIdentification({
    this.friendlyName,
    this.modelNumber,
    this.serialNumber,
    this.modelName,
    this.modelDescription,
    this.modelUrl,
    this.manufacturer,
    this.manufacturerUrl,
    this.headers,
  });

  /// Gets or sets the name of the friendly.
  @HiveField(0)
  String? friendlyName;

  /// Gets or sets the model number.
  @HiveField(1)
  String? modelNumber;

  /// Gets or sets the serial number.
  @HiveField(2)
  String? serialNumber;

  /// Gets or sets the name of the model.
  @HiveField(3)
  String? modelName;

  /// Gets or sets the model description.
  @HiveField(4)
  String? modelDescription;

  /// Gets or sets the model URL.
  @HiveField(5)
  String? modelUrl;

  /// Gets or sets the manufacturer.
  @HiveField(6)
  String? manufacturer;

  /// Gets or sets the manufacturer URL.
  @HiveField(7)
  String? manufacturerUrl;

  /// Gets or sets the headers.
  @HiveField(8)
  List<HttpHeaderInfo>? headers;

  factory DeviceIdentification.fromJson(Map<String, dynamic> json) => _$DeviceIdentificationFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceIdentificationToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 19)
class HttpHeaderInfo {
  HttpHeaderInfo({this.name, this.value, required this.match});

  @HiveField(0)
  String? name;

  @HiveField(1)
  String? value;

  /// Enum: "Equals" "Regex" "Substring"
  @HiveField(2)
  String match;

  factory HttpHeaderInfo.fromJson(Map<String, dynamic> json) => _$HttpHeaderInfoFromJson(json);
  Map<String, dynamic> toJson() => _$HttpHeaderInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 20)
class XmlAttribute {
  XmlAttribute({this.name, this.value});

  @HiveField(0)
  String? name;

  @HiveField(1)
  String? value;

  factory XmlAttribute.fromJson(Map<String, dynamic> json) => _$XmlAttributeFromJson(json);
  Map<String, dynamic> toJson() => _$XmlAttributeToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 21)
class DirectPlayProfile {
  DirectPlayProfile({this.container, this.audioCodec, this.videoCodec, required this.type});

  @HiveField(0)
  String? container;

  @HiveField(1)
  String? audioCodec;

  @HiveField(2)
  String? videoCodec;

  /// Enum: "Audio" "Video" "Photo"
  @HiveField(3)
  DlnaProfileType type;

  factory DirectPlayProfile.fromJson(Map<String, dynamic> json) => _$DirectPlayProfileFromJson(json);
  Map<String, dynamic> toJson() => _$DirectPlayProfileToJson(this);
}

@HiveType(typeId: 103)
enum DlnaProfileType {
  @HiveField(0)
  audio("Audio"),
  @HiveField(1)
  lyric("Lyric"),
  @HiveField(2)
  video("Video"),
  @HiveField(3)
  subtitle("Subtitle"),
  @HiveField(4)
  photo("Photo");

  const DlnaProfileType(this.jellyfinName);

  final String jellyfinName;
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 22)
class TranscodingProfile {
  TranscodingProfile({
    required this.type,
    required this.context,
    required this.container,
    this.minSegments = 1,
    this.audioCodec = "aac",
    this.videoCodec = "mp4",
    this.protocol,
    this.estimateContentLength = false,
    this.enableMpegtsM2TsMode = false,
    this.transcodeSeekInfo = "Auto",
    this.copyTimestamps = true,
    this.segmentLength = 0,
    this.breakOnNonKeyFrames = false,
    this.enableSubtitlesInManifest = true,
    this.maxAudioChannels,
    this.conditions = const [],
  });

  @HiveField(0)
  String? container;

  /// Enum: "Audio" "Video" "Photo"
  @HiveField(1)
  DlnaProfileType type;

  @HiveField(2)
  String videoCodec;

  @HiveField(3)
  String audioCodec;

  @HiveField(4)
  String? protocol;

  @HiveField(5)
  bool? estimateContentLength;

  @HiveField(6)
  bool? enableMpegtsM2TsMode;

  /// Enum: "Auto" "Bytes"
  @HiveField(7)
  String? transcodeSeekInfo;

  @HiveField(8)
  bool? copyTimestamps;

  /// Enum: "Streaming" "Static"
  @HiveField(9)
  String context;

  @HiveField(10)
  String? maxAudioChannels;

  @HiveField(11)
  int? minSegments;

  @HiveField(12)
  int? segmentLength;

  @HiveField(13)
  bool? breakOnNonKeyFrames;

  @HiveField(14)
  bool? enableSubtitlesInManifest;

  @HiveField(15)
  List<ProfileCondition> conditions;

  factory TranscodingProfile.fromJson(Map<String, dynamic> json) => _$TranscodingProfileFromJson(json);
  Map<String, dynamic> toJson() => _$TranscodingProfileToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 23)
class ContainerProfile {
  ContainerProfile({required this.type, this.conditions, this.container});

  /// Enum: "Audio" "Video" "Photo"
  @HiveField(0)
  String type;

  @HiveField(1)
  List<ProfileCondition>? conditions;

  @HiveField(2)
  String? container;

  factory ContainerProfile.fromJson(Map<String, dynamic> json) => _$ContainerProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ContainerProfileToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 24)
class ProfileCondition {
  ProfileCondition({required this.condition, required this.property, this.value, required this.isRequired});

  /// Enum: "Equals" "NotEquals" "LessThanEqual" "GreaterThanEqual" "EqualsAny"
  @HiveField(0)
  String condition;

  /// Enum: "AudioChannels" "AudioBitrate" "AudioProfile" "Width" "Height"
  /// "Has64BitOffsets" "PacketLength" "VideoBitDepth" "VideoBitrate"
  /// "VideoFramerate" "VideoLevel" "VideoProfile" "VideoTimestamp"
  /// "IsAnamorphic" "RefFrames" "NumAudioStreams" "NumVideoStreams"
  /// "IsSecondaryAudio" "VideoCodecTag" "IsAvc" "IsInterlaced"
  /// "AudioSampleRate" "AudioBitDepth"
  @HiveField(1)
  String property;

  @HiveField(2)
  String? value;

  @HiveField(3)
  bool isRequired;

  factory ProfileCondition.fromJson(Map<String, dynamic> json) => _$ProfileConditionFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileConditionToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 25)
class CodecProfile {
  CodecProfile({required this.type, this.conditions, this.applyConditions, this.codec, this.container});

  /// Enum: "Video" "VideoAudio" "Audio"
  @HiveField(0)
  String type;

  @HiveField(1)
  List<ProfileCondition>? conditions;

  @HiveField(2)
  List<ProfileCondition>? applyConditions;

  @HiveField(3)
  String? codec;

  @HiveField(4)
  String? container;

  factory CodecProfile.fromJson(Map<String, dynamic> json) => _$CodecProfileFromJson(json);
  Map<String, dynamic> toJson() => _$CodecProfileToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 26)
class ResponseProfile {
  ResponseProfile({
    this.container,
    this.audioCodec,
    this.videoCodec,
    required this.type,
    this.orgPn,
    this.mimeType,
    this.conditions,
  });

  @HiveField(0)
  String? container;

  @HiveField(1)
  String? audioCodec;

  @HiveField(2)
  String? videoCodec;

  /// Enum: "Audio" "Video" "Photo"
  @HiveField(3)
  String type;

  @HiveField(4)
  String? orgPn;

  @HiveField(5)
  String? mimeType;

  @HiveField(6)
  List<ProfileCondition>? conditions;

  factory ResponseProfile.fromJson(Map<String, dynamic> json) => _$ResponseProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ResponseProfileToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 27)
class SubtitleProfile {
  SubtitleProfile({this.format, required this.method, this.didlMode, this.language, this.container});

  @HiveField(0)
  String? format;

  /// Enum: "Encode" "Embed" "External" "Hls"
  @HiveField(1)
  String method;

  @HiveField(2)
  String? didlMode;

  @HiveField(3)
  String? language;

  @HiveField(4)
  String? container;

  factory SubtitleProfile.fromJson(Map<String, dynamic> json) => _$SubtitleProfileFromJson(json);
  Map<String, dynamic> toJson() => _$SubtitleProfileToJson(this);
}

// Here because sealed class works inside one file only
sealed class PlayableItem {}

class AlbumDisc implements PlayableItem {
  AlbumDisc({required this.parent, required this.tracks}) {
    assert(
      // there's no "all" in dart (at least IDE doesn't see it). De Morgan's law is here to save the day!
      !tracks.any((e) {
        return e.parentIndexNumber != tracks.first.parentIndexNumber;
      }),
    );
  }

  List<BaseItemDto> tracks;
  BaseItemDto parent;
}

@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  includeIfNull: false,
  converters: [BaseItemIdConverter()],
)
@HiveType(typeId: 0)
class BaseItemDto with RunTimeTickDuration implements PlayableItem {
  BaseItemDto({
    this.name,
    this.originalTitle,
    this.serverId,
    required this.id,
    this.etag,
    this.playlistItemId,
    this.dateCreated,
    this.extraType,
    this.airsBeforeSeasonNumber,
    this.airsAfterSeasonNumber,
    this.airsBeforeEpisodeNumber,
    this.canDelete,
    this.canDownload,
    this.hasSubtitles,
    this.preferredMetadataLanguage,
    this.preferredMetadataCountryCode,
    this.supportsSync,
    this.container,
    this.sortName,
    this.forcedSortName,
    this.video3DFormat,
    this.premiereDate,
    this.externalUrls,
    this.mediaSources,
    this.criticRating,
    this.productionLocations,
    this.path,
    this.officialRating,
    this.customRating,
    this.channelId,
    this.channelName,
    this.overview,
    this.taglines,
    this.genres,
    this.communityRating,
    this.runTimeTicks,
    this.playAccess,
    this.aspectRatio,
    this.productionYear,
    this.number,
    this.channelNumber,
    this.indexNumber,
    this.indexNumberEnd,
    this.parentIndexNumber,
    this.remoteTrailers,
    this.providerIds,
    this.isFolder,
    this.parentId,
    this.type,
    this.people,
    this.studios,
    this.genreItems,
    this.parentLogoItemId,
    this.parentBackdropItemId,
    this.parentBackdropImageTags,
    this.localTrailerCount,
    this.userData,
    this.recursiveItemCount,
    this.childCount,
    this.seriesName,
    this.seriesId,
    this.seasonId,
    this.specialFeatureCount,
    this.displayPreferencesId,
    this.status,
    this.airTime,
    this.airDays,
    this.tags,
    this.primaryImageAspectRatio,
    this.artists,
    this.artistItems,
    this.album,
    this.collectionType,
    this.displayOrder,
    this.albumId,
    this.albumPrimaryImageTag,
    this.seriesPrimaryImageTag,
    this.albumArtist,
    this.albumArtists,
    this.seasonName,
    this.mediaStreams,
    this.partCount,
    this.imageTags,
    this.backdropImageTags,
    this.parentLogoImageTag,
    this.parentArtItemId,
    this.parentArtImageTag,
    this.seriesThumbImageTag,
    this.seriesStudio,
    this.parentThumbItemId,
    this.parentThumbImageTag,
    this.parentPrimaryImageItemId,
    this.parentPrimaryImageTag,
    this.chapters,
    this.locationType,
    this.mediaType,
    this.endDate,
    this.lockedFields,
    this.lockData,
    this.width,
    this.height,
    this.cameraMake,
    this.cameraModel,
    this.software,
    this.exposureTime,
    this.focalLength,
    this.imageOrientation,
    this.aperture,
    this.shutterSpeed,
    this.latitude,
    this.longitude,
    this.altitude,
    this.isoSpeedRating,
    this.seriesTimerId,
    this.channelPrimaryImageTag,
    this.startDate,
    this.completionPercentage,
    this.isRepeat,
    this.episodeTitle,
    this.isMovie,
    this.isSports,
    this.isSeries,
    this.isLive,
    this.isNews,
    this.isKids,
    this.isPremiere,
    this.timerId,
    this.currentProgram,
    this.movieCount,
    this.seriesCount,
    this.albumCount,
    this.songCount,
    this.musicVideoCount,
    this.sourceType,
    this.dateLastMediaAdded,
    this.enableMediaSourceDisplay,
    this.cumulativeRunTimeTicks,
    this.isPlaceHolder,
    this.isHD,
    this.videoType,
    this.mediaSourceCount,
    this.screenshotImageTags,
    this.imageBlurHashes,
    this.isoType,
    this.trailerCount,
    this.programCount,
    this.episodeCount,
    this.artistCount,
    this.programId,
    this.channelType,
    this.audio,
    this.normalizationGain,
    this.hasLyrics,
  });

  /// Gets or sets the name.
  @HiveField(0)
  String? name;

  @HiveField(1)
  String? originalTitle;

  /// Gets or sets the server identifier.
  @HiveField(2)
  String? serverId;

  /// Gets or sets the id.
  @HiveField(3)
  BaseItemId id;

  /// Gets or sets the etag.
  @HiveField(4)
  String? etag;

  /// Gets or sets the playlist item identifier.
  @HiveField(5)
  String? playlistItemId;

  /// Gets or sets the date created.
  @HiveField(6)
  String? dateCreated;

  @HiveField(7)
  String? extraType;

  @HiveField(8)
  int? airsBeforeSeasonNumber;

  @HiveField(9)
  int? airsAfterSeasonNumber;

  @HiveField(10)
  int? airsBeforeEpisodeNumber;

  @HiveField(11)
  bool? canDelete;

  @HiveField(12)
  bool? canDownload;

  @HiveField(13)
  bool? hasSubtitles;

  @HiveField(14)
  String? preferredMetadataLanguage;

  @HiveField(15)
  String? preferredMetadataCountryCode;

  /// Gets or sets a value indicating whether [supports synchronize].
  @HiveField(16)
  bool? supportsSync;

  @HiveField(17)
  String? container;

  /// Gets or sets the name of the sort.
  @HiveField(18)
  String? sortName;

  @HiveField(19)
  String? forcedSortName;

  /// Enum: "HalfSideBySide" "FullSideBySide" "FullTopAndBottom"
  /// "HalfTopAndBottom" "MVC"
  /// Gets or sets the video3 D format.
  @HiveField(20)
  String? video3DFormat;

  /// Gets or sets the premiere date.
  @HiveField(21)
  String? premiereDate;

  /// Gets or sets the external urls.
  @HiveField(22)
  List<ExternalUrl>? externalUrls;

  /// Gets or sets the media versions.
  @HiveField(23)
  List<MediaSourceInfo>? mediaSources;

  /// Gets or sets the critic rating.
  @HiveField(24)
  double? criticRating;

  @HiveField(25)
  List<String>? productionLocations;

  /// Gets or sets the path.
  @HiveField(26)
  String? path;

  /// Gets or sets the official rating.
  @HiveField(27)
  String? officialRating;

  /// Gets or sets the custom rating.
  @HiveField(28)
  String? customRating;

  /// Gets or sets the channel identifier.
  @HiveField(29)
  String? channelId;

  @HiveField(30)
  String? channelName;

  /// Gets or sets the overview.
  @HiveField(31)
  String? overview;

  /// Gets or sets the taglines.
  @HiveField(32)
  List<String>? taglines;

  /// Gets or sets the genres.
  @HiveField(33)
  List<String>? genres;

  /// Gets or sets the community rating.
  @HiveField(34)
  double? communityRating;

  /// Gets or sets the run time ticks.
  @override
  @HiveField(35)
  int? runTimeTicks;

  /// Enum: "Full" "None"
  /// Gets or sets the play access.
  @HiveField(36)
  String? playAccess;

  /// Gets or sets the aspect ratio.
  @HiveField(37)
  String? aspectRatio;

  /// Gets or sets the production year.
  @HiveField(38)
  int? productionYear;

  /// Gets or sets the number.
  @HiveField(39)
  String? number;

  @HiveField(40)
  String? channelNumber;

  /// Gets or sets the index number.
  @HiveField(41)
  int? indexNumber;

  /// Gets or sets the index number end.
  @HiveField(42)
  int? indexNumberEnd;

  /// Gets or sets the parent index number.
  @HiveField(43)
  int? parentIndexNumber;

  /// Gets or sets the trailer urls.
  @HiveField(44)
  List<MediaUrl>? remoteTrailers;

  /// Gets or sets the provider ids.
  @HiveField(45)
  Map<String, dynamic>? providerIds;

  /// Gets or sets a value indicating whether this instance is folder.
  @HiveField(46)
  bool? isFolder;

  /// Gets or sets the parent id.
  @HiveField(47)
  BaseItemId? parentId;

  /// Gets or sets the type.
  @HiveField(48)
  String? type;

  /// Gets or sets the people.
  @HiveField(49)
  List<BaseItemPerson>? people;

  /// Gets or sets the studios.
  @HiveField(50)
  List<NameLongIdPair>? studios;

  @HiveField(51)
  List<NameLongIdPair>? genreItems;

  /// If the item does not have a logo, this will hold the Id of the Parent that
  /// has one.
  @HiveField(52)
  String? parentLogoItemId;

  /// If the item does not have any backdrops, this will hold the Id of the
  /// Parent that has one.
  @HiveField(53)
  String? parentBackdropItemId;

  /// Gets or sets the parent backdrop image tags.
  @HiveField(54)
  List<String>? parentBackdropImageTags;

  /// Gets or sets the local trailer count.
  @HiveField(55)
  int? localTrailerCount;

  /// User data for this item based on the user it's being requested for.
  @HiveField(56)
  UserItemDataDto? userData;

  /// Gets or sets the recursive item count.
  @HiveField(57)
  int? recursiveItemCount;

  /// Gets or sets the child count.
  @HiveField(58)
  int? childCount;

  /// Gets or sets the name of the series.
  @HiveField(59)
  String? seriesName;

  /// Gets or sets the series id.
  @HiveField(60)
  String? seriesId;

  /// Gets or sets the season identifier.
  @HiveField(61)
  String? seasonId;

  /// Gets or sets the special feature count.
  @HiveField(62)
  int? specialFeatureCount;

  /// Gets or sets the display preferences id.
  @HiveField(63)
  String? displayPreferencesId;

  /// Gets or sets the status.
  @HiveField(64)
  String? status;

  /// Gets or sets the air time.
  @HiveField(65)
  String? airTime;

  /// Items Enum: "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday"
  /// "Saturday"
  /// Gets or sets the air days.
  @HiveField(66)
  List<String>? airDays;

  /// Gets or sets the tags.
  @HiveField(67)
  List<String>? tags;

  /// Gets or sets the primary image aspect ratio, after image enhancements.
  @HiveField(68)
  double? primaryImageAspectRatio;

  /// Gets or sets the artists.
  @HiveField(69)
  List<String>? artists;

  /// Gets or sets the artist items.
  @HiveField(70)
  List<NameIdPair>? artistItems;

  /// Gets or sets the album.
  @HiveField(71)
  String? album;

  /// Gets or sets the type of the collection.
  @HiveField(72)
  String? collectionType;

  /// Gets or sets the display order.
  @HiveField(73)
  String? displayOrder;

  /// Gets or sets the album id.
  @HiveField(74)
  BaseItemId? albumId;

  /// Gets or sets the album image tag.
  @HiveField(75)
  String? albumPrimaryImageTag;

  /// Gets or sets the series primary image tag.
  @HiveField(76)
  String? seriesPrimaryImageTag;

  /// Gets or sets the album artist.
  @HiveField(77)
  String? albumArtist;

  /// Gets or sets the album artists.
  @HiveField(78)
  List<NameIdPair>? albumArtists;

  /// Gets or sets the name of the season.
  @HiveField(79)
  String? seasonName;

  /// Gets or sets the media streams.
  @HiveField(80)
  List<MediaStream>? mediaStreams;

  /// Gets or sets the part count.
  @HiveField(81)
  int? partCount;

  /// Gets or sets the image tags.
  @HiveField(82)
  Map<dynamic, String>? imageTags;

  /// Gets or sets the backdrop image tags.
  @HiveField(83)
  List<String>? backdropImageTags;

  /// Gets or sets the parent logo image tag.
  @HiveField(84)
  String? parentLogoImageTag;

  /// If the item does not have a art, this will hold the Id of the Parent that
  /// has one.
  @HiveField(85)
  String? parentArtItemId;

  /// Gets or sets the parent art image tag.
  @HiveField(86)
  String? parentArtImageTag;

  /// Gets or sets the series thumb image tag.
  @HiveField(87)
  String? seriesThumbImageTag;

  /// Gets or sets the series studio.
  @HiveField(88)
  String? seriesStudio;

  /// Gets or sets the parent thumb item id.
  @HiveField(89)
  String? parentThumbItemId;

  /// Gets or sets the parent thumb image tag.
  @HiveField(90)
  String? parentThumbImageTag;

  /// Gets or sets the parent primary image item identifier.
  @HiveField(91)
  String? parentPrimaryImageItemId;

  /// Gets or sets the parent primary image tag.
  @HiveField(92)
  String? parentPrimaryImageTag;

  /// Gets or sets the chapters.
  @HiveField(93)
  List<ChapterInfo>? chapters;

  /// Enum: "FileSystem" "Remote" "Virtual" "Offline"
  /// Gets or sets the type of the location.
  @HiveField(94)
  String? locationType;

  /// Gets or sets the type of the media.
  @HiveField(95)
  String? mediaType;

  /// Gets or sets the end date.
  @HiveField(96)
  String? endDate;

  /// Items Enum: "Cast" "Genres" "ProductionLocations" "Studios" "Tags" "Name"
  /// "Overview" "Runtime" "OfficialRating"
  /// Gets or sets the locked fields.
  @HiveField(97)
  List<String>? lockedFields;

  /// Gets or sets a value indicating whether [enable internet providers].
  @HiveField(98)
  bool? lockData;

  @HiveField(99)
  int? width;

  @HiveField(100)
  int? height;

  @HiveField(101)
  String? cameraMake;

  @HiveField(102)
  String? cameraModel;

  @HiveField(103)
  String? software;

  @HiveField(104)
  double? exposureTime;

  @HiveField(105)
  double? focalLength;

  /// Enum: "TopLeft" "TopRight" "BottomRight" "BottomLeft" "LeftTop" "RightTop"
  /// "RightBottom" "LeftBottom"
  @HiveField(106)
  String? imageOrientation;

  @HiveField(107)
  double? aperture;

  @HiveField(108)
  double? shutterSpeed;

  @HiveField(109)
  double? latitude;

  @HiveField(110)
  double? longitude;

  @HiveField(111)
  double? altitude;

  @HiveField(112)
  int? isoSpeedRating;

  /// Gets or sets the series timer identifier.
  @HiveField(113)
  String? seriesTimerId;

  /// Gets or sets the channel primary image tag.
  @HiveField(114)
  String? channelPrimaryImageTag;

  /// The start date of the recording, in UTC.
  @HiveField(115)
  String? startDate;

  /// Gets or sets the completion percentage.
  @HiveField(116)
  double? completionPercentage;

  /// Gets or sets a value indicating whether this instance is repeat.
  @HiveField(117)
  bool? isRepeat;

  /// Gets or sets the episode title.
  @HiveField(118)
  String? episodeTitle;

  /// Gets or sets a value indicating whether this instance is movie.
  @HiveField(119)
  bool? isMovie;

  /// Gets or sets a value indicating whether this instance is sports.
  @HiveField(120)
  bool? isSports;

  /// Gets or sets a value indicating whether this instance is series.
  @HiveField(121)
  bool? isSeries;

  /// Gets or sets a value indicating whether this instance is live.
  @HiveField(122)
  bool? isLive;

  /// Gets or sets a value indicating whether this instance is news.
  @HiveField(123)
  bool? isNews;

  /// Gets or sets a value indicating whether this instance is kids.
  @HiveField(124)
  bool? isKids;

  /// Gets or sets a value indicating whether this instance is premiere.
  @HiveField(125)
  bool? isPremiere;

  /// Gets or sets the timer identifier.
  @HiveField(126)
  String? timerId;

  /// Gets or sets the current program.
  @HiveField(127)
  dynamic currentProgram;

  /// Gets or sets the movie count.
  @HiveField(128)
  int? movieCount;

  /// Gets or sets the series count.
  @HiveField(129)
  int? seriesCount;

  /// Gets or sets the album count.
  @HiveField(130)
  int? albumCount;

  /// Gets or sets the track count.
  @HiveField(131)
  int? songCount;

  /// Gets or sets the music video count.
  @HiveField(132)
  int? musicVideoCount;

  // Below fields were added during null safety migration (0.5.0)

  /// Gets or sets the type of the source.
  @HiveField(133)
  String? sourceType;

  @HiveField(134)
  String? dateLastMediaAdded;

  @HiveField(135)
  bool? enableMediaSourceDisplay;

  /// Gets or sets the cumulative run time ticks.
  @HiveField(136)
  int? cumulativeRunTimeTicks;

  /// Gets or sets a value indicating whether this instance is place holder.
  @HiveField(137)
  bool? isPlaceHolder;

  /// Gets or sets a value indicating whether this instance is HD.
  @HiveField(138)
  bool? isHD;

  /// Enum: "VideoFile" "Iso" "Dvd" "BluRay"
  /// Gets or sets the type of the video.
  @HiveField(139)
  String? videoType;

  @HiveField(140)
  int? mediaSourceCount;

  /// Gets or sets the screenshot image tags.
  @HiveField(141)
  List<String>? screenshotImageTags;

  /// Gets or sets the blurhashes for the image tags. Maps image type to
  /// dictionary mapping image tag to blurhash value.
  @HiveField(142)
  ImageBlurHashes? imageBlurHashes;

  /// Enum: "Dvd" "BluRay"
  /// Gets or sets the type of the iso.
  @HiveField(143)
  String? isoType;

  /// Gets or sets the trailer count.
  @HiveField(144)
  int? trailerCount;

  @HiveField(145)
  int? programCount;

  /// Gets or sets the episode count.
  @HiveField(146)
  int? episodeCount;

  @HiveField(147)
  int? artistCount;

  /// Gets or sets the program identifier.
  @HiveField(148)
  String? programId;

  /// Enum: "TV" "Radio"
  /// Gets or sets the type of the channel.
  @HiveField(149)
  String? channelType;

  /// Enum: "Mono" "Stereo" "Dolby" "DolbyDigital" "Thx" "Atmos"
  /// Gets or sets the audio.
  @HiveField(150)
  String? audio;

  /// normalization gain (Loudness Unit Full Scale) for audio loudness normalization, similar to decibel but calculated differently.
  /// Gets or sets the normalization gain value.
  @HiveField(151)
  double? normalizationGain;

  /// Gets or sets the HasLyrics value.
  @HiveField(152)
  bool? hasLyrics;

  /// Custom helper field to determine if the BaseItemDto was created in offline mode
  bool? finampOffline;

  /// Checks if the item has its own image (not inherited from a parent)
  bool get hasOwnImage => imageTags?.containsKey("Primary") ?? false;

  /// String form of [productionYear], with substitution if null
  String get productionYearString => productionYear?.toString() ?? "Unknown Year";

  /// Gets the image id of a given item. If the item has its own image, it will
  /// return the item id. Otherwise, if the item's parent has an image ID, it
  /// returns that ID. Otherwise, if the item is an album and has an album ID,
  /// it will return that. If the item meets none of these conditions, this
  /// function will return null.
  String? get imageId {
    if (hasOwnImage) {
      return id.raw;
    } else if (parentPrimaryImageItemId != null) {
      return parentPrimaryImageItemId;
    } else if (albumId != null && albumPrimaryImageTag != null) {
      return albumId?.raw;
    }
    return null;
  }

  /// Whether or not the item is an artist
  bool get isArtist => type == "MusicArtist";

  /// The first primary blurhash of this item.
  String? get blurHash => imageBlurHashes?.primary?.values.first;

  /// The name of the track to use when sorting. This getter strips words that
  /// are removed by Jellyfin (the, a, an).
  String? get nameForSorting {
    // sortName seems to be of the form {4 digit track number} - {track Name} for tracks
    // It seems the server uses the unstripped regular name to work around this in some
    // cases?
    if (sortName != null && type != "Audio") {
      return sortName;
    }

    if (name == null) {
      return null;
    }

    if (type == "Audio") {
      return name!.toLowerCase();
    }

    // https://github.com/jellyfin/jellyfin/blob/054f42332d8e0c45fb899eeaef982aa0fd549397/MediaBrowser.Model/Configuration/ServerConfiguration.cs#L129
    // Should probably also do SortRemoveCharacters?
    // spaces needed to prevent stipping leading prefixes from other words
    const sortRemoveWords = ["the ", "a ", "an "];

    for (final word in sortRemoveWords) {
      if (name!.toLowerCase().startsWith(word)) {
        var strippedName = name!.substring(word.length);

        // Remove any leading spaces that could've occured due to removing prefixes.
        // For example, "The Black Parade" shouldn't become " Black Parade"
        strippedName = strippedName.trimLeft();

        return strippedName.toLowerCase();
      }
    }

    return name!.toLowerCase();
  }

  static BaseItemDto fromPlayableItem(PlayableItem item) {
    switch (item) {
      case AlbumDisc():
        return item.parent;
      case BaseItemDto():
        return item;
    }
  }

  factory BaseItemDto.fromJson(Map<String, dynamic> json) => _$BaseItemDtoFromJson(json);
  Map<String, dynamic> toJson({bool setOffline = true}) {
    var json = _$BaseItemDtoToJson(this);
    if (setOffline) {
      json["FinampOffline"] = true;
    }
    return json;
  }

  bool mostlyEqual(BaseItemDto other) {
    var equal = const DeepCollectionEquality().equals;
    return other.name == name &&
        equal(other.genres, genres) &&
        equal(other.artists, artists) &&
        other.albumArtist == albumArtist &&
        other.childCount == childCount &&
        other.imageId == imageId &&
        // imageId does not necessarily change when the image is updated, so
        // we must compare blurHashes as well.
        other.blurHash == blurHash &&
        other.mediaSources?.length == mediaSources?.length &&
        other.mediaStreams?.length == mediaStreams?.length &&
        other.normalizationGain == normalizationGain &&
        other.playlistItemId == playlistItemId;
  }

  DownloadItemType get downloadType => BaseItemDtoType.fromItem(this).downloadType!;

  static const _explicitRatings = [
    "XXX",
    "16",
    "18",
    "21",
    "FSK 16",
    "FSK-16",
    "FSK 18",
    "FSK-18",
    "E",
    "Explicit",
  ]; // the last two don't exist yet, but could easily be added server-side
  bool get isExplicit => _explicitRatings.contains(officialRating) || _explicitRatings.contains(customRating);

  // BaseItemDtos with the same id should be considered equal so that Providers
  // taking the BaseItemDto as an argument will be shared across all instances
  @override
  bool operator ==(Object other) {
    return other is BaseItemDto && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 29)
class ExternalUrl {
  ExternalUrl({this.name, this.url});

  @HiveField(0)
  String? name;

  @HiveField(1)
  String? url;

  factory ExternalUrl.fromJson(Map<String, dynamic> json) => _$ExternalUrlFromJson(json);
  Map<String, dynamic> toJson() => _$ExternalUrlToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  includeIfNull: false,
  converters: [BaseItemIdConverter()],
)
@HiveType(typeId: 5)
class MediaSourceInfo with RunTimeTickDuration {
  MediaSourceInfo({
    required this.protocol,
    this.id,
    this.path,
    this.encoderPath,
    this.encoderProtocol,
    required this.type,
    this.container,
    this.size,
    this.name,
    required this.isRemote,
    this.runTimeTicks,
    required this.supportsTranscoding,
    required this.supportsDirectStream,
    required this.supportsDirectPlay,
    required this.isInfiniteStream,
    required this.requiresOpening,
    this.openToken,
    required this.requiresClosing,
    this.liveStreamId,
    this.bufferMs,
    required this.requiresLooping,
    required this.supportsProbing,
    this.video3DFormat,
    required this.mediaStreams,
    this.formats,
    this.bitrate,
    this.timestamp,
    this.requiredHttpHeaders,
    this.transcodingUrl,
    this.transcodingSubProtocol,
    this.transcodingContainer,
    this.analyzeDurationMs,
    required this.readAtNativeFramerate,
    this.defaultAudioStreamIndex,
    this.defaultSubtitleStreamIndex,
    this.etag,
    required this.ignoreDts,
    required this.ignoreIndex,
    required this.genPtsInput,
    this.videoType,
    this.isoType,
    this.mediaAttachments,
  });

  /// Enum: "File" "Http" "Rtmp" "Rtsp" "Udp" "Rtp" "Ftp"
  @HiveField(0)
  String protocol;

  @HiveField(1)
  BaseItemId? id;

  @HiveField(2)
  String? path;

  @HiveField(3)
  String? encoderPath;

  /// Enum: "File" "Http" "Rtmp" "Rtsp" "Udp" "Rtp" "Ftp"
  @HiveField(4)
  String? encoderProtocol;

  /// Enum: "Default" "Grouping" "Placeholder"
  @HiveField(5)
  String type;

  @HiveField(6)
  String? container;

  @HiveField(7)
  int? size;

  @HiveField(8)
  String? name;

  /// Differentiate internet url vs local network.
  @HiveField(9)
  bool isRemote;

  @override
  @HiveField(10)
  int? runTimeTicks;

  @HiveField(11)
  bool supportsTranscoding;

  @HiveField(12)
  bool supportsDirectStream;

  @HiveField(13)
  bool supportsDirectPlay;

  @HiveField(14)
  bool isInfiniteStream;

  @HiveField(15)
  bool requiresOpening;

  @HiveField(16)
  String? openToken;

  @HiveField(17)
  bool requiresClosing;

  @HiveField(18)
  String? liveStreamId;

  @HiveField(19)
  int? bufferMs;

  @HiveField(20)
  bool requiresLooping;

  @HiveField(21)
  bool supportsProbing;

  /// Enum: "HalfSideBySide" "FullSideBySide" "FullTopAndBottom"
  /// "HalfTopAndBottom" "MVC"
  @HiveField(22)
  String? video3DFormat;

  @HiveField(23)
  List<MediaStream> mediaStreams;

  @HiveField(24)
  List<String>? formats;

  @HiveField(25)
  int? bitrate;

  /// Enum: "None" "Zero" "Valid"
  @HiveField(26)
  String? timestamp;

  @HiveField(27)
  Map<dynamic, String>? requiredHttpHeaders;

  @HiveField(28)
  String? transcodingUrl;

  @HiveField(29)
  String? transcodingSubProtocol;

  @HiveField(30)
  String? transcodingContainer;

  @HiveField(31)
  int? analyzeDurationMs;

  @HiveField(32)
  bool readAtNativeFramerate;

  @HiveField(33)
  int? defaultAudioStreamIndex;

  @HiveField(34)
  int? defaultSubtitleStreamIndex;

  // Below fields were added during null safety migration (0.5.0)

  @HiveField(35)
  String? etag;

  @HiveField(36)
  bool ignoreDts;

  @HiveField(37)
  bool ignoreIndex;

  @HiveField(38)
  bool genPtsInput;

  /// Enum: "VideoFile" "Iso" "Dvd" "BluRay"
  /// Enum VideoType.
  @HiveField(39)
  String? videoType;

  /// Enum: "Dvd" "BluRay"
  /// Enum IsoType.
  @HiveField(40)
  String? isoType;

  @HiveField(41)
  List<MediaAttachment>? mediaAttachments;

  /// The file size of the source if it was transcoded with [bitrate] (in bits
  /// per second).
  ///
  /// This function gets the channels from the first audio stream - other audio
  /// streams are ignored. If the item has multiple audio streams, this may be
  /// an issue as they are not counted in the size. Attachments are also not
  /// counted, as [mediaStreams] doesn't seem to note their size.
  int transcodedSize(int Function(int channels) bitrateChannels) {
    final channels = mediaStreams.firstWhere((element) => element.type == "Audio").channels ?? 2;
    final bitrate = bitrateChannels(channels);

    // Divide by 8 to get bytes/sec
    return (runTimeTicksDuration()?.inSeconds ?? 0) * bitrate ~/ 8;
  }

  factory MediaSourceInfo.fromJson(Map<String, dynamic> json) => _$MediaSourceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$MediaSourceInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true, includeIfNull: false)
@HiveType(typeId: 6)
class MediaStream {
  MediaStream({
    this.codec,
    this.codecTag,
    this.language,
    this.colorTransfer,
    this.colorPrimaries,
    this.colorSpace,
    this.comment,
    this.timeBase,
    this.codecTimeBase,
    this.title,
    this.videoRange,
    this.displayTitle,
    this.nalLengthSize,
    required this.isInterlaced,
    this.isAVC,
    this.channelLayout,
    this.bitRate,
    this.bitDepth,
    this.refFrames,
    this.packetLength,
    this.channels,
    this.sampleRate,
    required this.isDefault,
    required this.isForced,
    this.height,
    this.width,
    this.averageFrameRate,
    this.realFrameRate,
    this.profile,
    required this.type,
    this.aspectRatio,
    required this.index,
    this.score,
    required this.isExternal,
    this.deliveryMethod,
    this.deliveryUrl,
    this.isExternalUrl,
    required this.isTextSubtitleStream,
    required this.supportsExternalStream,
    this.path,
    this.pixelFormat,
    this.level,
    this.isAnamorphic,
  });

  /// Gets or sets the codec.
  @HiveField(0)
  String? codec;

  /// Gets or sets the codec tag.
  @HiveField(1)
  String? codecTag;

  /// Gets or sets the language.
  @HiveField(2)
  String? language;

  /// Gets or sets the color transfer.
  @HiveField(3)
  String? colorTransfer;

  /// Gets or sets the color primaries.
  @HiveField(4)
  String? colorPrimaries;

  /// Gets or sets the color space.
  @HiveField(5)
  String? colorSpace;

  /// Gets or sets the comment.
  @HiveField(6)
  String? comment;

  /// Gets or sets the time base.
  @HiveField(7)
  String? timeBase;

  /// Gets or sets the codec time base.
  @HiveField(8)
  String? codecTimeBase;

  /// Gets or sets the title.
  @HiveField(9)
  String? title;

  /// Gets or sets the video range.
  @HiveField(10)
  String? videoRange;

  @HiveField(11)
  String? displayTitle;

  @HiveField(12)
  String? nalLengthSize;

  /// Gets or sets a value indicating whether this instance is interlaced.
  @HiveField(13)
  bool isInterlaced;

  @HiveField(14)
  bool? isAVC;

  /// Gets or sets the channel layout.
  @HiveField(15)
  String? channelLayout;

  /// Gets or sets the bit rate.
  @HiveField(16)
  int? bitRate;

  /// Gets or sets the bit depth.
  @HiveField(17)
  int? bitDepth;

  /// Gets or sets the reference frames.
  @HiveField(18)
  int? refFrames;

  /// Gets or sets the length of the packet.
  @HiveField(19)
  int? packetLength;

  /// Gets or sets the channels.
  @HiveField(20)
  int? channels;

  /// Gets or sets the sample rate.
  @HiveField(21)
  int? sampleRate;

  /// Gets or sets a value indicating whether this instance is default.
  @HiveField(22)
  bool isDefault;

  /// Gets or sets a value indicating whether this instance is forced.
  @HiveField(23)
  bool isForced;

  /// Gets or sets the height.
  @HiveField(24)
  int? height;

  /// Gets or sets the width.
  @HiveField(25)
  int? width;

  /// Gets or sets the average frame rate.
  @HiveField(26)
  double? averageFrameRate;

  /// Gets or sets the real frame rate.
  @HiveField(27)
  double? realFrameRate;

  /// Gets or sets the profile.
  @HiveField(28)
  String? profile;

  /// Enum: "Audio" "Video" "Subtitle" "EmbeddedImage" "Data" "Lyric"
  /// Gets or sets the type.
  @HiveField(29)
  String type;

  /// Gets or sets the aspect ratio.
  @HiveField(30)
  String? aspectRatio;

  /// Gets or sets the index.
  @HiveField(31)
  int index;

  /// Gets or sets the score.
  @HiveField(32)
  int? score;

  /// Gets or sets a value indicating whether this instance is external.
  @HiveField(33)
  bool isExternal;

  /// Enum: "Encode" "Embed" "External" "Hls"
  /// Gets or sets the method.
  @HiveField(34)
  String? deliveryMethod;

  /// Gets or sets the delivery URL.
  @HiveField(35)
  String? deliveryUrl;

  /// Gets or sets a value indicating whether this instance is external URL.
  @HiveField(36)
  bool? isExternalUrl;

  @HiveField(37)
  bool isTextSubtitleStream;

  /// Gets or sets a value indicating whether [supports external stream].
  @HiveField(38)
  bool supportsExternalStream;

  /// Gets or sets the filename.
  @HiveField(39)
  String? path;

  /// Gets or sets the pixel format.
  @HiveField(40)
  String? pixelFormat;

  /// Gets or sets the level.
  @HiveField(41)
  double? level;

  /// Gets a value indicating whether this instance is anamorphic.
  @HiveField(42)
  bool? isAnamorphic;

  // Below fields were added during null safety migration (0.5.0)

  /// Gets or sets the color range.
  @HiveField(43)
  String? colorRange;

  @HiveField(44)
  String? localizedUndefined;

  @HiveField(45)
  String? localizedDefault;

  @HiveField(46)
  String? localizedForced;

  factory MediaStream.fromJson(Map<String, dynamic> json) => _$MediaStreamFromJson(json);
  Map<String, dynamic> toJson() => _$MediaStreamToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 47)
class MediaUrl {
  MediaUrl({this.url, this.name});

  String? url;

  String? name;

  factory MediaUrl.fromJson(Map<String, dynamic> json) => _$MediaUrlFromJson(json);
  Map<String, dynamic> toJson() => _$MediaUrlToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  converters: [BaseItemIdConverter()],
)
@HiveType(typeId: 48)
class BaseItemPerson {
  BaseItemPerson({this.name, this.id, this.role, this.type, this.primaryImageTag});

  /// Gets or sets the name.
  String? name;

  /// Gets or sets the identifier.
  String? id;

  /// Gets or sets the role.
  String? role;

  /// Gets or sets the type.
  String? type;

  /// Gets or sets the primary image tag.
  String? primaryImageTag;

  /// Gets or sets the primary image blurhash.
  ImageBlurHashes? imageBlurHashes;

  factory BaseItemPerson.fromJson(Map<String, dynamic> json) => _$BaseItemPersonFromJson(json);
  Map<String, dynamic> toJson() => _$BaseItemPersonToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  converters: [BaseItemIdConverter()],
)
@HiveType(typeId: 30)
class NameLongIdPair {
  NameLongIdPair({this.name, required this.id});

  @HiveField(0)
  String? name;

  @HiveField(1)
  BaseItemId id;

  factory NameLongIdPair.fromJson(Map<String, dynamic> json) => _$NameLongIdPairFromJson(json);
  Map<String, dynamic> toJson() => _$NameLongIdPairToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true, includeIfNull: false)
@HiveType(typeId: 1)
class UserItemDataDto {
  UserItemDataDto({
    this.rating,
    this.playedPercentage,
    this.unplayedItemCount,
    required this.playbackPositionTicks,
    required this.playCount,
    required this.isFavorite,
    this.likes,
    this.lastPlayedDate,
    required this.played,
    this.key,
    this.itemId,
  });

  /// Gets or sets the rating.
  @HiveField(0)
  double? rating;

  /// Gets or sets the played percentage.
  @HiveField(1)
  double? playedPercentage;

  /// Gets or sets the unplayed item count.
  @HiveField(2)
  int? unplayedItemCount;

  /// Gets or sets the playback position ticks.
  @HiveField(3)
  int playbackPositionTicks;

  /// Gets or sets the play count.
  @HiveField(4)
  int playCount;

  /// Gets or sets a value indicating whether this instance is favorite.
  @HiveField(5)
  bool isFavorite;

  /// Gets or sets a value indicating whether this
  /// MediaBrowser.Model.Dto.UserItemDataDto is likes.
  @HiveField(6)
  bool? likes;

  /// Gets or sets the last played date.
  @HiveField(7)
  String? lastPlayedDate;

  /// Gets or sets a value indicating whether this
  /// MediaBrowser.Model.Dto.UserItemDataDto is played.
  @HiveField(8)
  bool played;

  /// Gets or sets the key.
  @HiveField(9)
  String? key;

  /// Gets or sets the item identifier.
  @HiveField(10)
  String? itemId;

  factory UserItemDataDto.fromJson(Map<String, dynamic> json) => _$UserItemDataDtoFromJson(json);
  Map<String, dynamic> toJson() => _$UserItemDataDtoToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  converters: [BaseItemIdConverter()],
)
@HiveType(typeId: 2)
class NameIdPair {
  NameIdPair({this.name, required this.id});

  @HiveField(0)
  String? name;

  @HiveField(1)
  BaseItemId id;

  factory NameIdPair.fromJson(Map<String, dynamic> json) => _$NameIdPairFromJson(json);
  Map<String, dynamic> toJson() => _$NameIdPairToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class ChapterInfo {
  ChapterInfo({
    required this.startPositionTicks,
    this.name,
    this.imageTag,
    this.imagePath,
    required this.imageDateModified,
  });

  /// Gets or sets the start position ticks.
  int startPositionTicks;

  /// Gets or sets the name.
  String? name;

  String? imageTag;

  // Below fields were added during null safety migration (0.5.0)

  /// Gets or sets the image path.
  String? imagePath;

  String imageDateModified;

  factory ChapterInfo.fromJson(Map<String, dynamic> json) => _$ChapterInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ChapterInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
// ignore: camel_case_types
class QueryResult_BaseItemDto {
  QueryResult_BaseItemDto({this.items, required this.totalRecordCount, required this.startIndex});

  /// Gets or sets the items.
  List<BaseItemDto>? items;

  /// The total number of records available.
  int totalRecordCount;

  /// The index of the first record in Items.
  int startIndex;

  factory QueryResult_BaseItemDto.fromJson(Map<String, dynamic> json) => _$QueryResult_BaseItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$QueryResult_BaseItemDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class PlaybackInfoResponse {
  PlaybackInfoResponse({this.mediaSources, this.playSessionId, this.errorCode});

  /// Gets or sets the media sources.
  List<MediaSourceInfo>? mediaSources;

  /// Gets or sets the play session identifier.
  String? playSessionId;

  /// Enum: "NotAllowed" "NoCompatibleStream" "RateLimitExceeded"
  /// Gets or sets the error code.
  String? errorCode;

  factory PlaybackInfoResponse.fromJson(Map<String, dynamic> json) => _$PlaybackInfoResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PlaybackInfoResponseToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  converters: [BaseItemIdConverter()],
)
class PlaybackProgressInfo {
  PlaybackProgressInfo({
    this.canSeek = true,
    this.item,
    required this.itemId,
    this.sessionId,
    this.mediaSourceId,
    this.audioStreamIndex,
    this.subtitleStreamIndex,
    required this.isPaused,
    required this.isMuted,
    this.positionTicks,
    this.playbackStartTimeTicks,
    this.volumeLevel,
    this.brightness,
    this.aspectRatio,
    this.playMethod = "DirectPlay",
    this.liveStreamId,
    this.playSessionId,
    required this.repeatMode,
    this.playbackOrder = "Default",
    this.nowPlayingQueue,
    this.playlistItemId,
  });

  /// Gets or sets a value indicating whether this instance can seek.
  bool canSeek;

  /// Gets or sets the item.
  BaseItemDto? item;

  /// Gets or sets the item identifier.
  BaseItemId itemId;

  /// Gets or sets the session id.
  String? sessionId;

  /// Gets or sets the media version identifier.
  String? mediaSourceId;

  /// Gets or sets the index of the audio stream.
  int? audioStreamIndex;

  /// Gets or sets the index of the subtitle stream.
  int? subtitleStreamIndex;

  /// Gets or sets a value indicating whether this instance is paused.
  bool isPaused;

  /// Gets or sets a value indicating whether this instance is muted.
  bool isMuted;

  /// Gets or sets the position ticks.
  int? positionTicks;

  int? playbackStartTimeTicks;

  /// Gets or sets the volume level.
  int? volumeLevel;

  int? brightness;

  String? aspectRatio;

  /// Enum: "Transcode" "DirectStream" "DirectPlay"
  /// Gets or sets the play method.
  String playMethod;

  /// Enum: "Default" "Shuffle"
  /// Gets or sets the playback order.
  String playbackOrder;

  /// Gets or sets the live stream identifier.
  String? liveStreamId;

  /// Gets or sets the play session identifier.
  String? playSessionId;

  /// Enum: "RepeatNone" "RepeatAll" "RepeatOne"
  /// Gets or sets the repeat mode.
  String repeatMode;

  List<QueueItem>? nowPlayingQueue;

  String? playlistItemId;

  factory PlaybackProgressInfo.fromJson(Map<String, dynamic> json) => _$PlaybackProgressInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PlaybackProgressInfoToJson(this);
}

@HiveType(typeId: 32)
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true, includeIfNull: false)
class ImageBlurHashes {
  ImageBlurHashes({
    this.primary,
    this.art,
    this.backdrop,
    this.banner,
    this.logo,
    this.thumb,
    this.disc,
    this.box,
    this.screenshot,
    this.menu,
    this.chapter,
    this.boxRear,
    this.profile,
  });

  @HiveField(0)
  Map<String, String>? primary;

  @HiveField(1)
  Map<String, String>? art;

  @HiveField(2)
  Map<String, String>? backdrop;

  @HiveField(3)
  Map<String, String>? banner;

  @HiveField(4)
  Map<String, String>? logo;

  @HiveField(5)
  Map<String, String>? thumb;

  @HiveField(6)
  Map<String, String>? disc;

  @HiveField(7)
  Map<String, String>? box;

  @HiveField(8)
  Map<String, String>? screenshot;

  @HiveField(9)
  Map<String, String>? menu;

  @HiveField(10)
  Map<String, String>? chapter;

  @HiveField(11)
  Map<String, String>? boxRear;

  @HiveField(12)
  Map<String, String>? profile;

  factory ImageBlurHashes.fromJson(Map<String, dynamic> json) => _$ImageBlurHashesFromJson(json);
  Map<String, dynamic> toJson() => _$ImageBlurHashesToJson(this);
}

@HiveType(typeId: 33)
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class MediaAttachment {
  MediaAttachment({
    this.codec,
    this.codecTag,
    this.comment,
    required this.index,
    this.fileName,
    this.mimeType,
    this.deliveryUrl,
  });

  /// Gets or sets the codec.
  @HiveField(0)
  String? codec;

  /// Gets or sets the codec tag.
  @HiveField(1)
  String? codecTag;

  /// Gets or sets the comment.
  @HiveField(2)
  String? comment;

  /// Gets or sets the index.
  @HiveField(3)
  int index;

  /// Gets or sets the filename.
  @HiveField(4)
  String? fileName;

  /// Gets or sets the MIME type.
  @HiveField(5)
  String? mimeType;

  /// Gets or sets the delivery URL.
  @HiveField(6)
  String? deliveryUrl;

  factory MediaAttachment.fromJson(Map<String, dynamic> json) => _$MediaAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$MediaAttachmentToJson(this);
}

@HiveType(typeId: 34)
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class BaseItem {
  BaseItem({
    this.size,
    this.container,
    this.dateLastSaved,
    this.remoteTrailers,
    required this.isHD,
    required this.isShortcut,
    this.shortcutPath,
    this.width,
    this.height,
    this.extraIds,
    required this.supportsExternalTransfer,
  });

  @HiveField(0)
  int? size;

  @HiveField(1)
  String? container;

  @HiveField(2)
  String? dateLastSaved;

  /// Gets or sets the remote trailers.
  @HiveField(3)
  List<MediaUrl>? remoteTrailers;

  @HiveField(4)
  bool isHD;

  @HiveField(5)
  bool isShortcut;

  @HiveField(6)
  String? shortcutPath;

  @HiveField(7)
  int? width;

  @HiveField(8)
  int? height;

  @HiveField(9)
  List<String>? extraIds;

  @HiveField(10)
  bool supportsExternalTransfer;

  factory BaseItem.fromJson(Map<String, dynamic> json) => _$BaseItemFromJson(json);
  Map<String, dynamic> toJson() => _$BaseItemToJson(this);
}

@HiveType(typeId: 35)
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class QueueItem {
  QueueItem({required this.id, this.playlistItemId});

  @HiveField(0)
  String id;

  @HiveField(1)
  String? playlistItemId;

  factory QueueItem.fromJson(Map<String, dynamic> json) => _$QueueItemFromJson(json);
  Map<String, dynamic> toJson() => _$QueueItemToJson(this);
}

/// Class used to create new playlist. Not returned from Jellyfin.
@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  converters: [BaseItemIdConverter()],
)
class NewPlaylist {
  NewPlaylist({this.name, this.ids, this.userId, this.mediaType, this.isPublic});

  /// Gets or sets the name of the new playlist.
  String? name;

  /// Gets or sets item ids to add to the playlist.
  List<BaseItemId>? ids;

  /// Gets or sets the user id. Required when creating playlists, but not adding
  /// to them.
  String? userId;

  /// Gets or sets the media type.
  String? mediaType;

  /// Whether the playlist should be publicly visible
  bool? isPublic;

  factory NewPlaylist.fromJson(Map<String, dynamic> json) => _$NewPlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$NewPlaylistToJson(this);
}

/// Jellyfin response when creating new playlist.
@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  converters: [BaseItemIdConverter()],
)
class NewPlaylistResponse {
  NewPlaylistResponse({this.id});

  BaseItemId? id;

  factory NewPlaylistResponse.fromJson(Map<String, dynamic> json) => _$NewPlaylistResponseFromJson(json);
  Map<String, dynamic> toJson() => _$NewPlaylistResponseToJson(this);
}

/// Enum for sort types.
@HiveType(typeId: 37)
enum SortBy {
  @HiveField(0)
  album,
  @HiveField(1)
  albumArtist,
  @HiveField(2)
  artist,
  @HiveField(3)
  budget,
  @HiveField(4)
  communityRating,
  @HiveField(5)
  criticRating,
  @HiveField(6)
  dateCreated,
  @HiveField(7)
  datePlayed,
  @HiveField(8)
  playCount,
  @HiveField(9)
  premiereDate,
  @HiveField(10)
  productionYear,
  @HiveField(11)
  sortName,
  @HiveField(12)
  random,
  @HiveField(13)
  revenue,
  @HiveField(14)
  runtime,
  @HiveField(15)
  defaultOrder;

  static List<SortBy> defaultsFor({required TabContentType type, bool includeDefaultOrder = false}) {
    List<SortBy> options;

    switch (type) {
      case TabContentType.tracks:
        options = [
          SortBy.sortName,
          SortBy.album,
          SortBy.albumArtist,
          SortBy.artist,
          //SortBy.communityRating,
          //SortBy.criticRating,
          SortBy.premiereDate,
          SortBy.dateCreated,
          SortBy.datePlayed,
          SortBy.playCount,
          SortBy.runtime,
          SortBy.random,
        ];
      case TabContentType.albums:
        options = [
          SortBy.sortName,
          SortBy.albumArtist,
          //SortBy.communityRating,
          //SortBy.criticRating,
          //SortBy.datePlayed,
          SortBy.premiereDate,
          SortBy.dateCreated,
          SortBy.runtime,
          SortBy.random,
        ];
      case TabContentType.playlists:
      case TabContentType.artists:
        options = [
          SortBy.sortName,
          //SortBy.datePlayed,
          SortBy.dateCreated,
          SortBy.runtime,
          SortBy.random,
        ];
      case TabContentType.genres:
        options = [SortBy.sortName, SortBy.dateCreated, SortBy.random];
    }
    if (includeDefaultOrder) {
      options.insert(0, SortBy.defaultOrder);
    }
    return options;
  }

  /// Human-readable version of the [SortBy]. For example, toString() on
  /// [SortBy.album], toString() would return "SortBy.album". With this
  /// function, the same input would return "Album".
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => _humanReadableName(this);

  String toLocalisedString(BuildContext context) => _humanReadableLocalisedName(this, context);

  /// Name used by Jellyfin in API requests.
  String jellyfinName(TabContentType? contentType) {
    switch (contentType) {
      case TabContentType.albums:
        return _jellyfinNameMusicAlbums(this);
      case TabContentType.tracks:
        return _jellyfinNameTracks(this);
      default:
        return _jellyfinName(this);
    }
  }

  String _humanReadableName(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.album:
        return "Album";
      case SortBy.albumArtist:
        return "Album Artist";
      case SortBy.artist:
        return "Performing Artist";
      case SortBy.budget:
        return "Budget";
      case SortBy.communityRating:
        return "Community Rating";
      case SortBy.criticRating:
        return "Critic Rating";
      case SortBy.dateCreated:
        return "Date Added";
      case SortBy.datePlayed:
        return "Date Played";
      case SortBy.playCount:
        return "Play Count";
      case SortBy.premiereDate:
        return "Release Date";
      case SortBy.productionYear:
        return "Production Year";
      case SortBy.sortName:
        return "Name";
      case SortBy.random:
        return "Random";
      case SortBy.revenue:
        return "Revenue";
      case SortBy.runtime:
        return "Runtime";
      case SortBy.defaultOrder:
        return "Server Order";
    }
  }

  String _humanReadableLocalisedName(SortBy sortBy, BuildContext context) {
    switch (sortBy) {
      case SortBy.album:
        return AppLocalizations.of(context)!.album;
      case SortBy.albumArtist:
        return AppLocalizations.of(context)!.albumArtist;
      case SortBy.artist:
        return AppLocalizations.of(context)!.performingArtist;
      case SortBy.budget:
        return AppLocalizations.of(context)!.budget;
      case SortBy.communityRating:
        return AppLocalizations.of(context)!.communityRating;
      case SortBy.criticRating:
        return AppLocalizations.of(context)!.criticRating;
      case SortBy.dateCreated:
        return AppLocalizations.of(context)!.dateAdded;
      case SortBy.datePlayed:
        return AppLocalizations.of(context)!.datePlayed;
      case SortBy.playCount:
        return AppLocalizations.of(context)!.playCount;
      case SortBy.premiereDate:
        return AppLocalizations.of(context)!.premiereDate;
      case SortBy.productionYear:
        return AppLocalizations.of(context)!.productionYear;
      case SortBy.sortName:
        return AppLocalizations.of(context)!.name;
      case SortBy.random:
        return AppLocalizations.of(context)!.random;
      case SortBy.revenue:
        return AppLocalizations.of(context)!.revenue;
      case SortBy.runtime:
        return AppLocalizations.of(context)!.duration;
      case SortBy.defaultOrder:
        return AppLocalizations.of(context)!.defaultOrder;
    }
  }

  String _jellyfinName(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.album:
        return "Album";
      case SortBy.albumArtist:
        return "AlbumArtist";
      case SortBy.artist:
        return "Artist";
      case SortBy.budget:
        return "Budget";
      case SortBy.communityRating:
        return "CommunityRating";
      case SortBy.criticRating:
        return "CriticRating";
      case SortBy.dateCreated:
        return "DateCreated";
      case SortBy.datePlayed:
        return "DatePlayed";
      case SortBy.playCount:
        return "PlayCount";
      case SortBy.premiereDate:
        return "PremiereDate";
      case SortBy.productionYear:
        return "ProductionYear";
      case SortBy.sortName:
        return "SortName";
      case SortBy.random:
        return "Random";
      case SortBy.revenue:
        return "Revenue";
      case SortBy.runtime:
        return "Runtime";
      case SortBy.defaultOrder:
        return "";
    }
  }

  String _jellyfinNameMusicAlbums(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.album:
        return "Album";
      case SortBy.albumArtist:
        return "AlbumArtist,SortName";
      case SortBy.artist:
        return "Artist";
      case SortBy.budget:
        return "Budget";
      case SortBy.communityRating:
        return "CommunityRating,SortName";
      case SortBy.criticRating:
        return "CriticRating,SortName";
      case SortBy.dateCreated:
        return "DateCreated,SortName";
      case SortBy.datePlayed:
        return "DatePlayed";
      case SortBy.playCount:
        return "PlayCount";
      case SortBy.premiereDate:
        return "PremiereDate,SortName";
      case SortBy.productionYear:
        return "ProductionYear,PremiereDate,SortName";
      case SortBy.sortName:
        return "SortName";
      case SortBy.random:
        return "Random,SortName";
      case SortBy.revenue:
        return "Revenue";
      case SortBy.runtime:
        return "Runtime";
      case SortBy.defaultOrder:
        return "";
    }
  }

  String _jellyfinNameTracks(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.album:
        return "Album,SortName";
      case SortBy.albumArtist:
        return "AlbumArtist,Album,SortName";
      case SortBy.artist:
        return "Artist,Album,SortName";
      case SortBy.budget:
        return "Budget";
      case SortBy.communityRating:
        return "CommunityRating";
      case SortBy.criticRating:
        return "CriticRating";
      case SortBy.dateCreated:
        return "DateCreated,SortName";
      case SortBy.datePlayed:
        return "DatePlayed,SortName";
      case SortBy.playCount:
        return "PlayCount,SortName";
      case SortBy.premiereDate:
        return "PremiereDate,Album,ParentIndexNumber,IndexNumber,SortName";
      case SortBy.productionYear:
        return "ProductionYear";
      case SortBy.sortName:
        return "Name";
      case SortBy.random:
        return "Random";
      case SortBy.revenue:
        return "Revenue";
      case SortBy.runtime:
        return "Runtime,AlbumArtist,Album,SortName";
      case SortBy.defaultOrder:
        return "";
    }
  }

  IconData? getIcon() {
    switch (this) {
      case SortBy.album:
        return TablerIcons.disc;
      case SortBy.albumArtist:
      case SortBy.artist:
        return TablerIcons.user;
      case SortBy.communityRating:
      case SortBy.criticRating:
        return TablerIcons.chart_bar_popular;
      case SortBy.dateCreated:
        return TablerIcons.calendar_plus;
      case SortBy.datePlayed:
        return TablerIcons.clock;
      case SortBy.playCount:
        return TablerIcons.sum;
      case SortBy.premiereDate:
      case SortBy.productionYear:
        return TablerIcons.calendar;
      case SortBy.sortName:
        return TablerIcons.abc;
      case SortBy.random:
        return TablerIcons.arrows_shuffle;
      case SortBy.revenue:
        return TablerIcons.coins;
      case SortBy.runtime:
        return TablerIcons.stopwatch;
      case SortBy.defaultOrder:
        return TablerIcons.server;
      default:
        return null;
    }
  }
}

/// Enum for sort orders.
@HiveType(typeId: 38)
enum SortOrder {
  @HiveField(0)
  ascending,
  @HiveField(1)
  descending;

  /// Human-readable version of the [SortOrder]. For example, toString() on
  /// [SortOrder.ascending], toString() would return "SortOrder.ascending". With
  /// this function, the same input would return "Ascending". This function is
  /// also used in Jellyfin API calls, but another function will be needed when
  /// localisation support is added.
  @override
  String toString() => _humanReadableName(this);

  String _humanReadableName(SortOrder sortOrder) {
    switch (sortOrder) {
      case SortOrder.ascending:
        return "Ascending";
      case SortOrder.descending:
        return "Descending";
    }
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class PublicSystemInfoResult {
  PublicSystemInfoResult({
    this.localAddress,
    this.serverName,
    this.version,
    this.productName,
    this.operatingSystem,
    this.id,
    this.startupWizardCompleted,
  });

  @HiveField(0)
  String? localAddress;

  @HiveField(1)
  String? serverName;

  @HiveField(2)
  String? version;

  @HiveField(3)
  String? productName;

  @HiveField(4)
  String? operatingSystem;

  @HiveField(5)
  String? id;

  @HiveField(6)
  bool? startupWizardCompleted;

  factory PublicSystemInfoResult.fromJson(Map<String, dynamic> json) => _$PublicSystemInfoResultFromJson(json);
  Map<String, dynamic> toJson() => _$PublicSystemInfoResultToJson(this);
}

class PublicUsersResponse {
  PublicUsersResponse({required this.users});

  @HiveField(0)
  List<UserDto> users;
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class QuickConnectState {
  QuickConnectState({
    required this.authenticated,
    this.secret,
    this.code,
    this.deviceId,
    this.deviceName,
    this.appName,
    this.appVersion,
    this.dateAdded,
  });

  @HiveField(0)
  bool authenticated;

  @HiveField(1)
  String? secret;

  @HiveField(2)
  String? code;

  @HiveField(3)
  String? deviceId;

  @HiveField(4)
  String? deviceName;

  @HiveField(5)
  String? appName;

  @HiveField(6)
  String? appVersion;

  @HiveField(7)
  String? dateAdded;

  factory QuickConnectState.fromJson(Map<String, dynamic> json) => _$QuickConnectStateFromJson(json);
  Map<String, dynamic> toJson() => _$QuickConnectStateToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
class ClientDiscoveryResponse {
  ClientDiscoveryResponse({this.address, this.id, this.name, this.endpointAddress});

  String? address;

  String? id;

  String? name;

  String? endpointAddress;

  factory ClientDiscoveryResponse.fromJson(Map<String, dynamic> json) => _$ClientDiscoveryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ClientDiscoveryResponseToJson(this);
}

/// LyricMetadata model.
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 44)
class LyricMetadata {
  LyricMetadata({
    this.artist,
    this.album,
    this.title,
    this.author,
    this.length,
    this.by,
    this.offset,
    this.creator,
    this.version,
    this.isSynced,
  });

  /// Gets or sets the track artist.
  @HiveField(0)
  String? artist;

  /// Gets or sets the album this track is on.
  @HiveField(1)
  String? album;

  /// Gets or sets the title of the track.
  @HiveField(2)
  String? title;

  /// Gets or sets the author of the lyric data.
  @HiveField(3)
  String? author;

  /// Gets or sets the length of the track in ticks.
  @HiveField(4)
  int? length;

  /// Gets or sets who the LRC file was created by.
  @HiveField(5)
  String? by;

  /// Gets or sets the lyric offset compared to audio in ticks.
  @HiveField(6)
  int? offset;

  /// Gets or sets the software used to create the LRC file.
  @HiveField(7)
  String? creator;

  /// Gets or sets the version of the creator used.
  @HiveField(8)
  String? version;

  /// Gets or sets a value indicating whether this lyric is synced.
  @HiveField(9)
  bool? isSynced;

  factory LyricMetadata.fromJson(Map<String, dynamic> json) => _$LyricMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$LyricMetadataToJson(this);
}

/// Lyric model.
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 45)
class LyricLine {
  LyricLine({this.text, this.start, this.cues});

  /// Gets the text of this lyric line.
  @HiveField(0)
  String? text;

  /// Gets the start time in ticks.
  @HiveField(1)
  int? start;

  /// Gets the time-aligned cues for the song's lyrics.
  @HiveField(2)
  List<LyricLineCue>? cues;

  int get startMicros => start != null ? start! ~/ 10 : 0;

  factory LyricLine.fromJson(Map<String, dynamic> json) => _$LyricLineFromJson(json);
  Map<String, dynamic> toJson() => _$LyricLineToJson(this);
}

/// LyricResponse model.
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 46)
class LyricDto {
  LyricDto({this.metadata, this.lyrics});

  /// Gets or sets Metadata for the lyrics.
  @HiveField(0)
  LyricMetadata? metadata;

  /// Gets or sets a collection of individual lyric lines.
  @HiveField(1)
  List<LyricLine>? lyrics;

  factory LyricDto.fromJson(Map<String, dynamic> json) => _$LyricDtoFromJson(json);
  Map<String, dynamic> toJson() => _$LyricDtoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 49)
class LyricLineCue {
  LyricLineCue({required this.position, required this.start, this.endPosition, this.end});

  /// Gets the character index of the start of the lyric.
  @HiveField(0)
  int position;

  /// Gets the timestamp the lyric is synced to in ticks.
  @HiveField(1)
  int start;

  /// Gets the character index of the end of the lyric.
  @HiveField(2)
  int? endPosition;

  /// Gets the end timestamp the lyric is synced to in ticks.
  @HiveField(3)
  int? end;

  int get startMicros => start ~/ 10;

  int? get endMicros => end != null ? end! ~/ 10 : null;

  factory LyricLineCue.fromJson(Map<String, dynamic> json) => _$LyricLineCueFromJson(json);

  Map<String, dynamic> toJson() => _$LyricLineCueToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 102)
class PlaybackInfoRequest {
  PlaybackInfoRequest({
    this.userId,
    this.deviceProfile,
    this.startTimeTicks,
    this.maxStreamingBitrate,
    this.audioStreamIndex,
    this.subtitleStreamIndex,
    this.maxAudioChannels,
    this.mediaSourceId,
    this.liveStreamId,
    this.enableDirectPlay,
    this.enableDirectStream,
    this.enableTranscoding,
    this.allowVideoStreamCopy,
    this.allowAudioStreamCopy,
    this.autoOpenLiveStream,
    this.alwaysBurnInSubtitleWhenTranscoding,
  });

  final String? userId;
  final DeviceProfile? deviceProfile;
  final int? startTimeTicks;
  final int? maxStreamingBitrate;
  final int? audioStreamIndex;
  final int? subtitleStreamIndex;
  final int? maxAudioChannels;
  final String? mediaSourceId;
  final String? liveStreamId;
  final bool? enableDirectPlay;
  final bool? enableDirectStream;
  final bool? enableTranscoding;
  final bool? allowVideoStreamCopy;
  final bool? allowAudioStreamCopy;
  final bool? autoOpenLiveStream;
  final bool? alwaysBurnInSubtitleWhenTranscoding;

  factory PlaybackInfoRequest.fromJson(Map<String, dynamic> json) => _$PlaybackInfoRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PlaybackInfoRequestToJson(this);
}

@JsonSerializable(
  fieldRename: FieldRename.pascal,
  explicitToJson: true,
  anyMap: true,
  converters: [BaseItemIdConverter()],
)
@HiveType(typeId: 104)
class PlaylistInfo {
  PlaylistInfo({this.openAccess, this.shares, this.itemIds});

  @HiveField(0)
  bool? openAccess;

  @HiveField(1)
  List<PlaylistUser>? shares;

  @HiveField(2)
  List<BaseItemId>? itemIds;

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) => _$PlaylistInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 105)
class PlaylistUser {
  PlaylistUser({this.userId, this.canEdit});

  @HiveField(0)
  String? userId;

  @HiveField(1)
  bool? canEdit;

  factory PlaylistUser.fromJson(Map<String, dynamic> json) => _$PlaylistUserFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistUserToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true)
@HiveType(typeId: 106)
class PlaylistUsers {
  PlaylistUsers({this.users});

  @HiveField(0)
  List<PlaylistUser>? users;

  factory PlaylistUsers.fromJson(Map<String, dynamic> json) => _$PlaylistUsersFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistUsersToJson(this);
}
