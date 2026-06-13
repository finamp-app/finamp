import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:bits/bits.dart';
import 'package:collection/collection.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../builders/annotations.dart';
import '../components/MusicScreen/sort_and_filter_row.dart';
import '../services/finamp_settings_helper.dart';
import 'jellyfin_models.dart';
import 'migration_adapters.dart';
import 'music_models.dart';

part 'finamp_models.g.dart';

@HiveType(typeId: 8)
@collection
class FinampUser {
  FinampUser({
    required this.id,
    required this.publicAddress,
    required this.localAddress,
    required this.preferLocalNetwork,
    required this.isLocal,
    required this.accessToken,
    required this.serverId,
    this.currentViewId,
    this.views = const {},
  });

  @HiveField(0)
  String id;

  // @HiveField(1)
  // String baseUrl;
  @HiveField(1)
  @Name("baseUrl")
  String publicAddress;

  String get baseURL => isLocal && preferLocalNetwork ? localAddress : publicAddress;

  @HiveField(2)
  String accessToken;
  @HiveField(3)
  String serverId;
  @HiveField(4)
  @ignore
  BaseItemId? currentViewId;
  @Name("currentViewId")
  String? get isarCurrentViewId => currentViewId?.raw;
  set isarCurrentViewId(String? id) => currentViewId = id == null ? null : BaseItemId(id);
  @ignore
  @HiveField(5)
  Map<BaseItemId, BaseItemDto> views;

  @HiveField(7, defaultValue: DefaultSettings.localNetworkAddress)
  String localAddress;

  @HiveField(8, defaultValue: DefaultSettings.isLocal)
  bool isLocal;

  @HiveField(9, defaultValue: DefaultSettings.preferLocalNetwork)
  bool preferLocalNetwork;

  // We only need 1 user, the current user
  final Id isarId = 0;
  String get isarViews => jsonEncode(views);
  set isarViews(String json) => views = (jsonDecode(json) as Map<BaseItemId, dynamic>).map(
    (k, v) => MapEntry(k, BaseItemDto.fromJson(v as Map<String, dynamic>)),
  );

  @ignore
  BaseItemDto? get currentView => views[currentViewId];

  void update({bool? newIsLocal, String? newLocalAddress, String? newPublicAddress, bool? newPreferLocalNetwork}) {
    isLocal = newIsLocal ?? isLocal;
    localAddress = newLocalAddress ?? localAddress;
    publicAddress = newPublicAddress ?? publicAddress;
    preferLocalNetwork = newPreferLocalNetwork ?? preferLocalNetwork;
    GetIt.instance<FinampUserHelper>().saveUser(this);
  }
}

class DefaultSettings {
  // These consts are so that we can easily keep the same default for
  // FinampSettings's constructor and Hive's defaultValue.
  static const isOffline = false;
  static const themeMode = ThemeMode.system;
  static const amoledTheme = false;
  static const Locale? locale = null;
  static const Color? accentColor = null;
  static const shouldTranscode = false;
  static const transcodeBitrate = 320000;
  static const androidStopForegroundOnPause = true;
  static const onlyShowFavorites = false;
  static const trackShuffleItemCount = 250;

  /// Default track count for CarPlay and Siri shuffle. Lower than default
  /// for main app as the longer shuffle amount is slow over constrained
  /// CarPlay interface.
  static const quickShuffleItemCount = 30;
  static const volumeNormalizationActive = true;
  // Set the base gain to 6.0 dB, which will work against any tracks that have a normalization gain of -6.0 dB or lower. For higher gains this will cause the actual volume to be lower than it should be, since we can't compensate the volume upwards beyond 100%
  // Ideally the maximum gain in each library should be fetched from the server, and this volume should be adjusted accordingly to be the exact inverse, so that the quietest track in the library plays at 100% volume, and only louder tracks get their volume reduced
  static const volumeNormalizationIOSBaseGain = 6.0;
  static const volumeNormalizationMode = VolumeNormalizationMode.hybrid;
  static const contentViewType = ContentViewType.list;
  static const playbackSpeedVisibility = PlaybackSpeedVisibility.automatic;
  static const showTextOnGridView = true;
  static const sleepTimerDurationSeconds = 60 * 30;
  static const useCoverAsBackground = true;
  static const playerScreenCoverMinimumPadding = 1.5;
  static const showArtistsTracksSection = true;
  static const disableGesture = false;
  static const showFastScroller = true;
  static const autoExpandPlayerScreen = false;
  static const bufferDisableSizeConstraints = false;
  static const bufferDurationSeconds = 600;
  static const bufferSizeMegabytes = 50;
  static const tabOrder = [
    ContentType.home,
    ContentType.albums,
    ContentType.genericArtists,
    // Hidden by default
    ContentType.albumArtists,
    // Hidden by default
    ContentType.performingArtists,
    ContentType.playlists,
    ContentType.tracks,
    ContentType.genres,
  ];
  static const showTabs = {
    ContentType.home: true,
    ContentType.albums: true,
    ContentType.genericArtists: true,
    ContentType.albumArtists: false,
    ContentType.performingArtists: false,
    ContentType.playlists: true,
    ContentType.tracks: true,
    ContentType.genres: true,
  };
  static const itemSwipeActionLeftToRight = ItemSwipeActions.nothing;
  static const itemSwipeActionRightToLeft = ItemSwipeActions.addToNextUp;
  static const loopMode = FinampLoopMode.none;
  static const playbackSpeed = 1.0;
  static const playbackPitch = 1.0;
  static const syncPlaybackSpeedAndPitch = false;
  static const autoLoadLastQueueOnStartup = true;
  static const shouldTranscodeDownloads = TranscodeDownloadsSetting.ask;
  static const multichannelHandlingSetting = MultichannelHandlingSetting.stereoDownmixLossy;
  static const shouldRedownloadTranscodes = false;
  static const resyncOnStartup = true;
  static const splitScreenPlayerWidth = 400.0;
  static const enableVibration = true;
  static const prioritizeCoverFactor = 8.0;
  static const suppressPlayerPadding = false;
  static const hidePlayerBottomActions = false;
  static const reportQueueToServer = false;
  static const periodicPlaybackSessionUpdateFrequencySeconds = 150;
  static const playOnStaleDelay = 90;
  static const playOnReconnectionDelay = 5;
  static const enablePlayon = true;
  static const showArtistChipImage = true;
  static const trackOfflineFavorites = true;
  static const showProgressOnNowPlayingBar = true;
  static const startInstantMixForIndividualTracks = false;
  static const showLyricsTimestamps = true;
  static const lyricsAlignment = LyricsAlignment.start;
  static const lyricsFontSize = LyricsFontSize.medium;
  static const showLyricsScreenAlbumPrelude = true;
  static const showStopButtonOnMediaNotification = false;
  static const showShuffleButtonOnMediaNotification = true;
  static const showFavoriteButtonOnMediaNotification = true;
  static const showSeekControlsOnMediaNotification = true;
  static const keepScreenOnOption = KeepScreenOnOption.whileLyrics;
  static const keepScreenOnWhilePluggedIn = false;
  static const hasDownloadedPlaylistInfo = false;
  static const transcodingStreamingFormat = FinampTranscodingStreamingFormat.aacFragmentedMp4;
  static const featureChipsConfiguration = FinampFeatureChipsConfiguration(
    enabled: true,
    features: [
      FinampFeatureChipType.explicit,
      FinampFeatureChipType.playCount,
      FinampFeatureChipType.additionalPeople,
      FinampFeatureChipType.playbackMode,
      FinampFeatureChipType.codec,
      FinampFeatureChipType.bitRate,
      FinampFeatureChipType.bitDepth,
      FinampFeatureChipType.sampleRate,
      FinampFeatureChipType.size,
      FinampFeatureChipType.normalizationGain,
    ],
  );
  static const showCoversOnAlbumScreen = false;
  static const allowSplitScreen = true;
  static const requireWifiForDownloads = true;
  static const onlyShowFullyDownloaded = false;
  static const preferQuickSyncs = true;
  static const showDownloadsWithUnknownLibrary = true;
  static const downloadWorkers = 1;
  static const maxConcurrentDownloads = 5;
  static const downloadSizeWarningCutoff = 150;
  static const allowDeleteFromServer = false;
  static const oneLineMarqueeTextButton = false;
  static const showAlbumReleaseDateOnPlayerScreen = false;
  static const releaseDateFormat = ReleaseDateFormat.year;
  static const double currentVolume = 1.0;
  static const autoOffline = AutoOfflineOption.disconnected;
  static const autoOfflineListenerActive = true;
  static const audioFadeOutDuration = Duration(milliseconds: 0);
  static const audioFadeInDuration = Duration(milliseconds: 0);
  static const defaultArtistType = ArtistType.albumArtist;
  static const isLocal = false;
  static const preferLocalNetwork = false;
  static const localNetworkAddress = "http://0.0.0.0:8096";
  static const autoReloadQueue = false;
  static const genreCuratedItemSelectionTypeTracks = CuratedItemSelectionType.mostPlayed;
  static const genreCuratedItemSelectionTypeAlbums = CuratedItemSelectionType.latestReleases;
  static const genreCuratedItemSelectionTypeArtists = CuratedItemSelectionType.favorites;
  static const genreItemSectionsOrder = GenreItemSections.values;
  static const genreFilterArtistScreens = true;
  static const genreListsInheritSorting = true;
  static const genreItemSectionFilterChipOrder = CuratedItemSelectionType.values;
  static const applyFilterOnGenreChipTap = false;
  static const artistCuratedItemSelectionType = CuratedItemSelectionType.mostPlayed;
  static const artistItemSectionFilterChipOrder = CuratedItemSelectionType.values;
  static const artistItemSectionsOrder = ArtistItemSections.values;
  static const autoSwitchItemCurationType = true;
  static const genreFilterPlaylists = false;
  static const clearQueueOnStopEvent = false;
  static const useHighContrastColors = false;
  static const tileAdditionalInfoType = {
    ContentType.tracks: TileAdditionalInfoType.adaptive,
    ContentType.albums: TileAdditionalInfoType.adaptive,
    ContentType.performingArtists: TileAdditionalInfoType.adaptive,
    ContentType.albumArtists: TileAdditionalInfoType.adaptive,
    ContentType.playlists: TileAdditionalInfoType.adaptive,
    ContentType.genres: TileAdditionalInfoType.adaptive,
  };
  static const rpcEnabled = false;
  static const rpcIcon = DiscordRpcIcon.transparent;
  static const preferAddingToFavoritesOverPlaylists = false;
  static const previousTracksExpanded = false;
  static const autoplayRestoredQueue = false;
  static const preferNextUpPrepending = true;
  static const rememberLastUsedPlaybackActionRowPage = true;
  static const lastUsedPlaybackActionRowPage = PlaybackActionRowPage.newQueue;
  static const lastUsedPlaybackActionRowPageForQueueMenu = PlaybackActionRowPage.moveWithinQueue;
  static const useSystemAccentColor = false;
  static const useMonochromeIcon = false;
  static const radioMode = RadioMode.similar;
  static const radioEnabled = false;
  static const duckOnAudioInterruption = true;
  static const forceAudioOffloadingOnAndroid = false;
  static const previousTracksPersistenceMode = PreviousTracksPersistenceMode.persistent;
  static final homeScreenConfiguration = FinampHomeScreenConfiguration(
    actions: [
      QuickActionConfig(action: FinampQuickActions.shuffleTracks),
      QuickActionConfig(action: FinampQuickActions.playRandomFavoriteItem),
      QuickActionConfig(action: FinampQuickActions.playPreviousQueue),
      QuickActionConfig(action: FinampQuickActions.surpriseMe),
    ],
    sections: [
      HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType.recentlyAddedAlbums),
      HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType.favoriteTracks),
      HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType.frequentlyPlayedAlbums),
      HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType.favoritePlaylists),
      HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType.forgottenFavoriteTracks),
      HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType.recentQueues),
    ],
  );
  static const gridImageSizeMobile = 130;
  static const gridImageSizeDesktop = 150;
  static int get homeScreenImageSize => isDesktop ? homeScreenImageSizeDesktop : homeScreenImageSizeMobile;
  static const homeScreenImageSizeMobile = 90;
  static const homeScreenImageSizeDesktop = 120;
  static int get gridImageSize => isDesktop ? gridImageSizeDesktop : gridImageSizeMobile;
  static const useAndroidGainEffect = true;
}

@HiveType(typeId: 28)
class FinampSettings {
  FinampSettings({
    this.isOffline = DefaultSettings.isOffline,
    this.shouldTranscode = DefaultSettings.shouldTranscode,
    this.transcodeBitrate = DefaultSettings.transcodeBitrate,
    // downloadLocations is required since the other values can be created with
    // default values. create() is used to return a FinampSettings with
    // downloadLocations.
    required this.downloadLocations,
    this.androidStopForegroundOnPause = DefaultSettings.androidStopForegroundOnPause,
    this.showTabs = DefaultSettings.showTabs,
    this.onlyShowFavorites = DefaultSettings.onlyShowFavorites,
    this.trackShuffleItemCount = DefaultSettings.trackShuffleItemCount,
    this.volumeNormalizationActive = DefaultSettings.volumeNormalizationActive,
    this.volumeNormalizationIOSBaseGain = DefaultSettings.volumeNormalizationIOSBaseGain,
    this.volumeNormalizationMode = DefaultSettings.volumeNormalizationMode,
    this.contentViewType = DefaultSettings.contentViewType,
    this.playbackSpeedVisibility = DefaultSettings.playbackSpeedVisibility,
    this.contentGridViewCrossAxisCountPortrait,
    this.contentGridViewCrossAxisCountLandscape,
    this.showTextOnGridView = DefaultSettings.showTextOnGridView,
    required this.downloadLocationsMap,
    this.useCoverAsBackground = DefaultSettings.useCoverAsBackground,
    this.playerScreenCoverMinimumPadding = DefaultSettings.playerScreenCoverMinimumPadding,
    this.showArtistsTracksSection = DefaultSettings.showArtistsTracksSection,
    this.bufferDisableSizeConstraints = DefaultSettings.bufferDisableSizeConstraints,
    this.bufferDurationSeconds = DefaultSettings.bufferDurationSeconds,
    this.bufferSizeMegabytes = DefaultSettings.bufferSizeMegabytes,
    required this.tabSortBy,
    required this.tabSortOrder,
    this.loopMode = DefaultSettings.loopMode,
    this.playbackSpeed = DefaultSettings.playbackSpeed,
    this.playbackPitch = DefaultSettings.playbackPitch,
    this.syncPlaybackSpeedAndPitch = DefaultSettings.syncPlaybackSpeedAndPitch,
    this.tabOrder = DefaultSettings.tabOrder,
    this.autoloadLastQueueOnStartup = DefaultSettings.autoLoadLastQueueOnStartup,
    this.hasCompletedDownloadsServiceMigration =
        true, //!!! don't touch this default value, it's supposed to be hard coded to run the migration only once
    this.requireWifiForDownloads = DefaultSettings.requireWifiForDownloads,
    this.onlyShowFullyDownloaded = DefaultSettings.onlyShowFullyDownloaded,
    this.showDownloadsWithUnknownLibrary = DefaultSettings.showDownloadsWithUnknownLibrary,
    this.maxConcurrentDownloads = DefaultSettings.maxConcurrentDownloads,
    this.downloadWorkers = DefaultSettings.downloadWorkers,
    this.resyncOnStartup = DefaultSettings.resyncOnStartup,
    this.preferQuickSyncs = DefaultSettings.preferQuickSyncs,
    this.hasCompletedIsarUserMigration =
        true, //!!! don't touch this default value, it's supposed to be hard coded to run the migration only once
    this.downloadTranscodingCodec,
    this.downloadTranscodeBitrate,
    this.shouldTranscodeDownloads = DefaultSettings.shouldTranscodeDownloads,
    this.multichannelHandlingSetting = DefaultSettings.multichannelHandlingSetting,
    this.shouldRedownloadTranscodes = DefaultSettings.shouldRedownloadTranscodes,
    this.itemSwipeActionLeftToRight = DefaultSettings.itemSwipeActionLeftToRight,
    this.itemSwipeActionRightToLeft = DefaultSettings.itemSwipeActionRightToLeft,
    this.useFixedSizeGridTiles,
    this.fixedGridTileSize,
    this.allowSplitScreen = DefaultSettings.allowSplitScreen,
    this.splitScreenPlayerWidth = DefaultSettings.splitScreenPlayerWidth,
    this.enableVibration = DefaultSettings.enableVibration,
    this.prioritizeCoverFactor = DefaultSettings.prioritizeCoverFactor,
    this.suppressPlayerPadding = DefaultSettings.suppressPlayerPadding,
    this.hidePlayerBottomActions = DefaultSettings.hidePlayerBottomActions,
    this.reportQueueToServer = DefaultSettings.reportQueueToServer,
    this.periodicPlaybackSessionUpdateFrequencySeconds = DefaultSettings.periodicPlaybackSessionUpdateFrequencySeconds,
    this.playOnStaleDelay = DefaultSettings.playOnStaleDelay,
    this.playOnReconnectionDelay = DefaultSettings.playOnReconnectionDelay,
    this.enablePlayon = DefaultSettings.enablePlayon,
    this.currentVolume = DefaultSettings.currentVolume,
    this.showArtistChipImage = DefaultSettings.showArtistChipImage,
    this.trackOfflineFavorites = DefaultSettings.trackOfflineFavorites,
    this.showProgressOnNowPlayingBar = DefaultSettings.showProgressOnNowPlayingBar,
    this.startInstantMixForIndividualTracks = DefaultSettings.startInstantMixForIndividualTracks,
    this.showLyricsTimestamps = DefaultSettings.showLyricsTimestamps,
    this.lyricsAlignment = DefaultSettings.lyricsAlignment,
    this.lyricsFontSize = DefaultSettings.lyricsFontSize,
    this.showLyricsScreenAlbumPrelude = DefaultSettings.showLyricsScreenAlbumPrelude,
    this.showStopButtonOnMediaNotification = DefaultSettings.showStopButtonOnMediaNotification,
    this.showShuffleButtonOnMediaNotification = DefaultSettings.showShuffleButtonOnMediaNotification,
    this.showFavoriteButtonOnMediaNotification = DefaultSettings.showFavoriteButtonOnMediaNotification,
    this.showSeekControlsOnMediaNotification = DefaultSettings.showSeekControlsOnMediaNotification,
    this.keepScreenOnOption = DefaultSettings.keepScreenOnOption,
    this.keepScreenOnWhilePluggedIn = DefaultSettings.keepScreenOnWhilePluggedIn,
    this.featureChipsConfiguration = DefaultSettings.featureChipsConfiguration,
    this.showCoversOnAlbumScreen = DefaultSettings.showCoversOnAlbumScreen,
    this.hasDownloadedPlaylistInfo = DefaultSettings.hasDownloadedPlaylistInfo,
    this.transcodingStreamingFormat = DefaultSettings.transcodingStreamingFormat,
    this.downloadSizeWarningCutoff = DefaultSettings.downloadSizeWarningCutoff,
    this.allowDeleteFromServer = DefaultSettings.allowDeleteFromServer,
    this.oneLineMarqueeTextButton = DefaultSettings.oneLineMarqueeTextButton,
    this.showAlbumReleaseDateOnPlayerScreen = DefaultSettings.showAlbumReleaseDateOnPlayerScreen,
    this.releaseDateFormat = DefaultSettings.releaseDateFormat,
    this.defaultArtistType = DefaultSettings.defaultArtistType,
    this.autoOffline = DefaultSettings.autoOffline,
    this.autoOfflineListenerActive = DefaultSettings.autoOfflineListenerActive,
    this.audioFadeOutDuration = DefaultSettings.audioFadeOutDuration,
    this.audioFadeInDuration = DefaultSettings.audioFadeInDuration,
    this.autoReloadQueue = DefaultSettings.autoReloadQueue,
    this.screenSize,
    this.genreCuratedItemSelectionTypeTracks = DefaultSettings.genreCuratedItemSelectionTypeTracks,
    this.genreCuratedItemSelectionTypeAlbums = DefaultSettings.genreCuratedItemSelectionTypeAlbums,
    this.genreCuratedItemSelectionTypeArtists = DefaultSettings.genreCuratedItemSelectionTypeArtists,
    this.genreItemSectionsOrder = DefaultSettings.genreItemSectionsOrder,
    this.genreFilterArtistScreens = DefaultSettings.genreFilterArtistScreens,
    this.genreListsInheritSorting = DefaultSettings.genreListsInheritSorting,
    this.genreItemSectionFilterChipOrder = DefaultSettings.genreItemSectionFilterChipOrder,
    this.applyFilterOnGenreChipTap = DefaultSettings.applyFilterOnGenreChipTap,
    this.artistCuratedItemSelectionType = DefaultSettings.artistCuratedItemSelectionType,
    this.artistItemSectionFilterChipOrder = DefaultSettings.artistItemSectionFilterChipOrder,
    this.artistItemSectionsOrder = DefaultSettings.artistItemSectionsOrder,
    this.autoSwitchItemCurationType = DefaultSettings.autoSwitchItemCurationType,
    this.genreFilterPlaylists = DefaultSettings.genreFilterPlaylists,
    this.clearQueueOnStopEvent = DefaultSettings.clearQueueOnStopEvent,
    this.useHighContrastColors = DefaultSettings.useHighContrastColors,
    // !!! Don't touch this default value, it's supposed to be hard coded to run the migration only once
    this.hasCompletedDownloadsFileOwnerMigration = true,
    this.tileAdditionalInfoType = DefaultSettings.tileAdditionalInfoType,
    this.rpcEnabled = DefaultSettings.rpcEnabled,
    this.rpcIcon = DefaultSettings.rpcIcon,
    this.preferAddingToFavoritesOverPlaylists = DefaultSettings.preferAddingToFavoritesOverPlaylists,
    this.previousTracksExpanded = DefaultSettings.previousTracksExpanded,
    this.autoplayRestoredQueue = DefaultSettings.autoplayRestoredQueue,
    this.preferNextUpPrepending = DefaultSettings.preferNextUpPrepending,
    this.rememberLastUsedPlaybackActionRowPage = DefaultSettings.rememberLastUsedPlaybackActionRowPage,
    this.lastUsedPlaybackActionRowPage = DefaultSettings.lastUsedPlaybackActionRowPage,
    this.lastUsedPlaybackActionRowPageForQueueMenu = DefaultSettings.lastUsedPlaybackActionRowPageForQueueMenu,
    this.accentColor = DefaultSettings.accentColor,
    this.themeMode = DefaultSettings.themeMode,
    this.amoledTheme = DefaultSettings.amoledTheme,
    this.locale = DefaultSettings.locale,
    // !!! Don't touch this default value, it's supposed to be hard coded to run the migration only once
    this.hasCompletedThemeModeLocaleMigration = true,
    this.systemAccentColor = DefaultSettings.accentColor,
    this.useSystemAccentColor = DefaultSettings.useSystemAccentColor,
    this.useMonochromeIcon = DefaultSettings.useMonochromeIcon,
    this.duckOnAudioInterruption = DefaultSettings.duckOnAudioInterruption,
    this.forceAudioOffloadingOnAndroid = DefaultSettings.forceAudioOffloadingOnAndroid,
    this.previousTracksPersistenceMode = DefaultSettings.previousTracksPersistenceMode,
    required this.homeScreenConfiguration,
    required this.gridImageSize,
    required this.homeScreenImageSize,
    this.useAndroidGainEffect = DefaultSettings.useAndroidGainEffect,
  });

  @HiveField(0, defaultValue: DefaultSettings.isOffline)
  bool isOffline;
  @HiveField(1, defaultValue: DefaultSettings.shouldTranscode)
  bool shouldTranscode;
  @HiveField(2, defaultValue: DefaultSettings.transcodeBitrate)
  int transcodeBitrate;

  @Deprecated("Use downloadedLocationsMap instead")
  @HiveField(3)
  List<DownloadLocation> downloadLocations;

  @HiveField(4, defaultValue: DefaultSettings.androidStopForegroundOnPause)
  bool androidStopForegroundOnPause;

  @HiveField(5)
  @SettingsHelperMap("tabContentType")
  Map<ContentType, bool> showTabs;

  /// Used to remember if the user has set their music screen to favorites
  /// mode.
  @HiveField(6, defaultValue: DefaultSettings.onlyShowFavorites)
  bool onlyShowFavorites;

  /// Current sort by setting.
  @Deprecated("Use per-tab sort by instead")
  @HiveField(7)
  SortBy? sortBy;

  /// Current sort order setting.
  @Deprecated("Use per-tab sort order instead")
  @HiveField(8)
  SortOrder? sortOrder;

  /// Amount of tracks to get when shuffling tracks.
  @HiveField(9, defaultValue: DefaultSettings.trackShuffleItemCount)
  int trackShuffleItemCount;

  /// The content view type used by the music screen.
  @HiveField(10, defaultValue: DefaultSettings.contentViewType)
  ContentViewType contentViewType;

  /// Amount of grid tiles to use per-row when portrait.
  @HiveField(11)
  @Deprecated("Use gridImageSize instead")
  int? contentGridViewCrossAxisCountPortrait;

  /// Amount of grid tiles to use per-row when landscape.
  @HiveField(12)
  @Deprecated("Use gridImageSize instead")
  int? contentGridViewCrossAxisCountLandscape;

  /// Whether or not to show the text (title, artist etc) on the grid music
  /// screen.
  @HiveField(13, defaultValue: DefaultSettings.showTextOnGridView)
  bool showTextOnGridView = DefaultSettings.showTextOnGridView;

  // @HiveField(14, defaultValue: DefaultSettings.sleepTimerSeconds) //!!! don't reuse this hive ID!

  @HiveField(15, defaultValue: <String, DownloadLocation>{})
  @SettingsHelperIgnore("This map is read and modified in an unusual way, so helper methods are defined manually.")
  Map<String, DownloadLocation> downloadLocationsMap;

  /// Whether or not to use blurred cover art as background on player screen.
  @HiveField(16, defaultValue: DefaultSettings.useCoverAsBackground)
  bool useCoverAsBackground = DefaultSettings.useCoverAsBackground;

  @HiveField(18, defaultValue: DefaultSettings.bufferDurationSeconds)
  int bufferDurationSeconds;

  @HiveField(19, defaultValue: DefaultSettings.disableGesture)
  bool disableGesture = DefaultSettings.disableGesture;

  @HiveField(20, defaultValue: <ContentType, SortBy>{})
  @SettingsHelperMap("tabContentType")
  Map<ContentType, SortBy> tabSortBy;

  @HiveField(21, defaultValue: <ContentType, SortOrder>{})
  @SettingsHelperMap("tabContentType")
  Map<ContentType, SortOrder> tabSortOrder;

  @HiveField(22, defaultValue: DefaultSettings.tabOrder)
  List<ContentType> tabOrder;

  @HiveField(25, defaultValue: DefaultSettings.showFastScroller)
  bool showFastScroller = DefaultSettings.showFastScroller;

  @HiveField(27, defaultValue: DefaultSettings.loopMode)
  FinampLoopMode loopMode;

  @HiveField(28, defaultValue: DefaultSettings.autoLoadLastQueueOnStartup)
  bool autoloadLastQueueOnStartup;

  @HiveField(29, defaultValue: DefaultSettings.volumeNormalizationActive)
  bool volumeNormalizationActive;

  @HiveField(30, defaultValue: DefaultSettings.volumeNormalizationIOSBaseGain)
  double volumeNormalizationIOSBaseGain;

  @HiveField(33, defaultValue: DefaultSettings.volumeNormalizationMode)
  VolumeNormalizationMode volumeNormalizationMode;

  @HiveField(
    34,
    defaultValue: false,
  ) //!!! don't touch this default value, it's supposed to be hard coded to run the migration only once
  bool hasCompletedDownloadsServiceMigration;

  @HiveField(35, defaultValue: DefaultSettings.requireWifiForDownloads)
  bool requireWifiForDownloads;

  @HiveField(36, defaultValue: DefaultSettings.onlyShowFullyDownloaded)
  bool onlyShowFullyDownloaded;

  @HiveField(37, defaultValue: DefaultSettings.showDownloadsWithUnknownLibrary)
  bool showDownloadsWithUnknownLibrary;

  @HiveField(38, defaultValue: DefaultSettings.maxConcurrentDownloads)
  int maxConcurrentDownloads;

  @HiveField(39, defaultValue: DefaultSettings.downloadWorkers)
  int downloadWorkers;

  @HiveField(40, defaultValue: DefaultSettings.resyncOnStartup)
  bool resyncOnStartup;

  @HiveField(41, defaultValue: DefaultSettings.preferQuickSyncs)
  bool preferQuickSyncs;

  @HiveField(
    42,
    defaultValue: false,
  ) //!!! don't touch this default value, it's supposed to be hard coded to run the migration only once
  bool hasCompletedIsarUserMigration;

  @HiveField(43)
  FinampTranscodingCodec? downloadTranscodingCodec;

  @HiveField(44, defaultValue: DefaultSettings.shouldTranscodeDownloads)
  TranscodeDownloadsSetting shouldTranscodeDownloads;

  @HiveField(45)
  int? downloadTranscodeBitrate;

  @HiveField(46, defaultValue: DefaultSettings.shouldRedownloadTranscodes)
  bool shouldRedownloadTranscodes;

  @HiveField(47, defaultValue: DefaultSettings.enableVibration)
  bool enableVibration;

  @HiveField(48, defaultValue: DefaultSettings.playerScreenCoverMinimumPadding)
  double playerScreenCoverMinimumPadding = DefaultSettings.playerScreenCoverMinimumPadding;

  @HiveField(49, defaultValue: DefaultSettings.prioritizeCoverFactor)
  double prioritizeCoverFactor;

  @HiveField(50, defaultValue: DefaultSettings.suppressPlayerPadding)
  bool suppressPlayerPadding;

  @HiveField(51, defaultValue: DefaultSettings.hidePlayerBottomActions)
  bool hidePlayerBottomActions;

  @HiveField(52, defaultValue: DefaultSettings.reportQueueToServer)
  bool reportQueueToServer;

  @HiveField(53, defaultValue: DefaultSettings.periodicPlaybackSessionUpdateFrequencySeconds)
  int periodicPlaybackSessionUpdateFrequencySeconds;

  @HiveField(54, defaultValue: DefaultSettings.showArtistsTracksSection)
  bool showArtistsTracksSection = DefaultSettings.showArtistsTracksSection;

  @HiveField(55, defaultValue: DefaultSettings.showArtistChipImage)
  bool showArtistChipImage;

  @HiveField(56, defaultValue: DefaultSettings.playbackSpeed)
  double playbackSpeed;

  /// The content playback speed type defining how and whether to display the playback speed controls in the track menu
  @HiveField(57, defaultValue: DefaultSettings.playbackSpeedVisibility)
  PlaybackSpeedVisibility playbackSpeedVisibility;

  @HiveField(58, defaultValue: null)
  String? defaultDownloadLocation;

  @HiveField(59)
  @Deprecated("Use gridImageSize instead")
  bool? useFixedSizeGridTiles;

  @HiveField(60)
  @Deprecated("Use gridImageSize instead")
  int? fixedGridTileSize;

  @HiveField(61, defaultValue: DefaultSettings.allowSplitScreen)
  bool allowSplitScreen;

  @HiveField(62, defaultValue: DefaultSettings.splitScreenPlayerWidth)
  double splitScreenPlayerWidth;

  @HiveField(63, defaultValue: DefaultSettings.trackOfflineFavorites)
  bool trackOfflineFavorites;

  @HiveField(64, defaultValue: DefaultSettings.showProgressOnNowPlayingBar)
  bool showProgressOnNowPlayingBar;

  @HiveField(65, defaultValue: DefaultSettings.startInstantMixForIndividualTracks)
  bool startInstantMixForIndividualTracks;

  @HiveField(66, defaultValue: DefaultSettings.showLyricsTimestamps)
  bool showLyricsTimestamps;

  @HiveField(67, defaultValue: DefaultSettings.lyricsAlignment)
  LyricsAlignment lyricsAlignment;

  @HiveField(68, defaultValue: DefaultSettings.showStopButtonOnMediaNotification)
  bool showStopButtonOnMediaNotification;

  @HiveField(69, defaultValue: DefaultSettings.showSeekControlsOnMediaNotification)
  bool showSeekControlsOnMediaNotification;

  @HiveField(70, defaultValue: DefaultSettings.lyricsFontSize)
  LyricsFontSize lyricsFontSize;

  @HiveField(71, defaultValue: DefaultSettings.showLyricsScreenAlbumPrelude)
  bool showLyricsScreenAlbumPrelude;

  @HiveField(72, defaultValue: DefaultSettings.keepScreenOnOption)
  KeepScreenOnOption keepScreenOnOption;

  @HiveField(73, defaultValue: DefaultSettings.keepScreenOnWhilePluggedIn)
  bool keepScreenOnWhilePluggedIn;

  @HiveField(74, defaultValue: DefaultSettings.hasDownloadedPlaylistInfo)
  bool hasDownloadedPlaylistInfo;

  @HiveField(75, defaultValue: DefaultSettings.transcodingStreamingFormat)
  FinampTranscodingStreamingFormat transcodingStreamingFormat;

  @HiveField(76, defaultValue: DefaultSettings.featureChipsConfiguration)
  FinampFeatureChipsConfiguration featureChipsConfiguration;

  @HiveField(77, defaultValue: DefaultSettings.showCoversOnAlbumScreen)
  bool showCoversOnAlbumScreen;

  @HiveField(78, defaultValue: DefaultSettings.bufferDisableSizeConstraints)
  bool bufferDisableSizeConstraints;

  @HiveField(79, defaultValue: DefaultSettings.bufferSizeMegabytes)
  int bufferSizeMegabytes;

  @HiveField(80, defaultValue: DefaultSettings.downloadSizeWarningCutoff)
  int downloadSizeWarningCutoff;

  @HiveField(81, defaultValue: DefaultSettings.allowDeleteFromServer)
  bool allowDeleteFromServer;

  @HiveField(82, defaultValue: DefaultSettings.oneLineMarqueeTextButton)
  bool oneLineMarqueeTextButton;

  @HiveField(83, defaultValue: DefaultSettings.showAlbumReleaseDateOnPlayerScreen)
  bool showAlbumReleaseDateOnPlayerScreen;

  @HiveField(84, defaultValue: DefaultSettings.releaseDateFormat)
  ReleaseDateFormat releaseDateFormat;

  @HiveField(85, defaultValue: null)
  String? lastUsedDownloadLocationId;

  @HiveField(86, defaultValue: DefaultSettings.audioFadeOutDuration)
  Duration audioFadeOutDuration;

  @HiveField(87, defaultValue: DefaultSettings.audioFadeInDuration)
  Duration audioFadeInDuration;

  @HiveField(88, defaultValue: DefaultSettings.autoOffline)
  AutoOfflineOption autoOffline;

  // this will get set to false when the user
  // manually enables offline mode and set to
  // true when the user disables offline mode
  // again. This prevents offline mode from beeing
  // automatically disabled when connecting to wifi
  @HiveField(89, defaultValue: DefaultSettings.autoOfflineListenerActive)
  bool autoOfflineListenerActive;

  @HiveField(90, defaultValue: DefaultSettings.itemSwipeActionLeftToRight)
  ItemSwipeActions itemSwipeActionLeftToRight;

  @HiveField(91, defaultValue: DefaultSettings.itemSwipeActionRightToLeft)
  ItemSwipeActions itemSwipeActionRightToLeft;

  @HiveField(92, defaultValue: DefaultSettings.defaultArtistType)
  ArtistType defaultArtistType;

  @HiveField(93, defaultValue: DefaultSettings.currentVolume)
  double currentVolume;

  @HiveField(94, defaultValue: DefaultSettings.playOnStaleDelay)
  int playOnStaleDelay;

  @HiveField(95, defaultValue: DefaultSettings.playOnReconnectionDelay)
  int playOnReconnectionDelay;

  @HiveField(96, defaultValue: DefaultSettings.enablePlayon)
  bool enablePlayon;

  @HiveField(97, defaultValue: DefaultSettings.autoReloadQueue)
  bool autoReloadQueue;

  @HiveField(98, defaultValue: DefaultSettings.showShuffleButtonOnMediaNotification)
  bool showShuffleButtonOnMediaNotification;

  @HiveField(99, defaultValue: DefaultSettings.showFavoriteButtonOnMediaNotification)
  bool showFavoriteButtonOnMediaNotification;

  @HiveField(100)
  ScreenSize? screenSize;

  @HiveField(101, defaultValue: DefaultSettings.genreCuratedItemSelectionTypeTracks)
  CuratedItemSelectionType genreCuratedItemSelectionTypeTracks;

  @HiveField(102, defaultValue: DefaultSettings.genreCuratedItemSelectionTypeAlbums)
  CuratedItemSelectionType genreCuratedItemSelectionTypeAlbums;

  @HiveField(103, defaultValue: DefaultSettings.genreCuratedItemSelectionTypeArtists)
  CuratedItemSelectionType genreCuratedItemSelectionTypeArtists;

  @HiveField(104, defaultValue: DefaultSettings.genreItemSectionsOrder)
  List<GenreItemSections> genreItemSectionsOrder;

  @HiveField(105, defaultValue: DefaultSettings.genreFilterArtistScreens)
  bool genreFilterArtistScreens;

  @HiveField(106, defaultValue: DefaultSettings.genreListsInheritSorting)
  bool genreListsInheritSorting;

  @HiveField(107, defaultValue: DefaultSettings.genreItemSectionFilterChipOrder)
  List<CuratedItemSelectionType> genreItemSectionFilterChipOrder;

  @HiveField(108, defaultValue: DefaultSettings.applyFilterOnGenreChipTap)
  bool applyFilterOnGenreChipTap;

  @HiveField(109, defaultValue: DefaultSettings.artistCuratedItemSelectionType)
  CuratedItemSelectionType artistCuratedItemSelectionType;

  @HiveField(110, defaultValue: DefaultSettings.artistItemSectionFilterChipOrder)
  List<CuratedItemSelectionType> artistItemSectionFilterChipOrder;

  @HiveField(111, defaultValue: DefaultSettings.artistItemSectionsOrder)
  List<ArtistItemSections> artistItemSectionsOrder;

  @HiveField(112, defaultValue: DefaultSettings.autoSwitchItemCurationType)
  bool autoSwitchItemCurationType;

  @HiveField(113)
  @Deprecated("Prefer tabSortBy[ContentType.inPlaylist] instead")
  SortBy? playlistTracksSortBy;

  @HiveField(114)
  @Deprecated("Prefer tabSortOrder[ContentType.inPlaylist] instead")
  SortOrder? playlistTracksSortOrder;

  @HiveField(115, defaultValue: DefaultSettings.genreFilterPlaylists)
  bool genreFilterPlaylists;

  @HiveField(116)
  SleepTimer? sleepTimer;

  @HiveField(117, defaultValue: DefaultSettings.clearQueueOnStopEvent)
  bool clearQueueOnStopEvent;

  @HiveField(118, defaultValue: DefaultSettings.playbackPitch)
  double playbackPitch;

  @HiveField(119, defaultValue: DefaultSettings.syncPlaybackSpeedAndPitch)
  bool syncPlaybackSpeedAndPitch;

  @HiveField(120, defaultValue: DefaultSettings.useHighContrastColors)
  bool useHighContrastColors;

  // !!! Don't touch this default value, it's supposed to be hard coded to run the migration only once
  // Whether the downloads file owner migration has been completed.
  @HiveField(121, defaultValue: false)
  bool hasCompletedDownloadsFileOwnerMigration;

  @HiveField(122, defaultValue: DefaultSettings.tileAdditionalInfoType)
  @SettingsHelperMap("tabContentType")
  Map<ContentType, TileAdditionalInfoType> tileAdditionalInfoType;

  @HiveField(123, defaultValue: DefaultSettings.rpcEnabled)
  bool rpcEnabled;

  @HiveField(124, defaultValue: DefaultSettings.rpcIcon)
  DiscordRpcIcon rpcIcon;

  @HiveField(125, defaultValue: DefaultSettings.autoExpandPlayerScreen)
  bool autoExpandPlayerScreen = DefaultSettings.autoExpandPlayerScreen;

  @HiveField(126, defaultValue: DefaultSettings.preferAddingToFavoritesOverPlaylists)
  bool preferAddingToFavoritesOverPlaylists;

  @HiveField(127, defaultValue: DefaultSettings.previousTracksExpanded)
  bool previousTracksExpanded = DefaultSettings.previousTracksExpanded;

  @HiveField(128, defaultValue: DefaultSettings.autoplayRestoredQueue)
  bool autoplayRestoredQueue = DefaultSettings.autoplayRestoredQueue;

  @HiveField(129, defaultValue: DefaultSettings.preferNextUpPrepending)
  bool preferNextUpPrepending = DefaultSettings.preferNextUpPrepending;

  @HiveField(130, defaultValue: DefaultSettings.rememberLastUsedPlaybackActionRowPage)
  bool rememberLastUsedPlaybackActionRowPage;

  @HiveField(131, defaultValue: DefaultSettings.lastUsedPlaybackActionRowPage)
  PlaybackActionRowPage lastUsedPlaybackActionRowPage;

  @HiveField(132, defaultValue: DefaultSettings.accentColor)
  Color? accentColor = DefaultSettings.accentColor;

  @HiveField(133, defaultValue: DefaultSettings.themeMode)
  ThemeMode themeMode = DefaultSettings.themeMode;

  @HiveField(134, defaultValue: DefaultSettings.locale)
  Locale? locale = DefaultSettings.locale;

  // !!! don't touch this default value, it's supposed to be hard coded to run the migration only once
  @HiveField(135, defaultValue: false)
  bool hasCompletedThemeModeLocaleMigration;

  @HiveField(136, defaultValue: DefaultSettings.accentColor)
  Color? systemAccentColor = DefaultSettings.accentColor;

  @HiveField(137, defaultValue: DefaultSettings.useSystemAccentColor)
  bool useSystemAccentColor;

  @HiveField(138, defaultValue: DefaultSettings.useMonochromeIcon)
  bool useMonochromeIcon = DefaultSettings.useMonochromeIcon;

  @HiveField(139, defaultValue: DefaultSettings.lastUsedPlaybackActionRowPageForQueueMenu)
  PlaybackActionRowPage lastUsedPlaybackActionRowPageForQueueMenu;

  @HiveField(140, defaultValue: DefaultSettings.radioEnabled)
  bool radioEnabled = DefaultSettings.radioEnabled;

  @HiveField(141, defaultValue: DefaultSettings.radioMode)
  RadioMode radioMode = DefaultSettings.radioMode;

  @HiveField(142, defaultValue: DefaultSettings.duckOnAudioInterruption)
  bool duckOnAudioInterruption = DefaultSettings.duckOnAudioInterruption;

  @HiveField(143, defaultValue: DefaultSettings.forceAudioOffloadingOnAndroid)
  bool forceAudioOffloadingOnAndroid = DefaultSettings.forceAudioOffloadingOnAndroid;

  @HiveField(144, defaultValue: DefaultSettings.multichannelHandlingSetting)
  MultichannelHandlingSetting multichannelHandlingSetting;

  @HiveField(145, defaultValue: DefaultSettings.previousTracksPersistenceMode)
  PreviousTracksPersistenceMode previousTracksPersistenceMode;

  @HiveField(
    146,
    //!!! this is a dummy value, the actual default is set in [_migrateHomescreen] because it's a non-constant value, and therefore not supported as a Hive default value
    defaultValue: FinampHomeScreenConfiguration(actions: [], sections: []),
  )
  FinampHomeScreenConfiguration homeScreenConfiguration = DefaultSettings.homeScreenConfiguration;

  @HiveField(147, defaultValue: DefaultSettings.gridImageSizeMobile)
  int gridImageSize;

  @HiveField(148, defaultValue: DefaultSettings.amoledTheme)
  bool amoledTheme = DefaultSettings.amoledTheme;

  @HiveField(149, defaultValue: DefaultSettings.useAndroidGainEffect)
  bool useAndroidGainEffect;

  @HiveField(150, defaultValue: DefaultSettings.homeScreenImageSizeMobile)
  int homeScreenImageSize;

  static Future<FinampSettings> create() async {
    final downloadLocation = await DownloadLocation.create(
      name: DownloadLocation.internalStorageName,
      // default download location moved to support dir based on existing comment
      baseDirectory: DownloadLocationType.platformDefaultDirectory,
    );
    return FinampSettings(
      downloadLocations: [],
      downloadLocationsMap: {downloadLocation.id: downloadLocation},
      tabSortBy: {},
      tabSortOrder: {},
      homeScreenConfiguration: DefaultSettings.homeScreenConfiguration,
      gridImageSize: DefaultSettings.gridImageSize,
      homeScreenImageSize: DefaultSettings.homeScreenImageSize,
    );
  }

  DownloadProfile get downloadTranscodingProfile =>
      DownloadProfile(transcodeCodec: downloadTranscodingCodec, bitrate: downloadTranscodeBitrate);

  /// Returns the DownloadLocation that is the internal track dir. This can
  /// technically throw a StateError, but that should never happen™.
  DownloadLocation get internalTrackDir => downloadLocationsMap.values.firstWhere(
    (element) => element.baseDirectory == DownloadLocationType.platformDefaultDirectory,
  );

  Duration get bufferDuration => Duration(seconds: bufferDurationSeconds);

  set bufferDuration(Duration duration) => bufferDurationSeconds = duration.inSeconds;

  SortBy getTabSortBy(ContentType tabType) {
    return tabSortBy[tabType] ?? SortBy.sortName;
  }

  SortOrder getSortOrder(ContentType tabType) {
    return tabSortOrder[tabType] ?? SortOrder.ascending;
  }
}

enum CustomPlaybackActions { shuffle, toggleFavorite, radio, dbusVolume }

/// Custom storage locations for storing music/images.
@HiveType(typeId: 31)
class DownloadLocation {
  DownloadLocation({
    required this.name,
    required this.relativePath,
    required this.id,
    this.legacyUseHumanReadableNames,
    this.legacyDeletable,
    required this.baseDirectory,
  }) {
    assert(baseDirectory.needsPath == (relativePath != null));
    assert(
      baseDirectory == DownloadLocationType.migrated ||
          // ignore: deprecated_member_use_from_same_package
          (legacyUseHumanReadableNames == null && legacyDeletable == null),
    );
    assert(
      baseDirectory != DownloadLocationType.migrated ||
          // ignore: deprecated_member_use_from_same_package
          (legacyUseHumanReadableNames != null && legacyDeletable != null),
    );
  }

  /// Human-readable name for the path (shown in settings)
  @HiveField(0)
  String name;

  /// The path. We store this as a string since it's easier to put into Hive.
  @HiveField(1)
  String? relativePath;

  /// If true, store tracks using their actual names instead of Jellyfin item IDs.
  @Deprecated("This is here for migration.  Use useHumanReadableNames instead.")
  @HiveField(2)
  bool? legacyUseHumanReadableNames;

  bool get useHumanReadableNames => baseDirectory.useHumanReadableNames;

  /// If true, the user can delete this storage location. It's a bit of a hack,
  /// but the only undeletable location is the internal storage dir, so we can
  /// use this value to get the internal track dir.
  @HiveField(3)
  @Deprecated("This is here for migration.  Use baseDirectory instead.")
  bool? legacyDeletable;

  /// Unique ID for the DownloadLocation. If this DownloadLocation was created
  /// before 0.6, it will be "0", very temporarily until it is changed on
  /// startup.
  @HiveField(4, defaultValue: "0")
  String id;

  /// Base directory of DownloadLocation.  Used to calculate currentPath and
  /// to determine directory attributes.
  @HiveField(5, defaultValue: DownloadLocationType.migrated)
  DownloadLocationType baseDirectory;

  String? _currentPath;

  /// The current path to the location, updated during app startup
  String get currentPath => _currentPath!;

  /// Update currentPath to the latest value.  Run for every downloadLocation
  /// every time the app starts up.
  Future<void> updateCurrentPath() async {
    if (baseDirectory == DownloadLocationType.migrated) {
      // ignore: deprecated_member_use_from_same_package
      if (!legacyDeletable!) {
        baseDirectory = DownloadLocationType.internalDocuments;
        relativePath = null;
        name = "Legacy Internal Storage";
        // ignore: deprecated_member_use_from_same_package
      } else if (!legacyUseHumanReadableNames!) {
        baseDirectory = DownloadLocationType.external;
      } else {
        baseDirectory = DownloadLocationType.custom;
      }
      // ignore: deprecated_member_use_from_same_package
      legacyDeletable = null;
      // ignore: deprecated_member_use_from_same_package
      legacyUseHumanReadableNames = null;
    }
    switch (baseDirectory) {
      case DownloadLocationType.internalDocuments:
        _currentPath = (await getApplicationDocumentsDirectory()).path;
      case DownloadLocationType.internalSupport:
        _currentPath = (await getApplicationSupportDirectory()).path;
      case DownloadLocationType.external:
        _currentPath = relativePath!;
      case DownloadLocationType.custom:
        _currentPath = relativePath!;
      case DownloadLocationType.cache:
        _currentPath = (await getApplicationCacheDirectory()).path;
      case DownloadLocationType.none:
      case DownloadLocationType.migrated:
        throw StateError("Bad basedirectory");
    }
  }

  /// Initialises a new DownloadLocation. id will be a UUID.
  static Future<DownloadLocation> create({
    required String name,
    String? relativePath,
    required DownloadLocationType baseDirectory,
  }) async {
    var downloadLocation = DownloadLocation(
      name: name,
      relativePath: relativePath,
      baseDirectory: baseDirectory,
      id: const Uuid().v4(),
    );
    await downloadLocation.updateCurrentPath();
    return downloadLocation;
  }

  static const String internalStorageName = "Internal Storage";
}

/// Class used in AddDownloadLocationScreen. Basically just a DownloadLocation
/// with nullable values. Shouldn't be used for actually storing download
/// locations.
class NewDownloadLocation {
  NewDownloadLocation({this.name, this.path, required this.baseDirectory});

  String? name;
  String? path;
  DownloadLocationType baseDirectory;
}

/// Supported tab types in MusicScreenTabView.
@HiveType(typeId: 36)
enum ContentType {
  @HiveField(0)
  albums(BaseItemDtoType.album),
  @HiveField(1)
  genericArtists(BaseItemDtoType.artist),
  @HiveField(2)
  playlists(BaseItemDtoType.playlist),
  @HiveField(3)
  genres(BaseItemDtoType.genre),
  @HiveField(4)
  tracks(BaseItemDtoType.track),
  @HiveField(5)
  home(null),
  @HiveField(6)
  performingArtists(BaseItemDtoType.artist),
  @HiveField(7)
  albumArtists(BaseItemDtoType.artist),
  @HiveField(8)
  inPlaylist(BaseItemDtoType.track),
  @HiveField(9)
  mixed(null),
  @HiveField(10)
  inPerformingArtistAlbums(BaseItemDtoType.album),
  @HiveField(11)
  inAlbumArtistAlbums(BaseItemDtoType.album);

  const ContentType(this.itemType);

  final BaseItemDtoType? itemType;

  /// Human-readable version of the [ContentType]. For example, toString() on
  /// [ContentType.tracks], toString() would return "TabContentType.tracks".
  /// With this function, the same input would return "Tracks".
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case ContentType.tracks:
        return l10n.tracks;
      case ContentType.albums:
        return l10n.albums;
      case ContentType.genericArtists:
        return l10n.artists;
      case ContentType.genres:
        return l10n.genres;
      case ContentType.playlists:
        return l10n.playlists;
      case ContentType.home:
        return l10n.home;
      case ContentType.performingArtists:
        return l10n.performingArtists;
      case ContentType.albumArtists:
        return l10n.albumArtists;
      case ContentType.inPlaylist:
        return l10n.inPlaylist;
      case ContentType.mixed:
        return l10n.inCollection;
      case ContentType.inPerformingArtistAlbums:
        return l10n.performingArtistFilter;
      case ContentType.inAlbumArtistAlbums:
        return l10n.albumArtistFilter;
    }
  }

  static ContentType fromItemType(String? itemType) {
    switch (itemType) {
      case "Audio":
        return ContentType.tracks;
      case "MusicAlbum":
        return ContentType.albums;
      case "MusicArtist":
        return ContentType.genericArtists;
      case "MusicGenre":
        return ContentType.genres;
      case "Playlist":
        return ContentType.playlists;
      default:
        throw const FormatException("Unsupported itemType");
    }
  }

  bool get isArtist => switch (this) {
    ContentType.genericArtists || ContentType.performingArtists || ContentType.albumArtists => true,
    _ => false,
  };

  bool get isTab => switch (this) {
    ContentType.albums => true,
    ContentType.genericArtists => true,
    ContentType.playlists => true,
    ContentType.genres => true,
    ContentType.tracks => true,
    ContentType.home => true,
    ContentType.performingArtists => true,
    ContentType.albumArtists => true,
    ContentType.inPlaylist => false,
    ContentType.mixed => false,
    ContentType.inPerformingArtistAlbums => false,
    ContentType.inAlbumArtistAlbums => false,
  };

  bool get directlyDisplayable => switch (this) {
    ContentType.albums => true,
    ContentType.genericArtists => false,
    ContentType.playlists => true,
    ContentType.genres => true,
    ContentType.tracks => true,
    ContentType.home => false,
    ContentType.performingArtists => true,
    ContentType.albumArtists => true,
    ContentType.inPlaylist => false,
    ContentType.mixed => false,
    ContentType.inPerformingArtistAlbums => false,
    ContentType.inAlbumArtistAlbums => false,
  };
}

@HiveType(typeId: 39)
enum ContentViewType {
  @HiveField(0)
  list,
  @HiveField(1)
  grid;

  /// Human-readable version of this enum. I've written longer descriptions on
  /// enums like [ContentType], and I can't be bothered to copy and paste it
  /// again.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case ContentViewType.list:
        return l10n.list;
      case ContentViewType.grid:
        return l10n.grid;
    }
  }
}

@HiveType(typeId: 3)
@JsonSerializable(explicitToJson: true, anyMap: true)
@Deprecated("Hive download schemas are only present to enable migration.")
class DownloadedTrack {
  DownloadedTrack({
    required this.track,
    required this.mediaSourceInfo,
    required this.downloadId,
    required this.requiredBy,
    required this.path,
    required this.useHumanReadableNames,
    required this.viewId,
    this.isPathRelative = true,
    required this.downloadLocationId,
  });

  /// The Jellyfin item for the track
  @HiveField(0)
  BaseItemDto track;

  /// The media source info for the track (used to get file format)
  @HiveField(1)
  MediaSourceInfo mediaSourceInfo;

  /// The download ID of the track (for FlutterDownloader)
  @HiveField(2)
  String downloadId;

  /// The list of parent item IDs the item is downloaded for. If this is 0, the
  /// track should be deleted.
  @HiveField(3)
  List<String> requiredBy;

  /// The path of the track file. if [isPathRelative] is true, this will be a
  /// relative path from the track's DownloadLocation.
  @HiveField(4)
  String path;

  /// Whether or not the file is stored with a human readable name. We need this
  /// when deleting downloads, as we need to check for empty folders when
  /// deleting files with human readable names.
  @HiveField(5)
  bool useHumanReadableNames;

  /// The view that this download is in. Used for sorting in offline mode.
  @HiveField(6)
  String viewId;

  /// Whether or not [path] is relative.
  @HiveField(7, defaultValue: false)
  bool isPathRelative;

  /// The ID of the DownloadLocation that holds this file. Will be null if made
  /// before 0.6.
  @HiveField(8)
  String? downloadLocationId;

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) => _$DownloadedTrackFromJson(json);

  Map<String, dynamic> toJson() => _$DownloadedTrackToJson(this);
}

@HiveType(typeId: 4)
@Deprecated("Hive download schemas are only present to enable migration.")
class DownloadedParent {
  DownloadedParent({required this.item, required this.downloadedChildren, required this.viewId});

  @HiveField(0)
  BaseItemDto item;
  @HiveField(1)
  Map<String, BaseItemDto> downloadedChildren;

  /// The view that this download is in. Used for sorting in offline mode.
  @HiveField(2)
  String viewId;
}

@HiveType(typeId: 40)
@Deprecated("Hive download schemas are only present to enable migration.")
class DownloadedImage {
  DownloadedImage({
    required this.id,
    required this.downloadId,
    required this.path,
    required this.requiredBy,
    required this.downloadLocationId,
  });

  /// The image ID
  @HiveField(0)
  String id;

  /// The download ID of the track (for FlutterDownloader)
  @HiveField(1)
  String downloadId;

  /// The relative path to the image file. To get the absolute path, use the
  /// file getter.
  @HiveField(2)
  String path;

  /// The list of item IDs that use this image. If this is empty, the image
  /// should be deleted.
  @HiveField(3)
  List<String> requiredBy;

  /// The ID of the DownloadLocation that holds this file.
  @HiveField(4)
  String downloadLocationId;

  /// Creates a new DownloadedImage. Does not actually handle downloading or
  /// anything. This is only really a thing since having to manually specify
  /// empty lists is a bit jank.
  static DownloadedImage create({
    required String id,
    required String downloadId,
    required String path,
    List<String>? requiredBy,
    required String downloadLocationId,
  }) => DownloadedImage(
    id: id,
    downloadId: downloadId,
    path: path,
    requiredBy: requiredBy ?? [],
    downloadLocationId: downloadLocationId,
  );
}

/// A reference to a downloadable item with no state.  Can be freely created
/// from a BaseItemDto at any time.  DownloadStubs/DownloadItems are considered
/// equivalent if their types and ids match.
@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true, constructor: "_build")
class DownloadStub {
  DownloadStub._build({
    required this.id,
    required this.type,
    required this.jsonItem,
    required this.isarId,
    required this.name,
    required this.baseItemType,
  }) {
    assert(_verifyEnums(), "$type $baseItemType ${baseItem?.toJson().toString()}");
  }

  bool _verifyEnums() {
    switch (type) {
      case DownloadItemType.collection:
        return baseItem != null &&
            BaseItemDtoType.fromItem(baseItem!) == baseItemType &&
            baseItemType.downloadType == DownloadItemType.collection &&
            baseItemType != BaseItemDtoType.noItem;
      case DownloadItemType.track:
        return baseItemType.downloadType == DownloadItemType.track &&
            baseItem != null &&
            BaseItemDtoType.fromItem(baseItem!) == baseItemType;
      case DownloadItemType.image:
        return baseItem != null;
      case DownloadItemType.finampCollection:
        return baseItem == null && baseItemType == BaseItemDtoType.noItem && finampCollection != null;
      case DownloadItemType.anchor:
        return baseItem == null && baseItemType == BaseItemDtoType.noItem && id == "Anchor";
    }
  }

  factory DownloadStub.fromItem({required DownloadItemType type, required BaseItemDto item}) {
    assert(type.requiresItem);
    assert(type != DownloadItemType.image || (item.blurHash != null || item.imageId != null));
    String id = (type == DownloadItemType.image) ? item.blurHash ?? item.imageId! : item.id.raw;
    return DownloadStub._build(
      id: id,
      isarId: getHash(id, type),
      jsonItem: jsonEncode(item.toJson()),
      type: type,
      name: (type == DownloadItemType.image) ? "Image for ${item.name}" : item.name ?? id,
      baseItemType: BaseItemDtoType.fromItem(item),
    );
  }

  factory DownloadStub.fromId({required BaseItemId id, required DownloadItemType type, required String? name}) {
    assert(!type.requiresItem);
    return DownloadStub._build(
      id: id.raw,
      isarId: getHash(id.raw, type),
      jsonItem: null,
      type: type,
      name: name ?? "[$id]",
      baseItemType: BaseItemDtoType.noItem,
    );
  }

  factory DownloadStub.fromFinampCollection(FinampCollection collection) {
    String id = collection.id;

    return DownloadStub._build(
      id: id,
      isarId: getHash(id, DownloadItemType.finampCollection),
      jsonItem: jsonEncode(collection.toJson()),
      type: DownloadItemType.finampCollection,
      // Fetch localized name from default global context.
      name: collection.getName(GlobalSnackbar.requireL10n),
      baseItemType: BaseItemDtoType.noItem,
    );
  }

  /// The integer iD used as a database key by Isar
  final Id isarId;

  /// The id string of the underlying BaseItemDto
  final String id;

  /// The name of the underlying BaseItemDto
  final String name;

  @Enumerated(EnumType.ordinal)
  final BaseItemDtoType baseItemType;

  @Enumerated(EnumType.ordinal)
  @Index()
  final DownloadItemType type;

  /// The baseItemDto as a JSON string for storage in isar.
  /// Use baseItem to retrieve.
  final String? jsonItem;

  @ignore
  BaseItemDto? get baseItem => _baseItemCached ??= ((jsonItem == null || !type.requiresItem)
      ? null
      : BaseItemDto.fromJson(jsonDecode(jsonItem!) as Map<String, dynamic>));

  @ignore
  BaseItemDto? _baseItemCached;

  @ignore
  FinampCollection? get finampCollection => _finampCollectionCached ??= (type != DownloadItemType.finampCollection
      ? null
      : jsonItem == null
      // Switch on ID to allow legacy collections to continue syncing
      ? switch (id) {
          "Favorites" => FinampCollection(type: FinampCollectionType.favorites),
          "All Playlists" => FinampCollection(type: FinampCollectionType.allPlaylists),
          "5 Latest Albums" => FinampCollection(type: FinampCollectionType.latest5Albums),
          _ => throw "Invalid FinampCollection DownloadItem: no attached collection",
        }
      : FinampCollection.fromJson(jsonDecode(jsonItem!) as Map<String, dynamic>));

  @ignore
  FinampCollection? _finampCollectionCached;

  /// FNV-1a 64bit hash algorithm optimized for Dart Strings
  /// Provided by Isar documentation
  /// Do not use directly, use getHash
  static int _fastHash(String string) {
    var hash = 0xcbf29ce484222325;

    var i = 0;
    while (i < string.length) {
      final codeUnit = string.codeUnitAt(i++);
      hash ^= codeUnit >> 8;
      hash *= 0x100000001b3;
      hash ^= codeUnit & 0xFF;
      hash *= 0x100000001b3;
    }

    return hash;
  }

  /// Calculate a DownloadStub's isarId
  static int getHash(String id, DownloadItemType type) {
    return _fastHash(type.isarType + id);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadStub && other.isarId == isarId;
  }

  @override
  @ignore
  int get hashCode => isarId;

  /// For use by downloadsService during database inserts.  Do not call directly.
  DownloadItem asItem(DownloadProfile? transcodingProfile) {
    return DownloadItem(
      id: id,
      type: type,
      jsonItem: jsonItem,
      isarId: isarId,
      name: name,
      state: DownloadItemState.notDownloaded,
      baseItemType: baseItemType,
      baseIndexNumber: baseItem?.indexNumber,
      parentIndexNumber: baseItem?.parentIndexNumber,
      orderedChildren: null,
      path: null,
      isarViewId: null,
      userTranscodingProfile: null,
      syncTranscodingProfile: transcodingProfile,
      fileTranscodingProfile: null,
    );
  }

  factory DownloadStub.fromJson(Map<String, dynamic> json) => _$DownloadStubFromJson(json);
  Map<String, dynamic> toJson() => _$DownloadStubToJson(this);
}

/// Download metadata with state and file location information.  This should never
/// be built directly, and instead should be retrieved from Isar.
@collection
class DownloadItem extends DownloadStub {
  /// For use by Isar.  Do not call directly.
  DownloadItem({
    required super.id,
    required super.type,
    required super.jsonItem,
    required super.isarId,
    required super.name,
    required super.baseItemType,
    required this.state,
    required this.baseIndexNumber,
    required this.parentIndexNumber,
    required this.orderedChildren,
    required this.path,
    required this.isarViewId,
    required this.userTranscodingProfile,
    required this.syncTranscodingProfile,
    required this.fileTranscodingProfile,
  }) : super._build() {
    assert(!(type == DownloadItemType.collection && baseItemType == BaseItemDtoType.playlist) || viewId == null);
  }

  final requires = IsarLinks<DownloadItem>();

  @Backlink(to: "requires")
  final requiredBy = IsarLinks<DownloadItem>();

  final info = IsarLinks<DownloadItem>();

  @Backlink(to: "info")
  final infoFor = IsarLinks<DownloadItem>();

  /// Do not update directly.  Use downloadsService _updateItemState.
  @Enumerated(EnumType.ordinal)
  @Index()
  DownloadItemState state;

  /// index numbers from backing BaseItemDto.  Used to order tracks in albums.
  final int? baseIndexNumber;
  final int? parentIndexNumber;

  /// List of ordered isarIds of collection children.  This is used to order
  /// tracks in playlists.
  List<int>? orderedChildren;

  /// The path to the downloads file, relative to the download location's currentPath.
  String? path;

  /// The id of the view/library containing this item.  Will be null for playlists
  /// and child elements with no non-playlist parents.
  @ignore
  BaseItemId? get viewId => isarViewId == null ? null : BaseItemId(isarViewId!);
  set viewId(BaseItemId? id) => isarViewId = id?.raw;
  // Use viewId name to match older database entries
  @Name("viewId")
  String? isarViewId;

  DownloadProfile? userTranscodingProfile;
  DownloadProfile? syncTranscodingProfile;
  DownloadProfile? fileTranscodingProfile;

  @ignore
  DownloadLocation? get fileDownloadLocation =>
      FinampSettingsHelper.finampSettings.downloadLocationsMap[fileTranscodingProfile?.downloadLocationId];

  @ignore
  DownloadLocation? get syncDownloadLocation =>
      FinampSettingsHelper.finampSettings.downloadLocationsMap[syncTranscodingProfile?.downloadLocationId];

  @ignore
  File? get file {
    if (fileDownloadLocation == null || path == null) {
      return null;
    }

    return File(path_helper.join(fileDownloadLocation!.currentPath, path));
  }

  @override
  String toString() {
    return "$runtimeType ${type.name} '$name'";
  }

  /// Copy item with updated metadata.  Used inside _syncDownload, do not call elsewhere.
  DownloadItem? copyWith({
    BaseItemDto? item,
    List<DownloadStub>? orderedChildItems,
    BaseItemId? viewId,
    required bool forceCopy,
  }) {
    String? json;
    String? imageName;
    List<int>? newOrderedChildren;
    if (type == DownloadItemType.image) {
      // The only relevant attribute for an image is the imageid.  If it is unchanged, do not update.
      if (item == null) {
        return null;
      }
      if ((item.blurHash ?? item.imageId) != id) {
        throw "Could not update $name - incompatible new item $item";
      }
      if (item.imageId == baseItem!.imageId) {
        return null;
      }
      imageName = "Image for ${item.name}";
    } else {
      if (item != null) {
        if (baseItemType != BaseItemDtoType.fromItem(item) || baseItem == null) {
          throw "Could not update $name - incompatible new item $item";
        }
        if (item.id.raw != id) {
          throw "Could not update $name - incompatible new item $item";
        }
        // Not all BaseItemDto are requested with mediaSources, mediaStreams or childCount.  Do not
        // overwrite with null if the new item does not have them.
        item.mediaSources ??= baseItem?.mediaSources;
        item.sortName ??= baseItem?.sortName;
      }
      assert(
        item == null ||
            ((item.mediaSources == null || item.mediaSources!.isNotEmpty) &&
                (item.mediaStreams == null || item.mediaStreams!.isNotEmpty)),
      );
      newOrderedChildren = orderedChildItems?.map((e) => e.isarId).toList();
      if (!forceCopy) {
        if (viewId == null || viewId == this.viewId) {
          if (item == null || baseItem!.mostlyEqual(item)) {
            var equal = const DeepCollectionEquality().equals;
            if (equal(newOrderedChildren, orderedChildren)) {
              return null;
            }
          }
        }
      }
    }
    if (item != null) {
      json = jsonEncode(item.toJson());
    }
    return DownloadItem(
      baseIndexNumber: item?.indexNumber ?? baseIndexNumber,
      baseItemType: baseItemType,
      id: id,
      isarId: isarId,
      jsonItem: json ?? jsonItem,
      name: imageName ?? item?.name ?? name,
      orderedChildren: newOrderedChildren ?? orderedChildren,
      parentIndexNumber: item?.parentIndexNumber ?? parentIndexNumber,
      path: path,
      state: state,
      type: type,
      isarViewId: viewId?.raw ?? isarViewId,
      userTranscodingProfile: userTranscodingProfile,
      syncTranscodingProfile: syncTranscodingProfile,
      fileTranscodingProfile: fileTranscodingProfile,
    );
  }
}

/// The primary type of a DownloadItem.
///
/// Enumerated by Isar, do not modify order or delete existing entries.
/// New entries must be appended at the end of this list.
enum DownloadItemType {
  collection("collection", true, false),
  track("song", true, true),
  image("image", true, true),
  anchor("anchor", false, false),
  finampCollection("finampCollection", false, false);

  const DownloadItemType(this.isarType, this.requiresItem, this.hasFiles);

  ///!!! Used by `DownloadStub.getHash` to calculate the isarId for
  ///!!! the downloads system, DO NOT EDIT for any existing entries.
  ///!!! Doing so would invalidate existing downloads
  ///!!! and cause them to be deleted and re-downloaded.
  final String isarType;

  final bool requiresItem;
  final bool hasFiles;
}

/// The state of a DownloadItem's files and download task.
/// Obtain via downloadsService stateProvider.
/// Enumerated by Isar, do not modify order or delete existing entries.
enum DownloadItemState {
  notDownloaded,
  downloading,
  failed,
  complete,
  enqueued,
  syncFailed,
  needsRedownload,
  needsRedownloadComplete;

  bool get isFinal {
    switch (this) {
      case DownloadItemState.notDownloaded:
      case DownloadItemState.downloading:
      case DownloadItemState.enqueued:
        return false;
      case DownloadItemState.failed:
      case DownloadItemState.complete:
      case DownloadItemState.syncFailed:
      case DownloadItemState.needsRedownload:
      case DownloadItemState.needsRedownloadComplete:
        return true;
    }
  }

  bool get isComplete {
    switch (this) {
      case DownloadItemState.notDownloaded:
      case DownloadItemState.downloading:
      case DownloadItemState.enqueued:
      case DownloadItemState.syncFailed:
      case DownloadItemState.needsRedownload:
      case DownloadItemState.failed:
        return false;
      case DownloadItemState.complete:
      case DownloadItemState.needsRedownloadComplete:
        return true;
    }
  }

  static DownloadItemState fromTaskStatus(TaskStatus status) {
    assert(status != TaskStatus.paused);
    return switch (status) {
      // DownloadItemState.enqueued should only be reachable via _initiateDownload
      // or background_downloader listener to ensure item is ready to download
      TaskStatus.enqueued => DownloadItemState.downloading,
      TaskStatus.running => DownloadItemState.downloading,
      TaskStatus.complete => DownloadItemState.complete,
      TaskStatus.failed => DownloadItemState.failed,
      TaskStatus.canceled => DownloadItemState.notDownloaded,
      // Put paused items back in queue to be restarted
      TaskStatus.paused => DownloadItemState.enqueued,
      TaskStatus.notFound => DownloadItemState.failed,
      TaskStatus.waitingToRetry => DownloadItemState.downloading,
    };
  }
}

enum DeleteType {
  canDelete("canDelete"),
  cantDelete("cantDelete"),
  notDownloaded("notDownloaded");

  const DeleteType(this.textForm);
  final String textForm;
}

/// The status of a download, as used to determine download button state.
/// Obtain via downloadsService statusProvider.
enum DownloadItemStatus {
  /// not downloaded
  notNeeded(false, false, false),
  // downloaded over a parent
  incidental(false, false, true),
  incidentalOutdated(false, true, true),

  /// downloaded separately
  required(true, false, false),
  requiredOutdated(true, true, false);

  const DownloadItemStatus(this.isRequired, this.outdated, this.isIncidental);

  DeleteType toDeleteType() {
    return isRequired
        ? DeleteType.canDelete
        : (outdated || isIncidental ? DeleteType.cantDelete : DeleteType.notDownloaded);
  }

  final bool isRequired;
  final bool outdated;
  final bool isIncidental;

  bool get isDownloaded => isRequired || isIncidental;
}

/// The type of a BaseItemDto as determined from its type field.
/// Enumerated by Isar, do not modify order or delete existing entries
enum BaseItemDtoType {
  // TODO we should probably only have the types we care about
  // track, album, artist, playlist, library, collection.
  // Others should map to one if close enough, else throw.
  noItem(null, true, null, null),
  album("MusicAlbum", false, [track], DownloadItemType.collection),
  artist("MusicArtist", true, [album, track], DownloadItemType.collection),
  playlist("Playlist", true, [track], DownloadItemType.collection),
  genre("MusicGenre", true, [album, track], DownloadItemType.collection),
  track("Audio", false, [], DownloadItemType.track),
  library("CollectionFolder", true, [album, track], DownloadItemType.collection),
  folder("Folder", true, null, DownloadItemType.collection),
  musicVideo("MusicVideo", false, [], DownloadItemType.track),
  audioBook("AudioBook", false, [], DownloadItemType.track),
  tvEpisode("Episode", false, [], DownloadItemType.track),
  video("Video", false, [], DownloadItemType.track),
  movie("Movie", false, [], DownloadItemType.track),
  trailer("Trailer", false, [], DownloadItemType.track),
  //!!! apparently a typo in the API docs, "BoxSet" returns an invalid result (i.e. all libraries), but "BoxSets" returns the correct thing. at least for some requests?
  collection("BoxSet", true, [
    album, track, playlist, artist, genre, audioBook,
    // collection,
  ], DownloadItemType.collection),
  unknown(null, true, null, DownloadItemType.collection);

  // All possible types in Jellyfin as of 10.9:
  //"AggregateFolder" "Audio" "AudioBook" "BasePluginFolder" "Book" "BoxSet"
  // "Channel" "ChannelFolderItem" "CollectionFolder" "Episode" "Folder" "Genre"
  // "ManualPlaylistsFolder" "Movie" "LiveTvChannel" "LiveTvProgram" "MusicAlbum"
  // "MusicArtist" "MusicGenre" "MusicVideo" "Person" "Photo" "PhotoAlbum" "Playlist"
  // "PlaylistsFolder" "Program" "Recording" "Season" "Series" "Studio" "Trailer" "TvChannel"
  // "TvProgram" "UserRootFolder" "UserView" "Video" "Year"

  const BaseItemDtoType(this.jellyfinName, this.expectChanges, this.childTypes, this.downloadType);

  final String? jellyfinName;
  final bool expectChanges;
  final List<BaseItemDtoType>? childTypes;
  final DownloadItemType? downloadType;

  bool get expectChangesInChildren => childTypes?.any((x) => x.expectChanges) ?? true;

  bool get hasChildren => childTypes?.isNotEmpty ?? false;

  // BaseItemDto types that we handle like tracks have been handled by returning
  // the actual track type.  This may be a bad idea?
  static BaseItemDtoType fromItem(BaseItemDto item) {
    switch (item.type) {
      case "Audio":
      case "AudioBook":
      case "MusicVideo":
      case "Episode":
      case "Video":
      case "Movie":
      case "Trailer":
        return track;
      case "MusicAlbum":
        return album;
      case "MusicArtist":
        return artist;
      case "MusicGenre":
        return genre;
      case "Playlist":
        return playlist;
      case "CollectionFolder":
        return library;
      case "Folder":
        return folder;
      case "BoxSet":
        return collection;
      default:
        return unknown;
    }
  }

  // TODO stopgap solution until snackbars fate is decided
  static BaseItemDtoType? fromPlayableItem(FinampPlayable item) {
    switch (item) {
      case FinampPlayableDto():
        return BaseItemDtoType.fromItem(item.item);
      case _:
        return null;
    }
  }

  String localized(AppLocalizations l10n) => l10n.itemType(name);
}

/// The category of a section on the download screen.
/// Used to efficiently query downloads in the downloads_service
/// and displaying them to the user.
enum DownloadsScreenCategory {
  albums(DownloadItemType.collection, BaseItemDtoType.album),
  artists(DownloadItemType.collection, BaseItemDtoType.artist),
  playlists(DownloadItemType.collection, BaseItemDtoType.playlist),
  genres(DownloadItemType.collection, BaseItemDtoType.genre),
  tracks(DownloadItemType.track, BaseItemDtoType.track),
  special(DownloadItemType.finampCollection, null),
  library(DownloadItemType.collection, BaseItemDtoType.library);

  const DownloadsScreenCategory(this.type, this.baseItemType);

  final DownloadItemType type;
  final BaseItemDtoType? baseItemType;
}

@HiveType(typeId: 43)
class OfflineListen {
  OfflineListen({
    required this.timestamp,
    required this.userId,
    required this.itemId,
    required this.name,
    this.artist,
    this.album,
    this.trackMbid,
    this.deviceInfo,
  });

  /// The stop timestamp of the listen, measured in seconds since the epoch.
  @HiveField(0)
  int timestamp;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String itemId;

  @HiveField(3)
  String name;

  @HiveField(4)
  String? artist;

  @HiveField(5)
  String? album;

  // The MusicBrainz ID of the track, if available.
  @HiveField(6)
  String? trackMbid;

  @HiveField(7)
  DeviceInfo? deviceInfo;
}

@HiveType(typeId: 50)
enum FinampPlaybackOrder {
  @HiveField(0)
  shuffled,
  @HiveField(1)
  linear,
}

@HiveType(typeId: 51)
enum FinampLoopMode {
  @HiveField(0)
  none,
  @HiveField(1)
  one,
  @HiveField(2)
  all,
}

@HiveType(typeId: 52)
enum QueueItemSourceType {
  @HiveField(0)
  album,
  @HiveField(1)
  playlist,
  @HiveField(2)
  trackMix,
  @HiveField(3)
  artistMix,
  @HiveField(4)
  albumMix,
  @HiveField(5)
  favorites,
  @HiveField(6)
  allTracks,
  @HiveField(7)
  filteredList,
  @HiveField(8)
  genre,
  @HiveField(9)
  artist,
  @HiveField(10)
  nextUp,
  @HiveField(11)
  nextUpAlbum,
  @HiveField(12)
  nextUpPlaylist,
  @HiveField(13)
  nextUpArtist,
  @HiveField(14)
  nextUpGenre,
  @HiveField(15)
  formerNextUp,
  @HiveField(16)
  downloads,
  @HiveField(17)
  queue,
  @HiveField(18)
  unknown,
  @HiveField(19)
  genreMix,
  @HiveField(20)
  track,
  @HiveField(21)
  remoteClient,
  @HiveField(22)
  radio,
  @HiveField(23)
  homeScreenSection,
  @HiveField(24)
  collection,
  @HiveField(25)
  collectionMix,
}

@HiveType(typeId: 53)
enum QueueItemQueueType {
  @HiveField(0)
  previousTracks,
  @HiveField(1)
  currentTrack,
  @HiveField(2)
  nextUp,
  @HiveField(3)
  queue,
}

@HiveType(typeId: 54)
class QueueItemSource {
  const QueueItemSource.rawId({
    required this.type,
    required this.name,
    required this.id,
    this.item,
    this.contextNormalizationGain,
  });

  /*factory QueueItemSource.fromPlayableItem(
    PlayableItem playableItem, {
    QueueItemSourceType? type,
    QueueItemSourceNameType? nameType,
  }) {
    switch (playableItem) {
      case AlbumDisc():
        return QueueItemSource.fromBaseItem(playableItem.parent, type: type, nameType: nameType);
      case PlayableBaseItem():
        return QueueItemSource.fromBaseItem(playableItem.item, type: type, nameType: nameType);
      case HomeScreenPlayable():
        final context = GlobalSnackbar.materialAppScaffoldKey.currentContext!;
        return QueueItemSource.rawId(
          type: QueueItemSourceType.homeScreenSection,
          name: QueueItemSourceName(
            type: QueueItemSourceNameType.homeScreenSection,
            localizationParameter: playableItem.config.presetType?.name,
            pretranslatedName: playableItem.config.getTitle(context),
          ),
          id: playableItem.config.toLocalisedString(context),
        );
    }
  }*/

  factory QueueItemSource.fromBaseItem(
    BaseItemDto baseItem, {
    QueueItemSourceType? type,
    QueueItemSourceNameType? nameType,
  }) {
    final defaultType = switch (BaseItemDtoType.fromItem(baseItem)) {
      BaseItemDtoType.album => QueueItemSourceType.album,
      BaseItemDtoType.playlist => QueueItemSourceType.playlist,
      BaseItemDtoType.artist => QueueItemSourceType.artist,
      BaseItemDtoType.genre => QueueItemSourceType.genre,
      BaseItemDtoType.track => QueueItemSourceType.track,
      _ => QueueItemSourceType.unknown,
    };

    final gain = switch (BaseItemDtoType.fromItem(baseItem)) {
      BaseItemDtoType.playlist => null,
      BaseItemDtoType.artist => null,
      _ => baseItem.normalizationGain,
    };

    return QueueItemSource(
      type: type ?? defaultType,
      name: nameType != null
          ? QueueItemSourceName(type: nameType, localizationParameter: baseItem.name ?? "")
          : QueueItemSourceName(
              type: QueueItemSourceNameType.preTranslated,
              pretranslatedName: baseItem.name ?? GlobalSnackbar.requireL10n.placeholderSource,
            ),
      id: baseItem.id,
      item: baseItem,
      contextNormalizationGain: gain,
    );
  }

  QueueItemSource withItem(BaseItemDto? item) {
    if (item?.id.raw != id) return this;
    return QueueItemSource.rawId(
      type: type,
      name: name,
      id: id,
      item: item,
      contextNormalizationGain: contextNormalizationGain,
    );
  }

  QueueItemSource({
    required this.type,
    required this.name,
    required BaseItemId id,
    this.item,
    this.contextNormalizationGain,
  }) : id = id.raw;

  @HiveField(0)
  final QueueItemSourceType type;

  @HiveField(1)
  final QueueItemSourceName name;

  @HiveField(2)
  final String id;

  //@HiveField(3)
  final BaseItemDto? item;

  @HiveField(4)
  final double? contextNormalizationGain;

  bool get wantsItem => item == null && RegExp(r'^[0-9a-f]{32}$').matchAsPrefix(id) != null;

  @override
  bool operator ==(Object other) {
    return other is QueueItemSource &&
        other.type == type &&
        other.name == name &&
        other.id == id &&
        other.contextNormalizationGain == contextNormalizationGain;
  }

  @override
  int get hashCode => Object.hash(type, name, id, contextNormalizationGain);

  @override
  String toString() => name.toString();
}

@HiveType(typeId: 55)
enum QueueItemSourceNameType {
  @HiveField(0)
  preTranslated,
  @HiveField(1)
  yourLikes,
  @HiveField(2)
  shuffleAll,
  @HiveField(3)
  mix,
  @HiveField(4)
  instantMix,
  @HiveField(5)
  nextUp,
  @HiveField(6)
  tracksFormerNextUp,
  @HiveField(7)
  savedQueue,
  @HiveField(8)
  queue,
  @HiveField(9)
  remoteClient,
  @HiveField(10)
  radio,
  @HiveField(11)
  homeScreenSection,
}

@HiveType(typeId: 56)
class QueueItemSourceName {
  const QueueItemSourceName({
    required this.type,
    this.pretranslatedName,
    this.localizationParameter, // used if only part of the name is translated
  });

  @HiveField(0)
  final QueueItemSourceNameType type;
  @HiveField(1)
  final String? pretranslatedName;
  @HiveField(2)
  final String? localizationParameter;

  String getLocalized(AppLocalizations localizations) {
    switch (type) {
      case QueueItemSourceNameType.preTranslated:
        return pretranslatedName ?? "";
      case QueueItemSourceNameType.yourLikes:
        return localizations.yourLikes;
      case QueueItemSourceNameType.shuffleAll:
        return localizations.shuffleAllQueueSource;
      case QueueItemSourceNameType.mix:
        return localizations.mix(localizationParameter ?? "");
      case QueueItemSourceNameType.instantMix:
        return localizations.instantMix;
      case QueueItemSourceNameType.nextUp:
        return localizations.nextUp;
      case QueueItemSourceNameType.tracksFormerNextUp:
        return localizations.tracksFormerNextUp;
      case QueueItemSourceNameType.savedQueue:
        return localizations.savedQueue;
      case QueueItemSourceNameType.queue:
        return localizations.queue;
      case QueueItemSourceNameType.remoteClient:
        return "";
      case QueueItemSourceNameType.radio:
        if (localizationParameter != null) {
          return localizations.radioForItem(localizationParameter!);
        } else {
          return localizations.radio;
        }
      case QueueItemSourceNameType.homeScreenSection:
        return localizationParameter != null
            ? HomeScreenSectionConfiguration.getTitleForPreset(
                l10n: localizations,
                presetType: HomeScreenSectionPresetType.values.byName(localizationParameter!),
              )
            : pretranslatedName ?? "";
    }
  }

  @override
  String toString() {
    switch (type) {
      case QueueItemSourceNameType.preTranslated:
        return "QueueSource(${type.name},$pretranslatedName)";
      default:
        return "QueueSource(${type.name},$localizationParameter)";
    }
  }

  @override
  bool operator ==(Object other) {
    return other is QueueItemSourceName &&
        other.type == type &&
        other.pretranslatedName == pretranslatedName &&
        other.localizationParameter == localizationParameter;
  }

  @override
  int get hashCode => Object.hash(type, pretranslatedName, localizationParameter);
}

@HiveType(typeId: 57)
class FinampQueueItem {
  FinampQueueItem({required this.item, required this.source, this.type = QueueItemQueueType.queue}) {
    id = const Uuid().v4();
  }

  @HiveField(0)
  late String id;

  @HiveField(1)
  MediaItem item;

  @HiveField(2)
  QueueItemSource source;

  @HiveField(3)
  QueueItemQueueType type;

  BaseItemDto get baseItem {
    return BaseItemDto.fromJson(item.extras!["itemJson"] as Map<String, dynamic>);
  }

  BaseItemId get baseItemId => item.extras!["itemJson"]["Id"] as BaseItemId;
}

@HiveType(typeId: 58)
class FinampQueueOrder {
  FinampQueueOrder({
    required this.items,
    required this.originalSource,
    required this.linearOrder,
    required this.shuffledOrder,
    required this.sourceLibrary,
  }) {
    id = const Uuid().v4();
  }

  @HiveField(0)
  List<FinampQueueItem> items;

  @HiveField(1)
  QueueItemSource originalSource;

  /// The linear order of the items in the queue. Used when shuffle is disabled.
  /// The integers at index x contains the index of the item within [items] at queue position x.
  @HiveField(2)
  List<int> linearOrder;

  /// The shuffled order of the items in the queue. Used when shuffle is enabled.
  /// The integers at index x contains the index of the item within [items] at queue position x.
  @HiveField(3)
  List<int> shuffledOrder;

  @HiveField(4)
  late String id;

  @HiveField(5)
  BaseItemDto? sourceLibrary;
}

@HiveType(typeId: 59)
class FinampQueueInfo {
  FinampQueueInfo({
    required this.id,
    required this.previousTracks,
    required this.currentTrack,
    required this.nextUp,
    required this.queue,
    required this.source,
    required this.saveState,
    required this.sourceLibrary,
  });

  @HiveField(0)
  List<FinampQueueItem> previousTracks;

  @HiveField(1)
  FinampQueueItem? currentTrack;

  @HiveField(2)
  List<FinampQueueItem> nextUp;

  @HiveField(3)
  List<FinampQueueItem> queue;

  @HiveField(4)
  QueueItemSource source;

  @HiveField(5)
  SavedQueueState saveState;

  @HiveField(6)
  String id;

  @HiveField(7)
  BaseItemDto? sourceLibrary;

  int get currentTrackIndex => previousTracks.length + (currentTrack == null ? 0 : 1);
  int get upcomingTrackCount => nextUp.length + queue.length;
  int get trackCount => currentTrackIndex + upcomingTrackCount;
  List<FinampQueueItem> get fullQueue => CombinedIterableView([
    previousTracks,
    currentTrack != null ? [currentTrack!] : <FinampQueueItem>[],
    nextUp,
    queue,
  ]).toList(growable: false);

  /// Remaining duration of queue.  Does not consider position in current track.
  Duration get remainingDuration {
    var remaining = 0;
    for (var item in CombinedIterableView([nextUp, queue])) {
      remaining += item.item.duration?.inMicroseconds ?? 0;
    }
    return Duration(microseconds: remaining);
  }

  Duration getDurationUntil(int offset) {
    var total = 0;
    for (var item in CombinedIterableView([nextUp, queue]).take(max(offset - 1, 0))) {
      total += item.item.duration?.inMicroseconds ?? 0;
    }
    return Duration(microseconds: total);
  }

  int getTrackCountWithinDuration(Duration duration) {
    var totalDuration = Duration.zero;
    var trackCount = 0;
    fullQueue.reversed.takeWhile((item) {
      totalDuration += item.item.duration ?? Duration.zero;
      trackCount += 1;
      return totalDuration < duration;
    }).toList();
    return trackCount;
  }

  int? getTrackIndexAfter(Duration offset) {
    var total = 0;
    for (var (index, item) in CombinedIterableView([nextUp, queue]).indexed) {
      total += item.item.duration?.inMicroseconds ?? 0;
      if (total >= offset.inMicroseconds) {
        return currentTrackIndex + index + 1;
      }
    }
    return null;
  }

  FinampQueueItem? getQueueItemByOffset(int offset) {
    final index = currentTrackIndex + offset;
    if (index < 0 || index >= fullQueue.length) {
      return null;
    }
    return fullQueue[index];
  }

  int? getOffsetForQueueItem(FinampQueueItem item) {
    final absoluteIndex = fullQueue.indexWhere((q) => q.id == item.id);
    if (absoluteIndex == -1) {
      return null;
    }
    final relativeOffset = absoluteIndex - currentTrackIndex;
    return relativeOffset > 0 ? relativeOffset + 1 : relativeOffset + 1;
  }

  Duration get totalDuration {
    var total = 0;
    for (var item in fullQueue) {
      total += item.item.duration?.inMicroseconds ?? 0;
    }
    return Duration(microseconds: total);
  }

  int get undownloadedTracks {
    return fullQueue.where((e) => e.item.extras?["android.media.extra.DOWNLOAD_STATUS"] != 2).length;
  }
}

@HiveType(typeId: 60)
class FinampHistoryItem {
  FinampHistoryItem({required this.item, required this.startTime, this.endTime});

  @HiveField(0)
  FinampQueueItem item;

  @HiveField(1)
  DateTime startTime;

  @HiveField(2)
  DateTime? endTime;

  /// The duration of the play session (up until the current moment if still playing)
  Duration? get playDuration {
    return (endTime == null ? startTime.difference(DateTime.now()) : endTime!.difference(startTime)).abs();
  }

  /// The percentage of the item that has been played (up until the current moment if still playing)
  /// This shows the listened duration, not the "played" duration. so skipping ahead does not increase the play percentage
  double? get playPercentage {
    final totalDuration = item.baseItem.runTimeTicksDuration() ?? item.item.duration;
    if (totalDuration == null) {
      return null;
    }
    return (playDuration!.inMicroseconds / totalDuration.inMicroseconds).clamp(0.0, 1.0);
  }
}

// type id 61 used to migrate FinampStorableQueueInfo

@HiveType(typeId: 62)
enum SavedQueueState {
  @HiveField(0)
  preInit,
  @HiveField(1)
  init,
  @HiveField(2)
  loading,
  @HiveField(3)
  saving,
  @HiveField(4)
  failed,
  @HiveField(5)
  pendingSave,
}

@HiveType(typeId: 63)
/// Describes which mode will be used for loudness normalization.
enum VolumeNormalizationMode {
  /// Use track normalization gain if playing unrelated tracks, use album normalization gain if playing albums
  @HiveField(0)
  hybrid,

  /// Use track normalization gain regardless of context
  @HiveField(1)
  trackBased,

  /// Only normalize if playing albums
  @HiveField(2)
  albumOnly,

  @HiveField(3)
  albumBased,
}

@HiveType(typeId: 64)
enum DownloadLocationType {
  @HiveField(0)
  internalDocuments(false, false, BaseDirectory.applicationDocuments),
  @HiveField(1)
  internalSupport(false, false, BaseDirectory.applicationSupport),
  @HiveField(2)
  external(true, false, BaseDirectory.root),
  @HiveField(3)
  custom(true, true, BaseDirectory.root),
  @HiveField(4)
  none(false, false, BaseDirectory.root),
  @HiveField(5)
  migrated(true, false, BaseDirectory.root),
  @HiveField(6)
  cache(false, false, BaseDirectory.root);

  const DownloadLocationType(this.needsPath, this.useHumanReadableNames, this.baseDirectory);

  /// true if the download location path must be supplied in the constructer,
  /// false if it is calculated from the baseDirectory
  final bool needsPath;
  final bool useHumanReadableNames;
  final BaseDirectory baseDirectory;

  static DownloadLocationType get platformDefaultDirectory =>
      (Platform.isIOS || Platform.isAndroid) ? DownloadLocationType.internalSupport : DownloadLocationType.cache;
}

@HiveType(typeId: 65)
enum FinampTranscodingCodec {
  @HiveField(0)
  aac("aac", true, 1.2),
  @HiveField(1)
  mp3("mp3", true, 1.0),
  @HiveField(2)
  opus("ogg", false, 2.0),
  @HiveField(3)
  // Container is null to fall back to real original container per track
  original(null, true, 99999999);

  const FinampTranscodingCodec(this.container, this.iosCompatible, this.quality);

  /// The container to use for the given codec
  final String? container;

  final bool iosCompatible;

  /// Allowed codecs with higher quality*bitrate are prioritized
  final double quality;
}

@embedded
class DownloadProfile {
  DownloadProfile({FinampTranscodingCodec? transcodeCodec, int? bitrate, this.downloadLocationId}) {
    codec =
        transcodeCodec ??
        (Platform.isIOS || Platform.isMacOS ? FinampTranscodingCodec.aac : FinampTranscodingCodec.opus);
    stereoBitrate = bitrate ?? (Platform.isIOS || Platform.isMacOS ? 256000 : 128000);
  }

  /// The codec to use for the given transcoding job
  @Enumerated(EnumType.ordinal)
  late FinampTranscodingCodec codec;

  /// The bitrate of the file, in bits per second (i.e. 320000 for 320kbps).
  /// This bitrate is used for stereo, use [bitrateChannels] to get a
  /// channel-dependent bitrate.  Should be ignored if codec is original.
  late int stereoBitrate;

  String? downloadLocationId;

  /// [bitrate], but multiplied to handle multiple channels. The current
  /// implementation returns the unmodified bitrate if [channels] is 2 or below
  /// (stereo/mono), doubles it if under 6, and triples it otherwise. This
  /// *should* handle the 5.1/7.1 case, apologies if you're reading this after
  /// wondering why your cinema-grade ∞-channel track sounds terrible when
  /// transcoded.
  int bitrateChannels(int channels) {
    // If stereo/mono, return the base bitrate
    if (channels <= 2) {
      return stereoBitrate;
    }

    // If 5.1, return the bitrate doubled
    if (channels <= 6) {
      return stereoBitrate * 2;
    }

    // Otherwise, triple the bitrate
    return stereoBitrate * 3;
  }

  @ignore
  String get bitrateKbps => "${stereoBitrate ~/ 1000}kbps";

  @ignore
  double get quality => codec == FinampTranscodingCodec.original ? 9999999999999 : codec.quality * stereoBitrate;

  @override
  bool operator ==(Object other) {
    return other is DownloadProfile &&
        (codec == FinampTranscodingCodec.original || other.stereoBitrate == stereoBitrate) &&
        other.codec == codec &&
        other.downloadLocationId == downloadLocationId;
  }

  @override
  @ignore
  int get hashCode =>
      Object.hash(codec == FinampTranscodingCodec.original ? 0 : stereoBitrate, codec, downloadLocationId);
}

@HiveType(typeId: 66)
enum TranscodeDownloadsSetting {
  @HiveField(0)
  always,
  @HiveField(1)
  never,
  @HiveField(2)
  ask,
}

/// TODO
@collection
class DownloadedLyrics {
  DownloadedLyrics({required this.jsonItem, required this.isarId});

  factory DownloadedLyrics.fromItem({required LyricDto item, required int isarId}) {
    return DownloadedLyrics(isarId: isarId, jsonItem: jsonEncode(item.toJson()));
  }

  /// The integer ID used as a database key by Isar
  final Id isarId;

  /// The LyricDto as a JSON string for storage in isar.
  /// Use [lyricDto] to retrieve.
  final String? jsonItem;

  @ignore
  LyricDto? get lyricDto => _lyricDtoCached ??= ((jsonItem == null)
      ? null
      : LyricDto.fromJson(jsonDecode(jsonItem!) as Map<String, dynamic>));
  @ignore
  LyricDto? _lyricDtoCached;
}

@HiveType(typeId: 67)
enum PlaybackSpeedVisibility {
  @HiveField(0)
  automatic,
  @HiveField(1)
  visible,
  @HiveField(2)
  hidden;

  /// Human-readable version of this enum. I've written longer descriptions on
  /// enums like [ContentType], and I can't be bothered to copy and paste it
  /// again.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case PlaybackSpeedVisibility.automatic:
        return l10n.automatic;
      case PlaybackSpeedVisibility.visible:
        return l10n.shown;
      case PlaybackSpeedVisibility.hidden:
        return l10n.hidden;
    }
  }
}

enum FinampCollectionType {
  favorites(true),
  allPlaylists(true),
  latest5Albums(true),
  libraryImages(false),
  allPlaylistsMetadata(false),
  collectionWithLibraryFilter(true);

  const FinampCollectionType(this.hasAudio);

  final bool hasAudio;
}

@JsonSerializable(fieldRename: FieldRename.pascal, explicitToJson: true, anyMap: true, includeIfNull: false)
class FinampCollection {
  FinampCollection({required this.type, this.library, this.item}) {
    assert(
      (type == FinampCollectionType.libraryImages && library != null && item == null) ||
          (type == FinampCollectionType.collectionWithLibraryFilter && library != null && item != null) ||
          (type != FinampCollectionType.libraryImages &&
              type != FinampCollectionType.collectionWithLibraryFilter &&
              item == null &&
              library == null),
      'Invalid combination of type, library, and item for FinampCollection.',
    );
  }

  final FinampCollectionType type;
  final BaseItemDto? library;
  final BaseItemDto? item;

  String get id => switch (type) {
    FinampCollectionType.favorites => "Favorites",
    FinampCollectionType.allPlaylists => "All Playlists",
    FinampCollectionType.latest5Albums => "5 Latest Albums",
    FinampCollectionType.libraryImages => "Cache Library Images:${library!.id}",
    FinampCollectionType.allPlaylistsMetadata => "All Playlists Metadata",
    FinampCollectionType.collectionWithLibraryFilter => "Collection with Library Filter:${library!.id}:${item!.id}",
  };

  String getName(AppLocalizations localizations) => switch (type) {
    FinampCollectionType.favorites => localizations.finampCollectionNames("favorites"),
    FinampCollectionType.allPlaylists => localizations.finampCollectionNames("allPlaylists"),
    FinampCollectionType.latest5Albums => localizations.finampCollectionNames("fiveLatestAlbums"),
    FinampCollectionType.libraryImages => localizations.cacheLibraryImagesName(library!.name ?? ""),
    FinampCollectionType.allPlaylistsMetadata => localizations.finampCollectionNames("allPlaylistsMetadata"),
    FinampCollectionType.collectionWithLibraryFilter => item!.name ?? "Unkown Item",
  };

  factory FinampCollection.fromJson(Map<String, dynamic> json) => _$FinampCollectionFromJson(json);
  Map<String, dynamic> toJson() => _$FinampCollectionToJson(this);
}

@HiveType(typeId: 68)
enum MediaItemParentType {
  @HiveField(0)
  collection,
  @HiveField(1)
  rootCollection,
  @HiveField(2)
  instantMix,
}

@JsonSerializable(converters: [BaseItemIdConverter()])
@HiveType(typeId: 69)
class MediaItemId {
  MediaItemId({required this.contentType, required this.parentType, this.itemId, this.parentId});

  @HiveField(0)
  ContentType contentType;

  @HiveField(1)
  MediaItemParentType parentType;

  @HiveField(2)
  BaseItemId? itemId;

  @HiveField(3)
  BaseItemId? parentId;

  factory MediaItemId.fromJson(Map<String, dynamic> json) => _$MediaItemIdFromJson(json);

  Map<String, dynamic> toJson() => _$MediaItemIdToJson(this);

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

@HiveType(typeId: 70)
enum LyricsAlignment {
  @HiveField(0)
  start,
  @HiveField(1)
  center,
  @HiveField(2)
  end;

  /// Human-readable version of the [LyricsAlignment]
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case LyricsAlignment.start:
        return l10n.alignmentOptionStart;
      case LyricsAlignment.center:
        return l10n.alignmentOptionCenter;
      case LyricsAlignment.end:
        return l10n.alignmentOptionEnd;
    }
  }
}

@HiveType(typeId: 71)
enum LyricsFontSize {
  @HiveField(0)
  small,
  @HiveField(1)
  medium,
  @HiveField(2)
  large;

  /// Human-readable version of the [LyricsFontSize]
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case LyricsFontSize.small:
        return l10n.fontSizeOptionSmall;
      case LyricsFontSize.medium:
        return l10n.fontSizeOptionMedium;
      case LyricsFontSize.large:
        return l10n.fontSizeOptionLarge;
    }
  }
}

@HiveType(typeId: 72)
enum KeepScreenOnOption {
  @HiveField(0)
  disabled,
  @HiveField(1)
  alwaysOn,
  @HiveField(2)
  whilePlaying,
  @HiveField(3)
  whileLyrics;

  /// Human-readable version of this enum. I've written longer descriptions on
  /// enums like [ContentType], and I can't be bothered to copy and paste it
  /// again.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case KeepScreenOnOption.disabled:
        return l10n.keepScreenOnDisabled;
      case KeepScreenOnOption.alwaysOn:
        return l10n.keepScreenOnAlwaysOn;
      case KeepScreenOnOption.whilePlaying:
        return l10n.keepScreenOnWhilePlaying;
      case KeepScreenOnOption.whileLyrics:
        return l10n.keepScreenOnWhileLyrics;
    }
  }
}

@HiveType(typeId: 73)
enum FinampTranscodingStreamingFormat {
  @HiveField(0)
  aacMpegTS("aac", "ts"),
  @HiveField(1)
  aacFragmentedMp4("aac", "mp4"),
  @HiveField(2)
  opusFragmentedMp4("opus", "mp4"),
  @HiveField(3)
  flacFragmentedMp4("flac", "mp4"),
  @HiveField(4)
  vorbisMpegTS("vorbis", "ts"),
  @HiveField(5)
  vorbisFragmentedMp4("vorbis", "mp4");

  const FinampTranscodingStreamingFormat(this.codec, this.container);

  final String codec;

  /// The container to use to transport the segments
  final String container;

  int get sampleRate => switch (this) {
    FinampTranscodingStreamingFormat.opusFragmentedMp4 => 48000,
    FinampTranscodingStreamingFormat.flacFragmentedMp4 => 48000,
    _ => 44100,
  };

  bool get lossless => switch (this) {
    FinampTranscodingStreamingFormat.flacFragmentedMp4 => true,
    _ => false,
  };
}

@HiveType(typeId: 74)
enum FinampFeatureChipType {
  @HiveField(0)
  playCount,
  @HiveField(1)
  additionalPeople,
  @HiveField(2)
  playbackMode,
  @HiveField(3)
  codec,
  @HiveField(4)
  bitRate,
  @HiveField(5)
  bitDepth,
  @HiveField(6)
  size,
  @HiveField(7)
  normalizationGain,
  @HiveField(8)
  sampleRate,
  @HiveField(9)
  explicit;

  /// Human-readable version of the [FinampFeatureChipType]
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case FinampFeatureChipType.playCount:
        return l10n.playCount;
      case FinampFeatureChipType.additionalPeople:
        return l10n.additionalPeople;
      case FinampFeatureChipType.playbackMode:
        return l10n.playbackMode;
      case FinampFeatureChipType.codec:
        return l10n.codec;
      case FinampFeatureChipType.bitRate:
        return l10n.bitRate;
      case FinampFeatureChipType.bitDepth:
        return l10n.bitDepth;
      case FinampFeatureChipType.size:
        return l10n.size;
      case FinampFeatureChipType.normalizationGain:
        return l10n.normalizationGain;
      case FinampFeatureChipType.sampleRate:
        return l10n.sampleRate;
      case FinampFeatureChipType.explicit:
        return l10n.explicit;
    }
  }
}

@JsonSerializable()
@HiveType(typeId: 75)
class FinampFeatureChipsConfiguration {
  const FinampFeatureChipsConfiguration({required this.enabled, required this.features});

  @HiveField(0)
  final bool enabled;

  @HiveField(1)
  final List<FinampFeatureChipType> features;

  factory FinampFeatureChipsConfiguration.fromJson(Map<String, dynamic> json) =>
      _$FinampFeatureChipsConfigurationFromJson(json);

  Map<String, dynamic> toJson() => _$FinampFeatureChipsConfigurationToJson(this);

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  // implement copyWith
  FinampFeatureChipsConfiguration copyWith({bool? enabled, List<FinampFeatureChipType>? features}) {
    return FinampFeatureChipsConfiguration(enabled: enabled ?? this.enabled, features: features ?? this.features);
  }
}

@HiveType(typeId: 76)
class DeviceInfo {
  DeviceInfo({required this.name, required this.id});

  @HiveField(0)
  String name;

  @HiveField(1)
  String? id;
}

@HiveType(typeId: 77)
enum ReleaseDateFormat {
  @HiveField(0)
  year,
  @HiveField(1)
  iso,
  @HiveField(2)
  monthYear,
  @HiveField(3)
  monthDayYear;

  /// Human-readable version of this enum. I've written longer descriptions on
  /// enums like [ContentType], and I can't be bothered to copy and paste it
  /// again.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case ReleaseDateFormat.year:
        return l10n.releaseDateFormatYear;
      case ReleaseDateFormat.iso:
        return l10n.releaseDateFormatISO;
      case ReleaseDateFormat.monthYear:
        return l10n.releaseDateFormatMonthYear;
      case ReleaseDateFormat.monthDayYear:
        return l10n.releaseDateFormatMonthDayYear;
    }
  }
}

@HiveType(typeId: 78)
enum AutoOfflineOption {
  @HiveField(0)
  disabled,
  @HiveField(1)
  network,
  @HiveField(2)
  disconnected,
  @HiveField(3)
  unreachable;

  String toLocalisedString(BuildContext context) {
    switch (this) {
      case AutoOfflineOption.disabled:
        // return AppLocalizations.of(context)!.keepScreenOnDisabled;
        return AppLocalizations.of(context)!.autoOfflineOptionOff;
      case AutoOfflineOption.network:
        // return AppLocalizations.of(context)!.keepScreenOnAlwaysOn;
        return AppLocalizations.of(context)!.autoOfflineOptionNetwork;
      case AutoOfflineOption.disconnected:
        // return AppLocalizations.of(context)!.keepScreenOnWhilePlaying;
        return AppLocalizations.of(context)!.autoOfflineOptionDisconnected;
      case AutoOfflineOption.unreachable:
        return AppLocalizations.of(context)!.autoOfflineOptionUnreachable;
    }
  }
}

@HiveType(typeId: 92)
enum ItemSwipeActions {
  @HiveField(0)
  nothing,
  @HiveField(1)
  addToQueue,
  @HiveField(2)
  addToNextUp,
  @HiveField(3)
  playNext;

  /// Human-readable version of this enum.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case ItemSwipeActions.nothing:
        return l10n.keepScreenOnDisabled; // reused here
      case ItemSwipeActions.addToQueue:
        return l10n.addToQueue;
      case ItemSwipeActions.addToNextUp:
        return l10n.addToNextUp;
      case ItemSwipeActions.playNext:
        return l10n.playNext;
    }
  }
}

/// Enum for artist list types
@HiveType(typeId: 93)
enum ArtistType {
  @HiveField(0)
  albumArtist,
  @HiveField(1)
  artist;

  ContentType get tabType => switch (this) {
    ArtistType.albumArtist => ContentType.albumArtists,
    ArtistType.artist => ContentType.performingArtists,
  };
}

@JsonSerializable()
class FinampOutputRoute {
  // mapOf(
  //   "name" to route.name,
  //   "connectionState" to route.connectionState,
  //   "isSystemRoute" to route.isSystemRoute,
  //   "isDefault" to route.isDefault,
  //   "isDeviceSpeaker" to route.isDeviceSpeaker,
  //   "isBluetooth" to route.isBluetooth,
  //   "volume" to route.volume,
  //   "providerPackageName" to route.provider.packageName
  // )

  @HiveField(0)
  final String name;
  @HiveField(1)
  final int connectionState;
  @HiveField(2)
  final bool isSystemRoute;
  @HiveField(3)
  final bool isDefault;
  @HiveField(4)
  final bool isDeviceSpeaker;
  @HiveField(5)
  final bool isBluetooth;
  @HiveField(6)
  final double volume;
  @HiveField(7)
  final String providerPackageName;
  @HiveField(8)
  final bool isSelected;
  @HiveField(9)
  final int deviceType;
  @HiveField(10)
  final String? description;
  @HiveField(11)
  final Object? extras;
  @HiveField(12)
  final String? iconUri;
  // @HiveField(13)
  // final List<Object>? controlFilters;

  FinampOutputRoute({
    required this.name,
    required this.connectionState,
    required this.isSystemRoute,
    required this.isDefault,
    required this.isDeviceSpeaker,
    required this.isBluetooth,
    required this.volume,
    required this.providerPackageName,
    required this.isSelected,
    required this.deviceType,
    required this.description,
    required this.extras,
    required this.iconUri,
    // required this.controlFilters,
  });

  factory FinampOutputRoute.fromJson(Map<String, dynamic> json) {
    return _$FinampOutputRouteFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$FinampOutputRouteToJson(this);
  }
}

@HiveType(typeId: 94)
class ScreenSize {
  ScreenSize(this.sizeX, this.sizeY, this.locationX, this.locationY);

  ScreenSize.from(Size size, Offset location)
    : sizeX = size.width,
      sizeY = size.height,
      locationX = location.dx,
      locationY = location.dy;

  Size get size => Size(sizeX, sizeY);

  Offset get location => Offset(locationX, locationY);

  @HiveField(1)
  double sizeX;

  @HiveField(2)
  double sizeY;

  @HiveField(3)
  double locationX;

  @HiveField(4)
  double locationY;
}

@HiveType(typeId: 95)
enum CuratedItemSelectionType {
  @HiveField(0)
  mostPlayed,
  @HiveField(1)
  favorites,
  @HiveField(2)
  random,
  @HiveField(3)
  latestReleases,
  @HiveField(4)
  recentlyAdded,
  @HiveField(5)
  recentlyPlayed;

  /// Human-readable version of this enum.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case CuratedItemSelectionType.mostPlayed:
        return l10n.mostPlayed;
      case CuratedItemSelectionType.favorites:
        return l10n.favorites;
      case CuratedItemSelectionType.random:
        return l10n.random;
      case CuratedItemSelectionType.latestReleases:
        return l10n.latestReleases;
      case CuratedItemSelectionType.recentlyAdded:
        return l10n.recentlyAdded;
      case CuratedItemSelectionType.recentlyPlayed:
        return l10n.recentlyPlayed;
    }
  }

  String toLocalisedSectionTitle(BuildContext context, BaseItemDtoType baseType) {
    final loc = AppLocalizations.of(context)!;

    String? getTitle(String track, String album, String artist) {
      switch (baseType) {
        case BaseItemDtoType.track:
          return track;
        case BaseItemDtoType.album:
          return album;
        case BaseItemDtoType.artist:
          return artist;
        default:
          return null;
      }
    }

    switch (this) {
      case CuratedItemSelectionType.mostPlayed:
        return getTitle(loc.topTracks, loc.topAlbums, loc.topArtists) ?? "Unsupported Type";
      case CuratedItemSelectionType.favorites:
        return getTitle(loc.favoriteTracks, loc.favoriteAlbums, loc.favoriteArtists) ?? "Unsupported Type";
      case CuratedItemSelectionType.random:
        return getTitle(loc.tracks, loc.albums, loc.artists) ?? "Unsupported Type";
      case CuratedItemSelectionType.latestReleases:
        return getTitle(loc.latestTracks, loc.latestAlbums, loc.latestArtists) ?? "Unsupported Type";
      case CuratedItemSelectionType.recentlyAdded:
        return getTitle(loc.recentlyAddedTracks, loc.recentlyAddedAlbums, loc.recentlyAddedArtists) ??
            "Unsupported Type";
      case CuratedItemSelectionType.recentlyPlayed:
        return getTitle(loc.recentlyPlayedTracks, loc.recentlyPlayedAlbums, loc.recentlyPlayedArtists) ??
            "Unsupported Type";
    }
  }

  SortBy getSortBy() {
    switch (this) {
      case CuratedItemSelectionType.mostPlayed:
        return SortBy.playCount;
      case CuratedItemSelectionType.favorites:
        return SortBy.random;
      case CuratedItemSelectionType.random:
        return SortBy.random;
      case CuratedItemSelectionType.latestReleases:
        return SortBy.premiereDate;
      case CuratedItemSelectionType.recentlyAdded:
        return SortBy.dateCreated;
      case CuratedItemSelectionType.recentlyPlayed:
        return SortBy.datePlayed;
    }
  }
}

@HiveType(typeId: 96)
enum GenreItemSections {
  @HiveField(0)
  tracks,
  @HiveField(1)
  albums,
  @HiveField(2)
  artists;

  /// Human-readable version of this enum.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case GenreItemSections.tracks:
        return l10n.tracks;
      case GenreItemSections.albums:
        return l10n.albums;
      case GenreItemSections.artists:
        return l10n.artists;
    }
  }
}

@HiveType(typeId: 97)
enum ArtistItemSections {
  @HiveField(0)
  tracks,
  @HiveField(1)
  albums,
  @HiveField(2)
  appearsOn;

  /// Human-readable version of this enum.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case ArtistItemSections.tracks:
        return l10n.tracks;
      case ArtistItemSections.albums:
        return l10n.albums;
      case ArtistItemSections.appearsOn:
        return l10n.appearsOnAlbums;
    }
  }

  String toLocalisedSectionTitle(BuildContext context, CuratedItemSelectionType? curatedItemSelectionType) {
    final loc = AppLocalizations.of(context)!;

    String? getTitle(String tracks, String albums, String appearsOn) {
      switch (this) {
        case ArtistItemSections.tracks:
          return tracks;
        case ArtistItemSections.albums:
          return albums;
        case ArtistItemSections.appearsOn:
          return appearsOn;
      }
    }

    switch (curatedItemSelectionType) {
      case CuratedItemSelectionType.mostPlayed:
        return getTitle(loc.topTracks, loc.albums, loc.appearsOnAlbums) ?? "Unsupported Type";
      case CuratedItemSelectionType.favorites:
        return getTitle(loc.favoriteTracks, loc.albums, loc.appearsOnAlbums) ?? "Unsupported Type";
      case CuratedItemSelectionType.random:
        return getTitle(loc.randomTracks, loc.albums, loc.appearsOnAlbums) ?? "Unsupported Type";
      case CuratedItemSelectionType.latestReleases:
        return getTitle(loc.latestTracks, loc.albums, loc.appearsOnAlbums) ?? "Unsupported Type";
      case CuratedItemSelectionType.recentlyAdded:
        return getTitle(loc.recentlyAddedTracks, loc.albums, loc.appearsOnAlbums) ?? "Unsupported Type";
      case CuratedItemSelectionType.recentlyPlayed:
        return getTitle(loc.recentlyPlayedTracks, loc.albums, loc.appearsOnAlbums) ?? "Unsupported Type";
      case null:
        return getTitle(loc.tracks, loc.albums, loc.appearsOnAlbums) ?? "Unsupported Type";
    }
  }
}

@HiveType(typeId: 98)
class SleepTimer {
  /// Length of the timer, in seconds
  @HiveField(1, defaultValue: 0)
  int secondsLength;

  // Hive fields 0, 2 & 3 used on removed fields, do not re-use

  /// Length of the timer, in track count
  @HiveField(4, defaultValue: 0)
  int tracksLength;

  Timer? _timer;
  int? _tracksRemaining;

  DateTime? _startTime;
  Function? _callback;

  /// Notifier which is non-zero while the timer is running.  Updates at least as often as asString changes.
  final ValueNotifier<int> remainingNotifier = ValueNotifier(0);

  final sleepTimerLogger = Logger("SleepTimer");

  SleepTimer(this.secondsLength, this.tracksLength);

  Future<void> start(Function callback) async {
    assert(_timer == null && _tracksRemaining == null && _startTime == null && _timer == null);
    _startTime = DateTime.now();
    _callback = callback;

    remainingNotifier.value = secondsLength + tracksLength;

    if (secondsLength > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        final secondsLeft = remainingDuration.inSeconds;

        remainingNotifier.value = secondsLeft + tracksLength;

        if (secondsLeft <= 0) {
          t.cancel();
          _timer = null;
          if (tracksLength > 0) {
            sleepTimerLogger.info("Sleep timer switching to track count");
            _tracksRemaining = tracksLength;
          } else {
            sleepTimerLogger.info("Sleep timer duration finished");
            await _callback!();
          }
        }
      });
    } else {
      _tracksRemaining = tracksLength;
    }

    sleepTimerLogger.info("Sleep timer started for ${Duration(seconds: secondsLength)}, $tracksLength tracks");
  }

  void onTrackCompleted() {
    if (_tracksRemaining == null) return;
    assert(_startTime != null && _callback != null);
    _tracksRemaining = _tracksRemaining! - 1;
    remainingNotifier.value = _tracksRemaining!;
    if (_tracksRemaining! <= 0) {
      _tracksRemaining = null;
      sleepTimerLogger.info("Sleep timer tracks finished");
      _callback!();
    }
  }

  void cancel() {
    _startTime = null;
    _timer?.cancel();
    _timer = null;
    _tracksRemaining = null;
    remainingNotifier.value = 0;
    sleepTimerLogger.info("Sleep timer cancelled");
  }

  Duration get totalDuration => Duration(seconds: secondsLength);

  Duration get remainingDuration {
    if (_startTime == null) return Duration.zero;
    final diff = _startTime!.add(totalDuration).difference(DateTime.now());
    // we want to make sure playback ends when specified, so we need to be done fading by then
    final remaining = diff - FinampSettingsHelper.finampSettings.audioFadeOutDuration;
    return diff.isNegative ? Duration.zero : remaining;
  }

  int get remainingTracks => _tracksRemaining ?? 0;

  String asString(BuildContext context) {
    if (_tracksRemaining == null) {
      final minutes = (remainingDuration.inSeconds / 60).ceil();
      return AppLocalizations.of(context)!.sleepTimerRemainingTime(minutes);
    } else {
      return AppLocalizations.of(context)!.sleepTimerRemainingTracks(_tracksRemaining ?? 0);
    }
  }
}

@HiveType(typeId: 99)
@Deprecated("Removed in sleep timer refactor.  Class retained for hive.")
enum SleepTimerType {
  @HiveField(0)
  duration,

  @HiveField(1)
  tracks,
}

@HiveType(typeId: 100)
enum TileAdditionalInfoType {
  @HiveField(0)
  adaptive,
  @HiveField(1)
  dateAdded,
  @HiveField(2)
  dateReleased,
  @HiveField(3)
  duration,
  @HiveField(4)
  playCount,
  @HiveField(5)
  dateLastPlayed,
  @HiveField(6)
  none;

  /// Human-readable version of this enum.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case TileAdditionalInfoType.adaptive:
        return l10n.adaptive;
      case TileAdditionalInfoType.dateAdded:
        return l10n.dateAdded;
      case TileAdditionalInfoType.dateReleased:
        return l10n.premiereDate;
      case TileAdditionalInfoType.duration:
        return l10n.duration;
      case TileAdditionalInfoType.playCount:
        return l10n.playCount;
      case TileAdditionalInfoType.dateLastPlayed:
        return l10n.datePlayed;
      case TileAdditionalInfoType.none:
        return l10n.none;
    }
  }
}

@HiveType(typeId: 101)
enum DiscordRpcIcon {
  @HiveField(0)
  black,
  @HiveField(1)
  dark,
  @HiveField(2)
  light,
  @HiveField(3)
  transparent,
  @HiveField(4)
  transparentWhite,
  @HiveField(5)
  jellyfinTransparent;

  @override
  String toString() {
    switch (this) {
      case dark:
        return "dark";
      case black:
        return "black";
      case light:
        return "light";
      case transparent:
        return "transparent";
      case transparentWhite:
        return "transparent-white";
      case jellyfinTransparent:
        return "jellyfin-transparent";
    }
  }

  String toImage() {
    switch (this) {
      case dark:
        return "assets/icon/icon_combined.png";
      case black:
        return "assets/icon/icon_square_bg-black.png";
      case light:
        return "assets/icon/icon_square_bg-white.png";
      case transparent:
        return "images/finamp_cropped.png";
      case transparentWhite:
        return "assets/icon/icon_white_noborder.png";
      case jellyfinTransparent:
        return "images/jellyfin-icon-transparent.png"; // missing
    }
  }

  String toLocalisedString(BuildContext context) {
    switch (this) {
      case dark:
        return AppLocalizations.of(context)!.discordRPCIconDark;
      case black:
        return AppLocalizations.of(context)!.discordRPCIconBlack;
      case light:
        return AppLocalizations.of(context)!.discordRPCIconLight;
      case jellyfinTransparent:
        return AppLocalizations.of(context)!.discordRPCIconJFTransparent;
      case transparent:
        return AppLocalizations.of(context)!.discordRPCIconTransparent;
      case transparentWhite:
        return AppLocalizations.of(context)!.discordRPCIconWhiteTransparent;
    }
  }
}

@HiveType(typeId: 107)
enum PlaybackActionRowPage {
  @HiveField(0)
  newQueue,
  @HiveField(1)
  playNext,
  @HiveField(2)
  appendNext,
  @HiveField(3)
  playLast,
  @HiveField(4)
  moveWithinQueue,
  @HiveField(5)
  regularTrackOptions;

  /// Human-readable version of this enum.
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => toLocalisedString(GlobalSnackbar.englishL10n);

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case PlaybackActionRowPage.newQueue:
        return l10n.playbackActionPageNewQueue;
      case PlaybackActionRowPage.playNext:
        return l10n.playbackActionPageNext;
      case PlaybackActionRowPage.appendNext:
        return l10n.playbackActionPageNextUp;
      case PlaybackActionRowPage.playLast:
        return l10n.playbackActionPageAppendToQueue;
      case PlaybackActionRowPage.moveWithinQueue:
        return l10n.playbackActionPageMoveWithinQueue;
      case PlaybackActionRowPage.regularTrackOptions:
        return l10n.playbackActionPageRegularTrackOptions;
    }
  }
}

@HiveType(typeId: 108)
class RawThemeResult {
  RawThemeResult(this._highlightInt, this._backgroundInt);
  RawThemeResult.fromColors(Color highlight, Color background)
    : _highlightInt = highlight.toARGB32(),
      _backgroundInt = background.toARGB32();

  @HiveField(0)
  final int _highlightInt;
  Color get highlight => Color(_highlightInt);
  @HiveField(1)
  final int _backgroundInt;
  Color get background => Color(_backgroundInt);
}

@HiveType(typeId: 109)
enum RadioMode {
  @HiveField(0)
  similar,
  @HiveField(1)
  continuous,
  @HiveField(2)
  albumMix,
  @HiveField(3)
  reshuffle,
  @HiveField(4)
  random,
}

enum AlbumMixFallbackModes {
  similarSingles,
  artistAlbums,
  artistSingles,
  performingArtistAlbums,
  libraryAlbumsOrSingles,
}

class RadioCacheState {
  RadioCacheState({
    required this.tracks,
    required this.radioMode,
    required this.seedItem,
    required this.radioState,
    this.generating = false,
    this.queueing = false,
    this.failed = false,
    AlbumMixFallbackModes? albumMixFallbackMode,
  }) : _albumMixFallbackMode = albumMixFallbackMode;

  List<BaseItemDto> tracks;
  final RadioMode radioMode;
  final BaseItemDto? seedItem;
  final bool radioState;
  final bool generating;
  final bool queueing;
  final bool failed;
  AlbumMixFallbackModes? _albumMixFallbackMode;

  RadioCacheState copyWith({
    List<BaseItemDto>? tracks,
    RadioMode? radioMode,
    BaseItemDto? seedItem,
    BaseItemDto? previousSeedItem,
    bool? radioState,
    bool? generating,
    bool? queueing,
    bool? failed,
  }) {
    return RadioCacheState(
      tracks: tracks ?? this.tracks,
      radioMode: radioMode ?? this.radioMode,
      seedItem: seedItem ?? this.seedItem,
      radioState: radioState ?? this.radioState,
      generating: generating ?? this.generating,
      queueing: queueing ?? this.queueing,
      failed: failed ?? this.failed,
    );
  }

  bool get loading => generating || queueing;

  AlbumMixFallbackModes? get albumMixFallbackMode => _albumMixFallbackMode;
  void updateAlbumMixFallbackMode(AlbumMixFallbackModes? mode) {
    _albumMixFallbackMode = mode;
  }

  /// Ensures the radio settings used to obtain this result are still the same as the current settings
  bool isStillValid() {
    final currentRadioState = FinampSettingsHelper.finampSettings.radioEnabled;
    final currentRadioMode = FinampSettingsHelper.finampSettings.radioMode;
    final currentSeedItem = GetIt.instance<ProviderContainer>().read(getActiveRadioSeedProvider(currentRadioMode));
    return currentRadioState == radioState &&
        currentRadioMode == radioMode &&
        // Ignore incorrect seeds while the queue is actively being manipulated by the radio
        (currentSeedItem == seedItem || queueing);
  }
}

@HiveType(typeId: 110)
@immutable
// Migration adapter uses hive type id 61.  We extend an empty class to prevent adapter conflicts.
class FinampStorableQueueInfo extends FinampStorableQueueInfoLegacy {
  const FinampStorableQueueInfo({
    required this.currentTrackSeek,
    required this.creation,
    required this.sourceList,
    required this.packedPreviousTracks,
    required this.packedCurrentTrack,
    required this.packedNextUp,
    required this.packedQueue,
    required this.sourceIndex,
    required this.trackSourceIndexes,
    required this.packedShuffleOrder,
  });

  factory FinampStorableQueueInfo.fromQueueInfo(
    FinampQueueInfo info,
    int? seek,
    FinampPlaybackOrder? order,
    List<int> shuffleOrder,
  ) {
    final List<QueueItemSource> sourceList = [];
    final List<int> sourceIndexes = [];

    int addSource(QueueItemSource source) {
      final index = sourceList.indexOf(source);
      if (index >= 0) return index;
      sourceList.add(source);
      return sourceList.length - 1;
    }

    void appendTrackSource(FinampQueueItem track) {
      sourceIndexes.add(addSource(track.source));
    }

    // Tracks must be processed in order due to appending to sourceIndexes.
    // All sources must be added to sourceList before sourceIndexes can be bitpacked.
    info.previousTracks.forEach(appendTrackSource);
    if (info.currentTrack != null) appendTrackSource(info.currentTrack!);
    info.nextUp.forEach(appendTrackSource);
    info.queue.forEach(appendTrackSource);
    final queueSource = addSource(info.source);

    assert(sourceIndexes.length == info.trackCount);
    assert(sourceList.isNotEmpty);

    // BitBuffer throws exception attempting to write 0 bit entries, so create empty buffer manually.
    final buffer = sourceList.length == 1
        ? BitBuffer()
        : BitBuffer.fromBits(sourceIndexes, bitsPerIndex: (sourceList.length - 1).bitLength);

    // Validate shuffle order matches queue tracks
    assert(shuffleOrder.length == info.trackCount);
    assert(shuffleOrder.toSet().length == shuffleOrder.length);
    bool validateNextUp() {
      // If we are not shuffled, the order will not be stored, so we do not need to and cannot validate.
      if (order != FinampPlaybackOrder.shuffled) return true;
      if ((info.currentTrack == null ? 0 : 1) + info.nextUp.length > 1) {
        int lastIndex = shuffleOrder[info.previousTracks.length];
        for (int i = 1; i < (info.currentTrack == null ? 0 : 1) + info.nextUp.length; i++) {
          final newIndex = shuffleOrder[info.previousTracks.length + i];
          if (newIndex != lastIndex + 1) return false;
          lastIndex = newIndex;
        }
      }
      return true;
    }

    assert(validateNextUp(), shuffleOrder.toString());

    final packedOrder = info.trackCount <= 1
        ? BitBuffer()
        : BitBuffer.fromBits(shuffleOrder, bitsPerIndex: (info.trackCount - 1).bitLength);
    return FinampStorableQueueInfo(
      packedPreviousTracks: packIds(info.previousTracks.map<BaseItemId>((track) => track.baseItemId).toList()),
      packedCurrentTrack: info.currentTrack == null ? Uint8List(0) : packIds([info.currentTrack!.baseItemId]),
      currentTrackSeek: seek,
      packedNextUp: packIds(info.nextUp.map<BaseItemId>((track) => track.baseItemId).toList()),
      packedQueue: packIds(info.queue.map<BaseItemId>((track) => track.baseItemId).toList()),
      creation: DateTime.now().millisecondsSinceEpoch,
      sourceList: sourceList,
      sourceIndex: queueSource,
      trackSourceIndexes: buffer.toUInt8List(),
      packedShuffleOrder: order == FinampPlaybackOrder.shuffled ? packedOrder.toUInt8List() : null,
    );
  }

  @HiveField(0)
  final Uint8List packedPreviousTracks;
  List<BaseItemId> get previousTracks => _unpackIds(packedPreviousTracks);

  @HiveField(1)
  final Uint8List packedCurrentTrack;
  BaseItemId? get currentTrack => _unpackIds(packedCurrentTrack).firstOrNull;

  @HiveField(2)
  final int? currentTrackSeek;

  @HiveField(3)
  final Uint8List packedNextUp;
  List<BaseItemId> get nextUp => _unpackIds(packedNextUp);

  @HiveField(4)
  final Uint8List packedQueue;
  List<BaseItemId> get queue => _unpackIds(packedQueue);

  @HiveField(5)
  // timestamp, milliseconds since epoch
  final int creation;

  @HiveField(6)
  final List<QueueItemSource> sourceList;

  @HiveField(7)
  final int sourceIndex;

  @HiveField(8)
  final Uint8List trackSourceIndexes;

  @HiveField(9)
  final Uint8List? packedShuffleOrder;

  QueueItemSource get source => sourceList[sourceIndex];

  List<QueueItemSource> get trackSources =>
      _unpackIntList(trackSourceIndexes, sourceList.length - 1).map((x) => sourceList[x]).toList();

  List<int>? get shuffleOrder =>
      packedShuffleOrder == null ? null : _unpackIntList(packedShuffleOrder!, max(0, trackCount - 1)).toList();

  int get trackCount =>
      (packedPreviousTracks.length + packedCurrentTrack.length + packedNextUp.length + packedQueue.length) ~/ 16;

  /// Source indexes in trackSourceIndexes are stored as n bit unsigned ints packed
  /// into a Uint8List, where n is the smallest number that can index into all entries
  /// in sourceList.  e.g. if sourceList.length=4, n=2.  If sourceList.length=1, n=0.
  /// This function unpacks them into individual ints.
  Iterable<int> _unpackIntList(Uint8List list, int maxEntry) sync* {
    final buffer = BitBuffer.fromUInt8List(list);
    final entries = trackCount;
    final entrySize = maxEntry.bitLength;
    assert(
      buffer.getSize() >= entries * entrySize,
      "Want $entries of size $entrySize from buffer pf size ${buffer.getSize()}",
    );
    final reader = buffer.reader();
    for (int i = 0; i < entries; i++) {
      yield reader.readBits(entrySize);
    }
  }

  static List<BaseItemId> _unpackIds(Uint8List ids) {
    List<BaseItemId> out = [];
    for (int i = 0; i < ids.length; i += 16) {
      String id = "";
      for (int j = 0; j < 16; j++) {
        id += ids[i + j].toRadixString(16).padLeft(2, "0");
      }
      out.add(BaseItemId(id));
    }
    return out;
  }

  /// Pack a list of BaseItemIds into a Uint8Lis.  BaseItemIds are assumed to be
  /// 16 byte values formatted as a hexadecimal string.
  static Uint8List packIds(List<BaseItemId> ids) {
    final buffer = Uint8List(ids.length * 16);
    for (int i = 0; i < buffer.length; i++) {
      final stringIndex = (i % 16) * 2;
      final hex = ids[i ~/ 16].raw.substring(stringIndex, stringIndex + 2);
      buffer[i] = int.parse(hex, radix: 16);
    }
    return buffer;
  }

  @override
  String toString() {
    return "previous:${previousTracks.length} current:$currentTrack seek:$currentTrackSeek next:${nextUp.length} queue:${queue.length} order:${packedShuffleOrder == null ? "linear" : "shuffled"} sources $sourceList";
  }
}

@HiveType(typeId: 111)
enum MultichannelHandlingSetting {
  @HiveField(0)
  stereoDownmixLossy,
  @HiveField(1)
  stereoDownmixAll,
  @HiveField(2)
  fixedBitrate,
  /**
    reserved for potential automatic bitrate calculation
  @HiveField(3)
  dynamicBitrate,
  **/
}

/// Describes initial state of "previous tracks" header on queue open
@HiveType(typeId: 112)
enum PreviousTracksPersistenceMode {
  /// Use last stored state
  @HiveField(0)
  persistent,

  /// Override state to be collapsed on open
  @HiveField(1)
  initiallyCollapsed,

  /// Override state to be expanded on open
  @HiveField(2)
  initiallyExpanded,
}

sealed class HomeScreenSectionBase {
  /// Human-readable version of the [HomeScreenSectionType]
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson();
}

@HiveType(typeId: 113)
@JsonSerializable(includeIfNull: false)
class QueuesHomeSection extends HomeScreenSectionBase {
  QueuesHomeSection();

  @override
  bool operator ==(Object other) {
    return other is QueuesHomeSection;
  }

  @override
  int get hashCode => 765346;

  @override
  Map<String, dynamic> toJson() => _$QueuesHomeSectionToJson(this);
}

@HiveType(typeId: 114)
@JsonSerializable(converters: [LibraryIdConverter()], includeIfNull: false)
class TabsHomeSection extends HomeScreenSectionBase {
  TabsHomeSection({required this.libraryId, required this.contentType});
  @HiveField(0)
  final ContentType contentType;
  @HiveField(1)
  final LibraryId libraryId;

  @override
  bool operator ==(Object other) {
    return other is TabsHomeSection && other.contentType == contentType && other.libraryId == libraryId;
  }

  @override
  int get hashCode => Object.hash(contentType, libraryId);

  @override
  Map<String, dynamic> toJson() => _$TabsHomeSectionToJson(this);
}

@HiveType(typeId: 115)
@JsonSerializable(converters: [LibraryIdConverter(), BaseItemIdConverter()], includeIfNull: false)
class CollectionHomeSection extends HomeScreenSectionBase {
  CollectionHomeSection({required this.itemId, required this.libraryId, required this.contentType});
  @HiveField(0)
  final BaseItemId itemId;
  @HiveField(1)
  final LibraryId libraryId;
  @HiveField(2)
  final ContentType contentType;

  @override
  bool operator ==(Object other) {
    return other is CollectionHomeSection &&
        other.itemId == itemId &&
        other.libraryId == libraryId &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => Object.hash(itemId, libraryId, contentType);

  @override
  Map<String, dynamic> toJson() => _$CollectionHomeSectionToJson(this);
}

// hive type 116-118 reserved for fusture home sections

@JsonSerializable(includeIfNull: false, createFactory: false)
@HiveType(typeId: 119)
class HomeScreenSectionConfiguration {
  @HiveField(0)
  final HomeScreenSectionBase base;
  @HiveField(1)
  final SortAndFilterConfiguration sortConfig;
  @HiveField(2)
  final String? customSectionTitle;
  @HiveField(3)
  final HomeScreenSectionPresetType? presetType;

  const HomeScreenSectionConfiguration({
    required this.base,
    required this.sortConfig,
    this.customSectionTitle,
    this.presetType,
  });

  factory HomeScreenSectionConfiguration.fromPreset(HomeScreenSectionPresetType presetType) => switch (presetType) {
    HomeScreenSectionPresetType.favoriteTracks => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.tracks),
      sortConfig: SortAndFilterConfiguration(
        sortBy: SortBy.random,
        sortOrder: SortOrder.ascending,
        filters: {ItemFilter(type: ItemFilterType.isFavorite)},
      ),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.favoriteAlbums => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.albums),
      sortConfig: SortAndFilterConfiguration(
        sortBy: SortBy.random,
        sortOrder: SortOrder.ascending,
        filters: {ItemFilter(type: ItemFilterType.isFavorite)},
      ),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.favoriteArtists => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.performingArtists),
      sortConfig: SortAndFilterConfiguration(
        sortBy: SortBy.random,
        sortOrder: SortOrder.ascending,
        filters: {ItemFilter(type: ItemFilterType.isFavorite)},
      ),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.favoritePlaylists => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.playlists),
      sortConfig: SortAndFilterConfiguration(
        sortBy: SortBy.random,
        sortOrder: SortOrder.ascending,
        filters: {ItemFilter(type: ItemFilterType.isFavorite)},
      ),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.favoriteGenres => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.genres),
      sortConfig: SortAndFilterConfiguration(
        sortBy: SortBy.random,
        sortOrder: SortOrder.ascending,
        filters: {ItemFilter(type: ItemFilterType.isFavorite)},
      ),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.recentlyAddedAlbums => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: allLibraryPlaceholder, contentType: ContentType.albums),
      sortConfig: SortAndFilterConfiguration(sortBy: SortBy.dateCreated, sortOrder: SortOrder.descending, filters: {}),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.recentlyAddedTracks => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.tracks),
      sortConfig: SortAndFilterConfiguration(sortBy: SortBy.dateCreated, sortOrder: SortOrder.descending, filters: {}),
      customSectionTitle: null,
      presetType: presetType,
    ),
    // HomeScreenSectionPresetType.recentlyPlayedPlaylists => HomeScreenSectionConfiguration(
    //   type: HomeScreenSectionType.tabView,
    //   itemId: null,
    //   contentType: TabContentType.playlists,
    //   sortAndFilterConfiguration: SortAndFilterConfiguration(
    //     sortBy: SortBy.datePlayed,
    //     sortOrder: SortOrder.descending,
    //     filters: {},
    //   ),
    //   customSectionTitle: null,
    //   presetType: presetType,
    // ),
    HomeScreenSectionPresetType.frequentlyPlayedAlbums => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.albums),
      sortConfig: SortAndFilterConfiguration(sortBy: SortBy.playCount, sortOrder: SortOrder.descending, filters: {}),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.frequentlyPlayedTracks => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.tracks),
      sortConfig: SortAndFilterConfiguration(sortBy: SortBy.playCount, sortOrder: SortOrder.descending, filters: {}),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.frequentlyPlayedArtists => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.performingArtists),
      sortConfig: SortAndFilterConfiguration(sortBy: SortBy.playCount, sortOrder: SortOrder.descending, filters: {}),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.neverPlayedAlbums => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.albums),
      sortConfig: SortAndFilterConfiguration(
        sortBy: SortBy.random,
        sortOrder: SortOrder.ascending,
        filters: {ItemFilter(type: ItemFilterType.isUnplayed)},
      ),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.forgottenFavoriteTracks => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.tracks),
      sortConfig: SortAndFilterConfiguration(
        sortBy: SortBy.datePlayed,
        sortOrder: SortOrder.ascending,
        filters: {ItemFilter(type: ItemFilterType.isFavorite)},
      ),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.recentQueues => HomeScreenSectionConfiguration(
      base: QueuesHomeSection(),
      sortConfig: SortAndFilterConfiguration(sortBy: SortBy.datePlayed, sortOrder: SortOrder.descending, filters: {}),
      customSectionTitle: null,
      presetType: presetType,
    ),
    HomeScreenSectionPresetType.recentlyPlayedTracks => HomeScreenSectionConfiguration(
      base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.tracks),
      sortConfig: SortAndFilterConfiguration(sortBy: SortBy.datePlayed, sortOrder: SortOrder.descending, filters: {}),
      customSectionTitle: null,
      presetType: presetType,
    ),
  };

  String getTitle(AppLocalizations l10n) =>
      customSectionTitle ??
      (presetType != null ? getTitleForPreset(l10n: l10n, presetType: presetType!) : toLocalisedString(l10n));
  static String getTitleForPreset({required AppLocalizations l10n, required HomeScreenSectionPresetType presetType}) =>
      switch (presetType) {
        HomeScreenSectionPresetType.favoriteTracks => l10n.homeScreenSectionPresetFavoriteTracksTitle,
        HomeScreenSectionPresetType.favoriteAlbums => l10n.favoriteAlbums,
        HomeScreenSectionPresetType.favoriteArtists => l10n.favoriteArtists,
        HomeScreenSectionPresetType.favoritePlaylists => l10n.favoritePlaylists,
        HomeScreenSectionPresetType.favoriteGenres => l10n.favoriteGenres,
        HomeScreenSectionPresetType.recentlyAddedAlbums => l10n.newlyAddedAlbums,
        HomeScreenSectionPresetType.recentlyAddedTracks => l10n.newlyAddedTracks,
        // HomeScreenSectionPresetType.recentlyPlayedPlaylists => "Recent Playlists*",
        HomeScreenSectionPresetType.frequentlyPlayedAlbums => l10n.frequentlyPlayedAlbums,
        HomeScreenSectionPresetType.frequentlyPlayedTracks => l10n.frequentlyPlayedTracks,
        HomeScreenSectionPresetType.frequentlyPlayedArtists => l10n.frequentlyPlayedArtists,
        HomeScreenSectionPresetType.neverPlayedAlbums => l10n.unplayedAlbums,
        HomeScreenSectionPresetType.forgottenFavoriteTracks => l10n.homeScreenSectionPresetForgottenFavoriteTracksTitle,
        HomeScreenSectionPresetType.recentQueues => l10n.recentQueues,
        HomeScreenSectionPresetType.recentlyPlayedTracks => l10n.recentlyPlayedTracks,
      };

  String getDescription(AppLocalizations l10n) =>
      presetType != null ? getDescriptionForPreset(l10n: l10n, presetType: presetType!) : toLocalisedString(l10n);
  static String getDescriptionForPreset({
    required AppLocalizations l10n,
    required HomeScreenSectionPresetType presetType,
  }) => switch (presetType) {
    HomeScreenSectionPresetType.favoriteTracks => l10n.homeScreenSectionPresetFavoriteTracksDescription,
    HomeScreenSectionPresetType.favoriteAlbums => l10n.favoriteAlbumsDescription,
    HomeScreenSectionPresetType.favoriteArtists => l10n.favoriteArtistsDescription,
    HomeScreenSectionPresetType.favoritePlaylists => l10n.favoritePlaylistsDescription,
    HomeScreenSectionPresetType.favoriteGenres => l10n.favoriteGenresDescription,
    HomeScreenSectionPresetType.recentlyAddedAlbums => l10n.recentlyAddedAlbumsDescription,
    HomeScreenSectionPresetType.recentlyAddedTracks => l10n.recentlyAddedTracksDescription,
    // HomeScreenSectionPresetType.recentlyPlayedPlaylists =>
    //   "Playlists you listened to recently, starting with last played*",
    HomeScreenSectionPresetType.frequentlyPlayedAlbums => l10n.frequentlyPlayedAlbumsDescription,
    HomeScreenSectionPresetType.frequentlyPlayedTracks => l10n.frequentlyPlayedTracksDescription,
    HomeScreenSectionPresetType.frequentlyPlayedArtists => l10n.frequentlyPlayedArtistsDescription,
    HomeScreenSectionPresetType.neverPlayedAlbums => l10n.neverPlayedAlbumsDescription,
    HomeScreenSectionPresetType.forgottenFavoriteTracks =>
      l10n.homeScreenSectionPresetForgottenFavoriteTracksDescription,
    HomeScreenSectionPresetType.recentQueues => l10n.recentQueuesDescription,
    HomeScreenSectionPresetType.recentlyPlayedTracks => l10n.recentlyPlayedTracksDescription,
  };

  Map<String, dynamic> toJson() => _$HomeScreenSectionConfigurationToJson(this);

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  String toLocalisedString(AppLocalizations l10n) {
    switch (base) {
      case QueuesHomeSection():
        return "${l10n.queues} ${sortConfig.filters.map((filter) => filter.getName(l10n)).join(", ")} ${sortConfig.sortBy.toLocalisedString(l10n)} ${sortConfig.sortOrder == SortOrder.ascending ? "↑" : "↓"}";
      case TabsHomeSection tab:
        return "${sortConfig.filters.map((filter) => filter.getName(l10n)).join(", ")} ${tab.contentType.toLocalisedString(l10n)} ${sortConfig.sortBy.toLocalisedString(l10n)} ${sortConfig.sortOrder == SortOrder.ascending ? "↑" : "↓"}";
      case CollectionHomeSection():
        return l10n.collection;
    }
  }

  //!!! Ignore custom title for equality, as it is not a defining feature of the section and can be changed by the user without changing the underlying section data
  @override
  bool operator ==(Object other) {
    return other is HomeScreenSectionConfiguration && other.base == base && other.sortConfig == sortConfig;
    // other.customSectionTitle == customSectionTitle &&
    // other.presetType == presetType;
  }

  @override
  @ignore
  int get hashCode => Object.hash(base, sortConfig);

  String get id => "home-section-$hashCode";
}

@HiveType(typeId: 120)
enum HomeScreenSectionPresetType {
  @HiveField(0)
  favoriteTracks,
  @HiveField(1)
  favoriteAlbums,
  @HiveField(2)
  favoriteArtists,
  @HiveField(3)
  favoritePlaylists,
  @HiveField(4)
  favoriteGenres,
  @HiveField(5)
  recentlyAddedAlbums,
  @HiveField(6)
  recentlyAddedTracks,
  @HiveField(7)
  frequentlyPlayedAlbums,
  @HiveField(8)
  frequentlyPlayedTracks,
  @HiveField(9)
  frequentlyPlayedArtists,
  @HiveField(10)
  neverPlayedAlbums,
  @HiveField(11)
  forgottenFavoriteTracks,
  @HiveField(12)
  recentQueues,
  @HiveField(13)
  recentlyPlayedTracks,
  //TODO once we can track playlists plays, add this back in
  // @HiveField(7)
  // recentlyPlayedPlaylists,
  //TODO add section with generated mixes, e.g. via AudioMuse
  //TODO add more
}

@HiveType(typeId: 121)
enum FinampQuickActions {
  @HiveField(0)
  shuffleTracks,
  @HiveField(1)
  browseRecentQueues,
  @HiveField(2)
  browsePlaybackHistory,
  @HiveField(3)
  playRandomAlbum,
  @HiveField(4)
  playRandomTrack,
  @HiveField(5)
  playRandomFavoriteItem,
  @HiveField(6)
  playPreviousQueue,
  @HiveField(7)
  configureOutput,
  @HiveField(8)
  surpriseMe,
  @HiveField(9)
  playSpecificItem;
  //TODO support album/artist shuffle (requires queue support)

  bool get editable => switch (this) {
    FinampQuickActions.playSpecificItem => true,
    _ => false,
  };

  /// Human-readable version of the [FinampQuickActionType]
  @override
  @Deprecated("Use toLocalisedString when possible")
  String toString() => QuickActionConfig(action: this).getTitle(GlobalSnackbar.englishL10n);

  String getDescription(BuildContext context) {
    switch (this) {
      case FinampQuickActions.shuffleTracks:
        return AppLocalizations.of(context)!.shuffleTracksActionDescription;
      case FinampQuickActions.browseRecentQueues:
        return AppLocalizations.of(context)!.browseRecentQueuesActionDescription;
      case FinampQuickActions.browsePlaybackHistory:
        return AppLocalizations.of(context)!.browsePlaybackHistoryActionDescription;
      case FinampQuickActions.playRandomAlbum:
        return AppLocalizations.of(context)!.playRandomAlbumActionDescription;
      case FinampQuickActions.playRandomTrack:
        return AppLocalizations.of(context)!.playRandomTrackActionDescription;
      case FinampQuickActions.playRandomFavoriteItem:
        return AppLocalizations.of(context)!.playRandomFavoriteItemActionDescription;
      case FinampQuickActions.playPreviousQueue:
        return AppLocalizations.of(context)!.playPreviousQueueActionDescription;
      case FinampQuickActions.configureOutput:
        return AppLocalizations.of(context)!.configureOutputActionDescription;
      case FinampQuickActions.playSpecificItem:
        return AppLocalizations.of(context)!.playSpecificItemActionDescription;
      case FinampQuickActions.surpriseMe:
        return AppLocalizations.of(context)!.surpriseMeActionDescription;
    }
  }

  IconData getIcon() {
    return switch (this) {
      FinampQuickActions.shuffleTracks => TablerIcons.arrows_shuffle,
      FinampQuickActions.browseRecentQueues => Icons.auto_delete,
      FinampQuickActions.browsePlaybackHistory => TablerIcons.clock,
      FinampQuickActions.playRandomAlbum => TablerIcons.album,
      FinampQuickActions.playRandomTrack => TablerIcons.music,
      FinampQuickActions.playRandomFavoriteItem => TablerIcons.heart_question,
      FinampQuickActions.playPreviousQueue => TablerIcons.restore,
      FinampQuickActions.configureOutput => TablerIcons.device_speaker,
      FinampQuickActions.playSpecificItem => TablerIcons.music_pin,
      FinampQuickActions.surpriseMe => TablerIcons.radio,
    };
  }
}

@JsonSerializable(createFactory: false)
@HiveType(typeId: 122)
class FinampHomeScreenConfiguration {
  const FinampHomeScreenConfiguration({required this.actions, required this.sections});

  @HiveField(0)
  final List<QuickActionConfig> actions;

  @HiveField(1)
  final List<HomeScreenSectionConfiguration> sections;

  Map<String, dynamic> toJson() => _$FinampHomeScreenConfigurationToJson(this);

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  // implement copyWith
  FinampHomeScreenConfiguration copyWith({
    List<QuickActionConfig>? actions,
    List<HomeScreenSectionConfiguration>? sections,
  }) {
    return FinampHomeScreenConfiguration(actions: actions ?? this.actions, sections: sections ?? this.sections);
  }
}

@HiveType(typeId: 123)
enum ItemFilterType {
  @HiveField(0)
  isFavorite(Null),
  @HiveField(1)
  isFullyDownloaded(Null),
  @HiveField(2)
  startsWithCharacter(String),
  @HiveField(3)
  genreFilter(BaseItemDto),
  @HiveField(4)
  searchTerm(String),
  @HiveField(5)
  isUnplayed(Null);

  const ItemFilterType(this.extraType);

  final Type extraType;

  bool get isArtistGenre => switch (this) {
    genreFilter => true,
    _ => false,
  };

  IconData get icon => switch (this) {
    isFavorite => TablerIcons.heart,
    isFullyDownloaded => TablerIcons.download,
    startsWithCharacter => TablerIcons.abc,
    genreFilter => TablerIcons.tag,
    searchTerm => TablerIcons.list_search,
    isUnplayed => TablerIcons.headphones_off,
  };
}

@JsonSerializable()
@HiveType(typeId: 124)
class ItemFilter {
  ItemFilter({required this.type, dynamic extras}) : _extras = extras, assert(extras.runtimeType == type.extraType);

  @HiveField(0)
  final ItemFilterType type;

  @HiveField(1)
  final dynamic _extras;

  /// Prefer using the [extraString] and [extraBaseItem] getters, which include a cast
  dynamic get extras => _extras;
  String get extraString => _extras as String;
  BaseItemDto get extraBaseItem => _extras as BaseItemDto;

  factory ItemFilter.fromJson(Map<String, dynamic> json) => _$ItemFilterFromJson(json);

  Map<String, dynamic> toJson() => _$ItemFilterToJson(this);

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  String getName(AppLocalizations l10n) {
    switch (type) {
      case ItemFilterType.isFavorite:
        return l10n.isFavoriteFilter;
      case ItemFilterType.isFullyDownloaded:
        return l10n.isFullyDownloadedFilter;
      case ItemFilterType.isUnplayed:
        return l10n.isUnplayedFilter;
      case ItemFilterType.genreFilter:
        return l10n.genreFilter(extraBaseItem.name ?? "");
      case ItemFilterType.startsWithCharacter:
        return l10n.startsWithFilter(extraString.toUpperCase());
      case ItemFilterType.searchTerm:
        return l10n.searchTermFilter(extraString);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ItemFilter && other.type == type && other.extras == extras;
  }

  @override
  int get hashCode => Object.hash(type, extras);
}

@JsonSerializable()
@HiveType(typeId: 125)
class SortAndFilterConfiguration {
  const SortAndFilterConfiguration({required this.sortBy, required this.sortOrder, required this.filters});

  @HiveField(0)
  final SortBy sortBy;

  @HiveField(1)
  final SortOrder sortOrder;

  @HiveField(2)
  final Set<ItemFilter> filters;

  factory SortAndFilterConfiguration.fromJson(Map<String, dynamic> json) => _$SortAndFilterConfigurationFromJson(json);

  BaseItemDto? get genreFilter => filters.firstWhereOrNull((x) => x.type == ItemFilterType.genreFilter)?.extraBaseItem;

  bool get favoritesFilter => filters.firstWhereOrNull((x) => x.type == ItemFilterType.isFavorite) != null;

  SortAndFilterConfiguration copyWith({
    SortBy? sortBy,
    SortOrder? sortOrder,
    Set<ItemFilter>? filters,
    BaseItemDto? genreFilter,
    bool? favoriteFilter,
    bool? onlyShowFullyDownloadedFilter,
    String? searchQuery,
  }) {
    final processedFilters = filters ?? this.filters.toSet();
    if (genreFilter != null) {
      processedFilters.removeWhere((x) => x.type == ItemFilterType.genreFilter);
      processedFilters.add(ItemFilter(type: ItemFilterType.genreFilter, extras: genreFilter));
    }
    if (favoriteFilter != null) {
      processedFilters.removeWhere((x) => x.type == ItemFilterType.isFavorite);
      if (favoriteFilter) {
        processedFilters.add(ItemFilter(type: ItemFilterType.isFavorite));
      }
    }
    if (onlyShowFullyDownloadedFilter != null) {
      processedFilters.removeWhere((x) => x.type == ItemFilterType.isFullyDownloaded);
      if (onlyShowFullyDownloadedFilter) {
        processedFilters.add(ItemFilter(type: ItemFilterType.isFullyDownloaded));
      }
    }
    if (searchQuery != null) {
      processedFilters.removeWhere((x) => x.type == ItemFilterType.searchTerm);
      processedFilters.add(ItemFilter(type: ItemFilterType.searchTerm, extras: searchQuery));
    }
    return SortAndFilterConfiguration(
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      filters: processedFilters,
    );
  }

  static const defaultSort = ResolvedSortConfig.defaultSort;

  static const defaultInAlbumSort = ResolvedSortConfig.defaultInAlbumSort;

  static ResolvedSortConfig defaultForItem(BaseItemDto item) {
    if ([BaseItemDtoType.album, BaseItemDtoType.playlist].contains(BaseItemDtoType.fromItem(item))) {
      return defaultInAlbumSort;
    } else {
      return defaultSort;
    }
  }

  /*SortAndFilterConfiguration resolve({required bool isOffline, String? searchQuery}) {
    final newFilters = filters.union({
      if (searchQuery != null) ItemFilter(type: ItemFilterType.searchTerm, extras: searchQuery),
    });
    var newSortBy = sortBy;
    // PlayCount and Last Played are not representative in Offline Mode
    // so we disable it and overwrite it with the Sort Name if it was selected
    if (isOffline && (sortBy == SortBy.playCount || sortBy == SortBy.datePlayed)) {
      newSortBy = cont ? SortBy.defaultOrder : SortBy.sortName;
    }
    return copyWith(sortBy: newSortBy, filters: newFilters);
  }*/

  Map<String, dynamic> toJson() => _$SortAndFilterConfigurationToJson(this);

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  @override
  bool operator ==(Object other) {
    return other is SortAndFilterConfiguration &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder &&
        setEquals(other.filters, filters);
  }

  @override
  int get hashCode {
    return Object.hash(sortBy, sortOrder, Object.hashAllUnordered(filters));
  }
}

@HiveType(typeId: 126)
@JsonSerializable(converters: [BaseItemIdConverter()], includeIfNull: false)
class QuickActionConfig {
  @HiveField(0)
  final FinampQuickActions action;
  @HiveField(1)
  final BaseItemId? itemId;
  @HiveField(2)
  final String? itemName;

  const QuickActionConfig({required this.action, this.itemId, this.itemName});

  String getTitle(AppLocalizations l10n) {
    switch (action) {
      case FinampQuickActions.shuffleTracks:
        return l10n.shuffleTracksAction;
      case FinampQuickActions.browseRecentQueues:
        return l10n.recentQueues;
      case FinampQuickActions.browsePlaybackHistory:
        return l10n.playbackHistory;
      case FinampQuickActions.playRandomAlbum:
        return l10n.randomAlbumAction;
      case FinampQuickActions.playRandomTrack:
        return l10n.randomTrackAction;
      case FinampQuickActions.playRandomFavoriteItem:
        return l10n.randomFavoriteAction;
      case FinampQuickActions.playPreviousQueue:
        return l10n.previousQueueAction;
      case FinampQuickActions.configureOutput:
        return l10n.configureOutputAction;
      case FinampQuickActions.playSpecificItem:
        return l10n.playSpecificItemAction(itemName ?? "finamp_placeholder");
      case FinampQuickActions.surpriseMe:
        return l10n.surpriseMeAction;
    }
  }

  factory QuickActionConfig.fromJson(Map<String, dynamic> json) => _$QuickActionConfigFromJson(json);

  Map<String, dynamic> toJson() => _$QuickActionConfigToJson(this);

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
